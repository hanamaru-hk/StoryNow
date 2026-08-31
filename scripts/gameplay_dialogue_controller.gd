class_name GameplayDialogueController
extends RefCounted

const TTSVoiceProfile = preload("res://scripts/tts_voice_profile.gd")
const TTS_VOICE_BUS := "TTSVoice"

var _host: Control
var _continue_indicator_tween: Tween


func _init(host: Control) -> void:
	_host = host


func update_total() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var total := maxi(interactions.size(), 1)
	var index := clampi(current_index(), 0, total - 1)
	_host.set("total_dialogue", total)
	_host.set("current_dialogue_index", index)
	_host.set("_current_dialog_idx", index)


func show_current() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var index := current_index()
	var total := total_dialogues()
	if interactions.is_empty():
		_set_text("NameLabel", "")
		_set_text("DialogLabel", "")
		_set_text("DialogProgressLabel", "%d / %d" % [index + 1, total])
		return
	index = clampi(index, 0, interactions.size() - 1)
	set_current_index(index)
	var entry: Dictionary = interactions[index] if interactions[index] is Dictionary else {}
	_set_text("NameLabel", str(entry.get("character", entry.get("characer", ""))))
	_set_text("DialogLabel", str(entry.get("dialogue", "")))
	_set_text("DialogProgressLabel", "%d / %d" % [index + 1, total])
	_host.set("_scene_data", SceneDataManager.scene_data)


func has_previous_scene() -> bool:
	if not SceneDataManager.scene_data.has("prev_uuid"):
		return false
	var previous: Variant = SceneDataManager.scene_data.get("prev_uuid")
	if previous == null:
		return false
	if previous is String:
		return not previous.strip_edges().is_empty()
	if previous is Dictionary or previous is Array:
		return not previous.is_empty()
	return true


func has_previous_dialogue() -> bool:
	return current_index() > 0


func is_at_choice() -> bool:
	return current_index() >= total_dialogues() - 1


func can_open_choice() -> bool:
	return current_status() == "running" and is_at_choice()


func can_advance_dialogue() -> bool:
	return current_index() < total_dialogues() - 1 or can_open_choice()


func can_navigate_scene() -> bool:
	return current_status() == "running"


func current_wav_exists() -> bool:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var index := current_index()
	if index < 0 or index >= interactions.size():
		return false
	var entry: Dictionary = interactions[index] if interactions[index] is Dictionary else {}
	var filename := str(entry.get("sound_filename", "")).strip_edges()
	var uuid := current_uuid()
	return not filename.is_empty() and not uuid.is_empty() and FileAccess.file_exists("user://saves/%s/sounds/%s" % [uuid, filename])


func all_voice_files_exist() -> bool:
	var raw_interactions: Variant = SceneDataManager.scene_data.get("interactions", [])
	if not raw_interactions is Array:
		return true
	var uuid := current_uuid()
	if uuid.is_empty():
		return true
	for entry in raw_interactions:
		if not entry is Dictionary or str(entry.get("dialogue", "")).strip_edges().is_empty():
			continue
		var filename := str(entry.get("sound_filename", entry.get("sound_file", ""))).strip_edges()
		if filename.is_empty() or not FileAccess.file_exists("user://saves/%s/sounds/%s" % [uuid, filename]):
			return false
	return true


func interactions_are_empty() -> bool:
	var interactions: Variant = SceneDataManager.scene_data.get("interactions", [])
	return not interactions is Array or interactions.is_empty()


func recover_empty_interactions() -> bool:
	if current_status() != "running" or not interactions_are_empty():
		return false
	if has_previous_scene():
		_host.call("_set_game_status", "new_scene")
		await _host.call("_execute_new_scene_flow")
	else:
		_host.call("_set_game_status", "new_story")
		await _host.call("_execute_new_story_flow")
	return true


func recover_missing_assets(has_image: bool) -> void:
	if current_status() != "running":
		return
	var started_voice := false
	if not all_voice_files_exist():
		started_voice = bool(_host.call("_begin_voice_generation", SceneDataManager.scene_data))
	if not has_image:
		_host.call("_begin_image_generation")
		update_button_eligibility()
		if not await _host.call("_generate_comfyui_image"):
			return
		_host.call("_finish_image_generation")
	if started_voice:
		update_button_eligibility()
	else:
		enable_buttons()


