# Cards prontos para o Trello

Quadro: **link não informado**. Publicação: **não realizada**. Antes de escrever no Trello, confirmar quadro exato e obter autorização explícita. Só o Game Designer envia o link acadêmico até 04/10/2026 às 23:59.

Equipe: Murilo Cassetti, Heitor Crispim, Pedro Ferreira, Juan Carlos. Não foram inventadas atribuições. Em cada card, substituir “a confirmar” pelo responsável real antes de publicar. Listas sugeridas: A fazer / Em andamento / Em validação / Concluído.

## AC1-01 — GDD da versão entregue

Responsável: **a confirmar** · Prazo proposto: 01/10 · Lista: Em validação.

Descrição: conferir história, regras, controles, direção visual e recorte com a versão 0.2 implementada. História, nome, marcas e monetização são propostas do grupo.

- [x] Atualizar GDD com os arquivos e comportamento da entrega.
- [x] Separar implementação, histórico e propostas.
- [ ] Grupo revisar e registrar aprovação.

Anexar: `docs/ac1/GDD_AC1.md`, `MATRIZ_ENTREGA.md`.

## AC1-02 — Core loop e resultados

Responsável: **a confirmar** · Prazo proposto: 02/10 · Lista: Em validação.

Descrição: menu, encontro diurno, combate, E, F, noite, vitória/derrota e reinício. Preservar HP ao domesticar e contagem de três spawns.

- [x] Integrar fluxo e tratar reinícios/pausa.
- [x] Executar 32 verificações automatizadas e demonstração da IA.
- [x] Preparar projeto e PCK.
- [ ] Playtest humano livre de vitória e derrota.
- [ ] Aprovar sensação de controle e equilíbrio.

Anexar: ZIP do projeto, `delivery/InfinityPixel.pck`, `delivery/Demonstracao_AC1.avi`, `docs/ac1/TESTES_AC1.md`, relatórios JSON.

## AC1-03 — Guardião, dinossauros e cenário

Responsável: **a confirmar** · Prazo proposto: 02/10 · Lista: Em validação.

Descrição: novas malhas simples, animações por pivôs e arte de menu; pranchas coerentes com o protótipo. Não apresentar key art como fidelidade final da modelagem.

- [x] Guardião frente/lado/costas com arma e materiais.
- [x] Dino selvagem/aliado, colar e crista; variante com chifres.
- [x] Modelos aplicados preservando scripts/colisões.
- [x] Cenário diurno e noturno com capturas reais.
- [ ] Aprovar direção artística e créditos de IA.

Anexar: `docs/ac1/assets/final/guardiao.png`, `dinossauros.png`, `cenario_dia_noite.png`, SVGs e screenshots.

## AC1-04 — Arena e progressão

Responsável: **a confirmar** · Prazo proposto: 01/10 · Lista: Em validação.

Descrição: arena 40×40, base (0,-15), jogador (0,0), encontro (-10,+5), posto (0,-7), onda (0,+15). Corredor de 10 m livre de obstáculos físicos.

- [x] Preservar planta e aplicar coordenadas.
- [x] Aplicar vegetação, rochas, marcos e limites.
- [x] Demonstrar IA chegando e atacando a base.
- [ ] Jogador testar bordas e câmera perto de árvores.

Anexar: `docs/ac1/assets/arena_planta.svg`, `evidence/arena_dia.png`, `evidence/arena_noite.png`.

## AC1-05 — Menu, HUD, pausa e resultados

Responsável: **a confirmar** · Prazo proposto: 02/10 · Lista: Em validação.

- [x] Jogar, Controles, Créditos, Sair.
- [x] HUD com dados reais; sem HP fictício do player.
- [x] Pausa, mouse, reset, volumes e resultados.
- [x] Inspecionar capturas 1280×720 e 1920×1080.
- [ ] Grupo testar teclado/mouse e legibilidade no dispositivo de apresentação.

Anexar: `evidence/01_menu_1280.png`, `02_menu_1920.png`, `03_dia.png`, `03_dia_1920.png`, `04_pausa.png`, `08_vitoria.png`, `09_derrota.png`.

## AC1-06 — Passos do Refúgio: trilha e sinais

Responsável: **a confirmar** · Prazo proposto: 02/10 · Lista: Em validação.

- [x] Tema de 112 s com desenvolvimento musical.
- [x] Versões calma/combate e sinais de vitória/derrota.
- [x] Integrar playback, transições, pausa, buses e mudo.
- [x] Analisar clipping e duração; gravar áudio da engine no vídeo.
- [ ] Ouvir tema inteiro, emenda, timbres e transições.
- [ ] Aprovar composição e equilíbrio de volumes.

Anexar: `assets/audio/refugio_principal.wav`, `refugio_calm.wav`, `refugio_combat.wav`, `victory.wav`, `defeat.wav`, `tools/compose_score.py`, `audio_metrics.json`.

## AC1-07 — Marca, identidade e monetização

Responsável: **a confirmar** · Prazo proposto: 01/10 · Lista: Em validação.

- [x] Prancha de identidade, marca aplicada no menu e ícone do jogo.
- [x] Manter Inity Pixel como estúdio e atualizar o nome exibido do jogo para Infinity Pixel, conforme pedido do usuário.
- [x] Registrar protótipo gratuito e proposta de compra única futura, sem loja real.
- [ ] Aprovar marcas, nome e proposta comercial.

Anexar: `docs/ac1/assets/final/identidade.png`, SVG, `assets/ui/inity_mark.svg`, `assets/ui/game_icon.svg`, GDD.

## AC1-08 — Conferência e envio acadêmico

Responsável: **Game Designer a identificar** · Prazo interno proposto: 04/10, 20:00 · Lista: A fazer.

- [ ] Preencher funções e responsável real em todos os cards.
- [ ] Confirmar aprovação humana dos testes, música e arte.
- [ ] Subir anexos em local acessível ao avaliador (caminhos locais não servem).
- [ ] Conferir os oito itens de `MATRIZ_ENTREGA.md`.
- [ ] Se exigir aplicativo independente, instalar templates Godot 4.7.2 e exportar/testar.
- [ ] Game Designer enviar link do quadro até 04/10/2026 às 23:59 e guardar comprovante.

O quadro não foi publicado e o envio acadêmico não foi realizado por esta execução.
