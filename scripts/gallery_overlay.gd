extends Control

signal closed

const PAGE_SIZE := 12
const GRID_COLUMNS := 4
var _all_entries: Array[Dictionary] = []
var _current_page: int = 1
var _total_pages: int = 1
var _preview_uuid: String = ""
var _preview_entry: Dictionary = {}
var _preview_index: int = -1
var _preview_ui_hidden: bool = false
var _pending_engine_retry_action := ""


func _ready() -> void:
	if has_node("%GalleryBackButton"):
		%GalleryBackButton.pressed.connect(_on_back_pressed)
	if has_node("%GalleryBackground"):
		%GalleryBackground.gui_input.connect(_on_background_input)
	%GalleryPreview.gui_input.connect(_on_gallery_preview_input)
	%GalleryPreviewPreviousButton.pressed.connect(_on_preview_previous_pressed)
	%GalleryPreviewNextButton.pressed.connect(_on_preview_next_pressed)
	%GalleryPreviewLoadButton.pressed.connect(_on_preview_load_pressed)
	%GalleryPreviewBackButton.pressed.connect(_hide_preview)
	%GalleryPreviewConfirmCancel.pressed.connect(_on_preview_load_canceled)
	%GalleryPreviewConfirmLoad.pressed.connect(_on_preview_load_confirmed)
	%GalleryPreviewErrorOk.pressed.connect(_on_preview_error_ok_pressed)
	%GalleryPreviewErrorRetry.pressed.connect(_on_preview_error_retry_pressed)
	_update_labels()


func open() -> void:
	visible = true
	ServerRuntimeManager.set_engine_status_hint_visible(false)
	_hide_preview()
	_current_page = 1
	_refresh_grid()
	_update_labels()


func close() -> void:
	ServerRuntimeManager.set_engine_status_hint_visible(false)
	_hide_preview()
	visible = false
	closed.emit()


func _on_back_pressed() -> void:
	close()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _update_labels() -> void:
	if has_node("%GalleryTitle"):
		var t: String = I18n.translate("btn_gallery")
		%GalleryTitle.text = t if t != "btn_gallery" else "Gallery"
	if has_node("%GalleryBackButton"):
		var b: String = I18n.translate("btn_back")
		%GalleryBackButton.text = b if b != "btn_back" else "Back"
	var load_scene_text := I18n.translate("gallery_load_scene")
	%GalleryPreviewLoadButton.text = load_scene_text if load_scene_text != "gallery_load_scene" else "Load Scene"
	var preview_back_text := I18n.translate("btn_back")
	%GalleryPreviewBackButton.text = preview_back_text if preview_back_text != "btn_back" else "Back"
	%GalleryPreviewConfirmTitle.text = I18n.translate("confirm_dialog_title")
	%GalleryPreviewConfirmLoad.text = I18n.translate("btn_confirm")
	%GalleryPreviewConfirmCancel.text = I18n.translate("btn_cancel")
	%GalleryPreviewErrorTitle.text = I18n.translate("error_dialog_title")
	%GalleryPreviewErrorOk.text = "OK"
	%GalleryPreviewErrorRetry.text = I18n.translate("btn_retry")


func _refresh_grid() -> void:
	if not has_node("%GalleryGrid"):
		return
	var grid: GridContainer = %GalleryGrid
	for child in grid.get_children():
		child.queue_free()

	_all_entries = _get_gallery_entries()
	_total_pages = int(ceil(float(_all_entries.size()) / float(PAGE_SIZE))) if not _all_entries.is_empty() else 1
	if _current_page > _total_pages:
		_current_page = _total_pages
	if _current_page < 1:
		_current_page = 1

	if _all_entries.is_empty():
		grid.columns = 1
		var t_empty: String = I18n.translate("gallery_empty")
		_add_empty_label(t_empty if t_empty != "gallery_empty" else "No images")
		_update_pagination_bar()
		return

	_show_current_page()


