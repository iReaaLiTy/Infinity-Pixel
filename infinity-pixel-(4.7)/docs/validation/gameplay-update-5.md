# Gameplay Update 5.0 — retomada do trabalho do Astra

Data: 13/10/2026 · Godot 4.6.2 · projeto `infinity-pixel-(4.7)` · branch `main`.
Status: **implementado e testado automaticamente; aguardando playtest/aprovação manual.**

Escopo (playtest externo): (1) mais armadilhas, (2) torres mais espaçadas,
(3) Elixir de Jade para curar aliados, (4) cursor oculto no gameplay e golpe na
direção do personagem (não do mouse).

## 1. Estado encontrado (auditoria, Fase A)

- `git status` limpo; HEAD `0c52ffd "ssss"` = `origin/main` (0 à frente/0 atrás).
  O snapshot do início da sessão mostrava arquivos modificados/não rastreados;
  eles já tinham sido commitados pelo usuário nesse commit e publicados. Por isso
  o próprio `0c52ffd` serve de checkpoint recuperável do trabalho do Astra (não
  foi criado outro). Nenhum stash. Nenhum relatório escrito pelo Astra (só logs).
- Arquivos do Astra em `0c52ffd`: `scenes/player/player.gd`, `scenes/ui/main.gd`,
  `scenes/ui/hud.gd`, `scenes/enemies/wild_dino.gd`, `scenes/world/build_recipes.gd`,
  `scenes/world/spike_trap.gd`, `scenes/world/tutorial_director.gd`, novos
  `scenes/world/jade_elixir.gd`, `tests/gameplay5.*`, `tests/tower_layout5.*`,
  `tools/test_gameplay5.ps1` e logs em `docs/validation/gameplay-5-evidence/`.
- Regressão do estado herdado (`audit-full-headless/`): **20/27 suítes**, 33 checks
  falhando; `gameplay5` do Astra: 35/39.

| Item | Estado herdado |
|---|---|
| Ataque frontal | Parcial: mouse removido e alvo frontal único, mas a raiz do Player passou a girar com a orientação **suavizada** (golpe atrasado em relação ao WASD e sobrescrevendo `rotation.y` a cada quadro); 5 suítes antigas quebradas. |
| Cursor | Parcial: política `sync_cursor()` existia; 4 checks falhavam (o modo sem janela ignora `MOUSE_MODE_HIDDEN`); painéis da HUD continuavam capturando cliques com o cursor invisível (golpe "engolido" ou CONSTRUIR apertado às cegas); movimento bloqueado com a mochila aberta (regra nova não pedida). |
| Armadilhas | Quase completo: limite 5, texto da HUD, escala visual 1,25, faísca ao ativar. Testes antigos ainda esperavam 3. |
| Torres | **Não iniciado no jogo**: 3 candidatos testados só por coordenadas fixas no teste, todos reprovados; a cena não foi alterada. |
| Elixir | Completo nas regras (custo, Dia 2, 2 amanheceres, 1 guardado, cura válida), inventário e tecla G; dica G posicionada fora da tela e com nome interno do nó. |
| Tutorial | Textos de MOVE/ATTACK/NIGHT e dica de golpe no vazio atualizados. |

## 2. O que foi aproveitado e o que foi corrigido

Aproveitado do Astra: seleção de alvo por cone frontal com alinhamento > distância
e desempate determinístico; `ui_blocked`; `sync_cursor()`; limite 5; Elixir inteiro
(`jade_elixir.gd`, `heal_ally()`, cartão na mochila, botão por aliado, G, aviso no
Dia 2); textos do tutorial; `gameplay5.gd` e o script de regressão.

Corrigido/concluído nesta sessão:

1. **Ataque** (`player.gd`): `rotation.y` (direção lógica do golpe, com a
   AttackArea3D) é definida **na hora** pelo WASD e fica parada quando o jogador
   para; o modelo (`Visual`) gira suave atrás dela (giro rápido após um golpe).
   Corpos largos (rocha) contam pela borda no cone de 55°. Novo `face_toward()`
   para tutorial/ferramentas. Removidos restos da mira por cursor.
2. **Cursor** (`main.gd`, `hud.gd`): `cursor_hidden` guarda a decisão da política
   (testável sem janela); todas as transições passam por `sync_cursor()`. Com o
   cursor oculto os painéis da HUD deixam o clique passar (`set_pointer_capture`).
   Andar com a mochila aberta voltou a ser permitido (como antes); só o ataque é
   bloqueado enquanto há interface clicável.
3. **Armadilhas** (`spike_trap.gd`): estacas mais altas/grossas e 3 pedras de carga
   âmbar (acesas = armada; apagam a cada ativação). Volume de ativação, navegação,
   dano, custo e cargas inalterados.
