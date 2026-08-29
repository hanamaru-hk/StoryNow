class_name GameplayImageController
extends RefCounted

const GENERATING_VIDEO_PATH := "res://assets/videos/3.ogv"

var _host


func _init(host: Control) -> void:
	_host = host


func load_default_background() -> void:
	set_no_image_visible(false)
	show_generating_background()


func load_missing_background() -> void:
	var background := _node("BackgroundImage") as TextureRect
	background.texture = null
	background.modulate = Color.WHITE
	show_generating_background()


func set_no_image_visible(is_visible: bool) -> void:
	_get_no_image_placeholder().visible = is_visible


func show_generating_background() -> void:
	var video := _node("BackgroundVideo") as VideoStreamPlayer
	if video == null:
		_load_placeholder_background("res://assets/images/generating.jpg", 0.5)
		return
	set_no_image_visible(false)
	var background := _node("BackgroundImage") as TextureRect
	background.texture = null
	background.modulate = Color.WHITE
	video.visible = true
	video.stream = load(GENERATING_VIDEO_PATH)
	if not video.is_playing():
		video.play()


func hide_generating_background() -> void:
	var video := _node("BackgroundVideo") as VideoStreamPlayer
	if video:
		video.stop()
		video.visible = false


func on_background_video_finished() -> void:
	var video := _node("BackgroundVideo") as VideoStreamPlayer
	if video and video.visible:
		video.play()


func generate_scene_image() -> bool:
	var image_prompt := str(SceneDataManager.scene_data.get("image_prompt", ""))
	var uuid := _current_uuid()
	while true:
		var result: Dictionary = await ImageServerManager.generate_scene_image(image_prompt, uuid)
		if result.get("success", false):
			var save_path := str(result.get("save_path", ""))
			var filename := str(result.get("filename", ""))
			set_background_from_file(save_path)
			_append_image(filename)
			_host.set("_scene_data", SceneDataManager.scene_data)
			_host.set("_pending_retry_action", "")
			return true
		_host.set("_pending_retry_action", "comfyui_image")
		_host.show_error(str(result.get("error", I18n.translate("error_failed_generate_image"))), true, "comfyui_image")
		await _host.retry_requested
		await _host.get_tree().create_timer(0.1).timeout
		if not is_instance_valid(_host) or not _host.is_inside_tree():
			return false
		image_prompt = str(SceneDataManager.scene_data.get("image_prompt", image_prompt))
		uuid = _current_uuid()
	return false


func set_background_from_file(user_path: String) -> bool:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(user_path))
	if error != OK:
		error = image.load(user_path)
	if error != OK:
		error = _load_image_buffer(image, user_path)
	if error != OK:
		push_warning("Failed to load generated image %s: %s" % [user_path, error_string(error)])
		load_missing_background()
		return false
	hide_generating_background()
	var background := _node("BackgroundImage") as TextureRect
	background.texture = ImageTexture.create_from_image(image)
	background.modulate = Color.WHITE
	set_no_image_visible(false)
	return true


func image_filenames(uuid: String = "") -> Array:
	var resolved_uuid := uuid.strip_edges() if not uuid.strip_edges().is_empty() else _current_uuid()
	var images_dir := "user://saves/%s/images" % resolved_uuid
	var files: Array = []
	var saved: Variant = SceneDataManager.scene_data.get("image_filenames", [])
	if saved is Array:
		for value in saved:
			var filename := str(value).strip_edges()
			if _is_image_filename(filename) and FileAccess.file_exists("%s/%s" % [images_dir, filename]):
				files.append(filename)
	return files


func load_current_image(uuid: String = "") -> bool:
	var resolved_uuid := uuid.strip_edges() if not uuid.strip_edges().is_empty() else _current_uuid()
	var files := image_filenames(resolved_uuid)
	if files.is_empty():
		load_missing_background()
		return false
	var index := clampi(int(SceneDataManager.scene_data.get("current_image_index", 0)), 0, files.size() - 1)
	SceneDataManager.scene_data["current_image_index"] = index
	return set_background_from_file("user://saves/%s/images/%s" % [resolved_uuid, files[index]])


func show_action_overlay() -> void:
	_set_visible("ImageActionOverlay", true)


func hide_action_overlay() -> void:
	_set_visible("ImageActionOverlay", false)


func create_new_image() -> void:
	hide_action_overlay()
	var overlay := _node("ImageOverlay")
	if overlay and overlay.has_method("open"):
		overlay.open()
		return
	if str(SceneDataManager.scene_data.get("image_prompt", "")).strip_edges().is_empty():
		_host.show_error(I18n.translate("image_prompt_empty"))
		return
	await generate_scene_image()


