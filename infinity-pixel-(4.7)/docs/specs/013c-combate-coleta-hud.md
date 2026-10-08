# 013C — Combate, coleta, dinos diurnos e HUD compacta

Ciclo 1 — Núcleo Jogável. Etapa de polimento e expansão pedida em
2026-10-04, **depois do playtest da 013B e antes da Spec 014**.

**Por que existe:** no playtest da 013B:
- o primeiro clique no dinossauro nem sempre causava dano;
- o golpe precisava passar para 15;
- o domesticado deveria voltar com a vida cheia;
- faltava um segundo encontro diurno;
- o alcance das torres não era visível;
- o posto com o texto 3D "POSTO DE DEFESA" parecia debug;
- a HUD estava grande demais;
- a exploração não tinha coleta real (árvores e pedras eram só cenário).

Implementada; **aprovada manualmente pelo usuário em 2026-10-04**.

## Fora do escopo

- Spec 014 (céu e iluminação).
- Uso de Madeira/Pedra em construção ou crafting. As torres continuam
  custando só Pontos de Defesa.
- Mudança no ciclo (90/45/20/10 s), nas ondas (3 + noite − 1), nos atributos
  das criaturas, nos valores das torres ou na vida/respawn do Player.

## Requisitos

### RF-CMB-001 — Golpe do Player = 15

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** o valor de 20 da RF-AGE-002

`player.gd` tem uma única constante, `ATTACK_DAMAGE = 15`, que vale para
criaturas e recursos. O WildDino continua com 80 HP: 80 → 65 → 50 → 35 →
**20**, e em 20/80 é elegível (limite de 30% mantido).

### RF-CMB-002 — Um clique = um golpe (causa do "clique duplo")

**Prioridade:** DEVE
**Status:** PROVISÓRIO

**Causa, reproduzida com cliques reais:**
- Com o dino já no alcance (~2 m), o primeiro clique acertava 8/8 e 18/18
  vezes, em vários ângulos.
- O jogador clica quando o dino **parece** colado, a ~3 m, um pouco antes de
  entrar no alcance. Esse golpe acertava o vazio e **iniciava o cooldown de
  0,8 s mesmo sem acertar**.
- O dino chegava em ~0,3 s, e o clique seguinte, já no alcance, caía no
  cooldown e era **descartado em silêncio**. Dano em **0/8** tentativas;
  só o terceiro clique acertava.

**Risco de golpe duplo encontrado na auditoria:** quando a mira girava mais
de 0,1 rad, o golpe esperava 2 quadros de física **antes** de iniciar o
cooldown. Um segundo clique nessa janela gerava outro golpe.

**Correções:**
1. **Golpe resolvido no próprio clique:** mira → consulta de forma
   imediata com a caixa da `AttackArea3D` na rotação atual → dano. Não
   depende mais da sobreposição do passo anterior e não espera quadros.
2. **Mira no corpo clicado:** um raio da câmera pelo cursor contra criaturas
   e recursos. Projetar no chão um clique feito no corpo do dino desviava a
   mira em 14–29°.
3. **Golpe no vazio recupera em 0,3 s** (`WHIFF_COOLDOWN`); o golpe que
   acerta mantém 0,8 s.
4. **Buffer de um clique:** um clique feito nos últimos 0,35 s do cooldown
   fica guardado e sai **uma vez** quando o cooldown acaba, mirando no mesmo
   alvo. Cliques em excesso durante o cooldown são ignorados (proteção contra
   spam).

**Critérios de aceitação**

- Dado o dino no alcance, quando o jogador clica uma vez, então ele perde 15.
- Dado dois cliques no mesmo quadro, então há um golpe só.
- Dado um clique com o dino a 3,4 m e outro logo depois com ele a 1,6 m,
  então há 2 golpes, sendo 1 com dano. O segundo clique não se perde.

### RF-CMB-003 — Domesticação restaura a vida

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** "mantém a vida atual" (RF-AGE-006)