4. **Torres**: novas posições na cena e no gerador do vale; arte regenerada.
5. **Elixir** (`hud.gd`, `jade_elixir.gd`): dica G ancorada corretamente e legível
   (contorno), texto sem nome interno; "+N HP" flutuante maior e com contorno.
6. **Tutorial**: passo WEAKEN pede para encarar o dinossauro com WASD.

## 3. Funcionamento final

**Ataque direcional.** WASD define a direção (relativa à câmera); parado, mantém a
última. Clique esquerdo golpeia à frente: consulta física só no clique (sem varrer a
cena por quadro), caixa e alcance originais (2 m), cone de 55°, um alvo por golpe
(o mais alinhado; depois o mais perto). A posição do cursor é ignorada. Objetos
atrás nunca são atingidos. Aliados e o Refúgio nunca são alvo. Dano 15, cooldowns
0,6/0,3 s e buffer de clique inalterados.

**Cursor.** Oculto: exploração, combate, coleta, tutorial e durante o
posicionamento de obra (a pegada colorida da prévia, verde/vermelha, é o marcador).
Visível: menu, pausa, controles, configurações, créditos, derrota, fim do tutorial,
mochila e menu de construção. Perder o foco pausa e mostra o cursor; retomar oculta.
R gira, clique confirma, botão direito/B/ESC cancelam, validação e aviso de
recursos inalterados.

**Armadilhas.** Limite **5** (era 3). 15 madeiras + 6 pedras, 15 de dano, 3 ativações,
só inimigos da onda, mesmas regras de posicionamento.

**Torres** — seis slots, mesma rota informativa; dano/custo/alcance/cadência/
melhorias inalterados.

| Slot | Antes (x, z) | Agora (x, z) |
|---|---|---|
| SlotWestInner | (-10.5, -5.5) | (-12, -11) |
| SlotWestOuter | (-18, -1.5) | (-19, 6) |
| SlotRuinMeadow | (-3.8, -1) | (-3.5, 1) |
| SlotRuinArch | (3.6, 12.5) | (4.5, 13) |
| SlotEastInner | (10.5, -5.5) | (12.5, -8) |
| SlotEastOuter | (18, -1.5) | (19, 6) |

Separação mínima **8,07 m → 14,42 m**. Caminho real da navmesh sob alcance L1:
Oeste 19,3 m (antes 20,4), Ruína 25,4 m (27,3), Leste 19,9 m (20,3) — 93–98% do
anterior. Nenhuma torre a menos de 3,37 m do caminho; plataformas sem colisão,
sobre a navmesh, com 4 acessos; fora das trilhas, do Refúgio, da área de construção,
das entradas, marcos e coletáveis. Posições escolhidas por varredura da grade do
mapa real (sonda temporária, removida). Fonte única: `scenes/world/prototype_area.tscn`
e `tools/build_valley_art.gd` (`SLOTS`, que limpa relevo/detalhes); `valley_art.tscn`
e `flora_art.scn` regenerados pelos geradores oficiais.

**Elixir de Jade.** Custo 40 madeiras + 24 pedras; cura até 40 HP; 1 guardado.
Primeira fabricação no Dia 2; após fabricar, espera 2 amanheceres (Dia 2 → Dia 4),
contados pelo DayNightManager. Sem duplicação (reserva antes dos sinais; abrir/fechar
a mochila não fabrica). Cura só aliado domesticado vivo e ferido a até 3 m (G = mais
próximo, desempate por id); não consome com vida cheia, sem alvo, alvo distante,
inimigo, Player ou aliado morto; respeita o máximo. Mochila → Companheiros: ícone,
nome, descrição, custo, recursos, guardado, motivo (dias restantes/recursos/limite),
FABRICAR e "USAR ELIXIR · até 3 m" por aliado. Efeitos: faísca e anel jade, "+N HP"
real, barra atualizada. G estava livre (sem conflito).

**Tutorial.** 13 etapas intactas (40/40 no `tutorial`). MOVE: WASD anda e orienta;
ATTACK: golpe segue a direção do herói, cursor não controla; WEAKEN: encare com WASD;
NIGHT: armadilhas defendem as rotas. Elixir não é obrigatório: aviso contextual no
amanhecer do Dia 2.

## 4. Contratos de teste alterados intencionalmente

