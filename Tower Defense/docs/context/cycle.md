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
| 003-domesticacao | Condição e processo de domesticação (inclui `is_domesticable`, RF-AGE-017) | reaberta em 2026-09-30; correções técnicas implementadas, novo playtest humano pendente |
| 004-dinossauro-domesticado | Comportamento do dinossauro domesticado, posicionamento e combate | implementada, aguardando playtest manual (seguir/ficar/defesa por área) |
| 005-onda-e-vitoria | Disparo da onda, condição de vitória e de derrota | implementada, aguardando playtest manual (timing real da onda) |
| 006-ciclo-dia-noite | Estados DIA/NOITE, transição manual, buff noturno, fim de sessão | implementada e validada headless (estados/buff/derrota); playtest manual pendente para o fluxo completo em jogo |

## Status do ciclo

EM ANDAMENTO — Specs 001–006 têm implementações, com lacunas documentadas
(por exemplo, HP/respawn do Player). 001/002 mantêm aprovação histórica.
A Unidade 3 foi reaberta por solicitação do usuário: os resultados antigos
não a encerram novamente. Correções, evidências automatizadas atuais e
roteiro de aprovação em `docs/ac1/TESTES_UNIDADE_3.md`.

004/005/006 possuem verificações automatizadas de integração, incluindo
física e temporização, mas a avaliação humana de controle e ritmo continua
pendente. Ver `docs/ac1/TESTES_AC1.md` e `progress-tracker.md`.

O próximo incremento proposto após a validação da Unidade 3 é a câmera
elevada 3/4. A nova visão não autoriza implementar simultaneamente câmera,
colisões, construção e ciclo gradual de dia/noite.

## Evidências do playtest

- Unidade 1 (Spec 001), 2026-09-18: mecânica validada (movimento, câmera,
  ataque com dano). Primeira rodada falhou no ataque; corrigido e reaprovado.
  Sensação dos valores ainda não avaliada.

## Motivo do avanço para o próximo ciclo

Ainda não aplicável — Ciclo 1 só avança para o Ciclo 2 depois que o
incremento for implementado e validado em playtest (defesa da base
funcionando, domesticação funcionando, onda vencível e perdível).
