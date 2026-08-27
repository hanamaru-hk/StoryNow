extends CanvasLayer
## Lightweight always-on-top overlay showing LLM and Image server health.
##
## Updates reactively from ServerRuntimeManager signals; does not poll.

const COLOR_HEALTHY := Color(0.2, 0.8, 0.2)
const COLOR_UNHEALTHY := Color(0.8, 0.2, 0.2)
const COLOR_STARTING := Color(0.5, 0.5, 0.5)
const ROW_BG_LLM := Color(0.12, 0.18, 0.24, 0.88)
const ROW_BG_IMAGE := Color(0.24, 0.17, 0.1, 0.88)
const ROW_BG_SOUND := Color(0.15, 0.21, 0.14, 0.88)
const TimeoutCircle := preload("res://scripts/request_timeout_circle.gd")


func _ready() -> void:
	ServerRuntimeManager.llm_state_changed.connect(_on_llm_state_changed)
	ServerRuntimeManager.image_state_changed.connect(_on_image_state_changed)
	ServerRuntimeManager.chrome_visibility_changed.connect(_on_chrome_visibility_changed)
	ServerRuntimeManager.request_queue_changed.connect(_on_request_queue_changed)
	_apply_llm(ServerRuntimeManager.llm_state)
	_apply_image(ServerRuntimeManager.image_state)
	_on_chrome_visibility_changed(ServerRuntimeManager.chrome_visible)
	_on_request_queue_changed(ServerRuntimeManager.request_queue)
	_update_labels()


func _on_llm_state_changed(state: ServerRuntimeManager.ServerState) -> void:
	_apply_llm(state)


func _on_image_state_changed(state: ServerRuntimeManager.ServerState) -> void:
	_apply_image(state)


func _on_chrome_visibility_changed(is_visible: bool) -> void:
	visible = is_visible


func _on_request_queue_changed(queue: Array) -> void:
	for child in %QueueList.get_children():
		child.queue_free()

	%QueuePanel.visible = not queue.is_empty()
	for item in queue:
		if item is Dictionary:
			%QueueList.add_child(_make_queue_row(item as Dictionary))


func _apply_llm(state: ServerRuntimeManager.ServerState) -> void:
	%LLMDot.color = _color_for(state)


func _apply_image(state: ServerRuntimeManager.ServerState) -> void:
	%ImageDot.color = _color_for(state)


func _make_queue_row(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 34)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = _row_bg_for_kind(str(item.get("kind", "")))
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var label := Label.new()
	var label_text := str(item.get("label", "Request"))
	var tokens := int(item.get("tokens", 0))
	if tokens > 0:
		label_text = "%s (%d)" % [label_text, tokens]
	label.text = label_text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var status := Label.new()
	status.text = str(item.get("status", ""))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.custom_minimum_size = Vector2(86, 0)
	row.add_child(status)

	var circle := TimeoutCircle.new()
	circle.set_request_item(item)
	row.add_child(circle)

	var stream_text := str(item.get("stream_text", ""))
	if not stream_text.is_empty():
		var stream := RichTextLabel.new()
		stream.bbcode_enabled = false
		stream.fit_content = true
		stream.scroll_active = false
		stream.custom_minimum_size = Vector2(0, 22)
		stream.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stream.text = stream_text
		stack.add_child(stream)
	return panel


func _row_bg_for_kind(kind: String) -> Color:
	match kind:
		"image":
			return ROW_BG_IMAGE
		"sound":
			return ROW_BG_SOUND
		_:
			return ROW_BG_LLM


func _color_for(state: ServerRuntimeManager.ServerState) -> Color:
	match state:
		ServerRuntimeManager.ServerState.HEALTHY:
			return COLOR_HEALTHY
		ServerRuntimeManager.ServerState.UNHEALTHY:
			return COLOR_UNHEALTHY
		_:
			return COLOR_STARTING


func _update_labels() -> void:
	if has_node("%LLMLabel"):
		var t_llm: String = I18n.translate("server_llm")
		%LLMLabel.text = t_llm if t_llm != "server_llm" else "LLM"
	if has_node("%ImageLabel"):
		var t_img: String = I18n.translate("server_image")
		%ImageLabel.text = t_img if t_img != "server_image" else "Image"
