# 007 — Câmera Estratégica 3D

Ciclo 1 — Núcleo Jogável (ajuste de enquadramento pedido em 2026-10-03).

Substitui a câmera em terceira pessoa controlada pelo mouse descrita em
`001-controle-jogador.md` (RF-AGE-001, critério "a câmera gira em terceira
pessoa acompanhando o movimento" do mouse). O movimento por WASD e o ataque
corpo a corpo da Spec 001 continuam valendo; muda apenas **de onde se vê** e
**como se mira**.

## Fora do escopo

- Rotação da câmera pelo jogador (girar em passos de 90°, arrastar com botão
  do meio) — a orientação é fixa nesta spec; pode virar spec futura.
- Zoom pela roda do mouse — os parâmetros existem no Inspector, mas não há
  controle em jogo nesta spec.
- Movimento por clique (point-and-click) e pathfinding/`NavigationAgent3D`.
- Oclusão (fade de árvores entre a câmera e o jogador).
- Ajuste de tamanho/legibilidade dos rótulos 3D sobre as criaturas e
  qualquer reformulação de HUD.
- Spec 008, remoção do modal "Noite defendida", novo dia/noite, construção,
  recursos, coleta, mapa, save/load, seleção de aliados, vida/respawn do
  jogador, céu, novas criaturas ou mecânicas.

## Requisitos

### RF-CAM-001 — Câmera estratégica elevada

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** parte de câmera de RF-AGE-001

A câmera é uma `Camera3D` em perspectiva, elevada em 3/4, olhando
diagonalmente para baixo para o jogador, que fica sempre visível perto do
centro da tela. O enquadramento mostra uma área considerável ao redor
(criaturas, terreno, base). Não é câmera FPS nem fica colada atrás do
personagem. Parâmetros exportados no Inspector: distância, inclinação
(pitch), orientação (yaw), FOV, deslocamento do foco e suavização.

**Critérios de aceitação**

- Dado que a partida começou, então a câmera atual é a câmera estratégica, em
  projeção perspectiva, com a inclinação configurada.
- Dado que o jogador está em qualquer ponto da arena, então ele aparece
  dentro da região central da tela.
- Dado que um parâmetro da câmera é alterado no Inspector, então o
  enquadramento muda sem alterar código.

**Origem:** pedido do grupo para enquadramento de tower defense/estratégia
3D, adequado a defesa + sobrevivência + domesticação.

**Hipótese de protótipo — Enquadramento**
- **Valor inicial:** distância 20 m na linha de visão, pitch 50° (≈ 15,3 m de
  altura e ≈ 12,9 m de recuo horizontal), FOV 50°, foco 1 m acima dos pés do
  jogador, yaw 0° (câmera ao sul olhando para o norte, em direção à base).
- **Pergunta do protótipo:** esse enquadramento mostra o suficiente da arena
  sem deixar o personagem pequeno demais?
- **Teto ou limite de exploração:** distância 14–22 m de recuo, altura
  10–16 m, pitch 45–60°, FOV 45–55°.

### RF-CAM-002 — Orientação estável e acompanhamento suave

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-CAM-001

A câmera segue a **posição** do jogador com suavização, mas nunca herda a
rotação dele. Mirar ou atacar não gira a câmera.

**Critérios de aceitação**

- Dado que o jogador se move, então a câmera o acompanha e, parado, o foco
  converge para o jogador.
- Dado que o jogador gira (mira, ataque), então a orientação da câmera não
  muda.

**Origem:** orientação estratégica estável é o que torna a leitura do mapa
previsível.

**Hipótese de protótipo — Suavização**
- **Valor inicial:** `follow_smoothing = 8` (aproximação exponencial; 0 =
  sem suavização).
- **Pergunta do protótipo:** a câmera parece acompanhar sem atraso
  incômodo nem trancos?
- **Teto ou limite de exploração:** 4–15.

### RF-CAM-003 — WASD relativo à câmera

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-CAM-001, RF-AGE-001

WASD continua controlando diretamente o `CharacterBody3D`, mas as direções
são relativas à câmera projetada no plano horizontal: W = para cima na tela
(frente da câmera), S = oposto, A/D = esquerda/direita da tela. Velocidade,
gravidade e colisões da Spec 001 não mudam.

**Critérios de aceitação**

- Dado que o jogador pressiona W/S/A/D, então o personagem se move para
  cima/baixo/esquerda/direita na tela, independentemente da direção para a
  qual ele está virado.
- Dado que o yaw da câmera é alterado, então W continua seguindo a frente
  projetada da câmera.
- Dado que há um obstáculo, então a colisão continua bloqueando o movimento.

**Origem:** com câmera fixa, movimento relativo ao corpo do personagem
(como na Spec 001) ficaria confuso, porque o corpo agora vira para a mira.

### RF-CAM-004 — Mira do ataque pelo cursor

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-CAM-001, RF-AGE-002

O cursor fica visível durante o jogo. O personagem vira para o ponto do chão
sob o cursor e o ataque (RF-AGE-002) é dado nessa direção. Dano, alcance,
cooldown, contrato `take_damage`, grupo `damageable` e proteção contra fogo
amigo não mudam. Cliques consumidos pela interface (botões, painéis da HUD)
não disparam ataque no mundo.

**Critérios de aceitação**

- Dado que um dinossauro está ao lado do jogador e o jogador clica sobre ele,
  então o jogador vira para ele e o dinossauro recebe 20 de dano.
- Dado que o jogador clica na direção oposta ao dinossauro, então nenhum
  dano é aplicado.
- Dado que o jogador clica sobre um painel da HUD ou botão de menu, então
  nenhum ataque é acionado e o cooldown não começa.
- Dado que o jogador acabou de atacar, quando o cooldown ainda não terminou,
  então um novo clique não ataca.

**Origem:** com a câmera estratégica, o mouse deixa de girar a câmera e passa
a indicar a direção do golpe.

## Alternativas descartadas

- **Câmera ortográfica.** Descartada pelo pedido: perspectiva dá
  profundidade ao cenário 3D.
- **Manter a SpringArm3D filha do Player com outros valores.** Descartada:
  ela herda a rotação do Player, e o Player agora vira para a mira.
- **Câmera como nó separado na cena da arena.** Descartada por agora: exigiria
  alterar `prototype_area.tscn` e os testes que instanciam o Player; com
  `top_level = true` a câmera fica na cena do Player sem herdar seu
  transform.
- **Hit-test do ataque por consulta de forma (`intersect_shape`).**
  Descartado: trocaria o mecanismo de overlap validado na Spec 001.

## Perguntas em aberto

- O jogador deve poder girar a câmera (por exemplo, Q/E em passos de 90°) ou
  dar zoom? Hoje E é domesticar, então a tecla precisa ser decidida.
- Árvores altas perto da borda esquerda podem cobrir parte da visão. Precisa
  de fade/oclusão?
- Os rótulos 3D (HP, "Segure E") ficaram pequenos a esta distância. Devem
  ganhar tamanho fixo na tela ou migrar para a HUD?

## Não aplicável a este jogo

*Nenhuma.*
