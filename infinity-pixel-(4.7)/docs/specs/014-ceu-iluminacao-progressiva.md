# 014 — Céu, iluminação e transição visual do dia/noite

Ciclo 1 — Núcleo Jogável. Pedida em 2026-10-06, depois da aprovação manual
da 013C e da 013D.

**Por que existe:** o ciclo de tempo (Spec 013) já funcionava, mas o mundo
só tinha dois estados visuais (dia claro / noite azul, com um tween de
1,5 s). O jogador lia o período pela HUD. A 014 faz o **cenário** acompanhar
o relógio, de forma gradual e contínua:

manhã → dia → fim de tarde → pôr do sol → anoitecer → noite → madrugada →
amanhecer → novo dia.

Implementada; **aprovada manualmente (playtest de 2026-10-06)**. Spec 015: próxima,
não iniciada.

## Fora do escopo

- Clima, chuva, tempestade, neve, estações, temperatura.
- Qualquer efeito de gameplay ligado à luz (visão, furtividade, dano).
- Mudanças em duração do ciclo, ondas, dano, HP, domesticação, coleta,
  economia, inventário, construção, Fogueira, Armadilha, torres, navegação,
  respawn, câmera, movimento, menu e HUD.
- Fases da Lua, calendário, astronomia real.
- Inimigos, criaturas, estruturas, recursos ou crafting novos; save/load;
  minimapa; quests. Spec 015.

## Auditoria (estado antes da 014)

| Item | Estado encontrado |
|---|---|
| Fonte do tempo | `DayNightManager` (autoload): `state`, `phase_elapsed`, `clock_minutes()` (inteiro) |
| Visual | `DayNightVisual` (`day_night_visual.gd`, Spec 006): tween de 1,5 s entre 2 estados nos sinais `night_started`/`day_started` |
| Environment | `prototype_area.tscn`: fundo de **cor** (sem Sky), ambiente cor branca 0,35, tonemap Filmic, sem neblina, sem glow |
| Luz | 1 `DirectionalLight3D` com sombra, ângulo fixo (−45°, −45°), energia 0,8 |
| Fontes locais | 2 tochas do refúgio (OmniLight, sem sombra), núcleo do refúgio emissivo (material compartilhado com o fundo do menu), cristal das torres emissivo 0,8, OmniLight da Fogueira |
| Câmera | estratégica, **pitch 50°, FOV 50°**: a borda de cima da tela fica ~25° **abaixo** do horizonte |
| Renderer | GL Compatibility (Godot 4.6.2) |

**Descoberta que mudou o plano:** com a câmera real, **0% do céu** aparece
na tela (medido em 6 pontos do mapa, inclusive nas bordas, trocando o fundo
por magenta). Lua e estrelas só no Sky ficariam invisíveis no jogo. Decisão
do usuário (2026-10-06): **céu real + sinais no chão** — o céu existe (e é
conferido numa vista própria), e no jogo a Lua aparece como luz fria com
sombras que giram, e as estrelas também cintilam no gramado. A câmera não
mudou.

## Requisitos

### RF-CEU-001 — Uma só fonte de tempo

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- `DayNightManager.clock_hours()` (novo, só leitura): o mesmo horário de
  `clock_minutes()`, mas **contínuo** (horas com fração), derivado de
  `state` + `phase_elapsed`. Dia 8,0 → 18,0; noite 18,0 → 29,98 (05:59,
  segurando como o relógio da HUD).
- O visual não tem relógio, `Timer` nem leitura do relógio do sistema.
- Tempos preservados: dia 90 s, noite 45 s, aviso 20 s, contagem 10 s.

### RF-CEU-002 — Controlador visual

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- `scenes/world/day_night_visual.gd` (nó `DayNightVisual`, o mesmo da Spec
  006) foi reescrito como controlador do ambiente. Nada disso ficou em
  `main.gd`.
