# Glossário

Termos e conceitos usados no projeto. Reutilize este vocabulário nas specs.

- **Território** — área que o jogador defende contra ataques de criaturas selvagens.
- **Dinossauro domesticado** — criatura capturada pelo jogador que passa a atuar como aliado de defesa/combate.
- **Dinossauro selvagem** — criatura não domesticada; sempre representa ameaça potencial, nunca é passiva.
- **Domesticação** — processo de tornar um dinossauro selvagem em aliado do jogador.
- **Onda** — ciclo de ataque de criaturas selvagens contra o território.
- **Dia** — estado do jogo sem onda ativa; fase de preparação sem cronômetro obrigatório (posicionar, domesticar, organizar aliados, preparar defesa).
- **Noite** — estado do jogo com a onda em andamento; começa quando o jogador aciona "Iniciar Noite" e termina automaticamente com a vitória da onda, retornando ao Dia.
- **Buff noturno** — bônus temporário aplicado aos dinossauros hostis durante a Noite; nunca se aplica a dinossauros domesticados (aliados).
- **Carnotauro** — nome placeholder (provisório, sem arte final) da variante de dinossauro selvagem com `is_domesticable = false`, usada para validar a regra de domesticação restrita no Ciclo 1.
