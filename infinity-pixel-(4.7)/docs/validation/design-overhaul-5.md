# Validação — Design Overhaul 5.0 "Torres, menu, HUD, materiais e luz"

Data: 13/10/2026. Base: `d76c8dd`. **Sem push feito por mim.** Nenhuma Spec marcada como aprovada;
tudo aguarda o playtest manual. Mecânicas e balanceamento intocados (dano, vida, velocidade, ataque
direcional, cursor, domesticação, IA, ondas, custos, armadilhas, Elixir e cooldown, posições e
alcance das torres, territórios, duração do dia/noite, regras do tutorial).

Evidências em `design-5-evidence/`:
- `comparacao/antes` e `comparacao/depois`: capturas reais do Godot, mesmos enquadramentos;
- `comparacao/lado_a_lado`: as duas lado a lado (esquerda = antes, direita = depois);
- `desempenho/`: JSON de cada medição.

As capturas "antes" foram feitas numa cópia exportada do commit de partida (`git archive d76c8dd`),
com a mesma ferramenta (`tools/design5_capture.gd`).

## Estado de cada entrega

| Fase | Implementado | Validado automaticamente | Validado com janela | Aguardando playtest |
|---|---|---|---|---|
| A — Auditoria | sim | linha de base 29/29 sem janela | capturas e medição "antes" | — |
| B — Torres (3 níveis) | sim | `design5` (malhas, troca, disparo, colisor, tabela), `defense_economy`, `sky_cycle`, `tower_layout5` | capturas 05–11, 14, 15 | sim |
| C — Materiais | sim | `design5` (grão, compartilhamento, criaturas intactas), `visual_invariants` | capturas | sim |
| D — Menu | sim | `design5`, `visual_overhaul3`, `main_menu` (com janela) | 01, 01b–01f; 4 resoluções | sim |
| E — HUD | sim | `design5` (vitais, Elixir, painel da torre, layout 3 resoluções) | 02, 02b, 15 | sim |
| F — Inventário | sim (harmonização) | `inventory_ui`, `gameplay5` | 12, 12b | sim |
| G — Mundo e luz | sim (parcial, ver pendências) | `sky_cycle`, `night_enemy_visual`, `visual_invariants` | 09, 10, 13, 14b, 15b | sim |
| H — QA | sim | regressão completa (abaixo) | regressão com janela | — |

**Resumo dos testes:**
- Sem janela: **30/30 suítes, 989 verificações, 0 falhas**.
- Com janela: **31/31 suítes**, contando o `player_facing` reexecutado (ver itens 13–14).
- Suíte nova `design5`: **80/80 com janela** (67 sem janela; as 13 de layout só rodam com janela).

## 1. Estado inicial do Git

- `main` em `d76c8dd "cccc"`, igual a `origin/main`, árvore limpa. Você já tinha publicado os commits
  da 5.0 de gameplay, junto com as pastas `.codex-build/`, `.codex-finalizer/`, `output/` e `tmp/`.
- Durante a sessão você fez commits próprios: `1b51c93 "s"`, `b8b1d13 "eee"`, `dbcdf98 "dd"` e
  `240444a "cc"`. Eles levaram parte do meu trabalho ainda não commitado (menu, otimização da placa
  talhada, ablação do medidor, captura em câmera lenta) e evidências. Mantive tudo como está; nada foi
  reescrito. A branch aparece sincronizada com `origin/main`, ou seja, esses commits foram enviados por
  você; eu não fiz nenhum push.
- Linha de base: **29/29 suítes sem janela** (`design-5-evidence/baseline-headless`).
- O editor do Godot ficou aberto (PID 20116, desde as 8h52) durante todas as medições, antes e depois.

## 2. Como interpretei a imagem de referência

**A imagem das cinco torres não chegou**: não veio na mensagem e não estava em nenhuma pasta recente.
Segui a descrição escrita do pedido: bases robustas, corpos verticais altos, pedra e madeira, partes
superiores distintas, vegetação integrada, equipamento de defesa visível e silhueta legível de longe.
Não copiei nenhum modelo. Se você enviar a imagem, ajusto proporções e silhuetas.

## 3. Arquitetura das novas torres

Uma família só (`scenes/visuals/tower_forge.gd`), gerada por código em low-poly facetado com cor por
vértice. Cada nível tem uma malha compartilhada por todas as torres.

