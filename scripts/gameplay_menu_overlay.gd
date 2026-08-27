extends Control

signal closed
signal load_requested
signal gallery_requested
signal game_settings_requested
signal advanced_settings_requested
signal main_menu_requested
signal quit_game_requested


func _ready() -> void:
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%GameSetting.pressed.connect(_on_game_setting_pressed)
	%AdvancedSetting.pressed.connect(_on_advanced_setting_pressed)
	%BackToMainMenu.pressed.connect(_on_back_to_main_menu_pressed)
	%QuitGame.pressed.connect(_on_quit_game_pressed)
	%Back.pressed.connect(_on_back_pressed)
	_update_labels()


func open() -> void:
	visible = true
	_update_labels()


func close() -> void:
	visible = false
	closed.emit()


func _on_load_pressed() -> void:
	visible = false
	load_requested.emit()


func _on_gallery_pressed() -> void:
	visible = false
	gallery_requested.emit()


func _on_game_setting_pressed() -> void:
	visible = false
	game_settings_requested.emit()


func _on_advanced_setting_pressed() -> void:
	visible = false
	advanced_settings_requested.emit()


func _on_back_to_main_menu_pressed() -> void:
	visible = false
	main_menu_requested.emit()


func _on_quit_game_pressed() -> void:
	visible = false
	quit_game_requested.emit()


func _on_back_pressed() -> void:
	close()


func _update_labels() -> void:
	%Title.text = I18n.translate("gameplay_menu_title")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%GameSetting.text = I18n.translate("btn_game_setting")
	%AdvancedSetting.text = I18n.translate("btn_advanced_setting")
	%BackToMainMenu.text = I18n.translate("btn_back_to_main_menu")
	%QuitGame.text = I18n.translate("btn_quit_game")
	%Back.text = I18n.translate("btn_back")
