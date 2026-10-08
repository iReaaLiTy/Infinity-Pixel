# 013D — Inventário, construção com recursos e cura

Ciclo 1 — Núcleo Jogável. Pedida em 2026-10-04/05, depois da aprovação
manual da 013C e antes da Spec 014.

**Por que existe:** Madeira e Pedra (013C) eram só números. A 013D dá uso
real a elas com:
- um inventário simples;
- a **fundação** da construção (receita → fantasma → validação →
  posicionamento);
- duas estruturas que **não alteram a navegação**: Fogueira de Cura e
  Armadilha de Espinhos.

Loop: explorar → coletar → inventário → escolher → posicionar → noite (torres
+ armadilhas + aliados + cura) → amanhecer → coletar de novo.

Implementada; **aprovada manualmente (playtest de 2026-10-06)**.

## Fora do escopo

- Spec 014, céu e clima.
- Paredes, cercas, casa, portão, baú, venda e reparo de estruturas (paredes
  mudariam navmesh, rotas e alvos; ficam para a próxima expansão).
- Novos recursos, crafting complexo, bancada, árvore tecnológica, receitas
  desbloqueáveis, equipamento, armas, save/load.
- Mudança nos valores já aprovados:
  - Player 100 HP e golpe 15;
  - WildDino 80, domesticação 20 → 80;
  - ciclo 90/45 s;
  - coleta 30/45 HP (+10/+6);
  - 40 Pontos de Defesa e +15 por inimigo;
  - torres em Pontos de Defesa.

## Separação de moedas

| Moeda | Fonte | Uso |
|---|---|---|
| Pontos de Defesa | inimigos da onda (+15) | torres e upgrades (`DefenseSlots`, tecla C) |
| Madeira + Pedra | coleta (013C) | estruturas do Player (`BuildPlacer`, teclas B/I) |

## Requisitos

### RF-INV-001 — Inventário (tecla I)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Teclas:** I estava livre (em uso: WASD, clique esquerdo, E, F, C, T/N
  de depuração e ESC).
- **Abrir:** abre/fecha um painel compacto à direita, abaixo do grupo de
  recursos. **Não pausa o mundo** (inclusive à noite) e o topo da HUD
  aprovado na 013C não cresce.
- **Conteúdo:**
  - MADEIRA e PEDRA, com ícones e números;
  - CONSTRUÇÕES: cada receita com nome, custo (ícones) e [CONSTRUIR];
  - motivo de bloqueio: "Recursos insuficientes", "LIMITE ATINGIDO" ou
    "Disponível durante o dia".
- **Atualização:** os números mudam **pelo sinal** `resources_changed` do
  `ResourceStock`, no mesmo quadro. Os motivos de bloqueio são revistos só
  enquanto o painel está aberto.
- **ESC:** fecha posicionamento e painéis **antes** de abrir a pausa.

### RF-INV-002 — Fonte única e gasto atômico

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Fonte única:** o `ResourceStock` (013C) continua sendo a **única**
  contagem de Madeira e Pedra; não há cópia no inventário.
- **Métodos novos:** `can_afford_resources(wood, stone)` e
  `spend_resources(wood, stone)`.
- **Gasto atômico:** ou paga tudo, ou não paga nada. Nunca fica negativo.
- **Sinal:** cada recurso gasto emite `resources_changed` com delta
  negativo.

### RF-CON-001 — Receitas

**Prioridade:** DEVE
**Status:** PROVISÓRIO

As receitas estão em `scenes/world/build_recipes.gd`, a fonte única de
custo, limite, zona, raio e script.

| Estrutura | Madeira | Pedra | Limite | Zona |
|---|---|---|---|---|
| Fogueira de Cura | 20 | 12 | 1 | BuildZone (base) |
| Armadilha de Espinhos | 15 | 6 | 3 ativas | sobre as rotas noturnas |

Uma estrutura futura (cerca, portão, etc.) é só mais uma entrada nessa
tabela.

### RF-CON-002 — Modo construção (fundação reutilizável)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

O `BuildPlacer` (`scenes/world/build_placer.gd`) é um nó do mundo, o
último da árvore, para receber o clique antes do Player.

