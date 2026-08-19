extends Control


func _ready() -> void:
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Setting.pressed.connect(_on_setting_pressed)
	%ImageSetting.pressed.connect(_on_image_server_setting_pressed)
	%LLMSetting.pressed.connect(_on_llm_setting_pressed)
	%Exit.pressed.connect(_on_exit_pressed)
	%GameSettingsOverlay.closed.connect(_on_settings_closed)
	%ImageServerSettingsOverlay.closed.connect(_on_settings_closed)
	%LLMSettingsOverlay.closed.connect(_on_settings_closed)
	_update_labels()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/prompt.tscn")


func _on_load_pressed() -> void:
	pass


func _on_gallery_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	%GameSettingsOverlay.open()


func _on_image_server_setting_pressed() -> void:
	%ImageServerSettingsOverlay.open()


func _on_llm_setting_pressed() -> void:
	%LLMSettingsOverlay.open()


func _on_settings_closed() -> void:
	_update_labels()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _update_labels() -> void:
	%Start.text = I18n.translate("btn_start")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%Setting.text = I18n.translate("btn_game_setting")
	%ImageSetting.text = I18n.translate("btn_image_server_setting")
	%LLMSetting.text = I18n.translate("btn_llm_setting")
	%Exit.text = I18n.translate("btn_exit")
	$CenterContainer/VBoxContainer/Title.text = I18n.translate("main_title")
