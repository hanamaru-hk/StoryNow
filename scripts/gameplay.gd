extends Control

const CURRENT_VERSION := "1.0"

var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0

# Requested public dialogue tracking vars
var current_dialogue_index: int = 0
var total_dialogue: int = 1

func _ready() -> void:
	# --- Dialogue panel grid buttons ---
	%PlotButton.pressed.connect(_on_plot_pressed)
	%PlayAudioButton.pressed.connect(_on_play_audio_pressed)
	%DialogButton.pressed.connect(_on_dialog_btn_pressed)
	%ImageButton.pressed.connect(_on_image_btn_pressed)
	%PrevDialogButton.pressed.connect(_on_prev_dialog_pressed)
	%NextDialogButton.pressed.connect(_on_next_dialog_pressed)
	%PrevSceneButton.pressed.connect(_on_prev_scene_pressed)
	%NextSceneButton.pressed.connect(_on_next_scene_pressed)
	%SettingButton.pressed.connect(_on_setting_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false

	# --- GameSettingsOverlay (in-game settings) ---
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.closed.connect(_on_settings_closed)

	# --- ErrorReturnDialog ---
	%ErrorReturnDialog.confirmed.connect(_on_error_return)
	%ErrorReturnDialog.canceled.connect(_on_error_return)
	# AcceptDialog close via X also triggers canceled

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	_update_labels()
	_load_default_background()
	# Disable all SidePanel buttons except Setting and BackButton at start
	_set_all_side_buttons_disabled_except_settings_back()

	match GameProgressManager.settings.get("game_status", ""):
		"new_story":
			var uuid: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok: bool = SceneDataManager.load_data(uuid)
			if ok:
				_scene_data = SceneDataManager.scene_data
			await _handle_new_story()
			# --- After new_story: populate dynamic choice buttons above CustomInput ---
			_populate_dynamic_choice_buttons()
			# --- After new_story: update dialogue tracking and trigger image generation ---
			GameProgressManager.settings["game_status"] = "generate_image"
			GameProgressManager.save_settings()
			_update_total_dialogue()
			_show_current_dialogue()
			# Enable Next Dialogue and Dialogue buttons
			%NextDialogButton.disabled = false
			%DialogButton.disabled = false
			# Check prev dialogue eligibility
			%PrevDialogButton.disabled = not _is_prev_dialogue_exist()
			await _generate_comfyui_image()
			GameProgressManager.settings["game_status"] = "running"
			GameProgressManager.save_settings()
			_enable_all_side_buttons_by_eligibility()
		"new_scene":
			var uuid_new_scene: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok_new_scene: bool = SceneDataManager.load_data(uuid_new_scene)
			if ok_new_scene:
				_scene_data = SceneDataManager.scene_data
			print_verbose("")
			print_verbose("GameProgressManager.settings: %s" % str(GameProgressManager.settings))
			print_verbose("")
			print_verbose("SceneDataManager.scene_data (pre-scene): %s" % str(SceneDataManager.scene_data))
			await _handle_new_scene()
			# --- After new_scene: populate dynamic choice buttons above CustomInput ---
			_populate_dynamic_choice_buttons()
			# --- After new_scene: update dialogue tracking and trigger image generation ---
			GameProgressManager.settings["game_status"] = "generate_image"
			GameProgressManager.save_settings()
			_update_total_dialogue()
			_show_current_dialogue()
			# Enable Next Dialogue and Dialogue buttons
			%NextDialogButton.disabled = false
			%DialogButton.disabled = false
			# Check prev dialogue eligibility
			%PrevDialogButton.disabled = not _is_prev_dialogue_exist()
			await _generate_comfyui_image()
			GameProgressManager.settings["game_status"] = "running"
			GameProgressManager.save_settings()
			_enable_all_side_buttons_by_eligibility()
		"running":
			
			pass	
		_:
			pass


func _load_default_background() -> void:
	# Runtime load to avoid requiring .import (handles missing Texture2D loader error).
	# Uses Image.load_from_file via globalized path, then ImageTexture.
	var res_path := "res://assets/images/loading.png"
	var global_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# Fallback: try direct res:// path (works if file is imported elsewhere)
		err = img.load(res_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		%BackgroundImage.texture = tex
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)
	else:
		# Final fallback: try ResourceLoader (requires import)
		var res_tex: Resource = load(res_path)
		if res_tex is Texture2D:
			%BackgroundImage.texture = res_tex
		else:
			push_warning("Failed to load default background %s: %s" % [res_path, err])
		# Keep modulate for placeholder / 50% opacity
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)

