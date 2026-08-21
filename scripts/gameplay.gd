extends Control

# Scene data model (mirrors LLM output):
# {
#   "scenePrompt": String,
#   "dialog": Array[Dictionary],  # e.g. [{"Alice": "hi"}, {"narration": "..."}]
#   "choices": Array[String],      # alias: "next"
#   "storyBackground": String,
#   "image": ImageTexture (optional, runtime)
# }

var _scenes: Array = []
var _current_scene_idx: int = 0
var _current_dialog_idx: int = 0

# Story background prompt passed from brainstorm scene (autoload or arg)
var story_background: String = ""


func _ready() -> void:
	# --- Dialogue panel grid buttons ---
	%PlotButton.pressed.connect(_on_plot_pressed)
	%SettingButton.pressed.connect(_on_setting_pressed)
	%DialogButton.pressed.connect(_on_dialog_btn_pressed)
	%ImageButton.pressed.connect(_on_image_btn_pressed)
	%PrevDialogButton.pressed.connect(_on_prev_dialog_pressed)
	%NextDialogButton.pressed.connect(_on_next_dialog_pressed)
	%PrevSceneButton.pressed.connect(_on_prev_scene_pressed)
	%NextSceneButton.pressed.connect(_on_next_scene_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false

	# --- ErrorReturnDialog ---
	%ErrorReturnDialog.confirmed.connect(_on_error_return)
	%ErrorReturnDialog.canceled.connect(_on_error_return)
	# AcceptDialog close via X also triggers canceled

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	_update_labels()
	_load_default_background()
	# If launched without preloaded scenes, create placeholder for layout testing
	if _scenes.is_empty():
		_load_placeholder_scenes()
	_show_scene(0)


func _load_default_background() -> void:
	# Runtime load to avoid requiring .import (handles missing Texture2D loader error).
	# Uses Image.load_from_file via globalized path, then ImageTexture.
	var res_path := "res://assets/images/loading.jpg"
	var global_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# Fallback: try direct res:// path (works if file is imported elsewhere)
		err = img.load(res_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		%BackgroundImage.texture = tex
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)
	else:
		# Final fallback: try ResourceLoader (requires import)
		var res_tex: Resource = load(res_path)
		if res_tex is Texture2D:
			%BackgroundImage.texture = res_tex
		else:
			push_warning("Failed to load default background %s: %s" % [res_path, err])
		# Keep modulate for placeholder / 50% opacity
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)


func set_story_background(prompt: String) -> void:
	story_background = prompt


func push_scene(scene: Dictionary) -> void:
	# Normalize alias: LLM uses "choices", user spec calls it "next"
	if not scene.has("choices") and scene.has("next"):
		scene["choices"] = scene["next"]
	if not scene.has("next") and scene.has("choices"):
		scene["next"] = scene["choices"]
	_scenes.append(scene)


func _load_placeholder_scenes() -> void:
	# Two placeholder scenes for visual testing without LLM/ComfyUI
	_scenes = [
		{
			"scenePrompt": "cozy tavern interior, warm lighting",
			"dialog": [
				{"narration": "The tavern door creaks open. Rain drums on the roof."},
				{"Alice": "We shouldn't have come here..."},
				{"Bob": "We had no choice. The map led us here."},
			],
			"choices": ["Ask the bartender", "Sit at the corner table", "Leave immediately"],
			"next": ["Ask the bartender", "Sit at the corner table", "Leave immediately"],
			"storyBackground": story_background,
		},
		{
			"scenePrompt": "dark forest path, moonlight through trees",
			"dialog": [
				{"narration": "You step outside. The forest is silent."},
				{"Alice": "Do you hear that?"},
			],
			"choices": ["Follow the sound", "Run back inside"],
			"next": ["Follow the sound", "Run back inside"],
			"storyBackground": story_background,
		},
	]


# ------------------------------------------------------------------
# Scene / Dialog rendering
# ------------------------------------------------------------------
func _show_scene(idx: int) -> void:
	if _scenes.is_empty():
		return
	_current_scene_idx = clampi(idx, 0, _scenes.size() - 1)
	var scene: Dictionary = _scenes[_current_scene_idx]
	# Alias normalization
	if not scene.has("choices") and scene.has("next"):
		scene["choices"] = scene["next"]
	if scene.has("scenePrompt"):
		%ScenePromptLabel.text = str(scene["scenePrompt"])
	else:
		%ScenePromptLabel.text = ""

	# TODO: load image via ImageServerManager using scenePrompt
	# For now placeholder color / text
	# Example: var tex := await ImageServerManager.generate(scene["scenePrompt"])
	#          %BackgroundImage.texture = tex

	_current_dialog_idx = 0
	_show_dialog(_current_dialog_idx)
	_update_nav_buttons()
	# Hide choice overlay when entering a scene; it is shown only after last dialog
	%ChoiceOverlay.visible = false


