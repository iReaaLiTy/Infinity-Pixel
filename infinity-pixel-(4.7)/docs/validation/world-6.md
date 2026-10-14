# Validação — World 6.0 "Mundo, visual, interface e feedback"

Data: 14/10/2026. Base: `8b40957 "ss"`. **Nenhum push feito por mim.** Nenhuma entrega está marcada como
aprovada: tudo aguarda o seu playtest. Mecânicas e balanceamento ficaram intocados: HP do Player, dano,
velocidade, alcance, ataque direcional, cursor, domesticação, IA de aliados e inimigos, dano dos
dinossauros, Elixir, armadilhas, torres, custos, recursos, Pontos de Defesa, territórios, duração do dia
e da noite, regras das ondas, tutorial e dificuldade.

Evidências em `world-6-evidence/`:
- `comparacao/antes` e `comparacao/depois`: capturas reais do Godot, com os mesmos enquadramentos;
- `comparacao/lado_a_lado`: as duas lado a lado (esquerda = antes, direita = depois);
- `perf-ab/`: JSON e logs de cada rodada de desempenho e a tabela `comparacao.md`;
- `final-headless/` e `final-window/`: relatório JSON e log de cada suíte;
- `visual_invariants_diff_vs_baseline_017A.log`: o que mudou em física/posições contra a linha de base antiga.

As capturas e medições "antes" foram feitas numa cópia exportada do commit de partida
(`git archive 8b40957`), com as mesmas ferramentas (`tools/world6_capture.gd`, `tests/perf_probe.gd`).

Legenda: **IMPL** = implementado; **AUTO** = testado automaticamente; **JANELA** = testado com janela;
**VISUAL** = conferido nas capturas; **PLAYTEST** = aguardando o seu playtest.

| Fase | IMPL | AUTO | JANELA | VISUAL | PLAYTEST |
|---|---|---|---|---|---|
| A — Auditoria e linha de base | sim | 30/30 sem janela | capturas "antes" (28) | sim | — |
| B — Barra de vida dos dinossauros | sim | `world6` (barras), `visual_overhaul3` | sim | 03, 03b, 14, 14b, 16, 17 | sim |
| C — Pegadas | sim | `world6` (pegadas) | sim | 13 | sim |
| D — Inventário fóssil | sim | `world6`, `inventory_ui`, `gameplay5` | sim | 02, 02b, 02c (2 resoluções) | sim |
| E — Menu fóssil centralizado | sim | `world6` (3 resoluções), `main_menu`, `visual_overhaul3`, `design5` | sim | 01 (2 resoluções) | sim |
| F/G — Plano e expansão do mapa | sim | `world6` (mapa), `visual_invariants`, `world_layout` | sim | 04, 05–12, 18, 20, 21–25 | sim |
| H — Cachoeira e vulcão | sim | `world6` (marcos, partículas, sem dano) | sim | 08, 09, 10, 12, 23 | sim |
| I — Navmesh e câmera | sim | `world6`, `navigation_contracts`, `tower_layout5`, `acceptance` | sim | 21–25 | sim |
| J — Polimento e desempenho | sim | — | medição A/B | — | sim |
| K — QA e documentação | sim | regressão completa | regressão com janela | — | — |

**Resumo dos testes (código final):**
- Sem janela: **31/31 suítes**, 987 verificações nas 29 que gravam relatório, **0 falhas**
  (4 puladas: só rodam com janela).
- Com janela: **32/32 suítes** (as 31 + `main_menu`), 1.003 verificações, **0 falhas**.
- Suíte nova `world6`: **70/70 com janela**; 67 + 1 pulada sem janela.

## 1. Estado inicial do Git

- `main` em `8b40957 "ss"` (seu commit, só evidências), igual a `origin/main`, árvore limpa.
- O editor do Godot ficou aberto o tempo todo (PID 20116, aberto às 8h52 de 13/10); não foi fechado.

## 2. Linha de base

- **30/30 suítes sem janela** antes de qualquer mudança.
- 28 capturas "antes" (`comparacao/antes`), geradas na cópia do commit de partida.
- Desempenho "antes" medido no fim, no mesmo A/B alternado do "depois" (item 26).

## 3. Barra de vida dos dinossauros

`scenes/visuals/creature_health_bar.gd` + `creature_health_bar.gdshader`: barra gráfica (shader), não
caracteres. Fica embaixo do rótulo, que continua com identificação e número (`ALIADO  ·  64/80`).

