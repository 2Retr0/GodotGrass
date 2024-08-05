// I didn't put a lot of thought into this...
shader_type spatial;
render_mode shadows_disabled, ensure_correct_normals;

global uniform sampler2D heightmap : filter_linear, repeat_enable;
global uniform float heightmap_scale;

uniform vec3 base_color : source_color = vec3(0.05,0.2,0.01);
uniform vec3 tip_color : source_color = vec3(0.5,0.5,0.1);
uniform vec3 subsurface_scattering_color : source_color = vec3(1.0,0.75,0.1);

varying vec3 vertex_world;

float ease_in_quadratic(float x) {
	return x*x;
}

void vertex() {
	float heightmap_offset = (texture(heightmap, VERTEX.xz / vec2(textureSize(heightmap, 0))).x - 0.5) * heightmap_scale;
	VERTEX.y += heightmap_offset;
	vertex_world = VERTEX;
}

void fragment() {
	ALBEDO = mix(base_color*0.05, mix(base_color, tip_color, 0.5)*0.5, min(ease_in_quadratic(length(vertex_world.xz - CAMERA_POSITION_WORLD.xz)*0.01), 1.0));
}

void light() {
	float diffuse_factor = pow(4.0, dot(NORMAL, LIGHT)) / 4.0; // Diffuse never drops to 0 to simulate ambient bounces
	float sss_factor = max(-dot(VIEW, LIGHT), 0.0) * 0.5;
	DIFFUSE_LIGHT += (diffuse_factor + sss_factor*subsurface_scattering_color) * ATTENUATION * LIGHT_COLOR;
}