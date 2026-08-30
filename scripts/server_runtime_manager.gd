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
signal engine_status_hint_changed(is_visible: bool)
signal engine_status_hint_emphasis_requested

const HEARTBEAT_NOT_CONNECTED_INTERVAL := 2.0
const HEARTBEAT_CONNECTED_INTERVAL := 10.0
const INITIAL_CHECK_DELAY := 2.0

var llm_state := ServerState.STARTING
var image_state := ServerState.STARTING
var chrome_visible := true
var engine_status_hint_visible := false
var engine_status_hint_emphasized := false
var request_queue: Array[Dictionary] = []

var _heartbeat_timer: Timer
var _llm_started_this_session := false
var _image_started_this_session := false
var _next_request_id := 1
var _is_shutting_down := false


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
	if not FileAccess.file_exists("user://llm_settings.json"):
		var src_llm := AppPaths.external_path("data/default_llm_settings.json")
		if FileAccess.file_exists(src_llm):
			var src_file3 := FileAccess.open(src_llm, FileAccess.READ)
			if src_file3:
				var content3 := src_file3.get_as_text()
				src_file3.close()
				var dst_file3 := FileAccess.open("user://llm_settings.json", FileAccess.WRITE)
				if dst_file3:
					dst_file3.store_string(content3)
					dst_file3.close()
	if not FileAccess.file_exists("user://image_server_settings.json"):
		var src_image := AppPaths.external_path("data/default_image_server_settings.json")
		if FileAccess.file_exists(src_image):
			var src_file4 := FileAccess.open(src_image, FileAccess.READ)
			if src_file4:
				var content4 := src_file4.get_as_text()
				src_file4.close()
				var dst_file4 := FileAccess.open("user://image_server_settings.json", FileAccess.WRITE)
				if dst_file4:
					dst_file4.store_string(content4)
					dst_file4.close()
	# Ensure managers reload in case they initialized before the copy.
	if FileAccess.file_exists("user://llm_settings.json"):
		LLMSettingsManager.load_settings()
	if FileAccess.file_exists("user://image_server_settings.json"):
		ImageServerSettingsManager.load_settings()
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
	_heartbeat_timer.wait_time = _get_heartbeat_interval()
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
	_update_heartbeat_interval()


func _on_llm_status_changed(status: Dictionary) -> void:
	_set_llm_state(ServerState.HEALTHY if status.get("healthy", false) else ServerState.UNHEALTHY)


func _on_image_status_changed(status: Dictionary) -> void:
	_set_image_state(ServerState.HEALTHY if status.get("healthy", false) else ServerState.UNHEALTHY)


func _set_llm_state(new_state: ServerState) -> void:
	if new_state != llm_state:
		llm_state = new_state
		llm_state_changed.emit(llm_state)
		_update_heartbeat_interval()


func _set_image_state(new_state: ServerState) -> void:
	if new_state != image_state:
		image_state = new_state
		image_state_changed.emit(image_state)
		_update_heartbeat_interval()


func _get_heartbeat_interval() -> float:
	return HEARTBEAT_CONNECTED_INTERVAL if llm_state == ServerState.HEALTHY and image_state == ServerState.HEALTHY else HEARTBEAT_NOT_CONNECTED_INTERVAL


func _update_heartbeat_interval() -> void:
	if _is_shutting_down or not is_inside_tree():
		return
	if _heartbeat_timer == null or not _heartbeat_timer.is_inside_tree():
		return
	var next_interval := _get_heartbeat_interval()
	if is_equal_approx(_heartbeat_timer.wait_time, next_interval):
		return
	_heartbeat_timer.wait_time = next_interval
	_heartbeat_timer.start()


func set_chrome_visible(is_visible: bool) -> void:
	if chrome_visible == is_visible:
		return
	chrome_visible = is_visible
	chrome_visibility_changed.emit(chrome_visible)


func set_engine_status_hint_visible(is_visible: bool) -> void:
	if engine_status_hint_visible == is_visible:
		return
	engine_status_hint_visible = is_visible
	engine_status_hint_emphasized = false
	engine_status_hint_changed.emit(engine_status_hint_visible)


func emphasize_engine_status_hint() -> void:
	if not engine_status_hint_visible:
		return
	engine_status_hint_emphasized = true
	engine_status_hint_emphasis_requested.emit()


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


func update_request(request_id: int, patch: Dictionary) -> void:
	for index in range(request_queue.size()):
		var item: Dictionary = request_queue[index]
		if int(item.get("id", -1)) == request_id:
			for key in patch.keys():
				item[key] = patch[key]
			request_queue[index] = item
			request_queue_changed.emit(request_queue.duplicate(true))
			return


func clear_requests_by_kinds(kinds: Array[String]) -> void:
	var changed := false
	for index in range(request_queue.size() - 1, -1, -1):
		var item: Dictionary = request_queue[index]
		if kinds.has(str(item.get("kind", ""))):
			request_queue.remove_at(index)
			changed = true
	if changed:
		request_queue_changed.emit(request_queue.duplicate(true))


func has_generation_requests() -> bool:
	for item in request_queue:
		var kind := str(item.get("kind", ""))
		if kind == "llm" or kind == "image" or kind == "sound":
			return true
	return false


func cancel_active_generation_tasks() -> void:
	LLMManager.cancel_active_request()
	await ImageServerManager.interrupt_active_generation()
	TTSManager.cancel_generation()
	clear_requests_by_kinds(["llm", "image", "sound"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _exit_tree() -> void:
	_is_shutting_down = true
	if LLMManager.status_changed.is_connected(_on_llm_status_changed):
		LLMManager.status_changed.disconnect(_on_llm_status_changed)
	if ImageServerManager.status_changed.is_connected(_on_image_status_changed):
		ImageServerManager.status_changed.disconnect(_on_image_status_changed)
	if _llm_started_this_session:
		LLMManager.stop_server()
		_llm_started_this_session = false
	if _image_started_this_session:
		ImageServerManager.stop_server()
		_image_started_this_session = false
