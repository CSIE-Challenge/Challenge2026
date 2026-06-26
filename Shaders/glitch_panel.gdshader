shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform float edge_softness : hint_range(0.0, 1.0) = 0.2;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float glitch_speed : hint_range(0.0, 20.0) = 10.0;
uniform float glitch_active : hint_range(0.0, 1.0) = 1.0; // 0 = 關閉錯位, 1 = 開啟錯位

float rand(vec2 n) { 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float time_val = floor(TIME * glitch_speed);
    
    // 建立水平切割條帶
    float band = floor(uv.y * 15.0);
    float noise = rand(vec2(band, time_val));
    
    vec2 offset = vec2(0.0);
    if (noise > 0.9) { 
        offset.x = (rand(vec2(band, time_val + 1.0)) - 0.5) * glitch_intensity * glitch_active;
    }
    
    vec2 distorted_uv = uv + offset;
    
    // 邊緣透明度計算 (距離中心的距離)
    vec2 dist = abs(distorted_uv - vec2(0.5)) * 2.0;
    
    float alpha_x = 1.0 - smoothstep(1.0 - edge_softness, 1.0, dist.x);
    float alpha_y = 1.0 - smoothstep(1.0 - edge_softness, 1.0, dist.y);
    float edge_alpha = alpha_x * alpha_y;
    
    // 色彩分離 (Chromatic Aberration) 模擬錯誤特效
    float r_noise = rand(vec2(band + 10.0, time_val));
    vec2 r_offset = vec2((r_noise - 0.5) * glitch_intensity * 0.5 * glitch_active, 0.0);
    
    float b_noise = rand(vec2(band - 10.0, time_val));
    vec2 b_offset = vec2((b_noise - 0.5) * glitch_intensity * 0.5 * glitch_active, 0.0);
    
    vec2 dist_r = abs((distorted_uv + r_offset) - vec2(0.5)) * 2.0;
    float r_alpha = (1.0 - smoothstep(1.0 - edge_softness, 1.0, dist_r.x)) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, dist_r.y));
    
    vec2 dist_b = abs((distorted_uv + b_offset) - vec2(0.5)) * 2.0;
    float b_alpha = (1.0 - smoothstep(1.0 - edge_softness, 1.0, dist_b.x)) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, dist_b.y));
    
    vec4 final_color = bg_color;
    final_color.r *= r_alpha;
    final_color.g *= edge_alpha;
    final_color.b *= b_alpha;
    
    final_color.a *= max(r_alpha, max(edge_alpha, b_alpha));
    
    // 超出邊界則直接透明
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
        final_color.a = 0.0;
    }
    
    COLOR = final_color;
}
