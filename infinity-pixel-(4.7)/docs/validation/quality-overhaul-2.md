# Validação — Quality Overhaul 2.0 (combate, balanceamento, inventário, arte, interface, tutorial)

Data: 09/10/2026. Base: `1ccdae7` (6 commits locais da reformulação anterior, sem push).
**Sem push.** Nenhuma Spec foi marcada como aprovada; tudo aguarda o playtest manual.
Evidências reais do Godot: `quality-2-evidence/` (comparações: esquerda = antes, direita = depois).

## Estado de cada entrega

| Entrega | Implementado | Testado sem janela | Testado com janela | Playtest |
|---|---|---|---|---|
| Aliado sem dano (bug) | sim | sim (`ally_combat` 13) | sim | pendente |
| Direção do ataque do Player | sim | sim (`attack_direction` 9) | sim | pendente |
| Balanceamento do combate | sim | sim (`combat_balance` 6 + contratos) | sim | pendente |
| Inventário grande | sim | sim (`inventory_ui` 16) | sim + capturas 3 resoluções | pendente |
| Polimento visual (2ª passada) | sim | regressão | capturas | pendente |
| Configurações + menus | sim | sim (`settings_ui` 11) | sim (`main_menu` 27) | pendente |
| Tutorial mais acessível | sim | sim (`tutorial` 40) | sim | pendente |
| Propostas de game design, roadmap, auditoria de áudio | documentos | — | — | para aprovação |
| Melhorias sonoras | **não** (sem assets adequados) | — | — | — |

## Fase A — estado inicial (verificado)

`main` em `1ccdae7`, 6 commits à frente de `origin/main`, árvore limpa. Linha de base:
20/20 suítes, 700 checks, 0 falhas — confere com o relatório anterior.

## Fase B — correções críticas

### Aliado não causava dano
- **Causa real:** em SEGUIR, o aliado não tinha nenhuma lógica de combate (`_ally_follow` só
  andava). Só FICAR buscava alvos. Todo aliado começa em SEGUIR e o F fica bloqueado à noite,
  então um aliado que não foi posto em FICAR de dia passava a noite inteira sem atacar.
  Reproduzido: 0 de dano em 6 s ao lado de um inimigo. Agravante: mesmo em FICAR, o aliado
  (15 de dano) perdia sempre o 1×1 para o inimigo noturno (19,5 de dano).
- **Correção:** em SEGUIR, o aliado defende o jogador. Ataca inimigos da onda e selvagens que
  estão atacando o jogador ou um aliado, a até 7 m do jogador; larga o alvo se ele passar de
  10 m e volta a seguir. O estado continua SEGUIR. FICAR não mudou (código de ataque
  compartilhado).
  - Contra selvagem que não é da onda, o golpe do aliado **para em 20 HP**, o limiar da
    domesticação: ele ajuda a enfraquecer, mas nunca mata o candidato do jogador.
  - Sem fogo amigo (testado).

### Direção do ataque
- **Causa:** o clique só acertava a cápsula fina do tronco (r = 0,35). Clicar na copa caía na
  projeção do chão, ~2,3 m atrás da árvore pela inclinação da câmera, e entortava o golpe.
  O modelo ainda saltava para a direção no mesmo quadro.
  - Medido com o mesmo teste: **antes, 1/3 acertos na copa e 45,7° de desvio; agora, 3/3 e
    0,0°.**
- **Correção:**
  - O alvo do clique é a criatura ou recurso cujo corpo está mais perto do cursor na tela
    (70 px em 720p, até 7 m, criaturas têm prioridade). Refúgio e aliados nunca são alvo.
  - O golpe sempre atinge o alvo escolhido se ele estiver ao alcance.
  - Fora do alcance: sem dano, anel branco no alvo e a dica "FORA DE ALCANCE".
  - O modelo vira em ~0,1 s (sem salto) e um arco curto mostra a direção do golpe.
  - Preservados: clique para construir, E na domesticação e no marco, cancelamento do marco pelo
    golpe, bloqueio durante a canalização.

## Fase C — balanceamento (valores antes → depois)

