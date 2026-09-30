# ADR 0002 — Detecção de alvos por grupos e distância

**Status:** aceito
**Contexto:** Unidade 2 (Ciclo 1), implementação de `002-dinossauro-selvagem.md`

## Decisão

1. Papéis de entidade são expressos por grupos do Godot: `player`,
   `domesticated`, `wild_dino`, `territory`, além de `damageable` (ADR 0001).
2. O dinossauro selvagem detecta alvos percorrendo os grupos `player` e
   `domesticated` e medindo a distância no plano XZ contra o alcance de
   detecção (RF-AGE-004). Não usa `Area3D`.
3. Corpos de jogador (layer 2) e criaturas (layer 3) se bloqueiam
   mutuamente: máscara do jogador = 1+3, do inimigo = 1+2.

## Alternativas consideradas

- `Area3D` esférica de detecção com lista de overlap. Descartada por
  enquanto: a Unidade 1 mostrou que depender de sinais de entrada/saída é
  frágil, e para poucos alvos a checagem por distância é mais simples.

## Consequências

- A Spec 004 só precisa colocar o aliado no grupo `domesticated` para ser
  alvo dos inimigos, sem mexer em `wild_dino.gd`.
- Não há linha de visão nem custo escalável: se houver muitos alvos ou
  obstáculos que bloqueiem a detecção, revisar (por exemplo, `Area3D` +
  raycast).
