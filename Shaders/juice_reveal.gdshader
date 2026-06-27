shader_type canvas_item;

// 1. Color Parameters
uniform vec4 liquid_color : source_color = vec4(0.18, 0.65, 0.83, 1.0);
uniform vec4 border_color : source_color = vec4(0.08, 0.23, 0.38, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);

// 2. Squiggly Border Parameters
uniform float wave_frequency : hint_range(1.0, 30.0) = 12.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.015;
uniform float wave_speed : hint_range(0.0, 10.0) = 4.0;

// 3. Outline & Reveal Parameters
uniform float border_thickness : hint_range(0.0, 0.05) = 0.015;
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 reveal_origin = vec2(0.5, 0.5);

// Helper mask function
float get_revealed_mask(vec2 uv, float radius, sampler2D tex) {
    float tex_a = texture(tex, uv).a;
    return step(distance(uv, reveal_origin), radius) * step(0.5, tex_a);
}

void fragment() {
    // Distort UV coordinates
    vec2 distortion = vec2(
        sin(UV.y * wave_frequency + TIME * wave_speed),
        cos(UV.x * wave_frequency + TIME * wave_speed)
    ) * wave_amplitude;

    vec2 distorted_uv = UV + distortion;

    // Calculate max radius by the furtest corner
    vec2 furthest_corner = step(reveal_origin, vec2(0.5));
    float max_reveal_radius = distance(reveal_origin, furthest_corner) + wave_amplitude;
    float current_radius = reveal_progress * max_reveal_radius;

    // Samples center mask
    float liquid_mask = get_revealed_mask(distorted_uv, current_radius, TEXTURE);

    // Edge detection by sampling neighbors
    vec2 offset_x = vec2(border_thickness, 0.0);
    vec2 offset_y = vec2(0.0, border_thickness);

    float n_u = get_revealed_mask(distorted_uv + offset_y, current_radius, TEXTURE);
    float n_d = get_revealed_mask(distorted_uv - offset_y, current_radius, TEXTURE);
    float n_l = get_revealed_mask(distorted_uv - offset_x, current_radius, TEXTURE);
    float n_r = get_revealed_mask(distorted_uv + offset_x, current_radius, TEXTURE);

    // An inner border is where the center is filled, but at least one neighbor is empty
    float outline_mask = liquid_mask * (1.0 - (n_u * n_d * n_l * n_r));

    // Final color mixing
    vec4 final_color = liquid_color;

    // Apply outline
    final_color = mix(final_color, border_color, outline_mask);

    // Sample texture's green channel for the highlight placement
    float highlight_mask = texture(TEXTURE, distorted_uv).g * liquid_mask * (1.0 - outline_mask);
    final_color = mix(final_color, highlight_color, highlight_mask * highlight_color.a);

    // Final alpha crop to the overall liquid shape
    final_color.a *= liquid_mask;

    COLOR = final_color;
}
