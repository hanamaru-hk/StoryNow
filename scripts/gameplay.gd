extends Control

const CURRENT_VERSION := "1.0"
const CANTONESE_MALE_PITCH_SCALE := 0.7
const TTS_VOICE_BUS := "TTSVoice"
const GENERATING_IMAGE_PATH := "res://assets/images/generating.jpg"
const MUSIC_DIR := "data/music"

var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0
var _current_bgm_path: String = ""

# Requested public dialogue tracking vars
var current_dialogue_index: int = 0
var total_dialogue: int = 1

# Error dialog retry handling
signal retry_requested
var _pending_retry_action: String = ""  # "new_story" or "new_scene"
var _retry_in_progress: bool = false
var _chrome_visible: bool = true

func _ready() -> void:
	_set_chrome_visible(true)
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
	%GameplayMenuButton.pressed.connect(_on_gameplay_menu_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false
	%ImageActionNew.pressed.connect(_on_image_action_new_pressed)
	%ImageActionChange.pressed.connect(_on_image_action_change_pressed)
	%ImageActionBack.pressed.connect(_hide_image_action_overlay)
	%ImageChangePrev.pressed.connect(_on_image_change_prev_pressed)
	%ImageChangeNext.pressed.connect(_on_image_change_next_pressed)
	%ImageChangeSave.pressed.connect(_on_image_change_save_pressed)
	%ImageChangeBack.pressed.connect(_on_image_change_back_pressed)
	%ImageActionOverlay.visible = false
	%ImageChangeOverlay.visible = false

	# --- GameProgressOverlay (in-game advanced settings) ---
	if has_node("%GameProgressOverlay"):
		%GameProgressOverlay.closed.connect(_on_settings_closed)

	# --- Gameplay menu and settings overlays ---
	if has_node("%GameplayMenuOverlay"):
		%GameplayMenuOverlay.closed.connect(_on_settings_closed)
		%GameplayMenuOverlay.load_requested.connect(_on_gameplay_menu_load_requested)
		%GameplayMenuOverlay.gallery_requested.connect(_on_gameplay_menu_gallery_requested)
		%GameplayMenuOverlay.game_settings_requested.connect(_on_gameplay_menu_game_settings_requested)
		%GameplayMenuOverlay.advanced_settings_requested.connect(_on_gameplay_menu_advanced_settings_requested)
		%GameplayMenuOverlay.main_menu_requested.connect(_on_back_to_main_menu_requested)
		%GameplayMenuOverlay.quit_game_requested.connect(_on_quit_game_requested)
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.closed.connect(_on_settings_closed)
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.closed.connect(_on_settings_closed)
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.closed.connect(_on_settings_closed)
	if has_node("%AdvancedSettingsOverlay"):
		%AdvancedSettingsOverlay.closed.connect(_on_settings_closed)
		%AdvancedSettingsOverlay.image_settings_requested.connect(_on_image_server_setting_requested)
		%AdvancedSettingsOverlay.llm_settings_requested.connect(_on_llm_setting_requested)
	if has_node("%ImageServerSettingsOverlay"):
		%ImageServerSettingsOverlay.closed.connect(_on_settings_closed)
	if has_node("%LLMSettingsOverlay"):
		%LLMSettingsOverlay.closed.connect(_on_settings_closed)

	# --- ImageOverlay (extracted) ---
	if has_node("%ImageOverlay"):
		%ImageOverlay.closed.connect(_on_image_overlay_closed)
		%ImageOverlay.image_generated.connect(_on_image_generated)

	# --- PlotOverlay ---
	if has_node("%PlotOverlay"):
		%PlotOverlay.closed.connect(_on_plot_overlay_closed)

	# --- DialogueOverlay ---
	if has_node("%DialogueOverlay"):
		%DialogueOverlay.closed.connect(_on_dialogue_overlay_closed)
		%DialogueOverlay.dialogue_updated.connect(_on_dialogue_updated)

	# --- ErrorReturnPopup ---
	%ErrorReturnBack.pressed.connect(_on_error_return)
	%ErrorReturnRetry.pressed.connect(_on_error_retry_pressed)

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	_resize_choice_overlay_panel()

	# --- TTS auto-play ---
	if is_instance_valid(TTSManager) and TTSManager.has_signal("tts_generated") and not TTSManager.tts_generated.is_connected(_on_tts_generated):
		TTSManager.tts_generated.connect(_on_tts_generated)
	if is_instance_valid(TTSManager) and TTSManager.has_signal("batch_completed") and not TTSManager.batch_completed.is_connected(_on_tts_batch_completed):
		TTSManager.batch_completed.connect(_on_tts_batch_completed)

	_update_labels()
	_load_default_background()
	# Disable all SidePanel buttons except Setting and gameplay menu at start
	_set_all_side_buttons_disabled_except_settings_back()

	var startup_status := _load_startup_scene_status()
	match startup_status:
		"new_story":
			await _execute_new_story_flow()
		"new_scene":
			await _execute_new_scene_flow()
		"generating_image":
			await _execute_generating_image_flow()
		"generating_voice":
			_execute_generating_voice_flow()
		"generating_both":
			await _execute_generating_both_flow()
		"running":
			var uuid_running: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
			if SceneDataManager.scene_data.is_empty():
				var ok_running: bool = SceneDataManager.load_data(uuid_running)
				if ok_running:
					_scene_data = SceneDataManager.scene_data
				else:
					push_warning("Gameplay running: failed to load scene_data for uuid %s" % uuid_running)
					_scene_data = SceneDataManager.scene_data
					if _scene_data.is_empty():
						show_error(I18n.translate("error_failed_load_scene_data") % uuid_running)
			else:
				_scene_data = SceneDataManager.scene_data
			var recovered_empty_interactions := await _recover_empty_running_interactions()
			if recovered_empty_interactions:
				return
			# Restore dialogue index from GameProgressManager
			current_dialogue_index = int(GameProgressManager.settings.get("current_dialogue", 0))
			_current_dialog_idx = current_dialogue_index
			# Refresh dialogues and button panel
			_populate_dynamic_choice_buttons()
			_update_total_dialogue()
			# _update_total_dialogue may clamp index; sync back to local/manager
			_current_dialog_idx = current_dialogue_index
			_show_current_dialogue()
			var has_running_image := _load_current_scene_image(uuid_running)
			# Enable side buttons by eligibility and update labels
			_enable_all_side_buttons_by_eligibility()
			_update_labels()
			# Update TopBar title if available
			if has_node("%TitleLabel"):
				var title_text: String = str(SceneDataManager.scene_data.get("title", ""))
				if title_text.strip_edges().is_empty():
					title_text = str(SceneDataManager.scene_data.get("scene_prompt", SceneDataManager.scene_data.get("prompt", "")))
				if not title_text.strip_edges().is_empty():
					%TitleLabel.text = _format_title_with_round(title_text)
			%ChoiceOverlay.visible = false
			_play_scene_bgm()
			# Auto-play current dialogue wav if exists (prev_scene rule)
			_try_autoplay_current()
			await _recover_missing_running_assets(has_running_image)
		_:
			pass


func _load_startup_scene_status() -> String:
	var uuid := str(GameProgressManager.settings.get("current_uuid", "")).strip_edges()
	if not uuid.is_empty() and SceneDataManager.load_data(uuid):
		_scene_data = SceneDataManager.scene_data
		var scene_status := str(SceneDataManager.scene_data.get("game_status", "")).strip_edges()
		if not scene_status.is_empty():
			return scene_status
	return str(GameProgressManager.settings.get("game_status", "")).strip_edges()


func _set_scene_game_status(status: String, save_now: bool = true) -> void:
	SceneDataManager.scene_data["game_status"] = status
	if save_now:
		SceneDataManager.save()


func _set_game_status(status: String, save_now: bool = true) -> void:
	GameProgressManager.settings["game_status"] = status
	if save_now:
		GameProgressManager.save_settings()
	_set_scene_game_status(status, save_now)
	if is_inside_tree() and has_node("%NextSceneButton"):
		_update_button_eligibility()


func _current_game_status() -> String:
	var scene_status := str(SceneDataManager.scene_data.get("game_status", "")).strip_edges()
	if not scene_status.is_empty():
		return scene_status
	return str(GameProgressManager.settings.get("game_status", "")).strip_edges()


func _scene_has_voice_dialogue(scene_data: Dictionary) -> bool:
	var interactions: Array = scene_data.get("interactions", [])
	if not interactions is Array:
		return false
	for entry in interactions:
		if entry is Dictionary and not str((entry as Dictionary).get("dialogue", "")).strip_edges().is_empty():
			return true
	return false


func _begin_voice_generation(scene_data: Dictionary) -> bool:
	if scene_data.is_empty() or not _scene_has_voice_dialogue(scene_data):
		return false
	var status := _current_game_status()
	_set_game_status("generating_both" if status == "generating_image" else "generating_voice")
	TTSManager.generate_all_for_scene(scene_data)
	return true


func _begin_image_generation() -> void:
	var status := _current_game_status()
	if status == "generating_voice" or status == "generating_both":
		_set_game_status("generating_both")
	else:
		_set_game_status("generating_image")


func _finish_image_generation() -> void:
	var status := _current_game_status()
	if status == "generating_both":
		_set_game_status("generating_voice")
	elif status == "generating_image":
		_set_game_status("running")


func _finish_voice_generation() -> void:
	var status := _current_game_status()
	if status == "generating_both":
		_set_game_status("generating_image")
	elif status == "generating_voice":
		_set_game_status("running")


func _load_default_background() -> void:
	_set_no_image_label_visible(false)
	_load_placeholder_background(GENERATING_IMAGE_PATH, 0.5)


func _load_missing_save_background() -> void:
	%BackgroundImage.texture = null
	%BackgroundImage.modulate = Color(1, 1, 1, 1)
	_set_no_image_label_visible(true)


func _set_no_image_label_visible(is_visible: bool) -> void:
	var placeholder := _get_no_image_placeholder()
	placeholder.visible = is_visible


func _get_no_image_placeholder() -> Control:
	var placeholder: Control = null
	if %BackgroundImage.has_node("NoImagePlaceholder"):
		placeholder = %BackgroundImage.get_node("NoImagePlaceholder") as Control
	else:
		placeholder = CenterContainer.new()
		placeholder.name = "NoImagePlaceholder"
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		%BackgroundImage.add_child(placeholder)

		var bg := ColorRect.new()
		bg.color = Color.BLACK
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.add_child(bg)

		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 72)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_font_override("font", _create_no_image_font())
		label.text = "NO IMAGE"
		placeholder.add_child(label)
	return placeholder


