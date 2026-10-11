# Validação — Visual Overhaul 4.0 "Polimento, cenário, criaturas e desempenho"

Data: 11/10/2026. Base: `52ff985`. **Sem push.** Nenhuma Spec foi marcada como aprovada; tudo aguarda o
playtest manual. As Specs 015 e 013D não mudaram: o inventário continua **sem pausar**. O balanceamento
não foi tocado (vida, dano, custos, pontos, duração do dia/noite, ondas, domesticação, territórios,
tutorial).

Evidências reais do Godot em `visual-overhaul-4-evidence/`: `comparacao/` (esquerda = antes `52ff985`,
direita = depois, mesmo enquadramento) e `desempenho/` (JSON de cada rodada).

## Estado inicial do Git (verificado)

- `main` em `52ff985`, igual a `origin/main` (0/0). Os 6 commits que o relatório 3.0 chamava de
  "locais" já estavam no GitHub. Não fui eu que enviei, e nada foi enviado agora.
- A árvore tinha 9 arquivos `.uid` não versionados, gerados pelo Godot para os scripts da 3.0. Foram
  incluídos no primeiro commit.
- Linha de base:
  - **sem janela: 26/26 suítes, 798 checks, 0 falhas** (o `main_menu` exige janela);
  - **com janela: 27/27 suítes, 828 checks, 0 falhas** (o `acceptance` faz 36 checks com janela e 33 sem).
- **Por que só 4 suítes com janela na 3.0:** foi uma escolha de tempo minha, não uma limitação do
  ambiente. Agora rodei todas, na linha de base e no fim.

## Estado de cada entrega

| Fase | Implementado | Teste automático | Validado com janela | Aguardando playtest |
|---|---|---|---|---|
| A — Desempenho | sim | `visual_overhaul4` (sombras, log) + `perf_probe` | medições abaixo | percepção de fluidez |
| B — Vegetação | sim | `visual_overhaul4` (regras do cenário) | capturas b01, s01–s04 | sim |
| C — Rochas e ruínas | sim | `visual_overhaul4`, `visual_invariants`, `world_layout` | b02, b03 | sim |
| D — Dinossauros | sim (procedural; sem Blender) | `visual_overhaul4` (rig e passo), `creature_motion`, `gameplay_stability` | turntable, c02–c04, k02 | sim |
| E — Player | sim (refino) | `player_facing`, `attack_direction`, `visual_overhaul3` | turntable, c01 | sim |
| F — Interface | fonte embutida; o resto revisado e mantido | `main_menu`, `inventory_ui`, `visual_overhaul4` | m01–m06, i01/i02, k01 | sim |
| G — Áudio | sim (sons sintetizados, **não ouvidos**) | `visual_overhaul4` (6 checks de áudio) | — | **ouvir** |
| H — QA | sim | 27 sem janela + 28 com janela | 29 comparações | — |

## A — Auditoria e desempenho

### Ferramenta

O `tests/perf_probe.gd` passou a registrar, por vista:
- chamadas de desenho do passe visível e objetos;
- CPU e GPU de render;
- **tempo dos scripts por quadro** (nó de prioridade mínima × nó de prioridade máxima), média e p99;
- tempo dos scripts de física por passo;
- memória estática e de vídeo;
- tempo de carregamento do menu e da partida.

Duas opções novas:
- `--audit` lista a composição da cena (malhas visíveis, quantas projetam sombra, por ramo da cena, luzes,
  partículas, materiais únicos, nós com processamento).
- `--ablate` mede a onda de 10 sem cada subsistema.

### Gargalos encontrados (medidos no "antes")

1. **Log de combate no console: a causa do pior 1%.**
   - Cada `print()` custava ~0,43 ms com a saída num arquivo e ~15 ms através de pipe (é o caso da saída
     do editor). Cada golpe imprimia de 1 a 3 linhas.
   - O p99 dos scripts de física chegava a ~12 ms com dinossauros vivos. Só os quadros com golpe tinham
     esse pico.
   - Prova (`--quiet`, mesmo código): o p99 da física caiu para 0,7–2,3 ms e o pior 1% das cenas vivas subiu
     de 55–72 para 89–103 FPS.
   - Para separar a causa, instrumentei uma cópia de rascunho, nunca o repositório.
2. **Sombras:** ~80% das chamadas de desenho. Desligando a sombra direcional na onda de 10, as chamadas
   caem de 1450 para 301 e a GPU de 5,2 para 2,5 ms.
3. **ArenaArt:** 226 nós soltos (42 troncos, 84 copas, 16 rochas e 84 "samambaias" cônicas), todos
   projetando sombra. Escondê-la tira ~1040 chamadas (1450 → 410).
