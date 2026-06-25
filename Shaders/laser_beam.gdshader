shader_type canvas_item;

// ⚡ 雷射 Shader 控制參數 (可在 Line2D 的 Material 屬性中微調)
uniform float noise_strength : hint_range(0.0, 0.3) = 0.08; // 電流抖動強度
uniform float speed = 15.0;                                // 波動流動速度
uniform float core_thickness : hint_range(0.0, 0.2) = 0.06; // 白色高能核心粗細
uniform float glow_thickness : hint_range(0.1, 0.6) = 0.45; // 彩色光暈粗細

// 與 electric_ring 同源的隨機函數
float rand(vec2 p){
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

// 2D 雙線性插值雜訊，用於平滑電流波動
float noise(vec2 p){
    vec2 i=floor(p);
    vec2 f=fract(p);

    float a=rand(i);
    float b=rand(i+vec2(1,0));
    float c=rand(i+vec2(0,1));
    float d=rand(i+vec2(1,1));

    vec2 u=f*f*(3.0-2.0*f);

    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}

void fragment(){
    // 1. 計算 Y 軸到中心線 (0.5) 的距離
    float dist = abs(UV.y - 0.5);
    
    // 2. 引入 Noise 電能擾動，讓雷射的寬度隨時間與長度起伏
    float n = noise(vec2(UV.x * 12.0 - TIME * speed, TIME * speed * 0.5));
    dist += (n - 0.5) * noise_strength;
    
    // 3. 繪製內側白色核心 (Core) 與 外圍光暈 (Glow)
    float core = smoothstep(core_thickness, 0.0, dist);
    float glow = smoothstep(glow_thickness, 0.0, dist);
    
    // 混合基底顏色與白色能量核心
    vec3 base_color = vec3(1.0, 1.0, 1.0); 
    vec3 final_color = mix(base_color, vec3(2.5, 2.5, 2.5), core * 0.95); // 核心提亮
    
    // 4. 乘上 Canvas Item 的 Modulate 顏色，以便在 GDScript 中動態控制顏色和淡入淡出
    COLOR = vec4(final_color, glow) * COLOR;
}