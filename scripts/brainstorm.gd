extends Control

var _brainstorm_request_active := false
var _pending_engine_retry_action := ""


func _ready() -> void:
	ServerRuntimeManager.set_chrome_visible(true)
	MusicManager.play_random_mood("main_menu")
	%Random.pressed.connect(_on_random_pressed)
	%Enhance.pressed.connect(_on_enhance_pressed)
	%Advanced.pressed.connect(_on_advanced_pressed)
	%Start.pressed.connect(_on_start_pressed)
	%Back.pressed.connect(_on_back_pressed)
	%ErrorPopupOk.pressed.connect(_on_error_popup_ok_pressed)
	%ErrorPopupHelp.pressed.connect(_on_error_popup_help_pressed)
	%ErrorPopupRetry.pressed.connect(_on_error_popup_retry_pressed)
	%RandomConfirmCancel.pressed.connect(_on_random_confirm_canceled)
	%RandomConfirmOk.pressed.connect(_on_random_confirmed)
	%EnhanceConfirmCancel.pressed.connect(_on_enhance_confirm_canceled)
	%EnhanceConfirmOk.pressed.connect(_on_enhance_confirmed)
	_update_labels()
	_set_default_prompt()


func _exit_tree() -> void:
	ServerRuntimeManager.set_engine_status_hint_visible(false)


func _on_random_pressed() -> void:
	if _brainstorm_request_active:
		return
	if not _is_llm_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_ready"), true, "random")
		return
	if %BackgroundInput.text.strip_edges().is_empty():
		await _request_random_text()
		return
	%RandomConfirmPopup.visible = true


func _request_random_text() -> void:
	_set_brainstorm_request_active(true)
	var result: Dictionary = await LLMManager.request_random()
	if not is_inside_tree():
		return
	_set_brainstorm_request_active(false)
	if not result.get("success", false):
		var error := str(result.get("error", ""))
		if not result.get("cancelled", false) and error != "Cancelled":
			_show_error_popup(error)
	else:
		%BackgroundInput.text = result["text"]


func _on_enhance_pressed() -> void:
	if _brainstorm_request_active:
		return
	if not _is_llm_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_ready"), true, "enhance")
		return
	var input: String = %BackgroundInput.text.strip_edges()
	if input.is_empty():
		_show_error_popup(I18n.translate("notice_write_something_first"))
		return
	%EnhanceConfirmPopup.visible = true


func _request_enhanced_text(input: String) -> void:
	_set_brainstorm_request_active(true)
	var result: Dictionary = await LLMManager.request_enhance(input)
	if not is_inside_tree():
		return
	_set_brainstorm_request_active(false)
	if not result.get("success", false):
		var error := str(result.get("error", ""))
		if not result.get("cancelled", false) and error != "Cancelled":
			_show_error_popup(error)
	else:
		%BackgroundInput.text = result["text"]


func _on_advanced_pressed() -> void:
	%GameProgressOverlay.open()


func _show_loading(is_visible: bool) -> void:
	%LoadingOverlay.visible = is_visible


func _set_brainstorm_request_active(is_active: bool) -> void:
	_brainstorm_request_active = is_active
	_show_loading(false)
	_set_child_buttons_disabled(self, is_active)
	%Advanced.disabled = false
	%Back.disabled = false


func _set_child_buttons_disabled(root: Node, is_disabled: bool) -> void:
	if root == %GameProgressOverlay:
		return
	for child in root.get_children():
		var button := child as Button
		if button != null:
			button.disabled = is_disabled
		_set_child_buttons_disabled(child, is_disabled)


func _show_error_popup(message: String, show_engine_status_hint := false, retry_action := "") -> void:
	_pending_engine_retry_action = retry_action if show_engine_status_hint else ""
	var popup_message := message if not message.is_empty() else I18n.translate("error_dialog_text")
	if not show_engine_status_hint:
		popup_message = %ErrorPopupMessage.escape_bbcode(popup_message)
	%ErrorPopupMessage.text = "[center]%s[/center]" % popup_message
	%ErrorPopupOk.text = I18n.translate("btn_back") if show_engine_status_hint else "OK"
	%ErrorPopup.visible = true
	%ErrorPopupHelp.visible = show_engine_status_hint
	%ErrorPopupRetry.visible = not _pending_engine_retry_action.is_empty()
	ServerRuntimeManager.set_engine_status_hint_visible(show_engine_status_hint)


func _on_error_popup_ok_pressed() -> void:
	_close_error_popup()


func _on_error_popup_help_pressed() -> void:
	%HelpOverlay.open()


func _on_error_popup_retry_pressed() -> void:
	var action := _pending_engine_retry_action
	var servers_ready := _is_llm_ready()
	if action == "start":
		servers_ready = _are_story_servers_ready()
	if not servers_ready:
		ServerRuntimeManager.emphasize_engine_status_hint()
		return
	_close_error_popup()
	match action:
		"random":
			_on_random_pressed()
		"enhance":
			_on_enhance_pressed()
		"start":
			_on_start_pressed()


func _close_error_popup() -> void:
	_pending_engine_retry_action = ""
	%ErrorPopup.visible = false
	%ErrorPopupHelp.visible = false
	%ErrorPopupRetry.visible = false
	ServerRuntimeManager.set_engine_status_hint_visible(false)


func _on_start_pressed() -> void:
	if not _are_story_servers_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_and_image_ready"), true, "start")
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
	if _brainstorm_request_active:
		LLMManager.cancel_active_request()
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


func _on_enhance_confirmed() -> void:
	%EnhanceConfirmPopup.visible = false
	var input: String = %BackgroundInput.text.strip_edges()
	if input.is_empty():
		_show_error_popup(I18n.translate("notice_write_something_first"))
		return
	await _request_enhanced_text(input)


func _on_enhance_confirm_canceled() -> void:
	%EnhanceConfirmPopup.visible = false


func _update_labels() -> void:
	%TopBarTitle.text = I18n.translate("main_title")
	$MarginContainer/ContentPanel/ContentMargin/VBoxContainer/Title.text = I18n.translate("prompt_title")
	$MarginContainer/ContentPanel/ContentMargin/VBoxContainer/Description.text = I18n.translate("prompt_desc")
	%BackgroundInput.placeholder_text = I18n.translate("prompt_placeholder")
	%Random.text = I18n.translate("btn_random")
	%Enhance.text = I18n.translate("btn_enhance")
	%Advanced.text = I18n.translate("btn_flow_setting")
	%Start.text = I18n.translate("btn_start")
	%Back.text = I18n.translate("btn_back")
	%SaveNotice.text = I18n.translate("prompt_save_notice")
	%LoadingLabel.text = I18n.translate("loading_title")
	%ErrorPopupTitle.text = I18n.translate("error_dialog_title")
	%ErrorPopupOk.text = "OK"
	%ErrorPopupRetry.text = I18n.translate("btn_retry")
	%ErrorPopupHelp.text = I18n.translate("btn_help")
	%RandomConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%RandomConfirmMessage.text = I18n.translate("confirm_random_clear_text")
	%RandomConfirmCancel.text = I18n.translate("btn_cancel")
	%RandomConfirmOk.text = I18n.translate("btn_confirm")
	%EnhanceConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%EnhanceConfirmMessage.text = I18n.translate("confirm_enhance_change_text")
	%EnhanceConfirmCancel.text = I18n.translate("btn_cancel")
	%EnhanceConfirmOk.text = I18n.translate("btn_confirm")


func _set_default_prompt() -> void:
	if %BackgroundInput.text.strip_edges().is_empty():
		%BackgroundInput.text = I18n.translate("prompt_default")