func disable_buttons_for_loading() -> void:
	for name in ["PlotButton", "ImageButton", "PlayAudioButton", "PrevLineButton", "NextLineButton", "PrevSceneButton", "NextSceneButton"]:
		var button := _node(name) as Button
		if button:
			button.disabled = true
	for name in ["HelpButton", "SettingButton", "GameplayMenuButton"]:
		var button := _node(name) as Button
		if button:
			button.disabled = false


func update_button_eligibility() -> void:
	_set_disabled("PlotButton", not can_navigate_scene())
	_set_disabled("ImageButton", not can_navigate_scene())
	_set_disabled("PlayAudioButton", not current_wav_exists())
	_set_disabled("HelpButton", false)
	_set_disabled("PrevLineButton", not has_previous_dialogue())
	_set_disabled("NextLineButton", not can_advance_dialogue())
	_set_disabled("PrevSceneButton", not can_navigate_scene() or not has_previous_scene())
	_set_disabled("NextSceneButton", not can_navigate_scene())
	update_continue_indicator()


func start_continue_indicator() -> void:
	var indicator := _node("ContinueIndicator") as Control
	if indicator == null:
		return
	if is_instance_valid(_continue_indicator_tween):
		_continue_indicator_tween.kill()
	_continue_indicator_tween = _host.create_tween().set_loops()
	_continue_indicator_tween.tween_property(indicator, "modulate:a", 0.25, 0.55)
	_continue_indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.55)


func update_continue_indicator() -> void:
	var indicator := _node("ContinueIndicator") as Control
	if indicator:
		indicator.visible = has_current_dialogue()


func has_current_dialogue() -> bool:
	var interactions: Variant = SceneDataManager.scene_data.get("interactions", [])
	if not interactions is Array or interactions.is_empty():
		return false
	var index := clampi(current_index(), 0, interactions.size() - 1)
	var entry: Variant = interactions[index]
	return entry is Dictionary and not str(entry.get("dialogue", "")).strip_edges().is_empty()


func enable_buttons() -> void:
	update_button_eligibility()


func on_dialog_area_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if not can_advance_dialogue():
		return
	next_dialogue()
	_host.get_viewport().set_input_as_handled()


func previous_dialogue() -> void:
	if total_dialogues() <= 1 or current_index() <= 0:
		return
	stop_tts()
	set_current_index(current_index() - 1)
	_save_dialogue_progress()
	show_current()
	update_button_eligibility()
	try_autoplay()


func next_dialogue() -> void:
	if current_index() >= total_dialogues() - 1:
		if can_open_choice():
			_host.call("_show_choice_overlay")
		return
	if total_dialogues() <= 1:
		return
	stop_tts()
	set_current_index(current_index() + 1)
	_save_dialogue_progress()
	show_current()
	update_button_eligibility()
	try_autoplay()


func previous_scene() -> void:
	if not can_navigate_scene() or not has_previous_scene():
		return
	var previous_uuid := str(SceneDataManager.scene_data.get("prev_uuid", "")).strip_edges()
	if previous_uuid.is_empty():
		return
	GameProgressManager.settings["current_uuid"] = previous_uuid
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.settings["current_round"] = maxi(int(GameProgressManager.settings.get("current_round", 1)) - 1, 1)
	GameProgressManager.settings["current_dialogue"] = 0
	GameProgressManager.save_settings()
	_host.get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func play_current_audio() -> void:
	if not current_wav_exists():
		update_button_eligibility()
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var entry: Dictionary = interactions[current_index()] if interactions[current_index()] is Dictionary else {}
	var path := "user://saves/%s/sounds/%s" % [current_uuid(), str(entry.get("sound_filename", ""))]
	play_wav(ProjectSettings.globalize_path(path))


func stop_tts() -> void:
	var player := _tts_player()
	if player and player.playing:
		player.stop()


func play_wav(global_path: String) -> void:
	var player := _tts_player()
	if player == null:
		push_warning("TTSPlayer not found")
		return
	if player.playing:
		player.stop()
	player.pitch_scale = _playback_scale()
	var pitch_effect := _pitch_effect(player)
	if pitch_effect:
		pitch_effect.pitch_scale = _pitch_scale()
	var stream: AudioStreamWAV = null
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(ProjectSettings.localize_path(global_path)):
		if ClassDB.class_has_method("AudioStreamWAV", "load_from_file"):
			stream = AudioStreamWAV.load_from_file(global_path)
		if stream == null:
			stream = _load_wav(global_path)
	if stream == null:
		push_warning("Failed to load wav: %s" % global_path)
		return
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.stream = stream
	player.play()