| Valor | Antes | Depois | Por quê |
|---|---|---|---|
| Mordida hostil | instantânea | **preparação de 0,4 s** (corpo recua + arco vermelho no chão); acerta só se o alvo estiver a ≤ 2,35 m | janela de reação; recuar esquiva |
| Hostil durante a preparação | continuava andando | firma os pés | sem isso, recuar não escapava |
| Atacantes simultâneos do jogador | ilimitado | máx. 2 preparando ao mesmo tempo | menos dano "do nada" |
| Invulnerabilidade após um golpe | 0,6 s | 1,0 s | idem |
| Recarga do golpe que acerta | 0,8 s | 0,6 s | ataque mais responsivo |
| Dano do jogador | 15 | 15 | preserva 4 golpes → 20/80 (domesticação) |
| Bônus de dano noturno | ×1,30 (19,5) | ×1,15 (17,25) | primeira noite mais acessível |
| Golpe do aliado | 15 | 20 | o aliado precisa vencer o 1×1 |
| Tutorial (só ele) | 1,0 | dano hostil ×0,5 | ensinar, não punir |

Medido por `tests/combat_balance` (robô no jogo real):

| Cenário | Antes | Depois |
|---|---|---|
| Dia 1×1, enfraquecer até 20 HP | perde 45 | **perde 30** |
| Noite 1×3 sozinho, parado | cai em 5,6 s | cai em 6,0 s |
| Noite 1×3 sozinho, recuando na preparação | 5,6 s; recuar não ajuda | **8,8 s, 185 de dano causado** |
| Aliado × inimigo noturno 1×1 | aliado perde | **aliado vence (28 HP)** |
| Noite 1 com 1 torre + 1 aliado | vencida | vencida (Refúgio 100) |

3 inimigos noturnos contra o jogador sozinho continua perigoso, de propósito: é o papel das
torres e dos aliados. Contratos de teste atualizados, com o motivo escrito no próprio teste:
`player_health` (janela de 1,0 s), `day_cycle` (17,25), `sky_cycle` (1,15),
`physics_contracts` (+30 quadros da preparação), `ally_combat` (golpe de 20).

## Fase D — inventário

- Cartão central com ~78% da largura de referência sobre um véu escuro que bloqueia cliques no
  mundo. Três colunas:
  - RECURSOS: quantidades e de onde vêm.
  - CONSTRUÇÕES: o que fazem, onde ficam, custo com "faltam N", estado e CONSTRUIR.
  - DEFESA: pontos, custos de torre, torres erguidas, territórios e construções feitas.
- Fecha com I, ESC, FECHAR (focado ao abrir) ou clique fora.
- **Não pausa:** contrato aprovado da 013D (teste `build_heal [C]`). O rodapé avisa que o tempo
  continua. Se quiser pausar, é uma decisão sua.
- Testado em 1280×720, 1600×900 e 1920×1080: nenhum texto cortado, sem rolagem.

## Fase E — polimento visual

- `facetize.gd` troca esferas, cilindros e cápsulas lisas por versões facetadas com as mesmas
  medidas no Player, nos dinossauros, na Fogueira, na Armadilha e nas prévias de construção.
  Nós, materiais e colisões ficam iguais.
- Player: capa jade (silhueta), braços acompanham a passada e inclinação à frente ao correr.
- Cenário:
  - microrrelevo visual (≤ 7,5 cm, plano nas trilhas, no pátio e nos pontos), com normais
    reais;
  - 129 arbustos baixos (≤ 0,29 m, regra de 0,3 m sem sólido respeitada);
  - troncos caídos na Floresta Oeste e cascalho na Região Rochosa;
  - tudo nos blocos do chão, sem novas chamadas de desenho.
- Efeitos com função: construir, torre erguida ou melhorada, coleta concluída e inimigo
  surgindo na entrada (anel violeta).
- **Limitação honesta:** nos dinossauros, a mudança é modesta. O salto de qualidade dos
  personagens depende de modelos e animações próprios (com esqueleto), item principal do
  roadmap.

## Fase F — interface

- Configurações reais, salvas em `user://settings.cfg`, acessíveis no menu e na pausa:
  - volume geral, música e efeitos;
  - tela cheia;
  - escala da interface (90%, 100% ou 115%).
- Transição de entrada nos modais. O controle de volume da pausa agora tem o rótulo "Música".

## Fase G — tutorial

- Dano hostil pela metade só no tutorial (7,5 por mordida), com teste de que nada vaza para
  JOGAR.
- Textos ensinam: clique em cima do alvo, alcance de ~2 m, arco vermelho = recue.
- Feedback de erro no painel: golpe no vazio, longe demais e mordida chegando.

