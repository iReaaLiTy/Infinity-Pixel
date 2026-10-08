# 013 — Relógio, ciclo automático e ataques noturnos

Ciclo 1 — Núcleo Jogável (pedido em 2026-10-04, após a aprovação da Spec 012
e do novo menu principal).

Transforma o DIA/NOITE manual (Spec 006, tecla N) em um **ciclo de gameplay
automático**: relógio acelerado, aviso de anoitecer, noite às 18:00, onda
automática, amanhecer quando a onda é vencida, e Dia 2, Noite 2 e assim por
diante, enquanto o refúgio resistir. Preserva:
- a passagem noite → dia sem modal (Spec 008);
- rotas e navegação (Specs 010/012);
- vida e respawn do Player (Spec 011);
- os valores de combate, domesticação e buff noturno.

Implementada; **aguardando playtest manual e aprovação**.

## Fora do escopo

- Spec 014: céu e iluminação progressivos, sol/lua, estrelas, clima. O visual
  continua sendo o `day_night_visual.gd` atual (troca DIA/NOITE com
  transição de 1,5 s).
- Dificuldade além da quantidade: HP, dano e velocidade das criaturas não
  mudam por noite. Sem boss e sem espécies novas.
- Save/load (Spec 020): fechar o jogo recomeça no Dia 1.
- Construção, recursos, economia, áudio novo, seleção avançada de aliados.

## Fonte única de verdade temporal

O relógio fica **dentro do `DayNightManager`** (autoload), que já era o dono
do estado DIA/NOITE. Não existe um segundo sistema.

| Dado/sinal | Significado | Quem usa |
|---|---|---|
| `state` (DAY/NIGHT), `is_day()`, `is_night()` | Estado global | HUD, WaveManager, dano noturno (`wild_dino.gd`), comando F |
| `day_number` | Dia N; a Noite N usa o mesmo número | HUD, fórmula de onda |
| `nights_defended` | Noites vencidas na sessão | HUD (`main.victory_count` só lê este valor) |
| `phase_elapsed` | Segundos de gameplay no período atual | relógio |
| `clock_minutes()` / `clock_text()` | Horário "HH:MM" | HUD |
| `seconds_until_night()` | Tempo até as 18:00 | contagem final |
| `night_warning` | Uma vez por dia, 20 s antes das 18:00 | HUD (aviso) |
| `night_started` | 18:00 | WaveManager, visual, música |
| `day_started` | Amanhecer (noite vencida) | HUD, visual, EncounterSpawner |
| `game_over` | Refúgio caiu | HUD (derrota) |

## Requisitos

### RF-CIC-001 — Relógio de gameplay acelerado

**Prioridade:** DEVE
**Status:** PROVISÓRIO

Novo jogo (JOGAR ou Reiniciar): **Dia 1, 08:00, DIA**, 0 noites defendidas.

**Valores de playtest (2026-10-04):** no primeiro playtest o usuário achou o
ciclo muito longo (180 s de dia, 90 s de relógio noturno, aviso a 30 s). Os
tempos foram reduzidos à metade e o aviso foi para 20 s. A contagem continua
nos 10 s finais. A noite continua sem limite de tempo: os 45 s são só o
relógio, que segura em 05:59 até a onda ser vencida.

| Export (`DayNightManager`) | Valor atual | Significado |
|---|---|---|
| `day_duration_seconds` | **90** (era 180) | 08:00 → 18:00 (10 h de jogo em 1 min 30 s reais) |
| `night_duration_seconds` | **45** (era 90) | 18:00 → 05:59 **só no relógio** |
| `night_warning_seconds` | **20** (era 30) | Aviso antes das 18:00 |
| `night_countdown_seconds` | **10** | Contagem final |
| `day_start_hour` / `night_start_hour` / `dawn_hour` | 8 / 18 / 6 | Horários |

- O relógio soma o `delta` do jogo em `_process`, só quando `can_play()`.
  Fica parado no menu, com o jogo pausado e depois da derrota. Não usa o
  relógio do sistema.
- O minuto é proporcional: 1 min de jogo = 0,15 s real de dia e 0,0625 s real
  de noite.

**Critérios de aceitação**

- Dado JOGAR, então a HUD mostra "DIA 1 • PREPARAÇÃO" e "08:00".
- Dado o jogo pausado, então o horário não muda. Ao retomar, continua de
  onde parou.

### RF-CIC-002 — Aviso de anoitecer e contagem final

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **20 s antes das 18:00** (por volta das 15:46): `night_warning` é emitido **uma vez por dia**.
  A HUD mostra "A NOITE SE APROXIMA" no topo central por 2,5 s + 0,5 s de
  fade. Não pisca, não pausa, não captura cliques.
- **Últimos 10 s:** o painel de fase mostra "ANOITECE EM N" (10 … 1) em
  destaque laranja, abaixo das noites defendidas. Não há modal nem
  bloqueio, e nada cobre o centro da tela.

### RF-CIC-003 — Noite automática às 18:00

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** a entrada manual da RF-AGE-014 no fluxo normal

Quando `phase_elapsed` chega a `day_duration_seconds`:
1. o próprio `DayNightManager` chama `start_night()`;
2. o estado vira NOITE e o relógio fica em 18:00;
3. `night_started` é emitido;
4. o `WaveManager` (já ligado a esse sinal) inicia a onda.

