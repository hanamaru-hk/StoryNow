extends Node

const MUSIC_DIR := "data/music"
const BACKGROUND_MUSIC_ENABLED := false

var _player: AudioStreamPlayer
var _current_path: String = ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BGMPlayer"
	_player.bus = "Master"
	add_child(_player)
	if is_instance_valid(GameSettingsManager) and GameSettingsManager.has_signal("music_settings_changed"):
		GameSettingsManager.music_settings_changed.connect(_apply_settings)
	_apply_settings()


func play_for_scene(scene_data: Dictionary) -> void:
	if not BACKGROUND_MUSIC_ENABLED:
		stop()
		return
	var mood: String = str(scene_data.get("bgm_mood", "")).strip_edges().to_lower()
	if mood.is_empty():
		mood = str(scene_data.get("music_mood", "")).strip_edges().to_lower()
	if mood.is_empty():
		stop()
		return
	play_random_mood(mood, true)


func play_random_mood(mood: String, restart_if_playing: bool = false) -> void:
	if not BACKGROUND_MUSIC_ENABLED:
		stop()
		return
	if not restart_if_playing and _player.playing:
		return
	var music_path: String = _pick_random_music_path(mood)
	if music_path.is_empty() and mood == "others":
		music_path = _pick_random_music_path("other")
	if music_path.is_empty():
		push_warning("No music found for mood: %s" % mood)
		stop()
		return
	_play_path(music_path)


func stop() -> void:
	_player.stop()
	_player.stream = null
	_current_path = ""


func _play_path(music_path: String) -> void:
	if music_path == _current_path and _player.playing:
		return
	var stream: AudioStreamMP3 = AudioStreamMP3.load_from_file(music_path)
	if stream == null:
		push_warning("Failed to load bgm: %s" % music_path)
		stop()
		return
	stream.loop = true
	_current_path = music_path
	_player.stream = stream
	_apply_settings()
	_player.play()


func _pick_random_music_path(mood: String) -> String:
	var dir_path: String = AppPaths.external_path(MUSIC_DIR.path_join(mood))
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return ""
	var candidates: PackedStringArray = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".mp3"):
			candidates.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _apply_settings() -> void:
	var muted: bool = bool(GameSettingsManager.settings.get("music_muted", false))
	var volume_percent: int = clampi(int(GameSettingsManager.settings.get("music_volume", 70)), 0, 100)
	_player.volume_db = linear_to_db(float(volume_percent) / 100.0) if volume_percent > 0 else -80.0
	_player.stream_paused = muted
