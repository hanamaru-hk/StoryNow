extends Control

signal closed
signal dialogue_updated
signal summary_requested

const TRIM_LEN := 20
const SEX_MALE_ID := 0
const SEX_FEMALE_ID := 1
const SEX_OTHER_ID := 2

var _editing_index: int = -1
var _is_regenerating: bool = false

func _ready() -> void:
	if has_node("%DialogueBack"):
		%DialogueBack.pressed.connect(_on_hub_back_pressed)
	if has_node("%HubEditButton"):
		%HubEditButton.pressed.connect(_on_hub_edit_pressed)
	if has_node("%HubAddButton"):
		%HubAddButton.pressed.connect(_on_hub_add_pressed)
	if has_node("%RegenerateAllButton"):
		%RegenerateAllButton.pressed.connect(_on_regenerate_all_pressed)
	if has_node("%SummaryButton"):
		%SummaryButton.pressed.connect(_on_summary_pressed)
	if has_node("%RegenerateCancel"):
		%RegenerateCancel.pressed.connect(_on_regenerate_cancel_pressed)
	if has_node("%RegenerateConfirm"):
		%RegenerateConfirm.pressed.connect(_on_regenerate_confirm_pressed)
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
	if has_node("%EditDelete"):
		%EditDelete.pressed.connect(_on_edit_delete_pressed)
	if has_node("%SexDropdown"):
		%SexDropdown.item_selected.connect(_on_sex_selected)
	if has_node("%AddSexDropdown"):
		%AddSexDropdown.item_selected.connect(_on_add_sex_selected)
	visible = false
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	if has_node("%RegenerateConfirmPopup"):
		%RegenerateConfirmPopup.visible = false
	_update_labels()


func open() -> void:
	visible = true
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	if has_node("%RegenerateConfirmPopup"):
		%RegenerateConfirmPopup.visible = false
	_editing_index = -1
	_update_labels()
	_update_regenerate_button_state()


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
		label.text = I18n.translate("plot_overlay_empty") if I18n.translate("plot_overlay_empty") != "plot_overlay_empty" else "No dialogues"
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
		dropdown.add_item(I18n.translate("plot_overlay_no_items") if I18n.translate("plot_overlay_no_items") != "plot_overlay_no_items" else "No dialogues")
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
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	_editing_index = -1


func _on_hub_add_pressed() -> void:
	if has_node("%AddOverlay"):
		%AddOverlay.visible = true
		_refresh_dropdown()
		_update_labels()
		_reset_add_fields()
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%EditPopup"):
		%EditPopup.visible = false


func _on_summary_pressed() -> void:
	visible = false
	summary_requested.emit()


func _on_hub_back_pressed() -> void:
	# Hub back closes the whole dialogue overlay (unless a sub-overlay is open, close it first)
	if has_node("%RegenerateConfirmPopup") and %RegenerateConfirmPopup.visible:
		%RegenerateConfirmPopup.visible = false
		return
	if has_node("%EditPopup") and %EditPopup.visible:
		%EditPopup.visible = false
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


func _on_regenerate_all_pressed() -> void:
	if _is_regenerating:
		return
	if has_node("%RegenerateConfirmPopup"):
		%RegenerateConfirmPopup.visible = true
	_update_labels()


func _on_regenerate_cancel_pressed() -> void:
	if has_node("%RegenerateConfirmPopup"):
		%RegenerateConfirmPopup.visible = false


func _on_regenerate_confirm_pressed() -> void:
	if has_node("%RegenerateConfirmPopup"):
		%RegenerateConfirmPopup.visible = false
	visible = false
	closed.emit()
	await _execute_regenerate_all()


func _get_current_round() -> int:
	var from_scene = SceneDataManager.scene_data.get("current_round", null)
	var from_progress = GameProgressManager.settings.get("current_round", 1)
	var val: int
	if from_scene != null:
		val = int(from_scene)
	else:
		val = int(from_progress)
	if val < 1:
		val = 1
	return val


