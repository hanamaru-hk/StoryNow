extends Control

const TRACK_COLOR := Color(1, 1, 1, 0.22)
const LLM_COLOR := Color(0.45, 0.72, 1.0)
const IMAGE_COLOR := Color(1.0, 0.64, 0.34)
const EXPIRED_COLOR := Color(0.95, 0.25, 0.25)

var request_item: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(24, 24)
	set_process(true)


func set_request_item(item: Dictionary) -> void:
	request_item = item
	queue_redraw()


func _process(_delta: float) -> void:
	if not request_item.is_empty():
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	var width := 3.0
	draw_arc(center, radius, 0.0, TAU, 48, TRACK_COLOR, width, true)

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
	return LLM_COLOR
