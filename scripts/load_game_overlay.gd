extends Control

signal closed

const PAGE_SIZE := 10
var _all_entries: Array[Dictionary] = []
var _current_page: int = 1
var _total_pages: int = 1
var _error_popup: AcceptDialog
var _delete_confirm_popup: ConfirmationDialog
var _pending_delete_uuid: String = ""

func _ready() -> void:
	if has_node("%LoadCloseButton"):
		%LoadCloseButton.pressed.connect(_on_close_pressed)
	if has_node("%LoadBackground"):
		%LoadBackground.gui_input.connect(_on_background_input)
	_create_error_popup()
	_create_delete_confirm_popup()
	_update_labels()


func open() -> void:
	visible = true
	_current_page = 1
	_refresh_list()
	_update_labels()


func close() -> void:
	visible = false
	closed.emit()


func _on_close_pressed() -> void:
	close()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _update_labels() -> void:
	if has_node("%LoadTitle"):
		var t: String = I18n.translate("load_title") if I18n.translate("load_title") != "load_title" else "Load Game"
		%LoadTitle.text = t
	if has_node("%LoadCloseButton"):
		var b: String = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
		%LoadCloseButton.text = b
	if _error_popup != null:
		_error_popup.title = I18n.translate("error_dialog_title")
	if _delete_confirm_popup != null:
		_delete_confirm_popup.title = I18n.translate("confirm_dialog_title")
		_delete_confirm_popup.ok_button_text = I18n.translate("btn_confirm")
		_delete_confirm_popup.cancel_button_text = I18n.translate("btn_cancel")


func _refresh_list() -> void:
	if not has_node("%LoadList"):
		return
	var container: VBoxContainer = %LoadList
	for child in container.get_children():
		child.queue_free()

	var save_dir: String = SceneDataManager.SAVE_DIR
	if not DirAccess.dir_exists_absolute(save_dir):
		_add_empty_label("No saves found")
		return

	var dir := DirAccess.open(save_dir)
	if dir == null:
		_add_empty_label("No saves found")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var entries: Array[Dictionary] = []
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			var uuid: String = file_name
			var scene_path: String = save_dir + "/" + uuid + "/scene_data.json"
			if FileAccess.file_exists(scene_path):
				var f := FileAccess.open(scene_path, FileAccess.READ)
				if f != null:
					var json := JSON.new()
					var err := json.parse(f.get_as_text())
					f.close()
					if err == OK and json.data is Dictionary:
						var data: Dictionary = json.data as Dictionary
						var title: String = _get_save_title(uuid, data)
						var round_val: Variant = data.get("current_round", data.get("round", 1))
						var round_int: int = 1
						if round_val is int:
							round_int = round_val
						elif round_val is float:
							round_int = int(round_val)
						elif round_val is String:
							if str(round_val).is_valid_int():
								round_int = int(round_val)
							elif str(round_val).is_valid_float():
								round_int = int(float(round_val))
						var timestamp: String = str(data.get("timestamp", ""))
						entries.append({"uuid": uuid, "title": title, "round": round_int, "timestamp": timestamp, "data": data})
					else:
						entries.append({"uuid": uuid, "title": uuid, "round": 1, "timestamp": "", "data": {}})
				else:
					entries.append({"uuid": uuid, "title": uuid, "round": 1, "timestamp": "", "data": {}})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by timestamp descending (newest first). Lexicographic compare works for YYYY/MM/DD HH:MM:SS.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("timestamp", "")) > str(b.get("timestamp", ""))
	)

	_all_entries = entries
	_total_pages = int(ceil(float(_all_entries.size()) / float(PAGE_SIZE))) if not _all_entries.is_empty() else 1
	if _current_page > _total_pages:
		_current_page = _total_pages
	if _current_page < 1:
		_current_page = 1

	if entries.is_empty():
		_add_empty_label("No saves found")
		_update_pagination_bar()
		return

	_show_current_page()


func _add_empty_label(text: String) -> void:
	var container: VBoxContainer = %LoadList
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(lbl)


