extends Control


func _ready() -> void:
	%Random.pressed.connect(_on_random_pressed)
	%Start.pressed.connect(_on_start_pressed)
	%Back.pressed.connect(_on_back_pressed)
	_update_labels()


func _on_random_pressed() -> void:
	pass


func _on_start_pressed() -> void:
	pass


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	$MarginContainer/VBoxContainer/Title.text = I18n.translate("prompt_title")
	$MarginContainer/VBoxContainer/Description.text = I18n.translate("prompt_desc")
	$MarginContainer/VBoxContainer/BackgroundInput.placeholder_text = I18n.translate("prompt_placeholder")
	%Random.text = I18n.translate("btn_random")
	%Start.text = I18n.translate("btn_start")
	%Back.text = I18n.translate("btn_back")
