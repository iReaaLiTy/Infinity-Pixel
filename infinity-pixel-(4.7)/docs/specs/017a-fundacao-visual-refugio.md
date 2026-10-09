# 017A — Fundação Visual e Refúgio (fatia vertical)

Reformulação visual — direção "Vale de Jade" aprovada em 2026-10-08.
Base: commit `345f70a` (P0/P1 aprovadas). **Status (09/10/2026): Etapas 1–4
implementadas e testadas (sem e com janela), junto com a Spec 018; aguardando
playtest manual. Registro: `docs/validation/visual-hud-tutorial.md`.**
Histórico: Etapas 1 (linha de base) e 2 (protótipo em 3 objetos) registradas em
`docs/validation/017a.md`; as Etapas 3–4 (Refúgio inteiro, chão e trilhas) foram
autorizadas na execução autônoma de 09/10/2026. A HUD (extração de `main.gd` e
redesenho) foi feita como subetapa própria (017B/020).

## Objetivo visual

Transformar a área do Refúgio (a `SafeZone` e o que a câmera vê a partir
dela) numa amostra do novo estilo, antes de aplicá-lo ao mapa:

- low-poly **facetado** (normais planas), sem esferas lisas;
- sombreado em faixas (toon) agradável e barato;
- cores com significado: jade = jogador, âmbar = recurso/interação;
- chão, caminhos e paredões com contraste e formas naturais;
- Refúgio reconhecível como o coração da base, com o cristal em destaque;
- composição pensada para a câmera estratégica atual (distância 20 m,
  inclinação 50°, olhando para o sul), sem mudar a câmera.

Não é só troca de cor: formas, materiais e composição mudam.

## Fora do escopo

Economia G1–G6, variantes de inimigos, novas mecânicas, tutorial, HUD,
câmera, combate, controles, criaturas (modelos e animações), resto do mapa
(bosque, região rochosa, ruína), torres, armadilhas, Fogueira e marcos.

## Área da fatia

- `SafeZone` inteira: Refúgio (0, −15), pátio, `BuildZone` (7, −15; 8 × 10 m),
  caminhos até a bifurcação (z ≈ −2).
- Pontos de defesa internos: `SlotWestInner` (−10,5; −5,5),
  `SlotEastInner` (10,5; −5,5), `SlotRuinMeadow` (−3,8; −1).
- Fundo visível da câmera: trecho sul da borda (`BorderRidgeSouth`,
  `Mountain`/`Cliff` ao sul).
- Na borda da fatia, a cor do chão novo funde-se com a do chão atual (faixa de
  4 m) para não haver emenda dura.

## Regras invioláveis

1. **Colisões:** nenhum `StaticBody3D`, `CollisionShape3D` ou camada muda.
   `ArenaCollision` continua com 66 sólidos; os 4 `Boundary` de `ArenaArt`,
   o `Ground` e os sólidos do Refúgio (núcleo r = 0,55 m; tochas em
   (±3,3; −14,3); mastros em (±2; −16)) ficam idênticos.
2. **Navegação:** a navmesh é assada só de colisores estáticos (máscara 1 | 8,
   `tools/bake_navmesh.gd`); mesmo assim **não se re-assa**:
   `arena_navmesh.tres` deve ter o mesmo hash antes e depois.
3. **Posições de gameplay:** Refúgio, `PlayerSpawn`, `BuildZone`, pontos de
   defesa, entradas e rotas noturnas, colecionáveis e encontros não se movem.
4. **Peças altas sem colisão não podem enganar:** geometria acima de 0,3 m só
   onde já existe sólido (núcleo, tochas, mastros) ou fora da área jogável
   (além dos `Boundary`). No chão andável, só peças rentes (≤ 0,15 m).
5. **Regras e números aprovados** (P0/P1, 013–015) intocados.
6. **Ciclo dia/noite (Spec 014):** `day_night_visual.gd` não muda; o que
   brilha à noite entra no grupo `night_glow` com `set_night_glow(f)`, como
   torres, armadilhas, Fogueira e marcos já fazem. `RefugeNightLight`
   continua igual.

## Estratégia do shader toon

Em duas etapas, para provar antes de espalhar:

1. **Opção A (preferida, risco baixo):** `StandardMaterial3D` com
   `diffuse_mode = TOON`, `specular_mode = DISABLED`, `rim` suave e cor por
   vértice. Funciona no GL Compatibility, respeita Sol, Lua e luz ambiente da
   014 sem código novo.