func _create_no_image_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Black", "Arial"])
	return font


func _load_placeholder_background(res_path: String, alpha: float) -> void:
	# Runtime load to avoid requiring .import (handles missing Texture2D loader error).
	# Uses Image.load_from_file via globalized path, then ImageTexture.
	var global_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# Fallback: try direct res:// path (works if file is imported elsewhere)
		err = img.load(res_path)
	if err != OK:
		err = _load_image_from_file_access(img, res_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		%BackgroundImage.texture = tex
		%BackgroundImage.modulate = Color(1, 1, 1, alpha)
		_set_no_image_label_visible(false)
	else:
		# Final fallback: try ResourceLoader (requires import)
		var res_tex: Resource = load(res_path)
		if res_tex is Texture2D:
			%BackgroundImage.texture = res_tex
		else:
			push_warning("Failed to load placeholder background %s: %s" % [res_path, err])
		# Keep modulate for placeholder / 50% opacity
		%BackgroundImage.modulate = Color(1, 1, 1, alpha)


func _load_image_from_file_access(img: Image, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var lower_path := path.to_lower()
	if lower_path.ends_with(".png"):
		return img.load_png_from_buffer(bytes)
	if lower_path.ends_with(".jpg") or lower_path.ends_with(".jpeg"):
		return img.load_jpg_from_buffer(bytes)
	if lower_path.ends_with(".webp"):
		return img.load_webp_from_buffer(bytes)
	return ERR_FILE_UNRECOGNIZED


func _play_scene_bgm() -> void:
	var mood: String = _scene_bgm_mood()
	if mood.is_empty():
		_stop_scene_bgm()
		return
	var music_path: String = _pick_random_music_path(mood)
	if music_path.is_empty():
		push_warning("No music found for bgm mood: %s" % mood)
		_stop_scene_bgm()
		return
	if music_path == _current_bgm_path and _get_bgm_player().playing:
		return
	var stream: AudioStreamMP3 = AudioStreamMP3.load_from_file(music_path)
	if stream == null:
		push_warning("Failed to load bgm: %s" % music_path)
		_stop_scene_bgm()
		return
	stream.loop = true
	_current_bgm_path = music_path
	var player := _get_bgm_player()
	player.stream = stream
	player.play()


func _stop_scene_bgm() -> void:
	if not has_node("%BGMPlayer"):
		return
	var player := _get_bgm_player()
	player.stop()
	player.stream = null
	_current_bgm_path = ""


func _scene_bgm_mood() -> String:
	var mood: String = str(SceneDataManager.scene_data.get("bgm_mood", "")).strip_edges().to_lower()
	if mood.is_empty():
		mood = str(SceneDataManager.scene_data.get("music_mood", "")).strip_edges().to_lower()
	return mood


func _pick_random_music_path(mood: String) -> String:
	var dir_path: String = AppPaths.external_path(MUSIC_DIR.path_join(mood))
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var candidates: PackedStringArray = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and _is_supported_music_file(file_name):
			candidates.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _is_supported_music_file(file_name: String) -> bool:
	var lower_name: String = file_name.to_lower()
	return lower_name.ends_with(".mp3")


func _get_bgm_player() -> AudioStreamPlayer:
	if has_node("%BGMPlayer"):
		return %BGMPlayer as AudioStreamPlayer
	return $BGMPlayer as AudioStreamPlayer

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


func _is_at_choice_dialogue() -> bool:
	return current_dialogue_index >= total_dialogue - 1


func _can_open_choice_overlay() -> bool:
	return _current_game_status() == "running" and _is_at_choice_dialogue()


func _can_use_scene_navigation() -> bool:
	return _current_game_status() == "running"


func _current_dialogue_wav_exists() -> bool:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if interactions.is_empty():
		return false
	if current_dialogue_index < 0 or current_dialogue_index >= interactions.size():
		return false
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	var fname: String = str(entry.get("sound_filename", "")).strip_edges()
	if fname.is_empty():
		return false
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if uuid.is_empty():
		return false
	var path_user: String = "user://saves/%s/sounds/%s" % [uuid, fname]
	return FileAccess.file_exists(path_user)


func _all_voice_dialogues_have_sound_file() -> bool:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if not interactions is Array:
		return true
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if uuid.is_empty():
		return true
	for entry in interactions:
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry as Dictionary
		var dialogue := str(data.get("dialogue", "")).strip_edges()
		if dialogue.is_empty():
			continue
		var fname := str(data.get("sound_filename", data.get("sound_file", ""))).strip_edges()
		if fname.is_empty():
			return false
		if not FileAccess.file_exists("user://saves/%s/sounds/%s" % [uuid, fname]):
			return false
	return true


func _running_interactions_are_empty() -> bool:
	var interactions: Variant = SceneDataManager.scene_data.get("interactions", [])
	if not interactions is Array:
		return true
	return (interactions as Array).is_empty()


func _recover_empty_running_interactions() -> bool:
	if _current_game_status() != "running" or not _running_interactions_are_empty():
		return false
	if _is_prev_scene_exist():
		_set_game_status("new_scene")
		await _execute_new_scene_flow()
	else:
		_set_game_status("new_story")
		await _execute_new_story_flow()
	return true


func _recover_missing_running_assets(has_image: bool) -> void:
	if _current_game_status() != "running":
		return
	var started_voice := false
	if not _all_voice_dialogues_have_sound_file():
		started_voice = _begin_voice_generation(SceneDataManager.scene_data)
	if not has_image:
		_begin_image_generation()
		_update_button_eligibility()
		var comfy_ok := await _generate_comfyui_image()
		if not comfy_ok:
			return
		_finish_image_generation()
	if started_voice:
		_update_button_eligibility()
	else:
		_enable_all_side_buttons_by_eligibility()


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
	%GameplayMenuButton.disabled = false


func _update_button_eligibility() -> void:
	var is_running := _can_use_scene_navigation()
	%DialogButton.disabled = not is_running
	%ImageButton.disabled = not is_running
	%PlotButton.disabled = not is_running
	%PlayAudioButton.disabled = not _current_dialogue_wav_exists()
	%PrevDialogButton.disabled = not _is_prev_dialogue_exist()
	%NextDialogButton.disabled = not is_running and _is_at_choice_dialogue()
	%PrevSceneButton.disabled = not is_running or not _is_prev_scene_exist()
	%NextSceneButton.disabled = not is_running


func _enable_all_side_buttons_by_eligibility() -> void:
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
	for choice_index in choices.size():
		var choice = choices[choice_index]
		var text: String = ""
		if choice is Dictionary:
			# template uses "plot", fallback to common keys
			text = str(choice.get("plot", choice.get("text", choice.get("choice", ""))))
		else:
			text = str(choice)
		text = text.strip_edges()
		if text.is_empty():
			continue
		var display_text := text
		var was_previously_selected := choice is Dictionary and str(choice.get("plot", "")).strip_edges() != "" and str(choice.get("uuid", "")).strip_edges() != ""
		if was_previously_selected:
			var selected_prefix := I18n.translate("choice_previously_selected")
			if selected_prefix == "choice_previously_selected":
				selected_prefix = "Previously selected this choice"
			display_text = "***** %s ***** %s" % [selected_prefix, display_text]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)

		var row_height := _choice_row_height(display_text)
		if was_previously_selected:
			row.add_child(_make_previously_selected_choice_button(text, row_height))
		else:
			var btn := Button.new()
			btn.text = display_text
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.custom_minimum_size = Vector2(0, row_height)
			btn.pressed.connect(_on_dynamic_choice_pressed.bind(text))
			row.add_child(btn)

		var delete_btn := Button.new()
		delete_btn.text = I18n.translate("btn_delete") if I18n.translate("btn_delete") != "btn_delete" else "Delete"
		delete_btn.custom_minimum_size = Vector2(88, row_height)
		delete_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		delete_btn.pressed.connect(_on_dynamic_choice_delete_pressed.bind(choice_index))
		row.add_child(delete_btn)


func _on_dynamic_choice_pressed(choice_text: String) -> void:
	if has_node("%CustomInput"):
		%CustomInput.text = choice_text
	_on_choice_confirm()


func _make_previously_selected_choice_button(choice_text: String, row_height: float) -> Control:
	var selected_prefix := I18n.translate("choice_previously_selected")
	if selected_prefix == "choice_previously_selected":
		selected_prefix = "Previously selected this choice"
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, row_height)
	panel.gui_input.connect(_on_dynamic_choice_panel_input.bind(choice_text))
	panel.mouse_entered.connect(_on_dynamic_choice_panel_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_dynamic_choice_panel_hover.bind(panel, false))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.13, 1.0)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var rich_label := RichTextLabel.new()
	rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich_label.bbcode_enabled = true
	rich_label.fit_content = true
	rich_label.scroll_active = false
	rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.text = "[color=yellow]***** %s *****[/color] %s" % [_escape_bbcode(selected_prefix), _escape_bbcode(choice_text)]
	panel.add_child(rich_label)
	return panel


