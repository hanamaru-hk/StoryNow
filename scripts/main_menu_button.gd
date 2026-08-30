extends Button

const BUTTON_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 control_size = vec2(275.0, 90.0);
uniform vec4 background_top : source_color = vec4(0.06, 0.18, 0.45, 1.0);
uniform vec4 background_bottom : source_color = vec4(0.14, 0.35, 0.60, 1.0);
uniform vec4 decoration_color : source_color = vec4(1.0);
uniform float background_opacity : hint_range(0.0, 1.0) = 0.0;

float segment_distance(vec2 point, vec2 start, vec2 end) {
	vec2 start_to_point = point - start;
	vec2 start_to_end = end - start;
	float projection = clamp(dot(start_to_point, start_to_end) / dot(start_to_end, start_to_end), 0.0, 1.0);
	return length(start_to_point - start_to_end * projection);
}

void fragment() {
	vec2 point = UV * control_size;
	float panel_mask = step(54.0, point.x)
		* step(point.x, control_size.x - 6.0)
		* step(6.0, point.y)
		* step(point.y, control_size.y - 6.0);
	float gradient_position = clamp((point.y - 6.0) / (control_size.y - 12.0), 0.0, 1.0);
	vec4 panel_color = mix(background_top, background_bottom, gradient_position);
	panel_color.a = background_opacity * smoothstep(0.0, 1.0, gradient_position) * panel_mask;

	float circle_distance = length(point - vec2(28.0, 43.0)) - 19.0;
	float circle_mask = 1.0 - smoothstep(-1.0, 1.0, circle_distance);
	float diagonal_distance = segment_distance(point, vec2(40.0, 54.0), vec2(61.0, 75.0));
	float underline_distance = segment_distance(point, vec2(61.0, 75.0), vec2(control_size.x - 8.0, 75.0));
	float line_mask = 1.0 - smoothstep(2.6, 3.8, min(diagonal_distance, underline_distance));
	float decoration_mask = max(circle_mask, line_mask);

	vec4 result = panel_color;
	result = mix(result, decoration_color, decoration_mask * decoration_color.a);
	COLOR = result;
}
"""

const HOVER_TOP := Color(0.06, 0.18, 0.45, 1.0)
const HOVER_BOTTOM := Color("0b245a")
const PRESSED_TOP := Color("0b245a")
const PRESSED_BOTTOM := Color("061a43")
const DISABLED_TOP := Color("36465e")
const DISABLED_BOTTOM := Color("53677f")
const TEXT_COLOR := Color("ffffff")

@export var hover_font_size := 46

var _normal_font_size := 40
var _hovered := false
var _pressed := false
var _background_material: ShaderMaterial


func _ready() -> void:
	_normal_font_size = get_theme_font_size("font_size")
	flat = false
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_text_theme()
	_create_button_background()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	focus_entered.connect(_update_visual_state)
	focus_exited.connect(_update_visual_state)
	resized.connect(_sync_background_size)


func _apply_text_theme() -> void:
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_hover_color", TEXT_COLOR)
	add_theme_color_override("font_pressed_color", TEXT_COLOR)
	add_theme_color_override("font_focus_color", TEXT_COLOR)
	add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.52))
	add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.18, 0.5))
	add_theme_constant_override("outline_size", 1)
	var text_padding := StyleBoxEmpty.new()
	text_padding.content_margin_right = 12.0
	add_theme_stylebox_override("normal", text_padding)
	add_theme_stylebox_override("hover", text_padding)
	add_theme_stylebox_override("pressed", text_padding)
	add_theme_stylebox_override("disabled", text_padding)
	add_theme_stylebox_override("focus", text_padding)


func _create_button_background() -> void:
	var shader := Shader.new()
	shader.code = BUTTON_SHADER
	_background_material = ShaderMaterial.new()
	_background_material.shader = shader
	var background := ColorRect.new()
	background.name = "GraphicButtonBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.material = _background_material
	add_child(background)
	_sync_background_size()
	_update_visual_state()


func _sync_background_size() -> void:
	if is_instance_valid(_background_material):
		_background_material.set_shader_parameter("control_size", size)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	add_theme_font_size_override("font_size", hover_font_size if hovered else _normal_font_size)
	_update_visual_state()


func _set_pressed(pressed: bool) -> void:
	_pressed = pressed
	_update_visual_state()


func _update_visual_state() -> void:
	if not is_instance_valid(_background_material):
		return
	var top_color := HOVER_TOP
	var bottom_color := HOVER_BOTTOM
	var panel_opacity := 0.0
	var graphic_color := TEXT_COLOR
	if disabled:
		top_color = DISABLED_TOP
		bottom_color = DISABLED_BOTTOM
		panel_opacity = 0.30
		graphic_color = Color(TEXT_COLOR, 0.52)
	elif _pressed:
		top_color = PRESSED_TOP
		bottom_color = PRESSED_BOTTOM
		panel_opacity = 0.95
	elif _hovered or has_focus():
		panel_opacity = 0.85
	_background_material.set_shader_parameter("background_top", top_color)
	_background_material.set_shader_parameter("background_bottom", bottom_color)
	_background_material.set_shader_parameter("background_opacity", panel_opacity)
	_background_material.set_shader_parameter("decoration_color", graphic_color)
