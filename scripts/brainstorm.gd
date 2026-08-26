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
	var uuid := _generate_uuid()
	SceneDataManager.scene_data = {
		"uuid": uuid,
		"image_filenames": [],
		"version": "1.0",
		"interactions": [],
		"choices": [],
		"image_prompt": "",
		"summary": %BackgroundInput.text,
		"end": false,
		"expected_rounds": GameProgressManager.settings.get("expected_rounds", 20),
		"current_round": 1,
		"language": I18n.current_lang,
	}
	SceneDataManager.save()
	GameProgressManager.settings["current_uuid"] = uuid
	GameProgressManager.settings["game_status"] = "new_story"
	GameProgressManager.settings["current_round"] = 1
	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: Array = []
	for i in 16:
		bytes.append(rng.randi_range(0, 255))
	# UUID v4: set version and variant bits
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]


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
