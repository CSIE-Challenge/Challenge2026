shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float reverse_reveal : hint_range(0.0, 1.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.05;      // 波浪深度
uniform float wave_frequency : hint_range(1.0, 50.0) = 15.0;       // 波浪密集度
uniform float wave_speed = -5.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    if (UV.y > reveal)
        color.a = 0.0;
	if (UV.y < 1.0 - reverse_reveal)
		color.a = 0.0;
	float offset1 = sin(UV.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
	float offset2 = sin(UV.y * wave_frequency + TIME * wave_speed + PI) * wave_amplitude;

    float left_bound = offset1 + wave_amplitude;
    float right_bound = 1.0 - offset2 - wave_amplitude;

    float alpha_mask = step(left_bound, UV.x) * (1.0 - step(right_bound, UV.x));
	color.a *= alpha_mask;
    COLOR = color;
}