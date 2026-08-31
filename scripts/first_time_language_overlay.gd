extends Control

signal language_selected(lang: String)

const MAX_LANGUAGES_PER_ROW := 5
const LANGUAGE_BUTTON_MINIMUM_SIZE := Vector2(180, 56)

var _selected_language := ""


func _ready() -> void:
	_populate_language_grid()
	%ConfirmButton.pressed.connect(_confirm_requirements)
	_update_labels()


func _populate_language_grid() -> void:
	%LanguageGrid.columns = MAX_LANGUAGES_PER_ROW
	for lang in I18n.LANGUAGES:
		var button := Button.new()
		button.name = "Language_%s" % lang
		button.custom_minimum_size = LANGUAGE_BUTTON_MINIMUM_SIZE
		button.text = I18n.translate("lang_" + lang.to_lower())
		button.pressed.connect(_choose_language.bind(lang))
		%LanguageGrid.add_child(button)


func open() -> void:
	_selected_language = ""
	_set_requirements_step_visible(false)
	visible = true
	_update_labels()


func _choose_language(lang: String) -> void:
	_selected_language = lang
	GameSettingsManager.set_language(lang)
	_set_requirements_step_visible(true)
	_update_labels()


func _confirm_requirements() -> void:
	if _selected_language.is_empty():
		return
	GameSettingsManager.complete_first_time_setup()
	visible = false
	language_selected.emit(_selected_language)


func _set_requirements_step_visible(show_requirements: bool) -> void:
	for node in [%Title, %Spacer, %LanguageGrid]:
		node.visible = not show_requirements
	for node in [%RequirementsTitle, %RequirementsList, %ConfirmButton]:
		node.visible = show_requirements
	_update_nvidia_result()


func _update_labels() -> void:
	%Title.text = "Language"
	%RequirementsTitle.text = I18n.translate("first_time_requirements_title")
	%RequirementsList.text = I18n.translate("first_time_requirements_list")
	%CheckTitle.text = I18n.translate("first_time_quick_check")
	%ConfirmButton.text = I18n.translate("first_time_confirm")
	_update_nvidia_result()


func _update_nvidia_result() -> void:
	var adapter_name := RenderingServer.get_video_adapter_name().strip_edges()
	var adapter_vendor := RenderingServer.get_video_adapter_vendor().strip_edges()
	var adapter_description := adapter_name
	if adapter_description.is_empty():
		adapter_description = adapter_vendor
	var is_nvidia := (adapter_name + " " + adapter_vendor).to_lower().contains("nvidia")
	if adapter_description.is_empty():
		adapter_description = I18n.translate("first_time_gpu_unknown")
	var show_check_failure: bool = %RequirementsTitle.visible and not is_nvidia
	for node in [%CheckSeparator, %CheckTitle, %NvidiaResult]:
		node.visible = show_check_failure
	if show_check_failure:
		%NvidiaResult.text = I18n.translate("first_time_nvidia_fail") % adapter_description
		%NvidiaResult.modulate = Color(1.0, 0.55, 0.45)
