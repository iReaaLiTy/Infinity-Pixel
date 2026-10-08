# Spec 012 — Registro de validação (2026-10-04)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows
(Intel Iris Xe).

## Ponto de partida: trabalho parcial do GPT-6 Astra

A pasta do projeto **não é rastreada pelo git**: o repositório fica um nível
acima e a mostra como `?? ./`. Por isso não havia diff. O trabalho do Astra
foi identificado pela data de modificação (19:54–20:02 de 2026-10-04,
depois da Spec 011, que terminou às 17:33).

**Criados pelo Astra:**
- `tools/build_first_map.gd`: gerador autoral do vale;
- `scenes/world/world_regions.tscn`: zonas, trilhas e marcadores;
- `tools/build_collisions.gd`: leitura nativa das cenas;
- `tools/test_spec012.ps1`: executor de suítes;
- `tests/world_layout.gd/.tscn`: suíte da Spec 012;
- `tests/map_showcase.gd/.tscn`: capturas visuais;
- `docs/validation/spec012-evidence/`: logs e capturas.

**Modificados pelo Astra:**
- `scenes/visuals/arena_art.tscn`: árvores, pedras, limites e escarpas
  reposicionados;
- `scenes/world/prototype_area.tscn`: chão 48 × 52, PlayerSpawn (0, 1, −10),
  EnemySpawnPoint (0, 23), offsets das 3 entradas, encontro em (−10, 10),
  instância de `WorldRegions`;
- `scenes/world/arena_collision.tscn` e `arena_navmesh.tres`: regenerados;
- `tools/build_collisions.ps1`: passou a chamar o script Godot;
- `tools/build_visuals.py`: gerador antigo bloqueado quando o mapa autoral
  existe;
- `tests/physics_contracts.gd`: teste de parede diagonal relativo à parede
  real.

**Estado em que ficou:**
- O mapa, as zonas, as 3 rotas, a leitura nativa das colisões (66
  primitivas) e o bake estavam **concluídos** nos arquivos.
- A Spec 012 em `docs/specs`, o tracker, o cycle e o journal **não tinham
  sido feitos**. A aprovação da Spec 011 não foi registrada.
- Logs do Astra: física 22/23, navegação 37/38 e `world_layout` com parse
  error. Esses logs eram de uma execução anterior às últimas edições dele.
  Rodando o estado do disco antes de mexer: `world_layout` 47/47, física
  23/23, navegação 37/38.
- A **última edição** do Astra (`material()` com `srgb_to_linear()`) nunca
  foi aplicada às cenas: ele não rodou o gerador depois dela.

Os logs parciais dele foram preservados em `spec012-evidence/astra-parcial/`.

## Problemas encontrados e correções

| Problema | Causa | Correção |
|---|---|---|
| Navegação 37/38: "Após o Player correr, os 3 voltam a cercar" | Interação com a Spec 011: os 3 perseguidores **matavam o Player** no meio da medição e ele renascia no PlayerSpawn (log "[Player] morreu"/"renasceu") | Fixture do teste deixa o Player invulnerável (`_invulnerable_left = INF`), com comentário. Os contratos de navegação não mudaram; a vida tem suíte própria |
| Cores muito escuras ao regenerar | `srgb_to_linear()` convertia duas vezes (o `albedo_color` já é sRGB) | Removido; as cores voltaram exatamente às que o Astra tinha salvo |
| Região rochosa sem cara de rochosa | Pedrinhas pequenas e 5 árvores no meio | 5 árvores levadas para o bosque; 8 pedras do leste viraram blocos de 1,5–2,0 m |
| Bifurcação difusa | Trilhas do bosque e das pedras saíam em z = 4 e z = 14 | As duas saem de (0, 6), com piso de bifurcação e marcador `Fork` |
| Árvore no meio da trilha oeste | Tronco em (−14, 0), sobre a `WestTrail` | Estreitamento refeito: árvore do lado de trás e pedra do lado da câmera |
| Copas escondendo o Player | Árvores a < 3,5 m do lado da câmera das trilhas (no estreitamento oeste e na trilha do bosque) | Árvores movidas; nova verificação automática de oclusão |
| Pedras dos estreitamentos novos invadindo a faixa da trilha (achado pela verificação nova) | Posicionamento inicial meu | Afastadas para as margens |
| Captura do bosque dentro de uma árvore | Ponto do `map_showcase` em cima de um tronco | Pontos de captura em trilhas; captura da bifurcação adicionada |

Colisor de pedra: a altura passou a seguir a escala visual
(`max(0,85, escala_y × 0,9)`), porque os blocos são mais altos. Quantidade,
camadas e escala unitária continuam iguais.

## Resultados automatizados (execução final)

