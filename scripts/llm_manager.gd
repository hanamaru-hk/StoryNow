extends Node
## Library functions for managing the Ollama (LLM) server process.

const STATUS_PATH := "user://llm_status.json"
const OLLAMA_DIR := "server/llama"
const HEALTH_TIMEOUT := 5.0
const BRAINSTORM_TIMEOUT := 120.0
const LLM_HOST := "127.0.0.1"
const CHAT_ENDPOINT := "/v1/chat/completions"
const PROMPT_DIR := "res://data/llm"
const PROMPT_RANDOM := "prompt-random"
const PROMPT_ENHANCE := "prompt-enhance"
const PROMPT_REQUIREMENTS := "prompt-text-requirement"

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
	var exe_path := ProjectSettings.globalize_path("res://" + OLLAMA_DIR + "/llama-server.exe")
	var model_path := ProjectSettings.globalize_path("res://" + OLLAMA_DIR + "/models/unsloth__Qwen3.5-9B-UD-Q3_K_XL.gguf")
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


func brainstorm(input: String) -> Dictionary:
	var prompt_file := PROMPT_RANDOM if input.strip_edges().is_empty() else PROMPT_ENHANCE
	var prompt := _load_prompt(prompt_file)
	if prompt.is_empty():
		return {"success": false, "error": "Failed to load prompt template"}
	var requirements := _load_prompt(PROMPT_REQUIREMENTS)
	if requirements.is_empty():
		return {"success": false, "error": "Failed to load requirements template"}
	prompt = prompt.replace("__REQUIREMENTS__", requirements)
	if prompt_file == PROMPT_ENHANCE:
		prompt = prompt.replace("__USER_INPUT__", input)
	return await _request_completion(prompt)


func _load_prompt(file_name: String) -> String:
	var path := "%s/%s/%s" % [PROMPT_DIR, I18n.current_lang, file_name]
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


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
