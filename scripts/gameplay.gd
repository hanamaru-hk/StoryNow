extends Control

var _choice_controller: GameplayChoiceController
var _dialogue_controller: GameplayDialogueController
var _image_controller: GameplayImageController
var _flow_controller: GameplayFlowController
var _chrome_controller: GameplayChromeController

var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0

# Requested public dialogue tracking vars
var current_dialogue_index: int = 0
var total_dialogue: int = 1

# Error dialog retry handling
signal retry_requested
var _pending_retry_action: String = ""  # "new_story" or "new_scene"
var _retry_in_progress: bool = false
var _chrome_visible: bool = true
var _is_leaving_scene: bool = false

func _ready() -> void:
	_choice_controller = GameplayChoiceController.new(self)
	_dialogue_controller = GameplayDialogueController.new(self)
	_image_controller = GameplayImageController.new(self)
	_flow_controller = GameplayFlowController.new(self)
	_chrome_controller = GameplayChromeController.new(self)
	_set_chrome_visible(true)
	# --- Dialogue panel grid buttons ---
	%PlayAudioButton.pressed.connect(_on_play_audio_pressed)
	%PlotButton.pressed.connect(_on_plot_btn_pressed)
	%ImageButton.pressed.connect(_on_image_btn_pressed)
	%HelpButton.pressed.connect(_on_help_pressed)
	%PrevLineButton.pressed.connect(_on_prev_dialog_pressed)
	%NextLineButton.pressed.connect(_on_next_dialog_pressed)
	%PrevSceneButton.pressed.connect(_on_prev_scene_pressed)
	%NextSceneButton.pressed.connect(_on_next_scene_pressed)
	%SettingButton.pressed.connect(_on_setting_pressed)
	%GameplayMenuButton.pressed.connect(_on_gameplay_menu_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false
	%ImageActionNew.pressed.connect(_on_image_action_new_pressed)
	%ImageActionChange.pressed.connect(_on_image_action_change_pressed)
	%ImageActionBack.pressed.connect(_hide_image_action_overlay)
	%ImageChangePrev.pressed.connect(_on_image_change_prev_pressed)
	%ImageChangeNext.pressed.connect(_on_image_change_next_pressed)
	%ImageChangeSave.pressed.connect(_on_image_change_save_pressed)
	%ImageChangeBack.pressed.connect(_on_image_change_back_pressed)
	%ImageActionOverlay.visible = false
	%ImageChangeOverlay.visible = false

	# --- GameProgressOverlay (in-game advanced settings) ---
	if has_node("%GameProgressOverlay"):
		%GameProgressOverlay.closed.connect(_on_settings_closed)

	# --- Gameplay menu and settings overlays ---
	if has_node("%GameplayMenuOverlay"):
		%GameplayMenuOverlay.closed.connect(_on_settings_closed)
		%GameplayMenuOverlay.load_requested.connect(_on_gameplay_menu_load_requested)
		%GameplayMenuOverlay.gallery_requested.connect(_on_gameplay_menu_gallery_requested)
		%GameplayMenuOverlay.game_settings_requested.connect(_on_gameplay_menu_game_settings_requested)
		%GameplayMenuOverlay.advanced_settings_requested.connect(_on_gameplay_menu_advanced_settings_requested)
		%GameplayMenuOverlay.main_menu_requested.connect(_on_back_to_main_menu_requested)
		%GameplayMenuOverlay.quit_game_requested.connect(_on_quit_game_requested)
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.closed.connect(_on_settings_closed)
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.closed.connect(_on_settings_closed)
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.closed.connect(_on_settings_closed)
	if has_node("%AdvancedSettingsOverlay"):
		%AdvancedSettingsOverlay.closed.connect(_on_settings_closed)
		%AdvancedSettingsOverlay.image_settings_requested.connect(_on_image_server_setting_requested)
		%AdvancedSettingsOverlay.llm_settings_requested.connect(_on_llm_setting_requested)
	if has_node("%ImageServerSettingsOverlay"):
		%ImageServerSettingsOverlay.closed.connect(_on_settings_closed)
	if has_node("%LLMSettingsOverlay"):
		%LLMSettingsOverlay.closed.connect(_on_settings_closed)
	if has_node("%HelpOverlay"):
		%HelpOverlay.closed.connect(_on_settings_closed)

	# --- ImageOverlay (extracted) ---
	if has_node("%ImageOverlay"):
		%ImageOverlay.closed.connect(_on_image_overlay_closed)
		%ImageOverlay.generation_requested.connect(_on_image_generation_requested)
	if has_node("%BackgroundVideo") and %BackgroundVideo.has_signal("finished") and not %BackgroundVideo.finished.is_connected(_on_background_video_finished):
		%BackgroundVideo.finished.connect(_on_background_video_finished)
	if has_node("%GeneratingDotsTimer") and not %GeneratingDotsTimer.timeout.is_connected(_on_generating_dots_timeout):
		%GeneratingDotsTimer.timeout.connect(_on_generating_dots_timeout)

	# --- SummaryOverlay ---
	if has_node("%SummaryOverlay"):
		%SummaryOverlay.closed.connect(_on_summary_overlay_closed)

	# --- PlotOverlay ---
	if has_node("%PlotOverlay"):
		%PlotOverlay.closed.connect(_on_plot_overlay_closed)
		%PlotOverlay.dialogue_updated.connect(_on_dialogue_updated)
		%PlotOverlay.summary_requested.connect(_on_summary_pressed)

	# --- ErrorReturnPopup ---
	%ErrorReturnBack.pressed.connect(_on_error_return)
	%ErrorReturnRetry.pressed.connect(_on_error_retry_pressed)

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)
	_start_continue_indicator_flash()

	_resize_choice_overlay_panel()

	# --- TTS auto-play ---
	if is_instance_valid(TTSManager) and TTSManager.has_signal("tts_generated") and not TTSManager.tts_generated.is_connected(_on_tts_generated):
		TTSManager.tts_generated.connect(_on_tts_generated)
	if is_instance_valid(TTSManager) and TTSManager.has_signal("batch_completed") and not TTSManager.batch_completed.is_connected(_on_tts_batch_completed):
		TTSManager.batch_completed.connect(_on_tts_batch_completed)
	_update_labels()
	_load_default_background()
	# Disable all SidePanel buttons except Setting and gameplay menu at start
	_set_all_side_buttons_disabled_except_settings_back()

	await _flow_controller.run_startup()