func _update_regenerate_button_state() -> void:
	var disabled := _is_regenerating
	if has_node("%RegenerateAllButton"):
		%RegenerateAllButton.disabled = disabled
		if _is_regenerating:
			%RegenerateAllButton.text = I18n.translate("dialogue_regenerating") if I18n.translate("dialogue_regenerating") != "dialogue_regenerating" else "Regenerating..."
		else:
			%RegenerateAllButton.text = I18n.translate("dialogue_hub_regenerate") if I18n.translate("dialogue_hub_regenerate") != "dialogue_hub_regenerate" else "Regenerate Scene"
	if has_node("%HubEditButton"):
		%HubEditButton.disabled = disabled
	if has_node("%HubAddButton"):
		%HubAddButton.disabled = disabled
	if has_node("%SummaryButton"):
		%SummaryButton.disabled = disabled
	if has_node("%DialogueBack"):
		%DialogueBack.disabled = disabled


func _execute_regenerate_all() -> void:
	if _is_regenerating:
		return
	_is_regenerating = true
	_update_regenerate_button_state()
	var gameplay := get_parent()
	if gameplay == null or not gameplay.has_method("regenerate_current_scene"):
		push_error("PlotOverlay requires a gameplay parent with regenerate_current_scene()")
		_is_regenerating = false
		_update_regenerate_button_state()
		return
	await gameplay.call("regenerate_current_scene", _get_current_round())
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_refresh_list()
	_refresh_dropdown()
	dialogue_updated.emit()
	_is_regenerating = false
	_update_regenerate_button_state()
	_update_labels()


func _on_edit_overlay_back_pressed() -> void:
	if has_node("%EditPopup") and %EditPopup.visible:
		%EditPopup.visible = false
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
	var sex: String = str(dict.get("sex", "male")).strip_edges()
	if has_node("%EditCharacter"):
		%EditCharacter.text = character_name
	if has_node("%EditDialogue"):
		%EditDialogue.text = dialogue_text
	_set_sex_editor_value(sex)
	if has_node("%EditPopup"):
		%EditPopup.visible = true
	_update_labels()


func _on_edit_back_pressed() -> void:
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	_editing_index = -1


func _set_sex_editor_value(sex: String) -> void:
	if not has_node("%SexDropdown"):
		return
	var normalized := sex.to_lower()
	var selected_id := SEX_OTHER_ID
	if normalized == "male":
		selected_id = SEX_MALE_ID
	elif normalized == "female":
		selected_id = SEX_FEMALE_ID
	for i in %SexDropdown.item_count:
		if %SexDropdown.get_item_id(i) == selected_id:
			%SexDropdown.selected = i
			break
	if has_node("%CustomSexInput"):
		%CustomSexInput.text = sex if selected_id == SEX_OTHER_ID else ""
		%CustomSexInput.visible = selected_id == SEX_OTHER_ID


func _on_sex_selected(item_index: int) -> void:
	if not has_node("%SexDropdown") or not has_node("%CustomSexInput"):
		return
	%CustomSexInput.visible = %SexDropdown.get_item_id(item_index) == SEX_OTHER_ID
	if %CustomSexInput.visible:
		%CustomSexInput.grab_focus()


func _get_edited_sex() -> String:
	if not has_node("%SexDropdown") or %SexDropdown.selected < 0:
		return "male"
	match %SexDropdown.get_selected_id():
		SEX_MALE_ID:
			return "male"
		SEX_FEMALE_ID:
			return "female"
		_:
			var custom_value: String = %CustomSexInput.text.strip_edges() if has_node("%CustomSexInput") else ""
			return custom_value if not custom_value.is_empty() else "other"


func _reset_add_fields() -> void:
	if has_node("%AddCharacter"):
		%AddCharacter.text = ""
	if has_node("%AddDialogue"):
		%AddDialogue.text = ""
	if has_node("%AddSexDropdown"):
		for i in %AddSexDropdown.item_count:
			if %AddSexDropdown.get_item_id(i) == SEX_MALE_ID:
				%AddSexDropdown.selected = i
				break
	if has_node("%AddCustomSexInput"):
		%AddCustomSexInput.text = ""
		%AddCustomSexInput.visible = false


func _on_add_sex_selected(item_index: int) -> void:
	if not has_node("%AddSexDropdown") or not has_node("%AddCustomSexInput"):
		return
	%AddCustomSexInput.visible = %AddSexDropdown.get_item_id(item_index) == SEX_OTHER_ID
	if %AddCustomSexInput.visible:
		%AddCustomSexInput.grab_focus()


