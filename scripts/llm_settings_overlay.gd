extends Control

signal closed

var _pending := {}


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%ModelOption.item_selected.connect(_on_model_selected)
	%PortInput.text_changed.connect(_on_integer_input_changed.bind(%PortInput))
	%TimeoutInput.text_changed.connect(_on_integer_input_changed.bind(%TimeoutInput))
	%ContextSizeInput.text_changed.connect(_on_integer_input_changed.bind(%ContextSizeInput))
	%PortInput.text_submitted.connect(_on_port_submitted)
	%TimeoutInput.text_submitted.connect(_on_timeout_submitted)
	%ContextSizeInput.text_submitted.connect(_on_context_size_submitted)
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	visible = true
	LLMSettingsManager.startup_refresh_model_filename_list()
	_pending = LLMSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	_pending = {}
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	LLMSettingsManager.reset_to_defaults()
	_pending = LLMSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_apply_model_filename()
	_apply_port()
	_apply_timeout()
	_apply_context_size()
	LLMSettingsManager.settings = _pending.duplicate(true)
	LLMSettingsManager.save_settings()
	_pending = {}
	visible = false
	closed.emit()


func _on_port_submitted(_text: String) -> void:
	_apply_port()


func _on_model_selected(index: int) -> void:
	if index >= 0 and index < %ModelOption.item_count:
		_pending["llm_model_filename"] = str(%ModelOption.get_item_text(index))


func _on_timeout_submitted(_text: String) -> void:
	_apply_timeout()


func _on_context_size_submitted(_text: String) -> void:
	_apply_context_size()


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
	if port_text.is_valid_int():
		var port: int = port_text.to_int()
		if port > 0 and port <= 65535:
			_pending["port"] = port


func _apply_model_filename() -> void:
	var selected_index: int = %ModelOption.selected
	if selected_index >= 0 and selected_index < %ModelOption.item_count:
		_pending["llm_model_filename"] = str(%ModelOption.get_item_text(selected_index))


func _apply_timeout() -> void:
	var timeout_text: String = %TimeoutInput.text.strip_edges()
	if timeout_text.is_valid_int():
		var timeout: int = timeout_text.to_int()
		if timeout > 0:
			_pending["timeout"] = timeout


func _apply_context_size() -> void:
	var context_size_text: String = %ContextSizeInput.text.strip_edges()
	if context_size_text.is_valid_int():
		var context_size: int = context_size_text.to_int()
		if context_size >= 0:
			_pending["context_size"] = context_size


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
	%TimeoutInput.text = _integer_text(_pending.get("timeout", 60))
	%ContextSizeInput.text = _integer_text(_pending.get("context_size", 0))


func _integer_text(value: Variant) -> String:
	return str(str(value).to_int())


func _update_labels() -> void:
	%Title.text = I18n.translate("llm_settings_title")
	%ModelLabel.text = I18n.translate("settings_llm_model")
	%PortLabel.text = I18n.translate("settings_port")
	%TimeoutLabel.text = I18n.translate("settings_timeout")
	%ContextSizeLabel.text = I18n.translate("settings_context_size")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