`domesticate()` faz `hp = MAX_HP` (80) **uma vez**, na transição de
selvagem para aliado; chamar de novo não tem efeito. Depois disso, o aliado
perde vida normalmente. Não há regeneração contínua.

### RF-CMB-004 — Dois encontros diurnos

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-MAP-005

O `EncounterSpawner` mantém **um WildDino territorial por ponto**:
- a clareira das criaturas (bosque, −10, 10);
- `extra_spawn_points` = (13, 22), a `DistantTerritory` da Spec 012, na
  região rochosa. Os dois ficam a ~26 m um do outro.

Usa a mesma cena, IA e domesticação; não existe implementação nova.

A cada amanhecer, só o ponto cujo encontro deixou de ser selvagem
(domesticado ou morto) ganha um novo. Aliados continuam no mundo e não há
acúmulo.

Os encontros não pertencem à onda: não contam, não impedem o amanhecer e
**não dão Pontos de Defesa**.

### RF-CMB-005 — Pontos iniciais = 40

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** os 30 da RF-ECO-001

`DefenseEconomy.starting_points = 40`. O resto da economia não muda: torre
30/30/45 e +15 por inimigo da onda morto.

### RF-CMB-007 — Alcance visível das torres

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Anel:** fino (12 cm), translúcido, sem sombra, rente ao chão
  (`range_ring.gd`).
- **Raio:** gerado com o valor **exato** em metros, o mesmo `stats().range`
  usado pela busca de alvo: 8 / 9 / 10 m. É atualizado no upgrade.
- **Visibilidade:**
  - forte (0,8) quando o Player interage com a torre;
  - média (0,45) quando está perto do alcance;
  - discreta (0,12) de longe.
- **Prévia:** no ponto vazio em foco, mostra o alcance da futura L1
  (`DefenseTower.LEVELS[0].range` = 8 m).

### RF-CMB-008 — Pontos de construção sem texto de debug

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **O texto removido:** o "POSTO DE DEFESA" era o Label3D `PostLabel` do
  **posto antigo do AC1**, o octógono em (0, −7), e não dos pontos de
  construção. Ele foi removido da arte, e o gerador do mapa não o recria.
- **O octógono:** continua como marco, sem texto.
- **Pontos de construção:** ganharam um losango verde-água gravado e um
  cristal maior.
- **Painel do ponto vazio:** "PONTO DE CONSTRUÇÃO · Torre de Defesa · Custo:
  30 · [C] CONSTRUIR".

### RF-COL-001 — Madeira e Pedra (estoque)

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Fonte de verdade:** `ResourceStock` (nó do mundo), com `add(kind,
  amount)`, `get_amount(kind)` e o sinal `resources_changed`.
- **Responsabilidades separadas:** Pontos de Defesa vêm do combate e das
  ondas; Madeira e Pedra vêm da coleta.
- **Persistência:** os recursos persistem entre dias e só zeram ao reiniciar.

### RF-COL-002 — Árvores e pedras coletáveis

**Prioridade:** DEVE
**Status:** PROVISÓRIO

| Recurso | Quantidade | HP | Golpes (15) | Recompensa | Onde |
|---|---|---|---|---|---|
| Árvore | 8 | 30 | 2 | +10 Madeira | Bosque oeste |
| Pedra | 6 | 45 | 3 | +6 Pedra | Região rochosa |

**Visual:**
- **Árvores:** mais baixas, com copa verde-limão mais quente e um corte claro
  no tronco.
- **Pedras:** blocos com veios azul-acinzentados e âmbar.

**Coleta:** o golpe normal (clique, mira, alcance da caixa do ataque). Não há
tecla própria, e longe não alcança.

**Feedback:**
- **Golpe:** tremida e "aperto"; a pedra solta 3 lascas.
- **Esgotou:** a árvore tomba e some; a pedra estoura em lascas e some.
- **HUD:** "+10 MADEIRA" / "+6 PEDRA" por ~1 s.

**Pagamento:** só uma vez. A marca de esgotado é definida antes de pagar, e
golpes depois disso são ignorados.

