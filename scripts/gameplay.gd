extends Control


var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0

func _ready() -> void:
	# --- Dialogue panel grid buttons ---
	%PlotButton.pressed.connect(_on_plot_pressed)
	%PlayAudioButton.pressed.connect(_on_play_audio_pressed)
	%DialogButton.pressed.connect(_on_dialog_btn_pressed)
	%ImageButton.pressed.connect(_on_image_btn_pressed)
	%PrevDialogButton.pressed.connect(_on_prev_dialog_pressed)
	%NextDialogButton.pressed.connect(_on_next_dialog_pressed)
	%PrevSceneButton.pressed.connect(_on_prev_scene_pressed)
	%NextSceneButton.pressed.connect(_on_next_scene_pressed)
	%SettingButton.pressed.connect(_on_setting_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false

	# --- GameSettingsOverlay (in-game settings) ---
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.closed.connect(_on_settings_closed)

	# --- ErrorReturnDialog ---
	%ErrorReturnDialog.confirmed.connect(_on_error_return)
	%ErrorReturnDialog.canceled.connect(_on_error_return)
	# AcceptDialog close via X also triggers canceled

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	_update_labels()
	_load_default_background()

	match GameProgressManager.settings.get("game_status", ""):
		"new_story":
			var uuid: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok: bool = SceneDataManager.load_data(uuid)
			if ok:
				_scene_data = SceneDataManager.scene_data
		"new_scene":
			pass
		"running":
			pass
		_:
			pass


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

# ------------------------------------------------------------------
# Input handlers
# ------------------------------------------------------------------
# Trigger: virtual Node._input / _unhandled_input — called automatically by Godot's
# input dispatch (no signal connection needed). _input is used so right-click
# works even when GUI Controls (Dialogue/TopBar) would otherwise mark the event
# as handled and prevent _unhandled_input from firing.
func _input(event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	pass


func _toggle_chrome() -> void:
	pass


func _on_dialog_area_input(event: InputEvent) -> void:
	pass


func _on_prev_dialog_pressed() -> void:
	pass


func _on_next_dialog_pressed() -> void:
	pass


func _on_prev_scene_pressed() -> void:
	pass

func _on_next_scene_pressed() -> void:
	pass


func _on_dialog_btn_pressed() -> void:
	pass


func _on_image_btn_pressed() -> void:
	pass


func _on_plot_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_play_audio_pressed() -> void:
	pass


func _on_settings_closed() -> void:
	_update_labels()


# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false


func _on_choice_button_pressed(choice_text: String) -> void:
	_hide_choice_overlay()
	pass


func _on_choice_confirm() -> void:
	pass
	# _hide_choice_overlay()
	# await _advance_with_choice(chosen)


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


func _advance_with_choice(choice_text: String) -> void:
	pass


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
	%PlayAudioButton.text = I18n.translate("btn_play_audio") if I18n.translate("btn_play_audio") != "btn_play_audio" else "Play"
	%PrevDialogButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Prev"
	# NextDialog text is dynamic in _show_dialog
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "< Scene"
	%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Next Scene >"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%BackButton.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
