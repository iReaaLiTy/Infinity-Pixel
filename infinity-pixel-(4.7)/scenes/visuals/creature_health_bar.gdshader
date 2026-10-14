// World 6.0 — barra de vida das criaturas (so apresentacao).
// Quad sempre de frente para a camera (billboard), por cima da cena (sem
// teste de profundidade), sem luz. Uniformes animados pelo
// creature_health_bar.gd: fill (vida mostrada), ghost (rastro do dano),
// heal (brilho de cura), flash (golpe). Moldura escura, trilho, marcas a cada
// 25% e preenchimento em degrade vertical.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, blend_mix;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float ghost : hint_range(0.0, 1.0) = 1.0;
uniform float heal : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tone : source_color = vec4(0.41, 0.78, 0.63, 1.0);
uniform vec2 size = vec2(1.0, 0.11); // metros (para a moldura ter espessura constante)

void vertex() {
	// Billboard mantendo a escala do no.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * size;
	float edge = 0.018; // moldura (m)
	vec3 frame = vec3(0.04, 0.07, 0.06);
	vec3 track = vec3(0.10, 0.14, 0.13);
	vec3 col = frame;
	bool inside = px.x > edge && px.x < size.x - edge && px.y > edge && px.y < size.y - edge;
	if (inside) {
		float x = (px.x - edge) / (size.x - 2.0 * edge);
		float y = (px.y - edge) / (size.y - 2.0 * edge);
		col = track;
		if (x <= fill) {
			vec3 base = tone.rgb;
			// degrade: claro em cima (UV.y = 0 e o topo), escuro embaixo
			col = mix(base * 1.25 + 0.05, base * 0.7, y);
			col = mix(col, vec3(0.65, 1.0, 0.82), heal * 0.55);
		} else if (x <= ghost) {
			col = vec3(1.0, 0.92, 0.78) * 0.85; // rastro claro do dano recente
		}
		if (abs(fract(x * 4.0 + 0.5) - 0.5) < 0.012 && x > 0.01 && x < 0.99) {
			col *= 0.6; // marcas a cada 25%
		}
		col = mix(col, vec3(1.0), flash * 0.6);
	}
	ALBEDO = col;
	ALPHA = alpha;
}
