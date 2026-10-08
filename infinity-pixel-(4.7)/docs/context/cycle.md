# Estado do Ciclo

## Ciclo atual

**Ciclo 1 — Núcleo Jogável**

## Objetivo / pergunta do ciclo

O jogador consegue realizar a ação principal? Provar o menor recorte jogável
do core loop: preparar de dia (explorar, domesticar, posicionar defesa) →
iniciar a noite → enfrentar uma onda (com dinossauros hostis mais fortes) →
vencer ou perder. Ver detalhes em `game-overview.md`, seção "Primeiro
incremento".

## Specs selecionadas para este incremento

| Spec | Sistema | Status |
|---|---|---|
| 001-controle-jogador | Movimento e ataque básico do personagem | implementada, playtest aprovado (2026-09-18) |
| 002-dinossauro-selvagem | Comportamento e ataque do dinossauro selvagem inimigo | implementada, playtest aprovado (2026-09-18) |
| 003-domesticacao | Condição e processo de domesticação (inclui `is_domesticable`, RF-AGE-017) | implementada, playtest aprovado (2026-09-25, após correção) |
| 004-dinossauro-domesticado | Comportamento do dinossauro domesticado, posicionamento e combate | implementada, aguardando playtest manual (seguir/ficar/defesa por área) |
| 005-onda-e-vitoria | Disparo da onda, condição de vitória e de derrota | implementada, aguardando playtest manual (timing real da onda) |
| 006-ciclo-dia-noite | Estados DIA/NOITE, transição manual, buff noturno, fim de sessão | implementada e validada headless (estados/buff/derrota); playtest manual pendente para o fluxo completo em jogo |
| 007-camera-estrategica | Câmera estratégica 3D, WASD relativo à câmera, mira por cursor | implementada, verificação automatizada 31/31, aprovada (2026-10-03) |
| 008-continuidade-noite-dia-hud | Noite → dia sem modal, HUD compacta, Controles na pausa | implementada, verificação automatizada 35/35 + acceptance 36/36 (janela) e 33/33 (headless); aprovada (2026-10-03) |
| 009-contratos-fisicos-colisoes-obstaculos | Camadas/máscaras e 66 obstáculos sólidos | implementada, física 23/23; aprovada manualmente (2026-10-03) |
| 010-navegacao-avoidance-criaturas | Navmesh, NavigationAgent3D, avoidance, slots, spawns separados | implementada, navegação 38/38 (headless e janela); playtest manual 1–5 aprovado (2026-10-04) |
| 011-vida-morte-respawn-jogador | HP do jogador, invulnerabilidade, morte, respawn, HUD de vida | implementada, suíte 47/47 (headless e janela); aprovada pelo usuário (2026-10-04) |
| 012-primeiro-mapa-regioes | Vale 48 × 52 m, zonas, bifurcação, bosque/rochas, 3 rotas noturnas | implementada, world_layout 57/57 (headless e janela); aprovada pelo usuário (2026-10-04) |
| Menu principal (ajuste pós-012) | Menu com cara de jogo: vale real ao fundo, logo, JOGAR em destaque | implementado, main_menu 29/29 (janela); aprovado visualmente (2026-10-04) |
| 013-relogio-ciclo-ataques-noturnos | Relógio, ciclo automático, aviso/contagem, noites progressivas | implementada, day_cycle 43/43 (headless e janela) + regressões verdes (2026-10-04); aguardando playtest manual e aprovação |

## Status do ciclo

**Atualização 2026-10-03 — Spec 009:** contratos físicos e 66 obstáculos
implementados, aguardando playtest/aprovação. Ver `../validation/spec009.md`.
O usuário confirmou manualmente o retorno contínuo ao dia da Spec 008.
Specs 010 e 011 não iniciadas.

**Atualização 2026-10-03 — Spec 010:** Spec 009 aprovada manualmente pelo
usuário. Navegação (navmesh, NavigationAgent3D, avoidance, slots, spawns
separados) implementada; 38/38 headless e janela, regressões 007/008/009 e
acceptance verdes. Aguardando playtest visual (A–E) e aprovação. Ver
`../validation/spec010.md`. Spec 011 não iniciada.

**Atualização 2026-10-04 — Spec 011:** Specs 007–010 aprovadas pelo usuário,
incluindo a correção de orientação visual do Player. HP do jogador (100),
invulnerabilidade de 0,6 s, morte sem pausar, respawn em 2 s com 1,5 s de
proteção e HUD JOGADOR/REFÚGIO implementados. Suíte 47/47 headless e janela,
regressões verdes. Aguardando playtest manual (A–G) e aprovação. Ver
`../validation/spec011.md`. Spec 012 não iniciada.

**Atualização 2026-10-04 — Spec 012:** Spec 011 aprovada pelo usuário.
Primeiro mapa (vale 48 × 52 m) iniciado pelo GPT-6 Astra, interrompido por
limite de uso, auditado e concluído:
- correções de cor, região rochosa, bifurcação, estreitamentos e oclusão;
- fixture de HP no teste de navegação;
- documentação.

world_layout 57/57 e regressões verdes nos dois modos. Acceptance com janela
teve 1 crash intermitente em 4 execuções. Aguardando exploração visual
manual e aprovação. Ver `../validation/spec012.md`. Spec 013 não iniciada.

**Atualização 2026-10-04 — Spec 013:** Spec 012 e o redesenho do menu
principal aprovados pelo usuário. O ciclo automático foi implementado no
próprio DayNightManager, que segue como fonte única do tempo:
- relógio 08:00–18:00 em 3 min e noite visual de 90 s;
- aviso aos 30 s e contagem nos 10 s finais;
- noite automática e N só em modo de depuração;
- noites progressivas: 3 + (N − 1) inimigos em rodízio pelas 3 rotas.

