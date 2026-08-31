extends Node

const DialogueController := preload("res://scripts/gameplay_dialogue_controller.gd")

var _failures := 0
var _original_scene_data: Dictionary
var _original_game_settings: Dictionary


class TestHost extends Control:
	var current_dialogue_index := 0
	var total_dialogue := 1
	var _current_dialog_idx := 0
	var _scene_data: Dictionary = {}


func _ready() -> void:
	_original_scene_data = SceneDataManager.scene_data.duplicate(true)
	_original_game_settings = GameSettingsManager.settings.duplicate(true)
	GameSettingsManager.settings["dialogue_text_instant"] = false
	GameSettingsManager.settings["dialogue_text_speed"] = 30
	SceneDataManager.scene_data = {
		"interactions": [{"character": "Narrator", "dialogue": "an apple"}],
	}

	var host := TestHost.new()
	add_child(host)
	var name_label := _add_unique_control(host, Label.new(), "NameLabel") as Label
	var dialog_label := _add_unique_control(host, RichTextLabel.new(), "DialogLabel") as RichTextLabel
	var progress_label := _add_unique_control(host, Label.new(), "DialogProgressLabel") as Label
	var continue_indicator := _add_unique_control(host, Label.new(), "ContinueIndicator") as Label
	var controller := DialogueController.new(host)

	controller.show_current()
	_expect(name_label.text == "Narrator", "character name appears immediately")
	_expect(dialog_label.text == "an apple", "full dialogue is assigned to the dialogue label")
	_expect(dialog_label.visible_characters == 0, "dialogue starts with no visible characters")
	_expect(progress_label.text == "1 / 1", "dialogue progress appears immediately")
	_expect(not continue_indicator.visible, "continue indicator stays hidden while typing")
	controller._dialogue_tween.custom_step(0.1)
	_expect(
		dialog_label.visible_characters > 0 and dialog_label.visible_characters < dialog_label.get_total_character_count(),
		"dialogue is progressively revealed"
	)

	_expect(controller._finish_typewriter(), "first advance action completes the current dialogue")
	_expect(dialog_label.visible_characters == -1, "completing the animation reveals all dialogue")
	_expect(continue_indicator.visible, "continue indicator appears after the dialogue is complete")
	_expect(not controller._finish_typewriter(), "completed dialogue is not treated as still typing")
	GameSettingsManager.settings["dialogue_text_speed"] = 999
	_expect(GameSettingsManager.dialogue_text_speed() == 120, "dialogue speed is capped at its maximum")
	GameSettingsManager.settings["dialogue_text_speed"] = "fast"
	_expect(GameSettingsManager.dialogue_text_speed() == 30, "invalid dialogue speed uses the default")
	GameSettingsManager.settings["dialogue_text_instant"] = true
	controller.show_current()
	_expect(dialog_label.visible_characters == -1, "instant dialogue setting reveals the full line")
	_expect(not controller._finish_typewriter(), "instant dialogue does not start a typewriter animation")
	_expect(continue_indicator.visible, "instant dialogue shows the continue indicator immediately")

	SceneDataManager.scene_data = _original_scene_data
	GameSettingsManager.settings = _original_game_settings
	if _failures == 0:
		print("GameplayDialogueTypewriter: all tests passed")
	get_tree().quit(_failures)


func _add_unique_control(host: Control, control: Control, node_name: String) -> Control:
	control.name = node_name
	control.unique_name_in_owner = true
	host.add_child(control)
	control.owner = host
	return control


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("Gameplay dialogue typewriter test failed: %s" % message)
