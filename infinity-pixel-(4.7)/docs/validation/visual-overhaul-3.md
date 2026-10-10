# Validação — Visual Overhaul 3.0 "Expedição Pré-histórica"

Data: 10/10/2026. Base: `ef1f071`. **Sem push.** Nenhuma Spec foi marcada como aprovada; tudo aguarda o
playtest manual. Specs 015 e 013D não foram alteradas: o inventário continua **sem pausar**.
Evidências reais do Godot: `visual-overhaul-3-evidence/` (comparações: esquerda = antes, direita = depois).

## Estado inicial do Git (verificado)

- `main` em `ef1f071`, árvore limpa e **`main` = `origin/main`**. Os commits que o relatório anterior
  chamava de "locais, sem push" já estavam no GitHub no início desta execução. Não foram enviados por mim, e
  nada foi enviado agora.
- Linha de base reexecutada: **25/25 suítes, 760 checks, 0 falhas**, igual ao relatório anterior.

## Estado de cada entrega

| Entrega | Implementado | Teste automático | Capturas | Playtest |
|---|---|---|---|---|
| A — Menu principal | sim | `main_menu` (janela), `visual_overhaul3` | m01 (1280/1920) | pendente |
| A.5 — Pausa, configurações, controles, créditos, derrota, tutorial | sim | `settings_ui`, `tutorial` | m02–m06 | pendente |
| B — Mochila do Explorador | sim | `inventory_ui` 26 (era 16) | i01/i02 em 3 resoluções | pendente |
| C — Dinossauros + animações + facções | sim | `visual_overhaul3`, `night_enemy_visual`, `creature_motion` | c02–c05, turntable | pendente |
| D — Player explorador | sim | `player_facing`, `attack_direction`, `visual_overhaul3` | c01, turntable | pendente |
| E — HUD, rótulos, anéis, painel inferior | sim | `visual_overhaul3`, `combat_collect` | h01/h02 | pendente |
| F — Cenário | **parcial** (ver limites) | `visual_overhaul3`, `visual_invariants` | s01–s04 | pendente |
| G — Efeitos | sim | `visual_overhaul3` | — | pendente |

## A — Menu principal

- **Layout:** a coluna de pedra fica à esquerda, com uma faixa escura que se dissolve no cenário. O diorama 3D
  ocupa a direita.
- **Marca:** "JADEFALL" talhado, com letras em camadas, contorno, âmbar e duas rachaduras discretas. O cristal
  do Refúgio aparece como emblema.
- **Subtítulo:** placa de pedra com "GUARDIÕES DO REFÚGIO" entre dois ossos fósseis.
- **Fonte:** `SystemFont` (Segoe UI Black → Arial Black → Verdana). Nenhuma fonte foi embutida; ver os limites.
- **Botões:** JOGAR (âmbar, maior), TUTORIAL, CONTROLES, CONFIGURAÇÕES, CRÉDITOS e SAIR.
  - Os botões secundários têm o mesmo tamanho (348 × 48).
  - Cada botão tem um ícone vetorial próprio: cristal, pegadas, tecla, engrenagem, amonite e porta de pedra.
  - No hover, a borda fica jade, aparece um brilho, uma faixa jade lateral e o botão avança um pouco. No clique,
    ele afunda.
  - Entrada em cascata e foco de teclado em âmbar.
  - Não há CONTINUAR: o jogo não tem save.
- **Diorama:** é a arte real do vale, sem gameplay (sem corpos, IA, onda ou navegação).
  - Luz de fim de tarde, céu procedural e névoa leve.
  - Um aliado em primeiro plano cheira o chão e olha em volta (pose de vitrine), e um selvagem atravessa a
    trilha ao fundo.
  - Pegadas fósseis, ossada de costelas, crânio, totem e rocha com amonite.
  - Fagulhas dos braseiros, poeira de jade e luz jade no cristal.
  - A câmera gira ±2° em 48 s.
- **Bug corrigido:** chamar `show_menu()` com o menu aberto empilhava fundos (e sóis). A tela ficava estourada.
  Isso apareceu nas minhas primeiras capturas.

