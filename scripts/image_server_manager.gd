extends Node
## Library functions for managing the ComfyUI (Image Server) process.

const STATUS_PATH := "user://image_server_status.json"
const COMFYUI_DIR := "server/ComfyUI/ComfyUI_windows_portable"
const HEALTH_TIMEOUT := 5.0

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
	var port: int = ImageServerSettingsManager.settings["port"]
	var base_path := ProjectSettings.globalize_path("res://" + COMFYUI_DIR)
	var exe_path := base_path + "/python_embeded/python.exe"
	if not FileAccess.file_exists(exe_path):
		push_error("ComfyUI Python not found: " + exe_path)
		return
	var args := PackedStringArray(["-s", base_path + "/ComfyUI/main.py", "--port", str(port), "--windows-standalone-build", "--disable-auto-launch"])
	var pid: int = OS.create_process(exe_path, args, OS.is_stdout_verbose())
	if pid < 0:
		push_error("Failed to start ComfyUI process")
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
	var port: int = ImageServerSettingsManager.settings["port"]
	var http := HTTPClient.new()

	var error := http.connect_to_host("127.0.0.1", port)
	if error != OK:
		_set_unhealthy()
		return false

	var timeout := HEALTH_TIMEOUT

	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false

	print_verbose("Connected")

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		print_verbose("Not connected")
		http.close()
		_set_unhealthy()
		return false

	print_verbose("Sending request")

	error = http.request(
		HTTPClient.METHOD_GET,
		"/system_stats",
		PackedStringArray()
	)

	if error != OK:
		print_verbose("Request failed: " + str(error))
		http.close()
		_set_unhealthy()
		return false

	timeout = HEALTH_TIMEOUT

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()

		print_verbose("Request status: " + str(http.get_status()))

		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			print_verbose("Request timeout")
			http.close()
			_set_unhealthy()
			return false

	print_verbose("Request finished, status: " + str(http.get_status()))

	if not http.has_response():
		print_verbose("No HTTP response")
		http.close()
		_set_unhealthy()
		return false

	var response_code := http.get_response_code()
	print_verbose("Response code: " + str(response_code))

	# Consume the response body.
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
