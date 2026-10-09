# Propostas de game design e progressão (para aprovação — NÃO implementadas)

Data: 09/10/2026. Escritas depois do playtest da reformulação "Vale de Jade".
São **sugestões**: nenhuma regra, custo, moeda ou composição de onda foi
alterada por este documento. (O conteúdo exato das propostas G1–G6 discutidas
antes não está registrado no repositório; estas são propostas novas, P1–P6,
sobre os temas pedidos.)

Base numérica (medida por `tests/combat_balance` depois do balanceamento):
o jogador enfraquece um selvagem perdendo ~30 de vida; 1 aliado vence 1
inimigo noturno; a primeira noite com 1 torre + 1 aliado é vencida com o
Refúgio intacto; 3 inimigos noturnos sem apoio derrubam o jogador em 6–9 s.

## Problema de design observado

O ciclo EXPLORAR → COLETAR → DOMESTICAR → CONSTRUIR → DEFENDER existe, mas o
"EVOLUIR" é fraco: depois da Fogueira, das 3 armadilhas e de algumas torres,
as noites ficam parecidas e não há objetivo de longo prazo. O Refúgio
danificado não se recupera, e os territórios dão só área de construção.

## P1 — Reparo do Refúgio (baixo risco)
- De dia, segurar **E** no cristal: +10 de vida do Refúgio por 5 Madeira +
  3 Pedra (até o máximo). Dá uso à coleta entre as noites e um motivo para
  voltar à base.
- Teste: Refúgio a 60 → 4 reparos → 100; nunca passa do máximo; bloqueado à
  noite.

## P2 — Melhorias de defesa com Madeira/Pedra (médio)
- Torre nível 2/3 passa a custar Pontos **+** materiais (ex.: 30 PD + 10 Pedra).
  Liga a economia de coleta à de defesa (hoje separadas).
- Risco: deixa a melhoria mais cara; reavaliar com `combat_balance`.

## P3 — Recompensa territorial (médio)
- Território controlado rende, a cada amanhecer, +5 Madeira (Floresta Oeste)
  ou +4 Pedra (Região Rochosa), entregues no marco (segurar E). Recompensa a
  exploração sem renda passiva automática.

## P4 — Variante de inimigo: "Saltador" (alto — exige arte e testes)
- A partir da Noite 3: menor (55 de vida), mais rápido (5,5 m/s), mordida
  fraca (10), ignora aliados e corre para o Refúgio. Obriga a usar armadilhas
  nas trilhas e torres de alcance. Reaproveita o modelo do dino em escala 0,8.

## P5 — Noite especial a cada 3 dias (médio)
- "Lua Violeta": os inimigos chegam por uma única entrada (anunciada no
  entardecer com as runas daquela entrada piscando). Varia o planejamento
  sem novas regras de combate.

## P6 — Objetivo de longo prazo (alto)
- Campanha de 7 noites com uma "Noite do Guardião Ancestral" no fim; marcos
  de progresso (noites, territórios, aliados) mostrados no menu de pausa;
  precisa de salvamento (ver `roadmap-steam.md`).

## Ordem sugerida
P1 → P3 → P2 (economia), depois P5, e só então P4/P6 (conteúdo novo). Cada
uma deve vir com Spec própria, testes e playtest.
