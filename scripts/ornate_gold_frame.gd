class_name OrnateGoldFrame
extends Container

@export var background_color := Color(0.08, 0.08, 0.1, 0.75)
@export var frame_color := Color(0.82, 0.66, 0.28, 1.0)
@export var draw_background := true
@export_range(4.0, 32.0, 1.0) var corner_size := 14.0
@export_range(2.0, 8.0, 1.0) var inner_inset := 4.0
@export_range(0.0, 96.0, 1.0) var frame_padding := 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var frame_rect := Rect2(
		Vector2(-frame_padding, -frame_padding),
		size + Vector2(frame_padding * 2.0, frame_padding * 2.0)
	)
	if frame_rect.size.x < 16.0 or frame_rect.size.y < 16.0:
		return

	var cut := minf(corner_size, minf(frame_rect.size.x, frame_rect.size.y) * 0.25)
	var outer := _frame_points(frame_rect, 1.0, cut)
	if draw_background:
		draw_colored_polygon(outer, background_color)
	_draw_closed_line(outer, frame_color, 1.5)

	var inset := minf(inner_inset, cut * 0.45)
	var inner := _frame_points(frame_rect, inset, maxf(2.0, cut - inset))
	_draw_closed_line(inner, frame_color.darkened(0.18), 1.0)

	for horizontal_sign in [-1.0, 1.0]:
		for vertical_sign in [-1.0, 1.0]:
			_draw_corner_details(frame_rect, cut, horizontal_sign, vertical_sign)


func _frame_points(frame_rect: Rect2, inset: float, cut: float) -> PackedVector2Array:
	var left := frame_rect.position.x
	var top := frame_rect.position.y
	var right := frame_rect.end.x
	var bottom := frame_rect.end.y
	return PackedVector2Array([
		Vector2(left + inset + cut, top + inset),
		Vector2(right - inset - cut, top + inset),
		Vector2(right - inset, top + inset + cut),
		Vector2(right - inset, bottom - inset - cut),
		Vector2(right - inset - cut, bottom - inset),
		Vector2(left + inset + cut, bottom - inset),
		Vector2(left + inset, bottom - inset - cut),
		Vector2(left + inset, top + inset + cut),
	])


func _draw_closed_line(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed_points := points.duplicate()
	closed_points.append(points[0])
	draw_polyline(closed_points, color, width, true)


func _draw_corner_details(frame_rect: Rect2, cut: float, horizontal_sign: float, vertical_sign: float) -> void:
	var detail_length := clampf(cut * 0.55, 3.0, 9.0)
	var top_start := _corner_point(frame_rect, Vector2(cut + 3.0, 4.0), horizontal_sign, vertical_sign)
	var top_end := _corner_point(frame_rect, Vector2(cut + 3.0 + detail_length, 4.0), horizontal_sign, vertical_sign)
	var side_start := _corner_point(frame_rect, Vector2(4.0, cut + 3.0), horizontal_sign, vertical_sign)
	var side_end := _corner_point(frame_rect, Vector2(4.0, cut + 3.0 + detail_length), horizontal_sign, vertical_sign)
	draw_line(top_start, top_end, frame_color, 1.0, true)
	draw_line(side_start, side_end, frame_color, 1.0, true)

	var diagonal_start := _corner_point(frame_rect, Vector2(3.0, cut), horizontal_sign, vertical_sign)
	var diagonal_end := _corner_point(frame_rect, Vector2(cut, 3.0), horizontal_sign, vertical_sign)
	draw_line(diagonal_start, diagonal_end, frame_color.lightened(0.16), 1.0, true)


func _corner_point(frame_rect: Rect2, point: Vector2, horizontal_sign: float, vertical_sign: float) -> Vector2:
	return Vector2(
		frame_rect.position.x + point.x if horizontal_sign < 0.0 else frame_rect.end.x - point.x,
		frame_rect.position.y + point.y if vertical_sign < 0.0 else frame_rect.end.y - point.y
	)