- A cada quadro com o jogo ativo: lê a hora → amostra os quadros-chave →
  escreve Sol/Lua, ambiente, exposição, neblina, céu, estrelas e o brilho
  das fontes locais.
- O `Environment` é **duplicado por mundo**: uma partida nunca herda o céu
  da anterior.

### RF-CEU-003 — Transição contínua por quadros-chave

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- 19 quadros-chave por hora (`KEYS`), interpolados linearmente (`lerp` de
  cor e número), com volta 24 h → 0 h. Sem `if noite` / `if dia`.
- Períodos visuais (referência no relógio do jogo):

| Horário | Período | Leitura |
|---|---|---|
| 05:00–06:30 | Amanhecer | estrelas somem, Lua apaga, luz quente baixa |
| 06:30–09:00 | Manhã | 08:00 = Sol a 30°, luz clara levemente quente, sombras visíveis |
| 09:00–16:00 | Dia | Sol a até 60°, sombras curtas, sem estourar |
| 16:00–18:00 | Fim de tarde / pôr do sol | Sol desce, luz dourada, sombras longas (aviso visual) |
| 18:00–20:00 | Anoitecer | céu e ambiente esfriam, fontes locais ganham peso |
| 20:00–05:00 | Noite / madrugada | Lua, estrelas, ambiente azul escuro mas jogável |

- Em tempo real: 1 h de jogo = 9 s de dia; 1 h de noite = 3,75 s.

### RF-CEU-004 — Sol

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Mesma `DirectionalLight3D`. Nasce a leste, passa ao **sul** (atrás da
  câmera, sombras para o norte, frentes iluminadas) e se põe a oeste.
- Elevação: 30° às 08:00, 60° ao meio-dia, ~8° às 17:30 (mínimo 6°).
- Energia: 0,80 às 08:00, 0,64 ao meio-dia (o Sol alto ilumina mais o chão;
  a energia cai para não estourar), 0,50 às 18:00.
- Cor: quente de manhã, quase neutra ao meio-dia, dourada/laranja no fim
  da tarde. Opacidade da sombra 1,0 de dia.

### RF-CEU-005 — Ambiente, exposição e neblina

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Luz ambiente por cor (não pelo céu): branca ~0,34 de dia, azul ~0,55 à
  noite (noite escura, nunca preta).
- Exposição: 0,97 ao meio-dia, até 1,12 na noite profunda.
- Neblina de profundidade **muito leve** (0,0025 de dia, 0,004 à noite), na
  cor do período. Sem volumetria. Não esconde inimigos.
- Sem glow (custo de tela cheia; o brilho noturno vem de emissão e luzes
  locais).

### RF-CEU-006 — Céu e Lua

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- `day_night_sky.gdshader` (shader de céu): gradiente, disco e halo do Sol,
  disco e halo da Lua, estrelas procedurais. Sem `TIME`; atualizado a 5 Hz;
  radiância 32 px, incremental.
- Lua: nasce ~18:30 a leste, alta perto de 00:00, se põe ~06:00. Visível no
  céu da noite (`moon_alpha` 1,0) e apagada de dia.
- **No jogo:** às 19:00 (energia quase 0) a luz direcional passa a ser a
  Lua: fria, energia ~0,3, sombra a 55%, direção que gira durante a noite.
  Às 05:15 volta a ser o Sol.

### RF-CEU-007 — Estrelas

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Céu:** cada estrela tem seu limiar, então surgem uma a uma ao anoitecer
  (~18:40) e somem uma a uma no amanhecer.
- **Chão:** 120 pontinhos que cintilam no gramado aberto (1 `MultiMesh`,
  shader sem luz, sem sombra, sem colisão), com o mesmo fade e limiar por
  ponto. O cintilar usa um tempo do controlador, que para na pausa.
- Invisíveis de 06:00 a 18:00.

