extends Control

signal closed

var _pending := {}


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%LanguageOption.item_selected.connect(_on_language_selected)
	%ScreenSizeOption.item_selected.connect(_on_screen_size_selected)
	if has_node("%AutoplayCheck"):
		%AutoplayCheck.toggled.connect(_on_autoplay_toggled)
	if has_node("%ShowStreamingCheck"):
		%ShowStreamingCheck.toggled.connect(_on_show_streaming_toggled)
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
	GameSettingsManager.settings = _pending.duplicate(true)
	GameSettingsManager._apply_language()
	GameSettingsManager._apply_screen_size()
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


func _on_autoplay_toggled(pressed: bool) -> void:
	_pending["autoplay_tts"] = pressed
	_update_labels()


func _on_show_streaming_toggled(pressed: bool) -> void:
	_pending["show_streaming"] = pressed
	_update_labels()


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	var lang_index: int = I18n.LANGUAGES.find(_pending["language"])
	if lang_index >= 0:
		%LanguageOption.selected = lang_index
	var size_index: int = 0 if _pending["screen_size"] == "full" else 1
	%ScreenSizeOption.selected = size_index
	if has_node("%AutoplayCheck"):
		%AutoplayCheck.button_pressed = bool(_pending.get("autoplay_tts", true))
		%AutoplayCheck.text = I18n.translate("settings_on") if bool(_pending.get("autoplay_tts", true)) else I18n.translate("settings_off")
	if has_node("%ShowStreamingCheck"):
		%ShowStreamingCheck.button_pressed = bool(_pending.get("show_streaming", true))
		%ShowStreamingCheck.text = I18n.translate("settings_on") if bool(_pending.get("show_streaming", true)) else I18n.translate("settings_off")


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
