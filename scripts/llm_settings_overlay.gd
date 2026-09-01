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
	%ModelOption.item_selected.connect(_on_model_selected)
	%PortInput.text_changed.connect(_on_integer_input_changed.bind(%PortInput))
	%TimeoutInput.text_changed.connect(_on_integer_input_changed.bind(%TimeoutInput))
	%ContextSizeInput.text_changed.connect(_on_integer_input_changed.bind(%ContextSizeInput))
	%NglValueInput.text_changed.connect(_on_integer_input_changed.bind(%NglValueInput))
	%FitCheck.toggled.connect(_on_fit_toggled)
	%NglCheck.toggled.connect(_on_ngl_toggled)
	%PortInput.text_submitted.connect(_on_port_submitted)
	%TimeoutInput.text_submitted.connect(_on_timeout_submitted)
	%ContextSizeInput.text_submitted.connect(_on_context_size_submitted)
	%NglValueInput.text_submitted.connect(_on_ngl_value_submitted)
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	%ConfirmPopup.hide()
	_confirm_action = ConfirmAction.NONE
	visible = true
	LLMSettingsManager.startup_refresh_model_filename_list()
	_pending = LLMSettingsManager.settings.duplicate(true)
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
	LLMSettingsManager.reset_to_defaults()
	_pending = LLMSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_confirm_action = ConfirmAction.SAVE
	%ConfirmMessage.text = I18n.translate("settings_save_restart_confirm")
	%ConfirmPopup.visible = true


func _save_settings() -> void:
	_apply_model_filename()
	_apply_port()
	_apply_timeout()
	_apply_context_size()
	_apply_ngl_value()
	LLMSettingsManager.settings = _pending.duplicate(true)
	LLMSettingsManager.save_settings()
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


func _on_model_selected(index: int) -> void:
	if index >= 0 and index < %ModelOption.item_count:
		_pending["llm_model_filename"] = str(%ModelOption.get_item_text(index))


func _on_timeout_submitted(_text: String) -> void:
	_apply_timeout()


func _on_context_size_submitted(_text: String) -> void:
	_apply_context_size()


func _on_fit_toggled(pressed: bool) -> void:
	_pending["fit"] = pressed
	%FitCheck.text = I18n.translate("settings_on") if pressed else I18n.translate("settings_off")


func _on_ngl_toggled(pressed: bool) -> void:
	_pending["ngl"] = pressed
	%NglCheck.text = I18n.translate("settings_on") if pressed else I18n.translate("settings_off")
	%NglValueInput.editable = pressed


func _on_ngl_value_submitted(_text: String) -> void:
	_apply_ngl_value()


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


func _apply_model_filename() -> void:
	var selected_index: int = %ModelOption.selected
	if selected_index >= 0 and selected_index < %ModelOption.item_count:
		_pending["llm_model_filename"] = str(%ModelOption.get_item_text(selected_index))


func _apply_timeout() -> void:
	var timeout_text: String = %TimeoutInput.text.strip_edges()
	if SettingsValidator.is_valid_timeout(timeout_text):
		_pending["timeout"] = timeout_text.to_int()


func _apply_context_size() -> void:
	var context_size_text: String = %ContextSizeInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(context_size_text):
		_pending["context_size"] = context_size_text.to_int()


func _apply_ngl_value() -> void:
	var ngl_value_text: String = %NglValueInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(ngl_value_text):
		_pending["ngl_value"] = ngl_value_text.to_int()


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	var model_filenames := LLMSettingsManager.get_available_model_filenames()
	%ModelOption.clear()
	for model_filename in model_filenames:
		%ModelOption.add_item(model_filename)
	var selected_model := str(_pending.get("llm_model_filename", ""))
	var model_index := model_filenames.find(selected_model)
	if model_index >= 0:
		%ModelOption.selected = model_index
	%PortInput.text = _integer_text(_pending.get("port", 48763))
	%TimeoutInput.text = _integer_text(_pending["timeout"])
	%ContextSizeInput.text = _integer_text(_pending.get("context_size", 0))
	%FitCheck.button_pressed = bool(_pending["fit"])
	%FitCheck.text = I18n.translate("settings_on") if %FitCheck.button_pressed else I18n.translate("settings_off")
	%NglCheck.button_pressed = bool(_pending["ngl"])
	%NglCheck.text = I18n.translate("settings_on") if %NglCheck.button_pressed else I18n.translate("settings_off")
	%NglValueInput.text = _integer_text(_pending["ngl_value"])
	%NglValueInput.editable = %NglCheck.button_pressed


func _integer_text(value: Variant) -> String:
	return str(str(value).to_int())


func _update_labels() -> void:
	%Title.text = I18n.translate("llm_settings_title")
	%ModelLabel.text = I18n.translate("settings_llm_model")
	%PortLabel.text = I18n.translate("settings_port")
	%TimeoutLabel.text = I18n.translate("settings_timeout")
	%ContextSizeLabel.text = I18n.translate("settings_context_size")
	%FitLabel.text = I18n.translate("settings_llm_fit")
	%NglLabel.text = I18n.translate("settings_llm_ngl")
	%NglValueLabel.text = I18n.translate("settings_llm_ngl_value")
	%FitCheck.text = I18n.translate("settings_on") if %FitCheck.button_pressed else I18n.translate("settings_off")
	%NglCheck.text = I18n.translate("settings_on") if %NglCheck.button_pressed else I18n.translate("settings_off")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
	%ConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%ConfirmOk.text = I18n.translate("btn_confirm")
	%ConfirmCancel.text = I18n.translate("btn_cancel")