# ------------------------------------------------------------------
# Dialogue helpers — current/total tracking and UI update
# ------------------------------------------------------------------
func _update_total_dialogue() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	total_dialogue = interactions.size()
	if total_dialogue <= 0:
		total_dialogue = 1
	# keep legacy var in sync
	_current_dialog_idx = current_dialogue_index
	# clamp index inside range
	if current_dialogue_index < 0:
		current_dialogue_index = 0
	if current_dialogue_index >= total_dialogue:
		current_dialogue_index = total_dialogue - 1


func _show_current_dialogue() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if interactions.is_empty():
		if has_node("%NameLabel"):
			%NameLabel.text = ""
		if has_node("%DialogLabel"):
			%DialogLabel.text = ""
		if has_node("%DialogProgressLabel"):
			%DialogProgressLabel.text = "%d / %d" % [current_dialogue_index + 1, total_dialogue]
		return
	# clamp
	if current_dialogue_index < 0:
		current_dialogue_index = 0
	if current_dialogue_index >= interactions.size():
		current_dialogue_index = interactions.size() - 1
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	# NOTE: spec has typo "characer" — support both keys
	var character_name: String = str(entry.get("character", entry.get("characer", "")))
	var dialogue_text: String = str(entry.get("dialogue", ""))
	if has_node("%NameLabel"):
		%NameLabel.text = character_name
	if has_node("%DialogLabel"):
		%DialogLabel.text = dialogue_text
	if has_node("%DialogProgressLabel"):
		%DialogProgressLabel.text = "%d / %d" % [current_dialogue_index + 1, total_dialogue]
	# sync legacy
	_current_dialog_idx = current_dialogue_index
	_scene_data = SceneDataManager.scene_data

# ------------------------------------------------------------------
# Button eligibility helpers
# ------------------------------------------------------------------
func _is_prev_scene_exist() -> bool:
	# Check if SceneDataManager.scene_data has a non-null prev
	if not SceneDataManager.scene_data.has("prev_uuid"):
		return false
	var prev = SceneDataManager.scene_data.get("prev_uuid")
	if prev == null:
		return false
	if prev is String:
		return not str(prev).strip_edges().is_empty()
	if prev is Dictionary:
		return not (prev as Dictionary).is_empty()
	if prev is Array:
		return not (prev as Array).is_empty()
	return true


func _is_prev_dialogue_exist() -> bool:
	return current_dialogue_index != 0


func is_prev_scene_exist() -> bool:
	return _is_prev_scene_exist()


func is_prev_dialogue_exist() -> bool:
	return _is_prev_dialogue_exist()


func _set_all_side_buttons_disabled_except_settings_back() -> void:
	%DialogButton.disabled = true
	%ImageButton.disabled = true
	%PlotButton.disabled = true
	%PlayAudioButton.disabled = true
	%PrevDialogButton.disabled = true
	%NextDialogButton.disabled = true
	%PrevSceneButton.disabled = true
	%NextSceneButton.disabled = true
	%SettingButton.disabled = false
	%BackButton.disabled = false


func _update_button_eligibility() -> void:
	%PrevDialogButton.disabled = not _is_prev_dialogue_exist()
	%PrevSceneButton.disabled = not _is_prev_scene_exist()


