# 004 — Dinossauro Domesticado (Defesa)

Ciclo 1 — Núcleo Jogável.

## Fora do escopo

- Vários comandos, formações ou ordens complexas — Ciclo 1 tem apenas dois estados (seguir / ficar).
- Seleção de múltiplos dinossauros — fora do Ciclo 1.
- Bônus por domesticação, evolução própria ou atributos diferentes como aliado — fica para ciclos futuros.

## Requisitos

### RF-AGE-007 — Estados de seguir e defender posição

**Prioridade:** DEVE
**Status:** CONFIRMADO
**Depende de:** RF-AGE-006

Depois de domesticado, o dinossauro segue o jogador. Ao chegar no ponto
desejado, o jogador aciona o comando "ficar" e o dinossauro passa a
permanecer naquele ponto, funcionando como unidade defensiva.

**Critérios de aceitação**

- Dado que o dinossauro acabou de ser domesticado, quando nenhum comando foi
  dado, então ele segue o jogador.
- Dado que o dinossauro está seguindo o jogador, quando o jogador aciona o
  comando "ficar", então o dinossauro permanece parado naquele ponto do
  mapa.

**Origem:** grupo quer apenas dois estados no Ciclo 1 para manter simples,
sem múltiplos comandos ou formações.

### RF-AGE-008 — Defesa automática por área

**Prioridade:** DEVE
**Status:** PROVISÓRIO
**Depende de:** RF-AGE-007

Enquanto está no estado "ficar", o dinossauro domesticado detecta
dinossauros selvagens dentro de um raio de defesa ao redor do ponto onde foi
posicionado, se aproxima e ataca automaticamente. Ao derrotar o inimigo ou
perdê-lo de alcance, retorna ao ponto original.

Mantém os mesmos atributos de combate que tinha quando selvagem: 80 HP, 15
de dano por ataque, cooldown de 1 segundo, ataque corpo a corpo (ver
RF-AGE-004 em `002-dinossauro-selvagem.md`).

**Critérios de aceitação**

- Dado que o dinossauro está no estado "ficar", quando um dinossauro
  selvagem entra no raio de defesa, então o dinossauro domesticado se
  aproxima e ataca automaticamente, sem comando manual do jogador.
- Dado que o dinossauro domesticado está perseguindo um inimigo, quando o
  inimigo é derrotado ou sai do raio de defesa, então o dinossauro
  domesticado retorna para perto do ponto original.
- Dado que nenhum inimigo está dentro do raio de defesa, quando o
  dinossauro está no estado "ficar", então ele permanece parado no ponto.

**Origem:** IA automática para não exigir comando manual de ataque durante a
onda — mantém o núcleo do Ciclo 1 simples. Atributos de combate reaproveitados
da Spec 002 por serem o mesmo indivíduo/espécie, sem bônus de domesticação
neste ciclo.

**Hipótese de protótipo — Raio de defesa**
- **Valor inicial:** 8 metros a partir do ponto de "ficar"
- **Pergunta do protótipo:** 8m dá cobertura de defesa coerente sem o dinossauro se afastar demais do ponto?
- **Teto ou limite de exploração:** entre 6 e 12 metros. Valor inicial de 8m escolhido por coincidir com o alcance de detecção do dinossauro selvagem (RF-AGE-004), mantendo a lógica consistente entre os dois sistemas.

## Alternativas descartadas

*Nenhuma registrada nesta spec.*

## Perguntas em aberto

*Nenhuma para esta spec no momento.*

## Não aplicável a este jogo

*Nenhuma.*
