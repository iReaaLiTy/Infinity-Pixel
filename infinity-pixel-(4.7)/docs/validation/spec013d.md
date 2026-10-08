# Spec 013D — Registro de validação (2026-10-05)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

Este documento conserva o registro da implementação anterior e a revisão de
continuidade abaixo. Resultados históricos não substituem os testes da revisão.
**013C aprovada manualmente; 013D aprovada manualmente (playtest de
2026-10-06); Spec 014 é a próxima (não iniciada).**

## Auditoria da implementação anterior

- **Madeira e Pedra:** `ResourceStock` (nó do mundo, 013C), fonte única,
  com o sinal `resources_changed` que a HUD escuta. A 013D só acrescentou
  `can_afford_resources` / `spend_resources` (atômico).
- **Teclas:** em uso WASD, clique esquerdo, E, F, C, T/N (depuração) e ESC.
  **I, B, R, H e o botão direito estavam livres.**
- **BuildZone:** `WorldRegions/SafeZone/BuildZone` (7, −15), 8 × 10 m (Spec
  012).
- **Navmesh:** assada offline com o grupo `navigation_source`. Nenhuma
  estrutura entra nesse grupo nem faz rebake.

## Continuidade após a queda da conexão

A implementação estava completa no disco quando a conexão caiu. Na
retomada:
- **Mantido sem refazer:** tudo o que já estava salvo e passando.
- **Mudança de outra sessão, preservada:** durante a queda, outra sessão
  acrescentou ao `healing_campfire.gd` o cancelamento da cura ao **pausar**
  (`NOTIFICATION_PAUSED`) e o teste correspondente no `build_heal.gd` (66 →
  68 checagens). A mudança é correta (pausado, o `_physics_process` não
  roda, e a canalização continuaria ao despausar) e foi mantida.
- **Capturas antigas:** as capturas de uma execução anterior da ferramenta
  ficaram separadas em `spec013d-evidence/views/execucao-anterior/`.

## Revisão final de continuidade (2026-10-05, sessão única)

Duas sessões chegaram a trabalhar na 013D ao mesmo tempo; a segunda parou.
A auditoria final, com uma só sessão, encontrou:
- **Código da 013D íntegro:** inventário (I), construção (B/R, fantasma
  válido/inválido), receitas 20/12 e 15/6, só de dia, Pontos de Defesa só
  para torres. Nada parcialmente modificado.
- **Fogueira:** atacar cancela (`attack_count`), pausar cancela
  (`NOTIFICATION_PAUSED`), e iniciar domesticação ou posicionamento cancela
  uma cura **já em andamento** (`_channel_busy`, revisão das 18 h).
  `build_heal` continua com **68** checagens.
- **`tests/healing_actions.tscn` (7 checagens):** acrescentado na revisão das
  18 h para as ações incompatíveis e a remoção da Fogueira; faltava neste
  registro.
- **Teste instável corrigido (só no teste):** em ~1 de 5 execuções headless,
  `healing_actions` construía a Fogueira 5 quadros após `start_game()`, antes
  de a região do mapa novo entrar no mapa de navegação. O `validate()`
  recusava ("Terreno inválido"), `confirm()` devolvia `null` e o teste
  **travava** até o tempo-limite do runner (10 min). O fundo do menu já
  sincroniza o mesmo mapa, então `iteration_id > 0` não bastava (ainda falhou
  1/10). Agora o teste espera o ponto da Fogueira estar na navmesh e, se a
  construção for recusada, registra FAIL e encerra. Depois: **15/15**
  execuções seguidas. O jogo não muda: um jogador não constrói em 80 ms.
- **`project.godot`** salvo às 23:06 por um editor Godot aberto: conteúdo
  conferido, ações I/B/R/H intactas.

### Resultados finais (runner `tools/test_spec013d.ps1`, `--fixed-fps 60`)

| Suíte | Headless | Janela GL |
|---|---|---|
| `build_heal` (013D) | 68/68 | 68/68 |
| `healing_actions` (013D) | 7/7 | 7/7 |
| `combat_collect` (013C) | 46/46 | 46/46 |
| `defense_economy` (013B) | 35/35 | — |
| `day_cycle` (013) | 43/43 | — |
| `day_cycle_real` (013) | 15/15 | — |
| `world_layout` (012) | 57/57 | — |
| `player_health` (011) | 47/47 | — |
| `player_facing` | 37/37 | — |
| `physics_contracts` (009) | 23/23 | — |
| `navigation_contracts` (010) | 38/38 | — |
| `acceptance` | 33/33 | 36/36 |
| `main_menu` | — | 27/27 |

Sem `SCRIPT ERROR`. Os avisos de saída (certificados, ObjectDB) são os de
sempre. As suítes marcadas "—" com janela não foram tocadas pela revisão e
passaram com janela na revisão das 18 h. Logs e JSONs em
`spec013d-evidence/review-2026-10-05/`. Capturas refeitas em `views/`
(inclui a nova `00_inventario_vazio_insuficiente`).

## Resultados automatizados históricos (antes desta revisão)