func _on_dynamic_choice_panel_input(event: InputEvent, choice_text: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_dynamic_choice_pressed(choice_text)


func _on_dynamic_choice_panel_hover(panel: PanelContainer, is_hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.22, 1.0) if is_hovered else Color(0.13, 0.13, 0.13, 1.0)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)


func _choice_row_height(display_text: String) -> float:
	var estimated_chars_per_line := 30
	var estimated_lines := ceili(float(display_text.length()) / float(estimated_chars_per_line))
	return maxf(44.0, 24.0 + float(maxi(1, estimated_lines)) * 30.0)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _on_dynamic_choice_delete_pressed(choice_index: int) -> void:
	var choices: Array = SceneDataManager.scene_data.get("choices", [])
	if not choices is Array:
		return
	if choice_index < 0 or choice_index >= choices.size():
		return
	choices.remove_at(choice_index)
	SceneDataManager.scene_data["choices"] = choices
	SceneDataManager.save()
	_populate_dynamic_choice_buttons()



func _generate_comfyui_image() -> bool:
	var image_prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	print_verbose("Generating ComfyUI image for scene_data: %s" % image_prompt)
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
	while true:
		var result: Dictionary = await ImageServerManager.generate_scene_image(image_prompt, uuid)
		if result.get("success", false):
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
			SceneDataManager.scene_data["current_image_index"] = arr.size() - 1
			SceneDataManager.save()
			_scene_data = SceneDataManager.scene_data
			print_verbose("Saved ComfyUI image to %s, image_filenames: %s" % [save_path, str(arr)])
			_pending_retry_action = ""
			return true
		_pending_retry_action = "comfyui_image"
		show_error(str(result.get("error", I18n.translate("error_failed_generate_image"))), true, "comfyui_image")
		await retry_requested
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return false
		# Refresh prompt/uuid before retry (in case scene_data changed)
		image_prompt = str(SceneDataManager.scene_data.get("image_prompt", image_prompt))
		uuid = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", uuid)))
	return false


