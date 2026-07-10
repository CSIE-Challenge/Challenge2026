shader_type canvas_item;

uniform float thickness = 0.02;
uniform float noise_strength = 0.05;
uniform vec4 color : source_color;
uniform float offset;
uniform float draw;
uniform float color_variation = 0.4;
uniform int color_bands = 4;

float rand(vec2 p){
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float noise(vec2 p){
    vec2 i=floor(p);
    vec2 f=fract(p);

    float a=rand(i);
    float b=rand(i+vec2(1,0));
    float c=rand(i+vec2(0,1));
    float d=rand(i+vec2(1,1));

    vec2 u=f*f*(3.0-2.0*f);

    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
}

void fragment(){
    vec2 center = vec2(0.5,0.5);
    vec2 p = UV-center;

	float n = noise(UV*8.0+offset);
	float x = p.x + (n-0.5)*noise_strength*0.05;
	float show = abs(x) <= thickness? 1.0: 0.0;
	float d = abs(p.y) <= draw? 1.0: 0.0;
	float n_bands = floor(n * float(color_bands)) / float(max(color_bands - 1, 1));
	vec3 noise_color = color.rgb * (1.0 - color_variation + color_variation * n_bands);
	COLOR = vec4(noise_color, show * d);
}