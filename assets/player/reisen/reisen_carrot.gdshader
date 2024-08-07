shader_type spatial;
render_mode shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D color_ramp : source_color, filter_nearest;

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}

void light() {
	float u = (dot(NORMAL, LIGHT)*0.5 + 0.5) * ATTENUATION;
	DIFFUSE_LIGHT += texture(color_ramp, vec2(u, 0.0)).rgb;
}
