extends Control


func _ready() -> void:
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Setting.pressed.connect(_on_setting_pressed)
	%Exit.pressed.connect(_on_exit_pressed)
	%SettingsOverlay.closed.connect(_on_settings_closed)
	_update_labels()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/prompt.tscn")


func _on_load_pressed() -> void:
	pass


func _on_gallery_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	%SettingsOverlay.open()


func _on_settings_closed() -> void:
	_update_labels()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _update_labels() -> void:
	%Start.text = I18n.translate("btn_start")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%Setting.text = I18n.translate("btn_settings")
	%Exit.text = I18n.translate("btn_exit")
	$CenterContainer/VBoxContainer/Title.text = I18n.translate("main_title")
