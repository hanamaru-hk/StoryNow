extends Node
## Library functions for managing the Ollama (LLM) server process.

const STATUS_PATH := "user://llm_status.json"
const LLAMA_DIR := "server/llama"
const LLAMA_MODELS_DIR := "server/llama-models"
const HEALTH_TIMEOUT := 5.0
const BRAINSTORM_TIMEOUT := 120.0
const LLM_HOST := "127.0.0.1"
const CHAT_ENDPOINT := "/v1/chat/completions"
const PROMPT_DIR := "res://data/llm"
const RANDOM := "random"
const ENHANCE := "enhance"
const STORY := "story"
const SCENE := "scene"
const STORY_BACKGROUND_REQUIREMENT := "common/story_background_requirement"
const OUTPUT_JSON_REQUIREMENT := "common/output_json_requirement"
const OUTPUT_JSON_TEMPLATE := "common/output_template.json"
const SAFE_GUARDRAIL := "common/safe_guardrail"
const SAFE_DANBOORU_GUARDRAIL := "common/safe_danbooru_guardrail"
const FREE_GUARDRAIL := "common/free_guardrail"
const FREE_DANBOORU_GUARDRAIL := "common/free_danbooru_guardrail"


signal status_changed(status: Dictionary)

var status := {
	"pid": -1,
	"running": false,
	"healthy": false,
}


func _ready() -> void:
	load_status()


func start_server() -> void:
	if status["running"]:
		return
	var port: int = LLMSettingsManager.settings["port"]
	var port_number := str(port)
	var exe_path := ProjectSettings.globalize_path("res://" + LLAMA_DIR + "/llama-server.exe")
	var model_path := ProjectSettings.globalize_path("res://" + LLAMA_MODELS_DIR + "/huihui-qwen3.5-9b-Q4_K_M.gguf")
	# var model_path := ProjectSettings.globalize_path("res://" + LLAMA_DIR + "/models/unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf")
	if not FileAccess.file_exists(exe_path):
		push_error("llama-server executable not found: " + exe_path)
		return
	var args := PackedStringArray(["-ngl","99","-m", model_path, "--port", port_number])
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


func request_random() -> Dictionary:
	var prompt_file := RANDOM 
	var prompt := _load_prompt(prompt_file)
	if prompt.is_empty():
		return {"success": false, "error": "Failed to load prompt template"}
	var requirement := _load_prompt(STORY_BACKGROUND_REQUIREMENT)
	if requirement.is_empty():
		return {"success": false, "error": "Failed to load requirement template"}
	
	if GameSettingsManager.is_free_mode():
		var guardrail := _load_prompt(FREE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
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
	if GameSettingsManager.is_free_mode():
		var guardrail := _load_prompt(FREE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_GUARDRAIL)
		prompt = prompt.replace("__GUARDRAIL__", guardrail)
	prompt = prompt.replace("__STORY_BACKGROUND_REQUIREMENT__", requirement)
	prompt = prompt.replace("__PLAYER_INPUT__", input)
	prompt = prompt.replace("__MINIMUM_SENTENCES_IN_SUMMARY__", str(GameProgressManager.settings.get("minimum_sentences_in_summary", 10)))
	print_verbose("")
	print_verbose("prompt_enhance:"+ prompt)
	return await _request_completion(prompt)


func _load_prompt(file_name: String) -> String:
	var path := "%s/%s/%s" % [PROMPT_DIR, I18n.current_lang, file_name]
	if not FileAccess.file_exists(path):
		print_verbose("Prompt file not found for lang %s, falling back to en: %s" % [I18n.current_lang, path])
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _load_template(lang: String) -> String:
	var path := "%s/%s/%s" % [PROMPT_DIR, lang, OUTPUT_JSON_TEMPLATE]
	if not FileAccess.file_exists(path):
		# Fallback to en
		path = "%s/en/%s" % [PROMPT_DIR, OUTPUT_JSON_TEMPLATE]
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
	if GameSettingsManager.is_free_mode():
		var guardrail := _load_prompt(FREE_DANBOORU_GUARDRAIL)
		result = result.replace("__DANBOORU_GUARDRAIL__", guardrail)
	else:
		var guardrail := _load_prompt(SAFE_DANBOORU_GUARDRAIL)
		result = result.replace("__DANBOORU_GUARDRAIL__", guardrail)

	return result


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
	if GameSettingsManager.is_free_mode():
		var guardrail := _load_prompt(FREE_GUARDRAIL)
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
	prompt_output_json_requirement = _replace_requirement_placeholders(prompt_output_json_requirement)
	var template_str := _load_template(lang)
	if template_str.is_empty():
		return {"success": false, "error": "Failed to load template.json"}
	if GameSettingsManager.is_free_mode():
		var guardrail := _load_prompt(FREE_GUARDRAIL)
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

	var player_input: String = str(GameProgressManager.settings.get("player_input", ""))
	var expected_rounds: int = int(GameProgressManager.settings.get("expected_rounds", 0))
	var current_round: int = int(GameProgressManager.settings.get("current_round", 0))
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
	var http := HTTPRequest.new()
	http.timeout = BRAINSTORM_TIMEOUT
	add_child(http)
	var port: int = LLMSettingsManager.settings["port"]
	var url := "http://%s:%d%s" % [LLM_HOST, port, CHAT_ENDPOINT]
	var body := JSON.stringify({
		"messages": [{"role": "user", "content": prompt}],
		"stream": false,
		"thinking": false,
		"chat_template_kwargs": {
		    "enable_thinking": false
  		},
	})
	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if request_error != OK:
		http.queue_free()
		return {"success": false, "error": "Failed to send request"}
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		if result_code == HTTPRequest.RESULT_TIMEOUT:
			return {"success": false, "error": "Request timed out"}
		return {"success": false, "error": "Request failed"}
	var response_code: int = result[1]
	if response_code < 200 or response_code >= 300:
		return {"success": false, "error": "HTTP %d" % response_code}
	var response_body: PackedByteArray = result[3]
	var json := JSON.new()
	if json.parse(response_body.get_string_from_utf8()) != OK or json.data is not Dictionary:
		return {"success": false, "error": "Invalid response"}
	var choices: Array = json.data.get("choices", [])
	if choices.is_empty():
		return {"success": false, "error": "Empty response"}
	var message: Dictionary = choices[0].get("message", {})
	var content: String = message.get("content", "")
	if content.strip_edges().is_empty():
		return {"success": false, "error": "Empty content"}
	return {"success": true, "text": content}


func requestScene() -> void:
	pass


func requestStory() -> void:
	pass
