extends Control
## Large outlined arrow directing attention to the top-right engine indicators.

const ARROW_COLOR := Color(1.0, 0.78, 0.2, 1.0)
const OUTLINE_COLOR := Color(0.08, 0.08, 0.1, 1.0)
const SHAFT_WIDTH := 30.0
const OUTLINE_WIDTH := 48.0
const HEAD_LENGTH := 112.0
const HEAD_WIDTH := 152.0
const OUTLINE_PADDING := 10.0


func _draw() -> void:
	var start := Vector2(30.0, size.y - 30.0)
	var tip := Vector2(size.x - 24.0, 24.0)
	var direction := start.direction_to(tip)
	var outline_points := _make_arrow_polygon(
		start - direction * OUTLINE_PADDING,
		tip + direction * OUTLINE_PADDING,
		OUTLINE_WIDTH,
		HEAD_LENGTH + OUTLINE_PADDING * 2.0,
		HEAD_WIDTH + OUTLINE_PADDING * 2.0
	)
	var fill_points := _make_arrow_polygon(start, tip, SHAFT_WIDTH, HEAD_LENGTH, HEAD_WIDTH)
	draw_colored_polygon(outline_points, OUTLINE_COLOR)
	draw_colored_polygon(fill_points, ARROW_COLOR)


func _make_arrow_polygon(
	start: Vector2,
	tip: Vector2,
	shaft_width: float,
	head_length: float,
	head_width: float
) -> PackedVector2Array:
	var direction := start.direction_to(tip)
	var normal := Vector2(-direction.y, direction.x)
	var neck := tip - direction * head_length
	var shaft_half := shaft_width * 0.5
	var head_half := head_width * 0.5
	return PackedVector2Array([
		start + normal * shaft_half,
		neck + normal * shaft_half,
		neck + normal * head_half,
		tip,
		neck - normal * head_half,
		neck - normal * shaft_half,
		start - normal * shaft_half,
	])
