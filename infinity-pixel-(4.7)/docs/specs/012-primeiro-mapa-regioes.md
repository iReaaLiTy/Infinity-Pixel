# 012 — Primeiro mapa: regiões e estrutura do mundo

Ciclo 1 — Núcleo Jogável (pedido em 2026-10-04, após a aprovação da Spec 011).

Transforma a arena de protótipo no primeiro mapa real: um **vale compacto**
com uma base segura, uma transição, uma bifurcação, o bosque das criaturas a
oeste e uma região rochosa a leste. Há três rotas de ataque noturno. O mapa
reutiliza só os assets low-poly existentes. Câmera, combate, vida, domesticação
e navegação (Specs 007–011) não mudaram.

Início pelo GPT-6 Astra, interrompido por limite de uso; continuação e
correções em 2026-10-04 (ver `../validation/spec012.md`). Implementada e
**aprovada pelo usuário em 2026-10-04** após exploração visual manual.

## Fora do escopo

- Construção funcional: grid, placement, ghost, custos, torres. A BuildZone
  só **marca** o espaço.
- Recursos, coleta, mineração, inventário, crafting, economia. As
  ResourceZones só **marcam** regiões futuras.
- Novas espécies, novos encontros e boss. O único encontro diurno continua
  sendo o WildDino territorial.
- Save/load, equipamentos, XP, níveis, stamina, seleção avançada de aliados.
- Mudança de câmera, de valores de combate/vida ou da IA da Spec 010.

## Conceito

```
              ÁREA SELVAGEM (norte, +Z)
          ┌──── ruína / arco (0,16) ────┐
     BOSQUE (oeste)               REGIÃO ROCHOSA (leste)
   clareira das criaturas         blocos de pedra, portão natural
          └───── BIFURCAÇÃO (0,6) ──────┘
                      │
         TRANSIÇÃO (campina aberta, z −6…6)
   rota oeste ◄── estreitamentos ──► rota leste
                      │
       BASE (sul, −Z): refúgio + BuildZone + PlayerSpawn
```

Os eixos são os do mundo: o refúgio fica em −Z e a câmera estratégica (yaw
0) olha para −Z. Na tela, a base aparece no alto e as áreas selvagens perto
do jogador ao sair. "Oeste" = −X.

## Requisitos

### RF-MAP-001 — Vale de 48 × 52 m

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Chão:** `Ground` com 48 × 52 m, centrado em (0, 2): x −24…24, z −24…28.
- **Limites:** quatro `Boundary` (camada 1) em x = ±24,2, z = −24,2 e
  z = 28,2. Cada limite coincide com uma escarpa visível:
  - penhascos `Cliff` fora das paredes, a ≥ 26 m do centro, sem invadir a
    área andável;
  - cristas `BorderRidge` ao norte e ao sul;
  - montanhas ao fundo.
- **Gerador:** o layout é autoral e determinístico, criado por
  `tools/build_first_map.gd`.

### RF-MAP-002 — Base segura (SafeZone), refúgio e PlayerSpawn

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-012, RF-VID-004

| Elemento | Posição | Observação |
|---|---|---|
| Refúgio (`Territory`) | (0, 0, −15) | Mesma posição de antes; 100 HP, derrota em 0 |
| `PlayerSpawn` (Marker3D) | (0, 1, −10) | 5 m à frente do refúgio, no caminho, fora de sólidos; usado também pelo respawn (Spec 011) |
| `SafeZone/Center` | (0, −12), 24 × 18 m | Clareira clara e pavimentada ao redor do refúgio |
| Posto de defesa | (0, −7) | Marco existente, no início da estrada |

**Critérios de aceitação**

- Dado o início, então o Player nasce no `PlayerSpawn`, a 3–7 m do refúgio,
  sem sobreposição sólida.
- Dado o respawn, então ele volta ao mesmo marcador.

### RF-MAP-003 — BuildZone (marcação, sem construção)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

