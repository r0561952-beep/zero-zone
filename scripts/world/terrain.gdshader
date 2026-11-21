// ZERO ZONE — шейдер рельефа: смешивание пожухлой травы, лесной подстилки, грунтовки и грязи по маске региона.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec4 region_rect;
uniform sampler2D grass_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mud_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float wetness = 0.0;
uniform float snow = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 muv = (wpos.xz - region_rect.xy) / region_rect.zw;
	vec4 m = texture(mask_tex, muv);
	vec2 uv = wpos.xz;
	float macro = texture(forest_alb, uv * 0.011).g;
	float macro2 = texture(grass_alb, uv * 0.031 + 0.37).r;
	vec3 g = texture(grass_alb, uv / 3.0).rgb * (0.78 + macro2 * 0.45);
	vec3 gn = texture(grass_nrm, uv / 3.0).rgb;
	vec3 f = texture(forest_alb, uv / 3.2).rgb * (0.85 + macro * 0.3);
	vec3 fn = texture(forest_nrm, uv / 3.2).rgb;
	vec3 r = texture(gravel_alb, uv / 3.0).rgb;
	vec3 rn = texture(gravel_nrm, uv / 3.0).rgb;
	vec3 md = texture(mud_alb, uv / 2.6).rgb;
	vec3 mn = texture(mud_nrm, uv / 2.6).rgb;

	float noise = (macro - 0.5) * 0.5 + (macro2 - 0.5) * 0.3;
	float wf = smoothstep(0.12, 0.45, m.g + noise * 0.8);
	float wr = smoothstep(0.25, 0.6, m.r + m.a * 0.8 + noise * 0.4);
	float wm = smoothstep(0.05, 0.45, m.b + noise * 0.2);
	vec3 col = mix(g, f, wf);
	vec3 nrm = mix(gn, fn, wf);
	col = mix(col, r, wr);
	nrm = mix(nrm, rn, wr);
	col = mix(col, md, wm);
	nrm = mix(nrm, mn, wm);

	float wet = clamp(wetness + wm * 0.6 + wr * wetness * 0.4, 0.0, 1.0);
	col *= 1.0 - wet * 0.35;
	float up = clamp(wnrm.y, 0.0, 1.0);
	float sn = snow * smoothstep(0.3, 0.8, up + noise * 0.4) * (1.0 - wm);
	col = mix(col, vec3(0.82, 0.84, 0.86), sn);

	ALBEDO = col;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = mix(0.93, 0.35, wet * 0.85) * (1.0 - sn * 0.2);
	SPECULAR = 0.35 + wet * 0.3;
}
