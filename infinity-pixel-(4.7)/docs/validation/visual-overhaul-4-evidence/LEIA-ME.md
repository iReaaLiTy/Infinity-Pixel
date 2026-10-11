# Evidências — Visual Overhaul 4.0

Capturas e medições reais do Godot 4.6.2 (GL Compatibility, Intel Iris Xe), em 11/10/2026.

- `comparacao/`: **esquerda = antes** (`52ff985`, faixa âmbar), **direita = depois** (faixa jade), no mesmo
  enquadramento. Geradas por `tools/overhaul4_capture.gd`, `tools/creature_turntable.gd` e
  `tools/compose_compare.gd`.
  - m01: menu (1280 e 1920).
  - i01/i02: mochila (Recursos, Construções, Companheiros com aliados).
  - c01–c04: Player, dinossauro de perto e fileira de tipos.
  - b01–b04: Floresta Oeste, Região Rochosa, Ruína e Refúgio (câmera do jogo e câmera ampla).
  - s01–s04: meio-dia e noite (câmera do jogo e vale inteiro).
  - k01/k02: onda de 10 com torres e aliados (HUD e combate de perto). É jogo rodando: as criaturas
    não ficam no mesmo lugar nas duas fotos.
  - tt_*: turntable dos modelos (lateral, três-quartos, câmera estratégica, topo, cabeça e passada).
- `desempenho/`: JSON de cada rodada do `tests/perf_probe.tscn --live --audit`.
  - `final_antes_r1..r4`: cópia de `52ff985`.
  - `final_depois_r1..r6`: versões em ajuste.
  - `final_depois_r7..r8`: código final.
  - `semaudio_r1..r2`: código em ajuste, com `--audio-driver Dummy`.

Tudo foi medido com o editor do Godot do usuário aberto, na tomada.
