extends Node

const SETTINGS_PATH := "user://image_server_settings.json"
const DEFAULT_SETTINGS_PATH := "data/default_image_server_settings.json"

var settings := {
	"port": 56321,
	"timeout": 120,
}


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	_normalize_integer_settings()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings.merge(json.data, true)
			_normalize_integer_settings()


func reset_to_defaults() -> void:
	var file := FileAccess.open(AppPaths.external_path(DEFAULT_SETTINGS_PATH), FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings = json.data.duplicate()
			_normalize_integer_settings()
			save_settings()


func _normalize_integer_settings() -> void:
	for key in ["port", "timeout"]:
		if settings.has(key):
			settings[key] = str(settings[key]).to_int()
