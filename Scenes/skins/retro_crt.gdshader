shader_type canvas_item;
uniform float curvature = 3.0;
uniform float scanlines = 20.0;

vec2 curve(vec2 uv) {
	uv = (uv - 0.5) * 2.0;
	uv *= 1.05;	
	uv.x *= 1.0 + pow((abs(uv.y) / curvature), 2.0);
	uv.y *= 1.0 + pow((abs(uv.x) / curvature), 2.0);
	uv  = (uv / 2.0) + 0.5;
	return uv;
}

void fragment() {
    vec2 uv = curve(UV);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0);
    } else {
        float s = sin(uv.y * scanlines * 3.14159 * 2.0);
        s = (s * 0.5 + 0.5) * 0.3 + 0.7; // scanline intensity
        COLOR = COLOR * vec4(s, s, s, 1.0);
    }
}
