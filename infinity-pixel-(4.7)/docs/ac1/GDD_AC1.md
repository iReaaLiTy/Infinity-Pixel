# Jadefall: Guardiões do Refúgio — GDD da AC1

**Inity Pixel · revisão 07/10/2026 · Godot 4.6.2**

Fonte: projeto `infinity-pixel-(4.7)`, scripts/cenas atuais e Specs 001–015. Substitui a descrição 0.2 de 30/09, anterior aos sistemas de vida, mapa ampliado, coleta, construção e territórios. O rótulo “(4.7)” da aplicação não é a versão da engine.

Equipe documentada nos créditos: **Murilo Cassetti, Heitor Crispim, Pedro Ferreira e Juan Carlos**. Funções e Game Designer a confirmar. Código, modelos e música têm produção assistida por IA conforme os créditos existentes; não atribuir autoria individual sem confirmação.

## Conceito, proposta e público

Protótipo acadêmico de ação 3D, sobrevivência e tower defense com câmera estratégica. Explorar um vale, coletar materiais, enfraquecer criaturas para domesticá-las e combinar aliados e construções na defesa do Refúgio. A decisão central é eliminar uma ameaça ou preservar sua vida para transformá-la em defesa.

Plataforma técnica: computador, teclado e mouse, Godot 4.6.2; validação atual em Windows. Sem lançamento comercial/plataforma de loja confirmado. Público proposto: pessoas que gostam de exploração, criaturas e estratégia com controle direto. Classificação indicativa formal não definida.

## História — proposta existente, aprovação do grupo pendente

Uma comunidade de um vale fantástico protege seu refúgio contra criaturas noturnas. O Guardião aprende a formar vínculos com dinossauros e transforma ameaças em companheiros. Cristal, estandartes e lenço jade comunicam abrigo e vínculo. Humanos e dinossauros coexistem como fantasia. Não há campanha, diálogos ou nome próprio aprovado para o protagonista.

## Core loop IMPLEMENTADO

**Explorar → coletar madeira/pedra → combater ou domesticar → recuperar territórios → construir/preparar defesas durante o dia → sobreviver à onda noturna → amanhecer e repetir.**

São escolhas na preparação, não missões obrigatórias em sequência. O dia dura 90 segundos de jogo; depois começa automaticamente a noite. A primeira onda tem 3 inimigos, com mais 1 a cada noite. O relógio noturno percorre 45 segundos até 05:59, mas **só neutralizar toda a onda causa o amanhecer**. Matar ou domesticar neutraliza; Pontos de Defesa vêm apenas de inimigos da onda mortos. Destruição do Refúgio encerra a partida. Morte do jogador leva a respawn e não encerra a sessão.

## Controles reais

Fonte: `project.godot`, `player.gd`, `main.gd`, `build_placer.gd`, `territory_manager.gd` e `healing_campfire.gd`. WASD é lido por teclas físicas no script.

| Entrada | Comportamento implementado |
|---|---|
| W A S D | Movimento relativo à câmera, 6 m/s |
| Mouse | Mira no mundo; câmera estratégica acompanha o jogador |
| Botão esquerdo | Golpe na direção do cursor; coleta árvores/pedras; em construção confirma posição válida |
| E segurado 2 s | Domesticar criatura elegível até 3 m; de dia recuperar marco pronto até 2,2 m |
| F | Alternar aliado próximo entre seguir/ficar, somente de dia |
| C | Construir/melhorar torre perto de ponto defensivo, somente de dia |
| I | Abrir/fechar inventário de materiais e receitas |
| B | Abrir construção de estruturas |
| R | Girar fantasma de construção em 90° |
| Botão direito | Cancelar posicionamento de estrutura |
| H segurado 3 s | Curar 25 HP na Fogueira até 2,5 m, conforme cargas e recarga |
| Esc | Cancelar/fechar construção ou inventário primeiro; depois pausar/retomar |
| Botões da interface | Jogar, controles, créditos, volume/mudo, reinício, menu e sair |

