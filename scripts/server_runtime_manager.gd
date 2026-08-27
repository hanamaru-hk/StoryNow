extends Node
## App-wide coordinator for Ollama and ComfyUI server lifecycle.
##
## Reconciles stale persisted state on startup, starts both servers,
## runs periodic health checks, and shuts down owned processes on exit.

enum ServerState { STARTING, HEALTHY, UNHEALTHY }

signal llm_state_changed(state: ServerState)
signal image_state_changed(state: ServerState)
signal chrome_visibility_changed(is_visible: bool)
signal request_queue_changed(queue: Array)

const HEARTBEAT_INTERVAL := 8.0
const INITIAL_CHECK_DELAY := 2.0

var llm_state := ServerState.STARTING
var image_state := ServerState.STARTING
var chrome_visible := true
var request_queue: Array[Dictionary] = []

var _heartbeat_timer: Timer
var _llm_started_this_session := false
var _image_started_this_session := false
var _next_request_id := 1


func _ready() -> void:
	if not FileAccess.file_exists("user://game_progress.json"):
		var src_progress := AppPaths.external_path("data/default_game_progress.json")
		if not FileAccess.file_exists(src_progress):
			src_progress = AppPaths.external_path("data/default_game_progess.json")
		if FileAccess.file_exists(src_progress):
			var src_file := FileAccess.open(src_progress, FileAccess.READ)
			if src_file:
				var content := src_file.get_as_text()
				src_file.close()
				var dst_file := FileAccess.open("user://game_progress.json", FileAccess.WRITE)
				if dst_file:
					dst_file.store_string(content)
					dst_file.close()
	if not FileAccess.file_exists("user://game_settings.json"):
		var src_settings := AppPaths.external_path("data/default_game_settings.json")
		if FileAccess.file_exists(src_settings):
			var src_file2 := FileAccess.open(src_settings, FileAccess.READ)
			if src_file2:
				var content2 := src_file2.get_as_text()
				src_file2.close()
				var dst_file2 := FileAccess.open("user://game_settings.json", FileAccess.WRITE)
				if dst_file2:
					dst_file2.store_string(content2)
					dst_file2.close()
	LLMManager.status_changed.connect(_on_llm_status_changed)
	ImageServerManager.status_changed.connect(_on_image_status_changed)
	_reconcile_stale_state()
	_start_servers()
	_start_heartbeat()
	call_deferred("_add_overlay")


func _reconcile_stale_state() -> void:
	LLMManager.status["pid"] = -1
	LLMManager.status["running"] = false
	LLMManager.status["healthy"] = false
	LLMManager.save_status()
	ImageServerManager.status["pid"] = -1
	ImageServerManager.status["running"] = false
	ImageServerManager.status["healthy"] = false
	ImageServerManager.save_status()


func _start_servers() -> void:
	LLMManager.start_server()
	_llm_started_this_session = LLMManager.status["running"]
	ImageServerManager.start_server()
	_image_started_this_session = ImageServerManager.status["running"]


func _start_heartbeat() -> void:
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.timeout.connect(_on_heartbeat)
	add_child(_heartbeat_timer)
	_heartbeat_timer.start()

	var initial_timer := Timer.new()
	initial_timer.wait_time = INITIAL_CHECK_DELAY
	initial_timer.one_shot = true
	initial_timer.timeout.connect(_on_heartbeat)
	add_child(initial_timer)
	initial_timer.start()


func _add_overlay() -> void:
	var overlay_scene := load("res://scenes/server_status_overlay.tscn") as PackedScene
	if overlay_scene == null:
		return
	var overlay: Node = overlay_scene.instantiate()
	get_tree().root.add_child(overlay)


func _on_heartbeat() -> void:
	LLMManager.health_check()
	ImageServerManager.health_check()


func _on_llm_status_changed(status: Dictionary) -> void:
	_set_llm_state(ServerState.HEALTHY if status.get("healthy", false) else ServerState.UNHEALTHY)


func _on_image_status_changed(status: Dictionary) -> void:
	_set_image_state(ServerState.HEALTHY if status.get("healthy", false) else ServerState.UNHEALTHY)


func _set_llm_state(new_state: ServerState) -> void:
	if new_state != llm_state:
		llm_state = new_state
		llm_state_changed.emit(llm_state)


func _set_image_state(new_state: ServerState) -> void:
	if new_state != image_state:
		image_state = new_state
		image_state_changed.emit(image_state)


func set_chrome_visible(is_visible: bool) -> void:
	if chrome_visible == is_visible:
		return
	chrome_visible = is_visible
	chrome_visibility_changed.emit(chrome_visible)


func push_request(kind: String, label: String, timeout_seconds: float) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	request_queue.append({
		"id": request_id,
		"kind": kind,
		"label": label,
		"timeout_seconds": timeout_seconds,
		"started_at_msec": Time.get_ticks_msec(),
	})
	request_queue_changed.emit(request_queue.duplicate(true))
	return request_id


func pop_request(request_id: int) -> void:
	for index in range(request_queue.size()):
		var item: Dictionary = request_queue[index]
		if int(item.get("id", -1)) == request_id:
			request_queue.remove_at(index)
			request_queue_changed.emit(request_queue.duplicate(true))
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _exit_tree() -> void:
	if _llm_started_this_session:
		LLMManager.stop_server()
		_llm_started_this_session = false
	if _image_started_this_session:
		ImageServerManager.stop_server()
		_image_started_this_session = false