`WorldRegions/SafeZone/BuildZone` (Marker3D) fica em (7, −15) e tem metadado
`size_xz` = 8 × 10 m. Uma clareira pavimentada mais clara (`BuildClearing`)
marca o lugar, ao lado do refúgio. É plana, aberta e navegável: as 9
amostras de 8 × 10 m não têm sólido e estão na navmesh.

### RF-MAP-004 — Transição e bifurcação

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Transição** (`TransitionZone/Center` (0, 1), 30 × 16 m): a campina
  `Meadow` é aberta, com poucas pedras soltas e árvores só nas bordas. A
  densidade cresce para o norte.
- **Estrada:** `RuinRoad` vai do refúgio ao arco e à entrada norte.
- **Bifurcação:** no fim da campina, em (0, 6), com o piso `ForkPaving` e o
  marcador `Landmarks/Fork`. Dali saem as duas trilhas selvagens:
  - `GladeTrail` para o bosque;
  - `HeathTrail` para a região rochosa.

### RF-MAP-005 — Bosque oeste e região rochosa leste (WildZone)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Bosque** (`WildZone/WoodlandFloor`, piso escuro, ~19 × 22 m em
  (−12, 16)):
  - árvores mais densas, poucas pedras pequenas;
  - a clareira das criaturas `CreatureZones/CommonTerritory` fica em
    (−10, 10), 10 × 10 m, e é onde nasce o WildDino territorial
    (`EncounterSpawner` em (−10, 0,5, 10)).
- **Região rochosa** (`WildZone/StoneHeath`, piso claro, ~16 × 21 m em
  (15, 17)):
  - oito blocos de pedra de 1,5–2,0 m de altura e poucas árvores, só na
    borda;
  - na trilha, dois blocos formam um portão natural (`Landmarks/HeathGate`).
- **Área selvagem distante** (`WildZone/Center` (0, 22), 38 × 12 m): a
  ruína com o arco e a entrada norte, cercada pelos dois biomas.
- **CreatureZones/DistantTerritory** (13, 22): reserva para encontros
  futuros. **Nenhuma criatura nova** é criada agora.

A verificação automática confere:
- o bosque tem mais árvores que a região rochosa;
- a região rochosa tem mais pedras que árvores.

### RF-MAP-006 — Futuras ResourceZones (marcação)

**Prioridade:** PODE
**Status:** PROVISÓRIO

São Marker3D só com nome e tamanho, sem coleta:
- `ResourceZones/WoodlandReserve` (−17, 20), 9 × 10 m: madeira;
- `ResourceZones/StoneReserve` (17, 17), 9 × 12 m: minério.

### RF-MAP-007 — Três rotas noturnas (NightRoutes)

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-004, RF-AGE-010

| Entrada (marcador) | Ponto de spawn | Caminho até o refúgio |
|---|---|---|
| `RuinEntry` (norte) | (0, 0,5, 23) | Arco → bifurcação → campina → estrada |
| `WestEntry` | (−20, 0,5, 2) | `WestTrail` pelo estreitamento oeste |
| `EastEntry` | (20, 0,5, 2) | `EastTrail` pelo estreitamento leste |

O código não mudou. `EnemySpawnPoint` está em (0, 0,5, 23), e os
`spawn_offsets` do WaveManager trazem as entradas oeste e leste nas posições
1 e 2 da lista. Pela regra da Spec 010, "o n-ésimo inimigo começa pelo
n-ésimo ponto", então cada inimigo da onda de 3 sai de uma entrada. As
posições seguintes da lista são vizinhas dessas entradas, usadas como
reserva quando um ponto está ocupado.

**Critérios de aceitação**

- Dado o início da noite, então os 3 inimigos nascem a mais de 15 m uns dos
  outros, sobre a navmesh e fora de sólidos.
- Dado o percurso, então os 3 chegam a ≤ 1,5 m do refúgio e causam dano.

