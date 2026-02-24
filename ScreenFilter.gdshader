shader_type canvas_item;

// This is the uniform Godot 4 uses to read the screen
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- EXISTING SETTINGS ---
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform float blur_size : hint_range(0.0, 10.0) = 4.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float aberration_amount : hint_range(0.0, 0.1) = 0.0;

// --- NEW SETTINGS ---
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;

void fragment() {
    // 1. CHROMATIC ABERRATION (Applied First!)
    // We calculate the Red and Blue offsets based on distance from center
    vec2 dist_from_center = SCREEN_UV - 0.5;
    vec2 r_uv = SCREEN_UV + dist_from_center * aberration_amount;
    vec2 b_uv = SCREEN_UV - dist_from_center * aberration_amount;

    // FIX: We use 'screen_texture' (your uniform) instead of 'SCREEN_TEXTURE'
    float r = texture(screen_texture, r_uv).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, b_uv).b;
    
    // Combine them to get our starting "Bleeding" color
    vec4 raw_color = vec4(r, g, b, 1.0);
    
    // 2. GLOW
    // We sample the screen 4 times around the pixel to create a blur
    vec2 pixel = SCREEN_PIXEL_SIZE * blur_size;
    vec4 blur = texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0));
    blur += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0));
    blur *= 0.25;
    
    float brightness_val = max(blur.r, max(blur.g, blur.b));
    float glow_mask = smoothstep(glow_threshold, glow_threshold + 0.1, brightness_val);
    vec3 blooming_color = raw_color.rgb + (blur.rgb * glow_strength * glow_mask);
    
    // 3. SATURATION
    float grey = dot(blooming_color, vec3(0.299, 0.587, 0.114));
    vec3 sat_color = mix(vec3(grey), blooming_color, saturation);
    
    // 4. CONTRAST
    vec3 con_color = (sat_color - 0.5) * contrast + 0.5;
    
    // 5. BRIGHTNESS
    vec3 bright_color = con_color + brightness;
    
    // 6. VIGNETTE
    vec2 center = UV - 0.5;
    float dist = length(center);
    // Calculate the dark edges (mask)
    float vignette_mask = 1.0 - smoothstep(0.4, 1.0, dist * 1.5); 
    
    // Apply Vignette: Mix the bright color with a darkened version based on intensity
    vec3 final_color = mix(bright_color, bright_color * vignette_mask, vignette_intensity);

    // Final Output
    COLOR = vec4(final_color, 1.0);
}