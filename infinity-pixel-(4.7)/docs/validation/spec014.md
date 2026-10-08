# Spec 014 — Registro de validação (2026-10-06)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows
(Intel Iris Xe).

**013C aprovada manualmente; 013D aprovada manualmente; 014 aprovada
manualmente (playtest de 2026-10-06).** Spec 015: próxima, não iniciada.

## Auditoria (antes de mudar)

- **Tempo:** `DayNightManager` é a única fonte (`state`, `phase_elapsed`,
  `clock_minutes()`). O visual antigo (`DayNightVisual`) só trocava entre 2
  estados com um tween de 1,5 s nos sinais.
- **Ambiente:** fundo de cor (sem Sky), ambiente branco 0,35, Filmic, sem
  neblina/glow; 1 `DirectionalLight3D` fixa com sombra.
- **Fontes locais:** 2 tochas (OmniLight sem sombra) e o núcleo emissivo
  do refúgio (material compartilhado com o fundo do menu), cristal emissivo
  das torres, OmniLight da Fogueira.
- **Câmera:** pitch 50°, FOV 50°. **Medição:** fundo trocado por magenta e
  6 capturas (spawn, borda norte, cantos NO/NE, sul, oeste) = **0% de céu
  visível**. Decisão do usuário: céu real + sinais no chão.
- **Nenhum teste antigo** dependia do visual antigo.

## Resultados automatizados (runner `tools/test_spec014.ps1`, `--fixed-fps 60`)

| Suíte | Headless | Janela GL |
|---|---|---|
| `sky_cycle` (014) | 45/45 | 45/45 |
| `build_heal` (013D) | 68/68 | 68/68 |
| `healing_actions` (013D) | 7/7 | 7/7 |
| `combat_collect` (013C) | 46/46 | 46/46 |
| `defense_economy` (013B) | 35/35 | 35/35 |
| `day_cycle` (013) | 43/43 | 43/43 |
| `day_cycle_real` (013) | 15/15 | — |
| `world_layout` (012) | 57/57 | 57/57 |
| `player_health` (011) | 47/47 | 47/47 |
| `player_facing` | 37/37 | 37/37 |
| `physics_contracts` (009) | 23/23 | 23/23 |
| `navigation_contracts` (010) | 38/38 | 38/38 |
| `acceptance` | 33/33 | 36/36 |
| `main_menu` | — | 27/27 |

Sem `SCRIPT ERROR` nem `SHADER ERROR` nas execuções finais. Logs e JSONs em
`spec014-evidence/`.

### O que `sky_cycle` verifica (45)

- **Tempos:** 90 / 45 / 20 / 10 s intactos.
- **[A]** controlador existe, controla luz, Environment e céu; Environment
  duplicado por mundo.
- **[B]** começa em 08:00 com o visual na mesma hora; com o jogo andando
  segue `clock_hours()`; mudar o `DayNightManager` muda o visual.
- **[C]** relógio parado = Sol, luz e hora visual parados; sem relógio do
  sistema nem `Timer`.
- **[D]** Sol 12:00 > 08:00 > 17:30 em altura; leste de manhã, oeste à
  tarde; 08:00 a 30° (manhã, não meio-dia).
- **[E]** energia 12:00 0,64 > 18:00 0,50 > 00:00 0,32; meio-dia sem
  estourar.
- **[F]** pôr do sol mais quente; Lua fria. **[G]** ambiente claro de dia,
  azul mais escuro à noite, nunca preto.
- **[H]** estrelas (céu e chão) invisíveis 08:00–17:30; surgem aos poucos
  (18:00 0,00 → 18:48 0,19). **[I]** à noite todas (120 pontos no chão, 1
  MultiMesh); somem aos poucos (05:30 0,16).
- **[J]** 00:00: Lua alta e é a luz direcional; ela se move. **[K]** dia: Lua
  apagada, luz = Sol.
- **Fontes locais:** refúgio com luz noturna (apagada de dia, sem sombra);
  Fogueira mais forte à noite; cristal da torre mais brilhante; armadilha
  com brilho leve e sem luz.
