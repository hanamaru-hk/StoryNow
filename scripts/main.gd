extends Control


func _ready() -> void:
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Setting.pressed.connect(_on_setting_pressed)
	%Exit.pressed.connect(_on_exit_pressed)


func _on_start_pressed() -> void:
	pass


func _on_load_pressed() -> void:
	pass


func _on_gallery_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	pass


func _on_exit_pressed() -> void:
	get_tree().quit()
