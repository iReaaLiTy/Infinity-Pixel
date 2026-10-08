# 015 — Territórios controlados e expansão da base

Ciclo 1 — Núcleo Jogável. Pedida em 2026-10-06, depois da aprovação manual
da 013C, 013D e 014.

**Por que existe:** o mapa da Spec 012 tinha base e regiões, mas nenhuma
noção de progresso territorial. A 015 faz o jogador **recuperar** regiões
usando sistemas que já existem:

base → explorar → território selvagem → neutralizar o guardião (derrotar
**ou** domesticar) → ativar o marco (E) → território controlado → área de
construção maior.

Implementada; **aguardando playtest manual e aprovação**.

## Fora do escopo

- Paredes, cercas, casa, portões, fazenda, storage, crafting ou recursos
  novos, espécies novas, boss, quests, minimapa, save/load, NPCs, loja,
  tecnologia, upgrades.
- Perder território, ataques a territórios, barreiras contra inimigos.
- Aumentar o mapa; tornar conquistável a área selvagem distante.
- Mudar coleta (árvore +10 / 30 HP, pedra +6 / 45 HP), economia, torres,
  Fogueira, Armadilha, ondas, ciclo, câmera e o visual da Spec 014.

## Auditoria (antes de mudar)

| Item | Estado encontrado |
|---|---|
| Mapa (Spec 012) | Vale 48 × 52 m. `SafeZone` (refúgio + `BuildZone` 8 × 10 m em (7, −15)), `TransitionZone`, `WildZone` com `WoodlandFloor` (bosque, oeste) e `StoneHeath` (rochosa, leste), ruína/arco ao norte |
| Rotas noturnas | Estrada da ruína em x = 0 (z −13…26); trilhas oeste/leste em z ≤ 2. **Nenhuma rota entra no bosque ou na região rochosa** |
| Encontros diurnos (013C) | `EncounterSpawner`: um WildDino territorial na clareira do bosque (−10, 10) e outro na região rochosa (13, 22). No amanhecer recria só o ponto cujo encontro deixou de ser selvagem; nunca acumula; não pagam pontos nem contam na onda |
| E | `DomesticationChannel` (Player): segurar 2 s com selvagem elegível a até 3 m |
| Construção (013D) | `BuildPlacer`: zona "base" = BuildZone; zona "route" = rotas noturnas; sólidos, estruturas, refúgio, pontos de defesa e navmesh validados |
| HUD (013C) | Painel direito: DEFESA, MADEIRA, PEDRA; avisos curtos no topo; dica + barra embaixo |
| Reiniciar | `start_game()` cria um mundo novo |

## Requisitos

### RF-TER-001 — TerritoryManager

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- `scenes/world/territory_manager.gd` (nó `TerritoryManager` no mundo),
  fonte única do estado territorial. Nada disso em `main.gd` (a HUD só
  exibe).
- Sabe os territórios, o estado de cada um, o guardião, o marco e a área
  de construção. Estados: `WILD`, `READY_TO_CLAIM`, `CONTROLLED`. Só
  avançam; nada volta atrás nesta Spec.
- Sinais: `state_changed`, `claimed`, `region_entered`, `claim_cancelled`.

### RF-TER-002 — Territórios

**Prioridade:** DEVE
**Status:** PROVISÓRIO

| Território | Área (XZ) | Início | Construção de base |
|---|---|---|---|
| REFÚGIO (centro) | tudo ao sul da bifurcação (z ≤ 5,5) | CONTROLLED | só a BuildZone original (013D intacta) |
| FLORESTA OESTE | x ≤ −4, z > 5,5 (bosque) | WILD | a região toda, depois de recuperada |
| REGIÃO ROCHOSA | x ≥ 4, z > 5,5 (leste) | WILD | a região toda, depois de recuperada |
| (corredor da ruína) | \|x\| < 4, z > 5,5 | — | nunca (área selvagem futura) |

- O HUD conta 3 territórios (centro + oeste + leste).