- Billboard sem luz e desenhada por cima da cena (legível de noite e atrás de folhagem), 1,2 × 0,17 m.
- Cores: aliado jade, selvagem terracota, guardião âmbar, invasor azul-violeta profundo.
- Fundo escuro, borda, trilho, marcas de 25 % e gradiente vertical.
- Dano: o número muda na hora; a barra desce suave, com um rastro claro do valor anterior e uma piscada.
- Cura: a barra cresce suave com brilho jade. O "+N HP" vem do próprio Elixir, que é a única fonte de
  cura de dinossauros (não criei um segundo texto).
- Valores reais de HP e a lógica de combate não foram tocados.

## 4. Regras de visibilidade

Em `hud.gd` (`_update_creature_labels`), por facção:
- **Aliado em foco:** sempre. **Outros aliados:** feridos e próximos, ou logo depois de levar dano/cura.
- **Selvagem:** só em combate (ferido ou atingido nos últimos 5 s) ou muito perto.
- **Guardião:** durante o confronto. **Invasor:** durante o combate.
- Prioridade (guardião > invasor > selvagem > aliado em foco > aliado ferido) e distância.
- No máximo **9 rótulos com texto**; criaturas sem espaço para o texto mostram **só a barra** (até 12).
  Assim, uma onda grande não cobre a tela.
- Rótulos um pouco maiores para a câmera estratégica (`pixel_size` 0,0065 → 0,0085).

## 5. Pegadas

`scenes/world/player_footprints.gd`: uma MultiMesh com **48 instâncias fixas** usada em anel (pool,
sem nó por passo, 1 chamada de desenho).
- Uma pegada a cada 0,85 m percorridos de verdade, alternando os pés, atrás dos pés e virada para a
  direção do movimento. Nada com o Player parado, morto ou teleportado; nada a cada quadro.
- Vida de 6 s, somem gradualmente nos últimos 2,5 s.
- Tom por superfície (`WorldBiomes.surface_at`): terra escura (floresta/campo), poeira sutil na pedra,
  marca úmida escura na margem da água, cinza revolvida no vulcão.

## 6. Inventário fóssil

Lógica, textos e abas **inalterados**; só o desenho mudou.
- Véu (`inventory_veil.gdshader`) escurece e dessatura o jogo, que continua visível e rodando
  (Spec 013D). Os cliques ficam na interface.
- A placa é uma laje de escavação: contorno irregular lascado, gradiente e manchas de pedra,
  rachaduras (duas com jade brilhando por dentro), vértebras, ossos cruzados, amonite, pegadas fósseis,
  marcas de garra e cristais de jade quebrando a borda. As decorações ficam só na faixa da borda.
- Abas como tabuletas com pinos de osso: RECURSOS (pedra + cristal), CONSTRUÇÕES (ferramenta),
  COMPANHEIROS (crânio). Conteúdo em nichos de pedra entalhada.
- Fichas de expedição dos aliados só com dados reais (número, tipo, barra + HP, SEGUINDO/FICAR, papel,
  golpe). O Elixir virou um frasco de espécime cujo líquido mostra o estoque real.
- Desenho compartilhado em `scenes/ui/fossil_ui.gd` (também usado pelo menu).

## 7. Menu

- **Todas as opções centralizadas** dentro de uma laje arqueológica da mesma família da mochila.
- Logo JADEFALL em pedra esculpida (extrusão, contorno, chanfro) com rachaduras e veios de jade
  recortados nas letras; subtítulo menor entre ossos fósseis.
- Botões de pedra com pontas de osso, filete de jade e ícones fósseis. Passar o mouse acende o jade e
  cresce um pouco a partir do centro; o clique afunda; foco de teclado em âmbar.
- JOGAR maior (420 × 70, jade); as demais opções com o mesmo tamanho e espaçamento (360 × 48).
- Fundo: diorama 3D com o mundo novo (item 7a).
- A mesma identidade em pausa, controles, configurações, créditos, derrota e conclusão do tutorial.
- Contrato alterado a pedido: a hierarquia passou a ser "JOGAR > todas as outras iguais"
  (`visual_overhaul3` e `design5` atualizados).

### 7a. Diorama do menu

