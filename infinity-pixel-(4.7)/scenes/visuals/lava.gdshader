// World 6.0 — lava estilizada (so visual, sem dano): crosta escura em placas,
// fendas incandescentes entre as placas que pulsam devagar e escorrem.
// Emissao controlada (laranja/ambar), sem estourar em branco.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 hot : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 crust : source_color = vec4(0.16, 0.08, 0.06, 1.0);
uniform float glow = 1.6;
uniform float flow = 0.15;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.37, 289.11))) * 43758.5453); }

// Distancia ate a borda entre placas (F2 - F1 de Voronoi).
float plate_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 7.0));
			float d = length(g + o - f);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz * 1.1 + vec2(0.0, TIME * flow);
	float crack = 1.0 - smoothstep(0.04, 0.2, plate_edge(p));
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + world.x * 0.5);
	vec3 col = mix(crust.rgb, hot.rgb, max(crack, 0.12));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	EMISSION = hot.rgb * (0.15 + crack) * glow * pulse;
}