### RF-TER-003 — Guardião territorial

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Sem espécie nova:** o guardião é o **encontro diurno da 013C daquela
  região** (o mesmo `WildDino` territorial e domesticável). Enquanto o
  território está WILD, o encontro é marcado como guardião (rótulo
  "GUARDIÃO · 80/80").
- **Neutralizar = derrotar OU domesticar.** Qualquer um faz WILD →
  READY_TO_CLAIM, **uma única vez**:
  - derrotado: não dá Pontos de Defesa e não conta na onda (já era assim
    para encontros);
  - domesticado: vira aliado normal (vida cheia, seguir/ficar), sem nada de
    especial; a morte posterior desse aliado não muda o território.
- **Amanhecer (013C):** o `EncounterSpawner` continua recriando o encontro
  do ponto que ficou vazio. O `TerritoryManager` só marca um guardião se o
  território ainda estiver WILD e sem neutralização registrada. Como o
  guardião vivo não é recriado (o spawner só recria ponto vazio) e o
  guardião neutralizado já liberou o território, **nunca há guardião
  duplicado**. Os encontros recriados depois são selvagens comuns.
- Não usa rotas noturnas nem interfere no `WaveManager`.

### RF-TER-004 — Marco territorial

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- `territory_marker.gd`: pedestal de pedra baixo com cristal antigo, ~2 m.
  Oeste em (−14, 13); Leste em (13, 16): chão aberto, navegável, a mais de
  3,5 m de qualquer rota.
- **WILD:** cristal cinza-violeta, quase sem brilho. **READY:** dourado,
  pulsando. **CONTROLLED:** jade aceso com luz local pequena (sem sombra).
- Corpo pequeno (camada de construções) e obstáculo só de avoidance; a
  navmesh não muda. Participa do brilho noturno da Spec 014.

### RF-TER-005 — Conquista

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Com o território READY, **de dia**, a até 2,2 m do marco: segurar E por
  **2 s**. HUD: "RECUPERANDO TERRITÓRIO... 1,2 / 2,0 s" com barra.
- **Cancela, sem progresso salvo:** soltar E, sair do alcance, morrer,
  pausar, anoitecer, atacar, iniciar construção, curar na Fogueira.
- À noite não começa ("Recupere durante o dia").

### RF-TER-006 — Prioridade da tecla E

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Alvo domesticável válido a até 3 m vence o marco.**
- **Uma segurada de E = uma interação:** o `DomesticationChannel` guarda o
  dono da segurada atual (`e_hold_owner`: "domesticate" ou "territory"),
  liberado só quando o E é solto. Assim:
  - domesticar perto do marco não ativa o marco na mesma segurada;
  - um selvagem elegível que chega durante a recuperação não é domesticado
    nessa segurada.
- A leitura de E e a busca de alvo são as mesmas da domesticação.

### RF-TER-007 — Feedback da conquista

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Anel de energia que se expande no chão (1,1 s), cristal que salta e muda
  para jade, aviso curto "FLORESTA OESTE RECUPERADA" / "REGIÃO ROCHOSA
  RECUPERADA". Sem modal, sem pausa, sem cobrir a tela.

### RF-TER-008 — Limite visual discreto

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Contorno fino no chão (4 faixas, 1 material por território, sem luz nem
  sombra): rosado quando selvagem e jade quando controlado, com opacidade
  0,10 em repouso.
- Acende (0,42) ao entrar na região e durante a conquista, e volta a ficar
  sutil em ~1,5 s.

### RF-TER-009 — Expansão da área de construção

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- O `BuildPlacer` não foi duplicado. A zona "base" (Fogueira e futuras
  estruturas de base) passa a ser:
  - a BuildZone original, **ou**
  - um território CONTROLLED com área de construção (Oeste/Leste), via
    `TerritoryManager.is_build_area()`.
- Recusas novas:
  - **"Território selvagem: recupere o marco primeiro"** (Oeste/Leste ainda
    não recuperados);
  - **"Bloquearia uma rota noturna"** (fora da BuildZone, sólido a menos de
    2 m + raio de uma rota).
