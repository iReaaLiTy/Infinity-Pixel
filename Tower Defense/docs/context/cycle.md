# Estado do Ciclo

## Ciclo atual

**Ciclo 1 — Núcleo Jogável**

## Objetivo / pergunta do ciclo

O jogador consegue realizar a ação principal? Provar o menor recorte jogável
do core loop: preparar de dia (explorar, domesticar, posicionar defesa) →
iniciar a noite → enfrentar uma onda (com dinossauros hostis mais fortes) →
vencer ou perder. Ver detalhes em `game-overview.md`, seção "Primeiro
incremento".

## Specs selecionadas para este incremento

| Spec | Sistema | Status |
|---|---|---|
| 001-controle-jogador | Movimento e ataque básico do personagem | implementada, playtest aprovado (2026-09-18) |
| 002-dinossauro-selvagem | Comportamento e ataque do dinossauro selvagem inimigo | implementada, playtest aprovado (2026-09-18) |
| 003-domesticacao | Condição e processo de domesticação (inclui `is_domesticable`, RF-AGE-017) | implementada, playtest aprovado (2026-09-25, após correção) |
| 004-dinossauro-domesticado | Comportamento do dinossauro domesticado, posicionamento e combate | implementada, aguardando playtest manual (seguir/ficar/defesa por área) |
| 005-onda-e-vitoria | Disparo da onda, condição de vitória e de derrota | implementada, aguardando playtest manual (timing real da onda) |
| 006-ciclo-dia-noite | Estados DIA/NOITE, transição manual, buff noturno, fim de sessão | implementada e validada headless (estados/buff/derrota); playtest manual pendente para o fluxo completo em jogo |

## Status do ciclo

EM ANDAMENTO — Specs 001–006 implementadas. 001/002/003 validadas em
playtest manual; 004/005/006 verificadas por chamadas diretas headless
(`godot --headless --script`, 27/27 checks OK) mas ainda sem playtest manual
no editor, que é o único jeito de validar fisica de movimento (seguir/ficar/
defesa por área) e o ritmo real da onda/buff em jogo. Ver
`progress-tracker.md`, "Como testar a Unidade 4".

## Evidências do playtest

- Unidade 1 (Spec 001), 2026-09-18: mecânica validada (movimento, câmera,
  ataque com dano). Primeira rodada falhou no ataque; corrigido e reaprovado.
  Sensação dos valores ainda não avaliada.

## Motivo do avanço para o próximo ciclo

Ainda não aplicável — Ciclo 1 só avança para o Ciclo 2 depois que o
incremento for implementado e validado em playtest (defesa da base
funcionando, domesticação funcionando, onda vencível e perdível).
