# Visão Geral do Jogo

## Conceito

Tower Defense com elementos de RPG ambientado em uma era pré-histórica onde
humanos convivem com dinossauros. O jogador controla um personagem
diretamente (RPG de ação) enquanto organiza defesas baseadas em dinossauros
domesticados para proteger seu território de ataques de criaturas selvagens.

## Ambientação

Era pré-histórica. Humanos convivem com dinossauros de diferentes portes e
temperamentos.

## Gênero e referências

O jogo mistura três sistemas, cada um com uma referência específica:

**Tower Defense de controle direto — Dungeon Defenders**
O jogador controla o personagem diretamente enquanto também organiza suas
defesas. O mapa recebe ataques em ondas e é preciso preparar a área antes das
criaturas chegarem. No projeto, as defesas tradicionais (torres) são
substituídas por dinossauros domesticados, posicionados em pontos
estratégicos. Há gerenciamento simples de recursos para decidir quais
dinossauros posicionar ou melhorar.

**Domesticação de criaturas — ARK: Survival Evolved**
Diversidade de espécies de dinossauros encontradas no mapa, cada uma com
força, comportamento e dificuldade de domesticação diferentes. Dinossauros
menores e mais fracos são mais fáceis de domesticar no início; criaturas
maiores e mais perigosas aparecem conforme o jogo avança e algumas não podem
ser domesticadas de imediato — precisam ser combatidas ou expulsas do
território usando os dinossauros já domesticados. Nenhuma criatura selvagem é
passiva: todas podem representar perigo e atacar dependendo da situação.

**Progressão de personagem — World of Warcraft (versão simplificada)**
O personagem ganha experiência e sobe de nível explorando, enfrentando
criaturas e completando objetivos. Ao subir de nível, melhora atributos
básicos (vida, dano, defesa, possivelmente velocidade). Equipamentos são
simples no protótipo (arma e armadura). A evolução do personagem também
determina quais criaturas ele consegue enfrentar ou domesticar.

## Eixos estruturais

*Em definição — ver perguntas em aberto no fim deste documento.*

| Eixo | Valor |
|---|---|
| Ritmo | misto: exploração/coleta/domesticação/preparo sem pressão de tempo; combate e ondas em tempo real |
| Unidade de jogo | sessão contínua — mundo persistente, sem fases separadas |
| Controle | direto sobre um avatar (confirmado pela referência de Dungeon Defenders); indireto sobre os dinossauros posicionados — a detalhar |
| Fim | infinito com progressão — sem ponto final definido; personagem, território e dinossauros continuam evoluindo, novas regiões trazem ameaças maiores |

### Estrutura de ciclo ritmo (rascunho)

preparação (sem pressão de tempo) → início da onda → combate em tempo real
(jogador controla o personagem ativamente, dinossauros domesticados lutam
junto) → fim da onda → recompensa → nova preparação.

Fora das ondas, dinossauros selvagens soltos pelo mapa também representam
ameaça — a exploração não é totalmente segura, mas as ondas são o momento de
maior pressão.

**Origem:** referência direta em Dungeon Defenders. Para o protótipo, sem
ciclos de dia/noite ou tempo limitado — mantido simples de propósito.

### Mundo (rascunho)

Um único mundo persistente com regiões de perigo crescente. O jogador
expande o território aos poucos, sem recomeçar do zero. Ondas de ataque
acontecem dentro do mesmo mundo — depois de defender, o jogador continua
dali, podendo explorar, evoluir e melhorar a defesa.

**Escopo do protótipo:** apenas duas áreas — uma principal e uma mais
perigosa — para manter o projeto pequeno.

**Origem:** manter o mundo contínuo (sem fases) porque a progressão de
território e a descoberta de regiões mais perigosas são centrais à
experiência pretendida (crescimento de poder + curiosidade de descoberta).
Duas áreas no protótipo para não deixar o escopo grande demais.

## Core loop (CONFIRMADO)

explorar → encontrar recursos e dinossauros → domesticar/coletar → melhorar
personagem e dinossauros → organizar e posicionar os dinossauros de defesa →
iniciar onda → combate em tempo real (jogador participa ativamente: ataca, se
move, ajuda os dinossauros domesticados) → recompensa → expandir território →
encontrar criaturas mais fortes → repetir

**Origem:** o grupo confirmou o loop derivado das três referências (Dungeon
Defenders, ARK, WoW) e acrescentou o passo de organizar/posicionar os
dinossauros de defesa antes da onda, porque eles são a peça principal da
defesa. Escopo mantido enxuto de propósito para o protótipo — nenhuma etapa
extra adicionada agora.

## Experiência pretendida

Prioridade, da mais para a menos importante:

1. **Tensão de sobrevivência** — o mundo pré-histórico é perigoso; mesmo forte,
   o jogador nunca está totalmente seguro. Dinossauros selvagens são ameaça
   real, principalmente nas ondas de ataque, exigindo preparo prévio.
2. **Crescimento de poder** — evoluir o personagem, melhorar equipamentos e
   domesticar dinossauros mais fortes deve dar a sensação de estar mais
   preparado para ameaças que antes eram muito difíceis.
3. **Curiosidade de descoberta** — explorar novas áreas revela novas espécies,
   recursos e perigos.

**Origem:** o grupo quer que o perigo nunca desapareça — áreas novas e
dinossauros mais poderosos devem continuar desafiando o jogador mesmo depois
que ele progride, para sustentar a tensão de sobrevivência como sensação
principal.

### Objetivo temporário do protótipo

Sem fim definido no jogo completo, mas o protótipo tem um objetivo claro para
orientar o primeiro incremento: sobreviver às primeiras ondas, domesticar
pelo menos um dinossauro e conseguir acessar a segunda área (mais perigosa).

## Primeiro incremento (Ciclo 1 — Núcleo Jogável)

Menor versão jogável do core loop, apenas para provar que o núcleo funciona:
explorar → domesticar → posicionar defesa → enfrentar uma onda → vencer ou
perder.

Escopo do Ciclo 1:

- 1 personagem controlável, com movimento e ataque básico
- 1 área pequena para exploração
- 1 espécie de dinossauro pequeno e domesticável
- domesticação simples (uma ação/condição)
- posicionamento do dinossauro domesticado para defender o território
- dinossauros selvagens inimigos com a mesma IA (RF-AGE-003/004), em duas
  variantes de configuração: 1 domesticável e 1 não domesticável
  (RF-AGE-017) — para validar de fato a regra de domesticação restrita a
  certas espécies, não só a propriedade sem nenhum caso `false`
- ciclo DIA/NOITE simples, com transição manual (`006-ciclo-dia-noite.md`)
- 1 onda simples, disparada durante a NOITE
- jogador participa do combate junto com o dinossauro domesticado
- condição clara de vitória e de derrota

Fora do escopo do Ciclo 1 (fica para ciclos seguintes): sistema de nível,
atributos, equipamentos, segunda área, múltiplas espécies, expansão de
território.

**Origem:** corte proposto pela Grill a partir do objetivo temporário já
descrito pelo grupo, confirmado sem alterações.

## Perguntas em aberto

Nenhuma no momento — fundação do jogo fechada. Lacunas específicas do
primeiro incremento ficam registradas nas Specs correspondentes.