Usa as mesmas cenas de arte do jogo, sem corpos nem navegação. Com o menu no centro, as bordas da tela
mostram a cachoeira e o lago (terço esquerdo), o vulcão com cratera, fumaça e linhas de lava (terço
direito), o aliado em primeiro plano, um selvagem andando, as torres do Refúgio, floresta e montanhas.
No menu, a arte das regiões (a mais de 20 m da câmera) fica sem sombra projetada, sem o sub-bosque rente
e sem as partículas das poças de lava.

## 8. Como centralizei

A coluna (logo, subtítulo, laje com os botões) é um `VBoxContainer` (`MenuColumn`) com alinhamento
central. A cada mudança de tamanho da janela, ela é escalada pela altura e reposicionada no centro
horizontal e vertical da tela; os botões ficam centralizados dentro da laje e crescem a partir do
próprio centro no hover (`pivot_offset`). O teste `world6` confere, em
1280×720, 1600×900 e 1920×1080, que cada botão e o logo estão centralizados e dentro da tela.

## 9. Dimensões antigas e novas

| | Antes | Depois |
|---|---|---|
| Limites (x / z) | ±24,2 / −24,2 a 28,2 | **±32 / −42 a 32** |
| Área andável | 48 × 52 m = 2.496 m² | **64 × 74 m = 4.736 m² (1,90×)** |
| Chão físico | 48 × 52, centro z = 2 | 64 × 74, centro z = −5 |
| Paredes | `Boundary0..3` em ±24,2 / 28,2 / −24,2 | mesmos nós, em ±32 / 32 / −42 |

Posições preservadas (conferidas por `visual_invariants`, 51 posições): spawn do Player (0; 1; −10),
Refúgio/território (0; 0; −15), ponto de spawn das ondas (0; 0,5; 23), entradas (−20; 2), (20; 2) e
(0; 23), os seis slots de torre, os marcos de território oeste (−14; 13) e leste (13; 16) e os
retângulos dos territórios. Nenhum marco antigo foi movido. O mapa antigo continua inteiro no centro
como referência.

## 10. Biomas

Quatro regiões reais, definidas em `scenes/world/world_biomes.gd` (fonte única: limites, centros,
lago, rio, córrego, cachoeira, poças de lava, cume do vulcão, trilhas de exploração):
**VULCÃO** ao sul (alto da tela), **PEDRA** a leste, **ÁGUA** a oeste, **FLORESTA** ao norte e oeste,
**Refúgio** no centro. Cada região tem chão próprio, peças próprias e um marco.

**Territórios:** os biomas **não** viraram territórios. Continuam só os três da Spec 015 (Refúgio,
Floresta Oeste, Região Rochosa); `world6` confere isso.

## 11. Floresta

Coníferas, araucárias, folhosas e samambaias arbóreas com alturas variadas; samambaias e musgo no pé
das árvores; cogumelos; troncos caídos; pedras com musgo; ruínas cobertas de mata (oeste e norte);
cristais discretos; chão de mata escuro. Copas acima de 1,9 m (não escondem o Player).

## 12. Pedra

Formações (agulhas, lajes, matacões) com líquen; **arco natural** sobre a trilha leste; **pequeno
cânion** (duas fileiras de agulhas acompanhando a trilha); minério (cristais na base das rochas);
cascalho; arbustos secos; ruínas de pedra; fóssil de crânio. Chão cinza-esverdeado com cascalho claro.

## 13. Água

Lago (−22,5; −22) com água estilizada (`stylized_water.gdshader`: movimento, azul/jade, espuma na
margem, reflexo controlado), duas ilhas (rocha, samambaias, árvore-jade), juncos e cavalinhas,
nenúfares, pedras molhadas na margem, rio raso da cachoeira ao lago e um córrego, ambos atravessáveis,
com pedras de travessia. Grama úmida mais escura e lama perto da água.

## 14. Cachoeira

No paredão oeste (−32; −31): paredão de rocha úmida em degraus com musgo, **queda principal e duas
quedas menores** (`waterfall.gdshader`: faixas que descem, espuma), poço com espuma embaixo,
**névoa com 22 partículas**, pedras molhadas e vegetação em volta, rio saindo para o lago. Decorativa:
o poço é bloqueado (não se entra na água funda), e `world6` confere que o Player chega à beira e sai
livremente.

## 15. Vulcão

Cone low-poly ao fundo (13; −66), fora da área andável: rocha escura, cinza no alto, contrafortes de
basalto, **cratera** com brilho (OmniLight sem sombra), **cinco linhas de lava** descendo pela face
voltada para o vale e **fumaça discreta (14 partículas)**. Nas primeiras capturas a base do cone
invadia a área andável sem colisão; a base foi estreitada (raio 21 m) e as linhas acompanham a encosta.

