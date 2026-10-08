# ADR 0001 — Contrato de dano e esquema de camadas de colisão

**Status:** aceito
**Contexto:** Unidade 1 (Ciclo 1), implementação de `001-controle-jogador.md`

## Decisão

1. Qualquer entidade que possa receber dano implementa um método
   `take_damage(amount: float)` e pertence ao grupo `"damageable"`. Quem
   causa dano (jogador, e depois dinossauros) não precisa conhecer o tipo
   concreto do alvo — só chama `take_damage` se o método existir.

2. Esquema de camadas de colisão fixado desde já:
   - Layer 1 — mundo/geometria estática (chão, obstáculos)
   - Layer 2 — jogador
   - Layer 3 — criaturas (selvagens e domesticadas)
   - Layer 4 — reservada para base/território (Spec 005)

   **Complemento Spec 009 (2026-10-03):** a layer 4 agora é usada nos
   sólidos de base/construções; layer 5 reservada para interações e layer 6
   para projéteis. O contrato `damageable`/`take_damage` permanece igual.
   Detalhes de máscaras e Areas na Spec 009.

## Alternativas consideradas

- Checar o tipo da classe do alvo (`if body is WildDino`) em vez de um
  contrato por método/grupo. Descartado porque acopla o script do jogador a
  cada tipo novo de criatura, obrigando a editar `player.gd` toda vez que
  uma nova Spec adicionar uma entidade atacável.

## Consequências

- Specs 002 e 004 (dinossauro selvagem e domesticado) só precisam
  implementar `take_damage()` e entrar no grupo `"damageable"` para serem
  atacáveis — nenhuma mudança em `player.gd`.
- O esquema de camadas já reserva espaço para a base (Spec 005), evitando
  renumerar camadas depois.
- Mudar esse contrato mais tarde (por exemplo, para passar tipo de dano ou
  origem do ataque) exigiria tocar em todo nó que já implementa
  `take_damage()` — vale revisar essa assinatura antes de haver muitas
  entidades usando-a, não depois.

**Complemento Spec 011 (2026-10-04):** o Player passa a implementar o
contrato com HP real. A assinatura não mudou. Regras que ficam com quem
**recebe** o dano, não com quem ataca:
- dano inválido (`<= 0`, NaN, infinito) é ignorado;
- janelas de invulnerabilidade (entre hits e pós-respawn) descartam o dano;
- uma entidade morta ignora dano.

Futuros projéteis e armadilhas só precisam chamar `take_damage`.