## A.5 — Telas relacionadas

- Pausa, configurações, controles, créditos, derrota e fim do tutorial usam a mesma "tábua" de pedra.
  - Cabeçalho com ícone (fogueira na pausa, cristal em brasa na derrota) e título talhado.
  - Divisor jade com osso, ossos fósseis nos cantos e cristal no topo.
  - Sliders com pegador de cristal.
- O painel do tutorial ganhou pegada, contador e uma trilha de passos.
- Os controles passaram a citar as abas da mochila.

## B — Mochila do Explorador

- **Estrutura:**
  - Cartão de 1000 px de referência (78% de 1280) sobre um véu escuro.
  - Cabeçalho com mochila desenhada, teclas I/ESC desenhadas e FECHAR.
  - Três abas: **RECURSOS**, **CONSTRUÇÕES** e **COMPANHEIROS**. Funcionam por clique ou pelas teclas 1, 2 e 3,
    e a última aba é lembrada.
  - As páginas têm altura fixa, então o cartão não "pula" ao trocar de aba.
- **Recursos:** Madeira, Pedra e Pontos de Defesa, com ícone, quantidade, de onde vêm e para que servem.
  Também mostra os territórios recuperados e a regra de rebrota.
- **Construções:** Fogueira e Armadilha, com ícone, custo, "faltam N", estado e CONSTRUIR. Do outro lado, as
  torres, com pontos, custos (30 / 30 / 45), torres erguidas, territórios e estruturas. **Preços inalterados.**
- **Companheiros:** um cartão por aliado real, com:
  - medalhão com silhueta;
  - origem lida no momento da domesticação ("Ex-guardião · FLORESTA OESTE", "Ex-invasor da noite" ou
    "Selvagem do vale");
  - vida e barra ao vivo;
  - SEGUINDO (jade) ou FICAR (âmbar);
  - função escrita a partir das constantes reais: 7 m em SEGUIR, 8 m em FICAR e golpe de 20.

  Sem aliados, aparece um estado vazio ilustrado (pegadas até uma silhueta) explicando como domesticar. Nenhuma
  espécie ou estatística foi inventada, e a IA não foi tocada.
- **Rodapé:** "O MUNDO CONTINUA · DIA 10:30", com relógio animado. O inventário segue sem pausar (013D).
- **Testado (teclas e cliques reais):**
  - I, ESC, FECHAR (botão e Enter) e clique fora fecham.
  - O clique dentro do cartão ou numa aba não ataca.
  - 20 aberturas não duplicam o painel, e o foco abre em FECHAR.
  - Nenhum texto fica cortado em nenhuma aba em 1280×720, 1600×900 e 1920×1080, e o cartão fica entre 70% e 82%
    da largura.
  - Os cartões de aliado atualizam ao vivo.

## C — Dinossauros

- **Método:** `scenes/visuals/creature_forge.gd` com `tools/build_creatures.gd`. As malhas são *lofted* e
  facetadas, geradas por código e gravadas em `dino.tscn`, `carno.tscn` e `guardian.tscn`. Os nomes dos nós e
  um material por parte foram mantidos, porque a paleta noturna e os testes dependem deles.
  1. **Primeiro um** dinossauro (o selvagem). Comparei no *turntable* contra o modelo antigo
     (`comparacao/turntable_*`).
  2. A 1ª versão ficou fina demais vista de cima. Engrossei corpo, coxas, pescoço e cabeça e encurtei a cauda.
  3. Depois apliquei ao Carnotauro: mais pesado, crânio curto e fundo, chifres e braços mínimos.
- **Anatomia:**
  - crânio longo com bochechas, arcada sobre os olhos e crista nasal;
  - mandíbula separada (abre), dentes alternados em cima e embaixo;
  - olhos com pupila em fenda e pescoço em S;
  - tórax com ventre claro e listras escuras no dorso (cor por vértice);
  - cauda com pivô na raiz;
  - pernas digitígradas (coxa, canela, metatarso e três dedos com garras), com pivô no quadril;
  - bracinhos com dois dedos.
