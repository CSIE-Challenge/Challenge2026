shader_type canvas_item;

uniform float time_scale = 1.0;
// 宇宙深空底色
uniform vec4 base_color : source_color = vec4(0.02, 0.01, 0.05, 1.0);
// 星雲發光顏色
uniform vec4 glow_color : source_color = vec4(0.2, 0.05, 0.4, 1.0);
// 繁星顏色
uniform vec4 star_color : source_color = vec4(0.9, 0.9, 1.0, 1.0);

// 簡單的雜湊函數
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 基礎雜訊
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 分形布朗運動 (FBM)
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    // 將座標系統依照螢幕長寬比稍微調整，避免拉伸
    vec2 uv = UV;
    
    // 讓整片星空與星雲一起非常緩慢地移動 (往右上角漂移)
    uv.x += TIME * 0.005 * time_scale;
    uv.y -= TIME * 0.01 * time_scale;
    
    // 動態流體星雲
    vec2 p = uv * 1.5; // 降低空間頻率，讓星雲顯得更大更柔和
    float t = TIME * 0.05 * time_scale; // 降低改變速度
    float n1 = fbm(p + vec2(t, t));
    float n2 = fbm(p + vec2(-t, t * 0.5) + n1 * 2.0);
    float n3 = fbm(p + vec2(t * 0.3, -t * 0.8) + n2 * 2.0);
    
    // 混合深空與星雲
    vec4 plasma = mix(base_color, glow_color, n3 * 1.5);
    
    // 動態閃爍的星星：將畫面切割成網格來畫圓
    vec2 st = uv * 40.0; // 調整星空的縮放比例
    vec2 id = floor(st);
    vec2 f = fract(st) - 0.5;
    
    float r1 = hash(id);
    float r2 = hash(id * 12.34);
    float r3 = hash(id * 56.78);
    
    // 讓星星在格子內產生隨機偏移，才不會看起來像整齊的陣列
    vec2 offset = vec2(r1 - 0.5, r2 - 0.5) * 0.7;
    float d = length(f - offset);
    
    // 大小不一：根據亂數決定圓的半徑
    float radius = mix(0.03, 0.08, r3);
    
    // 畫出圓形，具有一點柔邊的光暈感
    float star_shape = smoothstep(radius, radius * 0.2, d);
    
    // 密度控制：藉由 step 函數，只有 r1 大於 0.9 才顯示星星 (降低密度)
    float density = step(0.92, r1); 
    
    // 一點點的色差：在淡藍色與淡粉色之間做隨機混合
    vec4 color_var = mix(vec4(0.7, 0.9, 1.0, 1.0), vec4(1.0, 0.8, 0.9, 1.0), r2);
    
    // 加上不同方向的空間漸變閃爍 (利用網格 id 製造大範圍波浪，頻率極慢)
    float twinkle = 0.5 + 0.5 * sin(TIME * 0.5 + id.x * 0.15 - id.y * 0.1 + r3 * 10.0);
    
    vec4 star_fx = color_var * star_shape * density * twinkle * 2.0;
    
    COLOR = plasma + star_fx;
}
