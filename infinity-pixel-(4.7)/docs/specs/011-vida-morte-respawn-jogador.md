# 011 — HP, dano, morte, respawn e HUD do jogador

Ciclo 1 — Núcleo Jogável (pedido em 2026-10-04, após a aprovação das Specs
007–010 e da correção de orientação visual do Player).

Dá ao jogador uma vida real, ligada ao contrato de dano que já existe
(ADR 0001). Aplica a decisão de `technical-decisions.md`: **a morte do
personagem não é derrota**. Só a queda do refúgio encerra a partida. A
morte leva a um respawn automático e o mundo continua rodando. Preserva as
Specs 007 (câmera/mira), 008 (noite → dia contínua, Controles), 009
(colisões) e 010 (navegação), além de todos os valores de combate e
domesticação. Implementada; **aprovada pelo usuário em 2026-10-04** após o playtest manual (A–G).

## Fora do escopo

- Spec 012 e qualquer sistema novo: construção, recursos, coleta,
  inventário, crafting, save/load, mapa novo, seleção avançada de aliados.
- Cura de qualquer tipo: regeneração automática, poções, itens. O HP só
  volta a 100 no respawn.
- Equipamentos, armaduras, XP, níveis, stamina, boss, status complexos.
- Tipos ou origem de dano, projéteis e armadilhas. O contrato continua
  `take_damage(amount: float)`, e eles poderão usá-lo depois.
- Mudança nos valores de dano, alcance ou cooldown das criaturas.
- Mudança na navegação da Spec 010 (navmesh, agentes, avoidance, slots,
  spawns).

## Requisitos

### RF-VID-001 — HP real do jogador pelo contrato de dano existente

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-004, ADR 0001

O Player tem `max_hp` (exportado, 100) e `current_hp`, que começa em
`max_hp`. Ele continua no grupo `damageable` com o mesmo
`take_damage(amount: float)`: não existe um segundo sistema de dano. Um hit
válido faz `current_hp = clamp(current_hp - amount, 0, max_hp)` e emite
`health_changed(current, maximum)`.

O dano é ignorado, sem efeito nenhum, quando:
- o Player está morto;
- está dentro de uma janela de invulnerabilidade (RF-VID-002, RF-VID-005);
- o valor é inválido (`<= 0`, NaN ou infinito).

Valores reais das fontes de dano, encontrados e **mantidos**:

| Fonte | Dano | Cooldown | Alcance |
|---|---|---|---|
| WildDino (selvagem/onda), dia | 15 | 1,0 s | 2 m |
| WildDino, noite (×1,3, RF-AGE-018) | 19,5 | 1,0 s | 2 m |
| Carnotauro (mesmo `wild_dino.gd`) | 15 / 19,5 | 1,0 s | 2 m |

Não há outra fonte de dano ao jogador. Aliados não atacam o Player (eles
buscam só o grupo `wild_dino`).

**Critérios de aceitação**

- Dado o início da partida, então o jogador tem 100/100.
- Dado um hit válido de 15, então o HP vai para 85/100.
- Dado um dano maior que o HP restante, então o HP fica em 0, nunca
  negativo.
- Dado `take_damage(0)`, negativo, NaN ou infinito, então nada muda e
  nenhuma janela de invulnerabilidade abre.

**Origem:** o `take_damage` do Player só imprimia no console.

**Hipótese de protótipo — Vida máxima**
- **Valor inicial:** 100 (`max_hp`). Morre com 7 hits de dia ou 6 à noite.
- **Pergunta do protótipo:** dá tempo de lutar ao lado dos aliados sem ser
  descuidado?
- **Teto ou limite de exploração:** 80–150.

### RF-VID-002 — Invulnerabilidade entre hits e feedback de dano

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-001

Depois de um hit válido, o Player ignora qualquer dano novo por
`hit_invulnerability` (0,6 s). A janela é do **Player**, não de cada
inimigo. Se três criaturas acertam no mesmo instante, só o primeiro hit
conta. Durante a janela o Player anda, ataca e a câmera funciona
normalmente; nada pausa.

