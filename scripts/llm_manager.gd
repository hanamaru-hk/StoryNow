extends Node
## Library functions for managing the Ollama (LLM) server process.

const LLMServerArgs := preload("res://scripts/llm_server_args.gd")
const STATUS_PATH := "user://llm_status.json"
const LLAMA_DIR := "server/llama"
const LLAMA_MODELS_DIR_CEN := "data/llama-models/cen"
const LLAMA_MODELS_DIR_AB := "data/llama-models/ab"
const HEALTH_TIMEOUT := 5.0
const DEFAULT_BRAINSTORM_TIMEOUT := 60.0
const LLM_HOST := "127.0.0.1"
const CHAT_ENDPOINT := "/v1/chat/completions"
const PROMPT_DIR := "data/llm"
const RANDOM := "random"
const THEMES := "themes"
const ENHANCE := "enhance"
const STORY := "story"
const SCENE := "scene"
const STORY_BACKGROUND_REQUIREMENT := "common/story_background_requirement"
const OUTPUT_JSON_REQUIREMENT := "common/output_json_requirement"
const OUTPUT_JSON_TEMPLATE := "common/output_template.json"
const DEVELOPMENT_CHOICES := "common/choices"
const DEVELOPMENT_ENDING := "common/ending"
const SAFE_GUARDRAIL := "common/safe_guardrail"
const SAFE_DANBOORU_GUARDRAIL := "common/safe_danbooru_guardrail"
const BUILDER_GUARDRAIL := "common/builder_guardrail"
const BUILDER_DANBOORU_GUARDRAIL := "common/builder_danbooru_guardrail"


signal status_changed(status: Dictionary)

var status := {
	"pid": -1,
	"running": false,
	"healthy": false,
}
var _cancel_requested := false
var _active_http: HTTPClient = null


func _ready() -> void:
	load_status()


func start_server() -> void:
	if status["running"]:
		return
	var port: int = LLMSettingsManager.settings["port"]
	var port_number := str(port)
	var exe_path := AppPaths.external_path(LLAMA_DIR + "/llama-server.exe")
	var model_filename := str(LLMSettingsManager.settings.get("llm_model_filename", ""))
	if model_filename.is_empty():
		model_filename = "cen/unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf"
	var model_path := AppPaths.external_path("data/llama-models/" + model_filename)
	if not FileAccess.file_exists(exe_path):
		push_error("llama-server executable not found: " + exe_path)
		return
	var args := LLMServerArgs.build(LLMSettingsManager.settings, model_path, port_number)
	var pid: int = OS.create_process(exe_path, args, OS.is_stdout_verbose())
	if pid < 0:
		push_error("Failed to start Ollama process")
		return
	status["pid"] = pid
	status["running"] = true
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func stop_server() -> void:
	if status["pid"] > 0:
		OS.execute("taskkill", ["/T", "/F", "/PID", str(status["pid"])])
		status["pid"] = -1
	status["running"] = false
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func health_check() -> bool:
	var port: int = LLMSettingsManager.settings["port"]
	var http := HTTPClient.new()

	var error := http.connect_to_host("127.0.0.1", port)
	if error != OK:
		_set_unhealthy()
		return false

	var timeout := HEALTH_TIMEOUT

	# Wait for connection
	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		_set_unhealthy()
		return false

	# Send request
	error = http.request(
		HTTPClient.METHOD_GET,
		"/health",
		PackedStringArray()
	)

	if error != OK:
		http.close()
		_set_unhealthy()
		return false

	timeout = HEALTH_TIMEOUT

	# Wait for response
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false

	# Make sure we actually received a response
	if not http.has_response():
		http.close()
		_set_unhealthy()
		return false

	var response_code := http.get_response_code()

	# Consume response body
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()

		if chunk.is_empty():
			await get_tree().process_frame

	http.close()

	if response_code >= 200 and response_code < 400:
		status["healthy"] = true
		status["running"] = true
		save_status()
		status_changed.emit(status)
		return true

	_set_unhealthy()
	return false


func _set_unhealthy() -> void:
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func save_status() -> void:
	var file := FileAccess.open(STATUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(status, "\t"))
		file.close()


