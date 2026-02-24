shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform float blur_size : hint_range(0.0, 10.0) = 3.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 raw_color = texture(screen_texture, SCREEN_UV);
    
    // Fake Glow (Blur)
    vec2 pixel = SCREEN_PIXEL_SIZE * blur_size;
    vec4 blur = texture(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y));
    blur += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0));
    blur += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0));
    blur *= 0.25;
    
    vec3 blooming_color = raw_color.rgb + (blur.rgb * glow_strength);
    
    // Saturation
    float grey = dot(blooming_color, vec3(0.299, 0.587, 0.114));
    vec3 sat_color = mix(vec3(grey), blooming_color, saturation);
    
    // Vignette
    vec2 center = UV - 0.5;
    float dist = length(center);
    float vignette = 1.0 - smoothstep(0.4, 1.0, dist * 1.5); 
    vec3 final_color = sat_color * (1.0 - vignette_intensity) + (sat_color * vignette * vignette_intensity);

    COLOR = vec4(final_color, 1.0);
}