Feedback discreto:
- o modelo dá um pulso curto (`Visual.flash()`, o mesmo das criaturas);
- a barra e o texto JOGADOR ficam avermelhados e voltam ao normal em 0,35 s.

Não há tremida de câmera, sangue nem efeito de tela.

**Critérios de aceitação**

- Dado um hit válido, quando outro chega 0,3 s depois, então é ignorado.
- Dado um hit válido, quando outro chega 0,7 s depois, então causa dano.
- Dado três `take_damage(15)` no mesmo quadro, então o HP cai só 15.

**Hipótese de protótipo — Janela entre hits**
- **Valor inicial:** 0,6 s (`hit_invulnerability`).
- **Pergunta do protótipo:** cercado por 3 dinos, o dano parece justo e
  ainda ameaçador?
- **Teto ou limite de exploração:** 0,4–1,0 s. Abaixo do cooldown de 1 s
  dos dinos, para que um único dino acerte a cada golpe.

### RF-VID-003 — Morte sem pausar o mundo

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-001

Quando `current_hp` chega a 0, o Player morre **uma única vez**: emite
`died` uma vez e inicia um só `RespawnTimer`. Enquanto está morto:
- não anda, não mira nem ataca;
- não domestica: o canal em andamento é cancelado no mesmo quadro, o alvo
  não é domesticado e o HP do alvo é mantido;
- não recebe dano;
- sai do grupo `player`, fica com `collision_layer = 0` e o
  `NavigationObstacle3D` é desligado;
- o modelo fica oculto.

A árvore não é pausada. Criaturas, onda, refúgio e ciclo dia/noite
continuam.

**Critérios de aceitação**

- Dado HP 0, então `died` é emitido exatamente uma vez, mesmo com mais dano.
- Dado o Player morto, quando WASD, clique ou E são usados, então nada
  acontece.
- Dado o Player canalizando E, quando morre, então o canal zera e o alvo
  continua selvagem com o mesmo HP.
- Dado o Player morto, então o jogo não pausa e nenhum modal abre.

### RF-VID-004 — Respawn automático no ponto inicial

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-003

`respawn_delay` (2 s) depois da morte, o Player volta ao Marker3D
`PlayerSpawn` (`prototype_area.tscn`, em `respawn_point_path`, mesmo ponto
inicial do Player). Sem o marcador, usa a posição inicial do Player. O
respawn:
- restaura 100/100;
- devolve grupo, camada de colisão e obstáculo de navegação;
- reativa movimento, ataque e domesticação;
- emite `health_changed` e `respawned`.

O timer é um nó do Player: pausa junto com a árvore (menu de pausa) e some
junto com o mundo (Reiniciar/Menu).

**Critérios de aceitação**

- Dado o Player morto, então ele renasce após 2,0 s de tempo de jogo, no
  `PlayerSpawn`, com 100/100.
- Dado o jogo pausado com o Player morto, então o respawn espera a pausa
  acabar.
- Dado o respawn, então andar, atacar (20 de dano) e domesticar funcionam.

**Hipótese de protótipo — Tempo de respawn**
- **Valor inicial:** 2 s (`respawn_delay`).
- **Pergunta do protótipo:** a morte pesa sem tirar o jogador da noite?
- **Teto ou limite de exploração:** 1–5 s.

### RF-VID-005 — Proteção após o respawn

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-004

Depois de renascer, o Player fica invulnerável por `respawn_protection`
(1,5 s), usando a mesma janela do RF-VID-002. Durante a proteção, o modelo
pisca para mostrar que ela está ativa. O Player anda, ataca e a câmera
funciona.

**Critérios de aceitação**

- Dado o respawn, quando chega dano 1,0 s depois, então é ignorado.
- Dado o respawn, quando chega dano 1,6 s depois, então causa dano.

**Hipótese de protótipo — Proteção pós-respawn**
- **Valor inicial:** 1,5 s (`respawn_protection`).
- **Teto ou limite de exploração:** 1–3 s.

