class_name OrnateGoldFrame
extends PanelContainer

@export var background_color := Color(0.08, 0.08, 0.1, 0.75)
@export var frame_color := Color(0.82, 0.66, 0.28, 1.0)
@export_range(4.0, 32.0, 1.0) var corner_size := 14.0
@export_range(2.0, 8.0, 1.0) var inner_inset := 4.0


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return

	var cut := minf(corner_size, minf(size.x, size.y) * 0.25)
	var outer := _frame_points(1.0, cut)
	draw_colored_polygon(outer, background_color)
	_draw_closed_line(outer, frame_color, 1.5)

	var inset := minf(inner_inset, cut * 0.45)
	var inner := _frame_points(inset, maxf(2.0, cut - inset))
	_draw_closed_line(inner, frame_color.darkened(0.18), 1.0)

	for horizontal_sign in [-1.0, 1.0]:
		for vertical_sign in [-1.0, 1.0]:
			_draw_corner_details(cut, horizontal_sign, vertical_sign)


func _frame_points(inset: float, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(inset + cut, inset),
		Vector2(size.x - inset - cut, inset),
		Vector2(size.x - inset, inset + cut),
		Vector2(size.x - inset, size.y - inset - cut),
		Vector2(size.x - inset - cut, size.y - inset),
		Vector2(inset + cut, size.y - inset),
		Vector2(inset, size.y - inset - cut),
		Vector2(inset, inset + cut),
	])


func _draw_closed_line(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, width, true)


func _draw_corner_details(cut: float, horizontal_sign: float, vertical_sign: float) -> void:
	var detail_length := clampf(cut * 0.55, 3.0, 9.0)
	var top_start := _corner_point(Vector2(cut + 3.0, 4.0), horizontal_sign, vertical_sign)
	var top_end := _corner_point(Vector2(cut + 3.0 + detail_length, 4.0), horizontal_sign, vertical_sign)
	var side_start := _corner_point(Vector2(4.0, cut + 3.0), horizontal_sign, vertical_sign)
	var side_end := _corner_point(Vector2(4.0, cut + 3.0 + detail_length), horizontal_sign, vertical_sign)
	draw_line(top_start, top_end, frame_color, 1.0, true)
	draw_line(side_start, side_end, frame_color, 1.0, true)

	var diagonal_start := _corner_point(Vector2(3.0, cut), horizontal_sign, vertical_sign)
	var diagonal_end := _corner_point(Vector2(cut, 3.0), horizontal_sign, vertical_sign)
	draw_line(diagonal_start, diagonal_end, frame_color.lightened(0.16), 1.0, true)


func _corner_point(point: Vector2, horizontal_sign: float, vertical_sign: float) -> Vector2:
	return Vector2(
		point.x if horizontal_sign < 0.0 else size.x - point.x,
		point.y if vertical_sign < 0.0 else size.y - point.y
	)