- **Facções** (a cor não é a única diferença):
  - invasor: espinhos dorsais no corpo e na cauda;
  - guardião: máscara de osso (chifre nasal e placas) e colar de contas âmbar com pedra-runa;
  - aliado: coleira com gema e crista jade.

  Os ornamentos levam o material na superfície da malha, então as regras de material do teste noturno
  continuam valendo.
- **Animações** (só visuais; o "rig" é feito por código, porque o modelo é plano):
  - Repouso: respiração, olhar em volta e piscadas.
  - Andar e correr: passo a partir do quadril, cabeça balançando, inclinação e cauda mais rápida.
  - Ataque: na preparação, a cabeça ergue e a boca abre; no golpe, o bote e a mandíbula fechando.
  - Dano: encolhe.
  - Domesticação: pulinho e cabeça para cima.
  - Eliminação: o corpo de jogo some no mesmo quadro (regra mantida). Fica uma cópia só visual que tomba e
    afunda em ~1,3 s.
  - **Colisões, rumo, alvo, dano e instante do dano: inalterados.** As correções P0/P1 seguem cobertas
    (`creature_motion` 32/32 e `gameplay_stability` 15/15).

## D — Player

- Novo explorador:
  - **chapéu de abas largas com faixa jade e pena** (é a silhueta mais legível vista de cima);
  - capa jade presa nos ombros;
  - mochila com saco de dormir, alças e lanterna de cristal;
  - colete de couro sobre a túnica âmbar, cinto com bolsa;
  - botas com bainha, braçadeiras e machado de pedra lascada.
- Chevron jade discreto no chão, à frente do modelo, para indicar a direção.
- A capa sobe para trás ao correr. O sinal antigo da rotação levava a capa para dentro do corpo e foi corrigido.
- Collider, alcance, dano, velocidade e mira: inalterados (`player_facing` 37, `attack_direction` 9 e
  `physics_contracts` 23).

## E — HUD

- **Painéis:**
  - A estrutura e os textos testados foram mantidos.
  - Painéis de pedra chanfrada e ícones temáticos (explorador de chapéu, cristal, recursos).
  - A borda pulsa em brasa com vida baixa (jogador abaixo de 30% ou Refúgio abaixo de 35%), fica âmbar na
    contagem para a noite e violeta à noite.
- **Rótulos contextuais** (só visibilidade e tamanho; texto e combate intactos):
  - Só o aliado mais perto (≤ 3,3 m) mostra o rótulo completo.
  - Aliados feridos a até 14 m mostram um rótulo menor.
  - Invasores aparecem sempre (menores a mais de 16 m).
  - Guardiões aparecem até 20 m e selvagens até 15 m.
  - Rótulos sobrepostos na tela ficam com o de maior prioridade.
- **Anéis de alcance:** as linhas brancas vinham dos `RangeRing` das torres (0,12 de opacidade mesmo de longe;
  0,45 perto).
  - Agora ficam escondidos de longe, aparecem a 0,24 perto do alcance e a 0,70 ao interagir com a torre.
  - São tracejados e jade claro.
  - A prévia do ponto vazio continua igual, e o raio é sempre o valor real da torre.
- **Painel inferior:**
  - Mais baixo, com marcador de cristal no objetivo.
  - A tecla da ação aparece desenhada (E, F, H ou CLIQUE), lida do próprio texto da dica.

## F — Cenário (parcial)

- **Sítio fóssil:**
  - Duas lajes com esqueleto em relevo, perto da Ruína do Arco e na Região Rochosa.
  - Costelas meio enterradas, amonites nas bordas e três rastros de pegadas fossilizadas acompanhando as trilhas
    selvagens.
  - Tudo com **no máximo 0,3 m**, sem colisão, numa malha única e sem sombra.
- **Refúgio:** crânios de dinossauro na travessa dos dois estandartes, no alto e acima dos sólidos existentes.
- **Marcos de território:** um pequeno crânio-totem no degrau do pedestal, dentro do sólido do marco.
- Navmesh, `arena_collision.tscn`, 87 corpos estáticos e posições de gameplay **iguais**
  (`visual_invariants` 14/14 e `navigation_contracts` 38/38).