day_cycle 43/43 e regressões verdes headless e com janela, sem crash 139.
Aguardando playtest manual. Ver `../validation/spec013.md`. Spec 014 não
iniciada.

EM ANDAMENTO — Specs 001–006 implementadas. 001/002/003 validadas em
playtest manual; 004/005/006 verificadas por chamadas diretas headless
(`godot --headless --script`, 27/27 checks OK) mas ainda sem playtest manual
no editor, que é o único jeito de validar fisica de movimento (seguir/ficar/
defesa por área) e o ritmo real da onda/buff em jogo. Ver
`progress-tracker.md`, "Como testar a Unidade 4".

## Evidências do playtest

- Unidade 1 (Spec 001), 2026-09-18: mecânica validada (movimento, câmera,
  ataque com dano). Primeira rodada falhou no ataque; corrigido e reaprovado.
  Sensação dos valores ainda não avaliada.

## Motivo do avanço para o próximo ciclo

Ainda não aplicável — Ciclo 1 só avança para o Ciclo 2 depois que o
incremento for implementado e validado em playtest (defesa da base
funcionando, domesticação funcionando, onda vencível e perdível).

**Atualização 2026-10-04 — balanceamento da Spec 013:** após o primeiro
playtest, dia 90 s (antes 180), relógio noturno 45 s (antes 90), aviso
20 s (antes 30), contagem 10 s. day_cycle_real 15/15 com os tempos reais;
regressões verdes. Spec 013 continua aguardando aprovação manual.

**Atualização 2026-10-04 — Spec 013B:** o ciclo da Spec 013 foi validado no
playtest, mas a Noite 2 ficou insustentável. Entrou a Spec 013B:
- Pontos de Defesa: 30 iniciais, +15 por inimigo da onda morto;
- 6 pontos fixos, 2 por rota;
- Torre de Defesa L1/L2/L3 (30/30/45), construção só de dia (tecla C);
- volume do menu com ícone e slider sempre visível.

A dificuldade base não mudou. defense_economy 35/35 e todas as regressões
verdes, headless e com janela. Aguardando playtest. Ver
`../validation/spec013b.md`. Spec 014 não iniciada.

**Atualização 2026-10-04 — Spec 013C:** o playtest da 013B validou os
sistemas e pediu polimento. A Spec 013C entregou:
- golpe 15 com 1 clique = 1 golpe (causa reproduzida e corrigida: o golpe
  no vazio descartava o clique seguinte);
- domesticado com vida cheia;
- 2 encontros diurnos;
- 40 pontos iniciais;
- anel de alcance das torres e prévia;
- posto sem texto de debug;
- coleta de Madeira e Pedra (8 árvores, 6 pedras, voltam no amanhecer);
- HUD compacta em três grupos.

Todas as suítes verdes nos dois modos (013C 46/46). 013B funcional; 013C
aguardando playtest. Spec 014 não iniciada.

**Atualização 2026-10-05 — Spec 013D:** a 013C foi aprovada manualmente.
Madeira e Pedra ganharam uso:
- inventário (I);
- construção com fantasma e validação por zona (B);
- Fogueira de Cura (+25 em 3 s, 2 cargas, 25 s de recarga);
- Armadilha de Espinhos (15 de dano, 3 cargas, até 3).

Nada muda a navmesh. build_heal 68/68 e healing_actions 7/7 nos dois modos;
regressões verdes (revisão final de 2026-10-05, sessão única). 013C aprovada
manualmente; 013D implementada.

**Atualização 2026-10-06 — playtest da 013D aprovado:** inventário, coleta,
construção, Fogueira, Armadilha, economia e amanhecer validados
manualmente. 013C e 013D aprovadas manualmente. **Spec 014 é a próxima**
(não iniciada).

**Atualização 2026-10-06 — Spec 014:** o cenário passa a acompanhar o
relógio: Sol que nasce, sobe e se põe, fim de tarde dourado, anoitecer,
noite com Lua (luz fria) e estrelas, amanhecer antes da troca de dia e
transição suave 05:59 → 08:00. Tudo lido do `DayNightManager`; nenhuma regra
mudou. sky_cycle 45/45 e regressões verdes nos dois modos. 013C e 013D
aprovadas manualmente; 014 implementada.

**Atualização 2026-10-06 — playtest da 014 aprovado:** ciclo visual validado
manualmente durante o gameplay. 013C, 013D e 014 aprovadas manualmente.
**Spec 015 é a próxima** (não iniciada).

**Atualização 2026-10-06 — Spec 015:** o mapa passa a ter progresso
territorial: Floresta Oeste e Região Rochosa começam selvagens, guardadas
pelos encontros diurnos; derrotar ou domesticar o guardião libera o marco;
segurar E 2 s recupera a região, e a área de construção cresce para ela. HUD
"TERRITÓRIOS 1/3". territory 68/68 e regressões verdes nos dois modos. 013C,
013D e 014 aprovadas manualmente; **015 implementada, aguardando playtest**.
Spec 016 não iniciada.

**Atualização 2026-10-08 — P0/P1 aprovadas manualmente:** depois da
interrupção do GPT-6 Astra, o projeto foi estabilizado (conflito de merge,
regressão da Spec 015, testes desatualizados e instáveis) e a tremedeira dos
dinossauros foi corrigida na causa (destino de navegação defasado + rumo
pelo avoidance). 17 suítes sem janela (635 checks) e 18 com janela (665)
verdes; playtest manual aprovado. Próximas fases: P2 documentação e
consolidação (em andamento), P3 tutorial jogável, P4 game design e UX, P5
visual noturno, P6 QA final. Ver `../validation/p0-p1.md`.
