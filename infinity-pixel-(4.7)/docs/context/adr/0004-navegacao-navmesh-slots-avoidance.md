# ADR 0004 — Navegação: navmesh offline, slots por alvo e avoidance RVO

**Status:** proposto (aguardando aprovação da Spec 010)
**Contexto:** `010-navegacao-avoidance-criaturas.md`. A IA direta (ADR 0002)
ia em linha reta até o alvo: com os sólidos da Spec 009 ela parava atrás deles,
e várias criaturas seguiam a mesma trajetória e disputavam o mesmo ponto.

## Decisão

1. **Navmesh assada offline** (`tools/bake_navmesh.gd` → `arena_navmesh.tres`)
   a partir dos colisores estáticos da máscara 9, nos nós do grupo
   `navigation_source`. Segue o padrão do gerador de colisões da Spec 009: um
   arquivo inspecionável e regenerável, sem custo em runtime.
2. **NavigationAgent3D só decide a direção.** A máquina de estados do
   `wild_dino.gd` continua igual. Cada estado chama `_navigate_to()` /
   `_approach()` e o resultado passa por `_drive()`. Gravidade e
   `move_and_slide` continuam no CharacterBody3D.
3. **Slots por alvo, guardados no próprio alvo** (metadata). Ângulos fixos no
   mundo, reserva estável, liberação explícita e escolha com espalhamento. Não
   há estado global: os slots somem junto com o alvo e não vazam entre
   partidas.
4. **Avoidance RVO do Godot** para quem está andando. Quem está parado fica
   fora do avoidance (`_hold_still`), funcionando como obstáculo fixo para os
   demais. O Player é um `NavigationObstacle3D`.
5. Criaturas continuam sem colisão física entre si (Spec 009).

## Alternativas consideradas

- Colisão criatura × criatura: empurrões e travamentos; muda contrato físico.
- Offsets aleatórios: instáveis e proibidos pelo pedido.
- Steering/separação manual: reimplementa o que o RVO do servidor já faz.
- Autoload de slots: estado global que precisa ser limpo a cada partida.

## Consequências

- Mudou arte ou colisões: rodar `tools/bake_navmesh.gd` e os testes.
- `move_and_slide` das criaturas que andam roda no sinal `velocity_computed`,
  e a flag `_avoidance_pending` impede movimento em quadros sem pedido (pausa,
  fim de jogo, canalização).
- O anel do refúgio é limitado pela chegada de 1,5 m: até 6 atacantes
  simultâneos na base. Os demais esperam no anel externo.
