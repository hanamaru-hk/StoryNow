extends Control

signal closed


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%LanguageOption.item_selected.connect(_on_language_selected)
	%ScreenSizeOption.item_selected.connect(_on_screen_size_selected)
	_update_labels()


func open() -> void:
	visible = true
	_update_labels()


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_language_selected(index: int) -> void:
	I18n.set_language(I18n.LANGUAGES[index])
	_update_labels()


func _on_screen_size_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1344, 768))
			DisplayServer.window_set_title("Instant Visual Novel")
			var screen_size := DisplayServer.screen_get_size()
			var window_size := Vector2i(1344, 768)
			var centered := (screen_size - window_size) / 2
			DisplayServer.window_set_position(centered)


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