func load_status() -> void:
	if not FileAccess.file_exists(STATUS_PATH):
		return
	var file := FileAccess.open(STATUS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			status = json.data


func cancel_active_request() -> void:
	_cancel_requested = true
	if _active_http != null:
		_active_http.close()


func request_random() -> Dictionary:
	var prompt_file := RANDOM 
	var prompt := _load_prompt(prompt_file)
	if prompt.is_empty():
		return {"success": false, "error": "Failed to load prompt template"}
	var theme := _load_random_theme()
	if theme.is_empty():
		return {"success": false, "error": "Failed to load themes"}
	var requirement := _load_prompt(STORY_BACKGROUND_REQUIREMENT)
	if requirement.is_empty():
		return {"success": false, "error": "Failed to load requirement template"}
	
	if GameSettingsManager.is_builder_mode():
		print_verbose("Builder mode: using builder guardrail")
		var guardrail := _load_prompt(BUILDER_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	else:
		print_verbose("Safe mode: using safe guardrail")
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	prompt = prompt.replace("__THEME__", theme)
	prompt = prompt.replace("__STORY_BACKGROUND_REQUIREMENT__", requirement)
	prompt = prompt.replace("__MINIMUM_SENTENCES_IN_SUMMARY__", str(GameProgressManager.settings.get("minimum_sentences_in_summary", 10)))
	print_verbose("")
	print_verbose("prompt_random:"+ prompt)
	return await _request_completion(prompt)

func request_enhance(input: String) -> Dictionary:
	var prompt_file := ENHANCE
	var prompt := _load_prompt(prompt_file)
	if prompt.is_empty():
		return {"success": false, "error": "Failed to load prompt template"}
	var requirement := _load_prompt(STORY_BACKGROUND_REQUIREMENT)
	if requirement.is_empty():
		return {"success": false, "error": "Failed to load requirement template"}
	if GameSettingsManager.is_builder_mode():
		print_verbose("Builder mode: using builder guardrail")
		var guardrail := _load_prompt(BUILDER_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	else:
		print_verbose("Safe mode: using safe guardrail")
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	prompt = prompt.replace("__STORY_BACKGROUND_REQUIREMENT__", requirement)
	prompt = prompt.replace("__PLAYER_INPUT__", input)
	prompt = prompt.replace("__MINIMUM_SENTENCES_IN_SUMMARY__", str(GameProgressManager.settings.get("minimum_sentences_in_summary", 10)))
	print_verbose("")
	print_verbose("prompt_enhance:"+ prompt)
	return await _request_completion(prompt)


func _load_prompt(file_name: String) -> String:
	var path := AppPaths.external_path("%s/%s/%s" % [PROMPT_DIR, I18n.current_lang, file_name])
	if not FileAccess.file_exists(path):
		print_verbose("Prompt file not found for lang %s, falling back to en: %s" % [I18n.current_lang, path])
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _load_random_theme() -> String:
	var themes_text := _load_prompt(THEMES)
	if themes_text.is_empty():
		return ""
	var themes := PackedStringArray()
	for line in themes_text.split("\n"):
		var theme := str(line).strip_edges()
		if not theme.is_empty():
			themes.append(theme)
	if themes.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return themes[rng.randi_range(0, themes.size() - 1)]


func _load_template(lang: String) -> String:
	var path := AppPaths.external_path("%s/%s/%s" % [PROMPT_DIR, lang, OUTPUT_JSON_TEMPLATE])
	if not FileAccess.file_exists(path):
		# Fallback to en
		path = AppPaths.external_path("%s/en/%s" % [PROMPT_DIR, OUTPUT_JSON_TEMPLATE])
		if not FileAccess.file_exists(path):
			return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _replace_requirement_placeholders(text: String) -> String:
	var s := GameProgressManager.settings
	var min_dialogues_per_scene_val := str(s.get("minimum_dialogues_per_scene", 10))
	var min_sent_val := str(s.get("minimum_sentences_per_dialogue", 10))
	var plot_val: String
	if s.has("minimum_plot_directions"):
		plot_val = str(s["minimum_plot_directions"])
	elif s.has("maximum_plot_directions"):
		plot_val = str(s["maximum_plot_directions"])
	else:
		plot_val = "10"
	var summ_val := str(s.get("minimum_sentences_in_summary", 10))
	var result := text
	# Old and new placeholder variants
	result = result.replace("__MINIMUM_DIALOGUES_PER_SCENE__", min_dialogues_per_scene_val)
	result = result.replace("__MINIMUM_SENTENCES_PER_DIALOGUE__", min_sent_val)
	result = result.replace("__MAXIMUM_PLOT_DIRECTIONS__", plot_val)
	result = result.replace("__MINIMUM_SENTENCES_IN_SUMMARY__", summ_val)
	if GameSettingsManager.is_builder_mode():
		var guardrail := _load_prompt(BUILDER_DANBOORU_GUARDRAIL)
		result = result.replace("__DANBOORU_GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_DANBOORU_GUARDRAIL)
		result = result.replace("__DANBOORU_GUARDRAIL__", guardrail)

	return result


func _replace_scene_development_placeholder(text: String, current_round: int, expected_rounds: int) -> String:
	var development := ""
	if expected_rounds > 0 and current_round >= expected_rounds:
		development = _load_prompt(DEVELOPMENT_ENDING)
	else:
		development = _load_prompt(DEVELOPMENT_CHOICES)
	return text.replace("__DEVELOPMENT__", development)


func request_new_story() -> Dictionary:
	var lang := I18n.current_lang
	var prompt_story := _load_prompt(STORY)
	if prompt_story.is_empty():
		return {"success": false, "error": "Failed to load prompt_story for lang %s" % lang}
	var prompt_output_json_requirement := _load_prompt(OUTPUT_JSON_REQUIREMENT)
	if prompt_output_json_requirement.is_empty():
		return {"success": false, "error": "Failed to load prompt_json_requirement"}
	prompt_output_json_requirement = _replace_requirement_placeholders(prompt_output_json_requirement)
	var template_str := _load_template(lang)
	if template_str.is_empty():
		return {"success": false, "error": "Failed to load template.json"}
	if GameSettingsManager.is_builder_mode():
		var guardrail := _load_prompt(BUILDER_GUARDRAIL)
		prompt_story = prompt_story.replace("__GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt_story = prompt_story.replace("__GUARDRAIL__", guardrail)
	var background: String = str(SceneDataManager.scene_data.get("summary", ""))
	# Fallback: if summary empty, try GameProgress or empty
	if background.strip_edges().is_empty():
		background = str(SceneDataManager.scene_data.get("summary", ""))
	prompt_story = prompt_story.replace("__STORY_BACKGROUND__", background)
	prompt_story = prompt_story.replace("__OUTPUT_JSON_REQUIREMENT__", prompt_output_json_requirement)
	prompt_story = prompt_story.replace("__OUTPUT_JSON_TEMPLATE__", template_str)


	print_verbose("")
	print_verbose("prompt_story:"+ prompt_story)
	return await _request_completion(prompt_story)


func request_new_scene() -> Dictionary:
	var lang := I18n.current_lang
	var prompt_scene := _load_prompt(SCENE)
	if prompt_scene.is_empty():
		return {"success": false, "error": "Failed to load prompt_scene for lang %s" % lang}
	var prompt_output_json_requirement := _load_prompt(OUTPUT_JSON_REQUIREMENT)
	if prompt_output_json_requirement.is_empty():
		return {"success": false, "error": "Failed to load prompt_json_requirement"}
	var template_str := _load_template(lang)
	if template_str.is_empty():
		return {"success": false, "error": "Failed to load template.json"}
	if GameSettingsManager.is_builder_mode():
		var guardrail := _load_prompt(BUILDER_GUARDRAIL)
		prompt_scene = prompt_scene.replace("__GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt_scene = prompt_scene.replace("__GUARDRAIL__", guardrail)
	# Load previous scene JSON from prev_uuid's file
	var prev_uuid: String = str(SceneDataManager.scene_data.get("prev_uuid", ""))
	if prev_uuid.strip_edges().is_empty():
		# fallback: try id-based lookup or GameProgressManager
		prev_uuid = str(SceneDataManager.scene_data.get("prev", ""))
	if prev_uuid.strip_edges().is_empty():
		prev_uuid = str(GameProgressManager.settings.get("prev_uuid", ""))
	var previous_json_str: String = ""

	if not prev_uuid.strip_edges().is_empty():
		var prev_path := "user://saves/%s/scene_data.json" % prev_uuid
		if FileAccess.file_exists(prev_path):
			var f := FileAccess.open(prev_path, FileAccess.READ)
			if f != null:
				previous_json_str = f.get_as_text()
				f.close()
		if previous_json_str.strip_edges().is_empty():
			# Fallback: stringify current scene_data as best effort
			previous_json_str = JSON.stringify(SceneDataManager.scene_data)
	else:
		previous_json_str = JSON.stringify(SceneDataManager.scene_data)
	
	var json = JSON.new()
	var summary: String = ""

	if json.parse(previous_json_str) == OK and json.data is Dictionary:
		summary = json.data.get("summary", "")

	var player_input: String = str(SceneDataManager.scene_data.get("player_input", GameProgressManager.settings.get("player_input", "")))
	var expected_rounds: int = int(SceneDataManager.scene_data.get("expected_rounds", GameProgressManager.settings.get("expected_rounds", 0)))
	var current_round: int = int(SceneDataManager.scene_data.get("current_round", GameProgressManager.settings.get("current_round", 0)))
	prompt_output_json_requirement = _replace_scene_development_placeholder(prompt_output_json_requirement, current_round, expected_rounds)
	prompt_output_json_requirement = _replace_requirement_placeholders(prompt_output_json_requirement)
	prompt_scene = prompt_scene.replace("__STORY_BACKGROUND__", summary)
	prompt_scene = prompt_scene.replace("__CURRENT_ROUND__", str(current_round))
	prompt_scene = prompt_scene.replace("__EXPECTED_ROUNDS__", str(expected_rounds))
	prompt_scene = prompt_scene.replace("__PLAYER_INPUT__", player_input)
	prompt_scene = prompt_scene.replace("__OUTPUT_JSON_REQUIREMENT__", prompt_output_json_requirement)
	prompt_scene = prompt_scene.replace("__OUTPUT_JSON_TEMPLATE__", template_str)
	print_verbose("")
	print_verbose("prompt_scene:"+ prompt_scene)
	return await _request_completion(prompt_scene)


func _request_completion(prompt: String) -> Dictionary:
	_cancel_requested = false
	var request_timeout: float = float(LLMSettingsManager.settings.get("timeout", DEFAULT_BRAINSTORM_TIMEOUT))
	var queue_id := ServerRuntimeManager.push_request("llm", I18n.translate("request_generating_gameplay"), request_timeout)
	var port: int = LLMSettingsManager.settings["port"]
	var body := JSON.stringify({
		"messages": [{"role": "user", "content": prompt}],
		"stream": true,
		"thinking": false,
		"cache_prompt": false,
		"chat_template_kwargs": {
		    "enable_thinking": false
  		},
	})
	var stream_result := await _request_completion_stream(port, body, queue_id, request_timeout)
	if not stream_result.get("success", false):
		ServerRuntimeManager.pop_request(queue_id)
		var was_cancelled := _cancel_requested or bool(stream_result.get("cancelled", false))
		return {
			"success": false,
			"cancelled": was_cancelled,
			"error": "Cancelled" if was_cancelled else str(stream_result.get("error", "Request failed")),
		}
	var content: String = str(stream_result.get("content", ""))
	if content.strip_edges().is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		return {"success": false, "error": "Empty content"}
	# Extract title field from content for TitleLabel (best-effort, no repair)
	var title: String = ""
	var t_for_title: String = content.strip_edges()
	if t_for_title.begins_with("```"):
		var s_idx: int = t_for_title.find("\n")
		var e_idx: int = t_for_title.rfind("```")
		if s_idx != -1 and e_idx != -1 and e_idx > s_idx:
			t_for_title = t_for_title.substr(s_idx + 1, e_idx - s_idx - 1).strip_edges()
		else:
			t_for_title = t_for_title.replace("```json", "").replace("```", "").strip_edges()
	var tmp_json := JSON.new()
	if tmp_json.parse(t_for_title) == OK and tmp_json.data is Dictionary:
		title = str((tmp_json.data as Dictionary).get("title", ""))
	ServerRuntimeManager.pop_request(queue_id)
	return {"success": true, "text": content, "title": title}


func _request_completion_stream(port: int, body: String, queue_id: int, request_timeout: float) -> Dictionary:
	var http := HTTPClient.new()
	_active_http = http
	var error := http.connect_to_host(LLM_HOST, port)
	if error != OK:
		_active_http = null
		return {"success": false, "error": "Failed to connect"}

	var started_at_msec := Time.get_ticks_msec()
	var deadline_msec := started_at_msec + int(request_timeout * 1000.0)
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		if _cancel_requested:
			http.close()
			_active_http = null
			return {"success": false, "cancelled": true, "error": "Cancelled"}
		http.poll()
		if Time.get_ticks_msec() > deadline_msec:
			http.close()
			_active_http = null
			return {"success": false, "error": "Request timed out"}
		await get_tree().process_frame

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		_active_http = null
		return {"success": false, "error": "Failed to connect"}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: text/event-stream",
	])
	error = http.request(HTTPClient.METHOD_POST, CHAT_ENDPOINT, headers, body)
	if error != OK:
		http.close()
		_active_http = null
		return {"success": false, "error": "Failed to send request"}

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		if _cancel_requested:
			http.close()
			_active_http = null
			return {"success": false, "cancelled": true, "error": "Cancelled"}
		http.poll()
		if Time.get_ticks_msec() > deadline_msec:
			http.close()
			_active_http = null
			return {"success": false, "error": "Request timed out"}
		await get_tree().process_frame

	if not http.has_response():
		http.close()
		_active_http = null
		return {"success": false, "error": "No response"}

	var response_code := http.get_response_code()
	if response_code < 200 or response_code >= 300:
		http.close()
		_active_http = null
		return {"success": false, "error": "HTTP %d" % response_code}

	var content := ""
	var buffer := ""
	var token_count := 0
	var last_update_msec := 0
	var stream_preview := ""
	var show_streaming := bool(GameSettingsManager.settings.get("show_streaming", true))
	while http.get_status() == HTTPClient.STATUS_BODY:
		if _cancel_requested:
			http.close()
			_active_http = null
			return {"success": false, "cancelled": true, "error": "Cancelled"}
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() > deadline_msec:
				http.close()
				_active_http = null
				return {"success": false, "error": "Request timed out"}
			await get_tree().process_frame
			continue

		buffer += chunk.get_string_from_utf8()
		var parsed := _consume_stream_events(buffer)
		buffer = str(parsed.get("buffer", ""))
		var streamed_content := str(parsed.get("content", ""))
		content += streamed_content
		token_count += int(parsed.get("tokens", 0))
		if show_streaming and not streamed_content.is_empty():
			stream_preview = _append_stream_preview(stream_preview, streamed_content)
		if token_count > 0 and Time.get_ticks_msec() - last_update_msec > 200:
			last_update_msec = Time.get_ticks_msec()
			var update := {
				"status": "%ds" % int((Time.get_ticks_msec() - started_at_msec) / 1000.0),
				"tokens": token_count,
			}
			if show_streaming:
				update["stream_text"] = stream_preview
			ServerRuntimeManager.update_request(queue_id, update)

	http.close()
	_active_http = null
	return {"success": true, "content": content}


func _append_stream_preview(current: String, piece: String) -> String:
	var preview := current
	for i in range(piece.length()):
		var character := piece.substr(i, 1)
		if character == "\n":
			preview = ""
			continue
		if character == "\r":
			continue
		preview += character
		if preview.length() > 15:
			preview = preview.substr(preview.length() - 15)
	return preview


func _consume_stream_events(buffer: String) -> Dictionary:
	var content := ""
	var token_count := 0
	while true:
		var separator := buffer.find("\n\n")
		var separator_length := 2
		if separator == -1:
			separator = buffer.find("\r\n\r\n")
			separator_length = 4
		if separator == -1:
			break
		var event := buffer.substr(0, separator)
		buffer = buffer.substr(separator + separator_length)
		for raw_line in event.split("\n"):
			var line := str(raw_line).strip_edges()
			if not line.begins_with("data:"):
				continue
			var data := line.substr(5).strip_edges()
			if data == "[DONE]":
				continue
			var json := JSON.new()
			if json.parse(data) != OK or json.data is not Dictionary:
				continue
			var choices: Array = json.data.get("choices", [])
			if choices.is_empty():
				continue
			var delta: Dictionary = choices[0].get("delta", {})
			var raw_piece = delta.get("content", "")
			if not (raw_piece is String):
				continue
			var piece := raw_piece as String
			if not piece.is_empty():
				content += piece
				token_count += 1
	return {"buffer": buffer, "content": content, "tokens": token_count}


func requestScene() -> void:
	pass


func requestStory() -> void:
	pass
