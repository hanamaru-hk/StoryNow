extends Control

signal closed

func _ready() -> void:
	if has_node("%LoadCloseButton"):
		%LoadCloseButton.pressed.connect(_on_close_pressed)
	if has_node("%LoadBackground"):
		%LoadBackground.gui_input.connect(_on_background_input)
	_update_labels()


func open() -> void:
	visible = true
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
						var title: String = str(data.get("title", "")).strip_edges()
						if title.is_empty():
							title = str(data.get("summary", "")).strip_edges()
							if title.length() > 80:
								title = title.substr(0, 80) + "..."
						if title.is_empty():
							title = uuid
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
						entries.append({"uuid": uuid, "title": title, "round": round_int, "data": data})
					else:
						entries.append({"uuid": uuid, "title": uuid, "round": 1, "data": {}})
				else:
					entries.append({"uuid": uuid, "title": uuid, "round": 1, "data": {}})
		file_name = dir.get_next()
	dir.list_dir_end()

	if entries.is_empty():
		_add_empty_label("No saves found")
		return

	for entry in entries:
		_add_save_item(entry)


func _add_empty_label(text: String) -> void:
	var container: VBoxContainer = %LoadList
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(lbl)


func _add_save_item(entry: Dictionary) -> void:
	var container: VBoxContainer = %LoadList
	var uuid: String = str(entry.get("uuid", ""))
	var title: String = str(entry.get("title", uuid))

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 48)

	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	row.add_child(label)

	var btn_text: String = I18n.translate("btn_load") if I18n.translate("btn_load") != "btn_load" else "Load"
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(120, 36)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_save_pressed.bind(uuid, entry))
	row.add_child(btn)

	container.add_child(row)

	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	container.add_child(sep)


func _on_save_pressed(uuid: String, entry: Dictionary) -> void:
	if uuid.strip_edges().is_empty():
		return
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