2. **Opção B (só se A falhar nos critérios):** `scenes/visuals/toon.gdshader`
   com `light()` em 3 faixas (`smoothstep` curto entre elas), `ATTENUATION`
   para sombras e borda de luz pela `LIGHT_COLOR`; a luz ambiente continua a
   do motor.

Validação em **3 objetos primeiro** (cristal do Refúgio, `SlotWestInner` e um
segmento do paredão sul), com capturas nas 6 horas de referência. Só depois de
aprovado nessas capturas o material vai para o resto da fatia.

Contorno (casca invertida) não entra na 017A.

## Paleta da fatia

| Papel | Cores | Uso |
|---|---|---|
| Jade (jogador) | #3FBF8F · #1E6B57 · #A8E6CF | Cristal, tecido dos estandartes, runas, encaixes dos pontos de defesa |
| Brilho do cristal | #7FD8B0 (emissão) | Cristal e runas, mais forte à noite |
| Grama do pátio | #6FAF5A · #5C9A4C · #3E7A45 | Variação por manchas, mais escura nas bordas |
| Terra batida (caminhos) | #C9A66B · #A8854F · #8C6A3F (borda) | Caminhos e entrada do pátio |
| Pedra do Refúgio | #B9A58C · #8F7E69 · #6F6152 | Plataforma, degraus, lajes |
| Madeira | #8A5E3B · #5E3F27 | Mastros, braseiros, deck da `BuildZone` |
| Âmbar (fogo/interação) | #E9A23B · #B8742A | Chamas, lanternas |
| Paredões | #A39C8F · #857E72 · #6F6A60, topo #4F8A4A | Rocha facetada com vegetação no topo |

As cores ficam em `scenes/visuals/palette.gd` (constantes); nenhum material
da fatia usa cor solta fora dela.

## Materiais

- Um material por papel (pedra, terra, grama, madeira, tecido, cristal,
  rocha), compartilhado entre malhas para poupar trocas de estado.
- Variação vem da **cor por vértice**, não de mais materiais nem texturas.
- Rugosidade alta, sem reflexo; emissão só em cristal, runas e chamas.
- Sombra projetada desligada em peças rentes (≤ 0,15 m) e decoração pequena.

## Mudanças de geometria visual

Todas geradas por `tools/build_refuge_art.gd` (no padrão de
`tools/build_first_map.gd`) e salvas em `scenes/visuals/refuge_art.tscn`,
instanciada em `prototype_area.tscn` **fora** do grupo `navigation_source`
e sem nenhum corpo físico.

| Item | Hoje | 017A |
|---|---|---|
| Chão da `SafeZone` | Caixa verde lisa + clareiras amarelo-pálidas | Malha subdividida com manchas de grama, pátio de terra e borda que se funde ao chão atual |
| Caminhos | Faixas `Paving*` retas, amarelo-pálidas | Terra batida com borda escura irregular, mesma posição e largura |
| Plataforma do Refúgio | Discos achatados | Tablado de pedra facetado em 2 níveis, lajes e degraus rentes (≤ 0,15 m) |
| Cristal central | Prisma branco | Cristal jade facetado e mais alto sobre o núcleo sólido, com brilho e anel de runas no chão |
| Tochas | Postes simples | Braseiros de pedra e madeira, chama âmbar, nos mesmos sólidos |
| Estandartes | Bandeirinhas claras | Tecido jade com emblema, mais altos, nos mesmos mastros |
| `BuildZone` | Octógono escuro | Deck de madeira delimitado por estacas rentes, mesma área |
| Pontos de defesa internos | Octógono claro com losango ciano | Base de pedra facetada com encaixe e cristal jade pequeno (`defense_slot.gd`, mesma API) |
| Paredão sul visível | Bolhas claras lisas | Rocha facetada em 3 tons, topo com vegetação; o `Boundary` não muda |
| Fundo | — | Silhueta de uma torre de vigia jade no paredão sul, fora da área jogável |

As malhas antigas substituídas deixam de aparecer pelo próprio
`tools/build_first_map.gd` (para o pipeline continuar reproduzível), sem
apagar nenhum colisor.

## Compatibilidade dia/noite

- Nenhuma cor da fatia "acende" sozinha de dia; à noite, cristal, runas e
  braseiros sobem pelo `night_glow` (0 → 1, a mesma curva da 014).
- As 6 horas de referência são capturadas antes e depois: 08:00, 12:00, 17:30,
  21:00, 00:00 e 05:30.
- À noite, o Refúgio continua sendo o ponto mais claro da tela, como hoje.

## Plano de testes