1. **Abrir:** **B** abre/fecha o menu CONSTRUIR. A receita também pode ser
   escolhida pelo inventário.
2. **Fantasma:** é a própria estrutura em modo `preview` (só visual),
   translúcida e com uma **pegada no chão** do tamanho real da área ocupada,
   verde se válida e vermelha se não. Ela segue o cursor no
   chão.
3. **Girar:** **R** gira 90°.
4. **Confirmar:** **clique esquerdo** confirma. O evento é consumido e o
   Player também ignora o clique enquanto `is_placing()`, então não há
   ataque.
5. **Cancelar:** **clique direito** ou **ESC** cancela sem gastar.
6. **Pagar:** a validação roda de novo e o pagamento só acontece ao
   confirmar, de forma atômica. Aparece "FOGUEIRA CONSTRUÍDA" ou
   "ARMADILHA CONSTRUÍDA", sem modal.
7. **Painel:** embaixo, "POSICIONANDO: …" com as teclas e o motivo, quando
   inválido.

**Teclas:** B, R e H estavam livres.

### RF-CON-003 — Validação do posicionamento

**Prioridade:** DEVE
**Status:** PROVISÓRIO

Uma posição é recusada, com o motivo exibido, se:
- **for noite:** "Construa durante o dia" (e o posicionamento em
  andamento é cancelado ao anoitecer);
- **o limite foi atingido;**
- **estiver fora da zona:**
  - Fogueira: dentro do retângulo da `SafeZone/BuildZone` (8 × 10 m em
    7, −15);
  - Armadilha: a até 2 m da linha central de uma das 3 `NightRoutes`
    (estrada da Ruína, trilha Oeste, trilha Leste);
- **estiver a < 3 m do refúgio;**
- **estiver a < 1,9 m de um ponto de defesa** (vazio ou com torre);
- **sobrepuser outra estrutura** (raios somados);
- **houver sólido ou corpo no cilindro da estrutura:** árvores, pedras,
  coletáveis, refúgio, torres, Player ou dinos (consulta de forma);
- **estiver fora do chão navegável.**

### RF-CON-004 — Fogueira de Cura

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Custo e limite:** 20 Madeira + 12 Pedra, **no máximo 1**.
- **Visual low-poly:** anel de 8 pedras, 3 toras cruzadas, chama em camadas
  (com tremulação) e luz quente.
- **Física:** sólido pequeno (raio 0,7, camada 4) + `NavigationObstacle3D`
  só de avoidance. Fica na BuildZone, fora das rotas, e não muda a navmesh.

### RF-CON-005 — Cura canalizada

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-VID-001

- **Uso:** **segurar H** (ação `heal_interact`) a até **2,5 m**, por **3 s**,
  dá **+25 HP** sem passar de 100 (`Player.heal`).
- **HUD:** "FOGUEIRA · Segure H para curar (+25) · Cargas N/2", a barra
  "CURANDO… x / 3,0 s" e o aviso "CURADO +25".
- **Cancela sem cura parcial** quando o Player:
  - sai do alcance;
  - sofre dano;
  - morre;
  - ataca;
  - solta H;
  - ou quando o jogo pausa (`NOTIFICATION_PAUSED`: ao despausar com H
    ainda segurado, a canalização recomeça do zero).

  Domesticação e posicionamento de construção impedem de começar **e
  cancelam uma cura já em andamento**. Recomeçar exige uma canalização
  completa nova. Remover a Fogueira interrompe a cura sem efeito atrasado.
  Mover dentro dos 2,5 m é permitido; sair desse alcance cancela.
- **Cargas:** 2 por ciclo; cada cura completa gasta 1. No **amanhecer**
  voltam a 2, sem acumular (compara o `day_number` do `DayNightManager`).
- **Recarga:** 25 s depois de cada cura ("Recarregando N s"), em tempo de
  jogo, e pausa com o jogo.