func _is_generating_save(data: Dictionary) -> bool:
	var game_status := str(data.get("game_status", "")).strip_edges()
	return game_status == "new_story" or game_status == "new_scene" or game_status == "new scene"


func _get_save_title(uuid: String, data: Dictionary) -> String:
	if _is_generating_save(data):
		var generating_text := I18n.translate("generating")
		return generating_text if generating_text != "generating" else "Generating"
	var title := str(data.get("title", "")).strip_edges()
	if title.is_empty():
		title = str(data.get("summary", "")).strip_edges()
		if title.length() > 80:
			title = title.substr(0, 80) + "..."
	if title.is_empty():
		title = uuid
	return title


func _show_current_page() -> void:
	if not has_node("%LoadList"):
		return
	var container: VBoxContainer = %LoadList
	for child in container.get_children():
		child.queue_free()
	var start: int = (_current_page - 1) * PAGE_SIZE
	var end: int = min(start + PAGE_SIZE, _all_entries.size())
	for i in range(start, end):
		_add_save_item(_all_entries[i])
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
	if not has_node("%PaginationBar"):
		return
	var bar: HBoxContainer = %PaginationBar
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


func _get_current_image_path(uuid: String, data: Dictionary) -> String:
	# Prefer image_filenames[current_image_index], fallback to scanning images dir.
	var arr: Variant = data.get("image_filenames", [])
	if arr is Array:
		var filenames: Array = arr as Array
		if not filenames.is_empty():
			var current_index := clampi(int(data.get("current_image_index", 0)), 0, filenames.size() - 1)
			var current_filename: String = str(filenames[current_index]).strip_edges()
			if not current_filename.is_empty():
				var p: String = "user://saves/%s/images/%s" % [uuid, current_filename]
				if FileAccess.file_exists(p):
					return p
				# Also try globalized existence via DirAccess.
				var images_dir_check: String = "user://saves/%s/images" % uuid
				if DirAccess.dir_exists_absolute(images_dir_check):
					var d := DirAccess.open(images_dir_check)
					if d != null:
						d.list_dir_begin()
						var fn := d.get_next()
						while fn != "":
							if fn == current_filename:
								d.list_dir_end()
								return p
							fn = d.get_next()
						d.list_dir_end()
	# Fallback: scan images directory for largest filename.
	var images_dir: String = "user://saves/%s/images" % uuid
	if not DirAccess.dir_exists_absolute(images_dir):
		return ""
	var dir := DirAccess.open(images_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	var largest_file: String = ""
	while fname != "":
		if not dir.current_is_dir() and (fname.ends_with(".png") or fname.ends_with(".jpg") or fname.ends_with(".jpeg") or fname.ends_with(".webp")):
			if largest_file.is_empty() or fname > largest_file:
				largest_file = fname
		fname = dir.get_next()
	dir.list_dir_end()
	if largest_file.is_empty():
		return ""
	return "%s/%s" % [images_dir, largest_file]


func _load_texture_from_user_path(user_path: String) -> Texture2D:
	if user_path.is_empty():
		return null
	var global_path: String = ProjectSettings.globalize_path(user_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		err = img.load(user_path)
	if err != OK:
		err = _load_image_from_file_access(img, user_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _load_image_from_file_access(img: Image, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var lower_path := path.to_lower()
	if lower_path.ends_with(".png"):
		return img.load_png_from_buffer(bytes)
	if lower_path.ends_with(".jpg") or lower_path.ends_with(".jpeg"):
		return img.load_jpg_from_buffer(bytes)
	if lower_path.ends_with(".webp"):
		return img.load_webp_from_buffer(bytes)
	return ERR_FILE_UNRECOGNIZED


func _add_save_item(entry: Dictionary) -> void:
	var container: VBoxContainer = %LoadList
	var uuid: String = str(entry.get("uuid", ""))
	var data: Dictionary = entry.get("data", {}) as Dictionary if entry.get("data", {}) is Dictionary else {}
	var title: String = _get_save_title(uuid, data)
	var timestamp: String = str(entry.get("timestamp", "")).strip_edges()

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size = Vector2(0, 120)

	# Thumbnail
	var thumb_path: String = _get_current_image_path(uuid, data)
	var tex: Texture2D = _load_texture_from_user_path(thumb_path)
	if tex == null:
		row.add_child(_create_no_image_thumbnail())
	else:
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(180, 112)
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.texture = tex
		row.add_child(thumb)

	# Timestamp + title vertical stack
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 8)

	var title_text := RichTextLabel.new()
	title_text.bbcode_enabled = true
	title_text.fit_content = true
	title_text.scroll_active = false
	title_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_text.custom_minimum_size = Vector2(0, 72)
	title_text.text = "[font_size=20][color=#d2d2d2]%s[/color][/font_size]\n[font_size=24][color=#ffffff]%s[/color][/font_size]" % [
		timestamp if not timestamp.is_empty() else "-",
		title,
	]
	vbox.add_child(title_text)

	row.add_child(vbox)

	var delete_btn_text: String = I18n.translate("btn_delete") if I18n.translate("btn_delete") != "btn_delete" else "Delete"
	var delete_btn := Button.new()
	delete_btn.text = delete_btn_text
	delete_btn.custom_minimum_size = Vector2(120, 44)
	delete_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete_btn.disabled = _is_current_gameplay_save(uuid)
	delete_btn.pressed.connect(_on_delete_save_pressed.bind(uuid, title))
	row.add_child(delete_btn)

	var load_btn_text: String = I18n.translate("btn_load") if I18n.translate("btn_load") != "btn_load" else "Load"
	var load_btn := Button.new()
	load_btn.text = load_btn_text
	load_btn.custom_minimum_size = Vector2(120, 44)
	load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_btn.pressed.connect(_on_save_pressed.bind(uuid, entry))
	row.add_child(load_btn)

	container.add_child(row)

	var sep := ColorRect.new()
	sep.color = Color(0.48, 0.48, 0.48, 1)
	sep.custom_minimum_size = Vector2(0, 4)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(sep)


func _create_no_image_thumbnail() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(180, 112)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_override("font", _create_no_image_font())
	label.text = "NO IMAGE"
	holder.add_child(label)
	return holder


func _create_no_image_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Black", "Arial"])
	return font


func _on_save_pressed(uuid: String, entry: Dictionary) -> void:
	if uuid.strip_edges().is_empty():
		return
	if not _are_story_servers_ready():
		_show_error_popup(I18n.translate("notice_wait_llm_and_image_ready"))
		return
	if ServerRuntimeManager.has_generation_requests():
		await ServerRuntimeManager.cancel_active_generation_tasks()
	# Similar to prev scene handler: set game progress uuid and go to gameplay
	GameProgressManager.settings["current_uuid"] = uuid
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.settings["current_dialogue"] = 0
	# Restore current_round from scene_data if available
	var round_val: Variant = entry.get("round", null)
	if round_val == null:
		var data: Dictionary = entry.get("data", {}) as Dictionary
		round_val = data.get("current_round", GameProgressManager.settings.get("current_round", 1))
	var cur_round: int = int(GameProgressManager.settings.get("current_round", 1))
	if round_val is int:
		cur_round = round_val
	elif round_val is float:
		cur_round = int(round_val)
	elif round_val is String:
		if str(round_val).is_valid_int():
			cur_round = int(round_val)
		elif str(round_val).is_valid_float():
			cur_round = int(float(round_val))
	if cur_round < 1:
		cur_round = 1
	GameProgressManager.settings["current_round"] = cur_round
	GameProgressManager.save_settings()
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")


func _on_delete_save_pressed(uuid: String, title: String) -> void:
	var clean_uuid := uuid.strip_edges()
	if clean_uuid.is_empty():
		return
	if _is_current_gameplay_save(clean_uuid):
		return
	_pending_delete_uuid = clean_uuid
	if _delete_confirm_popup == null:
		_create_delete_confirm_popup()
	var template := I18n.translate("load_delete_confirm")
	if template == "load_delete_confirm":
		template = "Delete this save?\n%s"
	_delete_confirm_popup.dialog_text = template % title
	_delete_confirm_popup.popup_centered()


func _on_delete_confirmed() -> void:
	var uuid := _pending_delete_uuid.strip_edges()
	_pending_delete_uuid = ""
	if uuid.is_empty():
		return
	if _is_current_gameplay_save(uuid):
		return
	var save_path := "%s/%s" % [SceneDataManager.SAVE_DIR, uuid]
	if not _delete_directory_recursive(save_path):
		_show_error_popup(I18n.translate("error_dialog_text"))
		return
	if str(GameProgressManager.settings.get("current_uuid", "")).strip_edges() == uuid:
		GameProgressManager.settings["current_uuid"] = ""
		GameProgressManager.settings["current_dialogue"] = 0
		GameProgressManager.settings["game_status"] = ""
		GameProgressManager.save_settings()
	if str(SceneDataManager.scene_data.get("uuid", "")).strip_edges() == uuid:
		SceneDataManager.scene_data = {}
	_refresh_list()


func _on_delete_canceled() -> void:
	_pending_delete_uuid = ""


func _is_current_gameplay_save(uuid: String) -> bool:
	var clean_uuid := uuid.strip_edges()
	if clean_uuid.is_empty():
		return false
	if get_tree().current_scene != null and get_tree().current_scene.name == "Gameplay":
		return clean_uuid == str(GameProgressManager.settings.get("current_uuid", "")).strip_edges()
	return false


func _delete_directory_recursive(path: String) -> bool:
	if path.strip_edges().is_empty() or not DirAccess.dir_exists_absolute(path):
		return false
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var child_path := "%s/%s" % [path, file_name]
			var ok := true
			if dir.current_is_dir():
				ok = _delete_directory_recursive(child_path)
			else:
				ok = dir.remove(file_name) == OK
			if not ok:
				dir.list_dir_end()
				return false
		file_name = dir.get_next()
	dir.list_dir_end()
	var parent := DirAccess.open(path.get_base_dir())
	if parent == null:
		return false
	return parent.remove(path.get_file()) == OK


func _is_llm_ready() -> bool:
	return ServerRuntimeManager.llm_state == ServerRuntimeManager.ServerState.HEALTHY


func _is_image_server_ready() -> bool:
	return ServerRuntimeManager.image_state == ServerRuntimeManager.ServerState.HEALTHY


func _are_story_servers_ready() -> bool:
	return _is_llm_ready() and _is_image_server_ready()


func _create_error_popup() -> void:
	_error_popup = AcceptDialog.new()
	_error_popup.name = "LoadErrorPopup"
	add_child(_error_popup)
	_center_popup_buttons(_error_popup)


func _create_delete_confirm_popup() -> void:
	_delete_confirm_popup = ConfirmationDialog.new()
	_delete_confirm_popup.name = "LoadDeleteConfirmPopup"
	_delete_confirm_popup.confirmed.connect(_on_delete_confirmed)
	_delete_confirm_popup.canceled.connect(_on_delete_canceled)
	add_child(_delete_confirm_popup)
	_center_popup_buttons(_delete_confirm_popup)


func _center_popup_buttons(popup: AcceptDialog) -> void:
	popup.min_size = Vector2i(520, 220)
	var label := popup.get_label()
	if label != null:
		label.custom_minimum_size = Vector2(420, 84)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok_button := popup.get_ok_button()
	if ok_button != null:
		ok_button.custom_minimum_size = Vector2(180, 48)
		if ok_button.get_parent() is BoxContainer:
			var button_row := ok_button.get_parent() as BoxContainer
			button_row.alignment = BoxContainer.ALIGNMENT_CENTER
			button_row.add_theme_constant_override("separation", 24)
	if popup is ConfirmationDialog:
		var cancel_button := (popup as ConfirmationDialog).get_cancel_button()
		if cancel_button != null:
			cancel_button.custom_minimum_size = Vector2(180, 48)


func _show_error_popup(message: String) -> void:
	if _error_popup == null:
		_create_error_popup()
	_error_popup.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	_error_popup.popup_centered()