func _show_dialog(idx: int) -> void:
	if _scenes.is_empty():
		return
	var scene: Dictionary = _scenes[_current_scene_idx]
	var dialogs: Array = scene.get("dialog", [])
	if dialogs.is_empty():
		%NameLabel.text = ""
		%DialogLabel.text = "(no dialog)"
		return
	_current_dialog_idx = clampi(idx, 0, dialogs.size() - 1)
	var entry: Dictionary = dialogs[_current_dialog_idx]
	# entry is single-key dict: {"Alice": "hi"} or {"narration": "..."}
	var speaker: String = ""
	var content: String = ""
	for k in entry.keys():
		speaker = str(k)
		content = str(entry[k])
		break
	if speaker == "narration":
		%NameLabel.text = ""
	else:
		%NameLabel.text = speaker
	%DialogLabel.text = content

	# Progress indicator
	%DialogProgressLabel.text = "%d / %d" % [_current_dialog_idx + 1, dialogs.size()]
	%SceneProgressLabel.text = "Scene %d / %d" % [_current_scene_idx + 1, _scenes.size()]
	_update_nav_buttons()

	# If this is the last dialog line, optionally hint that Next will open choices
	if _current_dialog_idx == dialogs.size() - 1:
		%NextDialogButton.text = I18n.translate("btn_choice") if I18n.translate("btn_choice") != "btn_choice" else "Choice >"
	else:
		%NextDialogButton.text = I18n.translate("btn_next_dialog") if I18n.translate("btn_next_dialog") != "btn_next_dialog" else "Next >"


func _update_nav_buttons() -> void:
	if _scenes.is_empty():
		return
	var scene: Dictionary = _scenes[_current_scene_idx]
	var dialogs: Array = scene.get("dialog", [])
	%PrevDialogButton.disabled = _current_dialog_idx <= 0
	# Next dialog is disabled only if we need to handle choice overlay externally
	# We keep it enabled; _on_next_dialog_pressed will open overlay at end.
	%NextDialogButton.disabled = false
	%PrevSceneButton.disabled = _current_scene_idx <= 0
	var is_last_dialog: bool = _current_dialog_idx >= dialogs.size() - 1
	# Next scene is enabled if not on last scene, or if last dialog allows branching
	%NextSceneButton.disabled = false
	# Dim hint when at last dialog and next scene would require choice
	if is_last_dialog and _current_scene_idx >= _scenes.size() - 1:
		%NextSceneButton.text = I18n.translate("btn_next_scene_choice") if I18n.translate("btn_next_scene_choice") != "btn_next_scene_choice" else "Next Scene *"
	else:
		%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Next Scene >"


# ------------------------------------------------------------------
# Input handlers
# ------------------------------------------------------------------
# Trigger: virtual Node._input / _unhandled_input — called automatically by Godot's
# input dispatch (no signal connection needed). _input is used so right-click
# works even when GUI Controls (Dialogue/TopBar) would otherwise mark the event
# as handled and prevent _unhandled_input from firing.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Don't toggle when choice/error overlays are open
		if %ChoiceOverlay.visible or %ErrorReturnDialog.visible:
			return
		_toggle_chrome()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Fallback duplicate for cases where _input is filtered; keeps same logic.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if %ChoiceOverlay.visible or %ErrorReturnDialog.visible:
			return
		_toggle_chrome()
		get_viewport().set_input_as_handled()


func _toggle_chrome() -> void:
	# Toggle TopBar and Dialogue visibility together (right-click anywhere)
	var next_visible: bool = not %Dialogue.visible
	%Dialogue.visible = next_visible
	%TopBar.visible = next_visible


func _on_dialog_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_dialog_pressed()


func _on_prev_dialog_pressed() -> void:
	if _current_dialog_idx > 0:
		_show_dialog(_current_dialog_idx - 1)
	else:
		# At first dialog, go to previous scene's last dialog if exists
		if _current_scene_idx > 0:
			_show_scene(_current_scene_idx - 1)
			var prev_dialogs: Array = _scenes[_current_scene_idx].get("dialog", [])
			_show_dialog(prev_dialogs.size() - 1)


func _on_next_dialog_pressed() -> void:
	var scene: Dictionary = _scenes[_current_scene_idx]
	var dialogs: Array = scene.get("dialog", [])
	if _current_dialog_idx < dialogs.size() - 1:
		_show_dialog(_current_dialog_idx + 1)
	else:
		# Last line -> open choice overlay for next scene
		_show_choice_overlay()


