extends Control

signal closed

var _pending := {}


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%PortInput.text_submitted.connect(_on_port_submitted)
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	visible = true
	_pending = ImageServerSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	_pending = {}
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	ImageServerSettingsManager.reset_to_defaults()
	_pending = ImageServerSettingsManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_apply_port()
	ImageServerSettingsManager.settings = _pending.duplicate(true)
	ImageServerSettingsManager.save_settings()
	_pending = {}
	visible = false
	closed.emit()


func _on_port_submitted(_text: String) -> void:
	_apply_port()


func _apply_port() -> void:
	var port_text: String = %PortInput.text.strip_edges()
	if port_text.is_valid_int():
		var port: int = port_text.to_int()
		if port > 0 and port <= 65535:
			_pending["port"] = port


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	%PortInput.text = str(_pending["port"])


func _update_labels() -> void:
	%Title.text = I18n.translate("image_server_settings_title")
	%PortLabel.text = I18n.translate("settings_port")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