T e N existem no InputMap como **depuração desativada por padrão**. Não são controles normais da AC. Mouse não gira a câmera atual.

## Personagem, combate e morte — IMPLEMENTADO

Guardião com túnica âmbar, lenço jade, bolsa, botas e machado de pedra, modelado em primitivas low-poly. Orientação responde ao movimento e à mira. Golpe: 15 de dano, intervalo 0,8 s ao acertar; golpe vazio recupera em 0,3 s; buffer de 0,35 s. Coleta usa o mesmo golpe.

Jogador: 100 HP; invulnerabilidade de 0,6 s após dano válido; respawn em 2 s no ponto (0,1,−10), vida restaurada e proteção de 1,5 s. A morte interrompe ações, mas não reseta base, materiais ou territórios. Refúgio: 100 HP; zero HP é derrota com Reiniciar/Menu. Sem regeneração automática da base documentada como mecânica.

## Criaturas, aliados e inimigos — IMPLEMENTADO

WildDino: 80 HP, dano base 15, detecção 8 m, alcance de ataque 2 m, velocidade base 4 m/s. Inimigos de onda avançam contra a base e reagem a jogador/aliados. Encontros diurnos são territoriais, um a oeste e outro a leste. Navmesh, avoidance e slots de aproximação conduzem a navegação. À noite os hostis recebem dano ×1,30 e velocidade ×1,20; aliados não recebem esses bônus.

Domesticação: espécie domesticável, viva, HP ≤30% (24/80). Com dano atual, **quatro golpes deixam 20/80; cinco deixam 5/80; seis matam**. E por 2 s converte e restaura a vida para 80/80 uma vez (Spec 013C). Soltar, afastar-se ou invalidar o alvo cancela; canalização trava alvo e impede conflito de combate. Aliado segue inicialmente; F alterna seguir/ficar de dia. À noite F não reposiciona. Aliados defendem e podem morrer; não recebem dano amigável do jogador.

Carnotauro é variante não domesticável com chifres e cor distinta em `scenes/enemies/carnotauro.tscn`. **Não é o inimigo padrão das ondas atuais.** Não há novas espécies ou boss nesta entrega.

## Recursos, inventário e construção — IMPLEMENTADO

Madeira e pedra são materiais distintos dos Pontos de Defesa (PD). Árvores coletáveis: 30 HP, rendem 10 madeiras. Pedras: 45 HP, rendem 6 pedras. Pagam uma vez ao esgotar e restauram no amanhecer. Inventário mostra totais e receitas; não é inventário de equipamentos com slots.

| Construção | Custo | Regras |
|---|---|---|
| Torre nível 1 | 30 PD | 10 dano, intervalo 1 s, alcance 8 m |
| Melhoria nível 2 | 30 PD | 15 dano, intervalo 0,85 s, alcance 9 m |
| Melhoria nível 3 | 45 PD | 20 dano, intervalo 0,70 s, alcance 10 m |
| Fogueira | 20 madeira + 12 pedra | Limite 1; cura 25; 2 cargas renovadas ao amanhecer; recarga 25 s |
| Armadilha | 15 madeira + 6 pedra | Limite 3 ativas; 15 dano, 3 cargas, rearme 0,35 s; nas rotas |

Começa com 40 PD; ganha 15 por inimigo da onda morto. Construção/melhorias só de dia. Torres ocupam seis pontos fixos. Estruturas usam fantasma, validação de espaço/chão/rotas e pagamento na confirmação. Fogueira cabe na BuildZone ou território recuperado com chão válido; armadilhas seguem restritas às rotas. H exige canalização, não é cura passiva; soltar, dano e ações incompatíveis cancelam.

## Territórios e progressão — IMPLEMENTADO

Spec 015 implementada, com aprovação manual ainda pendente no registro. Refúgio começa controlado; Floresta Oeste e Região Rochosa começam selvagens. Derrotar **ou domesticar** guardião libera marco; E por 2 s próximo dele de dia recupera a área. Habilita construção de base respeitando validações. Marcos: (−14,0,13) e (13,0,16). Feedback de entrada e contador de 1/3 a 3/3 na HUD.

