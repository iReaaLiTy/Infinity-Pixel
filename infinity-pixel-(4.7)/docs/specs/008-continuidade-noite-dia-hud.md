# 008 — Continuidade entre noite e dia + limpeza da interface de gameplay

Ciclo 1 — Núcleo Jogável (ajuste de fluxo e HUD pedido em 2026-10-03).

Complementa `006-ciclo-dia-noite.md` (RF-AGE-015): o estado continua voltando
a DIA quando a onda é vencida. O que muda é a **apresentação** dessa
passagem, que deixa de interromper o jogo. Também tira o tutorial permanente
da HUD e leva a lista de comandos para uma tela de Controles.

## Fora do escopo

- Ciclo automático de dia/noite (cronômetro). A transição DIA → NOITE
  continua manual (N), como na Spec 006.
- Mudanças na lógica de onda, contagem de ameaças, derrota, base, dano,
  domesticação, aliados ou câmera (Spec 007).
- Remapeamento de teclas: a tela de Controles é só informativa.
- HP, HUD de HP, morte e respawn do jogador.
- Navegação dos dinossauros (`NavigationAgent3D`, avoidance, rotas, correção
  de empilhamento), construção, recursos, save/load, novo mapa.

## Requisitos

### RF-UI-001 — Passagem NOITE → DIA sem interrupção

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-015, RF-AGE-011

Quando a última ameaça da noite é neutralizada, o estado global muda para
DIA, a iluminação volta ao dia pela transição normal e o jogo continua: a
árvore não é pausada, nenhum modal abre, nenhum clique é exigido, o jogador
anda imediatamente e os aliados continuam no mundo. Aparece só um aviso
pequeno e passageiro no topo da tela ("AMANHECEU · DIA • PREPARAÇÃO"), que
não bloqueia cliques e some sozinho.

**Critérios de aceitação**

- Dado que a última ameaça da noite é neutralizada, então o estado passa a
  DIA e a HUD mostra "DIA • PREPARAÇÃO".
- Dado que a noite foi vencida, então o jogo não pausa, não aparece "Noite
  defendida" nem o botão "Continuar no dia", e o jogador pode andar
  imediatamente.
- Dado que a noite foi vencida, então aliados domesticados continuam no
  mundo e o contador "Noites defendidas" aumenta.
- Dado que o aviso de amanhecer apareceu, então ele não captura cliques e
  some sozinho em cerca de 3 segundos.
- Dado que a base chega a 0 HP no mesmo quadro em que a última ameaça é
  neutralizada, então a derrota tem prioridade (comportamento já existente).

**Origem:** o modal de vitória quebrava o ritmo do core loop (preparar →
defender → preparar). O grupo quer que a noite termine e o dia comece sem
sair do jogo.

**Hipótese de protótipo — Aviso de amanhecer**
- **Valor inicial:** 2,5 s visível + 0,5 s de fade (`DAWN_TOAST_TIME`).
- **Pergunta do protótipo:** o aviso é notado sem atrapalhar?
- **Teto ou limite de exploração:** 2–3 s visível.

### RF-UI-002 — HUD de gameplay sem tutorial permanente

**Prioridade:** DEVE
**Status:** PROVISÓRIO

A HUD não mostra mais a linha permanente de comandos (WASD, mouse, clique,
E, F, N) nem dicas de tutorial fixas. Fica só um painel compacto, centralizado
embaixo, com o objetivo atual (curto). Ele também mostra uma dica de contexto
quando há um alvo ou aliado próximo (SEGURE E, CARNOTAURO, ALIADO x/80 HP) e a
barra de canalização só enquanto ela está em andamento. O painel cresce com o
texto e não ocupa a largura toda.

**Critérios de aceitação**

- Dado que o jogo está em andamento, então nenhuma lista de comandos aparece
  permanentemente na HUD.
- Dado que não há canalização, então a barra de canalização fica oculta.
- Dado que o jogador está perto de um aliado ou de um selvagem, então a dica
  de contexto aparece no painel compacto.

**Origem:** o painel inferior ocupava grande parte da tela com instruções
que o jogador só precisa consultar de vez em quando.

### RF-UI-003 — Tela de Controles no menu de pausa

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-UI-002

O menu de pausa ganha o botão "Controles", que abre uma tela informativa com
os comandos reais do jogo, em duas colunas (tecla — ação): WASD — Mover
(relativo à câmera); Mouse — Mirar; Clique esquerdo — Atacar na direção do
cursor; E (segurar 2 s) — Domesticar a até 3 m; F — Seguir/ficar (somente de
dia); N — Iniciar noite; ESC — Pausar/retomar. "Voltar" (ou ESC) retorna ao
menu de pausa, e o jogo continua pausado. O botão "Controles" do menu
principal usa a mesma lista.

**Critérios de aceitação**

- Dado que o jogo está pausado, quando o jogador escolhe "Controles", então a
  lista de comandos aparece e o jogo continua pausado.
- Dado que a tela de Controles está aberta pela pausa, quando o jogador
  escolhe "Voltar" ou aperta ESC, então volta ao menu de pausa.

**Origem:** as instruções saíram da HUD (RF-UI-002) e precisam continuar
acessíveis.

## Alternativas descartadas

- **Manter o modal de vitória sem pausar.** Descartado: continuaria cobrindo
  o centro da tela e exigindo clique para fechar.
- **Remover o painel inferior inteiro.** Descartado: objetivo, dicas de
  contexto (HP do aliado, "Segure E") e barra de canalização são informação
  de estado útil, e os rótulos 3D ficaram pequenos com a câmera da Spec 007.

## Perguntas em aberto

- O "ESC PAUSA" no canto superior direito deve continuar?
- O aviso de amanhecer deve ter som próprio? Hoje toca o jingle de vitória já
  existente.

## Não aplicável a este jogo

*Nenhuma.*
