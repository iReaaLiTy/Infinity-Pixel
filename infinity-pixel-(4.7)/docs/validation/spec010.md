# Spec 010 — Registro de validação (2026-10-03)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

## Ponto de partida

O pedido dizia que outro assistente tinha começado a Spec 010. Antes de editar,
os arquivos do projeto foram conferidos e nada da Spec 010 foi encontrado:
- nenhuma spec ou ADR;
- nenhum `NavigationRegion3D`, `NavigationAgent3D` ou avoidance em cenas ou
  scripts;
- nenhum teste;
- o tracker e o cycle ainda diziam "Specs 010/011 não iniciadas";
- o git não tinha stash, branch ou commit posterior a 30/09.

A implementação partiu do estado da Spec 009, sem desfazer nada.

## Resultados automatizados (execução final)

| Execução | Resultado |
|---|---|
| `tests/navigation_contracts.tscn`, headless | 38/38 |
| `tests/navigation_contracts.tscn`, janela/renderização GL | 38/38 |
| `tests/physics_contracts.tscn` (Spec 009), headless / janela | 23/23 / 23/23 |
| `tests/acceptance.tscn`, headless / janela | 33/33 / 36/36 |
| Script de regressão Spec 007 (janela, fora do projeto) | 31/31 |
| Script de regressão Spec 008 (janela, fora do projeto) | 35/35 |
| Startup pelo Godot MCP | sem erros nem warnings |

A suíte da Spec 010 também foi executada mais 4 vezes (2 headless, 2 janela)
antes das últimas mudanças, sempre 37/37. Os relatórios JSON finais estão em
`spec010-evidence/`. A suíte acceptance foi executada com `--evidence-dir` fora
do projeto, e as evidências AC1 em `docs/ac1/evidence` foram conferidas por
hash antes e depois (intactas).

### O que a suíte da Spec 010 verifica (cena real, física e IA reais)

- **Navmesh:** região com 329 polígonos e mapa sincronizado. A pedra Rock21 é
  buraco (o ponto navegável mais próximo fica a 1,30 m do centro). A borda do
  núcleo do refúgio fica a 1,00 m do centro. Existe caminho do spawn ao refúgio.
- **Contorno:** o perseguidor recebe caminho com desvio (8 pontos), contorna a
  pedra e chega a ≤ 2 m do Player.
- **Perseguição:**
  - 3 slots de ataque diferentes, os 3 dentro de 2 m;
  - separados (≥ 0,9 m) e cercando o Player (maior vão de 181°);
  - slots estáveis com o Player parado;
  - depois do Player correr, voltam a cercá-lo e continuam separados;
  - morte e domesticação liberam o slot.
- **Aliados:**
  - 3 slots de seguir diferentes, separados antes e depois de o Player andar;
  - F → FICAR;
  - atacam o hostil e voltam ao posto;
  - seguidores param perto do próprio slot mesmo com um aliado parado ao lado.
- **WildDino territorial:** persegue dentro da área e volta à origem pela
  navegação (0,45 m). 3 golpes deixam 20/80 e elegível (30%).
- **Carnotauro:** tem agente de navegação e continua não domesticável.
- **Onda:**
  - 3 inimigos nascem em pontos diferentes sobre a navmesh: (0; 15),
    (−1,6; 13,6) e (1,6; 13,6);
  - não se sobrepõem no trajeto (menor distância ≥ 0,8 m);
  - ocupam 3 slots diferentes no refúgio, chegam a ≤ 1,5 m, ficam distribuídos
    ao redor (maior vão de 169°) e os 3 causam dano;
  - base a 0 HP continua gerando derrota.

## Problemas encontrados e corrigidos durante a implementação

1. **Topos de pedra e do arco viravam ilhas navegáveis** (vértices em
   y = 1,25 e 4,5–5,0). `map_get_closest_point` podia projetar um ponto em
   cima da pedra. Corrigido com `region_min_size = 8`. Agora só há o nível do
   chão.
2. **Todo destino parecia inalcançável.** A navmesh fica a 0,5 m acima do chão
   físico, e o agente mede a chegada em 3D. Os slots trocavam a cada 0,5 s e as
   criaturas derivavam para o centro. Corrigido: o destino agora é enviado na
   altura da superfície da navmesh.
3. **Todos os spawns no mesmo ponto**, porque o anterior já tinha saído.
   Corrigido: o n-ésimo inimigo começa pelo n-ésimo ponto.
4. **Inimigo do centro parava a 1,52 m da base e não atacava.** A margem do
   avoidance empurrava. Corrigido:
   - raio de avoidance 0,55;
   - anel da base 1,2 m e chegada 0,25 m;
   - criatura parada fica fora do avoidance.
5. **Seguidor travava no corpo do Player.** Corrigido com
   `NavigationObstacle3D` no Player.
6. **Seguidor oscilava entre slots ocupados por um aliado parado.** Corrigido
   aceitando "perto o suficiente" (≤ 1 m) em slot de seguir/posto.
7. **Slot mais próximo puro enchia um lado só do alvo.** Trocado pelo custo
   com espalhamento.
8. Dois warnings novos (variável `snapped` com nome de função nativa)
   corrigidos. O warning antigo de `wild_dino.gd` (parâmetro `delta` sem uso)
   sumiu, porque `_ally_defend` agora usa `delta` para limitar a busca.

## Diagnóstico e limites das evidências

- **Avisos de encerramento headless:** "ObjectDB instances leaked" e "1
  resources still in use" já existiam antes (registrados em `spec009.md` e no
  tracker da Spec 008). As execuções com renderização terminam sem eles.
- **O que os testes medem:** os testes provam posições, slots, distâncias e
  dano. Não provam a sensação do movimento.
- **TESTE MANUAL NECESSÁRIO (A–E):**
  - A: noite com 3 inimigos sem fila perfeita;
  - B: ficar atrás ou perto de árvore/pedra e ver o contorno;
  - C: correr com 3 perseguidores;
  - D: vários aliados seguindo em posições diferentes;
  - E: inimigos distribuídos atacando o refúgio.
