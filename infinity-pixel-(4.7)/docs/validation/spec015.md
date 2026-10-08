# Spec 015 — Registro de validação (2026-10-06)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows
(Intel Iris Xe).

**013C, 013D e 014 aprovadas manualmente; 015 implementada / aguardando
playtest.** Spec 016 não iniciada.

## Auditoria (antes de mudar)

- **Mapa:** bosque (oeste, −21…−2,5 × 5,5…27,6), região rochosa (leste,
  7,2…23 × 7…28) e o corredor da ruína entre eles; base e BuildZone ao sul.
- **Rotas noturnas** (lidas das malhas): estrada da ruína x = 0, z −13…26;
  trilhas oeste/leste em z ≤ 2. **Nenhuma entra no bosque nem na rochosa.**
- **Chão livre** (sondagem com cilindro de 1,4 m, navmesh e distância de
  rota ≥ 3,5 m): 176 pontos no oeste e 187 no leste; marcos e pontos de
  teste escolhidos daí.
- **Encontros diurnos:** um por região, já territoriais e domesticáveis;
  recriados só quando o ponto fica vazio → usados como guardiões.
- **E:** `DomesticationChannel` lê a ação e a tecla física/evento.
- **Testes antigos** contam só `ArenaCollision` (66 sólidos): os marcos ficam
  em `TerritoryManager` e não alteram essa contagem.

## Resultados automatizados (runner `tools/test_spec015.ps1`, `--fixed-fps 60`)

| Suíte | Headless | Janela GL |
|---|---|---|
| `territory` (015) | 68/68 | 68/68 |
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

Nenhum teste antigo foi alterado. Sem `SCRIPT ERROR`/`SHADER ERROR`. Logs e
JSONs em `spec015-evidence/`.

### O que `territory` verifica (68)

- **Estado inicial [1–4, 26]:** manager com 3 territórios; Centro
  CONTROLLED, Oeste e Leste WILD; mapeamento das regiões (corredor da ruína
  fora); HUD 1/3.
- **Guardiões [10]:** são os 2 encontros diurnos; rótulo GUARDIÃO;
  domesticáveis; fora da onda; marcos apagados e a > 3,5 m das rotas.
