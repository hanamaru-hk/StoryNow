extends CanvasLayer
## Lightweight always-on-top overlay showing LLM and Image server health.
##
## Updates reactively from ServerRuntimeManager signals; does not poll.

const COLOR_HEALTHY := Color(0.2, 0.8, 0.2)
const COLOR_UNHEALTHY := Color(0.8, 0.2, 0.2)
const COLOR_STARTING := Color(0.5, 0.5, 0.5)


func _ready() -> void:
	ServerRuntimeManager.llm_state_changed.connect(_on_llm_state_changed)
	ServerRuntimeManager.image_state_changed.connect(_on_image_state_changed)
	ServerRuntimeManager.chrome_visibility_changed.connect(_on_chrome_visibility_changed)
	_apply_llm(ServerRuntimeManager.llm_state)
	_apply_image(ServerRuntimeManager.image_state)
	_on_chrome_visibility_changed(ServerRuntimeManager.chrome_visible)


func _on_llm_state_changed(state: ServerRuntimeManager.ServerState) -> void:
	_apply_llm(state)


func _on_image_state_changed(state: ServerRuntimeManager.ServerState) -> void:
	_apply_image(state)


func _on_chrome_visibility_changed(is_visible: bool) -> void:
	visible = is_visible


func _apply_llm(state: ServerRuntimeManager.ServerState) -> void:
	%LLMDot.color = _color_for(state)


func _apply_image(state: ServerRuntimeManager.ServerState) -> void:
	%ImageDot.color = _color_for(state)


func _color_for(state: ServerRuntimeManager.ServerState) -> Color:
	match state:
		ServerRuntimeManager.ServerState.HEALTHY:
			return COLOR_HEALTHY
		ServerRuntimeManager.ServerState.UNHEALTHY:
			return COLOR_UNHEALTHY
		_:
			return COLOR_STARTING
