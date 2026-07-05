shader_type canvas_item;

void fragment() {
    float alpha = COLOR.a;
    if (alpha == 0.0) {
        discard;
    }
    
    // 透過原始顏色判斷目前繪製的是填滿區(紅色)還是背景區(黑色)
    bool is_fill = COLOR.r > 0.5 && COLOR.g < 0.5;
    
    vec2 uv = UV;
    vec4 final_color = vec4(0.0);
    
    if (is_fill) {
        // --- 填充區 (流動能量效果) ---
        float time = TIME * 3.0;
        
        // 基礎漸層：深紅到鮮紅
        vec4 color_left = vec4(0.6, 0.0, 0.1, 1.0);
        vec4 color_right = vec4(1.0, 0.1, 0.3, 1.0);
        vec4 base_color = mix(color_left, color_right, uv.x);
        
        // 製作流動的波浪 (利用 sin 函數組合)
        // 斜向波浪
        float wave1 = sin(uv.x * 25.0 - uv.y * 10.0 - time);
        // 水波起伏
        float wave2 = sin(uv.x * 15.0 + uv.y * 15.0 - time * 1.5);
        
        // 將兩道波浪疊加並強化對比
        float flow = (wave1 + wave2) * 0.5;
        flow = smoothstep(0.1, 0.9, flow); 
        
        // 波浪的高光顏色 (帶點粉色的白光)
        vec4 highlight = vec4(1.0, 0.6, 0.7, 1.0);
        
        // 頂部與底部的邊緣高光反光
        float edge_glow = smoothstep(0.15, 0.0, uv.y) + smoothstep(0.85, 1.0, uv.y);
        
        // 合成：基礎色 + 流動波浪亮部 + 上下邊緣光
        final_color = mix(base_color, highlight, flow * 0.4);
        final_color.rgb += vec3(edge_glow * 0.4); 
    } else {
        // --- 背景區 (深色軌道) ---
        vec4 bg_dark = vec4(0.08, 0.0, 0.02, 1.0);
        
        // 簡單的內陰影：邊緣較暗，中間稍亮
        float inner_light = smoothstep(0.0, 0.3, uv.y) * smoothstep(1.0, 0.7, uv.y);
        
        final_color = vec4(bg_dark.rgb * mix(0.3, 1.0, inner_light), 0.8);
    }
    
    // 保留原始的 Alpha 值 (為了維持 StyleBox 的圓角與抗鋸齒邊緣)
    COLOR = final_color;
    COLOR.a *= alpha;
}
