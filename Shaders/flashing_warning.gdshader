shader_type canvas_item;

uniform float frequency : hint_range(0.0, 5.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
	float mult = sin(TIME * frequency) * 0.5 + 0.5;
    COLOR = vec4(tex_color.rgb, tex_color.a * mult);
}
