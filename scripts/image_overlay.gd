extends Control

signal closed
signal image_generated(save_path: String, filename: String)

func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Produce.pressed.connect(_on_produce_pressed)
	_update_labels()
	visible = false


func open() -> void:
	visible = true
	var prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	%ImagePromptInput.text = prompt
	%ImagePromptInput.editable = GameSettingsManager.is_free_mode()
	_update_labels()
	# Always allow produce, only editable state changes
	%Produce.disabled = false
	%Back.disabled = false


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_produce_pressed() -> void:
	# If free mode, textarea edit persists back to scene_data["image_prompt"] before generation
	var prompt_text: String = %ImagePromptInput.text.strip_edges() if %ImagePromptInput.text != null else ""
	if prompt_text.is_empty():
		prompt_text = str(SceneDataManager.scene_data.get("image_prompt", "")).strip_edges()
	if prompt_text.is_empty():
		# Keep overlay open; show error via gameplay dialog if available
		var parent_ctrl := get_parent()
		if parent_ctrl and parent_ctrl.has_method("show_error"):
			parent_ctrl.show_error(I18n.translate("image_prompt_empty"))
		return
	# Persist edited prompt when free mode (and also save for consistency)
	SceneDataManager.scene_data["image_prompt"] = prompt_text
	SceneDataManager.save()

	var uuid: String = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", "")))
	%Produce.disabled = true
	%Back.disabled = true
	%ImagePromptInput.editable = false

	var result: Dictionary = {}
	while true:
		result = await ImageServerManager.generate_scene_image(prompt_text, uuid)
		if result.get("success", false):
			break
		# Re-enable inputs so user can see overlay, but keep produce disabled until retry
		%Produce.disabled = false
		%Back.disabled = false
		%ImagePromptInput.editable = GameSettingsManager.is_free_mode()
		var err_msg: String = str(result.get("error", I18n.translate("error_failed_generate_image")))
		var parent_ctrl2 := get_parent()
		if parent_ctrl2 and parent_ctrl2.has_method("show_error"):
			parent_ctrl2.show_error(err_msg, true, "comfyui_image")
			# Wait for retry signal from parent (Gameplay)
			if parent_ctrl2.has_signal("retry_requested"):
				await parent_ctrl2.retry_requested
				await get_tree().create_timer(0.1).timeout
				if not is_instance_valid(self) or not is_inside_tree():
					return
				# Refresh prompt/uuid before retry and disable again
				prompt_text = %ImagePromptInput.text.strip_edges() if %ImagePromptInput.text != null else prompt_text
				if prompt_text.is_empty():
					prompt_text = str(SceneDataManager.scene_data.get("image_prompt", "")).strip_edges()
				SceneDataManager.scene_data["image_prompt"] = prompt_text
				SceneDataManager.save()
				uuid = str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", uuid)))
				%Produce.disabled = true
				%Back.disabled = true
				%ImagePromptInput.editable = false
				continue
		return

	%Produce.disabled = false
	%Back.disabled = false
	%ImagePromptInput.editable = GameSettingsManager.is_free_mode()
	# Clear pending retry on success (parent Gameplay tracks it)
	var parent_clear := get_parent()
	if parent_clear and parent_clear.get("_pending_retry_action") != null:
		parent_clear.set("_pending_retry_action", "")

	var save_path: String = str(result.get("save_path", ""))
	var filename: String = str(result.get("filename", ""))

	# Append the new image to the end of image_filenames[] and persist
	if not SceneDataManager.scene_data.has("image_filenames") or not SceneDataManager.scene_data["image_filenames"] is Array:
		SceneDataManager.scene_data["image_filenames"] = []
	var arr: Array = SceneDataManager.scene_data["image_filenames"]
	arr.append(filename)
	SceneDataManager.scene_data["image_filenames"] = arr
	SceneDataManager.scene_data["current_image_index"] = arr.size() - 1
	SceneDataManager.save()

	# Refresh background image via parent gameplay if it exposes _set_background_from_file
	var parent_ctrl3 := get_parent()
	if parent_ctrl3 and parent_ctrl3.has_method("_set_background_from_file"):
		parent_ctrl3._set_background_from_file(save_path)
	elif parent_ctrl3 and parent_ctrl3.has_node("%BackgroundImage"):
		# Fallback: try direct texture load
		var global_path := ProjectSettings.globalize_path(save_path)
		var img := Image.new()
		var err: Error = img.load(global_path)
		if err != OK:
			err = img.load(save_path)
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			parent_ctrl3.get_node("%BackgroundImage").texture = tex
			parent_ctrl3.get_node("%BackgroundImage").modulate = Color(1, 1, 1, 1)

	image_generated.emit(save_path, filename)

	# Close overlay on success
	visible = false
	closed.emit()


func _update_labels() -> void:
	if has_node("%Title"):
		%Title.text = I18n.translate("image_overlay_title") if I18n.translate("image_overlay_title") != "image_overlay_title" else "Image Prompt"
	if has_node("%Back"):
		%Back.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%Produce"):
		%Produce.text = I18n.translate("btn_produce") if I18n.translate("btn_produce") != "btn_produce" else "Produce"
	if has_node("%ImagePromptInput"):
		%ImagePromptInput.placeholder_text = I18n.translate("image_prompt_placeholder") if I18n.translate("image_prompt_placeholder") != "image_prompt_placeholder" else "Image prompt (Danbooru tags)..."
