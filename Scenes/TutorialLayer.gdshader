shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5); // Where the spotlight is looking (UV format)
uniform float radius_px = 150.0; // How big the hole is in pixels
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float base_alpha = 0.7; // 70% dark background

void fragment() {
	// Convert UV to exact pixel coordinates
	vec2 pixel_pos = UV * screen_size;
	vec2 center_pos = center * screen_size;
	
	// How far is this pixel from the center of the spotlight?
	float dist = distance(pixel_pos, center_pos);
	
	// Create a soft, feathered edge (20px transition)
	// 0.0 inside the radius, 1.0 outside the radius.
	float mask = smoothstep(radius_px - 20.0, radius_px + 20.0, dist);
	
	// Apply the color!
	COLOR = vec4(0.0, 0.0, 0.0, mask * base_alpha);
}