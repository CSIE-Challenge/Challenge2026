shader_type canvas_item;

uniform float thickness : hint_range(0.01, 0.5) = 0.15;                   // 石柱本體寬度
uniform float noise_strength : hint_range(0.0, 1.0) = 0.4;                // 邊緣岩石起伏程度
uniform float noise_scale : hint_range(1.0, 50.0) = 15.0;                 // 岩石表面紋理精細度
uniform vec4 color : source_color = vec4(0.65, 0.58, 0.31, 1.0);          // 石塊基礎顏色 (與關卡牆壁顏色相同)
uniform float color_variation : hint_range(0.0, 1.0) = 0.25;              // 色澤明暗變化幅度
uniform int color_bands = 3;                                              // 色帶分層數 (卡通色塊渲染風格)
uniform float offset = 0.0;                                               // 紋理位移值

// 堆疊石塊刻痕參數
uniform float blocks_count = 8.0;                                         // 垂直方向堆疊的石塊數量
uniform float crack_width : hint_range(0.0, 0.1) = 0.03;                  // 石塊與石塊間縫隙的寬度

// 沿用 walls (bounds.gdshader) 的隨機演算法
float rand(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 沿用 walls (bounds.gdshader) 的 2D 雜訊演算法
float noise(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment(){
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 p = uv - center;

	// 1. 利用與 bounds.gdshader 相同的雜訊扭曲 X 軸，製造凹凸不平的粗糙岩石邊緣
	float n = noise(uv * noise_scale + vec2(0.0, offset));
	float distorted_x = p.x + (n - 0.5) * noise_strength * 0.1;
	
	// 判斷是否在石牆柱體寬度內
	float is_pillar = abs(distorted_x) <= thickness ? 1.0 : 0.0;

	// 2. 模擬堆疊石塊 (Bricks) 的橫向接縫裂紋 (Cracks)
	// 利用雜訊讓接縫裂紋產生波浪起伏，顯得更自然不規則
	float crack_noise = noise(vec2(uv.x * 6.0, uv.y * 2.0));
	float crack_y = fract(uv.y * blocks_count + (crack_noise - 0.5) * 0.15);
	
	// 當 Y 座標接近石塊上下邊緣時，判定為接縫處
	float is_crack = (crack_y < crack_width || crack_y > (1.0 - crack_width)) ? 1.0 : 0.0;

	// 3. 沿用 bounds.gdshader 的色帶層次渲染 (Cell shading)，產生岩石特有的石面質地
	float n_bands = floor(n * float(color_bands)) / float(max(color_bands - 1, 1));
	vec3 rock_color = color.rgb * (1.0 - color_variation + color_variation * n_bands);

	// 對石塊接縫裂紋進行加深處理 (模擬遮蔽陰影 Ambient Occlusion)
	rock_color = mix(rock_color, rock_color * 0.35, is_crack);

	// 4. 設定透明度
	float alpha = is_pillar;
	// 讓縫隙處稍微呈現深陷透空感
	alpha = mix(alpha, alpha * 0.7, is_crack);

	// 5. 上下邊緣淡出，避免邊界生硬
	float edge_fade = smoothstep(0.0, 0.02, uv.y) * smoothstep(1.0, 0.98, uv.y);
	alpha *= edge_fade;

	COLOR = vec4(rock_color, alpha);
}