func _get_add_sex() -> String:
	if not has_node("%AddSexDropdown") or %AddSexDropdown.selected < 0:
		return "male"
	match %AddSexDropdown.get_selected_id():
		SEX_MALE_ID:
			return "male"
		SEX_FEMALE_ID:
			return "female"
		_:
			var custom_value: String = %AddCustomSexInput.text.strip_edges() if has_node("%AddCustomSexInput") else ""
			return custom_value if not custom_value.is_empty() else "other"


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
	dict["sex"] = _get_edited_sex()
	# Clear old sound_filename to force regeneration
	dict.erase("sound_filename")
	interactions[_editing_index] = dict
	var saved_idx := _editing_index
	SceneDataManager.scene_data["interactions"] = interactions
	SceneDataManager.save()
	# Non-blocking TTS for edited dialogue
	var uuid_edit := str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if not uuid_edit.is_empty() and not str(dialogue_text).strip_edges().is_empty():
		TTSManager.generate_single_interaction(uuid_edit, saved_idx)
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	_editing_index = -1
	_refresh_list()
	_refresh_dropdown()
	dialogue_updated.emit()


func _on_edit_delete_pressed() -> void:
	var interactions: Array = _get_interactions()
	if _editing_index < 0 or _editing_index >= interactions.size():
		return
	if interactions.size() <= 1:
		if has_node("%LastDialogueError"):
			%LastDialogueError.popup_centered()
		return
	interactions.remove_at(_editing_index)
	SceneDataManager.scene_data["interactions"] = interactions
	SceneDataManager.save()
	if has_node("%EditPopup"):
		%EditPopup.visible = false
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
		"character": %AddCharacter.text.strip_edges() if has_node("%AddCharacter") else "",
		"dialogue": %AddDialogue.text if has_node("%AddDialogue") else "",
		"sex": _get_add_sex()
	}
	interactions.insert(insert_at, new_entry)
	SceneDataManager.scene_data["interactions"] = interactions
	SceneDataManager.save()
	# Non-blocking TTS for newly added dialogue
	var uuid_add := str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if not uuid_add.is_empty():
		TTSManager.generate_single_interaction(uuid_add, insert_at)
	_refresh_list()
	_refresh_dropdown()
	if has_node("%DialogueDropdown"):
		var dropdown2: OptionButton = %DialogueDropdown
		for i in dropdown2.item_count:
			if dropdown2.get_item_id(i) == insert_at:
				dropdown2.selected = i
				break
	_reset_add_fields()
	dialogue_updated.emit()
	if has_node("%AddOverlay"):
		%AddOverlay.visible = false
	visible = false
	closed.emit()


func _on_back_pressed() -> void:
	# Legacy - delegate to hub back
	_on_hub_back_pressed()