### RF-VID-006 — HUD de vida do jogador

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-001, RF-UI-002

O painel de vida do topo esquerdo, que já mostrava o refúgio, ganha
"JOGADOR  atual / máximo" com uma barra laranja, acima de "REFÚGIO
atual / máximo" com a barra verde de antes. É o mesmo painel compacto e o
resto da HUD não muda.

A HUD reage aos sinais `health_changed`, `died` e `respawned` do Player,
ligados pelo `main.gd` ao montar a HUD. Não há consulta de HP por quadro.
Só `main.gd` conhece o Player; o Player não conhece a HUD. O texto
arredonda o HP para cima, então nunca mostra 0 com o Player vivo.

**Critérios de aceitação**

- Dado o início da partida, então a HUD mostra "JOGADOR  100 / 100" e a
  barra cheia.
- Dado um hit, então texto e barra mudam no mesmo quadro e ficam
  sincronizados.
- Dado o respawn, então a HUD volta a 100 / 100.

### RF-VID-007 — Aviso de morte e respawn

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-003, RF-VID-004

Na morte, um aviso pequeno no topo central diz "VOCÊ CAIU · retornando ao
ponto inicial em N…", com N contando os segundos. Ele não captura cliques,
não pausa e some no respawn. A morte não abre uma segunda tela de Game
Over.

### RF-VID-008 — IA com o jogador morto

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-003, RF-NAV-003

Integração mínima, sem mudar a IA da Spec 010. Como o Player morto sai do
grupo `player`, a busca de alvos por grupos (ADR 0002, a cada 0,15 s) para
de encontrá-lo:
- **inimigos de onda** voltam ao slot do refúgio e o atacam;
- o **WildDino territorial** volta para a origem;
- **aliados** que seguiam ficam perto do último ponto do Player.

O slot de ataque ao redor do Player é liberado pelo mecanismo já existente
de troca de alvo. No respawn o Player volta ao grupo e é detectado de novo
normalmente. Um golpe que chegue no intervalo de até 0,15 s é ignorado
pelo `take_damage`.

**Critérios de aceitação**

- Dado um inimigo de onda ao lado do Player, quando o Player morre, então em
  até 0,4 s o alvo do inimigo deixa de ser o Player.

### RF-VID-009 — Refúgio continua sendo a única derrota

**Prioridade:** DEVE
**Status:** CONFIRMADO (`technical-decisions.md`)
**Depende de:** RF-AGE-012, RF-AGE-016

A morte do Player leva ao respawn. O refúgio em 0 continua abrindo "O
refúgio caiu" com Reiniciar/Menu, sem alteração. A noite → dia contínua
(Spec 008) não muda.

## Sinais

| Sinal (Player) | Quando | Quem escuta |
|---|---|---|
| `health_changed(current, maximum)` | hit válido e respawn | HUD (`main.gd`) |
| `died` | uma vez por morte | HUD (aviso) |
| `respawned` | ao renascer | HUD (fecha o aviso) |

## Alternativas descartadas

- **Invulnerabilidade por inimigo** (cada atacante com sua janela).
  Descartado: três dinos ainda acertariam juntos. O pedido é proteger o
  Player.
- **Pausar a árvore ou abrir modal na morte.** Descartado: quebra o mundo
  contínuo da Spec 008 e a decisão "morte não é derrota".
- **Ensinar a IA a checar `is_dead`.** Descartado: tirar o Player do grupo
  `player` já resolve, sem tocar na IA da Spec 010.
- **HUD consultando o HP a cada quadro**, como faz com o refúgio.
  Descartado para o jogador por pedido explícito de usar sinais. O refúgio
  ficou como estava, para não redesenhar a HUD.

## Perguntas em aberto

- O respawn deve ser no refúgio em vez do ponto inicial? Hoje os dois ficam
  a 15 m um do outro, no mesmo corredor.
- A morte deve ter um custo além do tempo fora (2 s)?
- Os aliados deveriam voltar a seguir automaticamente o ponto de respawn?

## Não aplicável a este jogo

*Nenhuma.*
