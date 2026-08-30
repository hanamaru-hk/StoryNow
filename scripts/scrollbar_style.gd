class_name ScrollbarStyle
extends RefCounted

const WIDTH := 32.0
const TRACK_COLOR := Color(0.055, 0.05, 0.045, 0.92)
const GRABBER_COLOR := Color(0.68, 0.52, 0.22, 0.95)
const GRABBER_HOVER_COLOR := Color(0.86, 0.68, 0.31, 1.0)


static func apply(scroll_container: ScrollContainer) -> void:
	var scrollbar := scroll_container.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = WIDTH

	var track := StyleBoxFlat.new()
	track.bg_color = TRACK_COLOR
	track.corner_radius_top_left = 8
	track.corner_radius_top_right = 8
	track.corner_radius_bottom_left = 8
	track.corner_radius_bottom_right = 8
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)

	var grabber := _create_grabber(GRABBER_COLOR)
	var grabber_hover := _create_grabber(GRABBER_HOVER_COLOR)
	scrollbar.add_theme_stylebox_override("grabber", grabber)
	scrollbar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	scrollbar.add_theme_stylebox_override("grabber_pressed", grabber_hover)

	var up_arrow := _create_arrow_icon(true)
	var down_arrow := _create_arrow_icon(false)
	for state in ["decrement", "decrement_highlight", "decrement_pressed"]:
		scrollbar.add_theme_icon_override(state, up_arrow)
	for state in ["increment", "increment_highlight", "increment_pressed"]:
		scrollbar.add_theme_icon_override(state, down_arrow)


static func _create_grabber(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	return style


static func _create_arrow_icon(points_up: bool) -> Texture2D:
	var points := "9,17 16,7 23,17" if points_up else "9,7 16,17 23,7"
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'><path d='M%s Z' fill='#d9ad55'/></svg>" % points.replace(" ", " L")
	var image := Image.new()
	var error := image.load_svg_from_string(svg)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)