func _enable_all_side_buttons_by_eligibility() -> void:
	%DialogButton.disabled = false
	%ImageButton.disabled = false
	%PlotButton.disabled = false
	%PlayAudioButton.disabled = false
	%NextDialogButton.disabled = false
	%NextSceneButton.disabled = false
	# Prev buttons depend on eligibility
	_update_button_eligibility()

# ------------------------------------------------------------------
# Dynamic choice buttons above CustomInput
# ------------------------------------------------------------------
func _populate_dynamic_choice_buttons() -> void:
	if not has_node("%DynamicChoiceButtons"):
		return
	var container: VBoxContainer = %DynamicChoiceButtons
	for child in container.get_children():
		child.queue_free()
	var choices = SceneDataManager.scene_data.get("choices", [])
	if not choices is Array:
		return
	for choice in choices:
		var text: String = ""
		if choice is Dictionary:
			# template uses "plot", fallback to common keys
			text = str(choice.get("plot", choice.get("text", choice.get("choice", ""))))
		else:
			text = str(choice)
		text = text.strip_edges()
		if text.is_empty():
			continue
		var btn := Button.new()
		btn.text = text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_dynamic_choice_pressed.bind(text))
		container.add_child(btn)


func _on_dynamic_choice_pressed(choice_text: String) -> void:
	# Fill CustomInput with the chosen plot so user can edit or confirm
	if has_node("%CustomInput"):
		%CustomInput.text = choice_text
		%CustomInput.grab_focus()



func _generate_comfyui_image() -> void:
	var image_prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	print_verbose("Generating ComfyUI image for scene_data: %s" % image_prompt)
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
	var result: Dictionary = await ImageServerManager.generate_scene_image(image_prompt, uuid)
	if not result.get("success", false):
		show_error(str(result.get("error", "Failed to generate image")))
		return
	var save_path: String = str(result.get("save_path", ""))
	var filename: String = str(result.get("filename", ""))
	# update background
	_set_background_from_file(save_path)
	# append filename to SceneDataManager image_filenames array and persist
	if not SceneDataManager.scene_data.has("image_filenames") or not SceneDataManager.scene_data["image_filenames"] is Array:
		SceneDataManager.scene_data["image_filenames"] = []
	var arr: Array = SceneDataManager.scene_data["image_filenames"]
	arr.append(filename)
	SceneDataManager.scene_data["image_filenames"] = arr
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	print_verbose("Saved ComfyUI image to %s, image_filenames: %s" % [save_path, str(arr)])