- **Não feito:** variedade nova de vegetação, rochas remodeladas, novas ruínas e transições de bioma. Ver os
  limites.

## G — Efeitos

- Domesticação: pulinho com a cabeça para cima, além dos anéis jade que já existiam.
- Ataques dos dinossauros: preparação e bote com a boca.
- Eliminação: restos que tombam e afundam.
- Coleta e mineração: poeira no chão a cada golpe, além das lascas.
- Conquista de território: coluna de luz jade e lascas.
- Início da onda noturna: vinheta violeta curta nas bordas (1,6 s, sem bloquear cliques).
- Construção, torre e acertos: mantidos.
- Os instantes de dano e as regras não mudaram.

## Testes (execuções reais)

| Execução | Resultado |
|---|---|
| Linha de base (`ef1f071`), sem janela | 25/25 suítes, 760 checks, 0 falhas |
| Final, sem janela (`--fixed-fps 60`) | **26/26 suítes, 798 checks, 0 falhas** |
| Final, com janela (`main_menu`, `visual_overhaul3`, `inventory_ui`, `tutorial`) | **4/4 suítes, 121 checks, 0 falhas** |

- **Suíte nova `visual_overhaul3` (28 checks):** cobre o menu (marca, botões reais e consistentes, ícones,
  diorama sem gameplay e o bug do fundo duplicado), a tábua de configurações e o FossilArt (≤ 0,3 m, sem
  colisão). Também cobre:
  - partes do modelo e pivô da cauda;
  - rig sem mover o corpo;
  - máscara do guardião, que some ao domesticar, e a origem registrada;
  - regra de domesticação intacta;
  - rótulos contextuais;
  - tecla F desenhada;
  - anel escondido longe e visível perto com o raio real;
  - espinhos do invasor na paleta noturna;
  - vinheta que some sozinha;
  - restos que somem;
  - partes do explorador;
  - coluna de luz da conquista.
- **`inventory_ui`:** passou de 16 para 26 checks (abas, teclas 1–3, estado vazio, aliados ao vivo,
  3 resoluções, FECHAR por clique).
- **Testes antigos alterados, com o motivo:**
  - `main_menu`: a marca agora é desenhada (`TitleMark`) e o subtítulo mudou para "GUARDIÕES DO REFÚGIO";
  - `inventory_ui`: o corte de texto passou a ser verificado aba por aba (páginas escondidas não têm tamanho) e o
    teste abre a aba CONSTRUÇÕES antes de clicar em CONSTRUIR.

  Nenhuma expectativa de gameplay foi alterada.

## Desempenho

- **Método:** `tests/perf_probe.tscn --live`, com janela de 1280×720, sem vsync e 10 s por vista. Medi o "antes"
  (cópia de `ef1f071`) e o "depois", alternando.
- **Nova vista:** `menu_principal`.
- **Condições:**
  - notebook **na tomada** (99%);
  - **o editor do Godot estava aberto** (não fechei, para não perder trabalho seu).
- **Otimização feita depois da 1ª medição:** a 1ª medição do "depois" tinha +70 a +250 chamadas de desenho. Por
  isso, as 3 garras viraram uma malha por pé e as partes pequenas deixaram de projetar sombra. A tabela abaixo é
  da versão final (depois r2 e r3).

FPS pior 1% / médio (rodada · rodada) e chamadas de desenho:

