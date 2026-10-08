# 013B — Economia, pontos de defesa e torres fixas

Ciclo 1 — Núcleo Jogável. Etapa intermediária pedida em 2026-10-04, **entre
a Spec 013 e a 014**.

**Por que existe:** no playtest da Spec 013:
- o ciclo automático funcionou (90 s / 45 s / 20 s / 10 s);
- a **Noite 1** (3 dinos) foi vencida, mas com várias mortes do Player;
- a **Noite 2** (4 dinos) ficou insustentável.

Faltava uma progressão defensiva para acompanhar o crescimento das ondas. Em
vez de enfraquecer os inimigos, entra o primeiro loop de tower defense:
derrotar inimigos da onda → ganhar Pontos de Defesa → construir/melhorar
torres em pontos fixos → defender → preparar a próxima noite.

Inclui também um ajuste do controle de volume do menu principal.

Implementada; **aguardando playtest manual e aprovação**.

## Fora do escopo

- Construção livre, grid, paredes, venda, reparo, HP de torre, armadilhas,
  mais classes de torre.
- Outros recursos (madeira/pedra funcionais, comida), inventário, crafting,
  loja, economia complexa, save/load, boss, XP.
- Spec 014 (céu e iluminação).
- Mudança na dificuldade base: a quantidade de inimigos (3 + noite − 1), o
  HP 80, o dano 15/19,5, a velocidade e o intervalo de 2 s **não mudaram**.

## Requisitos

### RF-ECO-001 — Pontos de Defesa (moeda única)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Fonte de verdade:** `DefenseEconomy` (`scenes/world/defense_economy.gd`),
  um nó da cena do mundo.
- **Métodos:** `can_afford(cost)`, `spend(cost)` e `add_points(amount)`.
- **Sinal:** `points_changed(total, delta)`.
- **A HUD só exibe.**
- **Valor inicial:** `starting_points = 30`. JOGAR e Reiniciar recriam o
  mundo, então a partida sempre volta a 30. Sem save.

### RF-ECO-002 — Recompensa por inimigo da onda

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-011

Cada **inimigo da onda noturna morto** concede `reward_per_wave_enemy = 15`.

**Fonte confiável:** `WaveManager._neutralize_wave_enemy`. Cada inimigo da
onda sai do registro de ativos **uma única vez**, que já era o contrato
anti-contagem-dupla. Nessa primeira saída, e só com o motivo "morreu", o
WaveManager emite `wave_enemy_defeated`, e a economia soma 15.

**Não pagam:**
- inimigo da onda **domesticado** (vira aliado) e a morte posterior desse
  aliado;
- inimigo removido da cena sem morrer;
- um segundo sinal de morte do mesmo inimigo;
- selvagens fora da onda: o encontro territorial e os de teste (T).

Domesticar e depois matar não gera pontos.

### RF-ECO-003 — Seis pontos fixos de defesa

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-MAP-007

São os nós `DefenseSlots/*` em `prototype_area.tscn`, dois por rota, todos a
mais de 14 m do refúgio:

| Ponto | Posição (x, z) | Rota | Papel |
|---|---|---|---|
| `SlotWestOuter` | (−18, −1,5) | Oeste | Perto da entrada oeste |
| `SlotWestInner` | (−10,5, −5,5) | Oeste | Depois do estreitamento oeste |
| `SlotRuinArch` | (3,6, 12,5) | Ruína | Junto ao arco, antes da bifurcação |
| `SlotRuinMeadow` | (−3,8, −1) | Ruína | Campina, última linha da estrada |
| `SlotEastInner` | (10,5, −5,5) | Leste | Depois do estreitamento leste |
| `SlotEastOuter` | (18, −1,5) | Leste | Perto da entrada leste |

- **Fora das trilhas:** do lado oposto à câmera (−Z) ou ao lado da estrada,
  para a torre não esconder o Player (regra da Spec 012).
- **Ponto vazio:** plataforma baixa de pedra com pedrinhas na borda e um
  cristal pequeno girando. Não tem colisão.

### RF-ECO-004 — Torre de Defesa e níveis

**Prioridade:** DEVE
**Status:** PROVISÓRIO

Os valores ficam numa tabela única (`DefenseTower.LEVELS`):

| Nível | Custo | Dano | Intervalo | Alcance |
|---|---|---|---|---|
| 1 (construir) | 30 | 10 | 1,0 s | 8 m |
| 2 (melhorar) | 30 | 15 | 0,85 s | 9 m |
| 3 (melhorar, máximo) | 45 | 20 | 0,70 s | 10 m |

- **Visual low-poly:** base de pedra em dois degraus, três postes de madeira
  e uma coroa com cristal verde-água.
  - **L2:** cristal maior e anel dourado.
  - **L3:** cristal ainda maior e coroa mais alta.
- **Corpo:** sólido pequeno (camada 4, construções), com obstáculo de
  avoidance. **Sem HP**: os inimigos não atacam torres.
