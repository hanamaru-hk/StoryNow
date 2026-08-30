extends Control
## Large outlined arrow directing attention to the top-right engine indicators.

const ARROW_COLOR := Color(1.0, 0.78, 0.2, 1.0)
const OUTLINE_COLOR := Color(0.08, 0.08, 0.1, 1.0)
const SHAFT_WIDTH := 30.0
const OUTLINE_WIDTH := 48.0


func _draw() -> void:
	var start := Vector2(30.0, size.y - 30.0)
	var tip := Vector2(size.x - 24.0, 24.0)
	var head_left := Vector2(tip.x - 108.0, tip.y + 12.0)
	var head_down := Vector2(tip.x - 12.0, tip.y + 108.0)
	_draw_arrow_lines(start, tip, head_left, head_down, OUTLINE_COLOR, OUTLINE_WIDTH)
	_draw_arrow_lines(start, tip, head_left, head_down, ARROW_COLOR, SHAFT_WIDTH)


func _draw_arrow_lines(
	start: Vector2,
	tip: Vector2,
	head_left: Vector2,
	head_down: Vector2,
	color: Color,
	width: float
) -> void:
	draw_line(start, tip, color, width, true)
	draw_line(tip, head_left, color, width, true)
	draw_line(tip, head_down, color, width, true)
