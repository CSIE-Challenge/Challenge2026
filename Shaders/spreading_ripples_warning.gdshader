shader_type canvas_item;

uniform vec4 warning_color : source_color = vec4(0.73, 0.2, 0.2, 1.0);

void fragment() {
	float circle = step(distance(UV, vec2(0.5, 0.5)), 0.5);
	float blink = (abs(sin(TIME * 5.0)) + 0.2) * circle;
	COLOR = vec4(warning_color.rgb, blink);
}