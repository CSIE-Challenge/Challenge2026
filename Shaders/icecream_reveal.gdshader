shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 reveal_center = vec2(0.5, 0.5);
uniform float liquid_intensity : hint_range(0.0, 0.5) = 0.1;
uniform float liquid_scale : hint_range(1.0, 50.0) = 20.0;

uniform vec4 outline_color : source_color;
uniform float outline_width;

float noise(vec2 coord) {
	return fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 coord) {
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(noise(i + vec2(0.0, 0.0)), noise(i + vec2(1.0, 0.0)), u.x),
			   mix(noise(i + vec2(0.0, 1.0)), noise(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float max_radius = 1.42; // 1.414 for corner coverage
	float liquid_speed = 2.0;

	// texture distortion coords
	vec2 wobble_offset = vec2(
		value_noise(UV * (liquid_scale * 0.5) + vec2(TIME * liquid_speed, 0.0)),
		value_noise(UV * (liquid_scale * 0.5) + vec2(0.0, TIME * liquid_speed))
	) - 0.5;

	vec2 distorted_uv = UV + (wobble_offset * (liquid_intensity * 0.3) * progress);
	vec4 tex_color = texture(TEXTURE, distorted_uv);

	// squiggly reveal mask
	float dist = distance(UV, reveal_center);
	float squiggly_noise = value_noise((UV * liquid_scale) + vec2(TIME * 0.5));

	// fallof to remove edge islands
	float falloff = clamp(1.0 - (dist / max_radius), 0.0, 1.0);
	float active_distortion = liquid_intensity * falloff;

	float warped_dist = dist + (squiggly_noise - 0.5) * active_distortion;
	float alpha_mask = 1.0 - step(progress * max_radius, warped_dist);
	
	COLOR = vec4(tex_color.rgb, tex_color.a * alpha_mask);
	
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	float alpha = tex_color.a;
	alpha += texture(TEXTURE, distorted_uv + vec2(0.0, size.y)).a;  
	alpha += texture(TEXTURE, distorted_uv - vec2(0.0, size.y)).a;  
	alpha += texture(TEXTURE, distorted_uv - vec2(size.x, 0.0)).a;  
	alpha += texture(TEXTURE, distorted_uv + vec2(size.x, 0.0)).a;  

	vec4 final_color = mix(outline_color, tex_color, tex_color.a * alpha_mask);
	final_color.a = clamp(alpha * alpha_mask, 0.0, 1.0);
	
	COLOR = final_color;
}
