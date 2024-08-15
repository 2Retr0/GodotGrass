shader_type spatial;
render_mode shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform sampler2D color_ramp : source_color, filter_nearest;

void fragment() {
	float fresnel = pow(min(1.0 - dot(NORMAL, VIEW), 1.0), 4.0);
	ALBEDO = texture(albedo_texture, UV).rgb + round(fresnel)*0.2;
}

void light() {
	float u = (dot(NORMAL, LIGHT)*0.5 + 0.5) * ATTENUATION;
	DIFFUSE_LIGHT += texture(color_ramp, vec2(u, 0.0)).rgb;
}