func _load_startup_scene_status() -> String:
	return _flow_controller.load_startup_status()


func _set_scene_game_status(status: String, save_now: bool = true) -> void:
	SceneDataManager.scene_data["game_status"] = status
	if save_now:
		SceneDataManager.save()


func _set_game_status(status: String, save_now: bool = true) -> void:
	_flow_controller.set_game_status(status, save_now)


func _current_game_status() -> String:
	return _flow_controller.current_status()


func _begin_voice_generation(scene_data: Dictionary) -> bool:
	return _flow_controller.begin_voice_generation(scene_data)


func _begin_image_generation() -> void:
	_flow_controller.begin_image_generation()


func _finish_image_generation() -> void:
	_flow_controller.finish_image_generation()


func _finish_voice_generation() -> void:
	_flow_controller.finish_voice_generation()


func _load_default_background() -> void:
	_image_controller.load_default_background()


func _load_missing_save_background() -> void:
	_image_controller.load_missing_background()


func _set_no_image_label_visible(is_visible: bool) -> void:
	_image_controller.set_no_image_visible(is_visible)


func _show_generating_background() -> void:
	_image_controller.show_generating_background()


func _hide_generating_background() -> void:
	_image_controller.hide_generating_background()


func _on_background_video_finished() -> void:
	_image_controller.on_background_video_finished()


func _on_generating_dots_timeout() -> void:
	_image_controller.on_generating_dots_timeout()


func _play_scene_bgm() -> void:
	MusicManager.play_for_scene(SceneDataManager.scene_data)

# ------------------------------------------------------------------
# Dialogue helpers — current/total tracking and UI update
# ------------------------------------------------------------------
func _update_total_dialogue() -> void:
	_dialogue_controller.update_total()