- **Base:** plinto octogonal e pedras de fundação com musgo. Alvenaria em fiadas desencontradas,
  feita de blocos chanfrados individuais (juntas, desgaste, tons variados). Porta recuada de tábuas
  com soleira, ombreiras e verga, ou arco de aduelas. Amonite fóssil sobre a porta.
- **Corpo:** pilares e madeira de sustentação amarrada com corda. Contrafortes escalonados, runas de
  jade em glifos, galeria de tábuas (L2) e janelas acesas (L3).
- **Topo:** plataforma defensiva (deck com paliçada de estacas no L1; parapeito com ameias no L2/L3)
  e o **mecanismo de disparo, que gira para o alvo**:
  - L1: balista de madeira;
  - L2: besta de costelas fósseis;
  - L3: coroa de presas com o grande cristal e três lascas em órbita.
- **Animações (só apresentação):**
  - mecanismo voltado para o alvo (varredura lenta sem alvo);
  - cristal pulsando e "carregando" nos 0,22 s antes do disparo (lê `_cooldown`, não o altera);
  - recuo e clarão no **mesmo quadro** do disparo real, faísca na boca;
  - a lasca nasce no cristal (distância medida: 0,000 m);
  - ao melhorar, o modelo novo "cresce" do plinto, com lascas jade, coluna de luz e anel âmbar.
- **Intocados:** colisor (cilindro 0,8 × 2,4 m, camada 4), obstáculo de navegação, dano, alcance,
  cadência, custos, alvo, tempo de voo da lasca e posições dos 6 slots.
- **Limites de espaço:** entre 0,32 e 2 m de altura nada sai de 1,02 m do eixo (medido 0,83 / 0,90 /
  0,99 m). Rente ao chão, as pedras de fundação ficam sobre o plinto do slot (até 1,13 m; o plinto tem
  1,24 m).

## 4. Diferenças entre os três níveis

| | Sentinela do Jade (L1) | Guardiã do Vale (L2) | Bastião Ancestral (L3) |
|---|---|---|---|
| Corpo | alvenaria baixa (4 fiadas) + quadro de madeira com mãos-francesas em X | alvenaria alta (6 fiadas), 4 contrafortes, faixa de runas | alvenaria alta (8 fiadas), 8 contrafortes, duas faixas de runas, janelas acesas |
| Porta | verga reta + amonite | arco de aduelas + amonite | portal em arco + crânio de ceratopsídeo |
| Topo | deck de tábuas, paliçada de estacas, garras fósseis | galeria de tábuas sobre mísulas, parapeito com ameias, 4 chifres fósseis | cornija de mísulas, parapeito, 4 pináculos com cristais, estandartes |
| Mecanismo | balista de madeira, cristal pequeno | besta de costelas, cristal médio com lascas | coroa de presas, cristal grande, 3 lascas em órbita |
| Triângulos (corpo) | 2.758 | 5.038 | 5.804 |
| Cristal (altura) | 2,70 m | 3,24 m | 3,44 m (pináculos até ~3,35 m) |

## 5. Materiais e texturas

- **Pedra, madeira e chão** (`scenes/visuals/surface_finish.gd`):
  - grão procedural de 128 px (FastNoiseLite, gerado no jogo, sem arquivo externo nem licença de
    terceiros), aplicado como *detail* multiplicativo em projeção triplanar no espaço do mundo;
  - dá desgaste, manchas e variação de tom sem UV e sem esticar;
  - materiais com os mesmos parâmetros viram **um só** (225 malhas → 11 materiais);
  - ficam de fora: materiais com emissão, transparentes e tudo dentro de criaturas e do Player.
- **Torres:** pedra com chanfro claro (aresta gasta), base escura (oclusão), musgo nas faces de cima;
  madeira com topo claro e veio estilizado; corda, ferro e marfim fóssil próprios.
- **Cristais:**
  - emissão em jade profundo (`#1f8a66`), com energia de 0,45 de dia e 1,65 à noite;
  - antes, à noite, o cristal estourava em branco (`#7fd8b0` × 2,2); agora fica contido (capturas 10 e 08b);
  - transparência não usada (custo de ordenação); a profundidade vem de facetas alternadas e degradê.
- **Normal maps:** não usados. No modo toon eles quebram as faixas de luz e não agregavam valor real.
- **Vegetação:** o grão e o ajuste de cor dão variedade sem saturar mais. As cores de folhagem estão
  embutidas em `flora_art.scn` e não foram regeneradas.