func open_change_overlay() -> void:
	var files := image_filenames()
	if files.is_empty():
		_host.show_error(I18n.translate("image_no_saved_for_scene"))
		return
	SceneDataManager.scene_data["current_image_index"] = clampi(int(SceneDataManager.scene_data.get("current_image_index", 0)), 0, files.size() - 1)
	_set_visible("ImageChangeOverlay", true)
	refresh_change_overlay()


func refresh_change_overlay() -> void:
	var files := image_filenames()
	var preview := _node("ImagePreview") as TextureRect
	if files.is_empty():
		preview.texture = null
		_set_text("ImageChangeLabel", I18n.translate("image_change_title"))
		_set_disabled("ImageChangePrev", true)
		_set_disabled("ImageChangeNext", true)
		_set_disabled("ImageChangeSave", true)
		return
	var index := clampi(int(SceneDataManager.scene_data.get("current_image_index", 0)), 0, files.size() - 1)
	SceneDataManager.scene_data["current_image_index"] = index
	var path := "user://saves/%s/images/%s" % [_current_uuid(), files[index]]
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		error = image.load(path)
	preview.texture = ImageTexture.create_from_image(image) if error == OK else null
	_set_text("ImageChangeLabel", I18n.translate("image_change_counter") % [index + 1, files.size()])
	_set_disabled("ImageChangePrev", files.size() <= 1)
	_set_disabled("ImageChangeNext", files.size() <= 1)
	_set_disabled("ImageChangeSave", false)


func previous_image() -> void:
	var files := image_filenames()
	if files.is_empty():
		return
	var index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	SceneDataManager.scene_data["current_image_index"] = (index - 1 + files.size()) % files.size()
	refresh_change_overlay()


func next_image() -> void:
	var files := image_filenames()
	if files.is_empty():
		return
	var index := int(SceneDataManager.scene_data.get("current_image_index", 0))
	SceneDataManager.scene_data["current_image_index"] = (index + 1) % files.size()
	refresh_change_overlay()


func save_selected_image() -> void:
	if load_current_image():
		SceneDataManager.save()
	_set_visible("ImageChangeOverlay", false)
	_host.call("_update_labels")


func back_from_change() -> void:
	_set_visible("ImageChangeOverlay", false)
	show_action_overlay()


func on_image_generated() -> void:
	load_current_image()
	_host.call("_update_labels")


func _append_image(filename: String) -> void:
	var raw_files: Variant = SceneDataManager.scene_data.get("image_filenames", [])
	var files: Array = raw_files if raw_files is Array else []
	files.append(filename)
	SceneDataManager.scene_data["image_filenames"] = files
	SceneDataManager.scene_data["current_image_index"] = files.size() - 1
	SceneDataManager.save()


func _get_no_image_placeholder() -> Control:
	var background := _node("BackgroundImage") as TextureRect
	var existing := background.get_node_or_null("NoImagePlaceholder") as Control
	if existing:
		return existing
	var placeholder := CenterContainer.new()
	placeholder.name = "NoImagePlaceholder"
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(placeholder)
	var color := ColorRect.new()
	color.color = Color.BLACK
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.add_child(color)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color.WHITE)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Black", "Arial"])
	label.add_theme_font_override("font", font)
	label.text = "NO IMAGE"
	placeholder.add_child(label)
	return placeholder


func _load_placeholder_background(path: String, alpha: float) -> void:
	hide_generating_background()
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		error = image.load(path)
	if error != OK:
		error = _load_image_buffer(image, path)
	var background := _node("BackgroundImage") as TextureRect
	if error == OK:
		background.texture = ImageTexture.create_from_image(image)
		set_no_image_visible(false)
	else:
		var resource := load(path)
		if resource is Texture2D:
			background.texture = resource
	background.modulate = Color(1, 1, 1, alpha)


func _load_image_buffer(image: Image, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var lower := path.to_lower()
	if lower.ends_with(".png"):
		return image.load_png_from_buffer(bytes)
	if lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
		return image.load_jpg_from_buffer(bytes)
	if lower.ends_with(".webp"):
		return image.load_webp_from_buffer(bytes)
	return ERR_FILE_UNRECOGNIZED


func _is_image_filename(filename: String) -> bool:
	var lower := filename.to_lower()
	return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp")


func _current_uuid() -> String:
	return str(SceneDataManager.scene_data.get("uuid", GameProgressManager.settings.get("current_uuid", ""))).strip_edges()


func _set_visible(name: String, visible: bool) -> void:
	var control := _node(name) as Control
	if control:
		control.visible = visible


func _set_disabled(name: String, disabled: bool) -> void:
	var button := _node(name) as Button
	if button:
		button.disabled = disabled


func _set_text(name: String, text: String) -> void:
	var label := _node(name) as Label
	if label:
		label.text = text


func _node(unique_name: String) -> Node:
	return _host.get_node_or_null(NodePath("%%%s" % unique_name))