## 16. Região vulcânica

Chão de cinza escura com manchas de ferrugem e borda quente perto da lava; três **poças de lava
decorativas** (`lava.gdshader`: placas de crosta com fendas acesas que pulsam e escorrem) cercadas de
basalto e bloqueadas, com fagulhas e fumaça leves; fissuras incandescentes rentes; formações de
basalto agressivas; árvores queimadas; ossos (costelas e crânio); cristais escuros violeta; escória.
**Sem dano de lava**: nenhuma Area3D, nenhum corpo na arte (`world6` confere que o Player para na borda
e não perde vida). Paleta escura, não toda vermelha.

## 17. Transições

As peças são escolhidas por sorteio ponderado pelos pesos das regiões em cada ponto, então as bordas se
misturam: floresta → água (árvores de margem, vegetação úmida, chão escurece até a lama), floresta →
pedra (rochas com musgo, depois com líquen), pedra → vulcão (as rochas escurecem gradualmente até o
basalto), água → pedra (pedras molhadas). O chão usa pesos "afiados" (quadrado normalizado): cada
região lê com a própria cor e a passagem continua gradual.

## 18. Navmesh

- Rebake permitido e feito. Hash anterior `4834ED6228CE1F4C3681895CE9293B9F76E98C5A6334DEBDD3F600E98F0C76FB`;
  hash novo `AD1B74271AF23E57474E90B622E98AACAD5549A7B869BD374F400E768ADFFD8D` (758 vértices, 944 polígonos).
- `BiomeCollision` (82 sólidos) entrou no grupo `navigation_source`.
- **Problema encontrado:** com o mundo maior, a partição padrão (watershed) mudou o desenho dos
  polígonos no vale antigo e o A* passou a contornar árvores pelo lado mais longo na rota oeste
  (26,2 m em vez de 24,3 m), passando a 0,9 m do centro do slot WestInner. Com a partição em camadas
  (`LAYERS`), as três rotas voltaram ao comprimento antigo: **23,9 / 35,6 / 24,0 m** (antes
  24,3 / 35,6 / 24,0 m), com folga de 4,1 / 3,5 / 3,6 m até o slot mais próximo.
- **Ilhas:** os bloqueios grandes (lago, poço da cachoeira, poças de lava, rochas largas) ganharam um
  chapéu em cone mais íngreme que a rampa máxima do agente; nenhum vértice da navmesh fica acima do chão
  (`world_layout`).
- Validação (`world6`, `navigation_contracts`, `tower_layout5`, `acceptance`, `gameplay_stability`,
  `ally_combat`, `territory`): o Refúgio alcança 10 áreas novas; lago fundo e lava ficam fora; rio e
  córrego se atravessam (desvio 1,02 e 1,00); as três rotas das ondas ficam abertas e diretas; Player,
  aliados, selvagens, guardiões, invasores e ondas passaram nas suítes de regressão.

## 19. Câmera

A câmera estratégica não tem limites (segue o Player); com o mundo maior isso continua correto. Testei
nas cinco bordas (norte, oeste, leste, vulcão e cachoeira): o Player fica enquadrado e nada o encobre
(`world6` + capturas 21–25). O paredão norte já era baixo para a câmera. Não foi preciso fade. A borda
leste mostrava o fundo vazio entre o chão e as montanhas; um chão externo grosso e sem sombra resolveu.

## 20. Pipeline

`tools/build_first_map.gd` gera tudo, de forma determinística:
`refuge_art` → `valley_art` (chão por região, paredões nos limites novos, montanhas) → `flora_art` →
**`tools/build_biome_art.gd`** (novo: `scenes/visuals/biome_art.scn` + `scenes/world/biome_collision.tscn`)
→ `world_regions` (marcadores novos: `Biomes/*`, `Landmarks/Waterfall|Lake|Volcano`) → `arena_art`
(paredes). Depois, `tools/bake_navmesh.gd`. Nada foi editado só na cena final.

## 21. Materiais

Materiais compartilhados por tipo (um para as peças altas, um para as rentes, um para os cristais, um
para os cristais escuros, um para a lava, um para a água do lago e um para o rio). Shaders novos:
`stylized_water.gdshader`, `waterfall.gdshader`, `lava.gdshader`. A arte usa as mesmas paletas e o
mesmo acabamento facetado do vale (`Palette`, `Facets`, `Flora`).

