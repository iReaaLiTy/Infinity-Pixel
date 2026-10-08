shader_type sky;

// Spec: docs/specs/014-ceu-iluminacao-progressiva.md — RF-CEU-004 / 006 / 007
// Ceu estilizado low-poly: gradiente, disco do Sol, Lua e estrelas procedurais.
// Todos os valores vem do DayNightVisual (que le o DayNightManager); o shader
// nao usa TIME, entao nao anda sozinho nem durante a pausa.

uniform vec3 top_color : source_color = vec3(0.38, 0.62, 0.92);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.84, 0.86);
uniform vec3 ground_color : source_color = vec3(0.30, 0.38, 0.34);
uniform vec3 sun_dir = vec3(0.0, 0.5, 0.87); // aponta PARA o Sol
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_alpha = 1.0;
uniform vec3 moon_dir = vec3(0.0, 0.5, 0.87);
uniform float moon_alpha = 0.0;
uniform float stars = 0.0; // 0 = nenhuma .. 1 = todas

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.2, h));

	// Sol: halo largo + disco pequeno.
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += sun_color * (pow(sd, 10.0) * 0.3 + smoothstep(0.9988, 0.9993, sd)) * sun_alpha;

	// Lua: disco frio + halo curto.
	float md = max(dot(d, normalize(moon_dir)), 0.0);
	col += vec3(0.86, 0.9, 1.0) * (smoothstep(0.9983, 0.9988, md) * 1.1 + pow(md, 80.0) * 0.12) * moon_alpha;

	// Estrelas: uma por celula sorteada; cada uma tem seu limiar, entao surgem
	// aos poucos conforme `stars` sobe (e somem aos poucos no amanhecer).
	if (stars > 0.001 && h > 0.0) {
		vec3 p = d * 150.0;
		vec3 cell = floor(p);
		if (hash(cell) > 0.982) {
			vec3 c = cell + 0.5 + (vec3(hash(cell + 1.0), hash(cell + 2.0), hash(cell + 3.0)) - 0.5) * 0.6;
			float s = smoothstep(0.32, 0.0, length(p - c));
			float threshold = hash(cell + 5.0) * 0.85;
			float appear = smoothstep(threshold, threshold + 0.15, stars);
			col += vec3(0.9, 0.93, 1.0) * s * appear * (0.45 + 0.55 * hash(cell + 4.0)) * smoothstep(0.0, 0.12, h);
		}
	}
	COLOR = col;
}
