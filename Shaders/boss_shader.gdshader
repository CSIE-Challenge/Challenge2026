shader_type canvas_item;

uniform float side_glow_intensity : hint_range(0.0, 5.0) = 0.2;
uniform float breathing_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float breathing_speed : hint_range(0.0, 10.0) = 3.0;
uniform float hit_flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 50.0) = 0.0;

void fragment() {
    // 1. Vortex / Swirl distortion around the center (0.5, 0.5)
    vec2 uv = UV - vec2(0.5);
    if (distortion_strength > 0.0) {
        float dist = length(uv);
        float angle = distortion_strength * (1.0 - dist);
        float s = sin(angle);
        float c = cos(angle);
        uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
    }
    uv += vec2(0.5);
    
    // 2. Sample texture safely (transparent outside texture bounds if twisted)
    vec4 tex_color = vec4(0.0);
    if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
        tex_color = texture(TEXTURE, uv);
    }
    
    // 3. Side glow (make left/right sides brighter)
    float dist_x = abs(uv.x - 0.5) * 2.0;
    vec3 color_boost = tex_color.rgb * (1.0 + side_glow_intensity * pow(dist_x, 2.0));
    
    // 4. Brightness changes (idle breathing)
    float breathing = sin(TIME * breathing_speed) * breathing_intensity;
    vec3 final_rgb = color_boost * (1.0 + breathing);
    
    // 5. Hit flashing (blend to bright red)
    vec3 flash_color = vec3(1.0, 0.0, 0.0);
    final_rgb = mix(final_rgb, flash_color, hit_flash_strength);
    
    COLOR = vec4(final_rgb, tex_color.a) * COLOR;
}
