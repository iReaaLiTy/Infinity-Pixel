# 010 — Navegação, avoidance e movimentação em grupo das criaturas

Ciclo 1 — Núcleo Jogável (pedido em 2026-10-03, após a Spec 009).

Resolve o empilhamento das criaturas: trajetórias iguais, filas, sobreposição,
todas disputando o mesmo ponto e IA direta presa atrás dos obstáculos sólidos
da Spec 009. Preserva as Specs 007 (câmera/mira), 008 (noite → dia contínua) e
009 (camadas, máscaras e 66 obstáculos), além de todos os valores de combate e
domesticação. Implementada; **aguardando playtest visual e aprovação**.

## Fora do escopo

- Spec 011: HP, morte, respawn, invulnerabilidade e HUD de vida do Player.
- Colisão física entre criaturas (máscara 11 da Spec 009 mantida). A separação
  vem do avoidance e dos slots, não de corpos se empurrando.
- Navmesh dinâmica (rebake em jogo), construção, recursos, coleta, save/load,
  mapa novo e seleção avançada de aliados.
- Linha de visão para ataque/domesticação; alcances, dano, HP e velocidades.

## Requisitos

### RF-NAV-001 — Navmesh da arena assada a partir das colisões reais

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-FIS-001, RF-FIS-002

`prototype_area.tscn` tem um `NavigationRegion3D` (`NavigationRegion`) com
`scenes/world/arena_navmesh.tres`. A malha é gerada offline por
`tools/bake_navmesh.gd` a partir dos **colisores estáticos** da máscara 9
(mundo + base/construções, Spec 009) dos nós no grupo `navigation_source`
(`Ground`, `ArenaArt` com os limites, `ArenaCollision`). A mesma configuração
fica salva no recurso, então o botão "Bake NavigationMesh" do editor gera o
mesmo resultado.

| Parâmetro | Valor | Motivo |
|---|---|---|
| `cell_size` / `cell_height` | 0,25 / 0,25 | Iguais ao padrão do mapa 3D |
| `agent_radius` | 0,5 | Cápsula do WildDino/Carnotauro |
| `agent_height` | 1,75 | 1,6 m da cápsula, múltiplo de `cell_height` |
| `agent_max_climb` / `agent_max_slope` | 0,25 / 45° | Pedras (0,85 m) viram obstáculo |
| `region_min_size` | 8 (64 células ≈ 4 m²) | Remove ilhas isoladas (topo de pedra/arco) |

Resultado: 329 polígonos, só no nível do chão. Árvores, pedras, pilares, postes
e o núcleo do refúgio são buracos. A borda do buraco do núcleo fica a ~1,0 m
do centro, dentro da chegada de 1,5 m. Regerar:
`Godot_console --headless --path . --script res://tools/bake_navmesh.gd`.

**Critérios de aceitação**

- Dado o jogo iniciado, então o mapa de navegação tem a região sincronizada.
- Dado o centro de uma pedra/árvore, então o ponto navegável mais próximo fica
  fora dela (ex.: Rock21 → 1,30 m do centro).
- Dado o spawn e o refúgio, então existe caminho entre eles.

**Origem:** IA direta parava atrás dos sólidos da Spec 009.

### RF-NAV-002 — NavigationAgent3D nas criaturas existentes

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-001

`wild_dino.tscn` e `carnotauro.tscn` ganharam um `NavigationAgent3D`. O
`wild_dino.gd` mantém a máquina de estados (perseguir, ir à base, voltar à
origem territorial, aliado seguir/ficar/defender/voltar ao posto, canalização)
e troca só **como** cada estado anda: `_navigate_to()` dá a direção do próximo
ponto do caminho; gravidade, `move_and_slide`, velocidades (4 m/s, noite ×1,2)
e regras de ataque ficam iguais. Sem navmesh na cena, cai na IA direta antiga.

- Caminho novo só quando o destino anda > 0,5 m, no máximo 5×/s.
- Destino enviado na altura da superfície da navmesh (o agente mede chegada em
  3D; sem isso todo destino parecia inalcançável).
- Busca de alvo por grupos a cada 0,15 s, não a cada quadro; Player em cache.

**Critérios de aceitação**

- Dado um Player atrás de uma pedra, então o perseguidor recebe caminho com
  desvio e chega ao alcance do golpe.
- Dado o WildDino territorial sem alvo, então volta à origem pela navegação.
- Dado o Carnotauro, então navega igual e continua não domesticável.

### RF-NAV-003 — Slots de aproximação individuais e estáveis + avoidance

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-002

Cada alvo (Player, aliado, refúgio) guarda em metadata os próprios slots
(`scenes/enemies/approach_slots.gd`). Slot = ponto num anel ao redor do alvo,
em ângulo **fixo no mundo** (não gira com o alvo, não é sorteado).

| Tipo | Anel 0 (alcance) | Anel 1 (espera) |
|---|---|---|
| `attack` (Player/aliado/hostil) | 6 × 1,7 m (golpe: 2 m) | 10 × 3,2 m |
| `base` (refúgio) | 6 × 1,2 m (chegada: 1,5 m) | 10 × 2,6 m |
| `follow` (aliados) | 5 × 2,6 m | 8 × 4,0 m |

Escolha: slot livre, fora de obstáculo (projeção na navmesh ≤ 0,6 m), com
menor custo = distância − 1,5 × arco até o slot ocupado mais próximo. O
primeiro pega o mais perto; os seguintes se espalham e **cercam** o alvo.
A criatura mantém o slot até: trocar de alvo, morrer/sair da cena, ser
domesticada, mudar seguir/ficar, ou o slot ficar inalcançável/preso. Quem
está no anel de espera sobe para o anel 0 quando abre vaga (revisão a cada
0,5 s). Ataque continua pela distância ao alvo (2 m / 1,5 m), como antes.