func _set_background_from_file(user_path: String) -> bool:
	# user_path is like user://saves/.../images/SN_00001_.png
	var global_path := ProjectSettings.globalize_path(user_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# try direct user:// path (Godot 4 may load user:// directly)
		err = img.load(user_path)
	if err != OK:
		err = _load_image_from_file_access(img, user_path)
	if err != OK:
		push_warning("Failed to load generated image %s: %s" % [user_path, error_string(err)])
		_load_missing_save_background()
		return false
	var tex := ImageTexture.create_from_image(img)
	%BackgroundImage.texture = tex
	%BackgroundImage.modulate = Color(1, 1, 1, 1)
	_set_no_image_label_visible(false)
	return true


func _is_image_filename(file_name: String) -> bool:
	var lower_name := file_name.to_lower()
	return lower_name.ends_with(".png") or lower_name.ends_with(".jpg") or lower_name.ends_with(".jpeg") or lower_name.ends_with(".webp")


func _get_scene_image_filenames(uuid: String = "") -> Array:
	var resolved_uuid := uuid.strip_edges()
	if resolved_uuid.is_empty():
		resolved_uuid = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	var images_dir := "user://saves/%s/images" % resolved_uuid
	var image_files: Array = []
	var saved_filenames: Variant = SceneDataManager.scene_data.get("image_filenames", [])
	if saved_filenames is Array:
		for value in saved_filenames as Array:
			var file_name := str(value).strip_edges()
			if file_name.is_empty() or not _is_image_filename(file_name):
				continue
			if FileAccess.file_exists("%s/%s" % [images_dir, file_name]):
				image_files.append(file_name)
	return image_files


func _load_current_scene_image(uuid: String = "") -> bool:
	var resolved_uuid := uuid.strip_edges()
	if resolved_uuid.is_empty():
		resolved_uuid = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	var image_files := _get_scene_image_filenames(resolved_uuid)
	if image_files.is_empty():
		print_verbose("Gameplay running: no images found for %s, using no-image background" % resolved_uuid)
		_load_missing_save_background()
		return false
	var current_index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	current_index = clampi(current_index, 0, image_files.size() - 1)
	SceneDataManager.scene_data["current_image_index"] = current_index
	return _set_background_from_file("user://saves/%s/images/%s" % [resolved_uuid, str(image_files[current_index])])

# ------------------------------------------------------------------
# Input handlers
# ------------------------------------------------------------------
# Trigger: virtual Node._input / _unhandled_input — called automatically by Godot's
# input dispatch (no signal connection needed). _input is used so right-click
# works even when GUI Controls (Dialogue/TopBar) would otherwise mark the event
# as handled and prevent _unhandled_input from firing.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not _chrome_visible:
		_set_chrome_visible(true)
		get_viewport().set_input_as_handled()
		return
	if _has_blocking_overlay_visible():
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and _is_background_click(mouse_event.position):
		_set_chrome_visible(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_choice_overlay_panel()


func _toggle_chrome() -> void:
	_set_chrome_visible(not _chrome_visible)


func _set_chrome_visible(is_visible: bool) -> void:
	_chrome_visible = is_visible
	if has_node("%TopBar"):
		%TopBar.visible = is_visible
	if has_node("%Dialogue"):
		%Dialogue.visible = is_visible
	ServerRuntimeManager.set_chrome_visible(is_visible)


func _is_background_click(position: Vector2) -> bool:
	var is_on_background: bool = _is_point_inside_control(%BackgroundImage, position)
	var is_on_top_bar: bool = _is_point_inside_visible_control(%TopBar, position)
	var is_on_dialogue: bool = _is_point_inside_visible_control(%Dialogue, position)
	return is_on_background and not is_on_top_bar and not is_on_dialogue


func _has_blocking_overlay_visible() -> bool:
	var overlay_names: Array[String] = [
		"ChoiceOverlay",
		"ImageActionOverlay",
		"ImageChangeOverlay",
		"ImageOverlay",
		"PlotOverlay",
		"DialogueOverlay",
		"GameplayMenuOverlay",
		"LoadGameOverlay",
		"GalleryOverlay",
		"GameSettingsOverlay",
		"AdvancedSettingsOverlay",
		"ImageServerSettingsOverlay",
		"LLMSettingsOverlay",
		"GameProgressOverlay",
		"ErrorReturnPopup",
	]
	for overlay_name in overlay_names:
		var overlay: Node = get_node_or_null(overlay_name)
		if overlay is CanvasItem and (overlay as CanvasItem).visible:
			return true
	return false


func _is_point_inside_visible_control(control: Control, position: Vector2) -> bool:
	return control.visible and _is_point_inside_control(control, position)


func _is_point_inside_control(control: Control, position: Vector2) -> bool:
	return control.get_global_rect().has_point(position)


func _resize_choice_overlay_panel() -> void:
	var panel := get_node_or_null("ChoiceOverlay/CenterContainer/Panel")
	if panel is Control:
		var viewport_size := get_viewport_rect().size
		(panel as Control).custom_minimum_size = viewport_size * 0.7


func _on_dialog_area_input(event: InputEvent) -> void:
	pass


func _on_prev_dialog_pressed() -> void:
	if total_dialogue <= 1:
		return
	if current_dialogue_index > 0:
		_stop_tts_if_playing()
		current_dialogue_index -= 1
		GameProgressManager.settings["current_dialogue"] = current_dialogue_index
		GameProgressManager.save_settings()
		_show_current_dialogue()
		_update_button_eligibility()
		_try_autoplay_current()


func _on_next_dialog_pressed() -> void:
	# Spec: if (current_dialogue_index > total_dialogue) show choice overlay
	if current_dialogue_index > total_dialogue:
		if _can_open_choice_overlay():
			_show_choice_overlay()
		return
	# Also handle end-of-dialogue -> choice overlay (index at last dialogue)
	if current_dialogue_index >= total_dialogue - 1:
		if _can_open_choice_overlay():
			_show_choice_overlay()
		return
	if total_dialogue <= 1:
		return
	if current_dialogue_index < total_dialogue - 1:
		_stop_tts_if_playing()
		current_dialogue_index += 1
		GameProgressManager.settings["current_dialogue"] = current_dialogue_index
		GameProgressManager.save_settings()
		_show_current_dialogue()
		_update_button_eligibility()
		_try_autoplay_current()


func _on_prev_scene_pressed() -> void:
	if not _can_use_scene_navigation():
		return
	if not _is_prev_scene_exist():
		return
	var prev_uuid: String = str(SceneDataManager.scene_data.get("prev_uuid", "")).strip_edges()
	if prev_uuid.is_empty():
		return
	GameProgressManager.settings["current_uuid"] = prev_uuid
	GameProgressManager.settings["game_status"] = "running"
	var cur_round: int = int(GameProgressManager.settings.get("current_round", 1))
	GameProgressManager.settings["current_round"] = cur_round - 1
	GameProgressManager.settings["current_dialogue"] = 0
	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_next_scene_pressed() -> void:
	if not _can_use_scene_navigation():
		return
	_show_choice_overlay()


func _on_dialog_btn_pressed() -> void:
	if has_node("%DialogueOverlay"):
		%DialogueOverlay.open()


func _on_dialogue_overlay_closed() -> void:
	_update_labels()


func _on_dialogue_updated() -> void:
	_update_total_dialogue()
	_show_current_dialogue()
	_update_button_eligibility()
	_update_labels()
	_try_autoplay_current()


func _on_image_btn_pressed() -> void:
	_show_image_action_overlay()


func _show_image_action_overlay() -> void:
	%ImageActionOverlay.visible = true


func _hide_image_action_overlay() -> void:
	%ImageActionOverlay.visible = false


func _on_image_action_new_pressed() -> void:
	_hide_image_action_overlay()
	if has_node("%ImageOverlay"):
		%ImageOverlay.open()
	else:
		# Fallback inline behavior if overlay not instanced — with retry
		var prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
		if prompt.strip_edges().is_empty():
			show_error(I18n.translate("image_prompt_empty"))
			return
		var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
		while true:
			var result: Dictionary = await ImageServerManager.generate_scene_image(prompt, uuid)
			if result.get("success", false):
				var save_path: String = str(result.get("save_path", ""))
				var filename: String = str(result.get("filename", ""))
				if not SceneDataManager.scene_data.has("image_filenames") or not SceneDataManager.scene_data["image_filenames"] is Array:
					SceneDataManager.scene_data["image_filenames"] = []
				var arr: Array = SceneDataManager.scene_data["image_filenames"]
				arr.append(filename)
				SceneDataManager.scene_data["image_filenames"] = arr
				SceneDataManager.scene_data["current_image_index"] = arr.size() - 1
				SceneDataManager.save()
				_set_background_from_file(save_path)
				_pending_retry_action = ""
				break
			_pending_retry_action = "comfyui_image"
			show_error(str(result.get("error", I18n.translate("error_failed_generate_image"))), true, "comfyui_image")
			await retry_requested
			await get_tree().create_timer(0.1).timeout
			if not is_instance_valid(self) or not is_inside_tree():
				return
			# Refresh prompt/uuid before retry
			prompt = str(SceneDataManager.scene_data.get("image_prompt", prompt))
			uuid = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", uuid)))


func _on_image_action_change_pressed() -> void:
	_hide_image_action_overlay()
	_open_image_change_overlay()


func _open_image_change_overlay() -> void:
	var image_files := _get_scene_image_filenames()
	if image_files.is_empty():
		show_error(I18n.translate("image_no_saved_for_scene"))
		return
	var current_index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	SceneDataManager.scene_data["current_image_index"] = clampi(current_index, 0, image_files.size() - 1)
	%ImageChangeOverlay.visible = true
	_refresh_image_change_overlay()


func _refresh_image_change_overlay() -> void:
	var image_files := _get_scene_image_filenames()
	if image_files.is_empty():
		%ImagePreview.texture = null
		%ImageChangeLabel.text = I18n.translate("image_change_title")
		%ImageChangePrev.disabled = true
		%ImageChangeNext.disabled = true
		%ImageChangeSave.disabled = true
		return
	var current_index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	current_index = clampi(current_index, 0, image_files.size() - 1)
	SceneDataManager.scene_data["current_image_index"] = current_index
	var uuid := str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	var image_path := "user://saves/%s/images/%s" % [uuid, str(image_files[current_index])]
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(image_path))
	if err != OK:
		err = img.load(image_path)
	if err == OK:
		%ImagePreview.texture = ImageTexture.create_from_image(img)
	else:
		%ImagePreview.texture = null
	%ImageChangeLabel.text = I18n.translate("image_change_counter") % [current_index + 1, image_files.size()]
	%ImageChangePrev.disabled = image_files.size() <= 1
	%ImageChangeNext.disabled = image_files.size() <= 1
	%ImageChangeSave.disabled = false


func _on_image_change_prev_pressed() -> void:
	var image_files := _get_scene_image_filenames()
	if image_files.is_empty():
		return
	var current_index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	SceneDataManager.scene_data["current_image_index"] = (current_index - 1 + image_files.size()) % image_files.size()
	_refresh_image_change_overlay()


func _on_image_change_next_pressed() -> void:
	var image_files := _get_scene_image_filenames()
	if image_files.is_empty():
		return
	var current_index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	SceneDataManager.scene_data["current_image_index"] = (current_index + 1) % image_files.size()
	_refresh_image_change_overlay()


func _on_image_change_save_pressed() -> void:
	if _load_current_scene_image():
		SceneDataManager.save()
	%ImageChangeOverlay.visible = false
	_update_labels()


func _on_image_change_back_pressed() -> void:
	%ImageChangeOverlay.visible = false
	_show_image_action_overlay()


func _on_image_overlay_closed() -> void:
	_update_labels()


func _on_image_generated(_save_path: String, _filename: String) -> void:
	# Overlay already appended and refreshed background; keep hook for future
	_load_current_scene_image()
	_update_labels()


func _on_plot_pressed() -> void:
	if has_node("%PlotOverlay"):
		%PlotOverlay.open()


func _on_plot_overlay_closed() -> void:
	_update_labels()


func _on_setting_pressed() -> void:
	if has_node("%GameProgressOverlay"):
		%GameProgressOverlay.open()


func _on_gameplay_menu_pressed() -> void:
	if has_node("%GameplayMenuOverlay"):
		%GameplayMenuOverlay.open()


func _on_gameplay_menu_load_requested() -> void:
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.open()


func _on_gameplay_menu_gallery_requested() -> void:
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.open()


func _on_gameplay_menu_game_settings_requested() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_gameplay_menu_advanced_settings_requested() -> void:
	if has_node("%AdvancedSettingsOverlay"):
		%AdvancedSettingsOverlay.open()


func _on_image_server_setting_requested() -> void:
	if has_node("%ImageServerSettingsOverlay"):
		%ImageServerSettingsOverlay.open()


func _on_llm_setting_requested() -> void:
	if has_node("%LLMSettingsOverlay"):
		%LLMSettingsOverlay.open()


func _on_back_to_main_menu_requested() -> void:
	if _current_game_status() != "running":
		await ServerRuntimeManager.cancel_active_generation_tasks()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_game_requested() -> void:
	get_tree().quit()


func _on_play_audio_pressed() -> void:
	if not _current_dialogue_wav_exists():
		_update_button_eligibility()
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	var fname: String = str(entry.get("sound_filename", "")).strip_edges()
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	var path_user: String = "user://saves/%s/sounds/%s" % [uuid, fname]
	_play_wav(ProjectSettings.globalize_path(path_user))


func _get_tts_player() -> AudioStreamPlayer:
	if has_node("%TTSPlayer"):
		return %TTSPlayer as AudioStreamPlayer
	if has_node("TTSPlayer"):
		return $TTSPlayer as AudioStreamPlayer
	return null


func _stop_tts_if_playing() -> void:
	var p := _get_tts_player()
	if p and p.playing:
		p.stop()


func _play_wav(global_path: String) -> void:
	var player := _get_tts_player()
	if player == null:
		push_warning("TTSPlayer not found")
		return
	if player.playing:
		player.stop()
	player.pitch_scale = 1.0
	var pitch_effect := _get_tts_pitch_effect(player)
	if pitch_effect != null:
		pitch_effect.pitch_scale = _tts_pitch_scale_for_current_dialogue()
	# AudioStreamWAV.load_from_file is Godot 4.2+ static helper
	var stream: AudioStreamWAV = null
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(ProjectSettings.localize_path(global_path)):
		# Try static loader if available
		if ClassDB.class_has_method("AudioStreamWAV", "load_from_file"):
			stream = AudioStreamWAV.load_from_file(global_path)
		if stream == null:
			# Fallback: load via FileAccess and parse WAV header (16-bit PCM)
			stream = _load_wav_from_file(global_path)
	else:
		# Try user:// path directly
		var user_path := ProjectSettings.localize_path(global_path)
		if FileAccess.file_exists(user_path) and ClassDB.class_has_method("AudioStreamWAV", "load_from_file"):
			stream = AudioStreamWAV.load_from_file(global_path)
	if stream == null:
		push_warning("Failed to load wav: %s" % global_path)
		return
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stream = stream
	player.play()


func _get_tts_pitch_effect(player: AudioStreamPlayer) -> AudioEffectPitchShift:
	var bus_index := AudioServer.get_bus_index(TTS_VOICE_BUS)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, TTS_VOICE_BUS)
		AudioServer.set_bus_send(bus_index, "Master")
	player.bus = TTS_VOICE_BUS
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectPitchShift:
			return effect as AudioEffectPitchShift
	var pitch_effect := AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus_index, pitch_effect)
	return pitch_effect


