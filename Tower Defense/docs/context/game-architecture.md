# Arquitetura do Jogo

Síntese dos sistemas principais e como se conectam. Nível de
responsabilidade, não de implementação. Atualizado conforme as Specs
amadurecem.

## Sistemas do Ciclo 1

**Personagem do jogador** (`001-controle-jogador.md`)
Responsável por movimento livre em 3D, câmera em terceira pessoa e ataque
corpo a corpo com cooldown. É a fonte de dano controlada diretamente pelo
jogador, tanto na exploração quanto durante as ondas.

**Dinossauro selvagem** (`002-dinossauro-selvagem.md`)
Responsável pelo comportamento de ameaça: spawna apenas durante a onda
(NOITE), avança até a base, detecta e ataca o jogador ou dinossauros
domesticados no caminho. Durante a NOITE recebe o buff noturno de dano e
velocidade (`006-ciclo-dia-noite.md`, RF-AGE-018). Possui uma propriedade
explícita `is_domesticable` (RF-AGE-017): quando verdadeira, é o mesmo "tipo
de entidade" que, ao ser enfraquecido, se torna elegível para domesticação;
quando falsa, nunca fica elegível e só deixa de ser ameaça ao ser derrotado.

**Domesticação** (`003-domesticacao.md`)
Ponte entre o dinossauro selvagem e o dinossauro domesticado. Depende do
combate (Personagem → Dinossauro selvagem) reduzir a vida do alvo abaixo de
um limiar **e** de `is_domesticable` ser verdadeiro, e converte a entidade
selvagem em aliada através de uma ação de canalização do jogador.

**Ciclo Dia/Noite** (`006-ciclo-dia-noite.md`)
Orquestrador central do loop de jogo do Ciclo 1: mantém o estado global
DIA/NOITE. Durante o DIA (sem cronômetro) o jogador prepara, domestica e
organiza aliados; a NOITE começa por ação manual do jogador ("Iniciar
Noite") e ativa a Onda. Aplica o buff noturno aos dinossauros hostis (nunca
aos aliados) enquanto dura a NOITE. Vitória da Onda retorna ao DIA; derrota
da Base encerra a sessão sem retorno ao DIA.

**Dinossauro domesticado** (`004-dinossauro-domesticado.md`)
Responsável pelo comportamento do aliado: segue o jogador ou defende uma
posição fixa, com IA automática de combate por área. Reaproveita os
atributos de combate definidos em Dinossauro selvagem — não é um sistema de
stats separado no Ciclo 1.

**Onda e condição de vitória/derrota** (`005-onda-e-vitoria.md`)
Controla o spawn escalonado dos dinossauros selvagens durante a NOITE e
define o resultado (vitória ao derrotar os inimigos da onda, derrota se a
base perder toda a vida). Depende de Personagem, Dinossauro selvagem e
Dinossauro domesticado para determinar o resultado do combate. O início da
onda e o retorno ao DIA são orquestrados pelo Ciclo Dia/Noite.

## Como se conectam

```
Ciclo Dia/Noite ──"Iniciar Noite"──> Onda (spawn escalonado)
     │                                    │
     │                                    ├──vitória (todos derrotados)──> volta a DIA
     │                                    └──derrota (Base 0 HP)──────────> fim de sessão
     │
     └──NOITE ativa──> aplica buff noturno a todo Dinossauro selvagem hostil

Personagem ──ataca──> Dinossauro selvagem ──(vida baixa + is_domesticable)──> Domesticação ──> Dinossauro domesticado
     │                        │                                                                     │
     │                        └──ataca──> Base <────────────────defende──────────────────────────────┘
```

O Ciclo Dia/Noite é o orquestrador central do Ciclo 1: ele não implementa
combate, IA ou domesticação — apenas controla o estado DIA/NOITE, dispara a
Onda e aplica/remove o buff noturno, observando o estado dos outros sistemas
para decidir vitória ou derrota.

## Fora do Ciclo 1

Progressão de nível/atributos, equipamentos, múltiplas espécies, segunda
área e expansão de território ainda não têm sistemas definidos — entram em
ciclos futuros conforme `docs/context/game-overview.md`.