func _on_prev_scene_pressed() -> void:
	if _current_scene_idx > 0:
		_show_scene(_current_scene_idx - 1)
	else:
		_show_dialog(0)


func _on_next_scene_pressed() -> void:
	if _current_scene_idx < _scenes.size() - 1:
		_show_scene(_current_scene_idx + 1)
	else:
		_show_choice_overlay()


func _on_dialog_btn_pressed() -> void:
	# Focus / highlight dialog area — for now just ensure dialog visible
	%DialogArea.visible = true
	%BackgroundImage.visible = true


func _on_image_btn_pressed() -> void:
	# Toggle fullscreen image view idea: hide Dialogue temporarily on click
	# Simple toggle: hide/show Dialogue bottom panel
	%Dialogue.visible = not %Dialogue.visible


func _on_plot_pressed() -> void:
	# Placeholder: show storyBackground / plot summary
	var scene: Dictionary = _scenes[_current_scene_idx]
	var bg: String = str(scene.get("storyBackground", story_background))
	if bg.is_empty():
		bg = "(no plot info)"
	%DialogLabel.text = bg
	%NameLabel.text = "Plot"


func _on_setting_pressed() -> void:
	# Reuse existing settings overlay? For now show language/settings hint
	%DialogLabel.text = "Language: %s | Scenes: %d" % [I18n.current_lang, _scenes.size()]
	%NameLabel.text = "Setting"


# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	var scene: Dictionary = _scenes[_current_scene_idx]
	var next_steps: Array = scene.get("next", scene.get("choices", []))
	# Clear previous buttons
	for child in %ChoiceList.get_children():
		child.queue_free()

	for choice_text in next_steps:
		var btn := Button.new()
		btn.text = str(choice_text)
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_choice_button_pressed.bind(str(choice_text)))
		%ChoiceList.add_child(btn)

	# Add a separator label if no choices
	if next_steps.is_empty():
		var lbl := Label.new()
		lbl.text = "(No choices — write your own below)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		%ChoiceList.add_child(lbl)

	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false


func _on_choice_button_pressed(choice_text: String) -> void:
	_hide_choice_overlay()
	await _advance_with_choice(choice_text)


func _on_choice_confirm() -> void:
	var custom_text: String = %CustomInput.text.strip_edges()
	var chosen: String = custom_text
	if chosen.is_empty():
		# If no custom text, pick first choice if exists
		var scene: Dictionary = _scenes[_current_scene_idx]
		var next_steps: Array = scene.get("next", scene.get("choices", []))
		if not next_steps.is_empty():
			chosen = str(next_steps[0])
		else:
			return
	_hide_choice_overlay()
	await _advance_with_choice(chosen)


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


func _advance_with_choice(choice_text: String) -> void:
	# If we already have a next scene buffered, just navigate
	if _current_scene_idx < _scenes.size() - 1:
		_show_scene(_current_scene_idx + 1)
		return
	# Otherwise request new scene from LLM (stub for now)
	# Real flow:
	#   %ChoiceOverlay.visible = true with loading spinner
	#   var result := await LLMManager.generate_next_scene(story_background, _scenes, choice_text)
	#   if not result.success: show_error(...)
	#   else: push_scene(result.scene); _show_scene(_scenes.size()-1)
	# Placeholder: synthesize a dummy next scene locally so layout is testable
	var new_scene := {
		"scenePrompt": "generated from choice: " + choice_text,
		"dialog": [
			{"narration": "You chose: " + choice_text},
			{"Alice": "Let's see what happens next..."},
		],
		"choices": ["Continue", "Try something else", "Look around"],
		"next": ["Continue", "Try something else", "Look around"],
		"storyBackground": story_background,
	}
	push_scene(new_scene)
	_show_scene(_scenes.size() - 1)


# ------------------------------------------------------------------
# Error handling — common error return dialog for returning to main menu
# ------------------------------------------------------------------
func show_error(message: String) -> void:
	%ErrorReturnDialog.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnDialog.title = I18n.translate("error_dialog_title")
	%ErrorReturnDialog.popup_centered()


func _on_error_return() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	%DialogButton.text = I18n.translate("btn_dialog") if I18n.translate("btn_dialog") != "btn_dialog" else "Dialog"
	%ImageButton.text = I18n.translate("btn_image") if I18n.translate("btn_image") != "btn_image" else "Image"
	%PlotButton.text = I18n.translate("btn_plot") if I18n.translate("btn_plot") != "btn_plot" else "Plot"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%PrevDialogButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Prev"
	# NextDialog text is dynamic in _show_dialog
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "< Scene"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
