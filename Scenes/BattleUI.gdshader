shader_type canvas_item;

// This reads the screen behind the ColorRect
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- SETTINGS ---
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5; // How bright is the glow?
uniform float blur_size : hint_range(0.0, 10.0) = 3.0;    // How spread out is the glow?
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3; // Dark corners

void fragment() {
    // 1. Get the original sharp image
    vec4 raw_color = texture(screen_texture, SCREEN_UV);
    
    // 2. Create a blurry version (The Glow)
    // We sample 4 neighbors to create a cheap "fake blur"
    vec2 pixel = SCREEN_PIXEL_SIZE * blur_size;
    vec4 blur = texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y)); // Up
    blur += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y));      // Down
    blur += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0));     // Left
    blur += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0));      // Right
    blur *= 0.25; // Average them
    
    // 3. Combine: Add the blur on top of the original (Additive Blending)
    vec3 blooming_color = raw_color.rgb + (blur.rgb * glow_strength);
    
    // 4. Apply Saturation (For Finisher)
    float grey = dot(blooming_color, vec3(0.299, 0.587, 0.114));
    vec3 sat_color = mix(vec3(grey), blooming_color, saturation);
    
    // 5. Apply Vignette (Darker corners)
    vec2 center = UV - 0.5;
    float dist = length(center);
    // Smooth circle: Darkens only the far edges
    float vignette = 1.0 - smoothstep(0.4, 1.0, dist * 1.5); 
    // Mix the vignette color (black)
    vec3 final_color = sat_color * (1.0 - vignette_intensity) + (sat_color * vignette * vignette_intensity);

    COLOR = vec4(final_color, 1.0);
}