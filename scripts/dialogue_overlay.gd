extends Control

signal closed
signal dialogue_updated

const TRIM_LEN := 20

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
	if has_node("%EditPopup"):
		%EditPopup.visible = false
	_editing_index = -1


func _on_hub_add_pressed() -> void:
	if has_node("%AddOverlay"):
		%AddOverlay.visible = true
		_refresh_dropdown()
		_update_labels()
	if has_node("%EditOverlay"):
		%EditOverlay.visible = false
	if has_node("%EditPopup"):
		%EditPopup.visible = false


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
			%RegenerateAllButton.text = I18n.translate("dialogue_hub_regenerate") if I18n.translate("dialogue_hub_regenerate") != "dialogue_hub_regenerate" else "Regenerate All"
	if has_node("%HubEditButton"):
		%HubEditButton.disabled = disabled
	if has_node("%HubAddButton"):
		%HubAddButton.disabled = disabled
	if has_node("%DialogueBack"):
		%DialogueBack.disabled = disabled


func _extract_json(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var start := t.find("\n")
		var end := t.rfind("```")
		if start != -1 and end != -1 and end > start:
			t = t.substr(start + 1, end - start - 1).strip_edges()
		else:
			t = t.replace("```json", "").replace("```", "").strip_edges()
	return t


func _repair_llm_json_text(text: String) -> String:
	var key := "\"image_prompt\""
	var idx := text.find(key)
	if idx == -1:
		return text
	var colon := text.find(":", idx + key.length())
	if colon == -1:
		return text
	var first_quote := text.find("\"", colon)
	if first_quote == -1:
		return text
	var summary_key := "\"summary\""
	var summary_idx := text.find(summary_key, first_quote)
	if summary_idx == -1:
		summary_idx = text.find("\"end\"", first_quote)
		if summary_idx == -1:
			summary_idx = text.find("\"language\"", first_quote)
		if summary_idx == -1:
			return text
	var close_seq := text.rfind("\",", summary_idx)
	if close_seq == -1 or close_seq <= first_quote:
		return text
	var raw_val := text.substr(first_quote + 1, close_seq - first_quote - 1)
	var sanitized := raw_val.replace("\\\"", "").replace("\\", "").replace("\"", "").replace("'", "").replace("\n", " ").replace("\r", " ")
	sanitized = sanitized.strip_edges()
	while sanitized.find(",,") != -1:
		sanitized = sanitized.replace(",,", ",")
	var before := text.substr(0, first_quote + 1)
	var after := text.substr(close_seq)
	return before + sanitized + after


func _execute_regenerate_all() -> void:
	if _is_regenerating:
		return
	_is_regenerating = true
	_update_regenerate_button_state()
	# Infinite retry loop like gameplay _execute_new_story/scene
	while true:
		var round_val: int = _get_current_round()
		var is_first: bool = round_val == 1
		var result: Dictionary
		if is_first:
			result = await LLMManager.request_new_story()
		else:
			result = await LLMManager.request_new_scene()
		print_verbose("RegenerateAll round=%d is_first=%s result=%s" % [round_val, str(is_first), str(result)])
		if not result.get("success", false):
			var err_msg: String = str(result.get("error", "Failed to generate dialogue"))
			var gameplay = get_parent()
			if gameplay and gameplay.has_method("show_error"):
				gameplay.show_error(err_msg, true, "regenerate_all")
				if gameplay.has_signal("retry_requested"):
					await gameplay.retry_requested
					await get_tree().create_timer(0.1).timeout
					if not is_instance_valid(self) or not is_inside_tree():
						_is_regenerating = false
						_update_regenerate_button_state()
						return
					continue
			else:
				push_error("Regenerate failed: %s" % err_msg)
				break
			continue
		var raw_text: String = str(result.get("text", ""))
		var json_str: String = _extract_json(raw_text)
		var json := JSON.new()
		var err := json.parse(json_str)
		if err != OK or not json.data is Dictionary:
			var repaired := _repair_llm_json_text(json_str)
			if repaired != json_str:
				json = JSON.new()
				err = json.parse(repaired)
				if err == OK and json.data is Dictionary:
					json_str = repaired
			if err != OK or not json.data is Dictionary:
				var gameplay2 = get_parent()
				var msg2: String = "LLM returned invalid JSON: " + raw_text.substr(0, 300)
				if gameplay2 and gameplay2.has_method("show_error"):
					gameplay2.show_error(msg2, true, "regenerate_all")
					if gameplay2.has_signal("retry_requested"):
						await gameplay2.retry_requested
						await get_tree().create_timer(0.1).timeout
						if not is_instance_valid(self) or not is_inside_tree():
							_is_regenerating = false
							_update_regenerate_button_state()
							return
						continue
				push_warning(msg2)
				continue
		var llm_data: Dictionary = json.data as Dictionary
		if not llm_data.has("interactions") or not llm_data["interactions"] is Array:
			var gameplay3 = get_parent()
			var msg3: String = "LLM response missing interactions"
			if gameplay3 and gameplay3.has_method("show_error"):
				gameplay3.show_error(msg3, true, "regenerate_all")
				if gameplay3.has_signal("retry_requested"):
					await gameplay3.retry_requested
					await get_tree().create_timer(0.1).timeout
					if not is_instance_valid(self) or not is_inside_tree():
						_is_regenerating = false
						_update_regenerate_button_state()
						return
					continue
			push_warning(msg3)
			continue
		# Success: overwrite only interactions, preserve everything else
		var new_interactions: Array = (llm_data["interactions"] as Array).duplicate(true)
		# Normalize entries
		for i in new_interactions.size():
			var e = new_interactions[i]
			if not e is Dictionary:
				new_interactions[i] = {"character": str(e), "dialogue": "", "sex": "male"}
				continue
			var d: Dictionary = e as Dictionary
			if d.has("characer") and not d.has("character"):
				d["character"] = d["characer"]
				d.erase("characer")
			if not d.has("character"):
				d["character"] = ""
			if not d.has("dialogue"):
				d["dialogue"] = ""
			if not d.has("sex"):
				d["sex"] = "male"
			new_interactions[i] = d
		SceneDataManager.scene_data["interactions"] = new_interactions
		SceneDataManager.save()
		# Non-blocking TTS for regenerated dialogues
		TTSManager.generate_all_for_scene(SceneDataManager.scene_data)
		# Reset dialogue progress to 0 as requested
		GameProgressManager.settings["current_dialogue"] = 0
		GameProgressManager.save_settings()
		var gameplay4 = get_parent()
		if gameplay4:
			if gameplay4.get("current_dialogue_index") != null or gameplay4.has_method("_show_current_dialogue"):
				gameplay4.set("current_dialogue_index", 0)
			if gameplay4.get("_current_dialog_idx") != null:
				gameplay4.set("_current_dialog_idx", 0)
		_refresh_list()
		_refresh_dropdown()
		dialogue_updated.emit()
		# Clear retry pending in gameplay
		var gp_clear = get_parent()
		if gp_clear:
			if gp_clear.get("_pending_retry_action") != null:
				gp_clear.set("_pending_retry_action", "")
			else:
				# fallback direct assign if property exists
				gp_clear.set("_pending_retry_action", "")
		break
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
	if has_node("%EditCharacter"):
		%EditCharacter.text = character_name
	if has_node("%EditDialogue"):
		%EditDialogue.text = dialogue_text
	if has_node("%EditPopup"):
		%EditPopup.visible = true
	_update_labels()


func _on_edit_back_pressed() -> void:
	if has_node("%EditPopup"):
		%EditPopup.visible = false
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
	if has_node("%RegenerateAllButton") and not _is_regenerating:
		%RegenerateAllButton.text = I18n.translate("dialogue_hub_regenerate") if I18n.translate("dialogue_hub_regenerate") != "dialogue_hub_regenerate" else "Regenerate All"
	if has_node("%DialogueBack"):
		%DialogueBack.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%RegenerateConfirmLabel"):
		%RegenerateConfirmLabel.text = I18n.translate("dialogue_regenerate_confirm") if I18n.translate("dialogue_regenerate_confirm") != "dialogue_regenerate_confirm" else "Regenerate all dialogues? This will overwrite all current dialogues."
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
