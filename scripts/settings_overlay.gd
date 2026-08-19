extends Control

signal closed


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%LanguageOption.item_selected.connect(_on_language_selected)
	%ScreenSizeOption.item_selected.connect(_on_screen_size_selected)
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	visible = true
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_language_selected(index: int) -> void:
	SettingsManager.set_language(I18n.LANGUAGES[index])
	_update_labels()


func _on_screen_size_selected(index: int) -> void:
	match index:
		0:
			SettingsManager.set_screen_size("full")
		1:
			SettingsManager.set_screen_size("1344x768")


func _sync_ui_to_settings() -> void:
	var lang_index := I18n.LANGUAGES.find(SettingsManager.settings["language"])
	if lang_index >= 0:
		%LanguageOption.selected = lang_index
	var size_index := 0 if SettingsManager.settings["screen_size"] == "full" else 1
	%ScreenSizeOption.selected = size_index


func _update_labels() -> void:
	%Title.text = I18n.translate("settings_title")
	%LanguageLabel.text = I18n.translate("settings_language")
	%ScreenSizeLabel.text = I18n.translate("settings_screen_size")
	%Back.text = I18n.translate("btn_back")
	%LanguageOption.set_item_text(0, I18n.translate("lang_en"))
	%LanguageOption.set_item_text(1, I18n.translate("lang_zh_cn"))
	%LanguageOption.set_item_text(2, I18n.translate("lang_zh_tw"))
	%ScreenSizeOption.set_item_text(0, I18n.translate("settings_screen_full"))
	%ScreenSizeOption.set_item_text(1, I18n.translate("settings_screen_1344"))