### RF-CEU-008 — Refúgio e Fogueira à noite

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Refúgio:** núcleo emissivo 1,5 → 2,6, tochas 1,0 → 1,6 e uma luz local
  nova (`Territory/RefugeNightLight`, quente, alcance 10 m, **sem sombra**),
  apagada de dia. O material do núcleo é duplicado por mundo (o fundo do
  menu não muda).
- **Fogueira:** luz 0,6 de dia → 2,2 à noite, alcance da **luz** 4 → 6,5 m,
  chama mais forte. O **alcance da cura (2,5 m), cargas, recarga e
  cancelamentos não mudaram**.

### RF-CEU-009 — Torres

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Cristal e disparo emissivos 0,8 → 2,2 à noite. Dano, alcance, cadência e
  alvo não leem o brilho.

### RF-CEU-010 — Armadilhas

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Pontas com leve emissão à noite (até 0,35), **sem luz própria**.

### RF-CEU-011 — 05:59 → 08:00

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Segurando em 05:59 (onda viva): o visual fica no amanhecer.
- Ao vencer a onda o relógio salta para 08:00 (regra atual, intacta). O
  visual **percorre** 06:00 → 08:00 em ~2,7 s (0,75 h/s), sem flash: a
  maior variação de luz por quadro medida foi 0,008.

### RF-CEU-012 — Pausa, derrota e reinício

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Pausa:** o controlador para junto com o jogo (Sol, Lua, céu e cintilar).
- **Derrota:** `can_play()` falso congela o ambiente no estado do momento.
- **Reiniciar:** mundo e `Environment` novos, encaixados direto em 08:00
  (manhã), sem Lua, estrelas ou brilho noturno.

### RNF-CEU-001 — Desempenho (GL Compatibility)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Uma só luz com sombra (a direcional, que alterna Sol/Lua).
- Luzes locais sem sombra: 2 tochas + refúgio + Fogueira.
- Estrelas do chão: 1 draw call. Estrelas do céu: no shader.
- Sem partículas, glow, volumetria ou `TIME` no céu.

## Arquivos

- **Novos:** `scenes/world/day_night_sky.gdshader`,
  `scenes/world/night_glints.gdshader`, `tests/sky_cycle.gd/.tscn`,
  `tests/sky_showcase.gd/.tscn`, `tools/test_spec014.ps1`.
- **Modificados:** `scenes/world/day_night_visual.gd` (reescrito),
  `scenes/world/day_night_manager.gd` (`clock_hours()`, só leitura),
  `scenes/world/healing_campfire.gd`, `defense_tower.gd`, `spike_trap.gd`
  (só `set_night_glow()` visual).

## Testes

- **`tests/sky_cycle.tscn`:** 45 verificações (A–S, fontes locais, tempos,
  conexões de sinais sem acumular).
- **`tests/sky_showcase.tscn`:** capturas pela câmera real em 12 horários,
  a transição do novo dia e 5 vistas do céu.
- Detalhes em `../validation/spec014.md`.

## Alternativas descartadas

- **Inclinar a câmera à noite para mostrar o céu.** A câmera está aprovada e
  fora do escopo.
- **Faixa de céu desenhada no topo da tela.** Cobriria as colinas do norte e
  inimigos chegando.
- **Duas luzes direcionais (Sol + Lua).** Dobraria o custo de sombra; a
  troca na mesma luz acontece com energia ~0, invisível.
- **Ambiente vindo do céu.** Menos controle de legibilidade e mais custo de
  radiância; o ambiente usa cor dos quadros-chave.
- **Estrelas como centenas de nós 3D.** Substituído por shader + 1
  `MultiMesh`.
- **Glow de tela cheia.** Custo constante para um efeito discreto.

## Perguntas em aberto

- Valores de cor/energia são de protótipo: confirmar no playtest se a
  noite está escura o bastante e se o fim de tarde avisa a tempo.
- As estrelas do chão leem como "estrelas/sereno" ou confundem?

## Não aplicável a este jogo

- Ciclo astronômico real, latitude, estações.
