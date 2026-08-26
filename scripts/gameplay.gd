extends Control

const CURRENT_VERSION := "1.0"
const CANTONESE_MALE_PITCH_SCALE := 0.7

var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0

# Requested public dialogue tracking vars
var current_dialogue_index: int = 0
var total_dialogue: int = 1

# Error dialog retry handling
signal retry_requested
var _error_retry_button: Button = null
var _pending_retry_action: String = ""  # "new_story" or "new_scene"
var _retry_in_progress: bool = false

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

	# --- ErrorReturnDialog ---
	%ErrorReturnDialog.confirmed.connect(_on_error_return)
	%ErrorReturnDialog.canceled.connect(_on_error_return)
	# AcceptDialog close via X also triggers canceled
	# Add Retry button for LLM JSON parse failures
	_setup_error_dialog_retry()

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	# --- TTS auto-play ---
	if TTSManager.has_signal("tts_generated") and not TTSManager.tts_generated.is_connected(_on_tts_generated):
		TTSManager.tts_generated.connect(_on_tts_generated)

	_update_labels()
	_load_default_background()
	# Disable all SidePanel buttons except Setting and BackButton at start
	_set_all_side_buttons_disabled_except_settings_back()

	match GameProgressManager.settings.get("game_status", ""):
		"new_story":
			await _execute_new_story_flow()
		"new_scene":
			await _execute_new_scene_flow()
		"running":
			var uuid_running: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok_running: bool = SceneDataManager.load_data(uuid_running)
			if ok_running:
				_scene_data = SceneDataManager.scene_data
			else:
				push_warning("Gameplay running: failed to load scene_data for uuid %s" % uuid_running)
				_scene_data = SceneDataManager.scene_data
				if _scene_data.is_empty():
					show_error("Failed to load scene data: %s" % uuid_running)
			# Restore dialogue index from GameProgressManager
			current_dialogue_index = int(GameProgressManager.settings.get("current_dialogue", 0))
			_current_dialog_idx = current_dialogue_index
			# Refresh dialogues and button panel
			_populate_dynamic_choice_buttons()
			_update_total_dialogue()
			# _update_total_dialogue may clamp index; sync back to local/manager
			_current_dialog_idx = current_dialogue_index
			_show_current_dialogue()
			# Refresh image from save folder of uuid (no LLM / no ComfyUI generation)
			var image_filenames: Array = SceneDataManager.scene_data.get("image_filenames", []) if SceneDataManager.scene_data.get("image_filenames", []) is Array else []
			var bg_loaded: bool = false
			if not image_filenames.is_empty():
				var last_filename: String = str(image_filenames[image_filenames.size() - 1])
				if not last_filename.strip_edges().is_empty():
					var img_path: String = "user://saves/%s/images/%s" % [uuid_running, last_filename]
					# Only try to load if file exists
					if FileAccess.file_exists(img_path):
						_set_background_from_file(img_path)
						bg_loaded = true
					else:
						# Fallback: try direct save_path stored variations
						# Try with the filename as full user path
						_set_background_from_file(img_path)
						bg_loaded = true
			if not bg_loaded:
				# Fallback: scan images directory for any image file
				var images_dir: String = "user://saves/%s/images" % uuid_running
				if DirAccess.dir_exists_absolute(images_dir):
					var dir := DirAccess.open(images_dir)
					if dir != null:
						dir.list_dir_begin()
						var file_name := dir.get_next()
						var latest_file: String = ""
						while file_name != "":
							if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg") or file_name.ends_with(".webp")):
								latest_file = file_name
							file_name = dir.get_next()
						dir.list_dir_end()
						if not latest_file.is_empty():
							_set_background_from_file("%s/%s" % [images_dir, latest_file])
						else:
							print_verbose("Gameplay running: no images found in %s, keeping default background" % images_dir)
					else:
						print_verbose("Gameplay running: cannot open images dir %s" % images_dir)
				else:
					print_verbose("Gameplay running: images dir does not exist %s" % images_dir)
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
			# Auto-play current dialogue wav if exists (prev_scene rule)
			_try_autoplay_current()	
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
		_show_choice_overlay()
		return
	# Also handle end-of-dialogue -> choice overlay (index at last dialogue)
	if current_dialogue_index >= total_dialogue - 1:
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
	if has_node("%ImageOverlay"):
		%ImageOverlay.open()
	else:
		# Fallback inline behavior if overlay not instanced
		var prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
		if prompt.strip_edges().is_empty():
			show_error("Image prompt is empty")
			return
		var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
		var result: Dictionary = await ImageServerManager.generate_scene_image(prompt, uuid)
		if not result.get("success", false):
			show_error(str(result.get("error", "Failed to generate image")))
			return
		var save_path: String = str(result.get("save_path", ""))
		var filename: String = str(result.get("filename", ""))
		if not SceneDataManager.scene_data.has("image_filenames") or not SceneDataManager.scene_data["image_filenames"] is Array:
			SceneDataManager.scene_data["image_filenames"] = []
		var arr: Array = SceneDataManager.scene_data["image_filenames"]
		arr.append(filename)
		SceneDataManager.scene_data["image_filenames"] = arr
		SceneDataManager.save()
		_set_background_from_file(save_path)


func _on_image_overlay_closed() -> void:
	_update_labels()


func _on_image_generated(_save_path: String, _filename: String) -> void:
	# Overlay already appended and refreshed background; keep hook for future
	_update_labels()


func _on_plot_pressed() -> void:
	if has_node("%PlotOverlay"):
		%PlotOverlay.open()


