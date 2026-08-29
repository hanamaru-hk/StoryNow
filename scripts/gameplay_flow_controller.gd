class_name GameplayFlowController
extends RefCounted

var _host


func _init(host: Control) -> void:
	_host = host


func run_startup() -> void:
	match load_startup_status():
		"new_story":
			await execute_generation("new_story")
		"new_scene":
			await execute_generation("new_scene")
		"generating_image":
			await execute_generating_image()
		"generating_voice":
			execute_generating_voice()
		"generating_both":
			await execute_generating_both()
		"running":
			await _restore_running_scene()


func load_startup_status() -> String:
	var uuid := str(GameProgressManager.settings.get("current_uuid", "")).strip_edges()
	if not uuid.is_empty() and SceneDataManager.load_data(uuid):
		_sync_scene_data()
		var scene_status := str(SceneDataManager.scene_data.get("game_status", "")).strip_edges()
		if not scene_status.is_empty():
			return scene_status
	return str(GameProgressManager.settings.get("game_status", "")).strip_edges()


func set_game_status(status: String, save_now: bool = true) -> void:
	GameProgressManager.settings["game_status"] = status
	SceneDataManager.scene_data["game_status"] = status
	if save_now:
		GameProgressManager.save_settings()
		SceneDataManager.save()
	if _host.is_inside_tree() and _host.has_node("%NextSceneButton"):
		_host.call("_update_button_eligibility")


func current_status() -> String:
	var scene_status := str(SceneDataManager.scene_data.get("game_status", "")).strip_edges()
	return scene_status if not scene_status.is_empty() else str(GameProgressManager.settings.get("game_status", "")).strip_edges()


func begin_voice_generation(scene_data: Dictionary) -> bool:
	if scene_data.is_empty() or not _has_voice_dialogue(scene_data):
		return false
	set_game_status("generating_both" if current_status() == "generating_image" else "generating_voice")
	TTSManager.generate_all_for_scene(scene_data)
	return true


func begin_image_generation() -> void:
	set_game_status("generating_both" if current_status() in ["generating_voice", "generating_both"] else "generating_image")


func finish_image_generation() -> void:
	if current_status() == "generating_both":
		set_game_status("generating_voice")
	elif current_status() == "generating_image":
		set_game_status("running")


func finish_voice_generation() -> void:
	if current_status() == "generating_both":
		set_game_status("generating_image")
	elif current_status() == "generating_voice":
		set_game_status("running")


func handle_generated_scene(flow: String) -> bool:
	var result: Dictionary = await LLMManager.request_new_story() if flow == "new_story" else await LLMManager.request_new_scene()
	if result.get("cancelled", false) or _host_is_leaving():
		return false
	_host.call("_apply_title_from_result", str(result.get("title", "")))
	var parsed := GameplaySceneService.parse_generation_result(result)
	if not parsed.get("success", false):
		_host.set("_pending_retry_action", flow)
		var error_message := str(parsed.get("error", "Generation failed"))
		if error_message == "invalid_json":
			error_message = I18n.translate("error_llm_invalid_json")
		_host.show_error(error_message, true)
		return false
	var generated: Dictionary = parsed["data"]
	var current_round := int(GameProgressManager.settings.get("current_round", SceneDataManager.scene_data.get("current_round", 1)))
	var expected_rounds := int(GameProgressManager.settings.get("expected_rounds", SceneDataManager.scene_data.get("expected_rounds", 0)))
	SceneDataManager.scene_data = GameplaySceneService.merge_generated_scene(
		SceneDataManager.scene_data,
		generated,
		str(GameProgressManager.settings.get("current_uuid", "")),
		current_round,
		expected_rounds,
		flow == "new_scene"
	)
	SceneDataManager.save()
	_sync_scene_data()
	_host.call("_play_scene_bgm")
	_host.call("_apply_title_from_result", str(generated.get("title", parsed.get("title", ""))), generated)
	begin_image_generation()
	begin_voice_generation(SceneDataManager.scene_data)
	return true


