extends Control

signal closed

var _pending := {}


func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Reset.pressed.connect(_on_reset_pressed)
	%Save.pressed.connect(_on_save_pressed)
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
	GameProgressManager.reset_to_defaults()
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


func _apply_pending_from_ui() -> void:
	var v: String
	v = %ExpectedRoundInput.text.strip_edges()
	if v.is_valid_int():
		_pending["expected_round"] = v.to_int()
	v = %MinDialogueRoundsInput.text.strip_edges()
	if v.is_valid_int():
		_pending["minimum_dialogues_per_round"] = v.to_int()
	v = %MinSentencesInput.text.strip_edges()
	if v.is_valid_int():
		_pending["minimum_sentences_per_dialogue"] = v.to_int()
	v = %MaxPlotDirectionsInput.text.strip_edges()
	if v.is_valid_int():
		_pending["minimum_plot_directions"] = v.to_int()
		# also support alias maximum_plot_directions if used
		_pending["maximum_plot_directions"] = v.to_int()
	v = %MinSummaryInput.text.strip_edges()
	if v.is_valid_int():
		_pending["minimum_summary_sentences"] = v.to_int()
	_pending["image_instruction"] = %ImageInstructionInput.text


func _sync_ui_to_settings() -> void:
	if _pending.is_empty():
		return
	%ExpectedRoundInput.text = str(_pending.get("expected_round", 1))
	%MinDialogueRoundsInput.text = str(_pending.get("minimum_dialogues_per_round", 10))
	%MinSentencesInput.text = str(_pending.get("minimum_sentences_per_dialogue", 10))
	# Support both minimum_plot_directions and maximum_plot_directions keys
	var plot_val: Variant = _pending.get("minimum_plot_directions", _pending.get("maximum_plot_directions", 10))
	%MaxPlotDirectionsInput.text = str(plot_val)
	%MinSummaryInput.text = str(_pending.get("minimum_summary_sentences", 10))
	%ImageInstructionInput.text = str(_pending.get("image_instruction", ""))


func _update_labels() -> void:
	%Title.text = "Advanced Settings"
	%ExpectedRoundLabel.text = "Expected Round"
	%MinDialogueRoundsLabel.text = "Minimum Dialogue Rounds"
	%MinSentencesLabel.text = "Minimum Sentences per Dialogue"
	%MaxPlotDirectionsLabel.text = "Maximum Plot Directions"
	%MinSummaryLabel.text = "Minimum Summary Sentences"
	%ImageInstructionLabel.text = "Image Instruction (optional)"
	%Back.text = "Back"
	%Reset.text = "Reset"
	%Save.text = "Save"
