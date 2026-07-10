shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.5;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	
	// Scanlines & Blocky glitch
	float t = TIME * 10.0;
	float glitch_offset = 0.0;
	if (rand(vec2(t, uv.y)) > (1.0 - glitch_intensity * 0.1)) {
		glitch_offset = (rand(vec2(t, 1.0)) - 0.5) * 0.2 * glitch_intensity;
	}
	
	uv.x += glitch_offset;
	
	// Chromatic Aberration
	float ca = chromatic_aberration * 0.05;
	vec4 color_r = texture(TEXTURE, uv + vec2(ca, 0.0));
	vec4 color_g = texture(TEXTURE, uv);
	vec4 color_b = texture(TEXTURE, uv - vec2(ca, 0.0));
	
	vec4 tex_color = vec4(color_r.r, color_g.g, color_b.b, color_g.a);
	
	// Multiply by COLOR to preserve CanvasItem modulate
	vec4 final_color = tex_color * COLOR;
	
	// Create blocky noise for solid shapes to make glitch visible
	if (glitch_intensity > 0.1) {
		float block_noise = rand(floor(uv * 15.0) + vec2(t, 0.0));
		if (block_noise > 0.8) {
			final_color.rgb = vec3(1.0) - final_color.rgb; // invert color
		}
	}
	
	// Scanlines
	final_color.rgb *= 1.0 - (sin(uv.y * 100.0 + TIME * 50.0) * 0.1 * glitch_intensity);
	
	COLOR = final_color;
}