| Suíte | Antes | Agora |
|---|---|---|
| attack_direction | clique sobre o alvo orienta o golpe | reescrita: 8 direções, árvores de 3 lados, rocha diagonal/lateral, fora de alcance, vizinho lateral, 2 alvos no cone, alvo atrás, aliado/Refúgio, cooldown, cursor em 4 lados — sempre com cursor atrás |
| player_facing | "mira lógica intacta" / "golpe no lado do cursor" | "direção do golpe segue o WASD" / "golpe no lado do movimento, não do cursor" |
| combat_collect | clique sobre o alvo | o jogador encara o alvo antes do clique; todos os valores iguais |
| player_health | — | espera a soltura do D antes de encarar o alvo |
| physics_contracts | clique em painel da HUD não ataca | cursor oculto: atravessa e ataca; mochila aberta: não ataca |
| build_heal [AM], territory [36] | máximo 3 | máximo 5 (constrói 4ª e 5ª, recusa a 6ª) |
| build_heal [P] | slot Oeste Interno | slot Prado da Ruína (o Oeste saiu da beira da trilha) |
| acceptance | 3 conexões de `day_started` | 4 (+ JadeElixir); continua sem acúmulo |
| visual_invariants_baseline | slots antigos | só as 6 entradas dos slots |

## 5. Testes

- Sem janela (`final-headless/`): **29/29 suítes, 922 checks, 0 falhas**.
- Com janela (`final-window/`, inclui `main_menu` e confere `Input.mouse_mode` real):
  **30/30 suítes, 952 checks, 0 falhas**.
- `gameplay5` (46 checks): cursor em todas as telas, ataque com cursor atrás
  (árvore, pedra, dino, atrás, dois alvos, diagonal, parado, após andar com WASD,
  noite, tutorial), construção (menu/posicionamento/confirmar sem atacar), 5
  armadilhas, 6ª recusada, pedras de carga, Elixir completo, reinício.
- `tower_layout5` (44 checks): layout real da cena, separação, colisão, navmesh,
  acessos, trilhas, cobertura x layout antigo, torres L1→L3 nos 6 slots, rotas.

## 6. Capturas reais (`gameplay-5-evidence/captures/`, 1920×1080)

01 golpe frontal na árvore · 02 golpe frontal no dinossauro · 03 cinco armadilhas
(uma com 2/3 cargas) · 04/05 seis torres no novo layout (dia/noite) · 06/07 mochila
com o Elixir (disponível / guardado 1/1) · 08 dica G com aliado ferido · 09 cura
(+38 HP, 42→80) · 10 prévia de construção · 11 tutorial, passo do ataque.
O cursor do sistema não aparece em capturas de viewport; o estado dele é provado
pelos testes com janela.

## 7. Desempenho (`performance-after.json`)

Intel Iris Xe, gl_compatibility, vsync desligado, janela 1920×1080, 8 s por cenário.

| Cenário | FPS médio | 1% pior |
|---|---|---|
| padrão (3 distâncias) | 110–118 | 67–72 |
| vivo, noite, 10 inimigos, 3 torres, 3 aliados | 79,0 | 19,5 |
| **vivo, 6 torres + 5 armadilhas + 3 aliados + onda de 10 + Elixir** | **90,5** | **26,7** |
| vivo, tutorial | 109,6 | 68,2 |

Média acima de 60 em todos os cenários. O 1% pior fica abaixo de 60 nos cenários
noturnos com onda, inclusive nos pré-existentes — **a meta de 60 FPS estáveis não
está comprovada** nesses cenários. A medição do Astra (`performance-before.json`)
foi em 1280×720 e terminou com crash na saída, então não é comparável diretamente.

## 8. Pendências / limitações

- Aprovação manual (playtest) pendente; nada marcado como aprovado em Specs.
- 1% pior < 60 FPS nas noites com onda (anterior a esta atualização).
- Cursor oculto não é comprovável por captura de tela, só pelos testes com janela.

## 9. Roteiro de playtest manual

1. JOGAR: o cursor some. Ande com WASD e pare de frente para uma árvore com o mouse
   atrás do herói; clique — a árvore leva o golpe e o herói não vira.
2. Encare um dinossauro em diagonal e golpeie; tente golpear algo atrás — nada.
3. I abre a mochila (cursor aparece, clique não ataca); I/ESC fecha (cursor some).
   ESC pausa → Configurações → Voltar → Retomar. Alt+Tab pausa com cursor visível.
4. B → Armadilha: posicione pela pegada verde/vermelha, R gira, clique confirma,
   botão direito cancela. Construa 5 na estrada; a 6ª aparece como LIMITE ATINGIDO.
5. Veja os 6 pontos de defesa mais espalhados; erga torres (C) e defenda a noite.
6. No Dia 2: aviso do Elixir. Mochila → Companheiros → FABRICAR (40/24). Com um
   aliado ferido a até 3 m, aperte G: "+N HP" e barra cheia sem passar de 80.
   No Dia 3 está em recarga; no Dia 4 libera de novo.
7. Tutorial: siga as 13 etapas; o passo do ataque explica WASD/golpe à frente.
8. Perca a partida: a tela de derrota mostra o cursor; Reiniciar zera Elixir e
   armadilhas.
