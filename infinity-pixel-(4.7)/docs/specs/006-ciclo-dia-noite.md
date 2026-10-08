# 006 — Ciclo de Dia e Noite

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Duração cronometrada de dia (`day_duration` / timer automático) — transição
  DIA → NOITE continua manual neste ciclo; timer fica como possibilidade
  futura.
- Sistema de reparo ou recuperação da base após derrota — fica para ciclos
  futuros.
- Múltiplas noites/ondas nesta spec — a quantidade de inimigos e ondas
  continua definida em `005-onda-e-vitoria.md` (1 onda, 3 inimigos).
- Buff noturno de HP/resistência — mantido em `1.00x` (sem alteração) neste
  ciclo; só dano e velocidade são afetados (RF-AGE-018).

## Requisitos

### RF-AGE-013 — Estados DIA e NOITE

**Prioridade:** DEVE
**Status:** CONFIRMADO

O jogo possui dois estados globais e mutuamente exclusivos: DIA e NOITE.
Durante o DIA não há onda ativa; durante a NOITE a onda (`005-onda-e-vitoria.md`)
está em andamento.

**Critérios de aceitação**

- Dado que a partida está em andamento e nenhuma onda foi iniciada, então o
  jogo está no estado DIA.
- Dado que o jogador aciona "Iniciar Noite", quando o comando é confirmado,
  então o jogo passa para o estado NOITE.

**Origem:** formaliza como estado explícito e consultável por outros
sistemas (buff noturno, IA, HUD) o que já existia implicitamente como fase
de preparação e fase de onda.

### RF-AGE-014 — Transição manual DIA → NOITE

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-013, RF-AGE-009

Durante o DIA, sem cronômetro obrigatório, o jogador pode se posicionar,
domesticar dinossauros, organizar aliados (seguir/ficar) e preparar a
defesa. Quando estiver pronto, aciona manualmente "Iniciar Noite" —
substituindo semanticamente o comando "Iniciar onda" (RF-AGE-009) sem
alterar sua natureza manual — o que dispara o início da NOITE e da onda
(RF-AGE-010).

**Critérios de aceitação**

- Dado que o jogo está no estado DIA, quando o jogador aciona "Iniciar
  Noite", então o jogo passa para NOITE e a onda começa.
- Dado que o jogo está no estado DIA, quando nenhum comando é dado, então o
  jogo não avança sozinho para NOITE (sem cronômetro).

**Origem:** o grupo quer validar domesticação, organização de aliados e
defesa sem pressão de tempo antes de testar ritmo cronometrado; reaproveita
a decisão já confirmada de início manual da onda (RF-AGE-009) em vez de
criar um segundo mecanismo. Reduz escopo do ciclo.

### RF-AGE-015 — Retorno ao DIA após vitória

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-011, RF-AGE-013

> **Atualização 2026-10-03:** a regra não mudou. A apresentação da volta ao
> DIA (sem modal e sem pausa) está em `008-continuidade-noite-dia-hud.md`
> (RF-UI-001).

Quando a condição de vitória da onda (RF-AGE-011, todos os inimigos
derrotados) é cumprida, a NOITE termina automaticamente e o jogo retorna ao
estado DIA.

**Critérios de aceitação**

- Dado que o jogo está em NOITE, quando os inimigos da onda são todos
  derrotados, então o jogo retorna ao estado DIA.

**Origem:** fecha o loop DIA → NOITE → DIA; a noite termina "automaticamente
quando a condição da onda for concluída", sem novo comando manual do
jogador para voltar ao dia.

### RF-AGE-016 — Fim de sessão após derrota

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-012, RF-AGE-013

Quando a base chega a 0 HP (RF-AGE-012), a sessão/partida atual termina
definitivamente: o jogo não retorna ao estado DIA, entra em um estado de fim
de jogo, e bloqueia ações de gameplay (movimento, ataque, domesticação) até
o jogador reiniciar a partida.

**Critérios de aceitação**