- **Persistência:** as torres e os níveis continuam entre dias; só somem ao
  reiniciar.

### RF-ECO-005 — Alvo e ataque

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Alvo válido:** grupos `wave_enemy` **e** `wild_dino`, não
  `domesticated`, com HP > 0.
  - O WaveManager põe o grupo `wave_enemy` no spawn e o tira na
    neutralização.
  - Player, aliados, domesticados, refúgio e selvagens fora da onda nunca
    são alvo.
- **Escolha:** mantém o alvo atual enquanto ele for válido e estiver no
  alcance (plano XZ). Se não, procura o mais próximo a cada 0,15 s (busca
  por grupos, como a IA).
- **Ataque:** com cooldown, só com o jogo ativo (pausa e derrota param a
  torre). O dano usa o contrato `take_damage` (ADR 0001).
- **Feedback:** um dardo de cristal brilhante voa até o alvo em 0,18 s
  (sem física, sem colisão) e o cristal da torre pulsa. O dano entra na
  chegada, se o alvo ainda for válido.

### RF-ECO-006 — Interação contextual e bloqueio noturno

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Tecla nova:** **C** (ação `build_interact`). Antes estava livre; não
  conflita com WASD, clique, E, F, ESC, nem T/N de depuração.
- **Quando aparece:** a até 2,6 m de um ponto, um painel pequeno aparece
  acima do painel de objetivo, nunca no centro da tela.
- **Ponto vazio:** "TORRE DE DEFESA · Custo: 30 · [CONSTRUIR (C)]".
- **Torre:** "TORRE DE DEFESA · NÍVEL N · Dano · Alcance ·
  [MELHORAR — custo (C)]". No nível 3: "NÍVEL MÁXIMO".
- **Bloqueios:** botão desabilitado com motivo, "Pontos insuficientes" ou
  "Construa durante o dia". Apertar C bloqueado mostra o motivo num aviso
  breve.
- **De noite:** construir e melhorar ficam bloqueados (DIA = preparação,
  NOITE = defesa).
- **Clique no botão:** funciona e não dispara ataque, porque o painel
  consome o clique (Spec 007).

### RF-ECO-007 — HUD dos pontos

**Prioridade:** DEVE
**Status:** PROVISÓRIO

No topo, ao lado do painel de fase, um painel compacto mostra um cristal, o
número e a legenda "PONTOS DE DEFESA". Cada ganho mostra "+15" em dourado ao
lado por cerca de 1 s, subindo e sumindo. Não há modal.

### RF-UI-004 — Volume no menu principal

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** ajuste do menu pós-012

- **Layout:** ícone de som no canto inferior direito e, **logo abaixo e
  sempre visível**, um slider de 0 a 100%. O popup antigo saiu.
- **Regra única:** slider em 0 ⇔ mudo (Music e SFX silenciados, ícone com
  X).
  - Slider em 0: mudo.
  - Slider em 1% ou mais: som volta, ícone de som.
- **Clique no ícone com som:** slider vai a 0 (mudo).
- **Clique no ícone mudo:** volta ao **último volume diferente de zero**,
  que o `audio_director.last_nonzero_volume` guarda.
- **Mudo vindo da pausa:** aparece no menu como slider 0.
- **Pausa:** o controle de volume da pausa não mudou.

## Economia esperada (valores iniciais)

Novo jogo, 30 → torre L1 → 0 → Noite 1: 3 × 15 = 45 → Dia 2: **45 pontos**.
Escolha: segunda torre (30, sobram 15) ou L2 (30, sobram 15). Noite 2: até
+60. O ganho cresce com a onda: +15 por inimigo, e há um inimigo a mais por
noite.

## Testes

- **`tests/defense_economy.tscn`:** 35 checagens, cobrindo os itens A–T do
  pedido. Cena real, onda real e HUD real.
- **`tests/defense_showcase.tscn`:** ferramenta de captura com janela.
- **`tests/main_menu.tscn`:** atualizado para o novo controle de volume.
- Detalhes em `../validation/spec013b.md`.

## Alternativas descartadas

- **Reduzir os inimigos.** Descartado pelo pedido: primeiro testar se
  defesas resolvem a curva.
- **Clique do mouse no ponto para construir.** Conflitaria com o ataque
  (clique esquerdo). Proximidade + C (+ botão) segue o padrão do E.
- **Pagar pela domesticação.** Abriria o "farm" domesticar → matar.
- **Moeda na HUD.** A HUD não pode ser fonte de verdade.

## Perguntas em aberto

- 15 por inimigo e 30/30/45 bastam para a Noite 3 em diante?
- As torres deveriam poder ser vendidas, ou ter HP e ser atacadas, numa Spec
  futura?
- O ponto `SlotWestOuter`/`SlotEastOuter` perto das entradas é forte demais
  (acerta o inimigo logo ao nascer)?

## Não aplicável a este jogo

*Nenhuma.*
