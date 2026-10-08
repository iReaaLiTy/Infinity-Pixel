# ADR 0003 — Câmera estratégica `top_level` e mira separada do movimento

**Status:** proposto (aguardando aprovação da Spec 007)
**Contexto:** implementação de `007-camera-estrategica.md`, que substitui a
SpringArm3D em terceira pessoa da Spec 001.

## Decisão

1. A câmera é uma `Camera3D` (`StrategicCamera`, script
   `scenes/player/strategic_camera.gd`) filha do Player com
   `top_level = true`. Ela ignora o transform do pai e, a cada passo de
   física, aproxima exponencialmente seu ponto de foco da posição do Player
   e se posiciona por `distance`, `pitch_degrees` e `yaw_degrees`. A rotação
   do Player nunca chega à câmera.
2. Movimento e mira são separados. WASD vira direção no mundo pela
   frente/direita da câmera projetadas no plano XZ
   (`StrategicCamera.planar_direction`). A rotação Y do Player passa a seguir
   o ponto do chão sob o cursor (`screen_to_ground`).
3. O ataque continua sendo a `AttackArea3D` à frente do Player, consultada
   no golpe (ADR 0001, Spec 001). Como a área só atualiza os corpos
   sobrepostos no passo de física, quando a mira vira o Player no próprio
   clique o golpe é avaliado depois de um passo completo.
4. O ataque é lido em `_unhandled_input`. Controles de interface que
   consomem o clique (botões, painéis da HUD com `MOUSE_FILTER_STOP`)
   impedem o ataque.

## Alternativas consideradas

- SpringArm3D com valores maiores: herda a rotação do Player.
- Câmera na cena da arena com `NodePath` para o Player: exigiria mexer na
  cena da arena e nos testes que instanciam o Player.
- `intersect_shape` no golpe: resolveria a área desatualizada sem esperar o
  passo de física, mas trocaria o mecanismo de hit validado.

## Consequências

- Qualquer cena que instancie `player.tscn` ganha a câmera estratégica sem
  configuração extra.
- Cursor visível (`MOUSE_MODE_VISIBLE`) durante o jogo. Os painéis da HUD
  bloqueiam cliques no mundo atrás deles.
- Sem colisão de câmera: obstáculos altos entre a câmera e o jogador podem
  cobrir a visão (pergunta em aberto da Spec 007).
