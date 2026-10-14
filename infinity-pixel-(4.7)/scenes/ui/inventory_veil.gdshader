// World 6.0 — veu da mochila: o jogo continua visivel (e rodando) atras,
// escurecido e quase sem cor, com um leve tom jade. So existe com a mochila
// aberta (uma copia da tela por quadro nesse estado).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dim : hint_range(0.0, 1.0) = 0.42;
uniform float desaturate : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate) * dim;
	COLOR = vec4(c * vec3(0.92, 1.0, 0.96), 1.0);
}
