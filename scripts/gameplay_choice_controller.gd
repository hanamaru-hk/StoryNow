class_name GameplayChoiceController
extends RefCounted

const ScrollbarStyleScript := preload("res://scripts/scrollbar_style.gd")

var _host: Control
var _pending_delete_index := -1


func _init(host: Control) -> void:
	_host = host


func resize_overlay_panel() -> void:
	var panel := _host.get_node_or_null("ChoiceOverlay/CenterContainer/Panel")
	if panel is Control:
		(panel as Control).custom_minimum_size = _host.get_viewport_rect().size * 0.7


func style_scrollbar() -> void:
	var choice_scroll := _node("ChoiceScroll") as ScrollContainer
	if choice_scroll:
		ScrollbarStyleScript.apply(choice_scroll)
	var delete_confirm := _node("ChoiceDeleteConfirm") as Button
	if delete_confirm and not delete_confirm.pressed.is_connected(_confirm_delete_choice):
		delete_confirm.pressed.connect(_confirm_delete_choice)
	var delete_cancel := _node("ChoiceDeleteCancel") as Button
	if delete_cancel and not delete_cancel.pressed.is_connected(_cancel_delete_choice):
		delete_cancel.pressed.connect(_cancel_delete_choice)
	_update_delete_confirmation_labels()
	_cancel_delete_choice()


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
			display_text = "***** %s *****\n%s" % [_translated("choice_previously_selected", "Previously selected this choice"), choice_text]

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
		delete_button.pressed.connect(_request_delete_choice.bind(choice_index, choice_text))
		row.add_child(delete_button)

		var scrollbar_gutter := Control.new()
		scrollbar_gutter.custom_minimum_size.x = ScrollbarStyleScript.WIDTH + 8.0
		row.add_child(scrollbar_gutter)


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


func _request_delete_choice(choice_index: int, choice_text: String) -> void:
	_pending_delete_index = choice_index
	var message := _node("ChoiceDeleteConfirmMessage") as Label
	if message:
		var template := _translated("choice_delete_confirm", "Delete this choice?\n%s")
		message.text = template % choice_text
	var popup := _node("ChoiceDeleteConfirmPopup") as Control
	if popup:
		popup.visible = true


func _confirm_delete_choice() -> void:
	var choice_index := _pending_delete_index
	_cancel_delete_choice()
	if choice_index >= 0:
		delete_choice(choice_index)


func _cancel_delete_choice() -> void:
	_pending_delete_index = -1
	var popup := _node("ChoiceDeleteConfirmPopup") as Control
	if popup:
		popup.visible = false


func _update_delete_confirmation_labels() -> void:
	var title := _node("ChoiceDeleteConfirmTitle") as Label
	if title:
		title.text = _translated("confirm_dialog_title", "Confirm")
	var confirm_button := _node("ChoiceDeleteConfirm") as Button
	if confirm_button:
		confirm_button.text = _translated("btn_confirm", "Confirm")
	var cancel_button := _node("ChoiceDeleteCancel") as Button
	if cancel_button:
		cancel_button.text = _translated("btn_cancel", "Cancel")


func show_overlay() -> void:
	_cancel_delete_choice()
	_update_delete_confirmation_labels()
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
	_cancel_delete_choice()
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


func _make_selected_button(choice_text: String, row_height: float) -> Button:
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, row_height)
	button.pressed.connect(select_choice.bind(choice_text))
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14.0
	label.offset_top = 8.0
	label.offset_right = -14.0
	label.offset_bottom = -8.0
	var button_text_color := _host.get_theme_color("font_color", "Button").to_html(false)
	label.text = "[center][color=#806000]***** %s *****[/color]\n[color=#%s]%s[/color][/center]" % [
		_escape_bbcode(_translated("choice_previously_selected", "Previously selected this choice")),
		button_text_color,
		_escape_bbcode(choice_text),
	]
	return button


func _choice_text(choice: Variant) -> String:
	if choice is Dictionary:
		return str(choice.get("plot", choice.get("text", choice.get("choice", "")))).strip_edges()
	return str(choice).strip_edges()


func _choice_row_height(text: String) -> float:
	var choice_scroll := _node("ChoiceScroll") as ScrollContainer
	var text_width := choice_scroll.size.x if choice_scroll else 0.0
	if text_width <= 0.0:
		text_width = _host.get_viewport_rect().size.x * 0.7 - 72.0
	text_width = maxf(120.0, text_width - 88.0 - ScrollbarStyleScript.WIDTH - 24.0)
	var font := _host.get_theme_font("font", "Button")
	var font_size := _host.get_theme_font_size("font_size", "Button")
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size)
	return maxf(44.0, ceilf(text_size.y) + 16.0)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _translated(key: String, fallback: String) -> String:
	var translated := I18n.translate(key)
	return fallback if translated == key else translated


func _node(unique_name: String) -> Node:
	return _host.get_node_or_null(NodePath("%%%s" % unique_name))
