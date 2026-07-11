shader_type canvas_item;
uniform float time_scale = 1.0;
uniform vec4 base_color : source_color = vec4(0.3, 1.0, 0.4, 1.0);
uniform vec4 dark_color : source_color = vec4(0.0, 0.5, 0.1, 1.0);

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    if (dist > 1.0) {
        COLOR.a = 0.0;
    } else {
        // Swirling plasma effect
        vec2 p = uv;
        for(int i = 1; i < 4; i++) {
            vec2 newp = p;
            newp.x += 0.5 / float(i) * sin(float(i) * p.y + TIME * time_scale + 0.3);
            newp.y += 0.5 / float(i) * cos(float(i) * p.x + TIME * time_scale + 0.3);
            p = newp;
        }
        float plasma = cos(p.x + p.y + 1.0) * 0.5 + 0.5;
        vec4 tex_color = mix(dark_color, base_color, plasma);
        
        // Darken edges slightly
        float edge = pow(dist, 2.0);
        tex_color.rgb -= vec3(edge * 0.4);
        
        COLOR = tex_color * COLOR;
    }
}
