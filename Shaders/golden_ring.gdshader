shader_type canvas_item;

uniform float outer_radius : hint_range(0.0, 1.0) = 0.5;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.4;
uniform vec4 ring_color : source_color = vec4(1.0, 0.8, 0.2, 0.8);

void fragment() {
    vec2 uv = UV - vec2(0.5);
    float dist = length(uv);
    
    // 平滑邊緣，防止鋸齒
    float alpha_outer = 1.0 - smoothstep(outer_radius - 0.02, outer_radius, dist);
    float alpha_inner = smoothstep(inner_radius, inner_radius + 0.02, dist);
    
    // 只有在內外圈之間的區域才有顏色
    float ring_alpha = alpha_outer * alpha_inner;
    
    COLOR = ring_color;
    COLOR.a *= ring_alpha;
}
