// World 6.0 — queda d'agua estilizada: faixas de espuma descendo (UV.y), borda
// translucida, base clara. Sem luz forte (le-se de dia e de noite).
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform vec4 water : source_color = vec4(0.42, 0.74, 0.74, 1.0);
uniform vec4 foam : source_color = vec4(0.93, 0.99, 0.97, 1.0);
uniform float speed = 1.6;

float hash(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void fragment() {
	float lane = floor(UV.x * 9.0);
	float streak = fract(UV.y * 3.2 - TIME * speed * (0.8 + hash(lane) * 0.5) + hash(lane + 3.0));
	float s = smoothstep(0.55, 0.9, streak);
	vec3 col = mix(water.rgb, foam.rgb, s * 0.85 + smoothstep(0.75, 1.0, UV.y) * 0.6);
	ALBEDO = col;
	EMISSION = col * 0.12; // nunca fica preta a noite
	ALPHA = 0.88 * smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
}
