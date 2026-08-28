extends Control

const FADE_IN_SECONDS := 1.0
const BLACK_PRELOAD_SECONDS := 0.1
var _intro_video_should_resume := false


func _ready() -> void:
	modulate.a = 1.0
	_start_hidden_menu_video()
	print_verbose("")
	print_verbose("user data dir: " + OS.get_user_data_dir())
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Setting.pressed.connect(_on_setting_pressed)
	%AdvancedSetting.pressed.connect(_on_advanced_setting_pressed)
	%Exit.pressed.connect(_on_exit_pressed)
	%GameSettingsOverlay.closed.connect(_on_settings_closed)
	%AdvancedSettingsOverlay.closed.connect(_on_settings_closed)
	%AdvancedSettingsOverlay.image_settings_requested.connect(_on_image_server_setting_pressed)
	%AdvancedSettingsOverlay.llm_settings_requested.connect(_on_llm_setting_pressed)
	%ImageServerSettingsOverlay.closed.connect(_on_settings_closed)
	%LLMSettingsOverlay.closed.connect(_on_settings_closed)
	%FirstTimeLanguageOverlay.language_selected.connect(_on_first_time_language_selected)
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.closed.connect(_on_settings_closed)
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.closed.connect(_on_settings_closed)
	MusicManager.play_random_mood("others")
	_update_labels()
	_check_first_time_overlay()
	_play_intro_sequence()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/brainstorm.tscn")


func _on_load_pressed() -> void:
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.open()


func _on_gallery_pressed() -> void:
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.open()


func _on_setting_pressed() -> void:
	%GameSettingsOverlay.open()


func _on_advanced_setting_pressed() -> void:
	%AdvancedSettingsOverlay.open()


func _on_image_server_setting_pressed() -> void:
	%ImageServerSettingsOverlay.open()


func _on_llm_setting_pressed() -> void:
	%LLMSettingsOverlay.open()


func _on_settings_closed() -> void:
	_update_labels()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _check_first_time_overlay() -> void:
	if bool(GameSettingsManager.settings.get("first_time", true)):
		_intro_video_should_resume = true
		_pause_intro_video()
		%FirstTimeLanguageOverlay.open()


func _on_first_time_language_selected(_lang: String) -> void:
	_update_labels()
	if _intro_video_should_resume:
		_intro_video_should_resume = false
		_resume_intro_video()


func _update_labels() -> void:
	%Start.text = I18n.translate("btn_start")
	%Load.text = I18n.translate("btn_load")
	%Gallery.text = I18n.translate("btn_gallery")
	%Setting.text = I18n.translate("btn_game_setting")
	%AdvancedSetting.text = I18n.translate("btn_advanced_setting")
	%Exit.text = I18n.translate("btn_exit")


func _start_hidden_menu_video() -> void:
	%MenuVideo.visible = false
	%MenuVideo.modulate.a = 0.0
	%MenuVideo.stop()
	%MenuVideo.stream_position = 0.0
	%MenuVideo.play()


func _play_intro_sequence() -> void:
	await get_tree().create_timer(BLACK_PRELOAD_SECONDS).timeout
	%MenuVideo.visible = true
	var tween := create_tween()
	tween.tween_property(%MenuVideo, "modulate:a", 1.0, FADE_IN_SECONDS)
	tween.finished.connect(_on_intro_fade_finished)


func _on_intro_fade_finished() -> void:
	pass


func _on_menu_video_finished() -> void:
	%MenuVideo.paused = true


func _pause_intro_video() -> void:
	if %MenuVideo.is_playing():
		%MenuVideo.paused = true


func _resume_intro_video() -> void:
	if %MenuVideo.stream != null:
		%MenuVideo.paused = false