Avoidance (RVO) do `NavigationAgent3D`: raio 0,55, altura 1,6,
`neighbor_distance` 5, `max_neighbors` 8, `time_horizon_agents` 0,75,
`max_speed` 5,5. A velocidade desejada vai para o servidor e o
`move_and_slide` roda no `velocity_computed`. Criatura sem nada a fazer
(parada no slot/posto/canalização) fica firme **sem** avoidance: os outros a
contornam e ela não é empurrada para fora do alcance. O Player tem um
`NavigationObstacle3D` (raio 0,45) para as criaturas desviarem do corpo dele.

**Critérios de aceitação**

- Dado 3 perseguidores, então ocupam 3 slots diferentes, dentro de 2 m, sem
  se sobrepor (≥ 0,9 m), cercando o Player (maior vão ≤ 200°).
- Dado o Player parado, então os slots não mudam (sem sorteio, sem jitter).
- Dado o Player correndo, então os 3 se reposicionam ao redor dele.
- Dado morte ou domesticação, então o slot é liberado.

### RF-NAV-004 — Spawns separados e chegada distribuída ao refúgio

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-001, RF-NAV-003, RF-AGE-010

`WaveManager.spawn_offsets` (Inspector) lista 9 pontos fixos ao redor do
`EnemySpawnPoint`, entre os pilares do arco. O n-ésimo inimigo da onda começa
a busca pelo n-ésimo ponto. Um ponto é aceito se está na navmesh (≤ 0,3 m),
sem sólido/Player/criatura sobreposto (consulta de cilindro na máscara
1+2+4+8) e a ≥ 1,3 m de outra criatura. A busca roda só no spawn. Intervalo de
2 s e quantidade (3) não mudam.

**Critérios de aceitação**

- Dado o início da noite, então os 3 nascem em pontos diferentes
  (hoje (0; 15), (−1,6; 13,6), (1,6; 13,6)) sobre a navmesh.
- Dado os 3 chegando ao refúgio, então ocupam 3 slots diferentes, ficam a
  ≤ 1,5 m do centro, distribuídos ao redor, e todos causam dano.
- Dado a base a 0 HP, então a derrota continua igual.

### RF-NAV-005 — Slots individuais para aliados

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-003, RF-AGE-007, RF-AGE-008

Seguindo, cada aliado vai para o próprio slot `follow` ao redor do Player, com
histerese (parado no slot, só volta a andar quando o slot se afasta > 1 m).
Sem vaga, volta ao comportamento anterior (parar a 2,5 m). Ficar/defender
usa slots `attack` ao redor do hostil; voltar ao posto usa a navegação. F,
raio de defesa (8 m) e regra "F só de dia" não mudam.

**Critérios de aceitação**

- Dado 3 aliados seguindo, então ocupam 3 slots diferentes, separados ≥ 1 m,
  antes e depois do Player andar.
- Dado um aliado em FICAR, então ataca o hostil no raio e volta ao posto.

### RF-NAV-006 — Recuperação: caminho inválido, destino inalcançável, preso

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-NAV-002

- Destino fora da navmesh: o agente vai ao ponto alcançável mais próximo e
  para (`is_navigation_finished`), sem empurrar contra a parede.
- Slot inalcançável (atrás de obstáculo): troca por outro slot.
- Preso (querendo andar e < 0,25 m de progresso em 1 s): recalcula o caminho
  e, em slot de ataque/base, troca de slot. Em slot de seguir/posto, se já
  está a ≤ 1 m do destino (ex.: slot ocupado por um aliado parado), aceita
  "perto o suficiente" e para, sem oscilar.
- Um log `[NAV] ... sem progresso` por episódio, nunca por quadro/segundo.

**Critérios de aceitação**

- Dado um seguidor cujo slot está ocupado por um aliado parado, então ele para
  perto (≤ 1 m) sem oscilar nem gerar log repetido.

## Testes

`tests/navigation_contracts.tscn` (cena real, física e IA reais, 38 checks).
Resultados e limitações em `../validation/spec010.md`.

**TESTE MANUAL NECESSÁRIO:** A a E do pedido (noite com 3 inimigos sem fila,
contorno de árvore/pedra, perseguição com o Player correndo, vários aliados,
ataque distribuído ao refúgio) e a sensação geral do movimento.

## Alternativas descartadas

- **Offsets aleatórios por criatura:** pedido explicitamente fora; também
  mudaria a cada spawn e não resolve obstáculos.
- **Colisão física entre criaturas:** empurrões e travamentos em corredor;
  mudaria o contrato da Spec 009.
- **Rebake da navmesh em runtime:** custo no carregamento sem ganho, já que o
  mapa é estático; o bake offline fica inspecionável no editor.
- **Slot mais próximo puro:** testado; os 3 enchiam o mesmo lado do alvo
  (arco), sem cercar. Trocado pelo custo com espalhamento.

## Perguntas em aberto

- O anel do refúgio (1,2 m) é limitado pela chegada de 1,5 m: com mais de 6
  inimigos, os excedentes esperam no anel de 2,6 m sem atacar. A regra de
  chegada deve crescer quando a onda crescer?
- Aliados devem preferir slots "atrás" do Player (em relação à câmera)?
- Quando construções existirem, a navmesh precisará de rebake/obstáculos
  dinâmicos.

## Não aplicável a este jogo

*Nenhuma.*
