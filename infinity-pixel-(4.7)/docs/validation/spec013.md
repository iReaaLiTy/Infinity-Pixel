# Spec 013 — Registro de validação (2026-10-04)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

## Ponto de partida (auditoria)

- **Como a noite começava:** só pela tecla N (`DayNightManager._unhandled_input`
  → `start_night()` → `night_started`). Era citada nos Controles e nos
  objetivos da HUD ("N inicia a noite").
- **Como a onda começava:** `WaveManager` escuta `night_started`; 3
  inimigos, 2 s entre eles, rotas da Spec 012 pelo índice dos
  `spawn_offsets`.
- **Como a noite terminava:** com a onda neutralizada →
  `_finish_victory` adiado para o fim do quadro (derrota com prioridade) →
  `report_wave_victory()` → DIA + `day_started`.
- **Noites defendidas:** `main.victory_count`, incrementado na HUD
  (`_victory`). Não havia relógio nem número de dia; a HUD dizia "Sem
  cronômetro".
- **Dano noturno:** `wild_dino.gd` consulta `DayNightManager.is_night()`.

## Resultados automatizados (execução final)

| Suíte | Headless | Janela GL |
|---|---|---|
| `tests/day_cycle.tscn` (Spec 013) | 43/43 | 43/43 |
| `tests/world_layout.tscn` (Spec 012) | 57/57 | 57/57 |
| `tests/player_health.tscn` (Spec 011) | 47/47 | 47/47 |
| `tests/player_facing.tscn` | 37/37 | 37/37 |
| `tests/physics_contracts.tscn` (Spec 009) | 23/23 | 23/23 |
| `tests/navigation_contracts.tscn` (Spec 010) | 38/38 | 38/38 |
| `tests/acceptance.tscn` | 33/33 | 36/36 |
| `tests/main_menu.tscn` (menu pós-012) | — (exige janela) | 29/29 |

**Crash 139:** não ocorreu em nenhuma execução desta validação (8 suítes com
janela, 7 headless). Nenhuma suíte teve noite automática inesperada: as
noites registradas nos logs batem com as chamadas explícitas de
`start_night()` dos testes.

Relatórios JSON em `spec013-evidence/`. O `acceptance` grava o próprio
relatório na pasta de evidências que recebe.

### O que `day_cycle` verifica (itens do pedido)

- **[A]** JOGAR: Dia 1, DIA, 0 noites, 08:00 no instante do início. A HUD
  mostra "DIA 1 • PREPARAÇÃO", o relógio e as noites defendidas, sem "Sem
  cronômetro".
- **[B]** O horário avança na proporção configurada. A tecla N não inicia a
  noite fora do modo de depuração.
- **[C][D]** A pausa congela o horário; retomar continua.
- **[E]** O aviso dispara uma vez por dia (1 no Dia 1, 2 ao fim do Dia 2) e
  aparece na HUD.
- **[F]** A contagem fica oculta antes e mostra "ANOITECE EM 2" nos
  últimos segundos, sem modal nem pausa.
- **[G][H][I][J]** 18:00 → NOITE sozinha; onda automática com 3 inimigos,
  um em cada rota (Ruína, Oeste, Leste). A HUD mostra "NOITE 1 • DEFESA" e
  criados/neutralizados/ativos. O dano noturno é 19,5.
- **[T]** O relógio segura em 05:59 com inimigos ativos, e a noite não
  termina sozinha.
- **[U]** Domesticação seguida de morte do mesmo inimigo conta uma vez; sem
  contagem dupla depois do amanhecer.
- **[K][L][M]** Amanhecer: 1 noite defendida, Dia 2, 08:00, aviso
  "AMANHECEU · DIA 2", sem modal nem pausa.
- **[N][O]** Noite 2 automática com 4 inimigos: Ruína 2, Oeste 1, Leste 1.
  A fórmula dá 5 na Noite 3 e 6 na Noite 4.
- **[P]** Player morto na noite: relógio e onda continuam; respawn normal.
- **[Q]** A pausa congela relógio e spawns.
- **[R][S]** Noite 3 (5 inimigos): o último inimigo e o refúgio caem no
  mesmo quadro → "O refúgio caiu", noites defendidas continuam 2 e o
  relógio para. Reiniciar volta ao Dia 1, 08:00.

## Ajustes em testes existentes (e por quê)

- `acceptance.gd`: a checagem "último inimigo e refúgio no mesmo quadro"
  roda na **Noite 2**, que agora tem 4 inimigos. O teste fixava
  `_spawned_count = 3`, e com isso a onda nunca ficava completa: o teste
  passava sem exercitar a prioridade da derrota. Passou a usar
  `wave.enemy_count`, o que restaura o que ele verifica. Passava antes e
  continua passando.
