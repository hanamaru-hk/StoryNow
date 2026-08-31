extends Control

signal closed

const ScrollbarStyleScript := preload("res://scripts/scrollbar_style.gd")

var _pending := {}


func _ready() -> void:
	ScrollbarStyleScript.apply(%SettingsScroll)
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%LanguageOption.item_selected.connect(_on_language_selected)
	%ScreenSizeOption.item_selected.connect(_on_screen_size_selected)
	if has_node("%AutoplayCheck"):
		%AutoplayCheck.toggled.connect(_on_autoplay_toggled)
	if has_node("%ShowStreamingCheck"):
		%ShowStreamingCheck.toggled.connect(_on_show_streaming_toggled)
	if has_node("%DialogueInstantCheck"):
		%DialogueInstantCheck.toggled.connect(_on_dialogue_instant_toggled)
	if has_node("%DialogueSpeedSlider"):
		%DialogueSpeedSlider.value_changed.connect(_on_dialogue_speed_changed)
	if has_node("%VoiceVolumeSlider"):
		%VoiceVolumeSlider.value_changed.connect(_on_voice_volume_changed)
	if has_node("%VoiceMuteCheck"):
		%VoiceMuteCheck.toggled.connect(_on_voice_mute_toggled)
	if has_node("%MusicVolumeSlider"):
		%MusicVolumeSlider.value_changed.connect(_on_music_volume_changed)
	if has_node("%MusicMuteCheck"):
		%MusicMuteCheck.toggled.connect(_on_music_mute_toggled)
	if has_node("%SoundEffectVolumeSlider"):
		%SoundEffectVolumeSlider.value_changed.connect(_on_sound_effect_volume_changed)
	if has_node("%SoundEffectMuteCheck"):
		%SoundEffectMuteCheck.toggled.connect(_on_sound_effect_mute_toggled)
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	visible = true
	_pending = GameSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	_pending = {}
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	GameSettingsManager.reset_to_defaults()
	_pending = GameSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_update_hidden_screen_fields_for_save()
	GameSettingsManager.settings = _pending.duplicate(true)
	GameSettingsManager._apply_language()
	GameSettingsManager._apply_screen_size()
	GameSettingsManager.music_settings_changed.emit()
	GameSettingsManager.voice_settings_changed.emit()
	GameSettingsManager.sound_effect_settings_changed.emit()
	GameSettingsManager.save_settings()
	_pending = {}
	visible = false
	closed.emit()


func _on_language_selected(index: int) -> void:
	_pending["language"] = I18n.LANGUAGES[index]
	_update_labels()


func _on_screen_size_selected(index: int) -> void:
	match index:
		0:
			_pending["screen_size"] = "full"
		1:
			_pending["screen_size"] = "1344x768"
		2:
			_pending["screen_size"] = "1600x900"


func _update_hidden_screen_fields_for_save() -> void:
	var next_size := str(_pending.get("screen_size", "full"))
	var previous_size := str(GameSettingsManager.settings.get("screen_size", "full"))
	if _is_window_resolution(next_size):
		_pending["last_windows_resolution"] = next_size
	elif _is_window_resolution(previous_size):
		_pending["last_windows_resolution"] = previous_size
	elif not _pending.has("last_windows_resolution"):
		_pending["last_windows_resolution"] = "1344x768"
	_pending["last_aspect_ratio"] = _aspect_ratio_for_resolution(str(_pending["last_windows_resolution"]))


func _is_window_resolution(size: String) -> bool:
	return size == "1344x768" or size == "1600x900"


func _aspect_ratio_for_resolution(size: String) -> String:
	match size:
		"1344x768", "1600x900":
			return "16:9"
		_:
			return "16:9"


func _on_autoplay_toggled(pressed: bool) -> void:
	_pending["autoplay_tts"] = pressed
	_update_labels()


func _on_show_streaming_toggled(pressed: bool) -> void:
	_pending["show_streaming"] = pressed
	_update_labels()


func _on_dialogue_instant_toggled(pressed: bool) -> void:
	_pending["dialogue_text_instant"] = pressed
	_update_dialogue_speed_enabled()
	_update_labels()


func _on_dialogue_speed_changed(value: float) -> void:
	_pending["dialogue_text_speed"] = int(round(value))
	_update_labels()


func _on_music_volume_changed(value: float) -> void:
	_pending["music_volume"] = int(round(value))
	_update_labels()


func _on_voice_volume_changed(value: float) -> void:
	_pending["voice_volume"] = int(round(value))
	_update_labels()