- **Personagens e dinossauros:** identidade preservada. Mudou só o contorno de luz dos invasores
  noturnos (0,3 → 0,55), para separá-los do chão escuro. O corpo continua sem emissão (teste
  `night_enemy_visual`).

## 6. Novo layout do menu

- O diorama 3D ocupa a tela toda, com faixas de cinema no alto e no rodapé e vinheta.
- **Diorama:** câmera reenquadrada e luz de fim de tarde lateral (contorno quente, sombra fria).
  - Composição: o Refúgio à direita do centro, a Guardiã (L2) ao fundo, o Bastião (L3) à direita
    (torres só de vitrine, sem corpo físico) e o aliado em idle em três-quartos.
  - Movimento: fagulhas, poeira de jade e câmera em balanço lento.
  - Sem partida carregada: só arte.
- **Logotipo:** JADEFALL em relevo (extrusão, contorno, bisel claro e sombra), num lintel de pedra
  talhada com musgo, rachaduras e filete jade. Um medalhão com o cristal e ossos fósseis cruzados sela
  a ponta. O subtítulo fica numa faixa de tecido jade com bordas âmbar. Fonte embutida Lilita One (OFL).
- **Estela de pedra** com a hierarquia **JOGAR** (placa âmbar grande) > **TUTORIAL** (placa jade
  média) > CONTROLES / CONFIGURAÇÕES / CRÉDITOS / SAIR (iguais, menores).
  - Cada botão tem ícone próprio, divisor talhado, brilho jade no hover, avanço curto, afunda no
    clique, contorno âmbar no foco e seta no hover.
  - A coluna escala com a altura da janela (960×540 a 1920×1080 testados).
- **Telas relacionadas** (pausa, configurações, controles, créditos, derrota, fim do tutorial):
  mesma pedra talhada; a ação principal (Retomar, Reiniciar, Jogar partida) em placa âmbar.
- Configurações salvas e controles não foram alterados.

## 7. Novo layout da HUD

- **Vitais:**
  - medalhão do explorador (brasa) e do Refúgio (cristal), barras talhadas com marcas a cada 10%;
  - "rastro" claro do dano recente, medalhão piscando ao levar dano;
  - estado crítico com anel pulsando em brasa (Jogador < 30%, Refúgio < 35%), sem piscar a tela;
  - textos iguais aos de antes.
- **Ciclo:** o sol (dia) ou a lua com estrelas (noite) percorre um arco com a fração real do período,
  âmbar ou violeta. Relógio, "PREPARAÇÃO/DEFESA", onda e contagem final continuam. A borda do painel
  vira âmbar na contagem e violeta à noite.
- **Recursos:** fichas próprias, com hierarquia:
  - Defesa em destaque;
  - Madeira e Pedra;
  - Territórios e **Elixir de Jade** menores (o Elixir aparece a partir do Dia 2 com o estoque real 0/1 ou 1/1);
  - ESC desenhado como tecla.
- **Contexto (embaixo):** mais compacto; a linha de dica e a barra só aparecem quando há o que mostrar.
- **Torre:**
  - ícone, título, losangos de nível;
  - dano, alcance e cadência reais (tabela `LEVELS`);
  - prévia do próximo nível e "Faltam N Pontos de Defesa";
  - as torres não têm vida no sistema, então não há barra de vida.
- **Criaturas:** barra de vida compacta sob o rótulo (aliado jade, guardião âmbar, invasor violeta),
  com a mesma prioridade e visibilidade do rótulo. Texto e alertas dos invasores iguais.
- Sem cortes, sobreposições nem elementos fora da tela em 1280×720, 1600×900 e 1920×1080 (teste com janela).

## 8. Inventário

Não foi reconstruído:
- cartões em pedra talhada, cartão do Elixir na mesma placa;
- abas e botões herdam o estilo novo.

Continua sem pausar (Spec 013D); cursor e bloqueio de cliques sem regressão (`physics_contracts`,
`inventory_ui`, `design5`).

## 9. Iluminação

- **Meio-dia:** mais sol direto (0,72–0,74, sob o teto de 0,8), ambiente 0,32 → 0,30 e menos névoa
  (0,0025 → 0,0018). O resultado é mais volume e sombra.
- Mantida a regra da Spec 014: o ambiente do dia ≥ 1,4× o da noite. Tentei 0,28 e o teste reprovou;
  corrigi o valor, não o teste.
- **Ajuste de cor:** contraste 1,07 e saturação 1,06 foram testados no jogo e **removidos** (custavam
  ~0,9 ms de GPU, ver item 15–16). Ficaram só no diorama do menu.