func _on_plot_overlay_closed() -> void:
	_update_labels()


func _on_setting_pressed() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_play_audio_pressed() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if interactions.is_empty():
		return
	if current_dialogue_index < 0 or current_dialogue_index >= interactions.size():
		return
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	var fname: String = str(entry.get("sound_filename", "")).strip_edges()
	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if fname.is_empty() or uuid.is_empty():
		# On-demand generate
		if not uuid.is_empty():
			TTSManager.generate_single_interaction(uuid, current_dialogue_index)
		return
	var path_user: String = "user://saves/%s/sounds/%s" % [uuid, fname]
	if FileAccess.file_exists(path_user):
		_play_wav(ProjectSettings.globalize_path(path_user))
	else:
		# File missing -> regenerate
		TTSManager.generate_single_interaction(uuid, current_dialogue_index)


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
	player.pitch_scale = _tts_pitch_scale_for_current_dialogue()
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
	if not bool(GameSettingsManager.settings.get("autoplay_tts", true)):
		return
	var cur_uuid: String = str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if cur_uuid != uuid:
		return
	if idx != current_dialogue_index:
		return
	# Ensure file exists before play
	if not FileAccess.file_exists(save_path):
		return
	_play_wav(ProjectSettings.globalize_path(save_path))


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
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300), true)
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
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	# Apply title field to TitleLabel when request finishes
	_apply_title_from_result(str(llm_data.get("title", result.get("title", ""))), llm_data)
	# Mark progress as running so next load doesn't re-request
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	# Non-blocking TTS generation for all dialogues
	var tts_uuid_story := str(SceneDataManager.scene_data.get("uuid", ""))
	if not tts_uuid_story.is_empty():
		TTSManager.generate_all_for_scene(SceneDataManager.scene_data)
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
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300), true)
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
	if not SceneDataManager.scene_data.has("id"):
		SceneDataManager.scene_data["id"] = preserved_uuid
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	_apply_title_from_result(str(llm_data.get("title", result.get("title", ""))), llm_data)
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	# Non-blocking TTS generation for all dialogues (scene)
	var tts_uuid_scene := str(SceneDataManager.scene_data.get("uuid", ""))
	if not tts_uuid_scene.is_empty():
		TTSManager.generate_all_for_scene(SceneDataManager.scene_data)
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
	_pending_retry_action = ""

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
func _setup_error_dialog_retry() -> void:
	# Add Retry button once (AcceptDialog.add_button stores custom action "retry")
	if _error_retry_button != null:
		return
	# ok_button_text is "Return to Menu" – add Retry as custom action on the right
	_error_retry_button = %ErrorReturnDialog.add_button(I18n.translate("btn_retry"), false, "retry")
	if _error_retry_button:
		_error_retry_button.pressed.connect(_on_error_retry_pressed)
		_error_retry_button.visible = false
	# Also listen for custom_action (some Godot versions emit this instead of Button.pressed)
	if not %ErrorReturnDialog.custom_action.is_connected(_on_error_custom_action):
		%ErrorReturnDialog.custom_action.connect(_on_error_custom_action)


func _update_error_dialog_retry_visibility(allow_retry: bool) -> void:
	if _error_retry_button == null:
		return
	_error_retry_button.visible = allow_retry
	_error_retry_button.disabled = not allow_retry or _retry_in_progress
	var retry_text: String = I18n.translate("btn_retry")
	if retry_text == "btn_retry":
		retry_text = "Retry"
	_error_retry_button.text = retry_text


func show_error(message: String, allow_retry: bool = false, retry_action: String = "") -> void:
	if not retry_action.is_empty():
		_pending_retry_action = retry_action
	# If retry is allowed but no pending action has been set, do not show retry
	if allow_retry and _pending_retry_action.is_empty():
		allow_retry = false
	_update_error_dialog_retry_visibility(allow_retry and not _pending_retry_action.is_empty())
	%ErrorReturnDialog.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnDialog.title = I18n.translate("error_dialog_title")
	%ErrorReturnDialog.popup_centered()


func _on_error_custom_action(action: String) -> void:
	if action == "retry":
		_on_error_retry_pressed()


func _on_error_retry_pressed() -> void:
	if _pending_retry_action.is_empty() or _retry_in_progress:
		return
	_retry_in_progress = true
	_update_error_dialog_retry_visibility(false)
	%ErrorReturnDialog.hide()
	# Emit signal for the retry loop in _execute_*_flow; loop will clear pending on next iteration
	await get_tree().create_timer(0.05).timeout
	_retry_in_progress = false
	retry_requested.emit()


func _on_error_return() -> void:
	_pending_retry_action = ""
	_retry_in_progress = false
	_update_error_dialog_retry_visibility(false)
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
	if has_node("%ImageOverlay") and %ImageOverlay.has_method("_update_labels"):
		%ImageOverlay._update_labels()
	if has_node("%PlotOverlay") and %PlotOverlay.has_method("_update_labels"):
		%PlotOverlay._update_labels()
	if has_node("%DialogueOverlay") and %DialogueOverlay.has_method("_update_labels"):
		%DialogueOverlay._update_labels()
	# Error dialog buttons
	%ErrorReturnDialog.title = I18n.translate("error_dialog_title") if has_node("%ErrorReturnDialog") else ""
	if _error_retry_button != null:
		var retry_text: String = I18n.translate("btn_retry")
		_error_retry_button.text = retry_text if retry_text != "btn_retry" else "Retry"
