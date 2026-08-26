extends Node

var scene_data: Dictionary = {}

const SAVE_DIR := "user://saves"


func save() -> bool:
	var dt := Time.get_datetime_dict_from_system(false)
	scene_data["timestamp"] = "%04d/%02d/%02d %02d:%02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"], dt["second"]]
	var uuid := str(scene_data.get("uuid", ""))
	if uuid.is_empty():
		push_error("SceneDataManager.save: scene_data missing id")
		return false
	# see if folder saves exists -> no then create
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_absolute(SAVE_DIR)
		if err != OK:
			push_error("SceneDataManager.save: failed to create saves dir: %s" % error_string(err))
			return false
	# see if folder saves/[scene_data.uuid] exists -> no then create
	var uuid_dir := SAVE_DIR + "/" + uuid
	if not DirAccess.dir_exists_absolute(uuid_dir):
		var err2 := DirAccess.make_dir_recursive_absolute(uuid_dir)
		if err2 != OK:
			push_error("SceneDataManager.save: failed to create uuid dir %s: %s" % [uuid_dir, error_string(err2)])
			return false
	# save the scene_data.json into saves/[scene_data.uuid] from scene_data
	var file_path := uuid_dir + "/scene_data.json"
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("SceneDataManager.save: failed to open %s for writing" % file_path)
		return false
	file.store_string(JSON.stringify(scene_data, "\t"))
	file.close()
	return true


func load_data(uuid: String) -> bool:
	# see if folder saves exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		push_warning("SceneDataManager.load: saves dir does not exist")
		return false
	# see if folder saves/[uuid] exists
	var uuid_dir := SAVE_DIR + "/" + uuid
	if not DirAccess.dir_exists_absolute(uuid_dir):
		push_warning("SceneDataManager.load: uuid dir does not exist: %s" % uuid_dir)
		return false
	# load the data from saves/uuid/scene_data.json to scene_data
	var file_path := uuid_dir + "/scene_data.json"
	if not FileAccess.file_exists(file_path):
		push_warning("SceneDataManager.load: scene_data.json not found: %s" % file_path)
		return false
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("SceneDataManager.load: failed to open %s" % file_path)
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK or not json.data is Dictionary:
		push_error("SceneDataManager.load: failed to parse JSON: %s" % file_path)
		return false
	scene_data = json.data.duplicate(true)
	return true


# Alias for compatibility: load(uuid) — GDScript `load` is reserved, so use load_data
# Keep a wrapper named `load_scene` if needed, but expose `load_data` as primary.
# To allow `SceneDataManager.load(uuid)` calls, provide a callable via `call` trick:
func load(uuid: String) -> bool:
	return load_data(uuid)