func _get_gallery_entries() -> Array[Dictionary]:
	var save_dir: String = SceneDataManager.SAVE_DIR
	if not DirAccess.dir_exists_absolute(save_dir):
		return []

	var dir := DirAccess.open(save_dir)
	if dir == null:
		return []

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var entries: Array[Dictionary] = []
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			var entry := _read_save_entry(file_name)
			if not entry.is_empty():
				entries.append_array(_get_save_image_entries(entry))
		file_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_timestamp := str(a.get("timestamp", ""))
		var b_timestamp := str(b.get("timestamp", ""))
		if a_timestamp == b_timestamp:
			return int(a.get("image_index", 0)) < int(b.get("image_index", 0))
		return a_timestamp > b_timestamp
	)
	return entries


func _add_empty_label(text: String) -> void:
	var grid: GridContainer = %GalleryGrid
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(lbl)


func _show_current_page() -> void:
	if not has_node("%GalleryGrid"):
		return
	var grid: GridContainer = %GalleryGrid
	grid.columns = GRID_COLUMNS
	for child in grid.get_children():
		child.queue_free()
	var start: int = (_current_page - 1) * PAGE_SIZE
	var end: int = min(start + PAGE_SIZE, _all_entries.size())
	for i in range(start, end):
		_add_gallery_item(_all_entries[i])
	for i in range(end - start, PAGE_SIZE):
		_add_gallery_placeholder()
	_update_pagination_bar()


func _get_pagination_sequence(cur: int, total: int) -> Array:
	if total <= 7:
		var all: Array = []
		for i in range(total):
			all.append(i + 1)
		return all
	var pages_set := {}
	for i in [1, 2, 3]:
		if i >= 1 and i <= total:
			pages_set[i] = true
	for i in [total - 2, total - 1, total]:
		if i >= 1 and i <= total:
			pages_set[i] = true
	for i in [cur - 1, cur, cur + 1]:
		if i >= 1 and i <= total:
			pages_set[i] = true
	var sorted_keys: Array = pages_set.keys()
	sorted_keys.sort()
	var result: Array = []
	var prev: int = -100
	for k in sorted_keys:
		var ki: int = int(k)
		if prev != -100:
			var gap: int = ki - prev
			if gap == 2:
				result.append(prev + 1)
			elif gap > 2:
				result.append("...")
		result.append(ki)
		prev = ki
	return result


func _update_pagination_bar() -> void:
	if not has_node("%GalleryPaginationBar"):
		return
	var bar: HBoxContainer = %GalleryPaginationBar
	for child in bar.get_children():
		child.queue_free()
	if _total_pages <= 1:
		bar.visible = false
		return
	bar.visible = true

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 32)
	prev_btn.disabled = _current_page <= 1
	prev_btn.pressed.connect(_on_page_prev)
	bar.add_child(prev_btn)

	var seq: Array = _get_pagination_sequence(_current_page, _total_pages)
	for item in seq:
		if item is String:
			var lbl := Label.new()
			lbl.text = "..."
			lbl.custom_minimum_size = Vector2(24, 32)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			bar.add_child(lbl)
		else:
			var page_num: int = int(item)
			var btn := Button.new()
			btn.text = str(page_num)
			btn.custom_minimum_size = Vector2(40, 32)
			btn.disabled = page_num == _current_page
			if page_num == _current_page:
				btn.modulate = Color(0.7, 0.85, 1, 1)
			btn.pressed.connect(_on_page_selected.bind(page_num))
			bar.add_child(btn)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 32)
	next_btn.disabled = _current_page >= _total_pages
	next_btn.pressed.connect(_on_page_next)
	bar.add_child(next_btn)


func _on_page_selected(page: int) -> void:
	if page < 1 or page > _total_pages:
		return
	if page == _current_page:
		return
	_current_page = page
	_show_current_page()


func _on_page_prev() -> void:
	if _current_page > 1:
		_current_page -= 1
		_show_current_page()


func _on_page_next() -> void:
	if _current_page < _total_pages:
		_current_page += 1
		_show_current_page()


func _read_save_entry(uuid: String) -> Dictionary:
	var scene_path: String = "%s/%s/scene_data.json" % [SceneDataManager.SAVE_DIR, uuid]
	if not FileAccess.file_exists(scene_path):
		return {}

	var file := FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK or not json.data is Dictionary:
		return {"uuid": uuid, "title": uuid, "round": 1, "timestamp": "", "data": {}}

	var data: Dictionary = json.data as Dictionary
	var title: String = str(data.get("title", "")).strip_edges()
	if title.is_empty():
		title = str(data.get("summary", "")).strip_edges()
		if title.length() > 48:
			title = title.substr(0, 48) + "..."
	if title.is_empty():
		title = uuid

	var round_val: Variant = data.get("current_round", data.get("round", 1))
	return {
		"uuid": uuid,
		"title": title,
		"round": _to_positive_int(round_val, 1),
		"timestamp": str(data.get("timestamp", "")),
		"data": data,
	}


