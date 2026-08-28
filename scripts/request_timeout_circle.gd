extends Control

const TRACK_COLOR := Color(1, 1, 1, 0.22)
const LLM_COLOR := Color(0.45, 0.72, 1.0)
const IMAGE_COLOR := Color(1.0, 0.64, 0.34)
const SOUND_COLOR := Color(0.62, 0.9, 0.48)
const EXPIRED_COLOR := Color(0.95, 0.25, 0.25)
const SPINNER_ARC_RATIO := 0.68
const SPINNER_ROTATION_SPEED := TAU * 0.8

var request_item: Dictionary = {}
var spinner_kind := ""
var spinner_mode := false
var spinner_angle := -PI * 0.5


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(24, 24)
	set_process(true)


func set_request_item(item: Dictionary) -> void:
	spinner_mode = false
	request_item = item
	queue_redraw()


func set_spinner_kind(kind: String) -> void:
	spinner_mode = true
	spinner_kind = kind
	request_item = {}
	queue_redraw()


func _process(delta: float) -> void:
	if spinner_mode:
		spinner_angle = wrapf(spinner_angle + SPINNER_ROTATION_SPEED * delta, 0.0, TAU)
		queue_redraw()
	elif not request_item.is_empty():
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var width := 3.0
	draw_arc(center, radius, 0.0, TAU, 48, TRACK_COLOR, width, true)

	if spinner_mode:
		draw_arc(center, radius, spinner_angle, spinner_angle + TAU * SPINNER_ARC_RATIO, 48, _kind_color(spinner_kind), width, true)
		return

	var timeout := float(request_item.get("timeout_seconds", 1.0))
	var started_at := int(request_item.get("started_at_msec", Time.get_ticks_msec()))
	var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
	var remaining_ratio := clampf(1.0 - (elapsed / maxf(timeout, 0.001)), 0.0, 1.0)
	var color := EXPIRED_COLOR if remaining_ratio <= 0.0 else _kind_color(str(request_item.get("kind", "")))
	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * remaining_ratio
	draw_arc(center, radius, start_angle, end_angle, 48, color, width, true)


func _kind_color(kind: String) -> Color:
	if kind == "image":
		return IMAGE_COLOR
	if kind == "sound":
		return SOUND_COLOR
	return LLM_COLOR
