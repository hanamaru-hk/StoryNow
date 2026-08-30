extends Button

const BUTTON_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 control_size = vec2(375.0, 90.0);
uniform vec4 gradient_top : source_color = vec4(0.69, 0.82, 1.0, 1.0);
uniform vec4 gradient_bottom : source_color = vec4(0.55, 0.71, 0.95, 1.0);
uniform vec4 border_color : source_color = vec4(0.51, 0.60, 0.72, 1.0);
uniform vec4 inner_border_color : source_color = vec4(0.85, 0.91, 1.0, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.20, 0.27, 0.38, 0.32);
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.85;

float rounded_box_sdf(vec2 point, vec2 half_size, float radius) {
	vec2 distance_to_corner = abs(point) - half_size + vec2(radius);
	return min(max(distance_to_corner.x, distance_to_corner.y), 0.0)
		+ length(max(distance_to_corner, vec2(0.0))) - radius;
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * control_size + vec2(0.0, 2.0);
	vec2 half_size = control_size * 0.5 - vec2(5.0, 8.0);
	float radius = min(half_size.y, 16.0);
	float button_distance = rounded_box_sdf(point, half_size, radius);
	float shadow_distance = rounded_box_sdf(point - vec2(0.0, 4.0), half_size, radius);

	float button_mask = 1.0 - smoothstep(-1.0, 1.0, button_distance);
	float inner_border_mask = 1.0 - smoothstep(-0.8, 0.8, button_distance + 3.0);
	float fill_mask = 1.0 - smoothstep(-0.8, 0.8, button_distance + 6.0);
	float shadow_mask = (1.0 - smoothstep(-1.0, 4.0, shadow_distance)) * (1.0 - button_mask);

	float gradient_position = clamp((point.y + half_size.y) / (half_size.y * 2.0), 0.0, 1.0);
	vec4 fill_color = mix(gradient_top, gradient_bottom, gradient_position);
	float top_gloss = (1.0 - smoothstep(0.08, 0.52, UV.y)) * 0.16;
	fill_color.rgb = mix(fill_color.rgb, vec3(1.0), top_gloss);
	fill_color.a *= fill_opacity;

	vec4 button_color = mix(border_color, inner_border_color, inner_border_mask);
	button_color = mix(button_color, fill_color, fill_mask);
	vec4 result = shadow_color * shadow_mask;
	result = mix(result, button_color, button_mask);
	COLOR = result;
}
"""

const NORMAL_TOP := Color(0.06, 0.18, 0.45, 1.0)
const NORMAL_BOTTOM := Color("24599a")
const NORMAL_BORDER := Color("8298b9")
const NORMAL_INNER_BORDER := Color("d8e8ff")
const HOVER_TOP := Color("21488a")
const HOVER_BOTTOM := Color("3970b1")
const HOVER_BORDER := Color("7196c9")
const HOVER_INNER_BORDER := Color("edf6ff")
const PRESSED_TOP := Color("0b245a")
const PRESSED_BOTTOM := Color("173f79")
const PRESSED_BORDER := Color("587bad")
const PRESSED_INNER_BORDER := Color("bdd5f3")
const DISABLED_TOP := Color("c2ccd9")
const DISABLED_BOTTOM := Color("a8b4c5")
const DISABLED_BORDER := Color("8994a3")
const DISABLED_INNER_BORDER := Color("d8dde5")
const TEXT_COLOR := Color("ffffff")

@export var hover_font_size := 43

var _normal_font_size := 40
var _hovered := false
var _pressed := false
var _background_material: ShaderMaterial


func _ready() -> void:
	_normal_font_size = get_theme_font_size("font_size")
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_text_theme()
	_create_button_background()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	focus_entered.connect(_update_background_colors)
	focus_exited.connect(_update_background_colors)
	resized.connect(_sync_background_size)


func _apply_text_theme() -> void:
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_hover_color", TEXT_COLOR)
	add_theme_color_override("font_pressed_color", TEXT_COLOR)
	add_theme_color_override("font_focus_color", TEXT_COLOR)
	add_theme_color_override("font_disabled_color", Color(TEXT_COLOR, 0.58))
	add_theme_color_override("font_outline_color", Color(0.18, 0.35, 0.58, 0.38))
	add_theme_constant_override("outline_size", 1)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _create_button_background() -> void:
	var shader := Shader.new()
	shader.code = BUTTON_SHADER
	_background_material = ShaderMaterial.new()
	_background_material.shader = shader
	var background := ColorRect.new()
	background.name = "BlueButtonBackground"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.material = _background_material
	add_child(background)
	_sync_background_size()
	_update_background_colors()


func _sync_background_size() -> void:
	if is_instance_valid(_background_material):
		_background_material.set_shader_parameter("control_size", size)


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	add_theme_font_size_override("font_size", hover_font_size if hovered else _normal_font_size)
	_update_background_colors()


func _set_pressed(pressed: bool) -> void:
	_pressed = pressed
	_update_background_colors()


func _update_background_colors() -> void:
	if not is_instance_valid(_background_material):
		return
	var top_color := NORMAL_TOP
	var bottom_color := NORMAL_BOTTOM
	var outline_color := NORMAL_BORDER
	var inner_outline_color := NORMAL_INNER_BORDER
	if disabled:
		top_color = DISABLED_TOP
		bottom_color = DISABLED_BOTTOM
		outline_color = DISABLED_BORDER
		inner_outline_color = DISABLED_INNER_BORDER
	elif _pressed:
		top_color = PRESSED_TOP
		bottom_color = PRESSED_BOTTOM
		outline_color = PRESSED_BORDER
		inner_outline_color = PRESSED_INNER_BORDER
	elif _hovered or has_focus():
		top_color = HOVER_TOP
		bottom_color = HOVER_BOTTOM
		outline_color = HOVER_BORDER
		inner_outline_color = HOVER_INNER_BORDER
	_background_material.set_shader_parameter("gradient_top", top_color)
	_background_material.set_shader_parameter("gradient_bottom", bottom_color)
	_background_material.set_shader_parameter("border_color", outline_color)
	_background_material.set_shader_parameter("inner_border_color", inner_outline_color)