func _set_background_from_file(user_path: String) -> void:
	# user_path is like user://saves/.../images/SN_00001_.png
	var global_path := ProjectSettings.globalize_path(user_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# try direct user:// path (Godot 4 may load user:// directly)
		err = img.load(user_path)
	if err != OK:
		push_warning("Failed to load generated image %s: %s" % [user_path, error_string(err)])
		return
	var tex := ImageTexture.create_from_image(img)
	%BackgroundImage.texture = tex
	%BackgroundImage.modulate = Color(1, 1, 1, 1)

# ------------------------------------------------------------------
# Input handlers
# ------------------------------------------------------------------
# Trigger: virtual Node._input / _unhandled_input — called automatically by Godot's
# input dispatch (no signal connection needed). _input is used so right-click
# works even when GUI Controls (Dialogue/TopBar) would otherwise mark the event
# as handled and prevent _unhandled_input from firing.
func _input(event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	pass


func _toggle_chrome() -> void:
	pass


func _on_dialog_area_input(event: InputEvent) -> void:
	pass


func _on_prev_dialog_pressed() -> void:
	if total_dialogue <= 1:
		return
	if current_dialogue_index > 0:
		current_dialogue_index -= 1
		_show_current_dialogue()
		_update_button_eligibility()


func _on_next_dialog_pressed() -> void:
	# Spec: if (current_dialogue_index > total_dialogue) show choice overlay
	if current_dialogue_index > total_dialogue:
		_show_choice_overlay()
		return
	# Also handle end-of-dialogue -> choice overlay (index at last dialogue)
	if current_dialogue_index >= total_dialogue - 1:
		_show_choice_overlay()
		return
	if total_dialogue <= 1:
		return
	if current_dialogue_index < total_dialogue - 1:
		current_dialogue_index += 1
		_show_current_dialogue()
		_update_button_eligibility()


func _on_prev_scene_pressed() -> void:
	pass

func _on_next_scene_pressed() -> void:
	_show_choice_overlay()


func _on_dialog_btn_pressed() -> void:
	pass


func _on_image_btn_pressed() -> void:
	pass


func _on_plot_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_play_audio_pressed() -> void:
	pass


func _on_settings_closed() -> void:
	_update_labels()


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
	# LLM often emits image_prompt with bare quotes like "recurring" instead of \"recurring\",
	# which breaks JSON parsing. Repair by sanitizing the image_prompt value before parse.
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
	# Find the closing delimiter before "summary" — look for the last '",' before summary key
	var summary_key := "\"summary\""
	var summary_idx := text.find(summary_key, first_quote)
	if summary_idx == -1:
		# Fallback: try "end" or "language"
		summary_idx = text.find("\"end\"", first_quote)
		if summary_idx == -1:
			summary_idx = text.find("\"language\"", first_quote)
		if summary_idx == -1:
			return text
	# The image_prompt's closing quote is the '",' immediately before summary (allow whitespace)
	var close_seq := text.rfind("\",", summary_idx)
	if close_seq == -1 or close_seq <= first_quote:
		return text
	# Also handle the case where value ends with \" then ",
	var raw_val := text.substr(first_quote + 1, close_seq - first_quote - 1)
	# Sanitize: strip escaped and unescaped quotes, newlines, and Danbooru tag noise
	var sanitized := raw_val.replace("\\\"", "").replace("\\", "").replace("\"", "").replace("'", "").replace("\n", " ").replace("\r", " ")
	# Collapse whitespace and clean trailing commas
	sanitized = sanitized.strip_edges()
	# Remove duplicate commas
	while sanitized.find(",,") != -1:
		sanitized = sanitized.replace(",,", ",")
	# Rebuild text with sanitized value (no inner quotes, safe for JSON)
	var before := text.substr(0, first_quote + 1)
	var after := text.substr(close_seq)
	return before + sanitized + after


func _handle_new_story() -> void:
	var result: Dictionary = await LLMManager.request_new_story()
	print_verbose("LLM request_new_story result: %s" % str(result))
	if not result.get("success", false):
		show_error(str(result.get("error", "Failed to generate story")))
		return
	var raw_text: String = str(result.get("text", ""))
	var json_str: String = _extract_json(raw_text)
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not json.data is Dictionary:
		# Try to repair common LLM malformed image_prompt (bare quotes) and re-parse
		var repaired := _repair_llm_json_text(json_str)
		if repaired != json_str:
			print_verbose("Attempting repaired JSON parse for image_prompt bare quotes")
			json = JSON.new()
			err = json.parse(repaired)
			if err == OK and json.data is Dictionary:
				json_str = repaired
			else:
				# Fallback: try fallback extraction for image_prompt even if still invalid,
				# then attempt to recover other fields via manual parse
				print_verbose("Repaired JSON still invalid: %s" % error_string(err))
		if err != OK or not json.data is Dictionary:
			print_verbose("Failed to parse JSON: %s" % error_string(err))
			print_verbose("Failed to parse JSON: %s" % raw_text.substr(0, 300))
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300))
			return
	var llm_data: Dictionary = json.data as Dictionary

	print_verbose("Parsed llm_data image_prompt: '%s'" % str(llm_data.get("image_prompt", "<missing>")))
	# Don't modify the format of the LLM JSON – just extract and merge into SceneDataManager.scene_data
	if SceneDataManager.scene_data.is_empty():
		SceneDataManager.scene_data = llm_data.duplicate(true)
		if not SceneDataManager.scene_data.has("uuid"):
			SceneDataManager.scene_data["uuid"] = str(GameProgressManager.settings.get("current_uuid", ""))
	else:
		for key in llm_data.keys():
			SceneDataManager.scene_data[key] = llm_data[key]
	# Ensure essential meta fields remain if LLM omitted them
	if not SceneDataManager.scene_data.has("uuid"):
		SceneDataManager.scene_data["uuid"] = str(GameProgressManager.settings.get("current_uuid", ""))
	if not SceneDataManager.scene_data.has("version"):
		SceneDataManager.scene_data["version"] = "1.0"
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	# Mark progress as running so next load doesn't re-request
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	print_verbose("Final scene data: " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings: " + str(GameProgressManager.settings))


func _handle_new_scene() -> void:
	var result: Dictionary = await LLMManager.request_new_scene()
	print_verbose("LLM request_new_scene result: %s" % str(result))
	if not result.get("success", false):
		show_error(str(result.get("error", "Failed to generate scene")))
		return
	var raw_text: String = str(result.get("text", ""))
	var json_str: String = _extract_json(raw_text)
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not json.data is Dictionary:
		var repaired := _repair_llm_json_text(json_str)
		if repaired != json_str:
			print_verbose("Attempting repaired JSON parse for image_prompt bare quotes (scene)")
			json = JSON.new()
			err = json.parse(repaired)
			if err == OK and json.data is Dictionary:
				json_str = repaired
			else:
				print_verbose("Repaired JSON still invalid: %s" % error_string(err))
		if err != OK or not json.data is Dictionary:
			print_verbose("Failed to parse JSON (scene): %s" % error_string(err))
			print_verbose("Failed to parse JSON (scene): %s" % raw_text.substr(0, 300))
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300))
			return
	var llm_data: Dictionary = json.data as Dictionary
	print_verbose("Parsed scene llm_data image_prompt: '%s'" % str(llm_data.get("image_prompt", "<missing>")))
	# Merge into SceneDataManager.scene_data — preserve current uuid/prev_uuid/version/current_round
	var current_uuid := str(GameProgressManager.settings.get("current_uuid", ""))
	var preserved_uuid := str(SceneDataManager.scene_data.get("uuid", current_uuid))
	var preserved_prev := str(SceneDataManager.scene_data.get("prev_uuid", ""))
	var preserved_version := str(SceneDataManager.scene_data.get("version", CURRENT_VERSION))
	var preserved_current_round: Variant = SceneDataManager.scene_data.get("current_round", GameProgressManager.settings.get("current_round", 1))
	for key in llm_data.keys():
		SceneDataManager.scene_data[key] = llm_data[key]
	# Restore preserved meta
	SceneDataManager.scene_data["uuid"] = preserved_uuid
	if not preserved_prev.is_empty():
		SceneDataManager.scene_data["prev_uuid"] = preserved_prev
	SceneDataManager.scene_data["version"] = preserved_version
	SceneDataManager.scene_data["current_round"] = preserved_current_round
	if not SceneDataManager.scene_data.has("id"):
		SceneDataManager.scene_data["id"] = preserved_uuid
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	print_verbose("Final scene data (scene): " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings (scene): " + str(GameProgressManager.settings))
# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	_populate_dynamic_choice_buttons()
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false


func _on_choice_button_pressed(choice_text: String) -> void:
	_hide_choice_overlay()
	pass


func _on_choice_confirm() -> void:
	var raw_text: String = %CustomInput.text if has_node("%CustomInput") else ""
	var stripped_text: String = raw_text.strip_edges()
	if stripped_text.is_empty():
		return
	var normalized_input: String = stripped_text.to_lower()

	var choices: Array = SceneDataManager.scene_data.get("choices", [])
	if not choices is Array:
		choices = []
		SceneDataManager.scene_data["choices"] = choices

	var choice_index: int = -1
	for i in choices.size():
		var c = choices[i]
		var plot_raw: String = ""
		if c is Dictionary:
			plot_raw = str(c.get("plot", c.get("text", c.get("choice", ""))))
		else:
			plot_raw = str(c)
		if plot_raw.strip_edges().to_lower() == normalized_input:
			choice_index = i
			break

	if choice_index == -1:
		choice_index = choices.size()
		choices.append({"plot": stripped_text})
		SceneDataManager.scene_data["choices"] = choices
		SceneDataManager.save()

	# Ensure entry is a Dictionary for id handling
	if not choices[choice_index] is Dictionary:
		choices[choice_index] = {"plot": str(choices[choice_index])}
		SceneDataManager.scene_data["choices"] = choices
		SceneDataManager.save()

	var cur_round: int = int(GameProgressManager.settings.get("current_round", 1))

	print_verbose("Choice confirmed: '%s', index: %d, current_round: %d" % [stripped_text, choice_index, cur_round])
	# Keep GameProgressManager in sync if it tracks current_round
	if GameProgressManager.settings.has("current_round"):
		GameProgressManager.settings["current_round"] = cur_round + 1
	else:
		# Ensure game progress also reflects current round for new saves
		GameProgressManager.settings["current_round"] = 1

	var entry: Dictionary = choices[choice_index] as Dictionary
	var existing_id: String = str(entry.get("uuid", "")).strip_edges()
	if not existing_id.is_empty():
		GameProgressManager.settings["current_uuid"] = existing_id
		GameProgressManager.settings["game_status"] = "running"
	else:
		var uuid := _generate_uuid()
		var prev_uuid := str(SceneDataManager.scene_data.get("uuid", ""))
		entry["uuid"] = uuid
		choices[choice_index] = entry
		SceneDataManager.scene_data["choices"] = choices
		SceneDataManager.save()

		GameProgressManager.settings["game_status"] = "new_scene"
		GameProgressManager.settings["player_input"] = stripped_text
		GameProgressManager.settings["current_uuid"] = uuid

		# create new scene data using the new uuid
		SceneDataManager.scene_data["uuid"] = uuid
		SceneDataManager.scene_data["prev_uuid"] = prev_uuid
		SceneDataManager.scene_data["image_filenames"] = []
		SceneDataManager.scene_data["image_prompt"] = ""
		SceneDataManager.scene_data["image_instruction"] = ""
		SceneDataManager.scene_data["instruction"] = []
		SceneDataManager.scene_data["interactions"] = []
		SceneDataManager.scene_data["language"] = I18n.current_lang
		SceneDataManager.scene_data["summary"] = ""
		SceneDataManager.scene_data["version"] = CURRENT_VERSION
		SceneDataManager.scene_data["current_round"] = cur_round + 1

		SceneDataManager.scene_data["choices"] = []
		SceneDataManager.save()

	
	



	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: Array = []
	for i in 16:
		bytes.append(rng.randi_range(0, 255))
	# UUID v4: set version and variant bits
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]


func _advance_with_choice(choice_text: String) -> void:
	pass


# ------------------------------------------------------------------
# Error handling — common error return dialog for returning to main menu
# ------------------------------------------------------------------
func show_error(message: String) -> void:
	%ErrorReturnDialog.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnDialog.title = I18n.translate("error_dialog_title")
	%ErrorReturnDialog.popup_centered()


func _on_error_return() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	%DialogButton.text = I18n.translate("btn_dialog") if I18n.translate("btn_dialog") != "btn_dialog" else "Dialog"
	%ImageButton.text = I18n.translate("btn_image") if I18n.translate("btn_image") != "btn_image" else "Image"
	%PlotButton.text = I18n.translate("btn_plot") if I18n.translate("btn_plot") != "btn_plot" else "Plot"
	%PlayAudioButton.text = I18n.translate("btn_play_audio") if I18n.translate("btn_play_audio") != "btn_play_audio" else "Play"
	%PrevDialogButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Prev"
	# NextDialog text is dynamic in _show_dialog
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "< Scene"
	%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Next Scene >"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%BackButton.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