**Antes de qualquer mudança (linha de base):**
- capturas de referência (abaixo) e medição de desempenho na mesma máquina;
- `sha256` de `arena_navmesh.tres`, `arena_collision.tscn` e da parte física
  de `arena_art.tscn`; inventário das posições de gameplay em JSON.

**Novos testes:**
- `tests/visual_invariants`: 66 sólidos; `Boundary` e sólidos do Refúgio
  iguais; nenhum corpo físico em `RefugeArt`; posições de gameplay iguais ao
  JSON de base; `RefugeArt` fora de `navigation_source`.
- `tests/perf_probe` (com janela, `--disable-vsync`, máquina parada): 10 s em
  cada vista de referência; média de FPS, 1% mais lento, chamadas de desenho e
  primitivas, antes e depois.
- `tools/visual_capture`: as capturas abaixo, mesma câmera e mesmo horário,
  com o observador de foco.

**Regressão:** as 18 suítes sem janela (`--fixed-fps 60`) e com janela;
`creature_motion` 32/32, `navigation_contracts` 38/38,
`physics_contracts` 23/23, `sky_cycle` 45/45, `defense_economy` 35/35 e
`build_heal` 68/68 sem mudar expectativas.

## Capturas de comparação (antes × depois, 1280 × 720)

1. Vista padrão no início do Dia 1 (Player no `PlayerSpawn`), 08:00.
2. A mesma vista às 12:00, 17:30, 21:00, 00:00 e 05:30.
3. Refúgio aproximado (Player a 3 m do cristal), 12:00 e 21:00.
4. Caminho do pátio até a bifurcação (Player em z = −2), 12:00.
5. `SlotWestInner` vazio e com torre nível 1, 12:00 e 21:00.
6. `BuildZone` com fantasma de Fogueira válido e inválido.
7. Noite 1 com os 3 inimigos chegando ao Refúgio, 21:00.
8. Vista de cima da `SafeZone` (diagnóstico de composição).

## Riscos

| Risco | Mitigação |
|---|---|
| Toon do `StandardMaterial3D` não agradar | Teste em 3 objetos; opção B só se necessário |
| Noite da 014 ficar diferente | `day_night_visual.gd` intocado; 6 horas comparadas |
| Peça decorativa sem colisão parecer obstáculo | Regra 4; revisão nas capturas 3 e 7 |
| Emenda entre fatia e mapa antigo | Faixa de 4 m de fusão; aceita até o resto do mapa ser refeito |
| Queda de desempenho no Iris Xe | Materiais compartilhados, sem sombra em peças rentes, medição antes/depois |
| `build_first_map.gd` regenerar e desfazer | Substituições feitas pelo próprio tool |
| Testes que leem visuais dos pontos de defesa | API de `defense_slot.gd` mantida (`preview_ring`, `build`, `tower`) |
| Captura com janela travar | `force_draw`, timeout por execução, observador de foco |

## Critérios de aceitação

- [ ] Hash de `arena_navmesh.tres` igual; 66 sólidos; `visual_invariants` verde.
- [ ] As 18 suítes verdes sem janela e com janela, sem expectativas alteradas.
- [ ] Capturas 1–8 antes e depois, nas mesmas câmeras e horários.
- [ ] Desempenho medido antes e depois na mesma máquina; o relatório diz se a
      meta de 60 FPS foi atingida, com os números (sem afirmar sem medir).
- [ ] À noite, o Refúgio é o ponto mais claro da vista padrão.
- [ ] Nenhum objeto alto sem colisão no chão andável (revisão das capturas).
- [ ] Playtest manual do usuário aprovado.

## Arquivos

**Criar:** `scenes/visuals/palette.gd`, `tools/build_refuge_art.gd`,
`scenes/visuals/refuge_art.tscn` (+ malhas geradas), `tests/visual_invariants`,
`tests/perf_probe`, `tools/visual_capture.gd`; `scenes/visuals/toon.gdshader`
só na opção B.

**Modificar:** `scenes/world/prototype_area.tscn` (instância de `RefugeArt`),
`tools/build_first_map.gd`, `scenes/visuals/arena_art.tscn` e
`scenes/world/world_regions.tscn` (só malhas visuais substituídas),
`scenes/world/defense_slot.gd` (visual da base).

**Intocados:** `arena_navmesh.tres`, `arena_collision.tscn`, colisores de
`ArenaArt`, `day_night_visual.gd`, câmera, `player.gd`, `wild_dino.gd`,
`approach_slots.gd`, regras e números.
