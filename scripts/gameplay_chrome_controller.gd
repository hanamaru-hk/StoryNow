class_name GameplayChromeController
extends RefCounted

const BLOCKING_OVERLAYS: Array[String] = [
	"ChoiceOverlay", "ImageActionOverlay", "ImageChangeOverlay", "ImageOverlay",
	"SummaryOverlay", "PlotOverlay", "GameplayMenuOverlay", "LoadGameOverlay",
	"GalleryOverlay", "GameSettingsOverlay", "AdvancedSettingsOverlay",
	"ImageServerSettingsOverlay", "LLMSettingsOverlay", "GameProgressOverlay",
	"ErrorReturnPopup",
]

var _host: Control
var _visible := true


func _init(host: Control) -> void:
	_host = host


func handle_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if not _visible:
		set_visible(true)
		_host.get_viewport().set_input_as_handled()
		return
	if _has_blocking_overlay():
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and _is_background_click(event.position):
		set_visible(false)
		_host.get_viewport().set_input_as_handled()


func toggle() -> void:
	set_visible(not _visible)


func set_visible(is_visible: bool) -> void:
	_visible = is_visible
	_host.set("_chrome_visible", is_visible)
	for name in ["TopBar", "Dialogue"]:
		var control := _unique_node(name) as Control
		if control:
			control.visible = is_visible
	ServerRuntimeManager.set_chrome_visible(is_visible)


func _is_background_click(position: Vector2) -> bool:
	var background := _unique_node("BackgroundImage") as Control
	var top_bar := _unique_node("TopBar") as Control
	var dialogue := _unique_node("Dialogue") as Control
	return _contains(background, position) and not _contains_visible(top_bar, position) and not _contains_visible(dialogue, position)


func _has_blocking_overlay() -> bool:
	for overlay_name in BLOCKING_OVERLAYS:
		var overlay := _host.get_node_or_null(overlay_name)
		if overlay is CanvasItem and overlay.visible:
			return true
	return false


func _contains_visible(control: Control, position: Vector2) -> bool:
	return control != null and control.visible and _contains(control, position)


func _contains(control: Control, position: Vector2) -> bool:
	return control != null and control.get_global_rect().has_point(position)


func _unique_node(name: String) -> Node:
	return _host.get_node_or_null(NodePath("%%%s" % name))