| Suíte | Headless | Janela GL |
|---|---|---|
| `tests/build_heal.tscn` (013D) | 68/68 | 68/68 |
| `tests/combat_collect.tscn` (013C) | 46/46 | 46/46 |
| `tests/defense_economy.tscn` (013B) | 35/35 | 35/35 |
| `tests/main_menu.tscn` | — | 27/27 |
| `tests/day_cycle.tscn` (013) | 43/43 | 43/43 |
| `tests/day_cycle_real.tscn` (013) | 15/15 | — |
| `tests/world_layout.tscn` (012) | 57/57 | 57/57 |
| `tests/player_health.tscn` (011) | 47/47 | 47/47 |
| `tests/player_facing.tscn` | 37/37 | 37/37 |
| `tests/physics_contracts.tscn` (009) | 23/23 | 23/23 |
| `tests/navigation_contracts.tscn` (010) | 38/38 | 38/38 com `--fixed-fps 60` (ver abaixo) |
| `tests/acceptance.tscn` | 33/33 | 36/36 (cursor fora da janela) |

JSONs em `spec013d-evidence/`.

### O que `build_heal` verifica

- **Inventário [A–I]:**
  - I abre e fecha sem pausar (o relógio anda);
  - os números são os do `ResourceStock` e mudam no mesmo quadro;
  - gastar além do estoque falha e nunca fica negativo;
  - 20/12 com 20/6 falha sem retirar nada.
- **Construção [J–U]:**
  - B abre o menu e escolher a receita cria o fantasma;
  - o fantasma segue o ponto e fica válido na BuildZone;
  - fora da zona: "Fora da área permitida", também no painel;
  - recusa sobre árvore, outra estrutura, refúgio, ponto de defesa/torre,
    fora das rotas e em cima do Player;
  - clique direito e ESC cancelam sem gastar;
  - o clique de construir **não ataca**;
  - gasta exatamente a receita;
  - à noite: "Construa durante o dia".
- **Fogueira [V–AK]:**
  - custa 20/12 e o máximo é 1 ("LIMITE ATINGIDO");
  - a 4 m H não cura;
  - aos 2,7 s ainda não curou e aos 3 s cura +25 (50 → 75);
  - gasta 1 carga e inicia 25 s de recarga (bloqueia aos ~24 s, libera aos
    25 s);
  - sair do alcance, levar dano, morrer e pausar cancelam sem cura parcial;
  - 90 → 100, sem passar do máximo;
  - a 3ª cura no ciclo é recusada;
  - o amanhecer restaura 2 cargas;
  - com 100/100 não gasta carga; morto: "Indisponível";
  - o respawn não mudou.
- **Armadilha [AL–AV]:**
  - custa 15/6 e o máximo é 3;
  - começa com 3 cargas;
  - inimigo da onda: −15 e −1 carga;
  - parado em cima 1,2 s: um golpe só;
  - Player, aliado domesticado e selvagem diurno: sem dano;
  - dois inimigos no mesmo quadro: um golpe agora, o outro depois do
    intervalo;
  - na 3ª ativação ela some e o limite é liberado;
  - com cargas, continua no dia seguinte;
  - não tem corpo nem obstáculo de navegação;
  - um inimigo **real** da Ruína passa **por cima** da armadilha da estrada,
    leva 15 e chega ao refúgio.
- **Partida curta:**
  - coleta real de 4 árvores e 3 pedras → **40 Madeira / 18 Pedra**;
  - Fogueira + Armadilha → **5 / 0**;
  - Noite 1: ferido em 55, recua e cura +25 → 80;
  - um inimigo passa pela armadilha;
  - a torre continua atacando;
  - a noite é vencida e chega o Dia 2;
  - Reiniciar volta a 0/0, 40 pontos, sem estruturas, Dia 1.

## Problemas corrigidos na implementação anterior

- **Bug real (achado pelo teste):** ao reiniciar, a tabela de linhas de
  receita da HUD guardava as linhas da partida anterior, já liberadas, e a
  atualização tentava escrever nelas (SCRIPT ERROR repetido). Agora a tabela
  é recriada com a HUD.
- **Fantasma pouco visível** (na primeira captura): estruturas pequenas
  sumiam no gramado. O fantasma ganhou uma pegada no chão do tamanho real e
  ficou mais opaco.
- **Ajustes no teste (temporização e roteiro, não no jogo):**
  - teclas simuladas são entregues no **quadro de processo** seguinte; com
    janela e quadros perdidos, esperar só quadros de física não bastava;
  - esperas em **tempo de jogo** (passos de física), a base da recarga e da
    canalização;
  - os inimigos são congelados ao nascer, para não acionar as armadilhas
    antes da hora;
  - "dano cancela" passou a aceitar uma canalização **nova** do zero logo
    depois (H ainda segurado), desde que a anterior seja descartada e não
    haja cura parcial;
  - variável capturada em lambda virou array (GDScript copia as variáveis
    locais).
  - A primeira suspeita de perda de foco da janela foi testada e
    **descartada**; a opção temporária criada para ela foi removida.
