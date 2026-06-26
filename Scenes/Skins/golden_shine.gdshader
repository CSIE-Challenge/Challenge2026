shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform float shine_speed = 3.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // 簡單的掃光效果
    float shine = (sin(TIME * shine_speed - UV.x * 10.0 - UV.y * 10.0) + 1.0) * 0.5;
    // 強化光澤亮度
    vec4 final_color = tex * base_color;
    final_color.rgb += vec3(shine * 0.6); // 加上金屬高光
    COLOR = final_color;
}
