shader_type spatial;

uniform sampler2D palette_texture : source_color;
uniform float palette_strength : hint_range(0.0, 1.0) = 0.82;
uniform vec3 shadow_tone : source_color = vec3(0.20, 0.25, 0.17);
uniform vec3 light_tone : source_color = vec3(0.34, 0.42, 0.27);

varying float tile_variation;

void vertex() {
	vec2 tile_coord = floor(MODEL_MATRIX[3].xz / 2.0);
	tile_variation = fract(sin(dot(tile_coord, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 palette_color = texture(palette_texture, UV).rgb;
	float luminance = dot(palette_color, vec3(0.2126, 0.7152, 0.0722));
	float terrain_value = clamp(luminance * 0.55 + tile_variation * 0.45, 0.0, 1.0);
	vec3 terrain_color = mix(shadow_tone, light_tone, smoothstep(0.28, 0.88, terrain_value));
	ALBEDO = mix(palette_color, terrain_color, palette_strength);
	ROUGHNESS = 1.0;
}