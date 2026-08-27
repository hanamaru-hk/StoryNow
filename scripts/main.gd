extends Control


func _ready() -> void:
	print_verbose("")
	print_verbose("user data dir: " + OS.get_user_data_dir())
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Setting.pressed.connect(_on_setting_pressed)
	%AdvancedSetting.pressed.connect(_on_advanced_setting_pressed)
	%Exit.pressed.connect(_on_exit_pressed)
	%GameSettingsOverlay.closed.connect(_on_settings_closed)
	%AdvancedSettingsOverlay.closed.connect(_on_settings_closed)
	%AdvancedSettingsOverlay.image_settings_requested.connect(_on_image_server_setting_pressed)
	%AdvancedSettingsOverlay.llm_settings_requested.connect(_on_llm_setting_pressed)
	%ImageServerSettingsOverlay.closed.connect(_on_settings_closed)
	%LLMSettingsOverlay.closed.connect(_on_settings_closed)
	%FirstTimeLanguageOverlay.language_selected.connect(_on_first_time_language_selected)
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.closed.connect(_on_settings_closed)
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.closed.connect(_on_settings_closed)
	_update_labels()
	_check_first_time_overlay()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/brainstorm.tscn")


func _on_load_pressed() -> void:
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.open()


func _on_gallery_pressed() -> void:
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.open()


func _on_setting_pressed() -> void:
	%GameSettingsOverlay.open()


func _on_advanced_setting_pressed() -> void:
	%AdvancedSettingsOverlay.open()


func _on_image_server_setting_pressed() -> void:
	%ImageServerSettingsOverlay.open()


func _on_llm_setting_pressed() -> void:
	%LLMSettingsOverlay.open()


func _on_settings_closed() -> void:
	_update_labels()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _check_first_time_overlay() -> void:
	if not FileAccess.file_exists(GameSettingsManager.SETTINGS_PATH):
		%FirstTimeLanguageOverlay.open()


func _on_first_time_language_selected(_lang: String) -> void:
	_update_labels()


func _update_labels() -> void:
	%Start.text = I18n.translate("btn_start")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%Setting.text = I18n.translate("btn_game_setting")
	%AdvancedSetting.text = I18n.translate("btn_advanced_setting")
	%Exit.text = I18n.translate("btn_exit")
	$CenterContainer/VBoxContainer/Title.text = I18n.translate("main_title")
