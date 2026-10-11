# Auditoria de áudio

## Visual Overhaul 4.0 (11/10/2026) — o que foi implementado

Todos os sons continuam **originais**: nada foi baixado nem copiado de outro jogo. A música já era
composição sintetizada pelo grupo (`tools/compose_score.py`). Os efeitos novos foram sintetizados no
próprio Godot por `tools/build_sfx.gd` (seno, ruído filtrado e envelopes, com semente fixa). O
gerador grava WAV 16-bit mono 22,05 kHz em `assets/audio/sfx/`; em jogo, os arquivos só são
carregados.

| Som | Arquivo | Quando toca | Volume / intervalo mínimo |
|---|---|---|---|
| Tema principal | `refugio_principal.wav` (estava sem uso) | menu principal | barramento Music |
| Hover / clique | `sfx/ui_hover.wav`, `sfx/ui_click.wav` | todo botão do jogo (gancho global no `AudioDirector`) | −30 / −20 dB |
| Coleta | `sfx/collect_wood.wav`, `sfx/collect_stone.wav` | cada golpe em árvore ou rocha coletável | −17 / −18 dB · 0,06 s |
| Construção | `sfx/build.wav` | fogueira, armadilha, torre erguida ou melhorada (antes tocava o som da domesticação) | −15 dB · 0,25 s |
| Torre | `sfx/tower_shot.wav` | disparo do cristal | −27 dB · 0,14 s |
| Rosnado | `sfx/growl.wav` | preparação da mordida do hostil (junto do arco vermelho) | −23 dB · 0,35 s |
| Início da onda | `sfx/wave_start.wav` | 18:00 (trompa grave e tambor) | −13 dB |
| Ambiente de dia | `sfx/ambience_day.wav` (loop de 7,5 s) | menu e dia (vento e piados) | −27 dB |
| Ambiente de noite | `sfx/ambience_night.wav` (loop de 7,5 s) | noite (grilos e vento) | −27 dB |
| Golpe, domesticação, vitória, derrota | já existiam | sem mudança | — |

- O intervalo mínimo evita que várias torres ou invasores ao mesmo tempo virem "metralhadora".
- Sem o arquivo, o efeito fica mudo: nada quebra.
- Os efeitos vão no barramento SFX, regulável em Configurações.
- Coberto por `tests/visual_overhaul4.gd`: efeitos carregados, intervalo mínimo, clique global, ambiente
  de dia, noite (trompa, ambiente e música de combate) e tema do menu.

**Limite honesto:** nenhuma ferramenta de audição estava disponível para mim. Os sons foram medidos
(duração, pico normalizado a −3 dBFS), mas **não foram ouvidos**. Musicalidade, timbre e equilíbrio entre
eles precisam do seu ouvido no playtest. São placeholders de qualidade, prontos para ser trocados por
sons produzidos com o mesmo nome de arquivo.

## O que existia antes (`assets/audio`, composição original segundo `docs/ac1/ASSETS.md`)

| Arquivo | Uso |
|---|---|
| `refugio_principal.wav` | **4.0: música do menu** (antes não era usado) |
| `refugio_calm.wav` | música do dia (preparação) |
| `refugio_combat.wav` | música da noite (defesa) |
| `strike.wav` | golpe do jogador |
| `bond.wav` | domesticação concluída |
| `victory.wav` / `defeat.wav` | noite vencida (amanhecer) / derrota; também na conclusão do tutorial |

Barramentos: Master, Music e SFX, reguláveis em Configurações.

## Especificação para a produção final (pendente)

| Prioridade | Som | Observação |
|---|---|---|
| Alta | Impacto no dinossauro (carne): 3 variações | hoje o golpe do jogador usa o mesmo `strike` para tudo |
| Alta | Dano no jogador | complementa o lampejo |
| Alta | Acerto da torre no alvo | hoje só existe o disparo |
| Alta | Vocalizações por facção (selvagem, guardião, invasor, aliado feliz) | o rosnado atual serve a todos |
| Média | Passos (grama, terra, pedra) para Player e dinossauros | sincronizar com a fase do passo (`actor_visual._gait`) |
| Média | Fogueira acesa (loop curto) e cristal do Refúgio (zumbido baixo) | |
| Média | Território recuperado (coluna de luz) | |
| Baixa | Abrir/fechar a mochila, trocar de aba | hoje usam o clique genérico |

Caminhos legais: produzir no grupo (gravação + edição), usar bancos com licença compatível com venda
(registrando cada licença em `ASSETS.md`) ou contratar. Para substituir um efeito, basta gravar o arquivo
com o mesmo nome em `assets/audio/sfx/`.
