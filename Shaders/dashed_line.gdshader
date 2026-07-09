shader_type canvas_item;
uniform vec4 line_color: source_color;
uniform float speed = 3.0;

void fragment() {
	vec2 moving_uv = vec2(UV.x - TIME * speed, UV.y);
	vec4 tex = texture(TEXTURE, moving_uv);
	tex.rgb = line_color.rgb;
	COLOR = tex;
}
