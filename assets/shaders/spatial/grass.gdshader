shader_type spatial;
render_mode cull_disabled, ensure_correct_normals;

global uniform sampler2D heightmap : filter_linear, repeat_enable;
global uniform float heightmap_scale;
global uniform vec3 player_position;

group_uniforms GrassProperties;
uniform float clumping_factor : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D clump_noise;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform sampler2D wind_noise;

group_uniforms GrassColor;
uniform vec3 base_color : source_color = vec3(0.05,0.2,0.01);
uniform vec3 tip_color : source_color = vec3(0.5,0.5,0.1);
uniform vec3 subsurface_scattering_color : source_color = vec3(1.0,0.75,0.1);

// Source: https://www.shadertoy.com/view/Xt3cDn
float hash12(vec2 x) {
	uvec2 p = floatBitsToUint(x);
    p = 1103515245U * ((p >> 1U) ^ (p.yx));
    uint h32 = 1103515245U*((p.x) ^ (p.y >> 3U));
    uint n = h32 ^ (h32 >> 16U);
    return float(n) * (1.0 / float(0xffffffffU));
}

mat3 rotate_x(float angle) {
  float s = sin(angle), c = cos(angle);
  return mat3(vec3(1, 0, 0), vec3(0, c, s), vec3(0, -s, c));
}

mat3 rotate_y(float angle) {
  float s = sin(angle), c = cos(angle);
  return mat3(vec3(c, 0, -s), vec3(0, 1, 0), vec3(s, 0, c));
}

mat4 modelview_inverse(mat4 modelview_matrix) {
	mat3 rotation_inv = transpose(mat3(modelview_matrix));
	mat4 modelview_inv = mat4(rotation_inv);
	modelview_inv[3] = vec4(-(rotation_inv * modelview_matrix[3].xyz), 1.0);
	return modelview_inv;
}

float ease_in_quartic(float x) {
	float a = x*x;
	return a*a;
}

float ease_out_quartic(float x) {
	float a = 1.0 - x;
	float b = a*a;
	return 1.0 - b*b;
}