func _tts_pitch_scale_for_current_dialogue() -> float:
	var language := str(SceneDataManager.scene_data.get("language", I18n.current_lang)).strip_edges().to_lower()
	if language != "yue" and language != "zh_hk" and not language.contains("cantonese"):
		return 1.0
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if current_dialogue_index < 0 or current_dialogue_index >= interactions.size():
		return 1.0
	var entry = interactions[current_dialogue_index]
	if not entry is Dictionary:
		return 1.0
	var sex := str((entry as Dictionary).get("sex", "male")).strip_edges().to_lower()
	if sex == "male" or sex == "man" or sex == "boy":
		return CANTONESE_MALE_PITCH_SCALE
	return 1.0


func _load_wav_from_file(global_path: String) -> AudioStreamWAV:
	# Minimal WAV loader for 16-bit PCM (sherpa outputs 16kHz mono)
	var file_path := global_path
	# If global_path is like C:/..., try also user:// localize
	if not FileAccess.file_exists(file_path):
		file_path = ProjectSettings.localize_path(global_path)
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return null
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if data.size() < 44:
		return null
	# Basic validation: RIFF/WAVE
	if data[0] != 0x52 or data[1] != 0x49 or data[2] != 0x46 or data[3] != 0x46:
		return null
	var wav := AudioStreamWAV.new()
	# Parse fmt chunk to get sample rate / channels
	var sample_rate: int = 16000
	var channels: int = 1
	var bits_per_sample: int = 16
	# Search for "fmt " chunk
	for i in range(0, min(data.size() - 8, 256)):
		if data[i] == 0x66 and data[i+1] == 0x6D and data[i+2] == 0x74 and data[i+3] == 0x20:
			if i + 24 < data.size():
				channels = data[i+10] | (data[i+11] << 8)
				sample_rate = data[i+12] | (data[i+13] << 8) | (data[i+14] << 16) | (data[i+15] << 24)
				bits_per_sample = data[i+22] | (data[i+23] << 8)
			break
	# Find data chunk
	var data_offset: int = 44
	for i in range(12, min(data.size() - 8, 1024)):
		if data[i] == 0x64 and data[i+1] == 0x61 and data[i+2] == 0x74 and data[i+3] == 0x61:
			var chunk_size: int = data[i+4] | (data[i+5] << 8) | (data[i+6] << 16) | (data[i+7] << 24)
			data_offset = i + 8
			if chunk_size > 0 and data_offset + chunk_size <= data.size():
				data = data.slice(data_offset, data_offset + chunk_size)
			else:
				data = data.slice(data_offset)
			break
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.stereo = channels == 2
	wav.mix_rate = sample_rate
	return wav