func _show_current_dialogue() -> void:
	_dialogue_controller.show_current()


func _is_prev_scene_exist() -> bool:
	return _dialogue_controller.has_previous_scene()


func _is_prev_dialogue_exist() -> bool:
	return _dialogue_controller.has_previous_dialogue()


func _is_at_choice_dialogue() -> bool:
	return _dialogue_controller.is_at_choice()


func _can_open_choice_overlay() -> bool:
	return _dialogue_controller.can_open_choice()


func _can_use_scene_navigation() -> bool:
	return _dialogue_controller.can_navigate_scene()


func _current_dialogue_wav_exists() -> bool:
	return _dialogue_controller.current_wav_exists()


func _all_voice_dialogues_have_sound_file() -> bool:
	return _dialogue_controller.all_voice_files_exist()


func _running_interactions_are_empty() -> bool:
	return _dialogue_controller.interactions_are_empty()


func _recover_empty_running_interactions() -> bool:
	return await _dialogue_controller.recover_empty_interactions()


func _recover_missing_running_assets(has_image: bool) -> void:
	await _dialogue_controller.recover_missing_assets(has_image)


func is_prev_scene_exist() -> bool:
	return _dialogue_controller.has_previous_scene()


func is_prev_dialogue_exist() -> bool:
	return _dialogue_controller.has_previous_dialogue()


func _set_all_side_buttons_disabled_except_settings_back() -> void:
	_dialogue_controller.disable_buttons_for_loading()


func _update_button_eligibility() -> void:
	_dialogue_controller.update_button_eligibility()


func _start_continue_indicator_flash() -> void:
	_dialogue_controller.start_continue_indicator()


func _update_continue_indicator() -> void:
	_dialogue_controller.update_continue_indicator()


func _enable_all_side_buttons_by_eligibility() -> void:
	_dialogue_controller.enable_buttons()


func _populate_dynamic_choice_buttons() -> void:
	_choice_controller.populate_buttons()


func _on_dynamic_choice_pressed(choice_text: String) -> void:
	_choice_controller.select_choice(choice_text)


func _on_dynamic_choice_delete_pressed(choice_index: int) -> void:
	_choice_controller.delete_choice(choice_index)


func _generate_comfyui_image() -> bool:
	return await _image_controller.generate_scene_image()


func _set_background_from_file(user_path: String) -> bool:
	return _image_controller.set_background_from_file(user_path)


func _get_scene_image_filenames(uuid: String = "") -> Array:
	return _image_controller.image_filenames(uuid)


func _load_current_scene_image(uuid: String = "") -> bool:
	return _image_controller.load_current_image(uuid)


func _input(event: InputEvent) -> void:
	_chrome_controller.handle_input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _choice_controller:
		_choice_controller.resize_overlay_panel()


func _toggle_chrome() -> void:
	_chrome_controller.toggle()


func _set_chrome_visible(is_visible: bool) -> void:
	_chrome_controller.set_visible(is_visible)


func _resize_choice_overlay_panel() -> void:
	_choice_controller.resize_overlay_panel()


func _on_dialog_area_input(event: InputEvent) -> void:
	_dialogue_controller.on_dialog_area_input(event)


func _on_prev_dialog_pressed() -> void:
	_dialogue_controller.previous_dialogue()


func _on_next_dialog_pressed() -> void:
	_dialogue_controller.next_dialogue()


func _on_prev_scene_pressed() -> void:
	_dialogue_controller.previous_scene()


func _on_next_scene_pressed() -> void:
	if _dialogue_controller.can_navigate_scene():
		_choice_controller.show_overlay()


func _on_plot_btn_pressed() -> void:
	if has_node("%PlotOverlay"):
		%PlotOverlay.open()


func _on_plot_overlay_closed() -> void:
	_update_labels()


func _on_dialogue_updated() -> void:
	_update_total_dialogue()
	_show_current_dialogue()
	_update_button_eligibility()
	_update_labels()
	_try_autoplay_current()


func _on_image_btn_pressed() -> void:
	_image_controller.show_action_overlay()