void vertex() {
	float height_factor = 1.0 - UV.y;
	float hash0 = hash12(NODE_POSITION_WORLD.xz);
	float hash1 = hash12(-NODE_POSITION_WORLD.zx);
	float clump0 = texture(clump_noise, NODE_POSITION_WORLD.zx*0.075).x; // Noise
	float clump1 = texture(clump_noise, NODE_POSITION_WORLD.xz*0.5).x;
	float clump2 = texture(clump_noise,-NODE_POSITION_WORLD.zx*0.035).x;

	// --- GRASS BLADE HEIGHT/WIDTH ---
	vec3 camera_offset = NODE_POSITION_WORLD - CAMERA_POSITION_WORLD;
	float camera_distance = length(camera_offset);
	float height_offset = mix(0.4, 2.0, mix(hash0, clump0, 0.8));

	VERTEX.x *= mix(0.6, 1.0, hash1);
	// The further the distance from the camera, the thicker the grass blade will
	// appear to account for decreasing density with LOD
	VERTEX.x *= 1.0 + min(ease_in_quartic(0.033*camera_distance), 75.0);
	VERTEX.y *= height_offset;
	vec3 vertex_model = VERTEX; // Vertex in model space before any rotations are applied

	// --- WIND ---
	float heightmap_offset = (texture(heightmap, NODE_POSITION_WORLD.xz / vec2(textureSize(heightmap, 0))).x - 0.5) * heightmap_scale;
	float player_distance = length(player_position - (NODE_POSITION_WORLD + vec3(0, heightmap_offset, 0)));
	float crushed_factor = min(player_distance*player_distance*1.2, 1.0);

	float turn_angle_base = (mix(-0.15, 0.15, hash0) + clump2*clumping_factor)*TAU;
	float wind_direction = texture(wind_noise, NODE_POSITION_WORLD.zx*0.005/wind_speed + TIME*0.005*wind_speed).x*TAU;
	float wind_strength = mix(0.25, 1.0, texture(wind_noise, NODE_POSITION_WORLD.xz*0.025/wind_speed + TIME*0.05).x)*crushed_factor;
	wind_strength *= wind_strength;
	wind_strength *= mix(0.6, 0.7, hash1) * wind_speed;
	mat3 grass_rotate = rotate_y(mix(turn_angle_base, wind_direction, wind_strength));

	float bend_angle_base = mix(0.12, 0.25, hash1 + height_offset*0.1)*PI*height_factor;
	// We sample wind noise identically to strength, but with a time offset based on
	// the height to simulate the turbulence as the grass blade shakes from the wind.
	float wind_strength_turbulence = mix(0.25, 1.0, texture(wind_noise, NODE_POSITION_WORLD.xz*0.025/wind_speed + (TIME + height_factor*height_factor*0.25)*0.05).x);
	wind_strength_turbulence *= wind_strength_turbulence;
	wind_strength_turbulence *= mix(0.16, 0.25*hash0, clump1)*PI * min(wind_speed, 1.0);
	mat3 grass_bend = rotate_x(mix(0.45*PI, bend_angle_base + wind_strength_turbulence, crushed_factor));

	// Apply rotations to the vertex and normal
	mat3 grass_rotation_matrix = grass_rotate * grass_bend;
	VERTEX = grass_rotation_matrix * VERTEX;
	NORMAL = grass_rotation_matrix * NORMAL;

	// --- VIEW SPACE THICKENING ---
	// Grass blades perpendicular to the camera will appear very thin. We stretch
	// these blades horizontally in view space to make them appear more 'full'.
	vec3 vertex_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float dot_nv = dot(normalize(normal_world), normalize(camera_offset));

	// The direction of thickening in view space will be based on the x-coordinate
	// sign of the vertex position in model space. We multiply by a large factor
	// and round to correct for precision errors from positions at x=0.
	float thicken_direction = sign(round((grass_rotate * vertex_model).x * 1e6));
	float thicken_factor = ease_in_quartic(1.0 - abs(dot_nv)) * abs(vertex_model.x);
	vertex_view.x += thicken_factor * thicken_direction;
	VERTEX = (modelview_inverse(MODELVIEW_MATRIX) * vec4(vertex_view, 1.0)).xyz;

	// --- HEIGHTMAP OFFSET ---
	VERTEX.y += heightmap_offset;
}

void fragment() {
	float fog_factor = exp(-length(VERTEX)*0.017);
	mat3 normal_offset = rotate_y(mix(-0.12, 0.12, UV.x)*PI);
	NORMAL = normalize(normal_offset * NORMAL);
	// Blend grass normal with terrain normal based on distance (assumes up is 0,1,0!)
	NORMAL = mix(vec3(0,1,0), NORMAL, fog_factor);

	float height_factor = 1.0 - UV.y;
	ALBEDO = mix(base_color, tip_color, ease_in_quartic(height_factor));
	ALBEDO *= mix(0.1, 1.0, height_factor*height_factor); // AO
	// Color becomes more uniform as distance increases
	ALBEDO = mix(mix(base_color, tip_color, 0.5)*0.5, ALBEDO, fog_factor);

	//AO = mix(0.1, 1.0, height_factor*height_factor); // Note: This looks better but is only visible when shadows are enabled!
	ROUGHNESS = mix(1.0, 0.4, ease_out_quartic(height_factor));
	ANISOTROPY = 0.85;
}

void light() {
	float diffuse_factor = pow(4.0, dot(NORMAL, LIGHT)) / 4.0; // Diffuse never drops to 0 to simulate ambient bounces
	float sss_factor = max(-dot(VIEW, LIGHT), 0.0) * 0.5;
	DIFFUSE_LIGHT += (diffuse_factor + sss_factor*subsurface_scattering_color) * ATTENUATION * LIGHT_COLOR;
	SPECULAR_LIGHT *= diffuse_factor;
}