- **Recusa sem gastar nada:** Player morto ("Indisponível"), 100/100 ("Vida
  cheia"), em recarga ou sem cargas ("Sem cargas até amanhecer").
- **Uso noturno:** **pode usar à noite** (recuar, arriscar, voltar).
- **O que não faz:** não revive, não cura refúgio, dinos ou torres. O
  respawn não mudou.

### RF-CON-006 — Armadilha de Espinhos

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Custo e limite:** 15 Madeira + 6 Pedra, **no máximo 3 ativas** (1 por
  rota, por exemplo).
- **Visual low-poly baixo** (menos de 0,4 m): estrado de tábuas, 9 pontas e 4
  pedras de apoio.
- **Detecção:** `Area3D` com máscara de criaturas. **Sem corpo sólido e sem
  obstáculo de navegação.**
- **Alvo:** só inimigos válidos da **onda**, pelo mesmo filtro das torres
  (`DefenseTower.is_valid_target`). Nunca Player, aliado, domesticado,
  selvagem diurno ou refúgio.
- **Dano:** **15** por ativação.
  - **1 golpe por inimigo por passagem:** só volta a ferir depois que o
    inimigo sai da área.
  - **Intervalo de 0,35 s entre ativações:** dois inimigos que entram no
    mesmo quadro levam um golpe agora e o outro depois do intervalo.
- **Feedback:** as pontas saltam a cada ativação.

### RF-CON-007 — Cargas e duração da armadilha

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Cargas:** 3; cada ativação gasta 1 (até 45 de dano).
- **Esgotada:** na terceira ativação ela achata, some e libera o limite.
- **Entre dias:** com cargas, continua nos dias seguintes. Sem reparo nem
  recarga nesta versão.

## Navegação (Specs 009/010/012)

- **Sem rebake:** a navmesh continua assada offline; nenhuma construção faz
  rebake.
- **Armadilha:** não tem corpo nem obstáculo. Os inimigos passam **por cima**
  (verificado: o inimigo da Ruína cruza a armadilha da estrada, leva 15 e
  chega ao refúgio).
- **Fogueira:** obstáculo de avoidance pequeno, restrito à BuildZone, longe
  das rotas.

## Reiniciar

Estruturas, recursos e cargas vivem na cena do mundo, então Reiniciar volta
a:
- Madeira 0, Pedra 0, 40 Pontos;
- sem Fogueira, armadilhas ou torres;
- recursos do mapa cheios;
- Dia 1, 08:00.

## Balanceamento esperado

- **Por dia:** ~80 Madeira (8 árvores) e ~36 Pedra (6 pedras) no mapa.
- **Fogueira + 1 armadilha:** 35 Madeira + 18 Pedra, cerca de 4 árvores + 3
  pedras.

Não dá tempo de coletar tudo em 90 s: o jogador escolhe.

## Testes

- **`tests/build_heal.tscn`:** 68 checagens, cobrindo os itens A–AV, "pausar cancela a cura" e uma
  partida curta (coleta 40/18 → Fogueira + Armadilha → sobra 5/0 → noite:
  ferido, cura +25, armadilha −15, torre atacando → amanhecer).
- **`tests/build_showcase.tscn`:** ferramenta de captura com janela.
- **`tests/healing_actions.tscn`:** 7 verificações complementares de ações
  incompatíveis iniciadas durante a cura e remoção da Fogueira. Mantidas as
  68 verificações originais de `build_heal`, sem enfraquecer critérios.
- Detalhes em `../validation/spec013d.md`.

## Alternativas descartadas

- **Contagem própria no inventário.** Duplicaria a fonte; a HUD só lê o
  `ResourceStock`.
- **Cura instantânea por tecla.** Contra o pedido de recuar, parar e
  arriscar.
- **Armadilha com colisão ou obstáculo.** Bloquearia ou desviaria a rota;
  a ideia é que o inimigo pise nela.
- **Assinar `day_started` por estrutura.** Somaria conexões ao autoload, o
  que o acceptance verifica. Comparar `day_number` dá o mesmo resultado.

## Perguntas em aberto

- A cura de +25 com 2 cargas é suficiente na Noite 3 em diante?
- Armadilhas esgotadas deveriam poder ser recarregadas por uma fração do
  custo?
- A BuildZone (8 × 10 m) basta quando vierem casa, cercas e estruturas de
  criaturas?

## Não aplicável a este jogo

*Nenhuma.*