4. **O que não pesava:**
   - Scripts de `_process`: ~0,7–1,1 ms por quadro somados, p99 < 2 ms.
   - Luzes dinâmicas: 2 a 4 omni, sem sombra.
   - Partículas: só no menu.
   - Criar um invasor: < 1,5 ms (medido); derrotá-lo: ~2–2,6 ms (medido).
   - HUD: desligar o processamento do HUD não mudou o FPS (ablação).

### Otimizações aplicadas (cada uma medida)

| Otimização | Efeito medido |
|---|---|
| Mensagens por golpe, por spawn e de navegação → `print_verbose` (eventos raros seguem no log) | p99 da física de ~12 ms → ~1 ms; pior 1% vivo +20 a +40 FPS |
| Flora e rochas em blocos 3×3 (19 malhas no lugar de 226 nós) | −700 chamadas de dia |
| Sombra direcional em 2 fatias até 45 m (a câmera vê ~36 m) | menos passadas de sombra, sem corte visível nas capturas |
| Ventre, mandíbula, braços, coleira e chifres das criaturas sem sombra | −6 objetos por criatura em cada fatia |
| Copa da árvore coletável numa malha só | −14 nós |

**Testadas e descartadas por falta de efeito medido:**
- **Pré-aquecimento de shaders no início da partida:** o pico isolado continuou.
- **Pré-render dos glifos da fonte:** o pico continuou, e o menu ficou ~0,5 s mais lento para carregar.

Removi as duas.

## B — Vegetação

- **Gerador** `tools/build_flora_art.gd` + `scenes/visuals/flora.gd`:
  - As árvores e rochas são redesenhadas **nos mesmos lugares** dos nós antigos.
  - Os nós antigos ficam ocultos, porque o colisor e a navmesh leem o transform deles.
  - Tudo é gerado pela fonte (`tools/build_first_map.gd` chama o gerador): regenerar o mapa não apaga nada.
- **Cinco espécies, cada uma com silhueta própria vista de cima:**
  - **araucária**: tronco reto e verticilos de galhos com tufos, uma estrela em camadas;
  - **conífera**: quatro saias serrilhadas que caem nas pontas;
  - **samambaia-arborescente**: frondes arqueadas em estrela;
  - **copa larga**: tronco que bifurca e 6–7 lobos irregulares;
  - **árvore-jade**: lobos em gota, tons jade e cristais no pé.

  Cada árvore varia em altura, inclinação, tom (±7%), raízes na base e número de lobos e galhos.
- **Regra de leitura:**
  - na área andável, as copas começam acima de **1,9 m**;
  - entre 0,3 m e 1,9 m só há tronco ou rocha, sempre sobre o colisor;
  - o sub-bosque fica rente (≤ 0,3 m).
- **Sub-bosque em grupos:** samambaias, arbustos, cavalinhas, tapetes de musgo, troncos caídos com
  musgo e cogumelos. Há áreas densas (Floresta Oeste e bordas) e a campina continua aberta.
- **Floresta Oeste:** coníferas, araucárias e samambaias-arborescentes, sub-bosque verde-azulado, musgo
  ao pé das árvores e das rochas, troncos antigos. O marco territorial e as rotas ficaram livres.
- **Borda do vale** (entre o Boundary e o paredão, fora da área andável): mata alta de cicadáceas,
  samambaias-arborescentes e cavalinhas. As entradas das ondas ficam sempre abertas.
- **Árvores coletáveis:** mesma família (copa de lobos), em tons quentes de "lenha".

## C — Rochas, ruínas e biomas

- **Rochas em três famílias:** matacão arredondado, laje em camadas (estratos claros e escuros, topo
  plano) e agulha. Cada uma varia em escala e tom.
  - Na Floresta Oeste, levam **musgo** no topo.
  - Na Região Rochosa, **líquen** em manchas e tons cinza-esverdeados.
- **Região Rochosa:**
  - Os rochedos grandes ganharam cristais no topo, sobre o sólido.
  - Há cascalho e cristais pequenos na base das pedras, e 7 lajes baixas aflorando.
  - Cicadáceas baixas.
  - Na borda leste, fora da área andável, agulhas de pedra com cristais.
- **Ruína do Arco:**
  - Glifos jade nas faces dos pilares e da verga (espiral de amonite, pegada de três dedos e losango de
    cristal), dentro da caixa do sólido.
  - Cristais brotando da verga.
  - Piso antigo de lajes sob o arco, rente.
  - Anel de colunas quebradas (≤ 0,28 m) marcando a praça antiga, mais blocos talhados caídos.
