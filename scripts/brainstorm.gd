extends Control


func _ready() -> void:
	%Random.pressed.connect(_on_random_pressed)
	%Enhance.pressed.connect(_on_enhance_pressed)
	%Advanced.pressed.connect(_on_advanced_pressed)
	%Start.pressed.connect(_on_start_pressed)
	%Back.pressed.connect(_on_back_pressed)
	_update_labels()


func _on_random_pressed() -> void:
	%Random.disabled = true
	_show_loading(true)
	var result: Dictionary = await LLMManager.request_random()
	_show_loading(false)
	%Random.disabled = false
	if not result.get("success", false):
		_show_error_dialog(result.get("error", ""))
	else:
		%BackgroundInput.text = result["text"]

func _on_enhance_pressed() -> void:
	var input: String = %BackgroundInput.text
	%Random.disabled = true
	_show_loading(true)
	var result: Dictionary = await LLMManager.request_enhance(input)
	_show_loading(false)
	%Random.disabled = false
	if not result.get("success", false):
		_show_error_dialog(result.get("error", ""))
	else:
		%BackgroundInput.text = result["text"]


func _on_advanced_pressed() -> void:
	%GameProgressOverlay.open()


func _show_loading(is_visible: bool) -> void:
	%LoadingOverlay.visible = is_visible


func _show_error_dialog(message: String) -> void:
	%ErrorDialog.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorDialog.popup_centered()


func _on_start_pressed() -> void:
	# Pass story background to gameplay scene via autoload or scene change
	# For now just switch to gameplay scene; Gameplay will use placeholder if empty
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	$MarginContainer/VBoxContainer/Title.text = I18n.translate("prompt_title")
	$MarginContainer/VBoxContainer/Description.text = I18n.translate("prompt_desc")
	$MarginContainer/VBoxContainer/BackgroundInput.placeholder_text = I18n.translate("prompt_placeholder")
	%Random.text = I18n.translate("btn_random")
	%Start.text = I18n.translate("btn_start")
	%Back.text = I18n.translate("btn_back")
	%LoadingLabel.text = I18n.translate("loading_title")
	%ErrorDialog.title = I18n.translate("error_dialog_title")
