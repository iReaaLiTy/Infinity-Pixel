# 001 — Controle do Jogador

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Combos de ataque — adiado para ciclo futuro, foco do Ciclo 1 é provar o núcleo.
- Habilidades especiais — depende do sistema de progressão, fora do Ciclo 1.
- Esquiva — não faz parte do recorte mínimo do Ciclo 1.
- Múltiplas armas — depende do sistema de equipamentos, fora do Ciclo 1.

## Requisitos

### RF-AGE-001 — Movimento do personagem

**Prioridade:** DEVE
**Status:** PROVISÓRIO

O jogador controla o personagem em 3D, câmera em terceira pessoa, com
movimentação livre em qualquer direção via WASD e controle de câmera pelo
mouse.

> **Atualização 2026-10-03:** a câmera em terceira pessoa e o giro da câmera
> pelo mouse foram substituídos pela câmera estratégica fixa e pela mira por
> cursor da `007-camera-estrategica.md` (RF-CAM-001 a 004). O movimento
> livre por WASD continua valendo, agora relativo à câmera. O 2º critério
> abaixo é histórico.

**Critérios de aceitação**

- Dado que o jogador pressiona uma direção (WASD), quando não há obstáculo,
  então o personagem se move livremente na direção correspondente.
- Dado que o jogador movimenta o mouse, quando o personagem está em qualquer
  estado, então a câmera gira em terceira pessoa acompanhando o movimento.

**Origem:** referência de controle direto de Dungeon Defenders; grupo quer
personagem ágil, mas não rápido demais.

**Hipótese de protótipo**
- **Valor inicial:** 6 m/s
- **Pergunta do protótipo:** 6 m/s dá sensação de agilidade sem parecer rápido demais para o estilo do jogo?
- **Teto ou limite de exploração:** até 8 m/s nesta rodada — acima disso o personagem pode parecer rápido demais.

### RF-AGE-002 — Ataque corpo a corpo do personagem

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-001

O jogador ataca corpo a corpo na direção em que está olhando, atingindo
dinossauros dentro do alcance, com um cooldown entre ataques consecutivos.

**Critérios de aceitação**

- Dado que um dinossauro está dentro do alcance de ataque e na direção em
  que o personagem olha, quando o jogador aciona o ataque, então o
  dinossauro recebe dano.
- Dado que o jogador acabou de atacar, quando o cooldown ainda não terminou,
  então um novo ataque não pode ser acionado.
- Dado que nenhum dinossauro está dentro do alcance e direção do ataque,
  quando o jogador aciona o ataque, então nenhum dano é aplicado.

**Origem:** grupo quer que o ataque exija se aproximar do dinossauro; sem
combos ou variação de arma no Ciclo 1.

**Hipótese de protótipo — Alcance**
- **Valor inicial:** 2 metros
- **Pergunta do protótipo:** 2 metros exige aproximação sem parecer curto demais?
- **Teto ou limite de exploração:** até 3 metros — acima disso o ataque corpo a corpo pode parecer distante demais.

**Hipótese de protótipo — Cooldown**
- **Valor inicial:** 0,8 segundos
- **Pergunta do protótipo:** 0,8s dá ritmo de combate adequado sem parecer lento?
- **Teto ou limite de exploração:** até 0,5 segundos no mínimo — abaixo disso o ataque pode parecer rápido demais.

**Hipótese de protótipo — Dano**
- **Valor inicial:** 20 pontos
- **Pergunta do protótipo:** 20 de dano por golpe mantém o combate com ritmo, sem matar inimigos comuns rápido demais?
- **Teto ou limite de exploração:** até 35 pontos — acima disso inimigos comuns podem morrer rápido demais no protótipo.

## Alternativas descartadas

*Nenhuma registrada — o grupo já chegou com a decisão de ataque corpo a corpo simples.*

## Perguntas em aberto

*Nenhuma para esta spec no momento.*

## Não aplicável a este jogo

*Nenhuma.*
