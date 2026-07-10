shader_type canvas_item;

uniform float cover_progress : hint_range(-0.2, 1.2) = -0.2;
uniform float recede_progress : hint_range(-0.2, 1.2) = -0.2;

uniform vec4 water_color : source_color = vec4(0.08, 0.35, 0.65, 1.0);
uniform vec4 water_deep_color : source_color = vec4(0.02, 0.15, 0.35, 1.0);
uniform vec4 foam_color : source_color = vec4(1.2, 1.4, 2.0, 1.0); // HDR for glow
uniform float foam_thickness = 0.22;
uniform float wave_amp = 0.04;
uniform float wave_freq = 6.0;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

void fragment() {
    float time = TIME;
    
    // Smooth, continuous noise from seamless texture
    float noise1 = texture(noise_tex, UV * 1.5 + vec2(time * 0.05, time * 0.1)).r;
    float noise2 = texture(noise_tex, UV * 2.5 - vec2(time * 0.08, time * 0.05)).r;
    float edge_noise = (noise1 + noise2) * 0.5; // continuous 0 to 1
    
    // Wave edge calculation
    float edge_offset = (edge_noise - 0.5) * wave_amp * 2.0;
    // Layer a smooth sine wave for organic macroscopic wave shape
    edge_offset += sin(UV.y * wave_freq * 0.5 + time * 1.5) * wave_amp * 0.5;
    
    float current_cover = cover_progress + edge_offset;
    float current_recede = recede_progress + edge_offset;
    
    vec4 color = vec4(0.0);
    
    if (UV.x < current_cover && UV.x > current_recede) {
        // Fluid internal texture using the seamless noise texture
        vec2 scroll1 = UV * 2.0 + vec2(time * 0.1, time * 0.05);
        vec2 scroll2 = UV * 3.0 - vec2(time * 0.15, time * 0.08);
        float fluid_noise = texture(noise_tex, scroll1 + texture(noise_tex, scroll2).rg * 0.5).r;
        
        color = mix(water_deep_color, water_color, smoothstep(0.2, 0.8, fluid_noise));
        
        // Add glowing caustics (smooth continuous lines)
        float caustics = texture(noise_tex, UV * 4.0 + vec2(time * 0.1)).r;
        caustics = smoothstep(0.7, 0.9, caustics);
        color.rgb += vec3(caustics * 0.6);
        
        // Right edge foam (Covering wave)
        float right_dist = current_cover - UV.x;
        if (right_dist < foam_thickness) {
            float f_mix = right_dist / foam_thickness;
            float f_noise = texture(noise_tex, UV * 3.0 - vec2(time * 0.2, 0.0)).r;
            if (f_mix < f_noise) {
                // smooth transition for foam
                color = mix(color, foam_color, smoothstep(0.0, 1.0, 1.0 - f_mix)); 
            }
        }
        
        // Left edge foam (Receding wave)
        float left_dist = UV.x - current_recede;
        if (left_dist < foam_thickness) {
            float f_mix = left_dist / foam_thickness;
            float f_noise = texture(noise_tex, UV * 3.0 + vec2(time * 0.25, 0.0)).r;
            if (f_mix < f_noise) {
                color = mix(color, foam_color, smoothstep(0.0, 1.0, 1.0 - f_mix));
            }
        }
    }
    
    COLOR = color;
}
