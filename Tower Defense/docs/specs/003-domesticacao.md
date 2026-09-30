# 003 — Domesticação

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Comida ou itens específicos de domesticação — fica para ciclos futuros.
- Porcentagem de afinidade — fica para ciclos futuros.
- Múltiplos métodos de domesticação — Ciclo 1 tem apenas um método.

## Requisitos

### RF-AGE-005 — Enfraquecimento como pré-condição

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-002

O dinossauro domesticável só pode ser domesticado depois de ter sua vida
reduzida até um limiar mínimo.

**Critérios de aceitação**

- Dado que o dinossauro domesticável está com vida acima do limiar, quando o
  jogador se aproxima, então a opção de domesticação não aparece.
- Dado que o dinossauro domesticável está com vida igual ou abaixo do
  limiar, quando o jogador se aproxima, então a opção de domesticação
  aparece.

**Origem:** o grupo quer que a domesticação exija esforço prévio de combate,
não ser trivial.

**Hipótese de protótipo**
- **Valor inicial:** 30% de vida restante
- **Pergunta do protótipo:** 30% exige esforço de combate sem deixar o dinossauro perto demais de morrer antes da domesticação?
- **Teto ou limite de exploração:** entre 20% e 40%. Abaixo de 20% o dinossauro fica perto demais de ser derrotado antes de domesticar; acima de 40% a domesticação pode ficar fácil demais.

### RF-AGE-006 — Canalização da domesticação

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-005

Com a opção de domesticação disponível, o jogador segura a tecla E por um
tempo de canalização contínuo para completar a domesticação. Afastar-se do
dinossauro durante a canalização cancela o processo, exigindo reinício.

**Critérios de aceitação**

- Dado que a opção de domesticação está disponível, quando o jogador segura
  E pelo tempo de canalização completo sem se afastar, então o dinossauro
  se torna aliado do jogador.
- Dado que o jogador está canalizando a domesticação, quando ele se afasta
  do dinossauro antes de completar o tempo, então a canalização é cancelada
  e precisa recomeçar do zero.
- Dado que a domesticação foi concluída, quando ela termina, então o
  dinossauro deixa de atacar o jogador e passa a agir como aliado.

**Origem:** domesticação simples e não instantânea, sem itens ou múltiplos
métodos no Ciclo 1.

**Hipótese de protótipo**
- **Valor inicial:** 2 segundos de canalização
- **Pergunta do protótipo:** 2 segundos dá peso à ação sem tornar a domesticação frustrante?
- **Teto ou limite de exploração:** até 4 segundos nesta rodada.

### RF-AGE-017 — Propriedade `is_domesticable` bloqueia elegibilidade

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-005

Cada dinossauro selvagem possui uma propriedade explícita e configurável,
`is_domesticable` (verdadeiro/falso), independente do HP. Quando
`is_domesticable` é falso, o dinossauro nunca fica elegível para
domesticação, mesmo com a vida no limiar ou abaixo dele (RF-AGE-005): a
opção de domesticação nunca aparece, segurar E não inicia canalização, e o
dinossauro permanece hostil (pode atacar o jogador e a base) até ser
derrotado. A checagem consulta essa propriedade diretamente — nunca o nome
do node, o nome da cena, nem um `if` manual por tipo espalhado pelo código.

Para validar a regra neste Ciclo 1, existem duas variantes configuradas do
mesmo tipo de dinossauro selvagem (mesma IA, RF-AGE-003/004): uma com
`is_domesticable = true` (a existente) e uma segunda apenas para teste, com
`is_domesticable = false`, sem investimento em arte final — pode reaproveitar
a base visual atual com uma variação simples (ex. cor) só para ficar
identificável no playtest.

**Critérios de aceitação**

- Dado que `is_domesticable` é verdadeiro e o HP está no limiar ou abaixo
  (RF-AGE-005), então a opção de domesticação aparece e segurar E inicia a
  canalização (RF-AGE-006).
- Dado que `is_domesticable` é falso, quando o HP chega ao limiar ou abaixo,
  então a opção de domesticação não aparece e segurar E não inicia
  canalização.
- Dado que `is_domesticable` é falso, então o dinossauro só deixa de ser
  ameaça ao ser derrotado (morte normal), nunca por domesticação.

**Origem:** a distinção domesticável/não domesticável é requisito confirmado
do núcleo do jogo; criar a propriedade sem nenhum caso `false` deixaria a
regra sem validação real no MVP. O grupo não quer várias espécies, árvore de
progressão ou dados complexos agora — só o mínimo para provar a regra, com
arquitetura pronta para novas espécies em ciclos futuros.

## Alternativas descartadas

*Nenhuma registrada nesta spec.*

## Perguntas em aberto

- Nome/identidade definitiva da variante não domesticável (usado
  provisoriamente "Carnotauro" como placeholder de teste, sem arte final) —
  decisão de conteúdo a confirmar quando o jogo tiver mais espécies.

## Não aplicável a este jogo

*Nenhuma.*
