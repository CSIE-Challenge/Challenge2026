shader_type canvas_item;

uniform vec2 rect_size = vec2(100.0, 100.0); 

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float border_thickness = 2.0;       
uniform float dash_length = 0.1;           
uniform float dash_gap = 0.1;               
uniform float scroll_speed = 0.1;      

void fragment() {
    vec2 pixel_pos = UV * rect_size;
    
    float dist_left = pixel_pos.x;
    float dist_right = rect_size.x - pixel_pos.x;
    float dist_top = pixel_pos.y;
    float dist_bottom = rect_size.y - pixel_pos.y;
    
    float min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom));
    
    if (min_dist <= border_thickness) {
        float pos = 0.0;
        
        if (dist_top <= min_dist) {
            pos = pixel_pos.x; 
        } else if (dist_right <= min_dist) {
            pos = rect_size.x + pixel_pos.y; 
        } else if (dist_bottom <= min_dist) {
            pos = rect_size.x + rect_size.y + (rect_size.x - pixel_pos.x); 
        } else {
            pos = rect_size.x * 2.0 + rect_size.y + (rect_size.y - pixel_pos.y); 
        }
        
        pos -= TIME * scroll_speed;
        
        float total_dash = dash_length + dash_gap;
        float cycle = mod(pos, total_dash);
        
        if (cycle < dash_length) {
            COLOR = border_color;
        } else {
            COLOR = vec4(0.0);
        }
    } else {
        COLOR = vec4(0.0);
    }
}