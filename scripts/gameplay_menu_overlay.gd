extends Control

signal closed
signal load_requested
signal gallery_requested
signal game_settings_requested
signal advanced_settings_requested
signal main_menu_requested
signal quit_game_requested

enum LeaveAction {
	NONE,
	MAIN_MENU,
	QUIT_GAME,
}

var _pending_leave_action := LeaveAction.NONE


func _ready() -> void:
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%GameSetting.pressed.connect(_on_game_setting_pressed)
	%AdvancedSetting.pressed.connect(_on_advanced_setting_pressed)
	%BackToMainMenu.pressed.connect(_on_back_to_main_menu_pressed)
	%QuitGame.pressed.connect(_on_quit_game_pressed)
	%Back.pressed.connect(_on_back_pressed)
	%LeaveConfirmBack.pressed.connect(_on_leave_confirmation_back_pressed)
	%LeaveConfirmOk.pressed.connect(_on_leave_confirmation_confirmed)
	%LeaveConfirmPopup.visible = false
	_update_labels()


func open() -> void:
	_pending_leave_action = LeaveAction.NONE
	%LeaveConfirmPopup.visible = false
	visible = true
	_update_labels()


func close() -> void:
	_pending_leave_action = LeaveAction.NONE
	%LeaveConfirmPopup.visible = false
	visible = false
	closed.emit()


func _on_load_pressed() -> void:
	visible = false
	load_requested.emit()


func _on_gallery_pressed() -> void:
	visible = false
	gallery_requested.emit()


func _on_game_setting_pressed() -> void:
	visible = false
	game_settings_requested.emit()


func _on_advanced_setting_pressed() -> void:
	visible = false
	advanced_settings_requested.emit()


func _on_back_to_main_menu_pressed() -> void:
	_request_leave(LeaveAction.MAIN_MENU)


func _on_quit_game_pressed() -> void:
	_request_leave(LeaveAction.QUIT_GAME)


func _request_leave(action: LeaveAction) -> void:
	if ServerRuntimeManager.has_generation_requests():
		_pending_leave_action = action
		%LeaveConfirmPopup.visible = true
		%LeaveConfirmBack.grab_focus()
		return
	_emit_leave_action(action)


func _on_leave_confirmation_back_pressed() -> void:
	var action := _pending_leave_action
	_pending_leave_action = LeaveAction.NONE
	%LeaveConfirmPopup.visible = false
	if action == LeaveAction.QUIT_GAME:
		%QuitGame.grab_focus()
	else:
		%BackToMainMenu.grab_focus()


func _on_leave_confirmation_confirmed() -> void:
	var action := _pending_leave_action
	_pending_leave_action = LeaveAction.NONE
	%LeaveConfirmPopup.visible = false
	_emit_leave_action(action)


func _emit_leave_action(action: LeaveAction) -> void:
	visible = false
	match action:
		LeaveAction.MAIN_MENU:
			main_menu_requested.emit()
		LeaveAction.QUIT_GAME:
			quit_game_requested.emit()


func _on_back_pressed() -> void:
	close()


func _update_labels() -> void:
	%Title.text = I18n.translate("gameplay_menu_title")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%GameSetting.text = I18n.translate("btn_game_setting")
	%AdvancedSetting.text = I18n.translate("btn_advanced_setting")
	%BackToMainMenu.text = I18n.translate("btn_back_to_main_menu")
	%QuitGame.text = I18n.translate("btn_quit_game")
	%Back.text = I18n.translate("btn_back")
	%LeaveConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%LeaveConfirmMessage.text = I18n.translate("confirm_leave_generation_pending")
	%LeaveConfirmBack.text = I18n.translate("btn_back")
	%LeaveConfirmOk.text = I18n.translate("btn_confirm")