func _on_voice_mute_toggled(pressed: bool) -> void:
	_pending["voice_muted"] = pressed
	_update_labels()


func _on_music_mute_toggled(pressed: bool) -> void:
	_pending["music_muted"] = pressed
	_update_labels()


func _on_sound_effect_volume_changed(value: float) -> void:
	_pending["sound_effect_volume"] = int(round(value))
	_update_labels()


func _on_sound_effect_mute_toggled(pressed: bool) -> void:
	_pending["sound_effect_muted"] = pressed
	_update_labels()


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	var lang_index: int = I18n.LANGUAGES.find(_pending["language"])
	if lang_index >= 0:
		%LanguageOption.selected = lang_index
	var size_index: int = 0
	match str(_pending["screen_size"]):
		"1344x768":
			size_index = 1
		"1600x900":
			size_index = 2
	%ScreenSizeOption.selected = size_index
	if has_node("%AutoplayCheck"):
		%AutoplayCheck.button_pressed = bool(_pending.get("autoplay_tts", true))
		%AutoplayCheck.text = I18n.translate("settings_on") if bool(_pending.get("autoplay_tts", true)) else I18n.translate("settings_off")
	if has_node("%ShowStreamingCheck"):
		%ShowStreamingCheck.button_pressed = bool(_pending.get("show_streaming", true))
		%ShowStreamingCheck.text = I18n.translate("settings_on") if bool(_pending.get("show_streaming", true)) else I18n.translate("settings_off")
	if has_node("%DialogueInstantCheck"):
		%DialogueInstantCheck.button_pressed = bool(_pending.get("dialogue_text_instant", false))
		%DialogueInstantCheck.text = I18n.translate("settings_on") if bool(_pending.get("dialogue_text_instant", false)) else I18n.translate("settings_off")
	if has_node("%DialogueSpeedSlider"):
		%DialogueSpeedSlider.value = float(_pending.get("dialogue_text_speed", GameSettingsManager.DEFAULT_DIALOGUE_TEXT_SPEED))
	if has_node("%DialogueSpeedValue"):
		%DialogueSpeedValue.text = _dialogue_speed_text()
	if has_node("%VoiceVolumeSlider"):
		%VoiceVolumeSlider.value = float(_pending.get("voice_volume", 100))
	if has_node("%VoiceVolumeValue"):
		%VoiceVolumeValue.text = "%d%%" % int(_pending.get("voice_volume", 100))
	if has_node("%VoiceMuteCheck"):
		%VoiceMuteCheck.button_pressed = bool(_pending.get("voice_muted", false))
		%VoiceMuteCheck.text = I18n.translate("settings_on") if bool(_pending.get("voice_muted", false)) else I18n.translate("settings_off")
	if has_node("%MusicVolumeSlider"):
		%MusicVolumeSlider.value = float(_pending.get("music_volume", 70))
	if has_node("%MusicVolumeValue"):
		%MusicVolumeValue.text = "%d%%" % int(_pending.get("music_volume", 70))
	if has_node("%MusicMuteCheck"):
		%MusicMuteCheck.button_pressed = bool(_pending.get("music_muted", false))
		%MusicMuteCheck.text = I18n.translate("settings_on") if bool(_pending.get("music_muted", false)) else I18n.translate("settings_off")
	if has_node("%SoundEffectVolumeSlider"):
		%SoundEffectVolumeSlider.value = float(_pending.get("sound_effect_volume", 70))
	if has_node("%SoundEffectVolumeValue"):
		%SoundEffectVolumeValue.text = "%d%%" % int(_pending.get("sound_effect_volume", 70))
	if has_node("%SoundEffectMuteCheck"):
		%SoundEffectMuteCheck.button_pressed = bool(_pending.get("sound_effect_muted", false))
		%SoundEffectMuteCheck.text = I18n.translate("settings_on") if bool(_pending.get("sound_effect_muted", false)) else I18n.translate("settings_off")
	_update_dialogue_speed_enabled()