- Durante o desenvolvimento, duas falhas do próprio `day_cycle` foram
  corrigidas no teste:
  - o horário inicial era lido depois de alguns quadros (com o dia de 6 s,
    cada quadro vale 1,7 min de jogo); passou a ser lido no instante do
    `start_game()`;
  - a HUD atualiza um quadro depois da mudança de estado; o teste espera
    esse quadro.

## Verificação visual

`tests/cycle_showcase.tscn` (dia de 20 s só na captura) gravou 7 telas em
`spec013-evidence/views/` pela câmera real:

| Captura | Conferido |
|---|---|
| Menu | Menu novo intacto |
| Dia 1 | "DIA 1 • PREPARAÇÃO" + "09:00" em destaque; "Noites defendidas: 0" |
| Aviso | "A NOITE SE APROXIMA" pequeno no topo; não cobre o Player |
| Contagem | "ANOITECE EM 3" em laranja dentro do painel; legível |
| Noite 1 | "NOITE 1 • DEFESA 20:36", "3/3 criados · 0 neutralizados · 3 ativos"; inimigos chegando; visual noturno |
| Amanhecer | "AMANHECEU · DIA 2", relógio 08:16, "Noites defendidas: 1"; sem modal |

## Limites conhecidos

- Os tempos atuais (dia 90 s, relógio noturno 45 s) vêm do primeiro
  playtest, que reduziu à metade os 180 s / 90 s iniciais. Ainda precisam ser
  confirmados no playtest de aprovação.
- A troca visual DIA/NOITE continua binária (1,5 s de transição). A
  progressão do céu com o horário fica para a Spec 014.
- A HUD atualiza o texto a cada quadro (padrão já existente para o painel de
  fase). O texto pode ficar um quadro atrás da mudança de estado.
- Sem save: fechar o jogo recomeça no Dia 1.

## Reproduzir

```powershell
Godot_console --headless --path . --fixed-fps 60 res://tests/day_cycle.tscn
Godot_console --path . res://tests/cycle_showcase.tscn -- --output=<pasta>
```

## TESTE MANUAL NECESSÁRIO

1. JOGAR → Dia 1, 08:00, relógio andando.
2. Pausar (ESC) por alguns segundos → horário parado; retomar.
3. Perto das 17:00, notar "A NOITE SE APROXIMA" e depois "ANOITECE EM 10…1".
4. Às 18:00 a noite começa sozinha; 3 inimigos chegam por 3 direções.
5. Vencer a onda → "AMANHECEU · DIA 2", 08:00, Noites defendidas 1, sem
   modal, sem teleporte e sem cura.
6. Na Noite 2, conferir 4 inimigos distribuídos.
7. Morrer durante a noite → o relógio continua e o respawn é normal.
8. Deixar o relógio passar das 05:59 com inimigos vivos → a noite continua.
9. Deixar o refúgio cair → "O refúgio caiu"; Reiniciar volta ao Dia 1.
10. Conferir que a tecla N não faz nada.

## Ajuste de balanceamento após o primeiro playtest (2026-10-04)

O usuário achou o dia e a noite longos demais. Só os valores padrão do
`DayNightManager` mudaram; arquitetura, fórmula de onda, rotas, HUD e
contratos continuam iguais.

| Valor | Antes | Depois |
|---|---|---|
| `day_duration_seconds` (08:00 → 18:00) | 180 s | **90 s** |
| `night_duration_seconds` (18:00 → 05:59, só o relógio) | 90 s | **45 s** |
| `night_warning_seconds` | 30 s | **20 s** (≈ 15:46) |
| `night_countdown_seconds` | 10 s | 10 s |

A noite continua sem limite de tempo: o relógio segura em 05:59 até a onda
ser vencida.

**Suíte nova `tests/day_cycle_real.tscn`:** roda os tempos **reais**, sem
acelerar, em ~150 s de jogo, simulados em poucos segundos com headless e
`--fixed-fps 60`. Resultado: **15/15**.
- **Valores padrão:** 90/45/20/10.
- **Relógio:** 08:00 no início; 30 s → 11:20; a pausa congela.
- **Aviso:** dispara aos 70,02 s (faltando 20 s), às 15:46.
- **Contagem:** oculta antes, depois "ANOITECE EM 10" … "ANOITECE EM 1".
- **Noite:** automática aos 90 s (18:00, 3 inimigos); 22,5 s → 00:00.
- **Fim do relógio:** 45 s → 05:59 com inimigos vivos; 55 s → ainda 05:59,
  0 noites.
- **Onda vencida:** amanhecer, Dia 2, 08:00.

**Regressões após o ajuste:**
- headless: day_cycle 43/43, acceptance 33/33, player_health 47/47,
  world_layout 57/57, navigation 38/38, física 23/23, facing 37/37;
- com janela: day_cycle 43/43, acceptance 36/36.

Nenhuma suíte teve noite automática inesperada com o dia mais curto: as
noites nos logs batem com as chamadas explícitas dos testes. Sem crash 139.