- **Construção recusada [29, 31]:** Oeste/Leste selvagens recusam ("Território
  selvagem…"); corredor continua "Fora da área permitida"; BuildZone
  original continua válida.
- **Marco selvagem:** E não faz nada.
- **Derrotar o guardião Oeste [5, 7, 9, 10]:** WILD → READY; marco aceso; 0
  Pontos; onda inalterada; um único evento.
- **Cancelamentos:**
  - [15] soltar E; [14] sair do alcance; atacar; iniciar construção;
  - [17] pausar (ao despausar com E segurado, recomeça do zero);
  - [16] morrer (e [24] depois do respawn segue READY);
  - [18] começo da noite; [19] à noite não inicia.
- **Amanhecer [23]:**
  - Dia 2 com estados mantidos;
  - o encontro recriado no bosque é selvagem comum (sem guardião
    duplicado);
  - o guardião vivo do Leste não é recriado (2 selvagens diurnos).
- **Prioridade de E [11, 13]:**
  - com um selvagem elegível ao lado do marco pronto, E domestica e não
    ativa o marco, nem na mesma segurada depois;
  - durante a recuperação, um selvagem elegível que chega não é domesticado,
    nem depois na mesma segurada.
- **Conquista [12, 20, 21, 27]:** 2 s → CONTROLLED, marco jade, `claimed`
  uma vez, HUD 2/3; segurar E de novo não reconquista. Contorno existe.
- **Construção no Oeste recuperado [30, 33]:**
  - Fogueira aceita e construída (−20/−12);
  - árvore e marco continuam "Local ocupado";
  - Armadilha continua só em rota;
  - limite de 1 Fogueira mantido.
- **Domesticar o guardião Leste [6, 8, 9, 22]:**
  - READY; aliado comum com vida cheia; 0 Pontos;
  - morte posterior do aliado não muda nada (0 eventos).
- **Recuperar o Leste [20, 28, 32]:** 3/3; Fogueira aceita no Leste.
- **Persistência [23, 24]:** Dia 3 com 3/3; encontros recriados não viram
  guardiões; morte/respawn mantém 3/3.
- **Rotas [34]:** caminho da navmesh das 3 entradas até o refúgio.
- **Valores [35–38]:**
  - Fogueira 20/12, +25, 3 s, 2,5 m, 2 cargas, 25 s;
  - Armadilha 15/6, 15, 3 cargas, máx. 3;
  - Torre L1 e +15 por inimigo;
  - Coleta +10/30 HP e +6/45 HP, e coleta real +10.
- **Spec 014 [39]:** céu/estrelas e brilho noturno intactos; o marco brilha
  mais à noite.
- **Reiniciar [25, 40]:** estados iniciais, HUD 1/3, 2 guardiões novos, Oeste
  volta a recusar; conexões no `DayNightManager` iguais após 2 reinícios.

## Problemas encontrados e corrigidos

- **Marco pequeno demais** na 1ª captura: sumia entre as árvores do bosque.
  O visual foi ampliado ~1,45× e o colisor acompanhou (raio 0,75 m).
- **Ajustes no próprio teste novo** (não em testes antigos): posicionamento
  sem recursos não começava; a contagem de conexões precisava de um mundo
  vivo como base; um selvagem da onda cancelada entrava na contagem de
  encontros.

## Desempenho

Sonda temporária com janela e vsync desligado, Player no bosque com o marco
READY (pulsando e com luz), 3 × 300 quadros intercalados:

| Configuração | Tempo de quadro |
|---|---|
| Territórios completos | 9,86 ms |
| Sem a luz dos marcos | 9,65 ms |
| Sem territórios | 9,43 ms |

Custo ≈ 0,4 ms no pior lugar (bosque denso, marco com luz). Uma primeira
medição isolada indicou ~1 ms, mas não se repetiu com as configurações
intercaladas.

## Verificação visual (câmera real) — `spec015-evidence/views/`

| Captura | Conferido |
|---|---|
| 01 | Ao entrar no bosque: "FLORESTA OESTE · Território selvagem"; contorno rosado discreto; GUARDIÃO |
| 02 | Marco apagado ao lado do Player; dica "Marco inativo · Derrote ou domestique o guardião" |
| 03 | Fantasma vermelho; "Território selvagem: recupere o marco primeiro" |
| 04 | Guardião derrotado: marco dourado; objetivo "FLORESTA OESTE pronta: segure E…"; dica "TERRITÓRIO PRONTO… Segure E para ativar" |
| 05 | "RECUPERANDO TERRITÓRIO... 1,2 / 2,0 s" com barra |
| 06–07 | Anel de energia, "FLORESTA OESTE RECUPERADA", HUD **2/3**, marco jade |
| 08–09 | Fantasma verde no bosque; Fogueira construída (60/28) |
| 10–11 | Guardião do Leste domesticado → ALIADO; marco pronto |
| 12 | "REGIÃO ROCHOSA RECUPERADA", HUD **3/3** |
| 13–14 | Noite: marcos recuperados e Fogueira visíveis; contorno jade sutil |

## Limites conhecidos

- O limite é retangular (contorno reto no chão). Discreto, mas não segue a
  borda natural do bosque.
- **Armadilha:** continua permitida em qualquer rota noturna, inclusive na
  estrada da ruína ao norte da bifurcação (área não conquistável). Escolha
  para não mudar a 013D aprovada; pergunta aberta.
- O texto antigo do objetivo "Domestique o selvagem da clareira lateral"
  continua aparecendo quando não há aliados e nenhum marco pronto.
- Valores de protótipo: 2 s de E, 2,2 m de alcance, posição dos marcos.

## Reproduzir

```powershell
.\tools\test_spec015.ps1                  # todas as suítes, headless
.\tools\test_spec015.ps1 -Rendered        # com janela (+ main_menu)
Godot_console --path . res://tests/territory_showcase.tscn -- --output=<pasta>
```

## TESTE MANUAL NECESSÁRIO

1. **Início:** HUD "TERRITÓRIOS 1/3". Construir a Fogueira na BuildZone
   continua igual.
2. **Floresta Oeste:**
   - ao entrar, aparece o aviso "Território selvagem" (uma vez);
   - o contorno acende e some;
   - o guardião tem o rótulo GUARDIÃO;
   - o marco está apagado.
3. **Recusa:** B → Fogueira no bosque → vermelho, "Território selvagem:
   recupere o marco primeiro".
4. **Derrotar o guardião:** matar → marco dourado, sem "+PONTOS".
5. **Recuperar:**
   - segurar E no marco → barra 2 s;
   - testar soltar, afastar, atacar, B, ESC e morrer (cancela e recomeça do
     zero);
   - completo → anel, aviso e HUD 2/3.
6. **Construir no bosque:** Fogueira num lugar livre (verde); em cima de
   árvore/marco continua vermelho.
7. **Região Rochosa, ainda selvagem:** construir é recusado. Enfraquecer o
   guardião e **domesticar** (E perto dele) → aliado normal e marco pronto.
8. **Prioridade de E:** segurar E perto do marco pronto **e** de um
   selvagem enfraquecido → só domestica; soltar e segurar de novo → ativa o
   marco.
9. **Recuperar o Leste** → HUD 3/3 e construir lá.
10. **Noite:** não dá para iniciar a recuperação; se anoitecer no meio,
    cancela. Inimigos continuam passando normalmente; torres, armadilhas e
    aliados como antes.
11. **Amanhecer:** territórios continuam recuperados; os encontros que
    voltam são selvagens comuns (sem GUARDIÃO).
12. **Morte/respawn:** nada se perde.
13. **Reiniciar:** volta a 1/3, guardiões de volta, construção no bosque
    recusada.
14. **Visual:** marcos legíveis de dia e à noite; contorno não polui o mapa.