- **À noite:** cristais e glifos estão numa malha própria no grupo `night_glow`. Ficam discretos de dia
  (0,25) e acesos à noite (1,1).
- **Restrições respeitadas** (`visual_invariants` 14/14, `world_layout` 57/57, `navigation_contracts`
  38/38 e `visual_overhaul4`):
  - navmesh com o mesmo hash;
  - 66 sólidos iguais;
  - posições de torres, territórios e entradas iguais;
  - trilhas livres abaixo de 1,9 m;
  - entradas das ondas livres entre 0,3 m e 1,9 m;
  - cada um dos 42 troncos e 16 rochas com arte sobre o colisor.

## D — Dinossauros

- **Pipeline:**
  - O **Blender não está instalado** nesta máquina e, pela regra do pedido, não instalei nada.
  - O pipeline continua procedural (`creature_forge.gd` + `tools/build_creatures.gd`).
  - Melhorei primeiro o selvagem e comparei no turntable (lateral, três-quartos, câmera estratégica,
    topo, cabeça e passada). Depois apliquei ao Carnotauro (mesmo gerador).
  - Recomendação para quando houver Blender: exportar GLB com esqueleto mantendo os mesmos nomes de nó
    (`LegL`, `KneeL`, `AnkleL`, `Tail`, `TailTip`, `Head`, `Jaw`...). Assim a paleta noturna, os testes e
    a animação continuam valendo.
- **Modelo:**
  - Pernas com **joelho e tornozelo** (pivôs próprios) e coxa mais musculosa.
  - **Cauda em dois segmentos** (`TailTip`).
  - Olhos maiores com **brilho** na pupila (cor por vértice).
- **Comparação:**

  | Modelo | Triângulos antes → depois | Malhas | Objetos de sombra |
  |---|---|---|---|
  | Selvagem | 1191 → 1235 (+4%) | 25 → 26 | 15 → 11 |
  | Carnotauro | 1245 → 1289 (+4%) | 27 → 28 | 17 → 11 |

  O custo de desenho no jogo caiu, porque menos partes projetam sombra.
- **Animação** (só apresentação):
  - **Passo pela distância:** a fase avança com velocidade ÷ passada, então o pé não desliza e a cadência
    acompanha a velocidade. Testado: 16,8 rad para 4,5 m, contra 16,8 esperados.
  - A perna em balanço dobra o joelho (−0,56 rad) e o tornozelo compensa. O corpo sobe no meio do apoio.
  - Parado, fica em pose de repouso, sem andar no lugar (testes antigos mantidos).
  - A cauda tem fase acumulada (sem salto quando a velocidade muda) e a ponta atrasada, como chicote.
  - O corpo inclina nas curvas reais.
  - O selvagem do menu anda com a cadência casada com a velocidade.
- **Facções preservadas:** jade e coleira no aliado, terracota no selvagem, máscara e colar no guardião,
  azul-violeta com espinhos no invasor.
- **Intocados:** IA, dano, colisão, instante do golpe e correções P0/P1 (`creature_motion` 32/32,
  `gameplay_stability` 15/15).

## E — Player

- **Chapéu de explorador:** aba enrolada dos lados, caída na frente, e copa vincada (fedora de
  expedição), a silhueta mais legível de cima.
- **Golpe:** o braço sai no mesmo instante do clique, segura e volta suave. Antes era um seno simétrico.
- **Passo:** cadência pela distância e leve balanço lateral.
- **Intocados:** collider, velocidade, alcance, dano, direção do ataque e controles (`player_facing` 37,
  `attack_direction` 9, `physics_contracts` 23).
- **Limite:** o Player não tem joelho (a perna é uma peça). A mudança é discreta nas capturas.

## F — Menu, inventário, HUD e fonte

- **Fonte:**
  - O título, os botões e os cabeçalhos usam **Lilita One**, embutida em `assets/fonts` com a licença
    **SIL OFL 1.1** e a atribuição (`OFL.txt`, `LEIA-ME.txt`, `docs/ac1/ASSETS.md`).
  - Importada como MSDF: fica nítida em qualquer tamanho.
  - Nada mais depende de fonte instalada no computador.
- **Menu:** o diorama ganhou a flora nova, e o selvagem ao fundo anda com o joelho dobrando.
- **Mochila e HUD:** revisadas nas três abas e em três resoluções. Não encontrei corte de texto nem
  sobreposição que justificasse mudar a estrutura, então mantive. Não acrescentei nada só para ocupar
  espaço.
- **O que segue igual:** o inventário não pausa (013D) e cliques não atravessam o painel
  (`inventory_ui` 26/26).