## 22. Arquivos

Novos: `tools/build_biome_art.gd`, `scenes/visuals/biome_art.scn`, `scenes/world/biome_collision.tscn`,
`scenes/visuals/{stylized_water,waterfall,lava}.gdshader`, `scenes/visuals/creature_health_bar.{gd,gdshader}`,
`scenes/world/player_footprints.gd`, `scenes/world/world_biomes.gd`, `scenes/ui/fossil_ui.gd`,
`scenes/ui/inventory_veil.gdshader`, `tests/world6.{gd,tscn}`, `tools/world6_capture.{gd,tscn}`,
`tools/test_world6.ps1`, este relatório.
Alterados: `hud.gd`, `main.gd`, `menu_backdrop.gd`, `prototype_area.tscn`, geradores
(`build_first_map`, `build_valley_art`, `build_flora_art`, `build_refuge_art`, `bake_navmesh`), cenas
geradas, `arena_navmesh.tres`, testes (`visual_invariants` + linha de base, `world_layout`,
`tower_layout5`, `visual_overhaul3`, `design5`, `perf_probe`), `tools/perf_ab.ps1`.

## 23. Testes criados

`tests/world6.gd`: barras (cores por facção, dano, rastro, cura, visibilidade, limite de rótulos, noite),
pegadas (pool, alternância, direção, espaçamento, parado, fade, superfícies), inventário (abas, lógica,
véu, mundo rodando), menu (centralização em 3 resoluções, hierarquia, ícones) e mapa (limites, área,
chão nos cantos, regiões, marcos, partículas, sem dano, colisão, navmesh, água/lava, rotas, territórios,
paredes, lava, cachoeira, câmera).

## 24. Resultados sem janela

`final-headless/`: **31/31 suítes passaram** (`ally_combat`, `attack_direction`, `build_heal`,
`combat_balance`, `combat_collect`, `creature_motion`, `day_cycle`, `day_cycle_real`, `defense_economy`,
`domestication_regression`, `gameplay_stability`, `healing_actions`, `inventory_ui`,
`navigation_contracts`, `night_enemy_visual`, `physics_contracts`, `player_facing`, `player_health`,
`settings_ui`, `sky_cycle`, `territory`, `tutorial`, `visual_invariants`, `visual_overhaul3`,
`visual_overhaul4`, `world_layout`, `gameplay5`, `tower_layout5`, `design5`, `acceptance`, `world6`).
Linha de base: 30/30 (918 verificações); final: 31/31 (987 verificações, contando a `world6` nova).
Depois dos dois últimos ajustes (pegadas e espaçamento da barra), `world6`, `visual_overhaul3` e
`night_enemy_visual` foram reexecutados sem janela e com janela e passaram.

Testes que mudaram de contrato (de propósito, documentado no próprio arquivo):
- `visual_invariants`: linha de base regravada para o mundo expandido; o diff contra a antiga ficou em
  `visual_invariants_diff_vs_baseline_017A.log` (só `Boundary0-3` e `Ground` mudaram entre os sólidos
  antigos; **nenhuma posição de gameplay mudou**; o resto são sólidos e marcadores novos).
- `world_layout`: os marcadores do lago, da cachoeira e do vulcão e os centros de bioma não são destinos
  de caminhada (a chegada a cada região está em `world6`).
- `tower_layout5`: a rota termina no lado de chegada do Refúgio (como o invasor real, que para no slot
  de aproximação mais próximo), não no centro sólido dele.
- `visual_overhaul3` e `design5`: hierarquia do menu "JOGAR > demais iguais" (Fase E).

## 25. Resultados com janela

`final-window/`: **32/32 suítes passaram** (as 31 acima + `main_menu`), 1.003 verificações, 0 falhas.
Antes, na Fase E, `main_menu`, `visual_overhaul3`, `visual_overhaul4` e `design5` também passaram com
janela com o diorama novo.

## 26. FPS médio

Medido com janela, 1920×1080, sem vsync, Intel Iris Xe (Compatibility), editor do Godot aberto nos
dois lados. Rodadas alternadas (depois, antes, depois, antes), 8 s por cenário, média das 2 rodadas
(`perf-ab/comparacao.md`, JSON em `perf-ab/`). Cenários `vivo_*` com o jogo rodando (IA, torres, ondas).

