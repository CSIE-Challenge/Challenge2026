shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 0.8;
uniform vec4 tint_color: source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 blurred_texture = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = mix(blurred_texture, tint_color, tint_color.a);
	COLOR.a = texture(TEXTURE, UV).a;
}