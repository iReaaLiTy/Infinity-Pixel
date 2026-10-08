# 009 — Contratos físicos, colisões e obstáculos

Ciclo 1 — Núcleo Jogável (fundação física solicitada em 2026-10-03).

Complementa os ADRs 0001/0002. Preserva integralmente os scripts de gameplay,
a câmera da Spec 007 e a continuidade noite → dia/HUD da Spec 008 existentes.
Implementada; **aguardando aprovação e playtest manual**.

## Fora do escopo

- Spec 010: navegação, navmesh, avoidance, separação de spawns, posições de
  aproximação e correção do empilhamento de criaturas.
- Spec 011: HP, dano real, morte, respawn e HUD de vida do Player.
- Construção, coleta, recursos, save/load, mapa novo e ciclo automático.
- Linha de visão para ataque/domesticação e alterações de alcance/balanceamento.

## Requisitos

### RF-FIS-001 — Contrato explícito de camadas e máscaras

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** ADR 0001, ADR 0002

Os nomes ficam em `project.godot`, visíveis no Inspector. O número da camada
é diferente do valor do bit usado pela máscara serializada:

| Camada | Bit | Papel |
|---|---|---|
| 1 | 1 | Mundo: chão, limites, troncos, pedras |
| 2 | 2 | Player |
| 3 | 4 | Criaturas selvagens, Carnotauro e aliados |
| 4 | 8 | Base e construções: núcleo, arco, postes |
| 5 | 16 | Interações, reservada para futuras Areas detectáveis |
| 6 | 32 | Projéteis, reserva |

| Objeto | Layer (bit) | Mask (bits) | Efeito |
|---|---|---|---|
| Player | 2 | 13 = 1+4+8 | Bloqueia mundo, criaturas e construções |
| WildDino/Carnotauro/aliado | 4 | 11 = 1+2+8 | Bloqueia mundo, Player e construções |
| Chão/limites/troncos/pedras | 1 | 0 | Corpos móveis os detectam por suas máscaras |
| Núcleo/arco/postes | 8 | 0 | Corpos móveis os detectam por suas máscaras |
| AttackArea3D | 0 | 4 | Overlap somente com criaturas; não bloqueia movimento |

As máscaras são declaradas nas cenas, sem reatribuições dispersas em gameplay.
O gerador usa constantes nomeadas `worldLayer` e `buildingLayer`. O teste
compara as cenas com combinações de bits nomeados, evitando deriva silenciosa.
A camada 5 não é atribuída ao ataque: a Area já funciona como sensor sem
precisar ser detectada por outro sensor. Domesticação e detecção da IA usam
grupos/distância; não há uma Area de domesticação para transformar em corpo.

**Critérios de aceitação**

- Dado o projeto aberto, então as seis camadas possuem nomes no Inspector.
- Dadas as cenas de personagem/criaturas, então suas máscaras correspondem
  à tabela e a domesticação preserva a máscara.
- Dada a Area de ataque, então só consulta criaturas e não bloqueia corpos.

**Origem:** pedido de preparar contratos físicos coerentes sem quebrar combate.

### RF-FIS-002 — Obstáculos sólidos com primitivas simples

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-FIS-001

`scenes/world/arena_collision.tscn`, instanciada em `prototype_area.tscn`,
contém 66 StaticBody3D com CollisionShape3D, escala unitária e grupo
`solid_obstacles`. Os nomes correspondem aos elementos de `ArenaArt`:

| Objetos | Quantidade | Forma |
|---|---|---|
| Trunk0…41 | 42 | Cápsula, raio 0,25 m, altura do tronco |
| Rock0…45 (índices de três em três) | 16 | Cilindro, altura 0,85 m, raio 45% da maior dimensão horizontal |
| ArchPillar-1/1 e ArchTop | 3 | Caixas com dimensões/rotação do visual |
| FirePost-1/1 e BannerPole-2/2 | 4 | Cilindros com dimensões do visual |
| RefugeCore | 1 | Cilindro, raio 0,55 m, altura 2,6 m |

Chão e quatro limites físicos já existiam e são preservados. Samambaias,
copas, chamas, bandeiras de tecido, marca do posto e plataforma/anel baixos
continuam decorativos. Montanhas e falésias de fundo ficam além dos limites
jogáveis. Não há cerca nem portão fechado no mapa atual.

As primitivas aproximam o volume sólido; não são colisões por triângulos.
O raio do núcleo permite que a cápsula de criatura (raio 0,5 m) alcance o
limiar atual de ataque à base (1,5 m). Transformar a plataforma inteira
(raio 2,5 m) em obstáculo impediria esse ataque. O `Territory` mantém seu
script, grupos e método de dano: o corpo estático não é um novo alvo de dano.

**Critérios de aceitação**

- Dado o Player andando contra tronco, pedra, arco ou núcleo, então seu
  corpo é bloqueado, sem atravessar o obstáculo.
- Dado movimento diagonal contra uma parede, então `move_and_slide`
  preserva movimento tangencial à superfície.