Progresso permanece na sessão, após respawn e amanhecer. Reinício restaura o estado inicial. Novos encontros não desfazem conquista. Corredor da ruína ao norte é área selvagem não conquistável. Sem save persistente, níveis/XP ou campanha implementados.

## Level design e arena — IMPLEMENTADO

Arena aproximadamente **48 × 52 m**: X −24…24, Z −24…28. Refúgio (0,0,−15); spawn (0,1,−10). Base/BuildZone ao sul; bifurcação central conecta bosque oeste, região rochosa leste e ruína norte. Ondas entram pelo norte e laterais; recursos/encontros ocupam áreas de exploração. Colisões, navmesh e restrições de construção preservam circulação.

Seis pontos de torre, coordenadas X/Z: (−10,5;−5,5), (−18;−1,5), (−3,8;−1), (3,6;12,5), (10,5;−5,5), (18;−1,5). Oito árvores coletáveis a oeste e seis pedras a leste. A planta antiga de 40×40 é histórica; usar [mapa atual](../delivery/ac1/MAPA.md).

## Direção de arte e identidade

Malhas low-poly, materiais foscos e silhuetas distintas; vegetação, rochas, cristais, madeira e pedra. Guardião âmbar, aliado jade, ameaças em cores distintas. Estúdio **Inity Pixel**; jogo **Jadefall: Guardiões do Refúgio**. Paleta existente: #102B2A, #24554A, #69BE9B, #E7AE58, #C76C4C, #F2E8CE. Menu usa título âmbar/jade e cenário 3D. Keyart antiga é referência, não screenshot.

Céu, direção solar, cores, sombras e sinais noturnos variam com o relógio único. Tochas, cristais e Fogueira ganham presença à noite. A câmera não mostra o céu em todo enquadramento. Ver [moodboard](../delivery/ac1/MOODBOARD.md) e [identidade](../delivery/ac1/IDENTIDADE.md).

## Menu, HUD e áudio — IMPLEMENTADO

Menu: Jogar, Controles, Créditos, Sair, volume/mudo. HUD: HP real do jogador e Refúgio, dia/hora/fase, onda, madeira/pedra, PD, territórios, domesticação e dicas. Pausa permite retomar, reiniciar e voltar ao menu; perda de foco pausa. Reinício cria nova sessão e reinicia autoload.

Tema original existente **Passos do Refúgio**: `assets/audio/refugio_principal.wav`, 112 s; mixagem calma em menu/dia e combate à noite via `audio_director.gd`. Efeitos de golpe/vínculo e sinais de resultado separados; pausa atenua música. Fonte em `tools/compose_score.py`, sem samples externos segundo a proveniência existente. Aprovação musical depende de audição humana.

## PLANEJADO / PROPOSTO — não implementado

Aprovação da lore, comercialização por compra única, preço final, lançamento, níveis/XP, equipamentos, campanha, novas espécies/regiões, save e multiplayer. A proposta comercial não cria loja no protótipo. Ver [monetização](../delivery/ac1/MONETIZACAO.md).

## Decisões consolidadas

1. Combate direto e defesa indireta; domesticar restaura HP uma vez e oferece alternativa à eliminação.
2. Preparação tem tempo limitado; resolver onda é obrigatório para amanhecer.
3. Morte do jogador é recuperável; perda do Refúgio encerra sessão.
4. Materiais financiam estruturas; PD financiam torres, sem dinheiro real.
5. Territórios expandem possibilidades na arena existente, sem novo mapa.
6. Progressão territorial é de sessão; contratos das Specs anteriores preservados.
7. A AC demonstra o que existe; documentação conceitual antiga não comprova implementação.

## Validação

Resultados atuais em [TESTES.md](../delivery/ac1/TESTES.md). Automação e demonstrações com preparação controlada não equivalem a playtest livre ou aprovação humana de balanceamento/áudio. Trello, responsáveis e envio pelo Game Designer são etapas externas.