### RF-MAP-008 — Estreitamentos e marcos

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Estreitamentos** (passagens de ~5 m entre um sólido de cada lado, sem
  nada na faixa da trilha):
  - `WestChoke` (−14, 0,2): árvore ao sul, pedra ao norte;
  - `EastChoke` (14,2, −0,2): dois blocos;
  - `HeathGate` (13,8, 20,6): dois blocos na trilha rochosa.
- **O mapa não vira um labirinto de corredores:** a campina e a base ficam
  abertas.
- **Marcos (`Landmarks`):**
  - `Refuge`, com a fogueira e os estandartes existentes;
  - `DefensePost`;
  - `Fork`;
  - `OldArch`, o arco de pedra em (0, 16);
  - `StoneGarden`, os blocos;
  - os três estreitamentos.

### RF-MAP-009 — Legibilidade com a câmera estratégica

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-CAM-001

A câmera não mudou. O layout é que se adapta a ela:
- copas baixas (2,8–3,7 m);
- nenhum tronco a menos de 3,5 m **do lado da câmera** (+Z) da linha
  central de qualquer trilha. Nesse lado ficam só pedras baixas, e as
  árvores dos estreitamentos ficam do lado de trás.

O teste amostra 11 pontos por trecho de cada trilha.

### RF-MAP-010 — Colisões e navmesh do novo mapa

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-FIS-001, RF-NAV-001

- **Pipeline:** `build_first_map.gd` → `build_collisions.ps1` (que roda
  `tools/build_collisions.gd`) → `bake_navmesh.gd`.
- **Leitura nativa das cenas:** o gerador antigo lia `position = …` como
  texto e não entendia o `transform = Transform3D(…)` que o Godot salva
  quando há rotação ou escala. `build_collisions.gd` instancia
  `arena_art.tscn` e usa `position`, `rotation` e `scale` reais de cada
  nó.
- **Inventário:** os mesmos **66** sólidos da Spec 009 (42 troncos, 16
  pedras, 3 peças do arco, 2 fogueiras, 2 mastros, 1 núcleo), escala
  unitária. As camadas também são as mesmas: 1 para natureza, 4 para
  base/arco.
- **Única diferença:** a altura do colisor de pedra segue a altura visual
  (`max(0,85, escala_y × 0,9)`), porque os blocos da região rochosa são
  mais altos. Pedras pequenas mantêm 0,85 m.
- **Navmesh:** mesmos parâmetros da Spec 010 (incluindo
  `region_min_size = 8`, contra ilhas). São 532 polígonos, sem nenhum
  vértice acima de 0,6 m: não há ilhas em cima de pedras ou do arco.

**Critérios de aceitação**

- Dado cada sólido, então o colisor está no mesmo XZ do visual (desvio
  máximo medido 0,000 m) e com raio derivado da escala visual.
- Dado cada visual sólido (tronco, pedra, arco, fogueira, mastro, núcleo),
  então existe colisor.
- Dado o PlayerSpawn, então base, BuildZone, transição, bifurcação, bosque,
  clareira, região rochosa, reservas, estreitamentos e as três entradas
  têm caminho pela navmesh.

## Alternativas descartadas

- **Mapa gerado por sorteio.** Descartado: o mapa precisa ser aprendido e
  testado, então as posições são fixas.
- **Mudar a câmera** para enxergar sob as copas. Descartado: o pedido proíbe,
  e o layout resolve.
- **Árvore no centro da trilha como estreitamento** (como estava na trilha
  oeste). Descartado: parece erro e esconde o Player.

## Perguntas em aberto

- O respawn continua a 5 m do refúgio. Quando houver construção, o
  PlayerSpawn deve ir para dentro da BuildZone?
- A DistantTerritory deve receber um encontro mais forte em uma Spec futura?
- As escarpas fora das paredes são suficientes como limite, ou o grupo quer
  um limite físico visível (cerca/rochas com colisão)?

## Não aplicável a este jogo

*Nenhuma.*
