shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // Hide everything below the reveal line.
    if (UV.y > reveal)
        color.a = 0.0;

    COLOR = color;
}