func _add_gallery_item(entry: Dictionary) -> void:
	var grid: GridContainer = %GalleryGrid
	var uuid: String = str(entry.get("uuid", ""))
	var data: Dictionary = entry.get("data", {}) as Dictionary if entry.get("data", {}) is Dictionary else {}
	var image_path: String = str(entry.get("image_path", ""))

	var button := Button.new()
	# Thumbnail cards intentionally retain Godot's dark neutral style instead of the app-wide light controls.
	button.theme = ThemeDB.get_default_theme()
	button.custom_minimum_size = Vector2(230, 180)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.pressed.connect(_on_gallery_item_pressed.bind(uuid, entry))
	grid.add_child(button)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.custom_minimum_size = Vector2(214, 120.375)
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_child(aspect)

	var thumb := TextureRect.new()
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.texture = _load_texture_from_user_path(image_path)
	thumb.modulate = Color(0.32, 0.32, 0.38, 1) if thumb.texture == null else Color.WHITE
	aspect.add_child(thumb)

	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = false
	title.scroll_active = false
	title.custom_minimum_size = Vector2(0, 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var escaped_title: String = _escape_bbcode(str(entry.get("title", uuid)))
	title.text = "[center][font_size=18][color=#ffffff]%s[/color][/font_size][/center]" % escaped_title
	stack.add_child(title)


func _add_gallery_placeholder() -> void:
	var placeholder := Control.new()
	placeholder.custom_minimum_size = Vector2(230, 180)
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%GalleryGrid.add_child(placeholder)


func _get_save_image_entries(entry: Dictionary) -> Array[Dictionary]:
	var uuid: String = str(entry.get("uuid", "")).strip_edges()
	var data: Dictionary = entry.get("data", {}) as Dictionary if entry.get("data", {}) is Dictionary else {}
	var result: Array[Dictionary] = []
	if uuid.is_empty():
		return result
	var arr: Variant = data.get("image_filenames", [])
	if not arr is Array:
		return result

	var filenames: Array = arr as Array
	for i in range(filenames.size()):
		var filename: String = str(filenames[i]).strip_edges()
		if filename.is_empty():
			continue
		var image_path := "user://saves/%s/images/%s" % [uuid, filename]
		if not FileAccess.file_exists(image_path):
			continue
		var image_entry: Dictionary = entry.duplicate(true)
		image_entry["image_filename"] = filename
		image_entry["image_index"] = i
		image_entry["image_path"] = image_path
		result.append(image_entry)
	return result


func _load_texture_from_user_path(user_path: String) -> Texture2D:
	if user_path.is_empty():
		return null
	var img := Image.new()
	var err: Error = img.load(ProjectSettings.globalize_path(user_path))
	if err != OK:
		err = img.load(user_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _on_gallery_item_pressed(uuid: String, entry: Dictionary) -> void:
	if uuid.strip_edges().is_empty():
		return
	var index := _find_gallery_entry_index(uuid, entry)
	if index < 0:
		return
	_show_preview_at_index(index)


func _find_gallery_entry_index(uuid: String, entry: Dictionary) -> int:
	var image_path := str(entry.get("image_path", "")).strip_edges()
	for i in range(_all_entries.size()):
		var candidate: Dictionary = _all_entries[i]
		if str(candidate.get("uuid", "")) == uuid and str(candidate.get("image_path", "")).strip_edges() == image_path:
			return i
	return -1


func _show_preview_at_index(index: int) -> void:
	if index < 0 or index >= _all_entries.size():
		return
	var entry: Dictionary = _all_entries[index]
	var uuid := str(entry.get("uuid", "")).strip_edges()
	var image_path: String = str(entry.get("image_path", "")).strip_edges()
	var texture := _load_texture_from_user_path(image_path)
	if uuid.is_empty() or texture == null:
		return
	_preview_index = index
	_preview_uuid = uuid
	_preview_entry = entry.duplicate(true)
	%GalleryPreviewImage.texture = texture
	%GalleryPreviewTitle.text = _get_preview_title(uuid, entry)
	%GalleryPreviewPreviousButton.disabled = index <= 0
	%GalleryPreviewNextButton.disabled = index >= _all_entries.size() - 1
	%GalleryPreviewLoadButton.disabled = false
	%GalleryPreviewBackButton.disabled = false
	var entry_page := int(index / PAGE_SIZE) + 1
	if entry_page != _current_page:
		_current_page = entry_page
		_show_current_page()
	_set_preview_ui_hidden(false)
	%GalleryPreview.visible = true
	%GalleryPreviewLoadButton.grab_focus()


func _get_preview_title(uuid: String, entry: Dictionary) -> String:
	var title := str(entry.get("title", "")).strip_edges()
	var data: Dictionary = entry.get("data", {}) as Dictionary if entry.get("data", {}) is Dictionary else {}
	if title.is_empty():
		title = str(data.get("title", "")).strip_edges()
	if title.is_empty():
		title = str(data.get("summary", "")).strip_edges()
	if title.length() > 80:
		title = title.substr(0, 80) + "..."
	return title if not title.is_empty() else uuid


func _hide_preview() -> void:
	ServerRuntimeManager.set_engine_status_hint_visible(false)
	_pending_engine_retry_action = ""
	_set_preview_ui_hidden(false)
	_preview_uuid = ""
	_preview_entry = {}
	_preview_index = -1
	%GalleryPreviewImage.texture = null
	%GalleryPreviewTitle.text = ""
	%GalleryPreviewPreviousButton.disabled = false
	%GalleryPreviewNextButton.disabled = false
	%GalleryPreviewLoadButton.disabled = false
	%GalleryPreviewBackButton.disabled = false
	%GalleryPreviewConfirmPopup.visible = false
	%GalleryPreviewErrorPopup.visible = false
	%GalleryPreviewErrorRetry.visible = false
	%GalleryPreview.visible = false


func _on_gallery_preview_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if _preview_ui_hidden:
		_set_preview_ui_hidden(false)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_set_preview_ui_hidden(true)
		get_viewport().set_input_as_handled()


func _set_preview_ui_hidden(is_hidden: bool) -> void:
	_preview_ui_hidden = is_hidden
	%BottomBar.visible = not is_hidden
	ServerRuntimeManager.set_chrome_visible(not is_hidden)


func _on_preview_previous_pressed() -> void:
	_show_preview_at_index(_preview_index - 1)


func _on_preview_next_pressed() -> void:
	_show_preview_at_index(_preview_index + 1)


func _on_preview_load_pressed() -> void:
	if _preview_uuid.strip_edges().is_empty() or _preview_entry.is_empty():
		return
	var has_pending_generation := ServerRuntimeManager.has_generation_requests()
	if not has_pending_generation and not _are_story_servers_ready():
		_show_preview_error(I18n.translate("notice_wait_llm_and_image_ready"), true, "show_confirmation")
		return
	if has_pending_generation:
		%GalleryPreviewConfirmMessage.text = I18n.translate("confirm_leave_generation_pending")
		%GalleryPreviewConfirmCancel.text = I18n.translate("btn_back")
	else:
		var template := I18n.translate("gallery_load_scene_confirm")
		if template == "gallery_load_scene_confirm":
			template = "Load this scene?\n%s"
		%GalleryPreviewConfirmMessage.text = template % _get_preview_title(_preview_uuid, _preview_entry)
		%GalleryPreviewConfirmCancel.text = I18n.translate("btn_cancel")
	%GalleryPreviewConfirmPopup.visible = true
	%GalleryPreviewConfirmLoad.grab_focus()


func _on_preview_load_canceled() -> void:
	%GalleryPreviewConfirmPopup.visible = false
	%GalleryPreviewLoadButton.grab_focus()


func _on_preview_load_confirmed() -> void:
	%GalleryPreviewConfirmPopup.visible = false
	if not _are_story_servers_ready():
		_show_preview_error(I18n.translate("notice_wait_llm_and_image_ready"), true, "load")
		return
	var uuid := _preview_uuid.strip_edges()
	var entry := _preview_entry.duplicate(true)
	if uuid.is_empty() or entry.is_empty():
		return
	%GalleryPreviewPreviousButton.disabled = true
	%GalleryPreviewNextButton.disabled = true
	%GalleryPreviewLoadButton.disabled = true
	%GalleryPreviewBackButton.disabled = true
	var scene_changed := await _load_gallery_entry(uuid, entry)
	if is_instance_valid(self) and not scene_changed:
		_show_preview_at_index(_preview_index)


func _are_story_servers_ready() -> bool:
	return (
		ServerRuntimeManager.llm_state == ServerRuntimeManager.ServerState.HEALTHY
		and ServerRuntimeManager.image_state == ServerRuntimeManager.ServerState.HEALTHY
	)


func _show_preview_error(message: String, show_engine_status_hint := false, retry_action := "") -> void:
	_pending_engine_retry_action = retry_action if show_engine_status_hint else ""
	var popup_message := message if not message.is_empty() else I18n.translate("error_dialog_text")
	if not show_engine_status_hint:
		popup_message = %GalleryPreviewErrorMessage.escape_bbcode(popup_message)
	%GalleryPreviewErrorMessage.text = "[center]%s[/center]" % popup_message
	%GalleryPreviewErrorOk.text = I18n.translate("btn_back") if show_engine_status_hint else "OK"
	%GalleryPreviewErrorPopup.visible = true
	%GalleryPreviewErrorRetry.visible = not _pending_engine_retry_action.is_empty()
	if %GalleryPreviewErrorRetry.visible:
		%GalleryPreviewErrorRetry.grab_focus()
	else:
		%GalleryPreviewErrorOk.grab_focus()
	ServerRuntimeManager.set_engine_status_hint_visible(show_engine_status_hint)


func _on_preview_error_ok_pressed() -> void:
	_pending_engine_retry_action = ""
	%GalleryPreviewErrorPopup.visible = false
	%GalleryPreviewErrorRetry.visible = false
	ServerRuntimeManager.set_engine_status_hint_visible(false)
	%GalleryPreviewLoadButton.grab_focus()


func _on_preview_error_retry_pressed() -> void:
	if not _are_story_servers_ready():
		ServerRuntimeManager.emphasize_engine_status_hint()
		return
	var action := _pending_engine_retry_action
	_pending_engine_retry_action = ""
	%GalleryPreviewErrorPopup.visible = false
	%GalleryPreviewErrorRetry.visible = false
	ServerRuntimeManager.set_engine_status_hint_visible(false)
	if action == "load":
		await _on_preview_load_confirmed()
	elif action == "show_confirmation":
		_on_preview_load_pressed()


func _load_gallery_entry(uuid: String, entry: Dictionary) -> bool:
	var image_filename: String = str(entry.get("image_filename", "")).strip_edges()
	var image_index: int = _get_image_filename_index(entry, image_filename)
	if image_index < 0:
		return false
	if not SceneDataManager.load_data(uuid):
		return false
	if ServerRuntimeManager.has_generation_requests():
		await ServerRuntimeManager.cancel_active_generation_tasks()
	SceneDataManager.scene_data["current_image_index"] = image_index
	SceneDataManager.save()
	GameProgressManager.settings["current_uuid"] = uuid
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.settings["current_dialogue"] = 0
	GameProgressManager.settings["current_round"] = _to_positive_int(entry.get("round", 1), 1)
	GameProgressManager.save_settings()
	return get_tree().change_scene_to_file("res://scenes/gameplay.tscn") == OK


func _get_image_filename_index(entry: Dictionary, image_filename: String) -> int:
	if image_filename.is_empty():
		return -1
	var data: Dictionary = entry.get("data", {}) as Dictionary if entry.get("data", {}) is Dictionary else {}
	var arr: Variant = data.get("image_filenames", [])
	if not arr is Array:
		return -1
	var filenames: Array = arr as Array
	for i in range(filenames.size()):
		if str(filenames[i]).strip_edges() == image_filename:
			return i
	return -1


func _to_positive_int(value: Variant, fallback: int) -> int:
	var result := fallback
	if value is int:
		result = value
	elif value is float:
		result = int(value)
	elif value is String:
		if str(value).is_valid_int():
			result = int(value)
		elif str(value).is_valid_float():
			result = int(float(value))
	return max(result, 1)