func _on_help_pressed() -> void:
	if has_node("%HelpOverlay"):
		%HelpOverlay.open()


func _show_image_action_overlay() -> void:
	_image_controller.show_action_overlay()


func _hide_image_action_overlay() -> void:
	_image_controller.hide_action_overlay()


func _on_image_action_new_pressed() -> void:
	await _image_controller.create_new_image()


func _on_image_action_change_pressed() -> void:
	_image_controller.hide_action_overlay()
	_image_controller.open_change_overlay()


func _open_image_change_overlay() -> void:
	_image_controller.open_change_overlay()


func _refresh_image_change_overlay() -> void:
	_image_controller.refresh_change_overlay()


func _on_image_change_prev_pressed() -> void:
	_image_controller.previous_image()


func _on_image_change_next_pressed() -> void:
	_image_controller.next_image()


func _on_image_change_save_pressed() -> void:
	_image_controller.save_selected_image()


func _on_image_change_back_pressed() -> void:
	_image_controller.back_from_change()


func _on_image_overlay_closed() -> void:
	_update_labels()


func _on_image_generation_requested() -> void:
	_begin_image_generation()
	_update_button_eligibility()
	if await _image_controller.generate_scene_image():
		_finish_image_generation()
		_enable_all_side_buttons_by_eligibility()
		_pending_retry_action = ""


func _on_summary_pressed() -> void:
	if has_node("%SummaryOverlay"):
		%SummaryOverlay.open()


func _on_summary_overlay_closed() -> void:
	_update_labels()


func _on_setting_pressed() -> void:
	if has_node("%GameProgressOverlay"):
		%GameProgressOverlay.open()


func _on_gameplay_menu_pressed() -> void:
	if has_node("%GameplayMenuOverlay"):
		%GameplayMenuOverlay.open()


func _on_gameplay_menu_load_requested() -> void:
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.open()


func _on_gameplay_menu_gallery_requested() -> void:
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.open()


func _on_gameplay_menu_game_settings_requested() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_gameplay_menu_advanced_settings_requested() -> void:
	if has_node("%AdvancedSettingsOverlay"):
		%AdvancedSettingsOverlay.open()


func _on_image_server_setting_requested() -> void:
	if has_node("%ImageServerSettingsOverlay"):
		%ImageServerSettingsOverlay.open()


func _on_llm_setting_requested() -> void:
	if has_node("%LLMSettingsOverlay"):
		%LLMSettingsOverlay.open()


func _on_back_to_main_menu_requested() -> void:
	if _is_leaving_scene:
		return
	_is_leaving_scene = true
	%ErrorReturnPopup.visible = false
	if ServerRuntimeManager.has_generation_requests():
		await ServerRuntimeManager.cancel_active_generation_tasks()
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_quit_game_requested() -> void:
	get_tree().quit()


func _on_play_audio_pressed() -> void:
	_dialogue_controller.play_current_audio()


func _stop_tts_if_playing() -> void:
	_dialogue_controller.stop_tts()


func _try_autoplay_current() -> void:
	_dialogue_controller.try_autoplay()


func _on_tts_generated(uuid: String, idx: int, sound_filename: String, save_path: String) -> void:
	_dialogue_controller.on_tts_generated(uuid, idx, sound_filename, save_path)


func _on_tts_batch_completed(uuid: String) -> void:
	_dialogue_controller.on_tts_batch_completed(uuid)


func _on_settings_closed() -> void:
	_update_labels()


func _format_title_with_round(title: String) -> String:
	var t := title.strip_edges()
	if t.is_empty():
		return ""
	var cur_round: int = int(GameProgressManager.settings.get("current_round", 1))
	return "%d. %s" % [cur_round, t]


func _apply_title_from_result(result_title: String, fallback_data: Dictionary = {}) -> void:
	if not has_node("%TitleLabel"):
		return
	var t: String = result_title.strip_edges()
	if t.is_empty() and not fallback_data.is_empty():
		t = str(fallback_data.get("title", "")).strip_edges()
	if t.is_empty():
		return
	%TitleLabel.text = _format_title_with_round(t)


