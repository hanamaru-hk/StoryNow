extends Control

signal closed
signal generation_requested

func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Produce.pressed.connect(_on_produce_pressed)
	_update_labels()
	visible = false


func open() -> void:
	visible = true
	var prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	%ImagePromptInput.text = prompt
	%ImagePromptInput.editable = GameSettingsManager.is_builder_mode()
	_update_labels()
	# Always allow produce, only editable state changes
	%Produce.disabled = false
	%Back.disabled = false


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_produce_pressed() -> void:
	# In builder mode, textarea edits persist back to scene_data["image_prompt"] before generation.
	var prompt_text: String = %ImagePromptInput.text.strip_edges() if %ImagePromptInput.text != null else ""
	if prompt_text.is_empty():
		prompt_text = str(SceneDataManager.scene_data.get("image_prompt", "")).strip_edges()
	if prompt_text.is_empty():
		# Keep overlay open so the prompt can be corrected.
		var parent_ctrl := get_parent()
		if parent_ctrl and parent_ctrl.has_method("show_error"):
			parent_ctrl.show_error(I18n.translate("image_prompt_empty"))
		return
	# Persist the prompt before handing generation back to Gameplay's normal image flow.
	SceneDataManager.scene_data["image_prompt"] = prompt_text
	SceneDataManager.save()
	visible = false
	closed.emit()
	generation_requested.emit()


func _update_labels() -> void:
	if has_node("%Title"):
		%Title.text = I18n.translate("image_overlay_title") if I18n.translate("image_overlay_title") != "image_overlay_title" else "Image Prompt"
	if has_node("%Back"):
		%Back.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%Produce"):
		%Produce.text = I18n.translate("btn_produce") if I18n.translate("btn_produce") != "btn_produce" else "Produce"
	if has_node("%ImagePromptInput"):
		%ImagePromptInput.placeholder_text = I18n.translate("image_prompt_placeholder") if I18n.translate("image_prompt_placeholder") != "image_prompt_placeholder" else "Image prompt (Danbooru tags)..."
