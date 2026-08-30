extends Control

signal closed


func _ready() -> void:
	%TroubleshootingButton.pressed.connect(_show_troubleshooting)
	%GenerationRetryButton.pressed.connect(_show_generation_retry)
	%MinimumRequirementsButton.pressed.connect(_show_minimum_requirements)
	%HelpBack.pressed.connect(_close)
	%TroubleshootingMinimumRequirementsButton.pressed.connect(_show_minimum_requirements)
	%TroubleshootingBack.pressed.connect(_show_hub)
	%GenerationRetryBack.pressed.connect(_show_hub)
	%MinimumRequirementsBack.pressed.connect(_show_hub)
	_update_labels()


func open() -> void:
	visible = true
	_show_hub()
	_update_labels()


func _close() -> void:
	visible = false
	closed.emit()


func _show_hub() -> void:
	%HubCenter.visible = true
	%TroubleshootingOverlay.visible = false
	%GenerationRetryOverlay.visible = false
	%MinimumRequirementsOverlay.visible = false


func _show_troubleshooting() -> void:
	%HubCenter.visible = false
	%TroubleshootingOverlay.visible = true
	%GenerationRetryOverlay.visible = false
	%MinimumRequirementsOverlay.visible = false


func _show_generation_retry() -> void:
	%HubCenter.visible = false
	%TroubleshootingOverlay.visible = false
	%GenerationRetryOverlay.visible = true
	%MinimumRequirementsOverlay.visible = false


func _show_minimum_requirements() -> void:
	%HubCenter.visible = false
	%TroubleshootingOverlay.visible = false
	%GenerationRetryOverlay.visible = false
	%MinimumRequirementsOverlay.visible = true


func _update_labels() -> void:
	%HelpTitle.text = I18n.translate("help_title")
	%TroubleshootingButton.text = I18n.translate("help_engines_keep_starting")
	%GenerationRetryButton.text = I18n.translate("help_generation_retry")
	%MinimumRequirementsButton.text = I18n.translate("help_minimum_requirements")
	%HelpBack.text = I18n.translate("btn_back")
	%TroubleshootingTitle.text = I18n.translate("help_engines_keep_starting")
	%TroubleshootingStepOne.text = I18n.translate("help_check_requirements")
	%TroubleshootingMinimumRequirementsButton.text = I18n.translate("help_minimum_requirements")
	%TroubleshootingStepTwo.text = I18n.translate("help_free_memory")
	%TroubleshootingBack.text = I18n.translate("btn_back")
	%GenerationRetryTitle.text = I18n.translate("help_generation_retry")
	%GenerationRetryTimeout.text = I18n.translate("help_generation_retry_timeout")
	%GenerationRetryLowVram.text = I18n.translate("help_generation_retry_low_vram")
	%GenerationRetryBack.text = I18n.translate("btn_back")
	%MinimumRequirementsTitle.text = I18n.translate("help_minimum_requirements")
	%MinimumRequirementsText.text = I18n.translate("help_minimum_requirements_text")
	%MinimumRequirementsBack.text = I18n.translate("btn_back")
