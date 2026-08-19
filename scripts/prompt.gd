extends Control


func _ready() -> void:
	%Random.pressed.connect(_on_random_pressed)
	%Enhance.pressed.connect(_on_enhance_pressed)
	%Start.pressed.connect(_on_start_pressed)


func _on_random_pressed() -> void:
	pass


func _on_enhance_pressed() -> void:
	pass


func _on_start_pressed() -> void:
	pass
