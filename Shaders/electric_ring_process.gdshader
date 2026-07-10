shader_type canvas_item;
uniform float radius;
uniform float thickness;
uniform float fill;
uniform vec4 ring_warning_color_nfill : source_color;
uniform vec4 ring_warning_color_fill : source_color;

void fragment() {
	vec2 uv = UV - vec2(0.5,0.5);
	float dist = length(uv);
	float show = step(radius-0.5*thickness,dist)*step(dist,radius+0.5*thickness);
	float angle = atan(uv.x,-uv.y);
	if(angle<0.0)angle+=2.0*PI;
	angle /= (2.0*PI);
	vec4 final_color;
	if(angle < fill)final_color = ring_warning_color_fill*show;
	else final_color = ring_warning_color_nfill*show;
	COLOR = final_color;
}