- **Noite:** mesma, com cristais contidos; torres identificáveis pelos cristais, runas e anéis;
  invasores com contorno violeta mais forte.
- Horários e durações do `DayNightManager` não mudaram.

## 10. Cenário

- Grão de superfície em toda a arte do mundo (paredões, chão, trilhas, rochas, Refúgio, marcos,
  fogueira, armadilhas e pontos de defesa).
- Bases das torres novas; luz de meio-dia.
- Nenhuma decoração nova no mapa.
- Navmesh, colisões e posições intactas (`visual_invariants`: hashes iguais).
- **Tentado e revertido:** um leito de lascas de cristal em volta do cristal do Refúgio. Ele violava
  a regra do chão andável (peças acima de 0,3 m fora de sólido) e o script do Refúgio é reaproveitado
  pela arte do vale, o que o duplicava. Restaurei o arquivo original.

## 11. Arquivos

- **Novos:**
  - `scenes/visuals/tower_forge.gd`, `scenes/visuals/surface_finish.gd`, `scenes/ui/carved_style.gd`;
  - `tests/design5.gd/.tscn`;
  - `tools/design5_capture.gd/.tscn`, `tools/test_design5.ps1`, `tools/perf_summary.ps1`,
    `tools/perf_ab.ps1`, `tools/perf_compare.ps1`.
- **Alterados:**
  - `scenes/world/defense_tower.gd` (só o visual), `scenes/world/build_placer.gd` (acabamento ao
    construir), `scenes/world/day_night_visual.gd` (chaves de luz + ajuste de cor);
  - `scenes/ui/main.gd`, `scenes/ui/hud.gd`, `scenes/ui/ui_art.gd`, `scenes/ui/menu_backdrop.gd`;
  - `scenes/visuals/actor_visual.gd` (contorno do invasor);
  - `tests/perf_probe.gd` (cenários com 6 torres L3 e `--ablate`).
- **Contrato de teste alterado de propósito:** `tests/visual_overhaul3.gd`. Antes: "todos os
  secundários iguais, JOGAR maior". Agora: "JOGAR > TUTORIAL > demais iguais" (hierarquia pedida).

## 12. Comparações antes/depois (`comparacao/lado_a_lado/`)

| Arquivo | Conteúdo |
|---|---|
| 01 | menu em 1920 e 1280 |
| 01b–01f | configurações, créditos, controles, pausa, derrota |
| 02, 02b | HUD de dia e com o painel da torre, em 1280, 1600 e 1920 |
| 05, 06, 07 | torre L1, L2 e L3 (mesmo enquadramento) |
| 08 / 08b | os três níveis lado a lado, de dia e à noite |
| 09, 10, 11 | torre de dia, à noite e disparando (em 0,2× só na foto, para a lasca aparecer) |
| 12, 12b | inventário |
| 13 | Refúgio |
| 14 / 14b | gameplay com seis torres e o vale do alto |
| 15 / 15b | onda noturna |

## 13–14. Testes

**Sem janela** (`design-5-evidence/final-headless`): **30/30 suítes, 989 verificações, 0 falhas**.
As suítes cobrem:
- combate, aliados e domesticação;
- torres, armadilhas e Elixir;
- inventário, HUD, menu, configurações e cursor;
- construção, tutorial, territórios, dia/noite e navegação;
- invariantes visuais, aceitação e a nova `design5`.

**Com janela** (`final-window`): 31 suítes.
- 30 passaram na primeira rodada.
- `player_facing` reprovou 13 de 38 verificações (só os casos de teclas combinadas W+A/S+D/S+A)
  na rodada longa.
- Reexecutado isolado duas vezes, passou **38/38** nas duas (`final-retry-window`).
- Esse teste injeta teclas e depende do foco da janela, e nada desta reforma mexe em movimento.
  Registro como instabilidade de foco, não como regressão.
- Total aprovado com janela: 1.032 verificações. Inclui `main_menu` (27/27) e `design5` (80/80, com o
  layout da HUD e do menu em 1280×720, 1600×900, 1920×1080 e 960×540).

