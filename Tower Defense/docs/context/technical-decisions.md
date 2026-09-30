# Decisões Técnicas

Registra apenas decisões caras de reverter, com alternativa razoável
descartada, que alguém de fora do grupo perguntaria "por que assim".

## Ritmo misto: preparação sem pressão de tempo, combate em tempo real

Exploração, coleta, domesticação e preparação da defesa não têm pressão de
tempo. Ondas de ataque e combate rodam em tempo real, com o jogador
controlando o personagem ativamente.

**Alternativas descartadas:** ritmo totalmente por turnos (mudaria o gênero
para mais próximo de um TD tradicional/tático); ritmo totalmente em tempo
real incluindo preparação (removeria o espaço de planejamento que sustenta a
fase de organização da defesa).

**Motivo:** referência direta em Dungeon Defenders — o grupo quer controle
direto do personagem durante o combate, mas preparo tranquilo entre ondas.
Essa escolha define a arquitetura de estados do jogo (fase de preparação vs.
fase de onda) e seria cara de reverter depois que sistemas de UI, IA e
progressão forem construídos em cima dela.

## Mundo persistente e contínuo, sem fases separadas

O jogo é uma sessão contínua: o jogador expande o mesmo território ao longo
do tempo, sem estrutura de "fase 1, fase 2, fase 3". Ondas acontecem dentro
do mesmo mundo persistente.

**Alternativas descartadas:** estrutura de fases/níveis discretos, como a
maioria dos Tower Defense tradicionais.

**Motivo:** a progressão de território e a descoberta de regiões mais
perigosas são centrais à experiência pretendida (crescimento de poder +
curiosidade de descoberta). Definir isso agora evita reestruturar todo o
sistema de salvamento/progressão depois — mudar de mundo persistente para
fases seria uma reescrita de arquitetura, não um ajuste.

## Transição dia/noite manual, sem cronômetro; derrota é definitiva (sem retorno automático ao dia)

O Ciclo 1 tem dois estados globais, DIA e NOITE, mas a transição DIA → NOITE
é sempre acionada manualmente pelo jogador ("Iniciar Noite"), nunca por um
temporizador. A derrota (base a 0 HP) encerra a sessão/partida atual — o
jogo não retorna automaticamente a DIA nem recupera a base; o jogador
precisa reiniciar a partida para tentar de novo.

**Alternativas descartadas:** cronômetro automático de dia (`day_duration`),
que traria pressão de tempo à fase de preparação; derrota retornando
automaticamente a DIA, com ou sem reparo/recuperação da base.

**Motivo:** o grupo quer validar domesticação, organização de aliados e
defesa sem pressão de tempo antes de testar ritmo cronometrado (fica para um
ciclo futuro); e quer uma condição de derrota inequívoca para testar
corretamente vitória/derrota no MVP, sem mascarar o resultado com
recuperação automática da base. Mudar isso depois exigiria redesenhar o
estado central do loop de jogo e o fluxo de fim de partida.

## Morte do personagem não é derrota; apenas a base perdendo toda a vida é

Se o personagem do jogador morrer durante uma onda, ele reaparece (respawn) e
a onda continua. A única condição de derrota é a base chegando a 0 HP.

**Alternativas descartadas:** morte do personagem causar derrota imediata
(modelo mais punitivo, comum em outros TD com avatar controlável).

**Motivo:** o grupo optou por manter o teste do núcleo do Ciclo 1 focado na
defesa da base, sem travar o playtest toda vez que o personagem morre. Essa
decisão define onde fica o "risco real" do jogo (a base, não o personagem) e
molda todo o sistema de vida/dano e o design de dificuldade dos ciclos
seguintes — reverter depois exigiria redesenhar a curva de risco do jogo
inteiro.