## G — Áudio

Detalhes em `docs/context/audio-auditoria.md`.

- **Música do menu:** o tema `refugio_principal.wav` (composição original que estava sem uso) agora toca
  no menu.
- **Efeitos originais** sintetizados por `tools/build_sfx.gd`, sem samples de terceiros:
  - hover e clique em todo botão;
  - coleta de madeira e de pedra;
  - construção;
  - disparo da torre;
  - rosnado na preparação da mordida;
  - trompa no início da onda;
  - ambientes de dia (vento e piados) e de noite (grilos).
- Cada efeito tem um intervalo mínimo próprio.
- **Testado automaticamente:** carregamento, barramento, intervalo, clique global, troca de ambiente e
  música.
- **Não ouvido:** não há ferramenta de audição aqui. A qualidade depende do seu ouvido.

## Testes (execuções reais)

| Execução | Resultado |
|---|---|
| Linha de base (`52ff985`), sem janela | 26/26 suítes, 798 checks, 0 falhas |
| Linha de base (`52ff985`), com janela | 27/27 suítes, 828 checks, 0 falhas |
| Final, sem janela (`--fixed-fps 60`) | **27/27 suítes, 825 checks, 0 falhas** |
| Final, com janela | **28/28 suítes, 855 checks, 0 falhas** |

- **Suíte nova `visual_overhaul4` (27 checks):** fonte embutida e licença; flora no menu; FloraArt sem
  corpo e fora da navegação; nós antigos ocultos mas presentes; orçamento de malhas e triângulos;
  nada solto entre 0,3 m e 1,9 m; trilhas e entradas livres; arte sobre cada colisor; cristais acesos à
  noite; copa coletável; rig (joelho, tornozelo, ponta da cauda); repouso parado; joelho dobrando; passo
  pela distância; IA e colisor intocados; sombra em 2 fatias; log de eventos raros mantido; 6 checks de
  áudio.
- **Regressão encontrada e corrigida durante a execução:** o ambiente do amanhecer, ligado a um sinal
  novo, quebrou o check "reinícios não acumulam conexões de dia" (`acceptance`). Movi a chamada para o
  handler que já existia. O teste não foi alterado.
- **Nenhuma expectativa de teste antigo foi alterada.**

## Desempenho

- **Método:**
  - `tests/perf_probe.tscn --live --audit`, janela 1280×720, sem vsync, 10 s por vista após 2 s de
    aquecimento.
  - "Antes" é uma cópia de `52ff985` com o mesmo medidor.
  - Rodadas alternadas: antes, depois, antes, depois.
- **Condições:** Intel Iris Xe (GL Compatibility), na tomada, **com o seu editor do Godot aberto** (não o
  fechei).
- **Amostra:**
  - Antes: 4 rodadas (r1–r4).
  - Depois: 2 rodadas (r7–r8), com o código final deste commit.
  - As rodadas intermediárias do "depois" (r1–r6 e duas sem áudio) mediram versões em ajuste e estão em
    `desempenho/`. Na cena mais pesada (onda de 10 + 3 aliados), o pior 1% delas variou de 57 a 72,
    por causa do pico isolado descrito nos limites.

| Vista | Pior 1% antes | Pior 1% depois | Média antes | Média depois | Chamadas antes → depois | Triângulos antes → depois |
|---|---|---|---|---|---|---|
| Menu principal | 65–71 | 74–75 | 198 | 226 | 428 → 257 | 64 mil → 76 mil |
| Padrão 12:00 | 100–113 | 120–121 | 178 | 205 | 943 → 247 | 105 mil → 115 mil |
| Padrão 17:30 | 117–139 | 160–166 | 221 | 255 | 884 → 240 | 100 mil → 111 mil |
| Padrão 21:00 | 115–125 | 146–149 | 200 | 237 | 628 → 205 | 89 mil → 109 mil |
| Refúgio 12:00 | 100–115 | 119–122 | 181 | 205 | 922 → 239 | 103 mil → 114 mil |
| Ponto oeste 21:00 | 116–118 | 142–143 | 191 | 231 | 918 → 247 | 103 mil → 111 mil |
| Vivo: dia com dinossauros | 68–74 | 114–116 | 158 | 190 | 1100 → 310 | 126 mil → 159 mil |
| Vivo: noite, 3 inimigos, 3 torres, aliado | 59–72 | 85–86 | 173 | 195 | 990 → 377 | 108 mil → 120 mil |
| Vivo: mochila aberta à noite | 103–106 | 118–119 | 156 | 180 | 1263 → 539 | 122 mil → 130 mil |
| Vivo: onda de 10, 3 torres | 54–65 | 77–79 | 142 | 159 | 1447 → 620 | 131 mil → 132 mil |
| Vivo: onda de 10 + 3 aliados | 49–56 | 66–67 | 146 | 165 | 1285 → 528 | 124 mil → 127 mil |
| Vivo: tutorial | 121–135 | 130–142 | 205 | 218 | 483 → 217 | 75 mil → 96 mil |