**Suíte nova `tests/design5.gd`** verifica:
- modelo correto por nível e troca visual na melhoria;
- mecanismo voltado ao alvo e lasca saindo do cristal;
- colisor e tabela de jogo idênticos aos originais;
- materiais com grão (criaturas intactas, emissivos fora);
- menu sem fundo duplicado, hierarquia, estados e ação dos botões;
- ícones novos desenhados;
- vitais com rastro de dano, estado crítico, ficha do Elixir e painel da torre com dados reais;
- barra das criaturas, cursor (jogo, mochila, pausa);
- HUD sem cortes nem sobreposição nas 3 resoluções;
- integridade das malhas geradas (orçamento de triângulos, nada fora do raio, nada enterrado, cache).

## 15–16. Desempenho

**Condições:** Intel Iris Xe, gl_compatibility, vsync desligado, janela 1920×1050, 8 s por cenário.
"Antes" = cópia do commit de partida `d76c8dd`, com o mesmo `perf_probe`. As rodadas foram
alternadas (depois, antes, depois, antes) e a tabela mostra a média de duas rodadas
(`desempenho/ab_final4`). O editor do Godot estava aberto nas duas medições.

**Investigação:**
1. **Primeira medição** (`ab_pre_otimizacao`): queda de ~25–30% no FPS médio nas vistas estáticas.
   - O 3D não mudou (188 chamadas visíveis antes e depois).
   - A interface nova tinha ~120 chamadas de desenho a mais: cada placa talhada emitia dezenas de
     comandos 2D.
   - **Correção:** uma malha de triângulos por placa.
2. **Ablação intercalada** (`ablacao/ablacao_intercalada.json`, vista padrão às 12:00, duas repetições):

   | Configuração | FPS médio | GPU |
   |---|---|---|
   | Referência | ~132 | 6,4 ms |
   | Sem ajuste de cor | ~146–157 | −0,9 ms |
   | Sem grão | ~141 | −0,5 ms |
   | Sem HUD | ~135 | −0,15 ms |

   - O ajuste de contraste/saturação foi **removido do jogo** (no Compatibility é uma passada de tela
     inteira). O grão ficou, pelo ganho visual.
3. **Faísca na boca do mecanismo:** criava nós e materiais a cada disparo. **Removida.**
4. **Interrupção da sessão:** as rodadas `ab_final` (corrompida pela queda: leituras de 0 FPS e uma
   rodada sem resultado), `ab_final2` e `ab_final3` ficaram como histórico. Os números finais são os
   de `ab_final4`.

**Resultado final (média de 2 rodadas):**

| Cenario | FPS medio antes | FPS medio depois | 1% pior antes | 1% pior depois | draws antes | draws depois |
|---|---|---|---|---|---|---|
| dia_6torres_nivel3 | 143.3 | 126.4 | 94.6 | 85.6 | 480 | 516 |
| menu_principal | 132.3 | 108.4 | 27.8 | 21.8 | 256 | 282 |
| padrao_1200 | 160.8 | 135.7 | 53.6 | 44.0 | 244 | 274 |
| padrao_1730 | 187.5 | 162.4 | 63.5 | 56.8 | 235 | 265 |
| padrao_2100 | 176.7 | 158.8 | 57.3 | 52.1 | 202 | 235 |
| refugio_1200 | 162.7 | 145.8 | 54.6 | 47.0 | 239 | 269 |
| slot_oeste_2100 | 175.8 | 157.9 | 58.0 | 52.4 | 245 | 278 |
| vivo_dia_dinos | 156.9 | 137.9 | 74.9 | 59.2 | 309 | 340 |
| vivo_gameplay5_6torres_5armadilhas_3aliados | 136.7 | 120.8 | 66.4 | 57.5 | 464 | 502 |
| vivo_noite_10_torres | 125.8 | 110.3 | 65.3 | 55.9 | 644 | 689 |
| vivo_noite_10_torres_3aliados | 125.7 | 105.6 | 54.9 | 46.9 | 546 | 586 |
| vivo_noite_3_inventario | 140.9 | 121.0 | 78.0 | 70.9 | 537 | 568 |
| vivo_noite_3_torres_aliado | 137.9 | 126.1 | 45.9 | 50.7 | 366 | 402 |
| vivo_noite_6torres_nivel3 | 132.3 | 118.1 | 86.4 | 81.7 | 473 | 513 |
| vivo_tutorial | 178.1 | 151.1 | 88.8 | 67.9 | 212 | 240 |

**Leitura:**
- **FPS médio:** acima de 60 em todos os cenários, antes e depois. O menor valor depois é 105,6
  (onda de 10 com 3 aliados).