- **[P]** Fogueira: +25, 3 s, 2,5 m, 2 cargas, 25 s; luz maior **não**
  amplia a cura (Player a 4 m fora); cura real à noite 50 → 75.
- **[Q]** torre: mesmos `stats()` de dia e de noite. **[R]** inimigos: HP
  80, dano 15, velocidade 4, buff noturno 1,30/1,20. **[S]** coleta: árvore
  dá +10.
- **[M]** pausa (`pause_game()` real): relógio, Sol/Lua, céu e cintilar
  parados; ao despausar continua.
- **[O]** em 05:59 o visual fica no amanhecer; ao vencer a onda o relógio
  vai a 08:00 e o visual não salta (6,00 h); maior variação por quadro
  **0,008**; em ~4 s alcança o relógio sem estrelas, Lua ou brilho preso.
- **[N]** derrota congela relógio e ambiente.
- **[L]** reiniciar a partir de 00:00: Dia 1 08:00, Environment novo, sem
  Lua/estrelas/brilho, luz e ambiente da manhã; **sem acumular conexões**
  nos sinais do `DayNightManager`.

## Problemas encontrados e corrigidos

- **Regressão real (pega pelo `acceptance`, "Reinícios não acumulam
  conexões de dia"):** a primeira versão ligava *lambdas* aos sinais do
  `DayNightManager`; lambdas não são desligadas quando o mundo é liberado,
  então cada Reiniciar somava uma conexão. Voltou a usar métodos (como o
  visual antigo) e o `sky_cycle` ganhou a mesma verificação.
- **Meio-dia lavado** na 1ª captura: com o Sol a 60° o chão recebe ~70% mais
  luz direta que às 08:00. A energia agora **cai** ao meio-dia (0,64) e a
  exposição fica em 0,97.
- **Fim de tarde, anoitecer e amanhecer saturados demais** (vermelho/marrom):
  a neblina quente e o ambiente rosado dominavam. Neblina reduzida (0,0025
  dia / 0,004 noite) e cores do anoitecer/amanhecer mais neutras
  (lilás-azulado).
- **Estrelas do chão cedo demais e com cara de neve:** aparecem a partir de
  ~18:40, são menos (120), menores e cintilam de forma mais espaçada.

## Execuções com janela nesta máquina

- Um lote com janela (00:55) teve falhas de **entrada/tempo** em
  `build_heal` (8), `healing_actions` (1) e `combat_collect` (cliques sem
  efeito; depois um `SCRIPT ERROR` do próprio teste ao usar uma torre nula, e
  ele ficou parado até ser encerrado).
- **Não se repetiram:** as mesmas suítes passaram com janela **duas vezes
  seguidas** logo depois (68/68, 7/7, 46/46), e `acceptance` (36/36), que
  também usa cliques reais, passou no mesmo lote.
- É o mesmo tipo de instabilidade com janela já registrado na 013D
  (quadros perdidos, máquina com pouca memória). Nenhuma dessas suítes lê o
  visual.
- O travamento do `combat_collect` após um `SCRIPT ERROR` é do próprio
  teste (não encerra quando um passo falha). Ele não foi alterado: a regra é
  não mexer em testes antigos só para fazê-los passar.

## Desempenho

Sonda temporária com janela e vsync desligado, mesma cena, média de 3 × 300
quadros:

| Hora | Com a Spec 014 | Sem céu, neblina, estrelas do chão e luz do refúgio |
|---|---|---|
| 12:00 | 6,45 ms (155 FPS) | 6,45 ms (155 FPS) |
| 21:00 | 5,42 ms (185 FPS) | 5,38 ms (186 FPS) |

Custo adicional medido: ≤ 0,04 ms por quadro.

## Verificação visual (câmera real)

`tests/sky_showcase.tscn` gravou em `spec014-evidence/views/`:

| Captura | Conferido |
|---|---|
| 01 08:00 | Manhã: Sol a 30°, luz levemente quente, sombras longas e nítidas |
| 02 12:00 | Dia: sombras curtas, cores naturais (mais claro que a manhã, sem estourar) |
| 03–05 16:30–17:30 | Fim de tarde: luz dourada crescente, sombras longas para nordeste; HUD "ANOITECE EM N" coincide |
| 06 18:00 | Pôr do sol: tom quente e lilás moderado; refúgio e Fogueira começam a se destacar |
| 07 18:30 | Anoitecer: lilás-azulado, fontes locais em destaque, poucas estrelas no chão |
| 08 21:00 / 09 00:00 | Noite: azul escuro legível; Player, dinos, inimigos, torre, armadilha, caminhos e rochas distinguíveis; refúgio e Fogueira acolhedores; sombras da Lua |
| 10 04:30 | Madrugada: igual à noite, Lua mais baixa |
| 11 05:30 / 12 05:59 | Amanhecer: estrelas somem, luz quente baixa, ambiente volta |
| 13–15 novo dia | Relógio 08:00; visual 6,08 → 7,08 → 8,39 h em 3,3 s, sem flash |
| céu 12/18/21/00/05:30 | Vista do céu (câmera extra): azul; pôr do sol; estrelas e Lua; amanhecer |

## Limites conhecidos

- **A câmera de jogo não vê o céu.** Lua e estrelas aparecem no céu só na
  vista extra do showcase; no jogo, a Lua é a luz fria com sombras e as
  estrelas são os pontinhos do chão.
- **Noite em tempo real é curta:** 18:00–20:00 dura 7,5 s e o amanhecer
  (05:00–06:00) ~3,75 s, porque a noite inteira tem 45 s.
- **Visual do novo dia percorre 06:00–08:00 em ~2,7 s**; o relógio da HUD já
  mostra 08:00 nesse intervalo (regra do relógio mantida).
- **Fogueira:** a luz noturna alcança 6,5 m, mas a cura continua 2,5 m.
- **Sem glow:** o brilho vem de emissão + luzes locais.
- **Valores de protótipo:** cores, energias e horários dos quadros-chave.

## Reproduzir

```powershell
.\tools\test_spec014.ps1                  # todas as suítes, headless
.\tools\test_spec014.ps1 -Rendered        # com janela (+ main_menu)
Godot_console --path . res://tests/sky_showcase.tscn -- --output=<pasta>
```

## Teste manual — APROVADO (2026-10-06)

O playtest manual validou o ciclo visual durante o gameplay: tudo
funcionando corretamente. Nenhuma mudança de gameplay, iluminação ou
balanceamento depois do playtest.

Roteiro executado:

1. **Manhã (08:00):** ao clicar JOGAR, luz de manhã, sombras visíveis, não
   "meio-dia".
2. **Dia:** a sombra das árvores encurta até o meio-dia e cresce à tarde;
   nada estourado.
3. **Fim de tarde (~16:30–18:00):** dá para perceber pela luz que a noite
   vem, junto com o aviso de 20 s.
4. **Pôr do sol/anoitecer:** bonito, sem saturação exagerada; nenhum flash
   às 18:00.
5. **Noite:** escura mas jogável. Ver Player, inimigos, caminhos, torres,
   armadilhas, refúgio e aliados; combater perto e longe do refúgio.
6. **Fontes locais:** refúgio identificável de longe; Fogueira acolhedora;
   cristal da torre; pontas da armadilha visíveis.
7. **Estrelas no chão:** leem como "noite estrelada" ou confundem com algo
   do jogo?
8. **Amanhecer:** clareia antes do fim da onda; segurando em 05:59 continua
   amanhecer; ao vencer, passa para a manhã em ~3 s sem flash.
9. **Pausa (ESC):** nada se move no céu/luz; ao voltar continua.
10. **Derrota e Reiniciar:** o ambiente congela na derrota; Reiniciar volta à
    manhã do Dia 1, sem resto da noite.
11. **Menu:** igual ao aprovado.
12. **Desempenho:** sem quedas perceptíveis ao anoitecer.
