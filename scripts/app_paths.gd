extends Node

const BUILDER_DIR := "user://builder"


func _enter_tree() -> void:
	if DirAccess.dir_exists_absolute(BUILDER_DIR):
		return
	var error := DirAccess.make_dir_absolute(BUILDER_DIR)
	if error != OK:
		push_error("Failed to create %s: %s" % [BUILDER_DIR, error_string(error)])


func base_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


func external_path(relative_path: String) -> String:
	return base_dir().path_join(relative_path)


func external_exists(relative_path: String) -> bool:
	var path := external_path(relative_path)
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