- Dadas as colisões, então não usam trimesh nem herdam escala não uniforme.
- Dado o mapa atual, então o corredor central e o espaço do encontro
  diurno permanecem livres para a IA direta existente.

**Origem:** sólidos visíveis dentro da arena ainda eram apenas meshes.

**Hipótese de protótipo — Aproximação do volume sólido**
- **Valor inicial:** cápsulas nos troncos, cilindros nas pedras, caixas no arco.
- **Pergunta do protótipo:** a aproximação é legível e permite contornar quinas?
- **Teto ou limite de exploração:** ajustar primitivas sem bloquear os corredores
  nem expandir o núcleo além do alcance possível da IA atual.

### RF-FIS-003 — Preservação do gameplay e compatibilidade temporária

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-FIS-002, Specs 001–008

Player continua CharacterBody3D, velocidade 6, gravidade 9,8, movimento
relativo à câmera, cursor para mira e ataque por overlap (20 de dano,
cooldown 0,8 s). Criaturas continuam na IA direta, sem navegação nova.
WildDino tem 80 HP, limiar 30%, canalização E por 2 s a 3 m, cancelamentos
e alvo travado; aliados preservam HP/proteção de friendly fire. Carnotauro
continua não domesticável. Fluxos de pausa, Controles, derrota e amanhecer
contínuo permanecem como nas Specs 007/008.

Criaturas não colidem entre si, exatamente como antes: incluir o bit 4 em
sua máscara agora bloquearia a fila da onda sem fornecer contorno de obstáculos.
Elas colidem com o cenário; perseguir alguém atrás de uma árvore pode deixá-las
paradas até mudar o alvo/direção. Os percursos centrais ficam livres, mas não
há garantia de caminho para qualquer posição do mapa nesta IA.

**Critérios de aceitação**

- Dada a IA sem jogador interferindo, então percorre spawn → refúgio e
  efetivamente reduz o HP da base apesar do novo colisor.
- Dados três ataques válidos, então WildDino fica em 20/80 e pode ser domesticado.
- Dada vitória da onda, então volta ao dia sem modal/pausa e preserva aliados.
- Dado clique consumido pela HUD, então não inicia o cooldown do ataque.

**Origem:** manter o núcleo jogável enquanto a navegação aguarda a Spec 010.

## Decisões arquiteturais e preparação para Spec 010

- Colisões ficam em cena própria, editável no Inspector; nenhum script cria
  corpos a cada frame. Arte, câmera, UI, IA e combate não foram reescritos.
- `tools/build_collisions.ps1` lê a arte atual e refaz somente essa cena:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_collisions.ps1`.
  Não altera política persistente do Windows. Depois de regenerar/mover arte,
  refazer/revisar colisões e executar os testes; os dois roots usam a mesma origem.
- IDs de recursos usam apenas letras/números/underscore; nomes dos corpos
  mantêm a correspondência visual. Escala de mesh é incorporada às dimensões.
- Para a Spec 010, mundo e construções podem ser selecionados pelos bits 1 e
  8 (máscara 9), incluindo chão/limites existentes, e o grupo distingue novos
  obstáculos. Isso **não cria navmesh**: bake, raio/altura de agentes, rotas,
  colisão entre criaturas e avoidance precisam de decisão/teste próprios.
- Não há linha de visão: ataques por distância/overlap e domesticação ainda
  podem alcançar o outro lado de um sólido fino. Preservado o contrato atual.

## Testes

Ver `../validation/spec009.md` para execução, resultados e limitações.
`tests/physics_contracts.tscn` usa as cenas reais, input W, `test_move`,
`move_and_slide` e IA real. `tests/acceptance.tscn` cobre regressões anteriores.
`--evidence-dir=user://spec009-regression` evita sobrescrever evidências AC1.

**TESTE MANUAL NECESSÁRIO:** percorrer bordas/árvores/pedras e ambos os pilares,
contornar quinas em diagonal, avaliar encaixe visual e sensação de bloqueio;
conduzir/domesticar aliado e jogar uma noite completa, consultar Controles e
confirmar que o amanhecer continua fluido. Aprovação humana ainda pendente.

## Alternativas descartadas

- Trimesh detalhado para cada árvore/pedra: custo e quinas desnecessários.
- Colisor na plataforma inteira: impediria alcançar a base com a IA atual.
- Colidir criaturas entre si ou adicionar offsets: introduziria bloqueio ou
  anteciparia uma solução parcial para a Spec 010.
- Gerar colisões automaticamente em runtime: dificulta inspeção e adiciona
  dependência de nomes de meshes ao código de gameplay.

## Perguntas em aberto

- Quais aproximações de pedra/quina precisam ajuste após playtest?
- Como a navegação futura tratará a plataforma baixa e as rotas periféricas?
- Quando revisar linha de visão e colisão entre criaturas junto à Spec 010?

## Não aplicável a este jogo

*Nenhuma.*