- Memória estática (onda de 10): 65 MB → 61 MB; vídeo: 40 MB → 38 MB.
- Carregamento: menu 1253 ms → 1297 ms; partida (JOGAR → 1º quadro) 142 ms → 233 ms.
- Pior quadro isolado (ms), noite com 10 + 3 aliados: antes 23,86 / 24,8 / 23,36 / 28,83; depois 24,21 / 28,37. Noite com 3 inimigos: antes 28,73 / 26,42 / 23,48 / 30,2; depois 31,81 / 35,9.

- **Meta de 60 FPS:**
  - **Média:** atingida em todas as vistas.
  - **Pior 1%:** atingido em todas as vistas nas duas rodadas finais (mínimo de 66 FPS, na onda de 10
    com 3 aliados). Antes, quatro cenas vivas ficavam entre 49 e 74, e três delas abaixo de 60 em alguma
    rodada.
- **O que ganhou:**
  - O log por golpe era o gargalo do pior 1%.
  - As sombras e os 226 nós soltos pesavam nas chamadas de desenho: −55% a −74%.
- **O que custou:**
  - Mais triângulos (flora detalhada): +10 a +30 mil.
  - +90 ms para abrir a partida (a flora tem 4 MB).
  - Mesmo assim, a GPU e a CPU de render caíram: na onda de 10, GPU 5,2 → 4,6 ms e CPU 4,4 → 3,5 ms;
    ao meio-dia, GPU 4,5 → 4,0 ms.
- **Física:** p99 dos scripts de física com dinossauros vivos caiu de 11,4 → 0,7 ms (dia) e de 12,5 →
    5,1 ms (onda de 10 + 3 aliados).

## Limites honestos e pendências

- **Pico isolado de ~50 ms:**
  - **Onde:** em 5 das 8 rodadas intermediárias do "depois" (versões em ajuste), um único quadro de
    ~50 ms numa cena noturna de combate, inclusive numa rodada com o áudio desligado.
  - **Nas 2 rodadas finais:** não apareceu (pior quadro de 36 ms; no "antes", até 30 ms).
  - **Descartado (medido):** criar e derrotar criaturas, log, fonte, áudio e compilação de efeitos.
  - **Suspeita:** algo externo, como o editor do Godot aberto ou o sistema operacional.
  - **Como fechar:** como a amostra é pequena, vale remedir com o editor fechado.
- **Editor aberto:** todas as medições foram feitas com o seu editor do Godot aberto (não o fechei), na
  tomada. O "antes" e o "depois" foram alternados nas mesmas condições.
- **Modelos:** continuam procedurais, sem esqueleto. Blender não instalado.
- **Áudio:** sons sintetizados, não ouvidos por mim; lista de produção final em `audio-auditoria.md`.
- **Capturas:**
  - O combate (k01, k02) é jogo rodando: a posição das criaturas difere entre antes e depois.
  - O c01 (Player de perto) herdou o enquadramento da 3.0, que esconde parte do chapéu atrás do braseiro.
    O turntable mostra melhor.

## Roteiro de playtest

1. **Floresta Oeste:**
   - Ande pela mata: ficou mais bonita e natural?
   - Você continua achando o Player e as trilhas com facilidade?
2. **Região Rochosa e Ruína:**
   - Lajes, cristais, glifos e colunas quebradas dão vontade de explorar?
   - À noite, os cristais acesos ajudam ou distraem?
3. **Dinossauros:**
   - O passo ficou natural, sem patinar? O joelho dobrando aparece de perto?
   - A cauda balança bem?
   - Ainda dá para distinguir as facções sem os rótulos?
4. **Player:** o chapéu novo e o golpe (sai rápido, volta suave) estão bons?
5. **Fonte:** o título e os botões com Lilita One agradam?
6. **Áudio** (o ponto mais importante a validar):
   - O tema do menu, os cliques, a coleta, a construção, a torre e o rosnado estão bons?
   - E a trompa da noite e os ambientes? Algum som incomoda ou está alto demais?
7. **Desempenho:** com o editor **fechado**, o combate noturno com 10 inimigos está fluido? Algum
   travamento perceptível?
8. **Mochila e HUD:** continuam legíveis, sem pausar o jogo?
