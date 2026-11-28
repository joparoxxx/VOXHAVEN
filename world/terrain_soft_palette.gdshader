shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Preserve the original Quaternius Cube World Pixel Blocks art.
// Linear/mipmap sampling removes aggressive pixel shimmer when zoomed out.
uniform sampler2D terrain_texture : source_color, filter_linear_mipmap, repeat_disable;

// Soft terrain preset. Adjust from WorldView without editing third-party assets.
uniform float texture_saturation : hint_range(0.0, 1.0) = 0.76;
uniform float texture_contrast : hint_range(0.0, 1.0) = 0.78;

void fragment() {
    vec3 original = texture(terrain_texture, UV).rgb;
    float brightness = dot(original, vec3(0.2126, 0.7152, 0.0722));
    vec3 muted = mix(vec3(brightness), original, texture_saturation);
    vec3 soft = vec3(0.5) + (muted - vec3(0.5)) * texture_contrast;
    ALBEDO = clamp(soft * COLOR.rgb, vec3(0.0), vec3(1.0));
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
