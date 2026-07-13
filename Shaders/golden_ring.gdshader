shader_type canvas_item;

uniform float outer_radius : hint_range(0.0, 1.0) = 0.5;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.4;
uniform vec4 ring_color : source_color = vec4(1.0, 0.8, 0.2, 0.8);
uniform float shine_speed = 3.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    
    // 1. 計算環狀遮罩 (Ring Mask)
    float alpha_outer = 1.0 - smoothstep(outer_radius - 0.02, outer_radius, dist);
    float alpha_inner = smoothstep(inner_radius, inner_radius + 0.02, dist);
    float ring_alpha = alpha_outer * alpha_inner;
    
    // 2. 空間扭曲效果 (Distortion/Refraction)
    // 沿著圓心向外的方向偏移 SCREEN_UV，創造氣壓波紋般的透鏡折射
    vec2 dir = (dist > 0.0) ? normalize(uv) : vec2(0.0);
    vec2 distortion_offset = dir * ring_alpha * 0.015; // 0.015 為折射強度
    vec4 screen_col = texture(screen_texture, SCREEN_UV - distortion_offset);
    
    // 3. 加上與本體一樣的掃光金屬效果
    float shine = (sin(TIME * shine_speed - UV.x * 10.0 - UV.y * 10.0) + 1.0) * 0.5;
    vec4 gold_color = ring_color;
    gold_color.rgb += vec3(shine * 0.55); // 疊加亮色金屬高光
    
    // 4. 混合折射背景與金屬黃金環
    vec4 final_color = mix(screen_col, gold_color, ring_alpha * ring_color.a);
    
    COLOR = final_color;
}
