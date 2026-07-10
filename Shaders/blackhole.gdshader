shader_type canvas_item;

uniform vec4 disk_color : source_color = vec4(0.6, 0.1, 1.0, 1.0);
uniform float rotation_speed = 5.0;

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);
    
    // 核心 (黑洞)
    float core = smoothstep(0.25, 0.27, dist);
    
    // 吸積盤 (螺旋)
    float spiral = sin(angle * 4.0 - dist * 15.0 + TIME * rotation_speed);
    float disk_intensity = smoothstep(0.48, 0.27, dist) * (spiral * 0.4 + 0.6) * 1.5;
    
    vec4 color = mix(vec4(0.0, 0.0, 0.0, 1.0), disk_color * disk_intensity, core);
    
    // 邊緣淡出
    color.a = smoothstep(0.5, 0.45, dist);
    
    // 確保核心絕對不透明
    if (dist < 0.26) {
        color.a = 1.0;
    }
    
    COLOR = color;
}
