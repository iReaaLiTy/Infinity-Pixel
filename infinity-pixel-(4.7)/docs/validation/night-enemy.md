# Validação — identidade visual do inimigo noturno (Spec 019 antecipada)

Data: 09/10/2026. Entrega pequena e independente, pedida pelo usuário: só o
visual dos dinossauros criados pelas ondas noturnas. Sem commit, sem push.
Aprovação: avaliação visual do usuário (pendente).

## Regra

A aparência depende da **origem da criatura**, não do horário:

| Criatura | Aparência |
|---|---|
| Selvagem diurno (inclui o guardião territorial) | original (terracota), inclusive se continuar vivo à noite |
| Domesticado | aliado: original + crista jade + coleira |
| Inimigo criado pela onda noturna | paleta azul-violeta |
| Inimigo da onda domesticado | volta ao original e vira aliado |

## Implementação

- `scenes/world/wave_manager.gd`: em `_spawn_enemy()`, que só a onda chama, o inimigo recém-criado
  recebe `Visual.set_night_threat()`. Esse é o único ponto do código que decide quem é noturno.
- `scenes/visuals/actor_visual.gd`:
  - `set_night_threat()` troca o `material_override` **desta instância** por materiais próprios,
    um por papel (corpo, barriga, crista/garras/mandíbula, olhos, pupilas/pés), e guarda os
    originais.
  - `set_ally()` restaura os originais antes de aplicar a marca de aliado.
  - Os materiais do modelo (`dino.tscn`), compartilhados por todas as criaturas, nunca são
    alterados.
  - Nada fica guardado entre partidas: não há cache estático.
- **Paleta** (tom desejado na tela, à noite):

  | Papel | Cor |
  |---|---|
  | Corpo | `#18244D` |
  | Pupilas e pés | `#25214F` |
  | Barriga | `#332452` |
  | Crista, garras e mandíbula | `#6678C8` |

  - Os olhos têm o único brilho (`#6678C8`, energia 0,8, sem neon).
  - Uma borda de luz fraca (rim 0,3) separa a silhueta escura do chão.
- **Calibração medida:** com o albedo literal `#18244D`, o corpo aparecia como `#081560` às 21:00,
  azul elétrico. O luar da Spec 014 multiplica R/G/B por cerca de 0,26 / 0,43 / 1,58 (luz linear).
  O albedo agora é derivado da paleta por esse ganho (`night_albedo()`). Medido na tela às 21:00:
  corpo de `#17244B` a `#19274E`; às 00:00, de `#142146` a `#18264D`.
  Comparação em `night-enemy-evidence/comparacao/literal_x_calibrado_*.jpg`.

**Intocados:** `wild_dino.gd` e toda a pasta `scenes/enemies/`, `dino.tscn`, `carno.tscn`,
`scenes/player/`. Vida, dano, velocidade, IA, navegação, domesticação, animações, quantidade de
inimigos, regras das ondas, economia e colisões não mudaram.

## Testes

**Novo `tests/night_enemy_visual` (16 checks), sem janela e com janela:**
1. Dia: selvagens diurnos e guardiões com os materiais originais.
2. Onda da Noite 1 com 3/3 inimigos, todos com a paleta em todas as malhas.
3. Selvagens que continuam vivos à noite e guardiões não mudam.
4. Corpo calibrado, com borda de luz e sem emissão; só os olhos brilham (≤ 1,0).
5. Materiais compartilhados do modelo inalterados.
6. Inimigo da onda domesticado: cores normais, crista jade e coleira; vida igual; os outros
   inimigos continuam noturnos.
7. Reinício da partida: selvagens e guardiões originais, materiais compartilhados intactos, a
   nova onda noturna de novo, sem alteração acumulada.

**Regressão, sem mudar nenhuma expectativa antiga:**

| Execução | Resultado |
|---|---|
| Sem janela, `--fixed-fps 60` | **19/19 suítes, 663 checks, 0 falhas** (os 647 anteriores, com os mesmos números por suíte, + 16) |
| Com janela, `--fixed-fps 60` | **20/20 suítes, 693 checks, 0 falhas, nenhuma perda de foco** (677 + 16) |

Resumos: `night-enemy-evidence/regressao_headless/resumo.txt` e `regressao_janela/resumo.txt`. As
suítes com janela rodam numa cópia idêntica do código, com o observador de foco, como na P0/P1.

Aviso preexistente, sem relação com esta entrega: `1 resources still in use at exit` é o áudio
`res://assets/audio/bond.wav` (`--verbose`). Ele já aparecia em `physics_contracts`, `build_heal`
e outras suítes da P0/P1.

## Capturas

Em `night-enemy-evidence/capturas/`, geradas por `tools/night_enemy_capture.tscn`. O mesmo
cenário, no pátio do Refúgio, mostra lado a lado o guardião (selvagem diurno), um inimigo da onda
e um aliado domesticado:
- de perto às 21:00, 00:00, 05:30, 18:30 e 12:00;
- pela câmera do jogo às 21:00, 00:00 e 12:00;
- os 3 inimigos da Noite 1 chegando, às 21:00.

## Limitações observadas

- A calibração mira o meio da noite. No anoitecer (18:30) e no amanhecer (05:30), a luz quente
  deixa o inimigo quase preto-arroxeado. Ainda lê como ameaça escura, mas perde o azul.
- Os detalhes `#6678C8` (crista, garras, mandíbula) quase não aparecem de longe. O que distingue
  o inimigo na câmera do jogo é a silhueta escura e os olhos.
- O rótulo sobre o inimigo continua "SELVAGEM": texto da HUD, fora deste pedido.
