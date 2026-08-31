extends Control

signal closed

const SettingsValidator := preload("res://scripts/settings_value_validator.gd")

var _pending := {}


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
	%ExpectedRoundInput.text_changed.connect(_on_integer_input_changed.bind(%ExpectedRoundInput))
	%MinDialogueRoundsInput.text_changed.connect(_on_integer_input_changed.bind(%MinDialogueRoundsInput))
	%MinSentencesInput.text_changed.connect(_on_integer_input_changed.bind(%MinSentencesInput))
	%MaxPlotDirectionsInput.text_changed.connect(_on_integer_input_changed.bind(%MaxPlotDirectionsInput))
	%MinSummaryInput.text_changed.connect(_on_integer_input_changed.bind(%MinSummaryInput))
	_sync_ui_to_settings()
	_update_labels()


func open() -> void:
	visible = true
	_pending = GameProgressManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_back_pressed() -> void:
	_pending = {}
	visible = false
	closed.emit()


func _on_reset_pressed() -> void:
	GameProgressManager.reset_flow_settings_to_defaults()
	_pending = GameProgressManager.settings.duplicate(true)
	_sync_ui_to_settings()
	_update_labels()


func _on_save_pressed() -> void:
	_apply_pending_from_ui()
	# Preserve current_dialogue/current_uuid unchanged? Keep existing values from manager
	# _pending already contains them duplicated, not edited by UI, so safe.
	GameProgressManager.settings = _pending.duplicate(true)
	GameProgressManager.save_settings()
	_pending = {}
	visible = false
	closed.emit()


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


func _apply_pending_from_ui() -> void:
	var v: String
	v = %ExpectedRoundInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(v):
		_pending["expected_rounds"] = v.to_int()
	v = %MinDialogueRoundsInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(v):
		_pending["minimum_dialogues_per_scene"] = v.to_int()
	v = %MinSentencesInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(v):
		_pending["minimum_sentences_per_dialogue"] = v.to_int()
	v = %MaxPlotDirectionsInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(v):
		var plot_directions := v.to_int()
		_pending["minimum_plot_directions"] = plot_directions
		# also support alias maximum_plot_directions if used
		_pending["maximum_plot_directions"] = plot_directions
	v = %MinSummaryInput.text.strip_edges()
	if SettingsValidator.is_non_negative_integer(v):
		_pending["minimum_sentences_in_summary"] = v.to_int()


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	%ExpectedRoundInput.text = _integer_text(_pending.get("expected_rounds", 1))
	%MinDialogueRoundsInput.text = _integer_text(_pending.get("minimum_dialogues_per_scene", 10))
	%MinSentencesInput.text = _integer_text(_pending.get("minimum_sentences_per_dialogue", 10))
	# Support both minimum_plot_directions and maximum_plot_directions keys
	var plot_val: Variant = _pending.get("minimum_plot_directions", _pending.get("maximum_plot_directions", 10))
	%MaxPlotDirectionsInput.text = _integer_text(plot_val)
	%MinSummaryInput.text = _integer_text(_pending.get("minimum_sentences_in_summary", 10))


func _integer_text(value: Variant) -> String:
	return str(str(value).to_int())


func _update_labels() -> void:
	%Title.text = I18n.translate("game_progress_title")
	%ExpectedRoundLabel.text = I18n.translate("game_progress_expected_round")
	%MinDialogueRoundsLabel.text = I18n.translate("game_progress_min_dialogue_rounds")
	%MinSentencesLabel.text = I18n.translate("game_progress_min_sentences")
	%MaxPlotDirectionsLabel.text = I18n.translate("game_progress_max_plot_directions")
	%MinSummaryLabel.text = I18n.translate("game_progress_min_summary")
	%Back.text = I18n.translate("btn_back")
	%Reset.text = I18n.translate("btn_reset")
	%Save.text = I18n.translate("btn_save")
