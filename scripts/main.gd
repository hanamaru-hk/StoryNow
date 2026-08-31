extends Control

const FADE_IN_SECONDS := 1.0
const BLACK_PRELOAD_SECONDS := 0.1
const GRADIENT_REVEAL_DELAY := 1.5
const BUTTON_REVEAL_DELAY := 2.5
const OVERLAY_REVEAL_SECONDS := 0.8
const MENU_BACKGROUND_PATH := "res://assets/images/trail-start.webp"


func _ready() -> void:
	modulate.a = 1.0
	ServerRuntimeManager.set_chrome_visible(false)
	_load_menu_background()
	_start_hidden_menu_background()
	_hide_menu_overlay()
	print_verbose("")
	print_verbose("user data dir: " + OS.get_user_data_dir())
	%Start.pressed.connect(_on_start_pressed)
	%Load.pressed.connect(_on_load_pressed)
	%Gallery.pressed.connect(_on_gallery_pressed)
	%Help.pressed.connect(_on_help_pressed)
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
		%LoadGameOverlay.help_requested.connect(_on_help_pressed)
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.closed.connect(_on_settings_closed)
		%GalleryOverlay.help_requested.connect(_on_help_pressed)
	if has_node("%HelpOverlay"):
		%HelpOverlay.closed.connect(_on_settings_closed)
	_update_labels()
	_update_builder_mode_label()
	_check_first_time_overlay()
	if not bool(GameSettingsManager.settings.get("first_time", true)):
		MusicManager.play_random_mood("main_menu")
	_play_intro_sequence()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/brainstorm.tscn")


func _on_load_pressed() -> void:
	if has_node("%LoadGameOverlay"):
		%LoadGameOverlay.open()
		_update_main_menu_chrome_visibility()


func _on_gallery_pressed() -> void:
	if has_node("%GalleryOverlay"):
		%GalleryOverlay.open()
		_update_main_menu_chrome_visibility()


func _on_help_pressed() -> void:
	if has_node("%HelpOverlay"):
		%HelpOverlay.open()


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
	_update_builder_mode_label()
	_update_main_menu_chrome_visibility()


func _update_main_menu_chrome_visibility() -> void:
	var load_open: bool = has_node("%LoadGameOverlay") and %LoadGameOverlay.visible
	var gallery_open: bool = has_node("%GalleryOverlay") and %GalleryOverlay.visible
	ServerRuntimeManager.set_chrome_visible(load_open or gallery_open)


func _on_exit_pressed() -> void:
	await ServerRuntimeManager.request_app_quit()


func _check_first_time_overlay() -> void:
	if bool(GameSettingsManager.settings.get("first_time", true)):
		%FirstTimeLanguageOverlay.open()


func _on_first_time_language_selected(_lang: String) -> void:
	_update_labels()
	MusicManager.play_random_mood("main_menu")


func _update_labels() -> void:
	%Start.text = I18n.translate("main_btn_start")
	%Load.text = I18n.translate("main_btn_load")
	%Gallery.text = I18n.translate("main_btn_gallery")
	%Help.text = I18n.translate("main_btn_help")
	%Setting.text = I18n.translate("main_btn_game_setting")
	%AdvancedSetting.text = I18n.translate("main_btn_advanced_setting")
	%Exit.text = I18n.translate("main_btn_exit")


func _update_builder_mode_label() -> void:
	%BuilderModeLabel.visible = GameSettingsManager.is_builder_mode()


func _load_menu_background() -> void:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(MENU_BACKGROUND_PATH))
	if error != OK:
		push_warning("Failed to load trial menu background: %s" % error_string(error))
		return
	%MenuBackground.texture = ImageTexture.create_from_image(image)


func _start_hidden_menu_background() -> void:
	%MenuBackground.visible = false
	%MenuBackground.modulate.a = 0.0


func _play_intro_sequence() -> void:
	await get_tree().create_timer(BLACK_PRELOAD_SECONDS).timeout
	%MenuBackground.visible = true
	var tween := create_tween()
	tween.tween_property(%MenuBackground, "modulate:a", 1.0, FADE_IN_SECONDS)
	tween.finished.connect(_on_intro_fade_finished)
	_reveal_menu_overlay_after_delays()


func _on_intro_fade_finished() -> void:
	pass


func _hide_menu_overlay() -> void:
	for node in [%LeftGradient, %LogoGlow, %LogoOutline, %Logo, %PrimaryButtonGroup]:
		node.visible = true
		node.modulate.a = 0.0


func _reveal_menu_overlay_after_delays() -> void:
	await get_tree().create_timer(GRADIENT_REVEAL_DELAY).timeout
	_reveal_nodes([%LeftGradient, %LogoGlow, %LogoOutline, %Logo])
	await get_tree().create_timer(BUTTON_REVEAL_DELAY - GRADIENT_REVEAL_DELAY).timeout
	_reveal_nodes([%PrimaryButtonGroup])


func _reveal_nodes(nodes: Array) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for node in nodes:
		node.visible = true
		tween.tween_property(node, "modulate:a", 1.0, OVERLAY_REVEAL_SECONDS)
