extends Node
## Library functions for managing the ComfyUI (Image Server) process.

const STATUS_PATH := "user://image_server_status.json"
const COMFYUI_DIR := "server/ComfyUI"
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
	var exe_path := ProjectSettings.globalize_path("res://" + COMFYUI_DIR + "/run_nvidia_gpu.bat")
	if not FileAccess.file_exists(exe_path):
		push_error("ComfyUI launcher not found: " + exe_path)
		return
	var pid: int = OS.create_process(exe_path, [], true)
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
	var url := "http://127.0.0.1:" + str(port) + "/system_stats"
	var http := HTTPClient.new()
	var error := http.connect_to_host("127.0.0.1", port)
	if error != OK:
		_set_unhealthy()
		return false
	var timeout := HEALTH_TIMEOUT
	while http.get_status() == HTTPClient.STATUS_CONNECTING:
		http.poll()
		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		_set_unhealthy()
		return false
	error = http.request(HTTPClient.METHOD_GET, "/system_stats", PackedStringArray())
	if error != OK:
		http.close()
		_set_unhealthy()
		return false
	timeout = HEALTH_TIMEOUT
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false
	http.poll()
	var response_code := http.get_response_code()
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
