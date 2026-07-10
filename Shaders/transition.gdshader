shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float distortion : hint_range(-2.0, 2.0) = 0.0;     // 魚眼/拉伸扭曲強度
uniform float aberration : hint_range(0.0, 0.1) = 0.0;     // 紅藍錯位強度
uniform float mix_amount : hint_range(0.0, 1.0) = 0.0;     // 與次元背景色的融合度
uniform vec4 bg_color : source_color = vec4(0.08, 0.02, 0.15, 1.0); // 裂隙背景色 (深紫黑)

// 魚眼拉伸演算法
vec2 distort(vec2 uv, float k) {
    vec2 d = uv - 0.5;
    float r2 = dot(d, d);
    return 0.5 + d * (1.0 + k * r2);
}

void fragment() {
    vec2 uv = distort(SCREEN_UV, distortion);
    
    // 超出 UV 邊界的區域填充背景色
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = bg_color;
    } else {
        // 分離紅藍通道產生散光色差
        float r = texture(screen_texture, distort(SCREEN_UV + vec2(aberration, 0.0), distortion)).r;
        float g = texture(screen_texture, distort(SCREEN_UV, distortion)).g;
        float b = texture(screen_texture, distort(SCREEN_UV - vec2(aberration, 0.0), distortion)).b;
        
        vec4 screen_color = vec4(r, g, b, 1.0);
        COLOR = mix(screen_color, bg_color, mix_amount);
    }
}