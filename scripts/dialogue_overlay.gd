extends Control

signal closed
signal dialogue_updated

const TRIM_LEN := 20

var _editing_index: int = -1

func _ready() -> void:
	if has_node("%DialogueBack"):
		%DialogueBack.pressed.connect(_on_hub_back_pressed)
	if has_node("%HubEditButton"):
		%HubEditButton.pressed.connect(_on_hub_edit_pressed)
	if has_node("%HubAddButton"):
		%HubAddButton.pressed.connect(_on_hub_add_pressed)
	if has_node("%EditOverlayBack"):
		%EditOverlayBack.pressed.connect(_on_edit_overlay_back_pressed)
	if has_node("%AddOverlayBack"):
		%AddOverlayBack.pressed.connect(_on_add_overlay_back_pressed)
	if has_node("%DialogueConfirm"):
		%DialogueConfirm.pressed.connect(_on_confirm_pressed)
	if has_node("%EditBack"):
		%EditBack.pressed.connect(_on_edit_back_pressed)
	if has_node("%EditSave"):
		%EditSave.pressed.connect(_on_edit_save_pressed)
	visible = false
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	if has_node("%EditDialog"):
		%EditDialog.visible = false
	_update_labels()


func open() -> void:
	visible = true
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	if has_node("%EditDialog"):
		%EditDialog.visible = false
	_editing_index = -1
	_update_labels()


func _refresh_all() -> void:
	_refresh_list()
	_refresh_dropdown()


func _get_interactions() -> Array:
	var arr = SceneDataManager.scene_data.get("interactions", [])
	if arr is Array:
		return arr
	return []


func _trim_text(text: String) -> String:
	var t := text.strip_edges()
	if t.length() > TRIM_LEN:
		return t.substr(0, TRIM_LEN) + "..."
	return t


func _format_entry(entry: Dictionary) -> String:
	var character_name: String = str(entry.get("character", entry.get("characer", ""))).strip_edges()
	var dialogue_text: String = str(entry.get("dialogue", "")).strip_edges()
	var trimmed := _trim_text(dialogue_text)
	if trimmed.is_empty():
		trimmed = "..."
	if not character_name.is_empty():
		return "%s: %s" % [character_name, trimmed]
	return trimmed


func _refresh_list() -> void:
	if not has_node("%DialogueList"):
		return
	var container: VBoxContainer = %DialogueList
	for child in container.get_children():
		child.queue_free()
	var interactions: Array = _get_interactions()
	if interactions.is_empty():
		var label := Label.new()
		label.text = I18n.translate("dialogue_overlay_empty") if I18n.translate("dialogue_overlay_empty") != "dialogue_overlay_empty" else "No dialogues"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(label)
		return
	for i in interactions.size():
		var entry = interactions[i]
		var dict: Dictionary = entry if entry is Dictionary else {}
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, _format_entry(dict)]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_item_pressed.bind(i))
		container.add_child(btn)


func _refresh_dropdown() -> void:
	if not has_node("%DialogueDropdown"):
		return
	var dropdown: OptionButton = %DialogueDropdown
	dropdown.clear()
	var interactions: Array = _get_interactions()
	if interactions.is_empty():
		dropdown.add_item(I18n.translate("dialogue_overlay_no_items") if I18n.translate("dialogue_overlay_no_items") != "dialogue_overlay_no_items" else "No dialogues")
		dropdown.disabled = true
		if has_node("%DialogueConfirm"):
			%DialogueConfirm.disabled = true
		return
	dropdown.disabled = false
	if has_node("%DialogueConfirm"):
		%DialogueConfirm.disabled = false
	for i in interactions.size():
		var entry = interactions[i]
		var dict: Dictionary = entry if entry is Dictionary else {}
		var label_text := "%d. %s" % [i + 1, _format_entry(dict)]
		dropdown.add_item(label_text, i)
	# select last by default
	dropdown.selected = dropdown.item_count - 1


# --- Hub ---
func _on_hub_edit_pressed() -> void:
	if has_node("%EditOverlay"):
		%EditOverlay.visible = true
		_refresh_list()
		_update_labels()
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	if has_node("%EditDialog"):
		%EditDialog.visible = false
	_editing_index = -1


func _on_hub_add_pressed() -> void:
	if has_node("%AddOverlay"):
		%AddOverlay.visible = true
		_refresh_dropdown()
		_update_labels()
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%EditDialog"):
		%EditDialog.visible = false


func _on_hub_back_pressed() -> void:
	# Hub back closes the whole dialogue overlay (unless a sub-overlay is open, close it first)
	if has_node("%EditDialog") and %EditDialog.visible:
		%EditDialog.visible = false
		_editing_index = -1
		return
	if has_node("%EditOverlay") and %EditOverlay.visible:
		%EditOverlay.visible = false
		return
	if has_node("%AddOverlay") and %AddOverlay.visible:
		%AddOverlay.visible = false
		return
	visible = false
	closed.emit()


func _on_edit_overlay_back_pressed() -> void:
	if has_node("%EditDialog") and %EditDialog.visible:
		%EditDialog.visible = false
		_editing_index = -1
		return
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false


func _on_add_overlay_back_pressed() -> void:
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false


func _on_item_pressed(index: int) -> void:
	var interactions: Array = _get_interactions()
	if index < 0 or index >= interactions.size():
		return
	_editing_index = index
	var entry = interactions[index]
	var dict: Dictionary = entry if entry is Dictionary else {}
	var character_name: String = str(dict.get("character", dict.get("characer", "")))
	var dialogue_text: String = str(dict.get("dialogue", ""))
	if has_node("%EditCharacter"):
		%EditCharacter.text = character_name
	if has_node("%EditDialogue"):
		%EditDialogue.text = dialogue_text
	if has_node("%EditDialog"):
		%EditDialog.visible = true
	_update_labels()