func _update_labels() -> void:
	%Title.text = I18n.translate("settings_title")
	%LanguageLabel.text = I18n.translate("settings_language")
	%ScreenSizeLabel.text = I18n.translate("settings_screen_size")
	if has_node("%AutoplayLabel"):
		%AutoplayLabel.text = I18n.translate("settings_autoplay_tts") if I18n.translate("settings_autoplay_tts") != "settings_autoplay_tts" else "Auto-play TTS"
	if has_node("%AutoplayCheck"):
		%AutoplayCheck.text = I18n.translate("settings_on") if %AutoplayCheck.button_pressed else I18n.translate("settings_off")
	if has_node("%ShowStreamingLabel"):
		%ShowStreamingLabel.text = I18n.translate("settings_show_streaming") if I18n.translate("settings_show_streaming") != "settings_show_streaming" else "Show streaming"
	if has_node("%ShowStreamingCheck"):
		%ShowStreamingCheck.text = I18n.translate("settings_on") if %ShowStreamingCheck.button_pressed else I18n.translate("settings_off")
	if has_node("%DialogueInstantLabel"):
		%DialogueInstantLabel.text = I18n.translate("settings_dialogue_instant")
	if has_node("%DialogueInstantCheck"):
		%DialogueInstantCheck.text = I18n.translate("settings_on") if %DialogueInstantCheck.button_pressed else I18n.translate("settings_off")
	if has_node("%DialogueSpeedLabel"):
		%DialogueSpeedLabel.text = I18n.translate("settings_dialogue_speed")
	if has_node("%DialogueSpeedValue"):
		%DialogueSpeedValue.text = _dialogue_speed_text()
	if has_node("%VoiceVolumeLabel"):
		%VoiceVolumeLabel.text = I18n.translate("settings_voice_volume")
	if has_node("%VoiceVolumeValue"):
		%VoiceVolumeValue.text = "%d%%" % int(_pending.get("voice_volume", 100))
	if has_node("%VoiceMuteLabel"):
		%VoiceMuteLabel.text = I18n.translate("settings_voice_mute")
	if has_node("%VoiceMuteCheck"):
		%VoiceMuteCheck.text = I18n.translate("settings_on") if %VoiceMuteCheck.button_pressed else I18n.translate("settings_off")
	if has_node("%MusicVolumeLabel"):
		%MusicVolumeLabel.text = I18n.translate("settings_music_volume") if I18n.translate("settings_music_volume") != "settings_music_volume" else "Music Volume"
	if has_node("%MusicVolumeValue"):
		%MusicVolumeValue.text = "%d%%" % int(_pending.get("music_volume", 70))
	if has_node("%MusicMuteLabel"):
		%MusicMuteLabel.text = I18n.translate("settings_music_mute") if I18n.translate("settings_music_mute") != "settings_music_mute" else "Mute Music"
	if has_node("%MusicMuteCheck"):
		%MusicMuteCheck.text = I18n.translate("settings_on") if %MusicMuteCheck.button_pressed else I18n.translate("settings_off")
	if has_node("%SoundEffectVolumeLabel"):
		%SoundEffectVolumeLabel.text = I18n.translate("settings_sound_effect_volume")
	if has_node("%SoundEffectVolumeValue"):
		%SoundEffectVolumeValue.text = "%d%%" % int(_pending.get("sound_effect_volume", 70))
	if has_node("%SoundEffectMuteLabel"):
		%SoundEffectMuteLabel.text = I18n.translate("settings_sound_effect_mute")
	if has_node("%SoundEffectMuteCheck"):
		%SoundEffectMuteCheck.text = I18n.translate("settings_on") if %SoundEffectMuteCheck.button_pressed else I18n.translate("settings_off")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
	while %LanguageOption.item_count < I18n.LANGUAGES.size():
		%LanguageOption.add_item("")
	for i in range(I18n.LANGUAGES.size()):
		var lang_code: String = str(I18n.LANGUAGES[i])
		%LanguageOption.set_item_text(i, I18n.translate("lang_%s" % lang_code.to_lower()))
	%ScreenSizeOption.set_item_text(0, I18n.translate("settings_screen_full"))
	%ScreenSizeOption.set_item_text(1, I18n.translate("settings_screen_1344"))
	while %ScreenSizeOption.item_count < 3:
		%ScreenSizeOption.add_item("")
	%ScreenSizeOption.set_item_text(2, I18n.translate("settings_screen_1600"))


func _dialogue_speed_text() -> String:
	var speed := int(_pending.get("dialogue_text_speed", GameSettingsManager.DEFAULT_DIALOGUE_TEXT_SPEED))
	return I18n.translate("settings_dialogue_speed_value") % speed


func _update_dialogue_speed_enabled() -> void:
	if has_node("%DialogueSpeedSlider"):
		%DialogueSpeedSlider.editable = not bool(_pending.get("dialogue_text_instant", false))
