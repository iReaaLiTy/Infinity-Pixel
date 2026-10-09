# 022 — Tutorial jogável

**Status:** implementada e testada automaticamente (2026-10-09); **aguardando
playtest manual e aprovação**. Registro: `docs/validation/visual-hud-tutorial.md`.

## Objetivo

Ensinar o ciclo do jogo dentro do próprio jogo, sem sistemas duplicados: o
tutorial é a partida real (mesmo mapa, Player, IA, coleta, construção, torres,
onda) com um diretor que observa ações reais e mostra o próximo passo.

## Acesso

- Menu principal → **TUTORIAL** (ao lado de CONTROLES e CRÉDITOS).
- Pausa → **Reiniciar** repete o tutorial desde o passo 1; **Sair do tutorial**
  volta ao menu.
- Ao concluir: tela "Tutorial concluído!" com **Jogar partida** e **Menu**.

## Etapas (cada uma só avança com a ação real)

| # | Etapa | Conclui quando |
|---|---|---|
| 1 | Andar (WASD) | o jogador se afasta 2,5 m do ponto inicial |
| 2 | Ir até o sinal jade | chega a 1,8 m da coluna de luz na estrada |
| 3 | Atacar | um golpe NOVO (o recarregamento do ataque começa depois de entrar no passo) |
| 4 | Enfraquecer o selvagem | o guardião da Floresta Oeste fica domesticável (≤ 30% da vida) |
| 5 | Domesticar (segurar E) | o selvagem vira aliado |
| 6 | Coletar Madeira | 20 de Madeira no estoque (custo da Fogueira) |
| 7 | Coletar Pedra | 12 de Pedra |
| 8 | Abrir o inventário (I) | o painel do inventário fica visível |
| 9 | Construir a Fogueira | `BuildPlacer.structure_built` com a Fogueira |
| 10 | Preparar uma torre (C) | algum ponto de defesa recebe uma torre |
| 11 | Posicionar o aliado (F) | algum aliado entra em FICAR |
| 12 | Defender o Refúgio | a noite do tutorial é vencida (amanhecer) |
| 13 | Conclusão | tela final |

## Robustez

- Selvagem derrotado em vez de domesticado: surge outro selvagem perto do
  jogador e o passo continua (aviso no painel).
- Aliado morto antes do passo 11: volta a enfraquecer/domesticar um novo
  selvagem e, depois, retorna direto ao passo 11 (não repete a coleta).
- Jogador caído: respawn normal; o passo não muda.
- Derrota (Refúgio destruído): tela de derrota normal; Reiniciar repete o tutorial.

## Isolamento (só a instância do tutorial)

- `DayNightManager.clock_hold` segura **só o relógio** dos passos 1–11
  (criaturas, torres e combate continuam). `reset_session()` sempre zera a
  retenção: menu, JOGAR, Reiniciar e derrota nunca deixam o relógio parado.
- Primeira noite com **2** inimigos (`WaveManager.base_enemy_count` desta
  instância).
- Sem o guardião da Região Rochosa (onde ficam as pedras).
- Nenhum valor de dano, vida, custo, recompensa, velocidade ou regra muda.
  A partida normal não tem o diretor.

## Interface

- Painel "TUTORIAL · PASSO N DE 12" à esquerda: título, instrução curta, tecla,
  progresso (vida do alvo, Madeira x/20, Pedra x/12, invasores) e avisos.
- Objetivo da HUD = "TUTORIAL · <passo>".
- Coluna de luz jade + anel no chão no alvo do passo (ponto, selvagem,
  coletável mais próximo, área de construção, ponto de defesa, aliado).

## Arquivos

- `scenes/world/tutorial_director.gd` (novo), `tests/tutorial.gd/.tscn` (novo),
  `tools/tutorial_capture.gd/.tscn` (capturas).
- `scenes/ui/main.gd` (botão, `start_tutorial`, `restart`, conclusão),
  `scenes/ui/hud.gd` (`objective_override`),
  `scenes/world/day_night_manager.gd` (`clock_hold`).

## Testes

`tests/tutorial` (35 checks): partida normal sem diretor; relógio segurado;
2 inimigos; sem guardião rochoso; cada passo não avança sem a ação e avança com
ela; selvagem derrotado; aliado morto; jogador caído; noite vencida; sair solta
o relógio; partida normal depois do tutorial; Reiniciar pela pausa; sair pela
pausa.

## Fora do escopo

Narrativa, dublagem, setas na tela, tutorial de território (recuperar marco),
armadilha, melhoria de torre e cura na Fogueira (aparecem na partida normal).
