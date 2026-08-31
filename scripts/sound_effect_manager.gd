extends Node

const HOVER_SOUND := preload("res://assets/sound_effect/hover.mp3")
const CLICK_SOUND := preload("res://assets/sound_effect/click.mp3")

var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _muted := false


func _ready() -> void:
	_hover_player = _create_player("ButtonHoverPlayer", HOVER_SOUND)
	_click_player = _create_player("ButtonClickPlayer", CLICK_SOUND)
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in(get_tree().root)
	GameSettingsManager.sound_effect_settings_changed.connect(_apply_settings)
	_apply_settings()


func _create_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	return player


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)


func _connect_buttons_in(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child in node.get_children():
		_connect_buttons_in(child)


func _connect_button(button: BaseButton) -> void:
	var hover_callback := _on_button_mouse_entered.bind(button)
	if not button.mouse_entered.is_connected(hover_callback):
		button.mouse_entered.connect(hover_callback)
	var click_callback := _on_button_pressed.bind(button)
	if not button.pressed.is_connected(click_callback):
		button.pressed.connect(click_callback)


func _on_button_mouse_entered(button: BaseButton) -> void:
	if not button.disabled:
		_play(_hover_player)


func _on_button_pressed(button: BaseButton) -> void:
	if not button.disabled:
		_play(_click_player)


func _play(player: AudioStreamPlayer) -> void:
	if _muted:
		return
	player.play()


func _apply_settings() -> void:
	_muted = bool(GameSettingsManager.settings.get("sound_effect_muted", false))
	var volume_percent := clampi(int(GameSettingsManager.settings.get("sound_effect_volume", 70)), 0, 100)
	var volume_db := linear_to_db(float(volume_percent) / 100.0) if volume_percent > 0 else -80.0
	_hover_player.volume_db = volume_db
	_click_player.volume_db = volume_db
	if _muted:
		_hover_player.stop()
		_click_player.stop()
