extends Node

signal music_settings_changed
signal voice_settings_changed

const SETTINGS_PATH := "user://game_settings.json"
const DEFAULT_SETTINGS_PATH := "data/default_game_settings.json"
const DEFAULT_DIALOGUE_TEXT_SPEED := 30
const MIN_DIALOGUE_TEXT_SPEED := 5
const MAX_DIALOGUE_TEXT_SPEED := 120

var settings := {
	"first_time": true,
	"language": "en",
	"screen_size": "full",
	"last_windows_resolution": "1344x768",
	"last_aspect_ratio": "16:9",
	"safe_mode": false,
	"tried_builder_mode_yet": false,
	"autoplay_tts": true,
	"show_streaming": true,
	"dialogue_text_instant": false,
	"dialogue_text_speed": DEFAULT_DIALOGUE_TEXT_SPEED,
	"voice_volume": 100,
	"voice_muted": false,
	"music_volume": 70,
	"music_muted": false,
}


func _ready() -> void:
	load_settings()
	_apply_language()
	_apply_screen_size()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.alt_pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func save_settings() -> void:
	settings["dialogue_text_instant"] = is_dialogue_text_instant()
	settings["dialogue_text_speed"] = dialogue_text_speed()
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
	settings["dialogue_text_instant"] = is_dialogue_text_instant()
	settings["dialogue_text_speed"] = dialogue_text_speed()
	_update_hidden_screen_fields()


func reset_to_defaults() -> void:
	var file := FileAccess.open(AppPaths.external_path(DEFAULT_SETTINGS_PATH), FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			settings = json.data.duplicate()
			_update_hidden_screen_fields()
			_apply_language()
			_apply_screen_size()
			save_settings()
			music_settings_changed.emit()
			voice_settings_changed.emit()


func set_language(lang: String) -> void:
	settings["language"] = lang
	_apply_language()
	save_settings()


func complete_first_time_setup() -> void:
	settings["first_time"] = false
	save_settings()


func set_screen_size(size: String) -> void:
	settings["screen_size"] = size
	_update_hidden_screen_fields()
	_apply_screen_size()
	save_settings()


func set_music_settings(volume: int, muted: bool) -> void:
	settings["music_volume"] = clampi(volume, 0, 100)
	settings["music_muted"] = muted
	save_settings()
	music_settings_changed.emit()


func set_voice_settings(volume: int, muted: bool) -> void:
	settings["voice_volume"] = clampi(volume, 0, 100)
	settings["voice_muted"] = muted
	save_settings()
	voice_settings_changed.emit()


func dialogue_text_speed() -> int:
	var value := SettingsValueValidator.positive_integer_or_default(
		settings.get("dialogue_text_speed", DEFAULT_DIALOGUE_TEXT_SPEED),
		DEFAULT_DIALOGUE_TEXT_SPEED
	)
	return clampi(value, MIN_DIALOGUE_TEXT_SPEED, MAX_DIALOGUE_TEXT_SPEED)


func is_dialogue_text_instant() -> bool:
	var value: Variant = settings.get("dialogue_text_instant", false)
	return value if value is bool else false


func toggle_fullscreen() -> void:
	if _is_fullscreen_mode():
		var last_resolution: String = str(settings.get("last_windows_resolution", "1344x768"))
		if not _is_windowed_screen_size(last_resolution):
			last_resolution = "1344x768"
		settings["screen_size"] = last_resolution
		settings["last_windows_resolution"] = last_resolution
		settings["last_aspect_ratio"] = _aspect_ratio_for_resolution(last_resolution)
	else:
		var current_size: String = _current_window_resolution_key()
		if not _is_windowed_screen_size(current_size):
			current_size = str(settings.get("screen_size", "1344x768"))
		if not _is_windowed_screen_size(current_size):
			current_size = "1344x768"
		settings["last_windows_resolution"] = current_size
		settings["last_aspect_ratio"] = _aspect_ratio_for_resolution(current_size)
		settings["screen_size"] = "full"
	_apply_screen_size()
	save_settings()


func has_tried_builder_mode_yet() -> bool:
	return bool(settings.get("tried_builder_mode_yet", false))


func mark_tried_builder_mode_yet() -> void:
	settings["tried_builder_mode_yet"] = true
	save_settings()


func _apply_language() -> void:
	I18n.set_language(settings["language"])


func _apply_screen_size() -> void:
	_update_hidden_screen_fields()
	match settings["screen_size"]:
		"full":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"1344x768":
			_apply_windowed_resolution(Vector2i(1344, 768))
		"1600x900":
			_apply_windowed_resolution(Vector2i(1600, 900))


func _apply_windowed_resolution(resolution: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_title("StoryNow")
	var screen_size := DisplayServer.screen_get_size()
	var centered := (screen_size - resolution) / 2
	DisplayServer.window_set_position(centered)


func _update_hidden_screen_fields() -> void:
	match str(settings.get("screen_size", "full")):
		"1344x768":
			settings["last_windows_resolution"] = "1344x768"
			settings["last_aspect_ratio"] = "16:9"
		"1600x900":
			settings["last_windows_resolution"] = "1600x900"
			settings["last_aspect_ratio"] = "16:9"
		_:
			if not settings.has("last_windows_resolution"):
				settings["last_windows_resolution"] = "1344x768"
			if not settings.has("last_aspect_ratio"):
				settings["last_aspect_ratio"] = "16:9"


func _is_windowed_screen_size(size: String) -> bool:
	return size == "1344x768" or size == "1600x900"


func _is_fullscreen_mode() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _current_window_resolution_key() -> String:
	var size: Vector2i = DisplayServer.window_get_size()
	if size == Vector2i(1344, 768):
		return "1344x768"
	if size == Vector2i(1600, 900):
		return "1600x900"
	return ""


func _aspect_ratio_for_resolution(size: String) -> String:
	match size:
		"1344x768", "1600x900":
			return "16:9"
		_:
			return "16:9"


func is_builder_mode() -> bool:
	return not settings.get("safe_mode", false) and ( not DirAccess.get_files_at(AppPaths.external_path("data/builder")).is_empty() or not DirAccess.get_files_at("user://builder").is_empty() )