| Cenário | FPS médio antes | FPS médio depois | 1 % pior antes | 1 % pior depois | draws antes | draws depois |
|---|---|---|---|---|---|---|
| menu_principal | 98,9 | 89,6 | 20,6 | 17,1 | 282 | 533 |
| padrao_1200 | 121,1 | 117,2 | 36,4 | 36,4 | 274 | 318 |
| padrao_1730 | 132,6 | 127,0 | 43,0 | 45,3 | 265 | 299 |
| padrao_2100 | 129,8 | 115,9 | 39,2 | 36,7 | 235 | 277 |
| refugio_1200 | 123,0 | 118,0 | 37,1 | 36,5 | 269 | 313 |
| slot_oeste_2100 | 125,6 | 125,2 | 38,5 | 40,6 | 278 | 319 |
| vivo_dia_dinos | 114,2 | 116,9 | 39,6 | 46,5 | 340 | 373 |
| vivo_tutorial | 143,2 | 121,9 | 56,6 | 51,6 | 240 | 279 |
| vivo_noite_3_torres_aliado | 103,3 | 104,6 | 36,1 | 36,9 | 401 | 440 |
| vivo_noite_3_inventario | 100,7 | 85,4 | 42,0 | 45,4 | 568 | 814 |
| vivo_noite_6torres_nivel3 | 105,0 | 107,1 | 53,3 | 55,5 | 450 | 397 |
| vivo_noite_10_torres | 95,5 | 81,7 | 50,9 | 42,8 | 691 | 729 |
| vivo_noite_10_torres_3aliados | 94,3 | 89,6 | 38,6 | 37,2 | 592 | 609 |
| vivo_gameplay5_6torres_5armadilhas_3aliados | 95,1 | 93,8 | 41,6 | 35,2 | 521 | 565 |
| dia_6torres_nivel3 | 108,2 | 104,1 | 49,6 | 51,9 | 500 | 524 |

Regiões novas (só o "depois" vale; no projeto antigo esses pontos ficam além das paredes):

| Vista (câmera de jogo) | FPS médio | 1 % pior | draws |
|---|---|---|---|
| w6_floresta_1200 | 125,8 | 44,5 | 380 |
| w6_lago_1200 | 124,4 | 39,6 | 298 |
| w6_cachoeira_1200 | 139,2 | 45,6 | 258 |
| w6_pedra_1200 | 125,5 | 41,4 | 280 |
| w6_vulcao_1200 | 148,6 | 46,3 | 203 |

Outros números (média das 2 rodadas):

| | Antes | Depois |
|---|---|---|
| Carregar o jogo (menu → mundo) | 284 ms | 340 ms |
| Carregar o menu (primeiro quadro) | 2.246 ms | 2.431 ms |
| Memória estática (vista padrão) | 58,7 MB | 61,4 MB |
| Memória de vídeo (vista padrão) | 45,2 MB | 59,2 MB |
| Objetos visíveis (vista padrão) | 188 | 232 |
| Primitivas (vista padrão) | 116.750 | 134.424 |

## 27. Pior 1 %

Na mesma tabela (colunas "1 % pior").

## 28. Draw calls antes e depois

Na mesma tabela (colunas "draws").

**Leitura honesta:**
- No jogo, com o mapa 1,9× maior, o FPS médio caiu de 0 a 11 % na maioria das vistas (algumas ficaram
  iguais ou melhores, dentro do ruído). Os piores casos foram o tutorial (−15 %), a onda de 10 com
  torres (−14 %) e o inventário aberto (−15 %). O **pior 1 % ficou praticamente igual**, e as vistas
  ganharam de +30 a +45 draw calls. O culling por blocos (5 × 6 na arte dos biomas, 6 × 6 no chão)
  evita desenhar as regiões fora da tela.
- **Não afirmo 60 FPS constantes:** nos cenários de jogo, o pior 1 % nesta máquina fica entre 35 e
  56 FPS, antes e depois. O FPS médio fica acima de 80 em todos os cenários medidos.
- **Menu:** é o que mais subiu em draw calls (282 → 533), porque o diorama agora mostra o mundo inteiro
  até o vulcão. O FPS médio caiu cerca de 9 % (98,9 → 89,6) e o pior 1 % é dominado pelos engasgos do
  primeiro carregamento (quadro máximo de 160–240 ms nos dois lados). Já tirei as sombras, o sub-bosque e
  as partículas da lava do diorama.
