// World 6.0 — agua low-poly estilizada (lago, rio e corrego). Barata: ondas
// pequenas no vertice, normal facetada (derivadas), tom raso/fundo pela cor do
// vertice (alfa = 1 na margem, 0 no centro), espuma animada perto da margem,
// fluxo (UV.y) nos rios e reflexo do sol controlado (rugosidade).
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.07, 0.29, 0.33, 1.0);
uniform vec4 shallow : source_color = vec4(0.22, 0.58, 0.55, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.96, 0.92, 1.0);
uniform float flow_speed = 0.0; // > 0 nos rios (ao longo de UV.y)
uniform float wave_height = 0.035;

varying float edge;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = COLOR.a;
	float w = sin(world.x * 1.7 + TIME * 1.3) * cos(world.z * 1.3 - TIME * 1.1);
	VERTEX.y += w * wave_height * (1.0 - edge);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.0, 1.0, edge));
	// faixas suaves de luz que andam com o fluxo (ou derivam no lago)
	float drift = UV.y * 3.0 - TIME * flow_speed + sin(world.x * 0.7 + TIME * 0.4) * 0.6;
	col += vec3(0.05, 0.08, 0.07) * smoothstep(0.75, 1.0, sin(drift * 6.2831) * 0.5 + 0.5);
	// espuma: margem + manchas que andam
	float n = hash(floor(world.xz * 2.0 + vec2(TIME * flow_speed * 0.6, TIME * 0.15)));
	float f = smoothstep(0.78, 0.95, edge + n * 0.18);
	col = mix(col, foam.rgb, f * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
