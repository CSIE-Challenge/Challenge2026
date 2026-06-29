shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float revealed = step(1. - tex_color.r, progress);

    COLOR = vec4(0.0, 0.0, 0.0, revealed * tex_color.a);
}