- **Inventário aberto:** 568 → 814 draw calls (a placa fóssil desenhada por código e o véu com textura de
  tela); FPS médio 100,7 → 85,4.
- A primeira rodada A/B foi descartada (`perf-ab-contaminado/`): três processos meus travados estavam
  renderizando ao mesmo tempo. Os números acima são da rodada limpa.

## 29. Bugs encontrados e corrigidos

1. **Base do vulcão dentro da área andável** (o cone visual invadia ~8 m sem colisão): base estreitada.
2. **Partículas quadradas** (névoa, fumaça, fagulhas): textura radial suave.
3. **Lava escura com "pintas"** (o shader acendia o centro das células): fendas acesas entre placas.
4. **Fundo vazio visível na borda leste:** chão externo.
5. **Torre de vigia do Refúgio** passou a ficar dentro do mundo sem colisão: ganhou sólido.
6. **Ilhas na navmesh** em cima do lago e das poças de lava: bloqueios com chapéu em cone.
7. **Rota oeste mais longa** com a navmesh nova (watershed): partição em camadas.
8. **Teste de barra dependente do quadro:** o rastro da barra desce por tempo; o teste passou a esperar
   tempo real (antes falhava com a máquina carregada).
9. **Medição "antes" sem arquivo:** o caminho relativo era resolvido dentro da cópia antiga; o
   `perf_ab.ps1` passou a usar caminho absoluto.
10. **Processos travados meus** (um gerador antigo e duas medições "antes") contaminaram a primeira
    rodada de desempenho; foram encerrados e o A/B foi refeito do zero (a rodada contaminada ficou em
    `perf-ab-contaminado/`, só como registro).
11. **Pegadas quase invisíveis da câmera de jogo** (corretas, mas pequenas e claras demais): sola
    ≈1,3× maior e opacidade maior por superfície (pedra continua a mais sutil; margem úmida, a mais
    escura).
12. **Barra de vida encostando no texto** do rótulo à distância de jogo: barra uma linha inteira abaixo
    do centro do rótulo; os retângulos anti-sobreposição acompanharam.
13. **Teste de rotas medindo até o centro sólido do Refúgio** (`tower_layout5`): passou a medir até o
    lado de chegada, como o invasor real.

## 30. Limitações

- **Desempenho do menu e do inventário** (item 28): ficaram mais caros em draw calls. Se no seu
  playtest o menu ou a mochila parecerem pesados, os próximos passos são juntar os desenhos da placa
  fóssil num único `draw` cacheado e encurtar o alcance do diorama.
- **Pior 1 % abaixo de 60** nesta máquina (antes e depois); não foi um objetivo desta atualização mexer
  nisso.
- **Água e lava:** água estilizada sem reflexo real (só brilho controlado no shader), como pedido; a
  lava é só visual, sem dano, por regra.
- **Regiões sem mecânica nova:** como pedido, a exploração não dá recompensas novas; minério e cristais
  das regiões novas são cenário (não são coletáveis).
- **Rios:** o rio e o córrego são rasos e andáveis (não há natação); só a água funda (lago e poço da
  cachoeira) bloqueia.
- **Navmesh:** a partição em camadas mudou o desenho dos polígonos no mapa todo. As três rotas e todas as
  suítes de IA passaram, mas só o seu playtest confirma a "sensação" das rotas.
- **Capturas em 1600×900:** a centralização do menu foi testada automaticamente em 1280×720, 1600×900 e
  1920×1080; as capturas de menu e inventário estão em 1280×720 e 1920×1080.
- **Os biomas não são territórios** (regra sua); o HUD de território continua mostrando 1/3.

## 31. Capturas

Pasta `world-6-evidence/comparacao/`: 28 capturas "antes", 34 "depois" e 28 composições lado a lado.