| Suíte | Headless | Janela GL |
|---|---|---|
| `tests/world_layout.tscn` (Spec 012) | 57/57 | 57/57 |
| `tests/player_health.tscn` (Spec 011) | 47/47 | 47/47 |
| `tests/player_facing.tscn` | 37/37 | 37/37 |
| `tests/physics_contracts.tscn` (Spec 009) | 23/23 | 23/23 |
| `tests/navigation_contracts.tscn` (Spec 010) | 38/38 | 38/38 |
| `tests/acceptance.tscn` | 33/33 | 36/36 (3 de 4 execuções; ver abaixo) |
| Cena principal pelo MCP Godot | sem erros | — |

**Acceptance com janela:** a primeira execução terminou com exit 139 (crash do
processo), sem linha de resultado e sem a saída capturada. As três seguintes
deram 36/36 e exit 0. A causa não foi identificada. Registrado como
intermitente; não se usa como aprovação.

Os JSONs finais estão em `spec012-evidence/*_headless.json` e
`*_Windows.json`.

### O que `world_layout` verifica

- PlayerSpawn a 3–7 m do refúgio; Player nasce nele com 100 HP; o encontro
  territorial fica na clareira das criaturas.
- Navmesh sincronizada. Cada marcador de região, entrada, marco e
  estreitamento:
  - está na navmesh (≤ 0,35 m);
  - tem caminho a partir do spawn;
  - não tem sobreposição sólida.
- BuildZone 8 × 10 m aberta e navegável nas 9 amostras.
- WASD real: o Player sai da base, passa pelo arco e chega a z > 20.
- Morte e respawn voltam à área segura nova.
- Troncos e pedras são buracos na navmesh, e nenhum vértice fica acima de
  0,6 m (sem ilhas).
- **66 colisores** com o mesmo XZ e o mesmo raio dos visuais (desvio máximo
  0,000 m), e nenhum sólido visual sem colisor.
- Nenhum obstáculo dentro da faixa das trilhas, e nenhuma copa do lado da
  câmera escondendo trilhas.
- O bosque é mais arborizado; a região rochosa tem mais pedras que árvores.
- Onda real:
  - 3 inimigos em entradas a mais de 15 m umas das outras;
  - os 3 percorrem as rotas e atacam o refúgio;
  - a onda vencida volta ao dia sem interrupção;
  - o refúgio em 0 dá derrota.

## Verificação visual (capturas pela câmera real de gameplay)

`tests/map_showcase.tscn` é **ferramenta de evidência visual**, não teste
com asserções. Ele exige janela e grava 12 PNG em `spec012-evidence/views/`:

| Vista | Conferido |
|---|---|
| Spawn | Player nasce na frente do refúgio iluminado, posto de defesa e estrada visíveis |
| BuildZone | Clareira clara à direita do refúgio, sem obstáculos |
| Saída / transição | Estrada e campina abertas, bordas com poucas árvores |
| Bifurcação | Y claro: estrada segue para o arco, trilhas para bosque e pedras |
| Clareira das criaturas | WildDino na clareira, bosque denso ao redor |
| Bosque | Árvores densas e piso escuro, Player visível na trilha |
| Região rochosa | Blocos claros, piso claro, poucas árvores só na borda |
| Arco / entrada norte | Arco reconhecível, bosque à esquerda e pedras à direita |
| Rotas oeste/leste | Estreitamentos legíveis, Player visível |
| Visão geral (câmera diagnóstica separada, nunca usada no jogo) | Layout completo |

## Limites conhecidos

- O acceptance com janela teve 1 crash intermitente em 4 execuções, sem
  causa identificada.
- As escarpas e cristas fora das paredes são só visuais. O limite físico é a
  parede invisível de 0,4 m (Spec 009), como antes.
- A DistantTerritory e as ResourceZones são só marcadores.
- A sensação de "mais perigoso" vem da densidade, das cores e da distância.
  Não há encontros novos.
- `test_spec012.ps1` (do Astra) troca `APPDATA` por uma pasta temporária e
  roda as suítes sem janela visível. As execuções desta validação foram
  feitas direto no executável console.

## Reproduzir

```powershell
Godot_console --headless --path . --script res://tools/build_first_map.gd
powershell -File tools/build_collisions.ps1
Godot_console --headless --path . --script res://tools/bake_navmesh.gd
Godot_console --headless --path . --fixed-fps 60 res://tests/world_layout.tscn
Godot_console --path . res://tests/map_showcase.tscn -- --output=<pasta>
```

## TESTE MANUAL NECESSÁRIO

1. Nascer e reconhecer a base, o refúgio e a BuildZone.
2. Sair pela estrada, atravessar a campina e chegar à bifurcação.
3. Explorar o bosque (clareira do selvagem) e a região rochosa (portão de
   pedras).
4. Andar por trilhas e bordas procurando árvores que escondam o Player,
   colisões invisíveis ou sólidos atravessáveis.
5. Conferir os estreitamentos oeste e leste.
6. Iniciar a noite e observar os 3 inimigos chegando por direções
   diferentes.
7. Domesticar o selvagem, posicionar aliados, morrer e renascer na base.
