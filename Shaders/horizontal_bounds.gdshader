shader_type canvas_item;

uniform float radius = 0.4;
uniform float thickness = 0.02;
uniform float noise_strength = 0.05;
uniform vec4 color : source_color;
uniform float offset;

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

    float dist = length(p);

    float n = noise(UV*8.0+offset);
	float y = p.y + (n-0.5)*noise_strength*0.05;
	float show = abs(y) <= thickness? 1.0:0.0;
    COLOR = vec4(color.rgb, show);
}