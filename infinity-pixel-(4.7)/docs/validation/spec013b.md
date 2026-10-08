# Spec 013B — Registro de validação (2026-10-04)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

## Auditoria

- **"Inimigo definitivamente derrotado":** `WaveManager._neutralize_wave_enemy`.
  É chamado pelos sinais `died`, `domesticated` e `tree_exiting` de cada
  inimigo da onda. O inimigo sai de `_active_wave_enemies` uma única vez; as
  chamadas seguintes retornam cedo. A recompensa foi ligada nesse ponto,
  com o motivo "morreu".
- **Inputs em uso:** WASD (físico), clique esquerdo (`attack`), E
  (`domesticate`), F (`command_stay`), ESC (`ui_cancel`), T e N (depuração).
  **C estava livre.**
- **Áudio:** `audio_director` com `volume` e `muted`; o menu tinha um ícone
  que abria um popup com slider + "Mudo".

## Resultados automatizados (execução final)

| Suíte | Headless | Janela GL |
|---|---|---|
| `tests/defense_economy.tscn` (013B) | 35/35 | 35/35 |
| `tests/main_menu.tscn` | — | 27/27 |
| `tests/day_cycle.tscn` (013) | 43/43 | 43/43 |
| `tests/day_cycle_real.tscn` (013, tempos reais) | 15/15 | — |
| `tests/world_layout.tscn` (012) | 57/57 | 57/57 |
| `tests/player_health.tscn` (011) | 47/47 | 47/47 |
| `tests/player_facing.tscn` | 37/37 | 37/37 |
| `tests/physics_contracts.tscn` (009) | 23/23 | 23/23 |
| `tests/navigation_contracts.tscn` (010) | 38/38 | 38/38 |
| `tests/acceptance.tscn` | 33/33 | 36/36 |

Sem crash 139. Os JSONs estão em `spec013b-evidence/`.

### O que `defense_economy` verifica

- 6 pontos, 2 por rota, o mais próximo a 14,2 m do refúgio.
- **[A]** 30 pontos e HUD "30".
- **Painel perto do ponto:** "Custo: 30", botão habilitado.
- **[E][G]** A tecla C real constrói: ponto ocupado, 30 → 0, HUD "0".
- **[H]** Segunda torre no mesmo ponto recusada.
- **[F]** Sem pontos: botão desabilitado, "Pontos insuficientes"; C não
  constrói.
- **[P]** À noite: painel "Construa durante o dia"; construir e melhorar
  bloqueados mesmo com 100 pontos.
- **[I]** A torre L1 acerta um inimigo real da onda (80 → 70) e o mantém
  como alvo.
- **[B]** Morte do inimigo da onda: +15; HUD 15 e "+15" temporário.
- **[C]** Um `died` duplicado do mesmo inimigo, no mesmo quadro, não paga
  de novo.
- **[K]** O inimigo da onda domesticado não é alvo, não paga, e a morte
  posterior dele também não paga.
- **[J]** Sem inimigos, a torre não ataca o Player. Player, refúgio e
  aliado nunca são alvos válidos.
- **[D]** A torre ignora o selvagem fora da onda; o selvagem comum e o
  encontro mortos não pagam.
- **Fim da noite:** Dia 2 com 30 pontos (2 mortes pagas; o domesticado não
  pagou).
- **[O]** A torre e o nível persistem.
- **[L]** Pelo botão do painel: L1 → L2 por 30 (15 / 0,85 s / 9 m).
- **[M]** 44 pontos não bastam; L2 → L3 por 45 (20 / 0,70 s / 10 m).
- **[N]** L3 não melhora; painel "NÍVEL MÁXIMO".
- **[Q]** Reiniciar: 30 pontos, pontos vazios, Dia 1.
- **[R]** Slider 0 → mudo.
- **[S]** Slider 1% → som.
- **[T]** Com o slider em 60, o ícone muta (slider 0) e o segundo clique
  volta a 60.

## Ajustes durante o desenvolvimento

- **Parse error no `defense_slots.gd`:** a tipagem de `slot` vinha de um
  Array sem tipo. Corrigido.
- **Falhas iniciais do próprio teste**, investigadas antes de mexer:
  - [I]: os outros inimigos da onda já estavam perto da torre, que mirou o
    mais próximo (comportamento correto). O teste passou a afastá-los.
  - [C]: o teste chamava o neutralizador com um objeto já liberado, coisa
    que o motor nunca faz. Passou a simular um `died` duplicado real.
  - [K]: o inimigo já tinha levado 2 golpes legítimos da torre no caminho.
    O teste fixa o HP elegível antes de domesticar.
  - O diagnóstico isolado confirmou que a torre acertava (80 → 70).
- **`main_menu.gd`:** o trecho do popup antigo foi substituído por
  ícone + slider sempre visível, porque o pedido mudou essa UI. Total
  29 → 27 checagens.
- **Visual:** a torre ficou mais robusta (base e postes mais grossos,
  cristal maior) e o cristal do painel de pontos foi alinhado, depois da
  primeira captura.

## Verificação visual

`tests/defense_showcase.tscn` gravou 10 telas em `spec013b-evidence/views/`:

| Captura | Conferido |
|---|---|
| Menu | Ícone de som com o slider logo abaixo, no canto; estilo do menu mantido |
| Menu mudo | Ícone com X; slider em 0 |
| Ponto vazio | Plataforma de pedra com cristal; painel "TORRE DE DEFESA · Custo: 30 · CONSTRUIR (C)" acima do objetivo; HUD "30 PONTOS DE DEFESA" |
| Torre construída | Torre de pedra/madeira/cristal; HUD 0; painel L1 com "Pontos insuficientes" |
| Noite | Torre atacando inimigo da rota oeste; pontos vazios visíveis no escuro |
| +15 | "+15" dourado ao lado do contador |
| Dia 2 | "AMANHECEU · DIA 2", **45 pontos**, painel "MELHORAR — 30" |
| L2 / L3 | Anel dourado e cristal maior; L3 "NÍVEL MÁXIMO" |

O fluxo da captura confirmou a economia esperada: 30 → construir → 0 →
Noite 1 (3 × 15) → **45** no Dia 2 → melhorar por 30 → 15.

## Limites conhecidos

- Não foi possível validar por teste que a "Noite 2 fica mais administrável".
  Isso depende de jogo real (posicionamento, Player, aliados) e fica para o
  playtest.
- O ponto vazio não tem colisão. A torre tem um sólido de raio 0,8 m que não
  está na navmesh (assada offline); o desvio vem do avoidance. Os pontos
  ficam fora das trilhas para evitar bloqueios.
- O dardo é só visual. Se o alvo morrer antes da chegada, o golpe é
  descartado.
- O controle de volume da pausa (slider + "Mudo") não mudou. Mudo vindo da
  pausa aparece no menu como slider 0.

## TESTE MANUAL NECESSÁRIO

1. **Menu:** arrastar o slider até 0 (ícone mudo) e subir de novo; clicar
   no ícone (muta) e clicar de novo (volta ao volume anterior).
2. **Dia 1:** conferir 30 pontos; ir até um ponto, construir com C ou com o
   botão.
3. **Noite 1:** ver a torre atacando, o "+15" a cada morte e terminar com
   45 pontos.
4. **Dia 2:** decidir entre a segunda torre e a melhoria; tentar construir
   à noite ("Construa durante o dia").
5. **Noite 2:** avaliar se ficou administrável.
6. **Domesticação:** domesticar um inimigo da onda e confirmar que não paga;
   o encontro diurno também não paga.
7. **Reiniciar:** 30 pontos, sem torres, Dia 1.