## Fase H — testes

| Execução | Resultado |
|---|---|
| Sem janela (`--fixed-fps 60`) | **25/25 suítes, 760 checks, 0 falhas** |
| Com janela (cópia com observador de foco) | **26/26 suítes, 790 checks, 0 falhas, 0 perdas de foco** |

Suítes novas: `ally_combat`, `attack_direction`, `combat_balance`, `inventory_ui`, `settings_ui`.

## Desempenho

Medição alternada, com janela e sem vsync, 10 s por vista: antes = cópia de `1ccdae7`,
depois = final. **Atenção:**
- o notebook estava **na bateria** (33%, plano Equilibrado);
- **o editor do Godot estava aberto neste projeto** (não fechei, para não perder trabalho);
- os números absolutos ficaram bem abaixo dos da sessão anterior **nas duas versões**.

FPS médio / pior 1% (rodadas 1 · 2):

| Vista | Antes (`1ccdae7`) | Depois |
|---|---|---|
| padrão 12:00 | 135/71 · 140/74 | 137/42 · 124/60 |
| padrão 21:00 | 158/80 · 150/71 | 159/84 · 154/76 |
| Refúgio 12:00 | 144/79 · 143/77 | 142/75 · 140/78 |
| vivo: dia com dinossauros | 119/25 · 117/26 | 116/23 · 112/24 |
| vivo: noite, 3 inimigos, torres, aliado | 117/19 · 116/19 | 113/19 · 117/19 |
| vivo: inventário aberto à noite | 125/76 · 122/64 | 118/67 · 119/71 |
| vivo: onda de 10, 3 torres | 91/17 · 92/18 | 85/16 · 93/18 |
| vivo: onda de 10, 3 torres, 3 aliados | 89/17 · 98/17 | 97/17 · 91/15 |
| vivo: tutorial | 154/71 · 158/90 | 153/83 · 151/52 |

- Médias iguais dentro da variação. **Nenhuma regressão atribuível às mudanças desta rodada.**
- **A meta de 60 FPS no pior 1% não foi atingida nos cenários vivos nestas condições**, nem
  na versão anterior; na sessão anterior, na mesma máquina, as mesmas vistas davam 63–78.
- Repetir na tomada, com o editor fechado:
  `Godot_console --path . --resolution 1280x720 --disable-vsync res://tests/perf_probe.tscn -- --report=perf.json --live`.

## Pendências e limitações

- Playtest manual de tudo.
- Desempenho a remedir em condições normais (acima).
- Arte de personagens própria (modelos e animações). Áudio novo: nenhum asset adequado
  disponível (`docs/context/audio-auditoria.md`; `refugio_principal.wav` está sem uso).
- O inventário não pausa (decisão para você).
- Economia e progressão: só propostas (`docs/context/propostas-game-design.md`). Roadmap:
  `docs/context/roadmap-steam.md`.
- Referência No Heroes Here 2: consultei só a descrição oficial (defesa cooperativa de
  castelo, roguelike, até 4 jogadores, preparar estações e fabricar munição, 15 rodadas,
  reforço diário, "curveballs"). Não analisei gameplay em vídeo e não atribuo ao jogo nada além
  disso.

## Roteiro de playtest manual

1. **JOGAR**, de dia: domestique o guardião da Floresta Oeste com 4 golpes. Note o arco vermelho
   antes de cada mordida e recue para esquivar. Perdeu menos vida que antes?
2. Clique na **copa** de uma árvore amarelada pelos lados e numa rocha com cristais: o herói
   vira e acerta? Clique num alvo longe: aparece "FORA DE ALCANCE"?
3. Deixe o aliado em **SEGUIR** e espere a noite: ele ataca os invasores perto de você? Teste
   também **FICAR** perto do Refúgio.
4. Lute contra um selvagem comum com o aliado ajudando: ele para em 20 de vida (domesticável)?
5. **I**: o inventário grande cobre a tela? Fecha com I, ESC, FECHAR e clique fora? O tempo
   continua (decida se prefere pausar).
6. **Configurações** (menu e pausa): volumes, tela cheia e escala; feche e reabra o jogo: ficou
   salvo?
7. **Primeira noite** com 1 torre + aliado: está justa?
8. **TUTORIAL** completo; teste errar golpes, morrer, Reiniciar e Sair, e depois JOGAR.
9. Desempenho percebido na tomada, com o editor fechado.