- Todas as validações da 013D continuam: sólidos (árvores, pedras, marco),
  outras estruturas, refúgio, pontos de defesa, Player, navmesh, limite de
  1 Fogueira, só de dia.
- **Armadilha:** regra da 013D mantida (sobre as rotas noturnas). Nenhuma
  rota passa pelo Oeste/Leste.

### RF-TER-010 — Persistência, noite, morte e reinício

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Territórios recuperados ficam recuperados pelos dias e noites seguintes.
  CONTROLLED não impede inimigos (sem barreira).
- Morrer não perde território (só cancela uma conquista em andamento).
- Reiniciar: mundo novo, Centro CONTROLLED, Oeste/Leste WILD, guardiões
  novos.

### RF-TER-011 — Entrada em região

**Prioridade:** PODE
**Status:** PROVISÓRIO

- Aviso pequeno e temporário "FLORESTA OESTE · Território selvagem" (ou
  "Pronto para ser recuperado" / "Território controlado"). Só aparece
  quando o estado mudou desde o último aviso daquela região (não repete a
  cada entrada). Checado 4× por segundo, sem `Area3D`.

### RF-TER-012 — HUD

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Um item a mais no painel da direita: ícone de marco + **"1/3"** com a
  legenda TERRITÓRIOS (1/3 → 2/3 → 3/3).
- Dica perto do marco e objetivo do dia "… pronta: segure E no marco".
- Tela Controles: "E … no marco: recuperar território (de dia)".

### RNF-TER-001 — Desempenho

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- Sem `Area3D` por território: retângulos em XZ e uma checagem de região a
  4 Hz.
- O canal de conquista sai na hora quando E não está segurado.
- O marco só processa por quadro enquanto READY (pulso).
- 2 luzes locais pequenas (sem sombra) só nos marcos recuperados.
- 8 faixas de contorno estáticas.

## Arquivos

- **Novos:** `scenes/world/territory_manager.gd`,
  `scenes/world/territory_marker.gd`, `tests/territory.gd/.tscn`,
  `tests/territory_showcase.gd/.tscn`, `tools/test_spec015.ps1`.
- **Modificados:**
  - `prototype_area.tscn`: nó `TerritoryManager`;
  - `build_placer.gd`: zona base por território, recusas novas, rotas lidas
    uma vez;
  - `domestication_channel.gd`: dono da segurada de E, `is_e_held()`,
    `find_eligible_target()`;
  - `wild_dino.gd`: rótulo GUARDIÃO;
  - `main.gd`: item TERRITÓRIOS, avisos, dica/barra, objetivo, Controles.

## Testes

- **`tests/territory.tscn`:** 68 verificações (itens 1–40 da spec e
  extras).
- **`tests/territory_showcase.tscn`:** capturas pela câmera real.
- Detalhes em `../validation/spec015.md`.

## Alternativas descartadas

- **Guardião como criatura extra além dos encontros.** Dois dinos por
  região confundiriam (qual conta?) e exigiria outra regra de reaparecimento.
- **`Area3D` por território.** Os limites já são retângulos simples.
- **Barra de progresso ao ficar parado num círculo.** Pedido explícito
  contra.
- **Restringir a Armadilha a territórios controlados.** Tiraria da 013D
  (aprovada) a armadilha na estrada da ruína ao norte da bifurcação. Ficou
  como pergunta para o playtest.
- **Rebake da navmesh ao recuperar.** Nada no mapa muda de forma.

## Perguntas em aberto

- A Armadilha deve passar a exigir território controlado também (hoje: só
  rota noturna)?
- O objetivo "Domestique o selvagem da clareira lateral" (texto antigo da
  HUD) ainda faz sentido com os guardiões?
- 2 s de E e 2,2 m de alcance estão bons?

## Não aplicável a este jogo

- Perda de território e ataques a territórios (futuro).