- **Custo da reforma:** 8% a 16% de FPS médio nas vistas de jogo; no menu, 18%.
  - De onde vem: o grão triplanar (~0,5 ms de GPU), a HUD com mais peças (~30 chamadas a mais) e as
    torres com mais geometria e mecanismo animado.
  - Com torres, as chamadas de desenho aumentaram pouco: os materiais agora são compartilhados.
- **1% pior:** em geral de 5 a 10 FPS abaixo do de antes.
  - Nas noites com onda de 10 fica abaixo de 60 **antes e depois** (antes 55–65, depois 47–56).
  - **A meta de 60 FPS estáveis (1% pior ≥ 60) não está comprovada** nesses cenários. Já não estava
    antes, e a reforma piorou um pouco.
  - O 1% pior do menu (~22–28) vem do carregamento inicial e existia antes (~28–30).

## 17–18. Problemas encontrados e corrigidos

| Problema | Correção |
|---|---|
| Cristal da torre branco à noite (antigo) | Emissão em jade profundo e energia limitada |
| Peças planas (runas, tábuas, janelas, crânio) mal orientadas | Parâmetro `face` no gerador |
| Contrafortes como placas escuras chapadas | Contrafortes escalonados de blocos |
| HUD lendo `StyleBoxFlat` à força (quebraria com o estilo novo) | Leitura genérica de `StyleBox`; *setters* que redesenham |
| Ambiente do meio-dia abaixo da regra da Spec 014 | Valor ajustado |
| Leito de cristais violando o chão andável | Revertido |
| Placa talhada com dezenas de comandos 2D (≈ +120 chamadas de desenho e ~25–30% menos FPS nas vistas estáticas, medido) | Uma malha de triângulos por placa e marcas das barras numa chamada só |
| Worktree com caminho longo demais no Windows | Cópia por `git archive` num caminho curto |
| Sessão interrompida (token expirado) no meio da medição | Rodada inválida descartada, medição refeita |
| Ajuste de cor do ambiente custando ~0,9 ms de GPU (passada de tela inteira) | Removido do jogo (fica só no diorama do menu) |
| Faísca na boca do mecanismo criando nós a cada disparo | Removida; o clarão do cristal e o recuo continuam |
| `player_facing` com janela instável na regressão longa (foco) | Reexecutado isolado: 38/38 duas vezes |

## 19. Pendências

- Playtest manual de tudo (nada marcado como aprovado).
- Imagem de referência não recebida.
- Normal maps não usados (decisão técnica, ver item 5).
- Cores da vegetação embutidas na arte gerada não foram regeneradas.
- O 1% pior abaixo de 60 FPS nas noites com onda já acontecia antes (ver item 15–16).

## 20–21. Commits locais e estado final do Git

Meus commits (todos locais; **nenhum push feito por mim**):
- `736f46e` torres + acabamento de superfície;
- `ddb663d` HUD, inventário e suíte `design5`;
- `823414d` luz;
- `95df68a` otimização: sem ajuste de cor no jogo, ablação;
- `ac0f457` torres sem faísca por disparo;
- o último commit: relatório, comparações e medições.

Seus commits no meio da sessão, que incluíram parte do meu trabalho e evidências: `1b51c93`, `b8b1d13`, `dbcdf98`, `240444a`. Logs `.log`/`.err` das rodadas novas ficaram fora do meu commit.

## 22. Roteiro de playtest manual

1. **Menu:** confira o logotipo, a hierarquia JOGAR > TUTORIAL > opções, o hover, o clique e o foco
   pelo teclado (setas/Tab). Redimensione a janela. Abra Configurações, Créditos e Controles e volte.
2. **JOGAR:** confira a HUD: vitais, arco do sol, fichas, ESC. Leve um golpe de um dinossauro e veja
   o rastro na barra e o medalhão piscar.
3. Chegue perto de um ponto de defesa: o painel mostra custo e estatísticas do L1. Construa (L1),
   melhore para L2 e L3 e veja o modelo trocar. O painel mostra os dados reais e quantos pontos faltam.
4. À noite, veja o mecanismo girar para o invasor, a carga do cristal, o recuo e a lasca saindo do
   cristal. Confira se as torres ficam legíveis à noite e se o cristal não estoura em branco.
5. **Mochila (I):** cartões e Elixir. Confirme que o jogo continua correndo e que o cursor aparece.
6. **Dia 2:** a ficha do Elixir aparece na HUD; fabrique e veja 1/1.
7. Ande em volta das torres: nenhuma peça deve bloquear além do corpo de antes.
