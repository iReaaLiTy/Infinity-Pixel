# 005 — Onda e Condição de Vitória/Derrota

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Múltiplas ondas — Ciclo 1 tem apenas uma onda.
- Pausa ou reposicionamento de dinossauros durante a onda — não permitido no Ciclo 1.
- Início automático de onda por tempo/evento — início é sempre manual no Ciclo 1.

## Requisitos

### RF-AGE-009 — Início manual da onda

**Prioridade:** DEVE
**Status:** CONFIRMADO

O jogador inicia a onda manualmente, quando estiver pronto, através de um
comando "Iniciar onda". Depois de iniciada, a onda não pode ser pausada
para reposicionar dinossauros domesticados.

**Critérios de aceitação**

- Dado que o jogador está na fase de preparação, quando aciona "Iniciar
  onda", então a onda começa.
- Dado que a onda está em andamento, quando o jogador tenta reposicionar um
  dinossauro domesticado, então isso não é permitido.

**Origem:** ritmo misto definido em `game-overview.md` — preparação sem
pressão de tempo, onda em tempo real sem pausas.

### RF-AGE-010 — Spawn escalonado dos inimigos

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-009, RF-AGE-003

A primeira onda do Ciclo 1 tem 3 dinossauros selvagens inimigos, que
aparecem com um intervalo de 2 segundos entre cada um (não simultâneos).

**Critérios de aceitação**

- Dado que a onda foi iniciada, quando o spawn ocorre, então 3 dinossauros
  selvagens aparecem ao todo, um a cada 2 segundos.

**Origem:** 3 inimigos escolhido pelo grupo como quantidade suficiente para
testar a defesa sem complicar o balanceamento do primeiro protótipo (1 seria
pouco, 5+ já complica). Intervalo de 2s facilita acompanhar o primeiro teste.

### RF-AGE-011 — Condição de vitória

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-010

A onda é vencida quando os 3 dinossauros selvagens da onda forem derrotados.

**Critérios de aceitação**

- Dado que a onda está em andamento, quando os 3 dinossauros selvagens são
  derrotados, então a onda termina em vitória.

**Origem:** objetivo do Ciclo 1 é testar se o ciclo preparação → defesa →
combate funciona.

### RF-AGE-012 — Base e condição de derrota

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-004, RF-AGE-010

A base/território tem pontos de vida próprios. Cada dinossauro selvagem que
chega até a base causa dano a ela. A onda é perdida quando a base chega a 0
HP. A morte do personagem do jogador não causa derrota — ele reaparece
(respawn) e a onda continua.

**Critérios de aceitação**

- Dado que um dinossauro selvagem chega até a base, quando ataca, então a
  base perde pontos de vida equivalentes ao dano do inimigo.
- Dado que a base chega a 0 HP, quando isso ocorre, então a onda termina em
  derrota.
- Dado que o personagem do jogador morre durante a onda, quando isso
  acontece, então ele reaparece (respawn) e a onda continua normalmente.

**Origem:** grupo confirmou proposta da Grill — manter o personagem sem
derrota permanente no Ciclo 1 para não travar o teste da onda; a base é o
que realmente está em jogo.

**Hipótese de protótipo — Vida da base**
- **Valor inicial:** 100 HP
- **Pergunta do protótipo:** 100 HP, com 3 inimigos causando 15 de dano cada caso cheguem até ela, dá tempo suficiente pro jogador e o dinossauro domesticado defenderem antes da base cair?
- **Teto ou limite de exploração:** a ajustar após o primeiro playtest — nenhum teto numérico definido ainda pelo grupo.

## Alternativas descartadas

*Nenhuma registrada nesta spec.*

## Perguntas em aberto

- Teto de exploração para a vida da base, além do valor inicial de 100 HP — não definido pelo grupo, ajustar após primeiro playtest.

## Não aplicável a este jogo

*Nenhuma.*
