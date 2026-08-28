extends Control

signal closed

const PAGE_SIZE := 16
var _all_entries: Array[Dictionary] = []
var _current_page: int = 1
var _total_pages: int = 1


func _ready() -> void:
	if has_node("%GalleryBackButton"):
		%GalleryBackButton.pressed.connect(_on_back_pressed)
	if has_node("%GalleryBackground"):
		%GalleryBackground.gui_input.connect(_on_background_input)
	_update_labels()


func open() -> void:
	visible = true
	_current_page = 1
	_refresh_grid()
	_update_labels()


func close() -> void:
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
		var t_empty: String = I18n.translate("gallery_empty")
		_add_empty_label(t_empty if t_empty != "gallery_empty" else "No saves found")
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
	for child in grid.get_children():
		child.queue_free()
	var start: int = (_current_page - 1) * PAGE_SIZE
	var end: int = min(start + PAGE_SIZE, _all_entries.size())
	for i in range(start, end):
		_add_gallery_item(_all_entries[i])
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
	var image_filename: String = str(entry.get("image_filename", "")).strip_edges()
	var image_index: int = _get_image_filename_index(entry, image_filename)
	if image_index < 0:
		return
	if not SceneDataManager.load_data(uuid):
		return
	if ServerRuntimeManager.has_generation_requests():
		await ServerRuntimeManager.cancel_active_generation_tasks()
	SceneDataManager.scene_data["current_image_index"] = image_index
	SceneDataManager.save()
	GameProgressManager.settings["current_uuid"] = uuid
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.settings["current_dialogue"] = 0
	GameProgressManager.settings["current_round"] = _to_positive_int(entry.get("round", 1), 1)
	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


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