func _update_labels() -> void:
	_update_sex_dropdown_labels()
	_update_add_sex_dropdown_labels()
	if has_node("%Title"):
		%Title.text = I18n.translate("plot_overlay_title") if I18n.translate("plot_overlay_title") != "plot_overlay_title" else "Plot"
	if has_node("%HubEditButton"):
		%HubEditButton.text = I18n.translate("dialogue_hub_edit") if I18n.translate("dialogue_hub_edit") != "dialogue_hub_edit" else "Edit"
	if has_node("%HubAddButton"):
		%HubAddButton.text = I18n.translate("dialogue_hub_add") if I18n.translate("dialogue_hub_add") != "dialogue_hub_add" else "Add"
	if has_node("%RegenerateAllButton") and not _is_regenerating:
		%RegenerateAllButton.text = I18n.translate("dialogue_hub_regenerate") if I18n.translate("dialogue_hub_regenerate") != "dialogue_hub_regenerate" else "Regenerate Scene"
	if has_node("%SummaryButton"):
		%SummaryButton.text = I18n.translate("btn_summary") if I18n.translate("btn_summary") != "btn_summary" else "Summary"
	if has_node("%DialogueBack"):
		%DialogueBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%RegenerateConfirmLabel"):
		%RegenerateConfirmLabel.text = I18n.translate("dialogue_regenerate_confirm") if I18n.translate("dialogue_regenerate_confirm") != "dialogue_regenerate_confirm" else "Regenerate this scene? This will replace its story, dialogues, and choices, then generate a new image."
	if has_node("%RegenerateCancel"):
		%RegenerateCancel.text = I18n.translate("btn_cancel") if I18n.translate("btn_cancel") != "btn_cancel" else "Cancel"
	if has_node("%RegenerateConfirm"):
		%RegenerateConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
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
	if has_node("%AddCharacter"):
		%AddCharacter.placeholder_text = I18n.translate("dialogue_character_placeholder") if I18n.translate("dialogue_character_placeholder") != "dialogue_character_placeholder" else "Character"
	if has_node("%AddDialogue"):
		%AddDialogue.placeholder_text = I18n.translate("dialogue_text_placeholder") if I18n.translate("dialogue_text_placeholder") != "dialogue_text_placeholder" else "Dialogue..."
	if has_node("%AddSexLabel"):
		%AddSexLabel.text = I18n.translate("dialogue_sex_label") if I18n.translate("dialogue_sex_label") != "dialogue_sex_label" else "Sex"
	if has_node("%AddCustomSexInput"):
		%AddCustomSexInput.placeholder_text = I18n.translate("dialogue_sex_custom_placeholder") if I18n.translate("dialogue_sex_custom_placeholder") != "dialogue_sex_custom_placeholder" else "Enter a value"
	if has_node("%EditTitle"):
		%EditTitle.text = I18n.translate("dialogue_edit_title") if I18n.translate("dialogue_edit_title") != "dialogue_edit_title" else "Edit Dialogue"
	if has_node("%EditCharacter"):
		%EditCharacter.placeholder_text = I18n.translate("dialogue_character_placeholder") if I18n.translate("dialogue_character_placeholder") != "dialogue_character_placeholder" else "Character"
	if has_node("%EditDialogue"):
		%EditDialogue.placeholder_text = I18n.translate("dialogue_text_placeholder") if I18n.translate("dialogue_text_placeholder") != "dialogue_text_placeholder" else "Dialogue..."
	if has_node("%SexLabel"):
		%SexLabel.text = I18n.translate("dialogue_sex_label") if I18n.translate("dialogue_sex_label") != "dialogue_sex_label" else "Sex"
	if has_node("%CustomSexInput"):
		%CustomSexInput.placeholder_text = I18n.translate("dialogue_sex_custom_placeholder") if I18n.translate("dialogue_sex_custom_placeholder") != "dialogue_sex_custom_placeholder" else "Enter a value"
	if has_node("%EditBack"):
		%EditBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%EditSave"):
		%EditSave.text = I18n.translate("btn_save") if I18n.translate("btn_save") != "btn_save" else "Save"
	if has_node("%EditDelete"):
		%EditDelete.text = I18n.translate("btn_delete") if I18n.translate("btn_delete") != "btn_delete" else "Delete"
	if has_node("%LastDialogueError"):
		%LastDialogueError.title = I18n.translate("error_dialog_title") if I18n.translate("error_dialog_title") != "error_dialog_title" else "Error"
		%LastDialogueError.dialog_text = I18n.translate("dialogue_delete_last_error") if I18n.translate("dialogue_delete_last_error") != "dialogue_delete_last_error" else "The last dialogue cannot be deleted."


func _update_sex_dropdown_labels() -> void:
	if not has_node("%SexDropdown"):
		return
	var selected_id := SEX_MALE_ID
	if %SexDropdown.selected >= 0:
		selected_id = %SexDropdown.get_selected_id()
	%SexDropdown.clear()
	%SexDropdown.add_item(I18n.translate("dialogue_sex_male"), SEX_MALE_ID)
	%SexDropdown.add_item(I18n.translate("dialogue_sex_female"), SEX_FEMALE_ID)
	%SexDropdown.add_item(I18n.translate("dialogue_sex_other"), SEX_OTHER_ID)
	for i in %SexDropdown.item_count:
		if %SexDropdown.get_item_id(i) == selected_id:
			%SexDropdown.selected = i
			break


func _update_add_sex_dropdown_labels() -> void:
	if not has_node("%AddSexDropdown"):
		return
	var selected_id := SEX_MALE_ID
	if %AddSexDropdown.selected >= 0:
		selected_id = %AddSexDropdown.get_selected_id()
	%AddSexDropdown.clear()
	%AddSexDropdown.add_item(I18n.translate("dialogue_sex_male"), SEX_MALE_ID)
	%AddSexDropdown.add_item(I18n.translate("dialogue_sex_female"), SEX_FEMALE_ID)
	%AddSexDropdown.add_item(I18n.translate("dialogue_sex_other"), SEX_OTHER_ID)
	for i in %AddSexDropdown.item_count:
		if %AddSexDropdown.get_item_id(i) == selected_id:
			%AddSexDropdown.selected = i
			break
