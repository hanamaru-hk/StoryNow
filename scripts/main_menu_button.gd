extends Button

@export var hover_font_size := 96
@export var underline_gap := 10.0
@export var underline_thickness := 4.0

var _normal_font_size := 80
var _hovered := false


func _ready() -> void:
	_normal_font_size = get_theme_font_size("font_size")
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(queue_redraw)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	add_theme_font_size_override("font_size", hover_font_size if hovered else _normal_font_size)
	queue_redraw()


func _draw() -> void:
	if not _hovered:
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var underline_x := 0.0
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			underline_x = (size.x - text_size.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			underline_x = size.x - text_size.x
	var text_top := (size.y - text_size.y) * 0.5
	var underline_y := minf(size.y - underline_thickness * 0.5, text_top + text_size.y + underline_gap)
	draw_line(
		Vector2(underline_x, underline_y),
		Vector2(underline_x + text_size.x, underline_y),
		get_theme_color("font_hover_color"),
		underline_thickness,
		true
	)
