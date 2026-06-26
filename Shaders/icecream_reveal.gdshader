shader_type canvas_item;

// 1. Color Parameters
uniform vec4 liquid_color : source_color = vec4(0.18, 0.65, 0.83, 1.0);
uniform vec4 border_color : source_color = vec4(0.08, 0.23, 0.38, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);

// 2. Squiggly Border Parameters
uniform float wave_frequency : hint_range(1.0, 30.0) = 12.0;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.015;
uniform float wave_speed : hint_range(0.0, 10.0) = 4.0;

// 3. Dynamic Outline Thickness (in UV space)
uniform float border_thickness : hint_range(0.0, 0.05) = 0.015;

// 4. Reveal Parameters
uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 reveal_origin = vec2(0.5, 0.5);                

// Helper function to calculate a synchronized reveal mask at any UV offset
float get_revealed_mask(vec2 uv, vec2 origin, float radius, float edge_softness, sampler2D tex, vec2 distort) {
    vec2 distorted_uv = uv + distort;
    
    // Sample texture alpha at the distorted coordinate
    float tex_a = texture(tex, distorted_uv).a;
    
    // IMPORTANT FIX: Use the distorted UVs to calculate the distance from the origin.
    // This forces the reveal boundary to stretch and wiggle with the texture waves,
    // hiding the geometric sharp cutoff where they intersect.
    float dist_from_origin = distance(distorted_uv, origin);
    
    float reveal_mask = smoothstep(radius, radius - edge_softness, dist_from_origin);
    return step(0.5, tex_a * reveal_mask);
}

void fragment() {
    // Distort UV coordinates over time for the squiggly liquid effect
    vec2 distortion = vec2(
        sin(UV.y * wave_frequency + TIME * wave_speed),
        cos(UV.x * wave_frequency + TIME * wave_speed)
    ) * wave_amplitude;
    
    vec2 distorted_uv = UV + distortion;
    
    // --- 1. Dynamic Max Reveal Radius Calculation ---
    float dist_tl = distance(reveal_origin, vec2(0.0, 0.0));
    float dist_tr = distance(reveal_origin, vec2(1.0, 0.0));
    float dist_bl = distance(reveal_origin, vec2(0.0, 1.0));
    float dist_br = distance(reveal_origin, vec2(1.0, 1.0));
    
    // We add extra amplitude padding to ensure the distorted edge clears the corners cleanly
    float max_reveal_radius = max(max(dist_tl, dist_tr), max(dist_bl, dist_br)) + (wave_amplitude * 2.0);
    float current_reveal_radius = reveal_progress * max_reveal_radius;
    float edge_softness = 0.01;

    // --- 2. Calculate Synchronized Center Mask ---
    float liquid_mask = get_revealed_mask(UV, reveal_origin, current_reveal_radius, edge_softness, TEXTURE, distortion);
    
    // --- 3. Unified Outline Generation (Using the same Distorted Evaluation) ---
    vec2 offset_x = vec2(border_thickness, 0.0);
    vec2 offset_y = vec2(0.0, border_thickness);
    
    // Evaluate neighbors using the exact same distortion matrix
    float n_u = get_revealed_mask(UV + offset_y, reveal_origin, current_reveal_radius, edge_softness, TEXTURE, distortion);
    float n_d = get_revealed_mask(UV - offset_y, reveal_origin, current_reveal_radius, edge_softness, TEXTURE, distortion);
    float n_l = get_revealed_mask(UV - offset_x, reveal_origin, current_reveal_radius, edge_softness, TEXTURE, distortion);
    float n_r = get_revealed_mask(UV + offset_x, reveal_origin, current_reveal_radius, edge_softness, TEXTURE, distortion);
    
    // An inner border is where the center is filled, but at least one neighbor is empty
    float total_outline = liquid_mask * (1.0 - (n_u * n_d * n_l * n_r));
    
    // --- 4. Color Mixing ---
    vec4 final_color = liquid_color;
    
    // Sample texture's green channel for the highlight placement
    float highlight_mask = texture(TEXTURE, distorted_uv).g * liquid_mask;
    
    // Apply the outline over the liquid color
    final_color = mix(final_color, border_color, total_outline);
    
    // Apply your custom texture highlight (ignoring areas covered by the outline)
    final_color = mix(final_color, highlight_color, highlight_mask * highlight_color.a * (1.0 - total_outline));
    
    // Final alpha crop to the overall liquid shape
    final_color.a *= liquid_mask;
    
    COLOR = final_color;
}