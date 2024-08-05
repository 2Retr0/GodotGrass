shader_type spatial;
render_mode cull_disabled,depth_prepass_alpha,shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D color_ramp : filter_nearest;

void fragment() {
	float fresnel = pow(min(1.0 - dot(NORMAL, VIEW), 1.0), 4.0);
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb + round(fresnel)*0.2;
	ALPHA = albedo.a;
	SPECULAR = 0.2;
}

void light() {
	float u = (dot(NORMAL, LIGHT) + 1.0)*0.5 * ATTENUATION;
	DIFFUSE_LIGHT += texture(color_ramp, vec2(u, 0.0)).rgb;
}