- Dado que a base chega a 0 HP, então o jogo entra em estado de fim de jogo
  e não retorna a DIA.
- Dado que o jogo está em estado de fim de jogo, quando o jogador tenta
  agir, então nenhuma ação de gameplay tem efeito até a partida ser
  reiniciada.

**Origem:** o grupo quer uma condição de derrota inequívoca para testar se
vitória e derrota funcionam corretamente no MVP; não quer a base recuperando
HP automaticamente nem sistema de reparo ainda. Isso mantém "onde fica o
risco real" claro, na linha da decisão já registrada sobre a morte do
personagem não ser derrota.

### RF-AGE-018 — Buff noturno em dinossauros hostis

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-013, RF-AGE-004

Durante o estado NOITE, todo dinossauro selvagem hostil (domesticável ou
não — RF-AGE-017) recebe um multiplicador de dano e de velocidade de
movimento, sempre calculado a partir do valor-base do atributo, nunca
acumulado sobre um valor já modificado. Ao voltar para DIA, dano e
velocidade retornam exatamente ao valor-base. Dinossauros domesticados
(aliados) nunca recebem esse buff.

**Critérios de aceitação**

- Dado que o jogo está em NOITE, quando um dinossauro hostil ataca, então o
  dano aplicado é o dano-base multiplicado por `night_damage_multiplier`.
- Dado que o jogo está em NOITE, quando um dinossauro hostil se move, então
  a velocidade é a velocidade-base multiplicada por `night_speed_multiplier`.
- Dado que o jogo volta para DIA, então dano e velocidade voltam a usar
  exatamente o valor-base, sem multiplicador acumulado de noites anteriores.
- Dado que um dinossauro está no grupo de aliados/domesticados, quando é
  NOITE, então nenhum multiplicador noturno é aplicado a ele.

**Origem:** o grupo quer a noite perceptivelmente mais perigosa sem ainda
alterar a durabilidade dos inimigos, para testar se dano e velocidade já
criam pressão suficiente antes de somar mais dificuldade (HP) em ciclos
futuros.

**Hipótese de protótipo — Multiplicador de dano noturno**
- **Valor inicial:** `night_damage_multiplier = 1.30` (+30%)
- **Pergunta do protótipo:** +30% de dano à noite já cria pressão perceptível sem ser punitivo demais?
- **Teto ou limite de exploração:** até `1.50` (+50%) nesta rodada.

**Hipótese de protótipo — Multiplicador de velocidade noturna**
- **Valor inicial:** `night_speed_multiplier = 1.20` (+20%)
- **Pergunta do protótipo:** +20% de velocidade à noite pressiona a defesa sem ultrapassar injustamente a mobilidade do jogador/aliados?
- **Teto ou limite de exploração:** até `1.40` (+40%) nesta rodada.

**Hipótese de protótipo — Multiplicador de vida/resistência noturna**
- **Valor inicial:** `night_health_multiplier = 1.00` (sem alteração)
- **Pergunta do protótipo:** dano e velocidade sozinhos já bastam para criar pressão, ou HP/resistência precisa entrar num ciclo futuro?
- **Teto ou limite de exploração:** mantido em `1.00` neste Ciclo 1 — alterar HP noturno está fora de escopo agora.

## Alternativas descartadas

- Timer automático de dia (`day_duration`). Descartado para não introduzir
  pressão de tempo na preparação antes de validar o núcleo do gameplay;
  possibilidade explícita para um ciclo futuro.
- Derrota retornando ao DIA, com ou sem reparo/recuperação de base.
  Descartado para o Ciclo 1: o grupo quer uma condição de derrota clara, sem
  a base "voltando magicamente" ao HP cheio; reparo/continuação após derrota
  fica para ciclos futuros.

## Perguntas em aberto

- Nível de UI do estado de "fim de jogo" após derrota — fica para uma
  exploração de HUD/interface futura; esta spec só define o comportamento,
  não a apresentação.

## Não aplicável a este jogo

*Nenhuma.*
