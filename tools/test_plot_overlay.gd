extends Node

const PlotOverlayScene := preload("res://scenes/plot_overlay.tscn")

var _failures := 0
var _original_scene_data: Dictionary


func _ready() -> void:
	_original_scene_data = SceneDataManager.scene_data
	var overlay := PlotOverlayScene.instantiate()
	add_child(overlay)
	_test_layout(overlay)
	_test_sex_values(overlay)
	_test_add_dialogue_form(overlay)
	_test_last_dialogue_guard(overlay)
	SceneDataManager.scene_data = _original_scene_data
	overlay.queue_free()
	if _failures == 0:
		print("PlotOverlay: all tests passed")
	get_tree().quit(_failures)


func _test_layout(overlay: Control) -> void:
	var panel := overlay.get_node("EditOverlay/CenterContainer/Panel") as PanelContainer
	_expect(panel.custom_minimum_size.x >= 900.0, "edit dialogue list is widened")
	_expect(overlay.has_node("%EditDelete"), "edit popup has a delete button")
	_expect(overlay.has_node("%SexDropdown"), "edit popup has a sex dropdown")
	_expect(overlay.has_node("%CustomSexInput"), "edit popup has a custom sex input")
	var add_panel := overlay.get_node("AddOverlay/CenterContainer/Panel") as PanelContainer
	_expect(add_panel.custom_minimum_size.x == 960.0, "add dialogue overlay is widened by 50 percent")
	_expect(overlay.has_node("%AddCharacter"), "add dialogue form has a character field")
	_expect(overlay.has_node("%AddSexDropdown"), "add dialogue form has a sex dropdown")
	_expect(overlay.has_node("%AddCustomSexInput"), "add dialogue form has a custom sex input")
	_expect(overlay.has_node("%AddDialogue"), "add dialogue form has a dialogue textarea")
	var form := overlay.get_node("AddOverlay/CenterContainer/Panel/Margin/VBox/AddGroup/Margin/VBox")
	var dropdown_row := form.get_node("DropdownRow")
	var radio_row := form.get_node("RadioRow") as HBoxContainer
	_expect(dropdown_row.get_index() > radio_row.get_index(), "dialogue dropdown is below the radio buttons")
	_expect(dropdown_row.get_index() == form.get_child_count() - 1, "dialogue dropdown is the final form row")
	_expect(radio_row.alignment == BoxContainer.ALIGNMENT_BEGIN, "before and after radio buttons align left")


func _test_sex_values(overlay: Control) -> void:
	overlay.call("_set_sex_editor_value", "male")
	_expect(overlay.call("_get_edited_sex") == "male", "male label stores the English male value")
	overlay.call("_set_sex_editor_value", "female")
	_expect(overlay.call("_get_edited_sex") == "female", "female label stores the English female value")
	overlay.call("_set_sex_editor_value", "nonbinary")
	_expect(overlay.call("_get_edited_sex") == "nonbinary", "Other stores the user's custom value")


func _test_add_dialogue_form(overlay: Control) -> void:
	var dropdown := overlay.get_node("%AddSexDropdown") as OptionButton
	var custom_input := overlay.get_node("%AddCustomSexInput") as LineEdit
	for i in dropdown.item_count:
		if dropdown.get_item_id(i) == 2:
			dropdown.select(i)
			overlay.call("_on_add_sex_selected", i)
			break
	custom_input.text = "nonbinary"
	_expect(overlay.call("_get_add_sex") == "nonbinary", "add form Other stores the user's custom value")


func _test_last_dialogue_guard(overlay: Control) -> void:
	SceneDataManager.scene_data = {
		"interactions": [{"character": "Narrator", "dialogue": "Only line", "sex": "male"}]
	}
	overlay.set("_editing_index", 0)
	overlay.call("_on_edit_delete_pressed")
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	_expect(interactions.size() == 1, "last dialogue is not deleted")
	var error_dialog := overlay.get_node("%LastDialogueError") as AcceptDialog
	_expect(error_dialog.visible, "last dialogue deletion shows an error dialog")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("PlotOverlay test failed: %s" % message)