- **`defense_economy` (013B) com janela:** a espera de parede pelos spawns
  falhou com quadros perdidos. A espera passou a ser em tempo de jogo.

## Execuções com janela nesta máquina (memória baixa)

- **Memória:** a máquina estava com ~1,2–1,5 GB livres de 11,4 GB. Um lote com
  janela foi interrompido pelo sistema por falta de memória; as suítes foram
  rodadas de novo uma por vez.
- **`acceptance`:**
  - com o cursor do sistema **sobre** a janela, a mira contínua (correta no
    jogo) girou o Player nos golpes manuais (29/36);
  - com o cursor fora, **36/36**;
  - uma execução teve **crash 139**, o intermitente já registrado na Spec
    012; a seguinte passou.
- **`navigation_contracts`:**
  - sem tempo fixo, falhou em pontos diferentes a cada execução;
  - com renderização e `--fixed-fps 60`, **38/38**;
  - a suíte já mede em quadros de física. Com FPS muito baixo, vários passos
    de física rodam por quadro desenhado e o avoidance responde uma vez por
    quadro, então as criaturas andam menos que o teste espera;
  - é uma limitação existente da Spec 010 em máquina sobrecarregada (na
    013C a suíte passou com janela sem tempo fixo); a 013D não tocou na IA
    nem na navegação.

## Verificação visual histórica

`tests/build_showcase.tscn` gravou 10 telas em `spec013d-evidence/views/`:

| Captura | Conferido |
|---|---|
| 00 Inventário vazio | MADEIRA 0 / PEDRA 0; as duas receitas com "Recursos insuficientes" e [CONSTRUIR] apagado |
| 01 Inventário | Painel à direita, abaixo dos recursos: MADEIRA 40 e PEDRA 18 com ícones; receitas com custo e [CONSTRUIR]; topo da HUD igual |
| 02 Menu construir | Lista compacta de receitas (B) |
| 03 Fantasma válido | Disco verde na BuildZone; painel "POSICIONANDO: FOGUEIRA DE CURA" com as teclas |
| 04 Fantasma inválido | Disco vermelho fora da zona; "Fora da área permitida" |
| 05 Fogueira | Anel de pedras, toras, chama e luz quente; "FOGUEIRA CONSTRUÍDA"; recursos 20/6 |
| 06 Curando | "CURANDO… 1,6 / 3,0 s" com barra; HP 55 |
| 07 Curado | "CURADO +25"; HP 80 |
| 08 Fantasma da armadilha | Disco verde sobre a estrada (rota) |
| 09 Armadilha | Estrado baixo com pontas e pedras; "ARMADILHA CONSTRUÍDA"; recursos **5 / 0** |
| 10 Noite | Inimigo da onda sobre a armadilha (−15) |

## Limites conhecidos

- **Valores sem playtest:** 2 cargas, 25 s de recarga e +25 de cura; 3
  cargas da armadilha.
- **Armadilha:** sem reparo; esgotada, some na hora.
- **Fogueira:** fica na BuildZone, com obstáculo só de avoidance (uma
  criatura pode raspar nela).
- **Construção:** só duas receitas; paredes e cercas ficam para a próxima
  expansão, porque mudam a navegação.
- **Com janela em máquina sobrecarregada:** veja a seção acima.

## Reproduzir

```powershell
.\tools\test_spec013d.ps1                 # todas as suítes, headless
.\tools\test_spec013d.ps1 -Rendered       # com janela (+ main_menu)
Godot_console --headless --path . --fixed-fps 60 res://tests/build_heal.tscn
Godot_console --path . res://tests/build_showcase.tscn -- --output=<pasta>
```

## Teste manual — APROVADO (2026-10-06)

O playtest manual seguiu o roteiro abaixo e foi **aprovado**: inventário,
coleta, construção, Fogueira de Cura (cura, cargas, recarga), Armadilha de
Espinhos, economia, amanhecer e integração com o restante do gameplay
funcionando corretamente. Nenhuma mudança de gameplay ou balanceamento
depois do playtest.

Roteiro executado:

1. **Inventário:** I abre e fecha com o mundo andando (inclusive à noite);
   ESC fecha antes de pausar.
2. **Coleta:** juntar ~40 Madeira e 18 Pedra.
3. **Fogueira:** B → FOGUEIRA → mover o cursor (verde na BuildZone,
   vermelho fora) → R gira → clique constrói. O ataque não sai.
4. **Armadilha:** sobre uma rota; tentar sobre torre, refúgio, árvore ou
   fora da rota.
5. **Noite:** apanhar, recuar, segurar H por 3 s (+25). Sair do alcance,
   apanhar, atacar, soltar H, morrer ou pausar cancela. Durante o dia,
   iniciar domesticação ou posicionamento também cancela. Usar 2 cargas;
   a 3ª é recusada; ver a recarga.
6. **Armadilha à noite:** ver o inimigo pisar, perder 15 e a armadilha
   perder carga até sumir.
7. **Amanhecer:** a fogueira volta a 2 cargas e a armadilha com cargas
   continua.
8. **Reiniciar:** 0/0, 40 pontos, nada construído.
