shader_type canvas_item;

uniform float time;

uniform vec4 radar_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float radar_mul : hint_range(0.0, 1.0) = 1.0;
uniform float radar_speed : hint_range(0.1, 1.0) = 0.2;
uniform float tail_length : hint_range(0.1, 2.0) = 1.0;
uniform float division_lines : hint_range(0.0, 10.0) = 3.0;

uniform float progress : hint_range(0.0, 1.0) = 1.0; 
uniform float bg_brightness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    
    // calculate angle delta from position
    // (starts from top, clockwise)
    float angle = fract(atan(uv.y, uv.x) / TAU + 1.25);
    float current = fract(time * radar_speed);
    float angle_diff = fract(current - angle + 1.);
    
    // sweep
    float radar_sweep = pow(1.0 - angle_diff, tail_length * 5.0);

    // grid
    float circle_pattern = fract(dist * division_lines);
    float grid = smoothstep(0.95, 0.98, circle_pattern) * 0.3;
    
    float edge_fade = smoothstep(0.5, 0.48, dist);
    float final_intensity = (radar_sweep + grid) * edge_fade;
    
    vec4 back_color = vec4(radar_color.rgb, radar_color.a * final_intensity * radar_mul);
    
    vec4 tex_color = texture(TEXTURE, UV);    
    float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
    vec4 gray_color = vec4(gray) * bg_brightness;
    tex_color = mix(gray_color, tex_color, step(angle, progress));
    
    COLOR = mix(back_color, tex_color, tex_color.a);
}