**Pontos de Defesa:** recursos não dão Pontos de Defesa.

### RF-COL-003 — Física e navegação dos recursos

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-FIS-001, RF-NAV-001

- **Corpo:** sólido na camada 1 (bloqueia Player e criaturas) mais a camada 5
  ("interações", reservada na Spec 009) para o golpe.
- **Navmesh:** os recursos **não entram na navmesh**, que é assada offline só
  com o grupo `navigation_source`.
  - A IA desvia deles pelo `NavigationObstacle3D` (avoidance).
  - Ao esgotar, o corpo e o obstáculo são desligados; ao restaurar, voltam.
  - **Não há rebake** e não há buraco permanente.
- **Posição:** fora das trilhas e das rotas noturnas (verificado em teste) e
  longe das clareiras de combate.

### RF-COL-004 — Volta no amanhecer

**Prioridade:** DEVE
**Status:** PROVISÓRIO

- **Quando:** o recurso esgotado fica assim pelo resto do dia e da noite, e
  volta no **amanhecer seguinte**, com o mesmo nó, HP cheio, corpo e
  visual (14 nós, nunca duplicados).
- **Como detecta o amanhecer:** compara o `day_number` do `DayNightManager`
  e só verifica enquanto está esgotado. Ele não assina `day_started`, para
  não somar conexões ao autoload; o acceptance verifica que reiniciar não
  acumula conexões.

### RF-HUD-001 — HUD compacta em três grupos

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Substitui:** a faixa superior da RF-CIC-004 / RF-VID-006 / RF-ECO-007

- **Esquerda:** "JOGADOR 100 / 100" e "REFÚGIO 100 / 100" em 13 px, com
  barras de 6 px.
- **Centro:** "DIA 1 • 08:58" em 17 px e "PREPARAÇÃO · Noites: 0" em 12 px.
  À noite, "NOITE N • hh:mm", "DEFESA · Noites: N" e "criados ·
  neutralizados · ativos"; a contagem "ANOITECE EM N" aparece abaixo.
- **Direita:** ◆ Pontos (DEFESA), Madeira e Pedra, com ícone, número e
  legenda curta. "ESC pausa" fica pequeno, abaixo.
- **Painéis:** margens de 12 × 6 px; os três grupos ficam separados (não é
  mais uma barra contínua).
- **Ganhos:** "+15 PONTOS", "+10 MADEIRA" e "+6 PEDRA" aparecem por ~1 s
  abaixo do grupo da direita, sem sair da tela e sem mudar o painel.
- **Comparação em 1920×1080** (capturas antes/depois em
  `../validation/spec013c-evidence/views/`): a altura ocupada no topo caiu
  de ~205 px para ~125 px, e o centro da tela ficou livre.

## Testes

- **`tests/combat_collect.tscn`:** 46 checagens com cliques reais, cobrindo
  os itens A–AN.
- **Ferramentas de captura com janela:** `tests/collect_showcase.tscn` e
  `tests/hud_showcase.tscn`.
- Detalhes em `../validation/spec013c.md`.

## Alternativas descartadas

- **Executar dois ataques por clique.** Proibido, e mascararia a causa.
- **Aumentar o alcance do golpe.** Mudaria o balanceamento; o problema era o
  clique perdido, não o alcance.
- **Rebake da navmesh ao esgotar recursos.** Caro e desnecessário: o
  avoidance e o posicionamento fora das rotas resolvem.
- **Transformar todas as árvores do mapa em recurso.** Mudaria colisões e
  navmesh da Spec 012; foram criados 14 coletáveis dedicados.

## Perguntas em aberto

- O octógono do posto antigo (0, −7), agora sem texto, deve virar um ponto de
  construção ou sair do mapa?
- Quanto Madeira/Pedra a próxima etapa de construção vai exigir?
- O buffer de 0,35 s é perceptível como "resposta", ou deve ser menor?

## Não aplicável a este jogo

*Nenhuma.*