func _handle_new_story() -> bool:
	return await _flow_controller.handle_generated_scene("new_story")


func _handle_new_scene() -> bool:
	return await _flow_controller.handle_generated_scene("new_scene")


func _handle_generated_scene(flow: String) -> bool:
	return await _flow_controller.handle_generated_scene(flow)


func _execute_new_story_flow() -> void:
	await _flow_controller.execute_generation("new_story")


func _execute_new_scene_flow() -> void:
	await _flow_controller.execute_generation("new_scene")


func regenerate_current_scene(current_round: int) -> void:
	var flow := GameplaySceneService.generation_flow_for_round(current_round)
	current_dialogue_index = 0
	_current_dialog_idx = 0
	GameProgressManager.settings["current_dialogue"] = 0
	_set_game_status(flow)
	await _flow_controller.execute_generation(flow)


func _prepare_generating_resume_flow(load_image: bool = false) -> String:
	return _flow_controller.prepare_resume(load_image)


func _execute_generating_image_flow() -> void:
	await _flow_controller.execute_generating_image()


func _execute_generating_both_flow() -> void:
	await _flow_controller.execute_generating_both()


func _execute_generating_voice_flow() -> void:
	_flow_controller.execute_generating_voice()


func _show_choice_overlay() -> void:
	_choice_controller.show_overlay()


func _hide_choice_overlay() -> void:
	_choice_controller.hide_overlay()


func _on_choice_confirm() -> void:
	_choice_controller.confirm()


func _on_choice_cancel() -> void:
	_choice_controller.hide_overlay()


# ------------------------------------------------------------------
# Error handling — common error return popup for returning to main menu
# ------------------------------------------------------------------
func _update_error_popup_retry_visibility(allow_retry: bool) -> void:
	%ErrorReturnRetry.visible = allow_retry
	%ErrorReturnRetry.disabled = not allow_retry or _retry_in_progress
	var retry_text: String = I18n.translate("btn_retry")
	if retry_text == "btn_retry":
		retry_text = "Retry"
	%ErrorReturnRetry.text = retry_text


func show_error(message: String, allow_retry: bool = false, retry_action: String = "") -> void:
	if _is_leaving_scene:
		return
	if not retry_action.is_empty():
		_pending_retry_action = retry_action
	# If retry is allowed but no pending action has been set, do not show retry
	if allow_retry and _pending_retry_action.is_empty():
		allow_retry = false
	_update_error_popup_retry_visibility(allow_retry and not _pending_retry_action.is_empty())
	%ErrorReturnMessage.text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnTitle.text = I18n.translate("error_dialog_title")
	%ErrorReturnPopup.visible = true


func _on_error_retry_pressed() -> void:
	if _pending_retry_action.is_empty() or _retry_in_progress:
		return
	_retry_in_progress = true
	_update_error_popup_retry_visibility(false)
	%ErrorReturnPopup.visible = false
	# Emit signal for the retry loop in _execute_*_flow; loop will clear pending on next iteration
	await get_tree().create_timer(0.05).timeout
	_retry_in_progress = false
	retry_requested.emit()


