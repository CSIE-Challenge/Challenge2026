shader_type canvas_item;

uniform vec4 outline_color:source_color = vec4(0.6,0.6,0.6,1); 
uniform float outline_width = 20.0;            

void fragment() {
    vec4 texture_color = texture(TEXTURE, UV);
    vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
    
    float alpha = texture_color.a;
    alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;  
    alpha += texture(TEXTURE, UV - vec2(0.0, size.y)).a;  
    alpha += texture(TEXTURE, UV - vec2(size.x, 0.0)).a;  
    alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a; 
	alpha += texture(TEXTURE, UV + size).a;
	alpha += texture(TEXTURE, UV - size).a;
	alpha += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;  
    alpha += texture(TEXTURE, UV - vec2(size.x, -size.y)).a; 

    vec4 final_color = mix(outline_color, texture_color, texture_color.a);
    
    final_color.a = clamp(alpha, 0.0, 1.0);
    
    COLOR = final_color;
}