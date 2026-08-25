extends Control


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

	match GameProgressManager.settings.get("game_status", ""):
		"new_story":
			var uuid: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok: bool = SceneDataManager.load_data(uuid)
			if ok:
				_scene_data = SceneDataManager.scene_data
			await _handle_new_story()
			# --- After new_story: update dialogue tracking and trigger image generation ---
			_update_total_dialogue()
			_show_current_dialogue()
			await _generate_comfyui_image()
		"new_scene":
			pass
		"running":
			pass
		_:
			pass


func _load_default_background() -> void:
	# Runtime load to avoid requiring .import (handles missing Texture2D loader error).
	# Uses Image.load_from_file via globalized path, then ImageTexture.
	var res_path := "res://assets/images/loading.jpg"
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
# ComfyUI image generation — delegated to ImageServerManager
# ------------------------------------------------------------------
func _sanitize_image_prompt(prompt: String) -> String:
	# Thin wrapper — single source of truth lives in ImageServerManager
	return ImageServerManager.sanitize_image_prompt(prompt)


func _generate_comfyui_image() -> void:
	var raw_prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	var image_prompt: String = _sanitize_image_prompt(raw_prompt)
	if image_prompt != raw_prompt:
		print_verbose("Sanitized stored image_prompt for ComfyUI: '%s'" % image_prompt.substr(0, 100))
		SceneDataManager.scene_data["image_prompt"] = image_prompt
		SceneDataManager.save()
		_scene_data = SceneDataManager.scene_data
	if image_prompt.strip_edges().is_empty():
		push_warning("SceneDataManager image_prompt is empty after sanitize, skipping ComfyUI generation (raw was: '%s')" % raw_prompt.substr(0, 100))
		return
	var uuid: String = str(SceneDataManager.scene_data.get("id", GameProgressManager.settings.get("current_uuid", "")))
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


func _on_next_dialog_pressed() -> void:
	if total_dialogue <= 1:
		return
	if current_dialogue_index < total_dialogue - 1:
		current_dialogue_index += 1
		_show_current_dialogue()


func _on_prev_scene_pressed() -> void:
	pass

func _on_next_scene_pressed() -> void:
	pass


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
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300))
			return
	var llm_data: Dictionary = json.data as Dictionary
	# Sanitize image_prompt immediately after parse — remove stray quotes that would break workflow JSON
	if llm_data.has("image_prompt"):
		var raw_prompt: String = str(llm_data.get("image_prompt", ""))
		var clean_prompt: String = _sanitize_image_prompt(raw_prompt)
		if clean_prompt != raw_prompt:
			print_verbose("Sanitized image_prompt from '%s' to '%s'" % [raw_prompt.substr(0, 80), clean_prompt.substr(0, 80)])
		llm_data["image_prompt"] = clean_prompt
	print_verbose("Parsed llm_data image_prompt: '%s'" % str(llm_data.get("image_prompt", "<missing>")))
	# Don't modify the format of the LLM JSON – just extract and merge into SceneDataManager.scene_data
	if SceneDataManager.scene_data.is_empty():
		SceneDataManager.scene_data = llm_data.duplicate(true)
		if not SceneDataManager.scene_data.has("id"):
			SceneDataManager.scene_data["id"] = str(GameProgressManager.settings.get("current_uuid", ""))
	else:
		for key in llm_data.keys():
			SceneDataManager.scene_data[key] = llm_data[key]
	# Ensure essential meta fields remain if LLM omitted them
	if not SceneDataManager.scene_data.has("id"):
		SceneDataManager.scene_data["id"] = str(GameProgressManager.settings.get("current_uuid", ""))
	if not SceneDataManager.scene_data.has("version"):
		SceneDataManager.scene_data["version"] = "1.0"
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	# Mark progress as running so next load doesn't re-request
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	print_verbose("Final scene data: " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings: " + str(GameProgressManager.settings))
# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false


func _on_choice_button_pressed(choice_text: String) -> void:
	_hide_choice_overlay()
	pass


func _on_choice_confirm() -> void:
	pass
	# _hide_choice_overlay()
	# await _advance_with_choice(chosen)


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


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