**"Iniciar Noite" (tecla N):**
- saiu da HUD, da tela de Controles e dos objetivos;
- a tecla só funciona com `debug_force_night_key = true`, que vem
  desligado: o jogador normal nunca precisa dela;
- testes e ferramentas chamam `start_night()` diretamente.

### RF-CIC-004 — HUD temporal

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-UI-002

É o mesmo painel de fase do topo, com o mesmo estilo:
- **Linha 1:** "DIA 1 • PREPARAÇÃO" ou "NOITE 1 • DEFESA" e, à direita, o
  relógio "14:37" em fonte forte.
- **Linha 2, de dia:** "Noites defendidas: N".
- **Linha 2, de noite:** "4/4 criados · 1 neutralizados · 3 ativos" e, abaixo,
  "Noites defendidas: N".
- **Contagem:** "ANOITECE EM N" só nos últimos 10 s do dia.
- **Objetivos:** sem menção à tecla N, como "Posicione aliados (F) antes
  do anoitecer".

### RF-CIC-005 — Fim da noite e amanhecer

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-011, RF-AGE-015, RF-UI-001

- **O que encerra a noite:** a onda neutralizada (todos os previstos
  criados e nenhum ativo), pela mesma lógica do `WaveManager` de antes.
  Domesticação e morte contam uma única vez por inimigo.
- **O que o relógio não faz:** encerrar a noite. Se o relógio chega ao fim
  da noite com inimigos ativos, ele **segura em 05:59** e a noite
  continua.
- **Amanhecer** (`report_wave_victory`):
  - `nights_defended` += 1 e `day_number` += 1;
  - relógio em 08:00, estado DIA;
  - aviso "AMANHECEU · DIA N" (sem modal, sem pausa).
- **O que não acontece no amanhecer:** teleporte, cura do Player ou
  restauração do refúgio.

### RF-CIC-006 — Progressão de noites e distribuição pelas rotas

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-010, RF-MAP-007

- **Fórmula** (`WaveManager.enemy_count_for_night`):
  `base_enemy_count + extra_enemies_per_night × (noite − 1)`, com 3 e 1.
  Resultado: Noite 1 = 3, Noite 2 = 4, Noite 3 = 5, Noite 4 = 6…
- **Intervalo entre spawns:** 2 s, como antes. HP, dano e velocidade não
  mudam.
- **Rotas:** os `spawn_offsets` da Spec 012 estão intercalados por rota
  (índice % `route_count` = 3: Ruína, Oeste, Leste, Ruína, …). O n-ésimo
  inimigo usa a rota n % 3, em rodízio. Exemplo, Noite 2:
  Ruína 2, Oeste 1, Leste 1.
- **Ponto ocupado:** se o ponto estiver ocupado, o spawn tenta antes os
  outros pontos da **mesma rota** e só depois outras rotas. Antes, ia
  direto ao próximo índice, que é de outra rota.

### RF-CIC-007 — Derrota, morte do Player e dano noturno

**Prioridade:** DEVE
**Status:** CONFIRMADO (contratos anteriores)

- **Derrota:** refúgio em 0 → "O refúgio caiu" (RF-AGE-016). Se o último
  inimigo morre no mesmo quadro, a derrota vence (vitória adiada para o fim
  do quadro, que já existia). O relógio para na derrota.
- **Morte do Player (Spec 011):** não encerra a noite nem para o relógio.
  Respawn em 2 s com 1,5 s de proteção.
- **Dano noturno:** continua vindo do mesmo `is_night()`: 15 de dia e 19,5
  à noite. Não há outro multiplicador.

## Integrações

| Sistema | Mudança |
|---|---|
| `DayNightManager` | Relógio, contadores, `night_warning`, início automático, N só em modo de depuração |
| `WaveManager` | Quantidade por noite e desvio de spawn dentro da rota. Vitória e contagem como antes |
| HUD (`main.gd`) | Painel temporal, contagem, aviso, amanhecer com o número do dia, N fora dos Controles |
| `day_night_visual.gd`, `encounter_spawner.gd`, `wild_dino.gd`, `base.gd` | Sem mudança (já escutavam os sinais ou consultavam o estado) |

## Testes

- **`tests/day_cycle.tscn`:** 43 checagens, cobrindo os itens A–U do pedido.
  Dia de 6 s e noite de 4 s **só no teste**, ajustados pelos exports.
- **`tests/cycle_showcase.tscn`:** ferramenta de captura com janela (não é
  teste).
- Detalhes em `../validation/spec013.md`.

## Alternativas descartadas

- **Relógio em um nó novo na cena.** Descartado: criaria uma segunda fonte
  de verdade ao lado do autoload que já guarda o estado.
- **O relógio encerrar a noite às 06:00.** Descartado pelo pedido: inimigos
  sumiriam "magicamente".
- **Dificuldade por HP/dano.** Descartado nesta Spec: a progressão é só pela
  quantidade.

## Perguntas em aberto

- 90 s de dia são suficientes para domesticar e posicionar aliados? E
  depois da Noite 5?
- O relógio da noite (45 s) deve acompanhar a duração real esperada da onda
  quando houver mais inimigos?
- O aviso de 20 s deve ter som?

## Não aplicável a este jogo

*Nenhuma.*