| Vista | Antes r1 · r2 | Depois r2 · r3 | Chamadas antes → depois |
|---|---|---|---|
| menu principal | 58/156 · 70/155 | 52/178 · 53/177 | 933 → 428 |
| padrão 12:00 | 77/159 · 76/154 | 87/153 · 84/154 | 947 → 943 |
| padrão 17:30 | 100/188 · 105/192 | 99/170 · 92/173 | 908 → 884 |
| padrão 21:00 | 80/183 · 76/187 | 91/167 · 84/174 | 601 → 628 |
| Refúgio 12:00 | 78/163 · 70/167 | 85/154 · 85/154 | 926 → 922 |
| ponto oeste 21:00 | 84/172 · 85/167 | 88/158 · 89/160 | 941 → 918 |
| vivo: dia com dinossauros | 55/136 · 55/136 | 54/125 · 52/126 | 1103 → 1099 |
| vivo: noite, 3 torres, aliado | 44/132 · 49/136 | 45/123 · 45/125 | 1015 → 993 |
| vivo: inventário aberto à noite | 64/122 · 80/136 | 55/112 · 71/115 | 1177 → 1262 |
| vivo: onda de 10, 3 torres | 38/97 · 45/105 | 41/96 · 39/89 | 1609 → 1443 |
| vivo: onda de 10 + 3 aliados | 41/112 · 41/109 | 41/102 · 39/100 | 1336 → 1278 |
| vivo: tutorial | 93/185 · 86/181 | 85/161 · 95/167 | 439 → 483 |

- **Pior 1%:** dentro da variação entre rodadas nas duas versões.
- **Médias:** de 5% a 10% menores nas cenas vivas e de 0% a 10% nas estáticas. O custo vem de malhas mais
  detalhadas e da animação por código, não de chamadas de desenho.
- **Menu:** média maior, chamadas menos da metade, pior 1% um pouco menor (partículas e céu).
- **Meta de 60 FPS:** atingida na média em tudo. **No pior 1% das cenas vivas de noite, não** (39–55), e isso já
  acontecia antes (38–80). Não é regressão desta rodada.
- Repetir com o editor fechado:
  `Godot_console --path . --resolution 1280x720 --disable-vsync res://tests/perf_probe.tscn -- --report=perf.json --live`.

## Limites honestos

- **Modelagem:** os personagens são **procedurais**, sem esqueleto nem animação em ferramenta de 3D. A silhueta
  e a leitura melhoraram muito, mas não equivalem a modelos feitos à mão por um artista. O caminho profissional
  (Blender com rig e animações exportadas) continua no roadmap.
- **Fonte:** o título usa `SystemFont` (Segoe UI Black / Arial Black). Não embuti nenhuma fonte, porque não havia
  arquivo com licença adequada no projeto. Numa máquina sem essas fontes, o Godot usa outra do sistema. Para a
  Steam, recomendo uma fonte OFL embutida.
- **Cenário (Fase F):** só os sinais pré-históricos baixos e os crânios. Vegetação, rochas, ruínas e transições de
  bioma ficaram como estavam, porque mexer no gerador do vale exige revalidar colisões e navmesh. Prioridade da
  próxima rodada.
- **Áudio de interface:** não adicionei som de hover/clique, porque não há asset adequado.
- **Capturas:** a vista "c04 tipos" corta o guardião à esquerda nas duas versões (mesmo enquadramento). O
  guardião aparece de perto em c02/c03.

## Roteiro de playtest

1. **Menu:**
   - Os botões respondem bem (hover, clique, teclado)?
   - O diorama tem movimento suficiente sem cansar?
   - O título lê bem na sua tela?
2. **Configurações e pausa:** a nova tábua está boa? Os sliders estão fáceis de usar?
3. **JOGAR:**
   - Os dinossauros novos parecem melhores de perto e de longe?
   - Dá para distinguir guardião (máscara de osso), selvagem, invasor (espinhos) e aliado (coleira)?
4. **Combate:** a preparação da mordida (cabeça erguida e boca aberta) ajuda a recuar a tempo?
5. **Rótulos:** com 2–3 aliados juntos, o centro da tela ficou limpo? Faz falta ver a vida de todos?
6. **Mochila (I):**
   - Teste as abas com clique e com 1/2/3.
   - Verifique COMPANHEIROS com e sem aliados.
   - O tempo continuar correndo incomoda?
7. **Torres:** o alcance ficou legível sem as linhas brancas atravessando a tela?
8. **Fósseis:** procure o sítio fóssil perto da Ruína e na Região Rochosa, e as pegadas nas trilhas selvagens.
9. Desempenho percebido na tomada, com o editor fechado.