func _on_error_return() -> void:
	_is_leaving_scene = true
	_pending_retry_action = ""
	_retry_in_progress = false
	_update_error_popup_retry_visibility(false)
	%ErrorReturnPopup.visible = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	# Title / Dialog generating placeholders
	if has_node("%TitleLabel"):
		var cur_title: String = %TitleLabel.text.strip_edges()
		if cur_title == "Generating Title..." or cur_title == I18n.translate("generating_title") or cur_title.is_empty():
			var t_title: String = I18n.translate("generating_title")
			%TitleLabel.text = t_title if t_title != "generating_title" else "Generating Title..."
	if has_node("%DialogLabel"):
		var cur_dialog: String = %DialogLabel.text.strip_edges()
		if cur_dialog == "Generating the gameplay..." or cur_dialog == I18n.translate("generating_gameplay") or cur_dialog.is_empty():
			var t_gen: String = I18n.translate("generating_gameplay")
			%DialogLabel.text = t_gen if t_gen != "generating_gameplay" else "Generating the gameplay..."
	%PlotButton.text = I18n.translate("btn_plot") if I18n.translate("btn_plot") != "btn_plot" else "Plot"
	%ImageButton.text = I18n.translate("btn_image") if I18n.translate("btn_image") != "btn_image" else "Image"
	%PlayAudioButton.text = I18n.translate("btn_play_audio") if I18n.translate("btn_play_audio") != "btn_play_audio" else "Play"
	%HelpButton.text = I18n.translate("btn_help") if I18n.translate("btn_help") != "btn_help" else "Help"
	%PrevLineButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Dialogue"
	%NextLineButton.text = I18n.translate("btn_next_dialog") if I18n.translate("btn_next_dialog") != "btn_next_dialog" else "Dialogue >"
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "<< Scene"
	%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Scene >>"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%GameplayMenuButton.text = I18n.translate("btn_gameplay_menu") if I18n.translate("btn_gameplay_menu") != "btn_gameplay_menu" else "Menu"
	# Choice overlay
	var choice_title: String = I18n.translate("choice_title")
	if has_node("%ChoiceTitle"):
		%ChoiceTitle.text = choice_title if choice_title != "choice_title" else "Choose Next Step"
	else:
		var ct_node := get_node_or_null("ChoiceOverlay/CenterContainer/Panel/Margin/VBox/Title")
		if ct_node is Label:
			(ct_node as Label).text = choice_title if choice_title != "choice_title" else "Choose Next Step"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	# Image action overlay
	if has_node("%ImageActionNew"):
		var t_new: String = I18n.translate("image_action_new")
		%ImageActionNew.text = t_new if t_new != "image_action_new" else "New"
	if has_node("%ImageActionChange"):
		var t_change: String = I18n.translate("image_action_change")
		%ImageActionChange.text = t_change if t_change != "image_action_change" else "Change"
	if has_node("%ImageActionBack"):
		var t_back: String = I18n.translate("btn_back")
		%ImageActionBack.text = t_back if t_back != "btn_back" else "Back"
	# Image change overlay
	if has_node("%ImageChangeBack"):
		var t_ic_back: String = I18n.translate("btn_back")
		%ImageChangeBack.text = t_ic_back if t_ic_back != "btn_back" else "Back"
	if has_node("%ImageChangeSave"):
		var t_ic_save: String = I18n.translate("btn_save")
		%ImageChangeSave.text = t_ic_save if t_ic_save != "btn_save" else "Save"
	if has_node("%ImageOverlay") and %ImageOverlay.has_method("_update_labels"):
		%ImageOverlay._update_labels()
	if has_node("%SummaryOverlay") and %SummaryOverlay.has_method("_update_labels"):
		%SummaryOverlay._update_labels()
	if has_node("%PlotOverlay") and %PlotOverlay.has_method("_update_labels"):
		%PlotOverlay._update_labels()
	if has_node("%GameplayMenuOverlay") and %GameplayMenuOverlay.has_method("_update_labels"):
		%GameplayMenuOverlay._update_labels()
	if has_node("%HelpOverlay") and %HelpOverlay.has_method("_update_labels"):
		%HelpOverlay._update_labels()
	# Error popup buttons
	if has_node("%ErrorReturnPopup"):
		%ErrorReturnTitle.text = I18n.translate("error_dialog_title")
		var t_ok: String = I18n.translate("btn_back_to_main_menu")
		%ErrorReturnBack.text = t_ok if t_ok != "btn_back_to_main_menu" else "Return to Menu"
		var t_dlg: String = I18n.translate("error_dialog_text")
		# Only override fallback text if it matches the old hard-coded fallback
		if %ErrorReturnMessage.text == "Something went wrong. Returning to main menu." or %ErrorReturnMessage.text == t_dlg:
			%ErrorReturnMessage.text = t_dlg if t_dlg != "error_dialog_text" else "Something went wrong. Returning to main menu."
		var retry_text: String = I18n.translate("btn_retry")
		%ErrorReturnRetry.text = retry_text if retry_text != "btn_retry" else "Retry"