| Pedido | Arquivo |
|---|---|
| Menu antes/depois (com o mundo novo) | `01_menu_1280.png`, `01_menu_1920.png` |
| Inventário antes/depois | `02_inventario_*`, `02b_inventario_companheiros_*`, `02c_inventario_construcoes_*` |
| HUD de dinossauro antes/depois | `03_hud_dinossauro_aliado_cheio.png`, `03b_hud_dinossauros_varios.png` |
| Visão geral antes/depois | `04_visao_geral_mapa.png`, `04b_gameplay_dia.png` |
| Floresta, pedra, água | `05_floresta.png`, `06_pedra.png`, `07_agua.png` |
| Cachoeira | `08_cachoeira.png` |
| Vulcão e região vulcânica | `09_vulcao.png`, `10_regiao_vulcanica.png` |
| Transições floresta → água e pedra → vulcão | `11_transicao_floresta_agua.png`, `12_transicao_pedra_vulcao.png` |
| Pegadas | `13_pegadas_player.png` (câmera de jogo), `13b_pegadas_vista_de_cima.png` |
| Aliado cheio / ferido / curado | `14_aliado_barra_cheia.png`, `14b_aliado_ferido.png`, `16_aliado_curado.png` |
| Onda noturna | `17_onda_noturna.png`, `17b_onda_noturna_alto.png` |
| Refúgio no mapa expandido | `18_refugio_mapa_expandido.png` |
| Visão dos quatro biomas | `20_quatro_biomas.png` |
| Câmera nas bordas | `21_camera_borda_norte.png` … `25_camera_borda_oeste.png` |

Nas capturas "antes" das regiões novas, a câmera mostra o que existia no mesmo lugar (paredões e o
vazio além deles).

## 32. Commits

Todos locais, na `main`, **nenhum enviado**:

| Commit | Conteúdo |
|---|---|
| `68f3b50` | feat(creatures): barra de vida gráfica com cores por facção e visibilidade inteligente |
| `1bc6ad6` | feat(player): pegadas em pool que seguem o movimento real, por superfície |
| `3a71d4c` | feat(ui): mochila fóssil de expedição |
| `84cbacc` | feat(ui): menu fóssil centralizado e telas modais fósseis |
| `284215b` | feat(world): mundo de 64 × 74 m com floresta, pedra, água e vulcão (+ navmesh) |
| `e25942b` | test(world): testes do mapa expandido e linha de base nova documentada |
| `217ee36` | feat(ui): diorama do menu mostra o mundo novo |
| `1f745f4` | fix(player): pegadas legíveis da câmera estratégica |
| `61bc56c` | perf(ui): arte dos biomas mais leve no diorama do menu |
| `d8698e1` | fix(hud): barra de vida afastada do texto do rótulo |
| último | docs(world): relatório World 6.0, evidências, ferramentas de captura e medição |

## 33. Estado final do Git

- `main` 11 commits à frente de `origin/main` (`8b40957`), **sem push**.
- Árvore limpa depois do último commit; não usei `reset --hard`, `clean`, `restore .` nem nada destrutivo.
- O editor do Godot (PID 20116) continua aberto. Os processos travados que eu mesmo criei (um gerador
  antigo e duas medições) foram encerrados; nenhum processo seu foi tocado.
- A cópia "antes" (`%TEMP%\w6b`) fica fora do repositório.

## 34. Roteiro de playtest

1. **Menu:** abra o jogo em 1280×720 e 1920×1080. Todas as opções no centro? JOGAR em destaque? Passe o
   mouse e clique: o brilho e a pressão parecem bons? O fundo mostra a cachoeira e o vulcão?
2. **Pausa, controles, configurações, créditos:** mesma identidade fóssil?
3. **Barras de vida:** domestique um dinossauro, deixe-o levar dano e use o Elixir. Número na hora, barra
   descendo suave, cura com brilho jade e "+N HP"? Cores certas por facção? Numa onda grande, a tela fica
   limpa?
4. **Pegadas:** ande pela floresta, pela pedra, pela beira da água e pela cinza. Pegadas alternadas,
   atrás dos pés, somem devagar? Nada parado?
5. **Inventário (I):** o jogo continua visível e rodando atrás? As três abas, as fichas dos aliados e o
   frasco do Elixir estão legíveis?
6. **Mapa:** saia do vale nas quatro direções. Cada região parece um lugar diferente? As transições
   parecem naturais? A cachoeira e o vulcão funcionam como marcos? Você fica preso em algum lugar?
7. **Lava e água:** encoste na lava (não deve dar dano) e na beira do lago e do poço da cachoeira (não
   deve prender). Atravesse o rio e o córrego.
8. **Câmera:** vá até as bordas. O Player fica sempre visível?
9. **Noite:** jogue uma noite inteira. As três rotas parecem as de antes? Torres, armadilhas, aliados e
   o Refúgio se comportam igual?
10. **Desempenho:** o jogo continua fluido na sua máquina, inclusive no menu?

**Quando terminar, eu paro e aguardo o seu playtest. Nada foi enviado ao GitHub.**
