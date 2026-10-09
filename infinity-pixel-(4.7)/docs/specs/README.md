# Índice de Specs

| ID | Arquivo | Sistema | Status |
|---|---|---|---|
| 001 | `001-controle-jogador.md` | Movimento e ataque básico do personagem | Ciclo 1 |
| 002 | `002-dinossauro-selvagem.md` | Comportamento e ataque do dinossauro selvagem (inimigo de onda) | Ciclo 1 |
| 003 | `003-domesticacao.md` | Condição e processo de domesticação | Ciclo 1 |
| 004 | `004-dinossauro-domesticado.md` | Comportamento do dinossauro domesticado, posicionamento e defesa | Ciclo 1 |
| 005 | `005-onda-e-vitoria.md` | Início de onda, spawn, condição de vitória e derrota | Ciclo 1 |
| 006 | `006-ciclo-dia-noite.md` | Estados DIA/NOITE, transição manual, vitória/derrota da sessão | Ciclo 1 |
| 007 | `007-camera-estrategica.md` | Câmera estratégica 3D, WASD relativo à câmera, mira do ataque pelo cursor | Ciclo 1 — aprovada (2026-10-03) |
| 008 | `008-continuidade-noite-dia-hud.md` | Noite → dia sem modal, HUD sem tutorial permanente, Controles na pausa | Ciclo 1 — aprovada (2026-10-03) |
| 009 | `009-contratos-fisicos-colisoes-obstaculos.md` | Camadas, máscaras e obstáculos sólidos | Ciclo 1 — aprovada manualmente (2026-10-03) |
| 010 | `010-navegacao-avoidance-criaturas.md` | Navmesh, NavigationAgent3D, avoidance, slots de aproximação/aliados, spawns separados | Ciclo 1 — aprovada (2026-10-04) |
| 011 | `011-vida-morte-respawn-jogador.md` | HP do jogador, invulnerabilidade, morte, respawn automático, HUD de vida | Ciclo 1 — aprovada (2026-10-04) |
| 012 | `012-primeiro-mapa-regioes.md` | Primeiro mapa: vale 48 × 52 m, base/BuildZone, transição, bifurcação, bosque, região rochosa, 3 rotas noturnas | Ciclo 1 — aprovada (2026-10-04); redesenho do menu principal pós-012 também aprovado |
| 013 | `013-relogio-ciclo-ataques-noturnos.md` | Relógio 08:00–18:00, ciclo automático dia/noite, aviso e contagem, noites progressivas pelas 3 rotas | Ciclo 1 — ciclo validado funcionalmente no playtest (tempos 90/45/20/10); balanceamento seguiu na 013B |
| 013B | `013b-economia-defesas-fixas.md` | Pontos de Defesa, 6 pontos fixos, Torre de Defesa L1–L3, volume do menu | Ciclo 1 — funcional, playtest realizado; aguardando polimento da 013C |
| 013C | `013c-combate-coleta-hud.md` | Golpe 15 (1 clique = 1 golpe), domesticado com vida cheia, 2 dinos diurnos, alcance das torres, Madeira/Pedra, HUD compacta | Ciclo 1 — aprovada manualmente (2026-10-04) |
| 013D | `013d-inventario-construcao-cura.md` | Inventário (I), construção com Madeira/Pedra (B: fantasma, validação, zonas), Fogueira de Cura, Armadilha de Espinhos | Ciclo 1 — aprovada manualmente (2026-10-06) |
| 014 | `014-ceu-iluminacao-progressiva.md` | Céu, Sol/Lua, estrelas, luz ambiente e fontes locais acompanhando o relógio (manhã → noite → amanhecer), transição contínua | Ciclo 1 — aprovada manualmente (2026-10-06) |
| 015 | `015-territorios-controlados.md` | Territórios (Refúgio, Floresta Oeste, Região Rochosa): guardião derrotado ou domesticado, marco com E, HUD 1/3, área de construção expandida | Ciclo 1 — implementada, aguardando playtest manual/aprovação |
| 017A | `017a-fundacao-visual-refugio.md` | Fundação visual "Vale de Jade": Refúgio, chão, trilhas, paredões, pontos de defesa, luz do meio-dia | Etapas 1–4 implementadas e testadas; aguardando playtest manual |
| 022 | `022-tutorial-jogavel.md` | Tutorial jogável integrado ao jogo real (13 etapas, instância isolada) | Implementada e testada; aguardando playtest manual |

## Padrão

Cada spec segue o formato descrito em `docs/context` — requisitos com
identificador (`RF-<AREA>-NNN` / `RNF-<AREA>-NNN`), prioridade, status e
critérios de aceitação no formato Dado/Quando/Então. Seções fixas: Fora do
escopo, Alternativas descartadas, Perguntas em aberto, Não aplicável a este
jogo.
