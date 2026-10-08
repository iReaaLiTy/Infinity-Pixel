shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Spec: docs/specs/014-ceu-iluminacao-progressiva.md — RF-CEU-007
// "Sereno estrelado": pontinhos que cintilam no chao e nas rochas. A camera
// estrategica nunca enxerga o ceu, entao as estrelas tambem aparecem aqui.
// Um unico MultiMesh (1 draw call). `twinkle_time` vem do DayNightVisual e so
// anda com o jogo ativo (para na pausa e na derrota).

uniform float stars = 0.0;
uniform float twinkle_time = 0.0;
uniform vec3 tint : source_color = vec3(0.78, 0.86, 1.0);

varying float v_phase;
varying float v_threshold;

void vertex() {
	v_phase = INSTANCE_CUSTOM.x;
	v_threshold = INSTANCE_CUSTOM.y;
}

void fragment() {
	float appear = smoothstep(v_threshold, v_threshold + 0.15, stars);
	float wave = 0.5 + 0.5 * sin(twinkle_time * (1.3 + v_phase * 1.7) + v_phase * 6.2831);
	float twinkle = 0.12 + 0.88 * wave * wave * wave * wave;
	ALBEDO = tint * appear * twinkle * 1.1;
}
