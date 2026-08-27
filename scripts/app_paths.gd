extends Node


func base_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	return OS.get_executable_path().get_base_dir()


func external_path(relative_path: String) -> String:
	return base_dir().path_join(relative_path)


func external_exists(relative_path: String) -> bool:
	var path := external_path(relative_path)
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
