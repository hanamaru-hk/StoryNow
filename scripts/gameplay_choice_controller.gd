class_name GameplayChoiceController
extends RefCounted

var _host: Control


func _init(host: Control) -> void:
	_host = host


func resize_overlay_panel() -> void:
	var panel := _host.get_node_or_null("ChoiceOverlay/CenterContainer/Panel")
	if panel is Control:
		(panel as Control).custom_minimum_size = _host.get_viewport_rect().size * 0.7


func populate_buttons() -> void:
	var container := _node("DynamicChoiceButtons") as VBoxContainer
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var choices: Variant = SceneDataManager.scene_data.get("choices", [])
	if not choices is Array:
		return
	for choice_index in choices.size():
		var choice = choices[choice_index]
		var choice_text := _choice_text(choice)
		if choice_text.is_empty():
			continue
		var was_selected := choice is Dictionary and not str(choice.get("uuid", "")).strip_edges().is_empty()
		var display_text := choice_text
		if was_selected:
			display_text = "***** %s ***** %s" % [_translated("choice_previously_selected", "Previously selected this choice"), choice_text]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)
		var row_height := _choice_row_height(display_text)
		if was_selected:
			row.add_child(_make_selected_button(choice_text, row_height))
		else:
			var button := Button.new()
			button.text = display_text
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.custom_minimum_size = Vector2(0, row_height)
			button.pressed.connect(select_choice.bind(choice_text))
			row.add_child(button)

		var delete_button := Button.new()
		delete_button.text = _translated("btn_delete", "Delete")
		delete_button.custom_minimum_size = Vector2(88, row_height)
		delete_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		delete_button.pressed.connect(delete_choice.bind(choice_index))
		row.add_child(delete_button)


func select_choice(choice_text: String) -> void:
	var custom_input := _node("CustomInput") as TextEdit
	if custom_input:
		custom_input.text = choice_text
	confirm()


func delete_choice(choice_index: int) -> void:
	var raw_choices: Variant = SceneDataManager.scene_data.get("choices", [])
	if not raw_choices is Array:
		return
	var choices: Array = raw_choices
	if choice_index < 0 or choice_index >= choices.size():
		return
	choices.remove_at(choice_index)
	SceneDataManager.scene_data["choices"] = choices
	SceneDataManager.save()
	populate_buttons()


func show_overlay() -> void:
	var story_has_ended := bool(SceneDataManager.scene_data.get("end", false))
	var custom_input := _node("CustomInput") as TextEdit
	if custom_input:
		custom_input.text = ""
		custom_input.placeholder_text = _translated("choice_custom_placeholder", "Or write what you want to do...")
	var story_end_label := _node("StoryEndLabel") as Label
	if story_end_label:
		story_end_label.visible = story_has_ended
		story_end_label.text = I18n.translate("story_end_message")
	var choice_scroll := _node("ChoiceScroll") as Control
	if choice_scroll:
		choice_scroll.visible = not story_has_ended
	if story_has_ended:
		var container := _node("DynamicChoiceButtons")
		if container:
			for child in container.get_children():
				child.queue_free()
	else:
		populate_buttons()
	var overlay := _node("ChoiceOverlay") as Control
	if overlay:
		overlay.visible = true


func hide_overlay() -> void:
	var overlay := _node("ChoiceOverlay") as Control
	if overlay:
		overlay.visible = false
	var story_end_label := _node("StoryEndLabel") as Control
	if story_end_label:
		story_end_label.visible = false
	var choice_scroll := _node("ChoiceScroll") as Control
	if choice_scroll:
		choice_scroll.visible = true


func confirm() -> void:
	var custom_input := _node("CustomInput") as TextEdit
	var choice_text := custom_input.text.strip_edges() if custom_input else ""
	if choice_text.is_empty():
		return
	var current_round := int(GameProgressManager.settings.get("current_round", 1))
	var transition := GameplaySceneService.build_choice_transition(
		SceneDataManager.scene_data,
		choice_text,
		current_round,
		I18n.current_lang,
		GameplaySceneService.generate_uuid()
	)
	if not transition.get("success", false):
		return
	GameProgressManager.settings["current_round"] = int(transition["next_round"])
	GameProgressManager.settings["current_uuid"] = str(transition["target_uuid"])
	SceneDataManager.scene_data = transition["parent_scene"]
	SceneDataManager.save()
	if transition["reused"]:
		GameProgressManager.settings["game_status"] = "running"
	else:
		GameProgressManager.settings["game_status"] = "new_scene"
		GameProgressManager.settings["player_input"] = choice_text
		SceneDataManager.scene_data = transition["target_scene"]
		SceneDataManager.save()
	GameProgressManager.save_settings()
	_host.get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _make_selected_button(choice_text: String, row_height: float) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, row_height)
	panel.gui_input.connect(_on_selected_input.bind(choice_text))
	panel.mouse_entered.connect(_set_selected_hover.bind(panel, true))
	panel.mouse_exited.connect(_set_selected_hover.bind(panel, false))
	_set_selected_hover(panel, false)
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "[color=yellow]***** %s *****[/color] %s" % [
		_escape_bbcode(_translated("choice_previously_selected", "Previously selected this choice")),
		_escape_bbcode(choice_text),
	]
	panel.add_child(label)
	return panel


func _on_selected_input(event: InputEvent, choice_text: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_choice(choice_text)


func _set_selected_hover(panel: PanelContainer, is_hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.22, 1.0) if is_hovered else Color(0.13, 0.13, 0.13, 1.0)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)


func _choice_text(choice: Variant) -> String:
	if choice is Dictionary:
		return str(choice.get("plot", choice.get("text", choice.get("choice", "")))).strip_edges()
	return str(choice).strip_edges()


func _choice_row_height(text: String) -> float:
	return maxf(44.0, 24.0 + float(maxi(1, ceili(float(text.length()) / 30.0))) * 30.0)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _translated(key: String, fallback: String) -> String:
	var translated := I18n.translate(key)
	return fallback if translated == key else translated


func _node(unique_name: String) -> Node:
	return _host.get_node_or_null(NodePath("%%%s" % unique_name))