func _try_autoplay_current() -> void:
	if not bool(GameSettingsManager.settings.get("autoplay_tts", true)):
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if interactions.is_empty():
		return
	if current_dialogue_index < 0 or current_dialogue_index >= interactions.size():
		return
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	var fname: String = str(entry.get("sound_filename", "")).strip_edges()
	if fname.is_empty():
		return
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if uuid.is_empty():
		uuid = str(GameProgressManager.settings.get("current_uuid", "")).strip_edges()
	if uuid.is_empty():
		return
	var user_path: String = "user://saves/%s/sounds/%s" % [uuid, fname]
	if not FileAccess.file_exists(user_path):
		return
	_play_wav(ProjectSettings.globalize_path(user_path))


func _on_tts_generated(uuid: String, idx: int, sound_filename: String, save_path: String) -> void:
	var cur_uuid: String = str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if cur_uuid != uuid:
		return
	if idx != current_dialogue_index:
		return
	_update_button_eligibility()
	if not bool(GameSettingsManager.settings.get("autoplay_tts", true)):
		return
	# Ensure file exists before play
	if not FileAccess.file_exists(save_path):
		return
	_play_wav(ProjectSettings.globalize_path(save_path))


func _on_tts_batch_completed(uuid: String) -> void:
	var cur_uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if cur_uuid != uuid:
		return
	_finish_voice_generation()
	_enable_all_side_buttons_by_eligibility()


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


func _format_title_with_round(title: String) -> String:
	var t := title.strip_edges()
	if t.is_empty():
		return ""
	var cur_round: int = int(GameProgressManager.settings.get("current_round", 1))
	return "%d. %s" % [cur_round, t]


func _apply_title_from_result(result_title: String, fallback_data: Dictionary = {}) -> void:
	if not has_node("%TitleLabel"):
		return
	var t: String = result_title.strip_edges()
	if t.is_empty() and not fallback_data.is_empty():
		t = str(fallback_data.get("title", "")).strip_edges()
	if t.is_empty():
		return
	%TitleLabel.text = _format_title_with_round(t)


func _should_force_story_end() -> bool:
	var current_round := int(GameProgressManager.settings.get("current_round", SceneDataManager.scene_data.get("current_round", 0)))
	var expected_rounds := int(GameProgressManager.settings.get("expected_rounds", SceneDataManager.scene_data.get("expected_rounds", 0)))
	return expected_rounds > 0 and current_round >= expected_rounds