func execute_generation(flow: String) -> void:
	var uuid := str(GameProgressManager.settings.get("current_uuid", ""))
	if SceneDataManager.load_data(uuid):
		_sync_scene_data()
	while true:
		_host.set("_pending_retry_action", flow)
		if await handle_generated_scene(flow):
			_host.set("_pending_retry_action", "")
			break
		if _host_is_leaving():
			return
		await _host.retry_requested
		await _host.get_tree().create_timer(0.1).timeout
		if not is_instance_valid(_host) or not _host.is_inside_tree():
			return
	_host.call("_populate_dynamic_choice_buttons")
	_host.call("_update_total_dialogue")
	_host.call("_show_current_dialogue")
	_host.call("_update_button_eligibility")
	if not await _host.call("_generate_comfyui_image"):
		return
	finish_image_generation()
	_host.call("_enable_all_side_buttons_by_eligibility")
	_host.set("_pending_retry_action", "")


func prepare_resume(load_image: bool = false) -> String:
	var uuid := str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()
	if SceneDataManager.scene_data.is_empty() and not uuid.is_empty() and SceneDataManager.load_data(uuid):
		_sync_scene_data()
	if SceneDataManager.scene_data.is_empty():
		_host.show_error(I18n.translate("error_failed_load_scene_data") % uuid)
		return ""
	_host.call("_populate_dynamic_choice_buttons")
	_host.call("_update_total_dialogue")
	_host.call("_show_current_dialogue")
	_host.call("_play_scene_bgm")
	if load_image:
		_host.call("_load_current_scene_image", uuid)
	else:
		_host.call("_update_button_eligibility")
	return uuid


func execute_generating_image() -> void:
	var uuid := prepare_resume()
	if uuid.is_empty():
		return
	_host.call("_load_current_scene_image", uuid)
	begin_image_generation()
	if await _host.call("_generate_comfyui_image"):
		finish_image_generation()
		_host.call("_enable_all_side_buttons_by_eligibility")
		_host.set("_pending_retry_action", "")


func execute_generating_both() -> void:
	if prepare_resume().is_empty():
		return
	begin_image_generation()
	begin_voice_generation(SceneDataManager.scene_data)
	if await _host.call("_generate_comfyui_image"):
		finish_image_generation()
		_host.call("_enable_all_side_buttons_by_eligibility")
		_host.set("_pending_retry_action", "")


func execute_generating_voice() -> void:
	if prepare_resume(true).is_empty():
		return
	set_game_status("generating_voice")
	if not begin_voice_generation(SceneDataManager.scene_data):
		finish_voice_generation()
	_host.call("_enable_all_side_buttons_by_eligibility")


func _restore_running_scene() -> void:
	var uuid := str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
	if SceneDataManager.scene_data.is_empty() and SceneDataManager.load_data(uuid):
		_sync_scene_data()
	if SceneDataManager.scene_data.is_empty():
		_host.show_error(I18n.translate("error_failed_load_scene_data") % uuid)
		return
	if await _host.call("_recover_empty_running_interactions"):
		return
	_host.set("current_dialogue_index", int(GameProgressManager.settings.get("current_dialogue", 0)))
	_host.set("_current_dialog_idx", int(_host.get("current_dialogue_index")))
	_host.call("_populate_dynamic_choice_buttons")
	_host.call("_update_total_dialogue")
	_host.set("_current_dialog_idx", int(_host.get("current_dialogue_index")))
	_host.call("_show_current_dialogue")
	var has_image := bool(_host.call("_load_current_scene_image", uuid))
	_host.call("_enable_all_side_buttons_by_eligibility")
	_host.call("_update_labels")
	var title := str(SceneDataManager.scene_data.get("title", SceneDataManager.scene_data.get("scene_prompt", SceneDataManager.scene_data.get("prompt", ""))))
	if not title.strip_edges().is_empty():
		_host.call("_apply_title_from_result", title, SceneDataManager.scene_data)
	var choice_overlay := _host.get_node_or_null("%ChoiceOverlay") as Control
	if choice_overlay:
		choice_overlay.visible = false
	_host.call("_play_scene_bgm")
	_host.call("_try_autoplay_current")
	await _host.call("_recover_missing_running_assets", has_image)


func _has_voice_dialogue(scene_data: Dictionary) -> bool:
	var interactions: Variant = scene_data.get("interactions", [])
	if not interactions is Array:
		return false
	for entry in interactions:
		if entry is Dictionary and not str(entry.get("dialogue", "")).strip_edges().is_empty():
			return true
	return false


func _sync_scene_data() -> void:
	_host.set("_scene_data", SceneDataManager.scene_data)


func _host_is_leaving() -> bool:
	return not is_instance_valid(_host) or bool(_host.get("_is_leaving_scene"))
