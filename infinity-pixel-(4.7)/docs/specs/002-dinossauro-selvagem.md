# 002 — Dinossauro Selvagem (Inimigo de Onda)

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Patrulha antes da onda — inimigo não fica ativo no mapa fora da onda no Ciclo 1.
- Fuga ou retirada tática — não faz parte do recorte mínimo do Ciclo 1.
- Ataque à distância — apenas corpo a corpo no Ciclo 1.
- Múltiplos tipos de IA/espécie inimiga — Ciclo 1 tem apenas um tipo de IA
  de inimigo (RF-AGE-003/004). Ver `003-domesticacao.md` (RF-AGE-017): uma
  segunda *variante de configuração* do mesmo tipo, sem IA distinta, existe
  apenas para validar a regra de domesticação restrita — isso não conta como
  uma segunda espécie/IA.

## Requisitos

### RF-AGE-003 — Spawn e avanço até o território

**Prioridade:** DEVE
**Status:** CONFIRMADO

O dinossauro selvagem inimigo não existe ativo no mapa antes da onda. Ele
surge (spawna) somente quando a onda começa e avança automaticamente em
direção ao território/base do jogador.

**Critérios de aceitação**

- Dado que a onda não começou, quando o jogador explora o mapa, então
  nenhum dinossauro selvagem inimigo de onda está presente.
- Dado que a onda começa, quando o spawn ocorre, então o dinossauro passa a
  se mover automaticamente em direção ao território.

**Origem:** IA simples pedida pelo grupo — spawn → caminhar até a base →
detectar → atacar → continuar. Comportamento fora da onda fica para ciclos
futuros.

### RF-AGE-004 — Detecção e ataque corpo a corpo

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-003

Enquanto avança até o território, o dinossauro selvagem detecta o jogador ou
um dinossauro domesticado dentro do alcance de detecção, para de avançar e
ataca corpo a corpo o alvo mais próximo. Ao derrotar o alvo ou perdê-lo de
alcance, retoma o avanço em direção ao território.

**Critérios de aceitação**

- Dado que o dinossauro selvagem está avançando, quando o jogador ou um
  dinossauro domesticado entra no alcance de detecção, então o inimigo para
  de avançar e ataca o alvo mais próximo.
- Dado que o inimigo está atacando um alvo, quando esse alvo é derrotado ou
  sai do alcance, então o inimigo volta a avançar em direção ao território.
- Dado que o inimigo está atacando, quando o cooldown ainda não terminou,
  então um novo ataque não pode ser acionado.

**Origem:** prioridade do inimigo é chegar ao território, mas reage a
ameaças no caminho. Velocidade deliberadamente abaixo dos 6 m/s do jogador
(RF-AGE-001) para não superar a mobilidade do personagem.

**Hipótese de protótipo — Vida (HP)**
- **Valor inicial:** 80 HP (cerca de 4 golpes do personagem, que causa 20 de dano — RF-AGE-002)
- **Pergunta do protótipo:** 80 HP dá um combate com ritmo, nem rápido nem arrastado demais?
- **Teto ou limite de exploração:** até 120 HP — acima disso o inimigo básico pode ficar resistente demais.

**Hipótese de protótipo — Dano por ataque**
- **Valor inicial:** 15 pontos
- **Pergunta do protótipo:** 15 de dano pressiona o jogador sem ser punitivo demais?
- **Teto ou limite de exploração:** até 25 pontos — acima disso pode ficar agressivo demais para o inimigo básico.

**Hipótese de protótipo — Cooldown**
- **Valor inicial:** 1 segundo
- **Pergunta do protótipo:** 1s de intervalo entre ataques mantém a pressão sem ser injusto?
- **Teto ou limite de exploração:** até 0,6 segundos no mínimo.

**Hipótese de protótipo — Alcance de detecção**
- **Valor inicial:** 8 metros
- **Pergunta do protótipo:** 8m dá tempo do jogador reagir antes do confronto?
- **Teto ou limite de exploração:** até 12 metros.

**Hipótese de protótipo — Velocidade de movimento**
- **Valor inicial:** 4 m/s
- **Pergunta do protótipo:** 4 m/s pressiona a defesa sem ultrapassar a mobilidade do jogador?
- **Teto ou limite de exploração:** até 5,5 m/s — deve permanecer sempre abaixo dos 6 m/s do personagem (RF-AGE-001).

## Alternativas descartadas

*Nenhuma registrada nesta spec.*

## Perguntas em aberto

*Nenhuma para esta spec no momento.*

## Não aplicável a este jogo

*Nenhuma.*
