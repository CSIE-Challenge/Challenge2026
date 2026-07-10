shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D colors : hint_default_black;

void fragment() {
    vec4 mask = texture(TEXTURE, UV);
    float threshold = 1. - mask.r;

    float mapped_coord = clamp(threshold - progress, 0., 1.);
    vec4 mapped_col = texture(colors, vec2(mapped_coord, 0.));

    COLOR = vec4(mapped_col.rgb, mapped_col.a * mask.a);
}
