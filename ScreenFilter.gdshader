shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// --- EXISTING SETTINGS ---
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform float blur_size : hint_range(0.0, 10.0) = 4.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.6;

// --- NEW SETTINGS ---
// Brightness: 0.0 is normal. >0 is brighter, <0 is darker.
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
// Contrast: 1.0 is normal. >1 is high contrast, <1 is grey/flat.
uniform float contrast : hint_range(0.5, 2.0) = 1.0;

void fragment() {
    vec4 raw_color = texture(screen_texture, SCREEN_UV);
    
    // 1. GLOW
    vec2 pixel = SCREEN_PIXEL_SIZE * blur_size;
    vec4 blur = texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0));
    blur += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0));
    blur *= 0.25;
    
    float brightness_val = max(blur.r, max(blur.g, blur.b));
    float glow_mask = smoothstep(glow_threshold, glow_threshold + 0.1, brightness_val);
    vec3 blooming_color = raw_color.rgb + (blur.rgb * glow_strength * glow_mask);
    
    // 2. SATURATION
    float grey = dot(blooming_color, vec3(0.299, 0.587, 0.114));
    vec3 sat_color = mix(vec3(grey), blooming_color, saturation);
    
    // --- 3. APPLY CONTRAST ---
    // Formula: Move color to center (0.5), scale it, move back.
    vec3 con_color = (sat_color - 0.5) * contrast + 0.5;
    
    // --- 4. APPLY BRIGHTNESS ---
    // Formula: Simple addition
    vec3 bright_color = con_color + brightness;
    
    // 5. VIGNETTE
    vec2 center = UV - 0.5;
    float dist = length(center);
    float vignette = 1.0 - smoothstep(0.4, 1.0, dist * 1.5); 
    
    // Apply Vignette to final color
    vec3 final_color = bright_color * (1.0 - vignette_intensity) + (bright_color * vignette * vignette_intensity);

    COLOR = vec4(final_color, 1.0);
}