extends Control

signal closed

const ScrollbarStyleScript := preload("res://scripts/scrollbar_style.gd")
const SettingsValidator := preload("res://scripts/settings_value_validator.gd")

enum ConfirmAction {
	NONE,
	RESET,
	SAVE,
}

var _pending := {}
var _confirm_action := ConfirmAction.NONE


func _ready() -> void:
	ScrollbarStyleScript.apply(%SettingsScroll)
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%ConfirmCancel.pressed.connect(_on_confirmation_canceled)
	%ConfirmOk.pressed.connect(_on_confirmed)
	%PortInput.text_changed.connect(_on_integer_input_changed.bind(%PortInput))
	%TimeoutInput.text_changed.connect(_on_integer_input_changed.bind(%TimeoutInput))
	%ImageWidthInput.text_changed.connect(_on_integer_input_changed.bind(%ImageWidthInput))
	%ImageHeightInput.text_changed.connect(_on_integer_input_changed.bind(%ImageHeightInput))
	%LowVramCheck.toggled.connect(_on_low_vram_toggled)
	%PortInput.text_submitted.connect(_on_port_submitted)
	%TimeoutInput.text_submitted.connect(_on_timeout_submitted)
	_update_field_visibility()
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	%ConfirmPopup.hide()
	_confirm_action = ConfirmAction.NONE
	visible = true
	_pending = ImageServerSettingsManager.settings.duplicate(true)
	_update_field_visibility()
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	%ConfirmPopup.hide()
	_confirm_action = ConfirmAction.NONE
	_pending = {}
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	_confirm_action = ConfirmAction.RESET
	%ConfirmMessage.text = I18n.translate("settings_reset_restart_confirm")
	%ConfirmPopup.visible = true


func _reset_settings() -> void:
	ImageServerSettingsManager.reset_to_defaults()
	_pending = ImageServerSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_confirm_action = ConfirmAction.SAVE
	%ConfirmMessage.text = I18n.translate("settings_save_restart_confirm")
	%ConfirmPopup.visible = true


func _save_settings() -> void:
	_apply_port()
	_apply_timeout()
	_apply_image_width()
	_apply_image_height()
	_pending["prefix"] = %PrefixInput.text
	_pending["suffix"] = %SuffixInput.text
	ImageServerSettingsManager.settings = _pending.duplicate(true)
	ImageServerSettingsManager.save_settings()
	_pending = {}
	visible = false
	closed.emit()


func _on_confirmed() -> void:
	var action := _confirm_action
	_confirm_action = ConfirmAction.NONE
	%ConfirmPopup.visible = false
	match action:
		ConfirmAction.RESET:
			_reset_settings()
		ConfirmAction.SAVE:
			_save_settings()


func _on_confirmation_canceled() -> void:
	_confirm_action = ConfirmAction.NONE
	%ConfirmPopup.visible = false


func _on_port_submitted(_text: String) -> void:
	_apply_port()


func _on_timeout_submitted(_text: String) -> void:
	_apply_timeout()


func _on_low_vram_toggled(pressed: bool) -> void:
	_pending["low_vram"] = pressed
	%LowVramCheck.text = I18n.translate("settings_on") if pressed else I18n.translate("settings_off")


func _on_integer_input_changed(text: String, input: LineEdit) -> void:
	var sanitized := _digits_only(text)
	if sanitized == text:
		return
	var old_caret := input.caret_column
	input.text = sanitized
	input.caret_column = clampi(old_caret - (text.length() - sanitized.length()), 0, sanitized.length())


func _digits_only(text: String) -> String:
	var result := ""
	for i in range(text.length()):
		var character := text.substr(i, 1)
		if character >= "0" and character <= "9":
			result += character
	return result


func _apply_port() -> void:
	var port_text: String = %PortInput.text.strip_edges()
	if SettingsValidator.is_valid_port(port_text):
		_pending["port"] = port_text.to_int()


func _apply_timeout() -> void:
	var timeout_text: String = %TimeoutInput.text.strip_edges()
	if SettingsValidator.is_valid_timeout(timeout_text):
		_pending["timeout"] = timeout_text.to_int()


func _apply_image_width() -> void:
	var width_text: String = %ImageWidthInput.text.strip_edges()
	if SettingsValidator.is_valid_image_dimension(width_text):
		_pending["image_width"] = width_text


func _apply_image_height() -> void:
	var height_text: String = %ImageHeightInput.text.strip_edges()
	if SettingsValidator.is_valid_image_dimension(height_text):
		_pending["image_height"] = height_text


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	%PortInput.text = _integer_text(_pending.get("port", 56321))
	%TimeoutInput.text = _integer_text(_pending["timeout"])
	%ImageWidthInput.text = str(_pending["image_width"])
	%ImageHeightInput.text = str(_pending["image_height"])
	%LowVramCheck.button_pressed = bool(_pending["low_vram"])
	%LowVramCheck.text = I18n.translate("settings_on") if %LowVramCheck.button_pressed else I18n.translate("settings_off")
	%PrefixInput.text = str(_pending.get("prefix", ""))
	%SuffixInput.text = str(_pending.get("suffix", ""))


func _integer_text(value: Variant) -> String:
	return str(str(value).to_int())


func _update_field_visibility() -> void:
	var show_prompt_affixes := GameSettingsManager.is_builder_mode()
	%PrefixRow.visible = show_prompt_affixes
	%SuffixRow.visible = show_prompt_affixes
	%ImageWidthRow.visible = show_prompt_affixes
	%ImageHeightRow.visible = show_prompt_affixes


func _update_labels() -> void:
	%Title.text = I18n.translate("image_server_settings_title")
	%PortLabel.text = I18n.translate("settings_port")
	%TimeoutLabel.text = I18n.translate("settings_timeout")
	%LowVramLabel.text = I18n.translate("settings_low_vram")
	%ImageWidthLabel.text = I18n.translate("settings_image_width")
	%ImageHeightLabel.text = I18n.translate("settings_image_height")
	%LowVramCheck.text = I18n.translate("settings_on") if %LowVramCheck.button_pressed else I18n.translate("settings_off")
	%PrefixLabel.text = I18n.translate("settings_prompt_prefix")
	%SuffixLabel.text = I18n.translate("settings_prompt_suffix")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
	%ConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%ConfirmOk.text = I18n.translate("btn_confirm")
	%ConfirmCancel.text = I18n.translate("btn_cancel")
