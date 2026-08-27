extends Control

signal closed
signal image_settings_requested
signal llm_settings_requested


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%ImageSetting.pressed.connect(_on_image_setting_pressed)
	%LLMSetting.pressed.connect(_on_llm_setting_pressed)
	_update_labels()


func open() -> void:
	visible = true
	_update_labels()


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_image_setting_pressed() -> void:
	visible = false
	image_settings_requested.emit()


func _on_llm_setting_pressed() -> void:
	visible = false
	llm_settings_requested.emit()


func _update_labels() -> void:
	%Title.text = I18n.translate("advanced_settings_title")
	%ImageSetting.text = I18n.translate("btn_image_server_setting")
	%LLMSetting.text = I18n.translate("btn_llm_setting")
	%Back.text = I18n.translate("btn_back")
