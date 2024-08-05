shader_type spatial;
render_mode unshaded,cull_front;

uniform float outline_thighness : hint_range(0.0, 0.2, 0.005) = 0.055;

void vertex() {
	VERTEX += NORMAL*outline_thighness;
}

void fragment() {
	ALBEDO = vec3(0.29, 0.21, 0.12)*0.1;
}