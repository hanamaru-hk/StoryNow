extends Node
## App-wide coordinator for Ollama and ComfyUI server lifecycle.
##
## Reconciles stale persisted state on startup, starts both servers,
## runs periodic health checks, and shuts down owned processes on exit.

enum ServerState { STARTING, HEALTHY, UNHEALTHY }

signal llm_state_changed(state: ServerState)
signal image_state_changed(state: ServerState)

const HEARTBEAT_INTERVAL := 15.0
const INITIAL_CHECK_DELAY := 2.0

var llm_state := ServerState.STARTING
var image_state := ServerState.STARTING

var _heartbeat_timer: Timer
var _llm_started_this_session := false
var _image_started_this_session := false


func _ready() -> void:
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
	_heartbeat_timer.autostart = true
	_heartbeat_timer.timeout.connect(_on_heartbeat)
	add_child(_heartbeat_timer)

	var initial_timer := Timer.new()
	initial_timer.wait_time = INITIAL_CHECK_DELAY
	initial_timer.one_shot = true
	initial_timer.timeout.connect(_on_heartbeat)
	add_child(initial_timer)
	initial_timer.start()


func _add_overlay() -> void:
	var overlay := preload("res://scenes/server_status_overlay.tscn").instantiate()
	get_tree().root.add_child(overlay)


func _on_heartbeat() -> void:
	var llm_healthy := LLMManager.health_check()
	var image_healthy := ImageServerManager.health_check()

	var new_llm := ServerState.HEALTHY if llm_healthy else ServerState.UNHEALTHY
	var new_image := ServerState.HEALTHY if image_healthy else ServerState.UNHEALTHY

	if new_llm != llm_state:
		llm_state = new_llm
		llm_state_changed.emit(llm_state)
	if new_image != image_state:
		image_state = new_image
		image_state_changed.emit(image_state)


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
