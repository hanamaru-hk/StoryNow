extends Control


func _ready() -> void:
	%Random.pressed.connect(_on_random_pressed)
	%Enhance.pressed.connect(_on_enhance_pressed)
	%Advanced.pressed.connect(_on_advanced_pressed)
	%Start.pressed.connect(_on_start_pressed)
	%Back.pressed.connect(_on_back_pressed)
	%ErrorPopupOk.pressed.connect(_on_error_popup_ok_pressed)
	%RandomConfirmCancel.pressed.connect(_on_random_confirm_canceled)
	%RandomConfirmOk.pressed.connect(_on_random_confirmed)
	_update_labels()


func _on_random_pressed() -> void:
	if not _is_llm_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_ready"))
		return
	%RandomConfirmPopup.visible = true


func _request_random_text() -> void:
	%Random.disabled = true
	_show_loading(true)
	var result: Dictionary = await LLMManager.request_random()
	_show_loading(false)
	%Random.disabled = false
	if not result.get("success", false):
		_show_error_popup(result.get("error", ""))
	else:
		%BackgroundInput.text = result["text"]


func _on_enhance_pressed() -> void:
	if not _is_llm_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_ready"))
		return
	var input: String = %BackgroundInput.text.strip_edges()
	if input.is_empty():
		_show_error_popup(I18n.translate("notice_write_something_first"))
		return
	%Enhance.disabled = true
	_show_loading(true)
	var result: Dictionary = await LLMManager.request_enhance(input)
	_show_loading(false)
	%Enhance.disabled = false
	if not result.get("success", false):
		_show_error_popup(result.get("error", ""))
	else:
		%BackgroundInput.text = result["text"]


func _on_advanced_pressed() -> void:
	%GameProgressOverlay.open()


func _show_loading(is_visible: bool) -> void:
	%LoadingOverlay.visible = is_visible


func _show_error_popup(message: String) -> void:
	%ErrorPopupMessage.text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorPopup.visible = true


func _on_error_popup_ok_pressed() -> void:
	%ErrorPopup.visible = false


func _on_start_pressed() -> void:
	if not _are_story_servers_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_and_image_ready"))
		return
	var input: String = %BackgroundInput.text.strip_edges()
	if input.is_empty():
		_show_error_popup(I18n.translate("notice_write_something_first"))
		return
	var uuid := _generate_uuid()
	SceneDataManager.scene_data = {
		"uuid": uuid,
		"image_filenames": [],
		"version": "1.0",
		"interactions": [],
		"choices": [],
		"image_prompt": "",
		"summary": input,
		"end": false,
		"expected_rounds": GameProgressManager.settings.get("expected_rounds", 20),
		"current_round": 1,
		"language": I18n.current_lang,
		"game_status": "new_story",
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


func _is_llm_ready() -> bool:
	return ServerRuntimeManager.llm_state == ServerRuntimeManager.ServerState.HEALTHY


func _is_image_server_ready() -> bool:
	return ServerRuntimeManager.image_state == ServerRuntimeManager.ServerState.HEALTHY


func _are_story_servers_ready() -> bool:
	return _is_llm_ready() and _is_image_server_ready()


func _on_random_confirmed() -> void:
	%RandomConfirmPopup.visible = false
	%BackgroundInput.text = ""
	await _request_random_text()


func _on_random_confirm_canceled() -> void:
	%RandomConfirmPopup.visible = false


func _update_labels() -> void:
	$MarginContainer/VBoxContainer/Title.text = I18n.translate("prompt_title")
	$MarginContainer/VBoxContainer/Description.text = I18n.translate("prompt_desc")
	$MarginContainer/VBoxContainer/BackgroundInput.placeholder_text = I18n.translate("prompt_placeholder")
	%Random.text = I18n.translate("btn_random")
	%Enhance.text = I18n.translate("btn_enhance")
	%Advanced.text = I18n.translate("btn_advanced_setting")
	%Start.text = I18n.translate("btn_start")
	%Back.text = I18n.translate("btn_back")
	%LoadingLabel.text = I18n.translate("loading_title")
	%ErrorPopupTitle.text = I18n.translate("error_dialog_title")
	%ErrorPopupOk.text = "OK"
	%RandomConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%RandomConfirmMessage.text = I18n.translate("confirm_random_clear_text")
	%RandomConfirmCancel.text = I18n.translate("btn_cancel")
	%RandomConfirmOk.text = I18n.translate("btn_confirm")