func _handle_new_story() -> bool:
	var result: Dictionary = await LLMManager.request_new_story()
	print_verbose("LLM request_new_story result: %s" % str(result))
	# Apply title field from _request_completion immediately when request finishes
	_apply_title_from_result(str(result.get("title", "")))
	if not result.get("success", false):
		_pending_retry_action = "new_story"
		show_error(str(result.get("error", "Failed to generate story")), true)
		return false
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
			_pending_retry_action = "new_story"
			show_error(I18n.translate("error_llm_invalid_json") , true)
			return false
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
	if not SceneDataManager.scene_data.has("current_image_index"):
		SceneDataManager.scene_data["current_image_index"] = 0
	if _should_force_story_end():
		SceneDataManager.scene_data["end"] = true
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	_play_scene_bgm()
	# Apply title field to TitleLabel when request finishes
	_apply_title_from_result(str(llm_data.get("title", result.get("title", ""))), llm_data)
	# Keep legacy progress status aligned while scene_data owns resumable status.
	_begin_image_generation()
	# Non-blocking TTS generation for all dialogues
	_begin_voice_generation(SceneDataManager.scene_data)
	print_verbose("Final scene data: " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings: " + str(GameProgressManager.settings))
	return true


func _handle_new_scene() -> bool:
	var result: Dictionary = await LLMManager.request_new_scene()
	print_verbose("LLM request_new_scene result: %s" % str(result))
	_apply_title_from_result(str(result.get("title", "")))
	if not result.get("success", false):
		_pending_retry_action = "new_scene"
		show_error(str(result.get("error", "Failed to generate scene")), true)
		return false
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
			_pending_retry_action = "new_scene"
			show_error(I18n.translate("error_llm_invalid_json"), true)
			return false
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
	if not SceneDataManager.scene_data.has("current_image_index"):
		SceneDataManager.scene_data["current_image_index"] = 0
	if not SceneDataManager.scene_data.has("id"):
		SceneDataManager.scene_data["id"] = preserved_uuid
	if _should_force_story_end():
		SceneDataManager.scene_data["end"] = true
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	_play_scene_bgm()
	_apply_title_from_result(str(llm_data.get("title", result.get("title", ""))), llm_data)
	_begin_image_generation()
	# Non-blocking TTS generation for all dialogues (scene)
	_begin_voice_generation(SceneDataManager.scene_data)
	print_verbose("Final scene data (scene): " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings (scene): " + str(GameProgressManager.settings))
	return true
# ------------------------------------------------------------------
# New story/scene flow with retry support (called from _ready)
# ------------------------------------------------------------------
func _execute_new_story_flow() -> void:
	var uuid: String = str(GameProgressManager.settings.get("current_uuid", ""))
	var ok: bool = SceneDataManager.load_data(uuid)
	if ok:
		_scene_data = SceneDataManager.scene_data
	print_verbose("")
	print_verbose("GameProgressManager.settings: %s" % str(GameProgressManager.settings))
	print_verbose("")
	print_verbose("SceneDataManager.scene_data (pre-story): %s" % str(SceneDataManager.scene_data))
	# Retry loop: handles invalid JSON / request failures infinitely until success or return to menu
	while true:
		_pending_retry_action = "new_story"
		var success: bool = await _handle_new_story()
		if success:
			_pending_retry_action = ""
			break
		# Failure: dialog shown with Retry – wait for retry signal; Return will change scene and abort loop
		await retry_requested
		# Allow dialog to hide before next attempt
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
	# --- After new_story: populate dynamic choice buttons above CustomInput ---
	_populate_dynamic_choice_buttons()
	# --- After new_story: update dialogue tracking and trigger image generation ---
	_begin_image_generation()
	_update_total_dialogue()
	_show_current_dialogue()
	_update_button_eligibility()
	var comfy_ok: bool = await _generate_comfyui_image()
	if not comfy_ok:
		return
	_finish_image_generation()
	_enable_all_side_buttons_by_eligibility()
	_pending_retry_action = ""


func _execute_new_scene_flow() -> void:
	var uuid_new_scene: String = str(GameProgressManager.settings.get("current_uuid", ""))
	var ok_new_scene: bool = SceneDataManager.load_data(uuid_new_scene)
	if ok_new_scene:
		_scene_data = SceneDataManager.scene_data
	print_verbose("")
	print_verbose("GameProgressManager.settings: %s" % str(GameProgressManager.settings))
	print_verbose("")
	print_verbose("SceneDataManager.scene_data (pre-scene): %s" % str(SceneDataManager.scene_data))
	# Retry loop: same pattern as new_story – infinite retries until success
	while true:
		_pending_retry_action = "new_scene"
		var success: bool = await _handle_new_scene()
		if success:
			_pending_retry_action = ""
			break
		await retry_requested
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
	# --- After new_scene: populate dynamic choice buttons above CustomInput ---
	_populate_dynamic_choice_buttons()
	# --- After new_scene: update dialogue tracking and trigger image generation ---
	_begin_image_generation()
	_update_total_dialogue()
	_show_current_dialogue()
	_update_button_eligibility()
	var comfy_ok2: bool = await _generate_comfyui_image()
	if not comfy_ok2:
		return
	_finish_image_generation()
	_enable_all_side_buttons_by_eligibility()
	_pending_retry_action = ""


func _prepare_generating_resume_flow(load_image: bool = false) -> String:
	var uuid := str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if SceneDataManager.scene_data.is_empty() and not uuid.is_empty():
		if SceneDataManager.load_data(uuid):
			_scene_data = SceneDataManager.scene_data
	if SceneDataManager.scene_data.is_empty():
		show_error(I18n.translate("error_failed_load_scene_data") % uuid)
		return ""
	_populate_dynamic_choice_buttons()
	_update_total_dialogue()
	_show_current_dialogue()
	_play_scene_bgm()
	if load_image:
		_load_current_scene_image(uuid)
	else:
		_update_button_eligibility()
	return uuid


func _execute_generating_image_flow() -> void:
	var uuid := _prepare_generating_resume_flow()
	if uuid.is_empty():
		return
	_begin_image_generation()
	var comfy_ok := await _generate_comfyui_image()
	if not comfy_ok:
		return
	_finish_image_generation()
	_enable_all_side_buttons_by_eligibility()
	_pending_retry_action = ""


func _execute_generating_both_flow() -> void:
	var uuid := _prepare_generating_resume_flow()
	if uuid.is_empty():
		return
	_begin_image_generation()
	_begin_voice_generation(SceneDataManager.scene_data)
	var comfy_ok := await _generate_comfyui_image()
	if not comfy_ok:
		return
	_finish_image_generation()
	_enable_all_side_buttons_by_eligibility()
	_pending_retry_action = ""


func _execute_generating_voice_flow() -> void:
	var uuid := _prepare_generating_resume_flow(true)
	if uuid.is_empty():
		return
	_set_game_status("generating_voice")
	if not _begin_voice_generation(SceneDataManager.scene_data):
		_finish_voice_generation()
	_enable_all_side_buttons_by_eligibility()


# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	var story_has_ended := _is_story_end()
	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	if has_node("%StoryEndLabel"):
		%StoryEndLabel.visible = story_has_ended
		%StoryEndLabel.text = _story_end_message()
	if has_node("%ChoiceScroll"):
		%ChoiceScroll.visible = not story_has_ended
	if story_has_ended:
		if has_node("%DynamicChoiceButtons"):
			for child in %DynamicChoiceButtons.get_children():
				child.queue_free()
	else:
		_populate_dynamic_choice_buttons()
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false
	if has_node("%StoryEndLabel"):
		%StoryEndLabel.visible = false
	if has_node("%ChoiceScroll"):
		%ChoiceScroll.visible = true


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
		SceneDataManager.scene_data["end"] = false
		SceneDataManager.save()

		GameProgressManager.settings["game_status"] = "new_scene"
		GameProgressManager.settings["player_input"] = stripped_text
		GameProgressManager.settings["current_uuid"] = uuid

		# create new scene data using the new uuid
		SceneDataManager.scene_data["uuid"] = uuid
		SceneDataManager.scene_data["prev_uuid"] = prev_uuid
		SceneDataManager.scene_data["image_filenames"] = []
		SceneDataManager.scene_data["current_image_index"] = 0
		SceneDataManager.scene_data["image_prompt"] = ""
		SceneDataManager.scene_data["instruction"] = []
		SceneDataManager.scene_data["interactions"] = []
		SceneDataManager.scene_data["language"] = I18n.current_lang
		SceneDataManager.scene_data["summary"] = ""
		SceneDataManager.scene_data["version"] = CURRENT_VERSION
		SceneDataManager.scene_data["current_round"] = cur_round + 1
		SceneDataManager.scene_data["player_input"] = stripped_text
		SceneDataManager.scene_data["game_status"] = "new_scene"

		SceneDataManager.scene_data["choices"] = []
		SceneDataManager.save()

	
	



	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


func _is_story_end() -> bool:
	return bool(SceneDataManager.scene_data.get("end", false))


func _story_end_message() -> String:
	return I18n.translate("story_end_message")


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
# Error handling — common error return popup for returning to main menu
# ------------------------------------------------------------------
func _update_error_popup_retry_visibility(allow_retry: bool) -> void:
	%ErrorReturnRetry.visible = allow_retry
	%ErrorReturnRetry.disabled = not allow_retry or _retry_in_progress
	var retry_text: String = I18n.translate("btn_retry")
	if retry_text == "btn_retry":
		retry_text = "Retry"
	%ErrorReturnRetry.text = retry_text


func show_error(message: String, allow_retry: bool = false, retry_action: String = "") -> void:
	if not retry_action.is_empty():
		_pending_retry_action = retry_action
	# If retry is allowed but no pending action has been set, do not show retry
	if allow_retry and _pending_retry_action.is_empty():
		allow_retry = false
	_update_error_popup_retry_visibility(allow_retry and not _pending_retry_action.is_empty())
	%ErrorReturnMessage.text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnTitle.text = I18n.translate("error_dialog_title")
	%ErrorReturnPopup.visible = true


func _on_error_retry_pressed() -> void:
	if _pending_retry_action.is_empty() or _retry_in_progress:
		return
	_retry_in_progress = true
	_update_error_popup_retry_visibility(false)
	%ErrorReturnPopup.visible = false
	# Emit signal for the retry loop in _execute_*_flow; loop will clear pending on next iteration
	await get_tree().create_timer(0.05).timeout
	_retry_in_progress = false
	retry_requested.emit()


func _on_error_return() -> void:
	_pending_retry_action = ""
	_retry_in_progress = false
	_update_error_popup_retry_visibility(false)
	%ErrorReturnPopup.visible = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	# Title / Dialog generating placeholders
	if has_node("%TitleLabel"):
		var cur_title: String = %TitleLabel.text.strip_edges()
		if cur_title == "Generating Title..." or cur_title == I18n.translate("generating_title") or cur_title.is_empty():
			var t_title: String = I18n.translate("generating_title")
			%TitleLabel.text = t_title if t_title != "generating_title" else "Generating Title..."
	if has_node("%DialogLabel"):
		var cur_dialog: String = %DialogLabel.text.strip_edges()
		if cur_dialog == "Generating the gameplay..." or cur_dialog == I18n.translate("generating_gameplay") or cur_dialog.is_empty():
			var t_gen: String = I18n.translate("generating_gameplay")
			%DialogLabel.text = t_gen if t_gen != "generating_gameplay" else "Generating the gameplay..."
	%DialogButton.text = I18n.translate("btn_dialog") if I18n.translate("btn_dialog") != "btn_dialog" else "Dialogue"
	%ImageButton.text = I18n.translate("btn_image") if I18n.translate("btn_image") != "btn_image" else "Image"
	%PlotButton.text = I18n.translate("btn_plot") if I18n.translate("btn_plot") != "btn_plot" else "Plot"
	%PlayAudioButton.text = I18n.translate("btn_play_audio") if I18n.translate("btn_play_audio") != "btn_play_audio" else "Play"
	%PrevDialogButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Dialogue"
	%NextDialogButton.text = I18n.translate("btn_next_dialog") if I18n.translate("btn_next_dialog") != "btn_next_dialog" else "Dialogue >"
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "<< Scene"
	%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Scene >>"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%GameplayMenuButton.text = I18n.translate("btn_gameplay_menu") if I18n.translate("btn_gameplay_menu") != "btn_gameplay_menu" else "Menu"
	# Choice overlay
	var choice_title: String = I18n.translate("choice_title")
	if has_node("%ChoiceTitle"):
		%ChoiceTitle.text = choice_title if choice_title != "choice_title" else "Choose Next Step"
	else:
		var ct_node := get_node_or_null("ChoiceOverlay/CenterContainer/Panel/Margin/VBox/Title")
		if ct_node is Label:
			(ct_node as Label).text = choice_title if choice_title != "choice_title" else "Choose Next Step"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	# Image action overlay
	if has_node("%ImageActionNew"):
		var t_new: String = I18n.translate("image_action_new")
		%ImageActionNew.text = t_new if t_new != "image_action_new" else "New"
	if has_node("%ImageActionChange"):
		var t_change: String = I18n.translate("image_action_change")
		%ImageActionChange.text = t_change if t_change != "image_action_change" else "Change"
	if has_node("%ImageActionBack"):
		var t_back: String = I18n.translate("btn_back")
		%ImageActionBack.text = t_back if t_back != "btn_back" else "Back"
	# Image change overlay
	if has_node("%ImageChangeBack"):
		var t_ic_back: String = I18n.translate("btn_back")
		%ImageChangeBack.text = t_ic_back if t_ic_back != "btn_back" else "Back"
	if has_node("%ImageChangeSave"):
		var t_ic_save: String = I18n.translate("btn_save")
		%ImageChangeSave.text = t_ic_save if t_ic_save != "btn_save" else "Save"
	if has_node("%ImageOverlay") and %ImageOverlay.has_method("_update_labels"):
		%ImageOverlay._update_labels()
	if has_node("%PlotOverlay") and %PlotOverlay.has_method("_update_labels"):
		%PlotOverlay._update_labels()
	if has_node("%DialogueOverlay") and %DialogueOverlay.has_method("_update_labels"):
		%DialogueOverlay._update_labels()
	if has_node("%GameplayMenuOverlay") and %GameplayMenuOverlay.has_method("_update_labels"):
		%GameplayMenuOverlay._update_labels()
	# Error popup buttons
	if has_node("%ErrorReturnPopup"):
		%ErrorReturnTitle.text = I18n.translate("error_dialog_title")
		var t_ok: String = I18n.translate("btn_back_to_main_menu")
		%ErrorReturnBack.text = t_ok if t_ok != "btn_back_to_main_menu" else "Return to Menu"
		var t_dlg: String = I18n.translate("error_dialog_text")
		# Only override fallback text if it matches the old hard-coded fallback
		if %ErrorReturnMessage.text == "Something went wrong. Returning to main menu." or %ErrorReturnMessage.text == t_dlg:
			%ErrorReturnMessage.text = t_dlg if t_dlg != "error_dialog_text" else "Something went wrong. Returning to main menu."
		var retry_text: String = I18n.translate("btn_retry")
		%ErrorReturnRetry.text = retry_text if retry_text != "btn_retry" else "Retry"