func _on_edit_back_pressed() -> void:
	if has_node("%EditDialog"):
		%EditDialog.visible = false
	_editing_index = -1


func _on_edit_save_pressed() -> void:
	if _editing_index < 0:
		return
	var interactions: Array = _get_interactions()
	if _editing_index < 0 or _editing_index >= interactions.size():
		return
	var character_text: String = %EditCharacter.text.strip_edges() if has_node("%EditCharacter") and %EditCharacter.text != null else ""
	var dialogue_text: String = %EditDialogue.text if has_node("%EditDialogue") and %EditDialogue.text != null else ""
	var entry = interactions[_editing_index]
	var dict: Dictionary = entry if entry is Dictionary else {}
	dict["character"] = character_text
	if dict.has("characer"):
		dict.erase("characer")
	dict["dialogue"] = dialogue_text
	if not dict.has("sex"):
		dict["sex"] = "male"
	interactions[_editing_index] = dict
	SceneDataManager.scene_data["interactions"] = interactions
	SceneDataManager.save()
	if has_node("%EditDialog"):
		%EditDialog.visible = false
	_editing_index = -1
	_refresh_list()
	_refresh_dropdown()
	dialogue_updated.emit()


func _on_confirm_pressed() -> void:
	var interactions: Array = _get_interactions()
	var selected_idx: int = -1
	if has_node("%DialogueDropdown"):
		var dropdown: OptionButton = %DialogueDropdown
		if dropdown.item_count == 0 or dropdown.disabled:
			selected_idx = -1
		else:
			var sel: int = dropdown.selected
			if sel >= 0 and sel < dropdown.item_count:
				selected_idx = dropdown.get_item_id(sel)
			else:
				selected_idx = interactions.size() - 1
	var add_before: bool = false
	if has_node("%AddBeforeRadio"):
		add_before = %AddBeforeRadio.button_pressed

	var insert_at: int
	if interactions.is_empty():
		insert_at = 0
	elif selected_idx < 0:
		insert_at = interactions.size()
	else:
		if add_before:
			insert_at = selected_idx
		else:
			insert_at = selected_idx + 1
		insert_at = clampi(insert_at, 0, interactions.size())

	var new_entry: Dictionary = {
		"character": "",
		"dialogue": "New dialogue",
		"sex": "male"
	}
	interactions.insert(insert_at, new_entry)
	SceneDataManager.scene_data["interactions"] = interactions
	SceneDataManager.save()
	_refresh_list()
	_refresh_dropdown()
	if has_node("%DialogueDropdown"):
		var dropdown2: OptionButton = %DialogueDropdown
		for i in dropdown2.item_count:
			if dropdown2.get_item_id(i) == insert_at:
				dropdown2.selected = i
				break
	dialogue_updated.emit()


func _on_back_pressed() -> void:
	# Legacy - delegate to hub back
	_on_hub_back_pressed()


func _update_labels() -> void:
	if has_node("%Title"):
		%Title.text = I18n.translate("dialogue_overlay_title") if I18n.translate("dialogue_overlay_title") != "dialogue_overlay_title" else "Dialogues"
	if has_node("%HubEditButton"):
		%HubEditButton.text = I18n.translate("dialogue_hub_edit") if I18n.translate("dialogue_hub_edit") != "dialogue_hub_edit" else "Edit"
	if has_node("%HubAddButton"):
		%HubAddButton.text = I18n.translate("dialogue_hub_add") if I18n.translate("dialogue_hub_add") != "dialogue_hub_add" else "Add"
	if has_node("%DialogueBack"):
		%DialogueBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%EditOverlayTitle"):
		%EditOverlayTitle.text = I18n.translate("dialogue_edit_list_title") if I18n.translate("dialogue_edit_list_title") != "dialogue_edit_list_title" else "Edit Dialogues"
	if has_node("%EditOverlayBack"):
		%EditOverlayBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%AddOverlayTitle"):
		%AddOverlayTitle.text = I18n.translate("dialogue_add_title") if I18n.translate("dialogue_add_title") != "dialogue_add_title" else "Add Dialogue"
	if has_node("%AddOverlayBack"):
		%AddOverlayBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%AddBeforeRadio"):
		%AddBeforeRadio.text = I18n.translate("dialogue_add_before") if I18n.translate("dialogue_add_before") != "dialogue_add_before" else "Add before"
	if has_node("%AddAfterRadio"):
		%AddAfterRadio.text = I18n.translate("dialogue_add_after") if I18n.translate("dialogue_add_after") != "dialogue_add_after" else "Add after"
	if has_node("%DialogueConfirm"):
		%DialogueConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	if has_node("%EditTitle"):
		%EditTitle.text = I18n.translate("dialogue_edit_title") if I18n.translate("dialogue_edit_title") != "dialogue_edit_title" else "Edit Dialogue"
	if has_node("%EditCharacter"):
		%EditCharacter.placeholder_text = I18n.translate("dialogue_character_placeholder") if I18n.translate("dialogue_character_placeholder") != "dialogue_character_placeholder" else "Character"
	if has_node("%EditDialogue"):
		%EditDialogue.placeholder_text = I18n.translate("dialogue_text_placeholder") if I18n.translate("dialogue_text_placeholder") != "dialogue_text_placeholder" else "Dialogue..."
	if has_node("%EditBack"):
		%EditBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%EditSave"):
		%EditSave.text = I18n.translate("btn_save") if I18n.translate("btn_save") != "btn_save" else "Save"