func try_autoplay() -> void:
	if not bool(GameSettingsManager.settings.get("autoplay_tts", true)) or not current_wav_exists():
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	var entry: Dictionary = interactions[current_index()] if interactions[current_index()] is Dictionary else {}
	var path := "user://saves/%s/sounds/%s" % [current_uuid(), str(entry.get("sound_filename", ""))]
	play_wav(ProjectSettings.globalize_path(path))


func on_tts_generated(uuid: String, index: int, _sound_filename: String, save_path: String) -> void:
	if current_uuid() != uuid or index != current_index():
		return
	update_button_eligibility()
	if bool(GameSettingsManager.settings.get("autoplay_tts", true)) and FileAccess.file_exists(save_path):
		play_wav(ProjectSettings.globalize_path(save_path))


func on_tts_batch_completed(uuid: String) -> void:
	if current_uuid() != uuid:
		return
	_host.call("_finish_voice_generation")
	enable_buttons()


func current_index() -> int:
	return int(_host.get("current_dialogue_index"))


func total_dialogues() -> int:
	return int(_host.get("total_dialogue"))


func set_current_index(index: int) -> void:
	_host.set("current_dialogue_index", index)
	_host.set("_current_dialog_idx", index)


func current_uuid() -> String:
	return str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()


func current_status() -> String:
	return str(_host.call("_current_game_status"))


func _save_dialogue_progress() -> void:
	GameProgressManager.settings["current_dialogue"] = current_index()
	GameProgressManager.save_settings()


func _tts_player() -> AudioStreamPlayer:
	return _node("TTSPlayer") as AudioStreamPlayer


func _pitch_effect(player: AudioStreamPlayer) -> AudioEffectPitchShift:
	var bus_index := AudioServer.get_bus_index(TTS_VOICE_BUS)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, TTS_VOICE_BUS)
		AudioServer.set_bus_send(bus_index, "Master")
	player.bus = TTS_VOICE_BUS
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectPitchShift:
			return effect
	var effect := AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus_index, effect)
	return effect


func _pitch_scale() -> float:
	return float(_voice_profile().get("pitch_scale", 1.0))


func _playback_scale() -> float:
	return float(_voice_profile().get("playback_scale", 1.0))


func _voice_profile() -> Dictionary:
	var language := str(SceneDataManager.scene_data.get("language", I18n.current_lang))
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if current_index() < 0 or current_index() >= interactions.size() or not interactions[current_index()] is Dictionary:
		return TTSVoiceProfile.resolve(language, "other")
	var sex := str(interactions[current_index()].get("sex", "male"))
	return TTSVoiceProfile.resolve(language, sex)


func _load_wav(global_path: String) -> AudioStreamWAV:
	var path := global_path if FileAccess.file_exists(global_path) else ProjectSettings.localize_path(global_path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data := file.get_buffer(file.get_length())
	file.close()
	if data.size() < 44 or data[0] != 0x52 or data[1] != 0x49 or data[2] != 0x46 or data[3] != 0x46:
		return null
	var sample_rate := 16000
	var channels := 1
	var bits_per_sample := 16
	for index in range(0, min(data.size() - 8, 256)):
		if data[index] == 0x66 and data[index + 1] == 0x6D and data[index + 2] == 0x74 and data[index + 3] == 0x20:
			if index + 24 < data.size():
				channels = data[index + 10] | (data[index + 11] << 8)
				sample_rate = data[index + 12] | (data[index + 13] << 8) | (data[index + 14] << 16) | (data[index + 15] << 24)
				bits_per_sample = data[index + 22] | (data[index + 23] << 8)
			break
	for index in range(12, min(data.size() - 8, 1024)):
		if data[index] == 0x64 and data[index + 1] == 0x61 and data[index + 2] == 0x74 and data[index + 3] == 0x61:
			var size := data[index + 4] | (data[index + 5] << 8) | (data[index + 6] << 16) | (data[index + 7] << 24)
			var offset := index + 8
			data = data.slice(offset, offset + size) if size > 0 and offset + size <= data.size() else data.slice(offset)
			break
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.stereo = channels == 2
	wav.mix_rate = sample_rate
	return wav


func _set_disabled(name: String, disabled: bool) -> void:
	var button := _node(name) as Button
	if button:
		button.disabled = disabled


func _set_text(name: String, text: String) -> void:
	var control := _node(name)
	if control is Label:
		(control as Label).text = text
	elif control is RichTextLabel:
		(control as RichTextLabel).text = text


func _node(unique_name: String) -> Node:
	return _host.get_node_or_null(NodePath("%%%s" % unique_name))
