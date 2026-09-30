# Tower Defense Dino — GDD da AC1

**Estúdio:** Inity Pixel · **Versão:** 0.1 · **Data:** 30/09/2026  
**Equipe:** Murilo Cassetti, Heitor Crispim, Pedro Ferreira e Juan Carlos. Funções a confirmar pelo grupo.  
**Entrega:** 04/10/2026 às 23:59, pelo Game Designer, mediante link do Trello.

## 1. Conceito e experiência

Jogo 3D de defesa de território com controle direto em terceira pessoa. O jogador enfraquece dinossauros selvagens, domestica os elegíveis e posiciona aliados para enfrentar uma onda noturna. A decisão central é eliminar uma ameaça ou preservá-la como defesa, sabendo que o aliado mantém a vida restante.

Pilares registrados no projeto: tensão de sobrevivência, crescimento de poder e descoberta. Referências declaradas pelo grupo: Dungeon Defenders (defesa com avatar), ARK (domesticação) e World of Warcraft (progressão futura). A AC1 demonstra o primeiro ciclo; níveis, equipamentos, coleta, expansão e mundo salvo ficam para etapas posteriores.

## 2. História — proposta para a AC1

Em um vale de uma pré-história fantástica, uma pequena comunidade mantém seu último refúgio. Ao anoitecer, criaturas avançam sobre o território. Um guardião aprende a transformar ameaças em companheiros e precisa organizar a defesa antes de iniciar a noite. A base representa esse refúgio; sua destruição encerra a tentativa.

Humanos e dinossauros coexistem por convenção de fantasia. A história é contexto visual; não exige cutscenes, diálogos ou missões adicionais. O protagonista ainda não tem nome próprio aprovado.

## 3. Core loop e escopo

**Dia sem cronômetro → encontrar selvagem → enfraquecer → domesticar → conduzir e posicionar aliado → iniciar noite → defender base → eliminar/domesticar ameaças → voltar ao dia.**

Derrota: base a zero, com tela de resultado e opção de recomeçar como integração proposta. Vitória da onda: os três inimigos foram criados e deixaram de ser hostis. Não encerra permanentemente o jogo: retorna ao dia.

Para a versão de apresentação, propõe-se um encontro domesticável disponível durante o dia, sem depender da tecla de depuração T. Depois da vitória, um novo encontro só deve ser disponibilizado se o anterior deixou de ser selvagem. Esse fluxo ainda precisa ser integrado pelo Claude.

## 4. Controles

| Entrada | Comportamento |
|---|---|
| W/A/S/D | Mover o personagem |
| Mouse | Girar câmera |
| Clique esquerdo | Ataque corpo a corpo |
| E segurado | Domesticar alvo elegível próximo |
| F próximo do aliado | Alternar seguir/ficar; atualmente pode afetar vários aliados no alcance |
| N | Iniciar noite durante o dia |
| Esc | Hoje libera mouse; proposta AC1: pausa com Retomar/Menu |
| T | Depuração de spawn; não deve ser necessário na apresentação |

## 5. Regras existentes e valores provisórios

Valores lidos no código em 30/09; equilíbrio ainda depende de playtest.

| Sistema | Regra |
|---|---|
| Jogador | 6 m/s; dano 20; alcance aproximado 2 m; cooldown 0,8 s |
| Vida do jogador | Ainda não implementada; dano só registrado no Output. Não mostrar barra fictícia |
| Selvagem | 80 HP; dano diurno 15; velocidade diurna 4 m/s; detecção 8 m; ataque 1 s |
| Domesticação | Espécie elegível, viva, HP ≤30%, alcance 3 m, E durante 2 s |
| Cancelamento | Soltar E, sair do alcance ou alvo inválido zera o progresso |
| Conversão | Mantém HP atual; sai de wild_dino, entra em domesticated; não cura |
| Aliado | Segue por padrão; F a 3 m alterna ficar; defesa em raio de 8 m do posto |
| Variante | Carnotauro é nome provisório da cena não domesticável |
| Base | 100 HP; zero causa derrota |
| Onda | 3 inimigos com intervalo de 2 s |
| Noite | Selvagens: dano ×1,30 e velocidade ×1,20; aliados sem esse bônus |

Três golpes deixam o selvagem com 20/80 HP. O quarto o mata. Um aliado recém-domesticado pode morrer rapidamente; isso é risco do equilíbrio atual, não prova de falha da conversão. Não alterar vida ou dano silenciosamente para facilitar a demonstração.

## 6. Arena — proposta de apresentação

**Clareira do Refúgio**, 40 × 40 m, preservando o piso existente. Coordenadas em X/Z: jogador (0,0), base (0,-15), entrada de onda (0,+15). O arquivo `assets/arena_planta.svg` mostra a planta, legenda e zonas.

Progressão dentro da arena: reconhecer base e controles → encontro domesticável → levar aliado ao posto → enfrentar onda pelo corredor central. Não é uma segunda fase nem implementa a expansão futura.

Proposta: encontro diurno em (-10,+5), posto em (0,-7), corredor livre com 10 m de largura. O percurso dos inimigos continua direto; pedras e árvores ficam fora desse corredor. Limites devem impedir queda do jogador sem aprisionar criaturas ou bloquear a câmera. Decoração não pode exigir um sistema novo de navegação para esta entrega.

## 7. Arte e identidade — proposta

Visual geométrico de poucos polígonos, silhuetas grandes e materiais foscos. Guardião com túnica âmbar, lenço verde e arma curta de pedra; dinossauro pequeno com cauda marcante; base com pedras e estandarte. Verde e indicação textual identificam aliado; vermelho e texto identificam hostil; variante não domesticável tem marca própria. Cor nunca é a única indicação de estado.

Paleta: fundo #102B2A, floresta #24554A, aliado #69BE8C, âmbar #E7AE58, hostil #D9705D, claro #F2E8CE. Tipografia de apresentação: sans-serif do sistema; interface Godot pode usar a fonte padrão sem dependência externa.

Entregáveis visuais originais: logo do estúdio, logo do jogo, prancha do personagem, cenário, planta da arena e mockups de menu/HUD. São SVG editáveis. As pranchas são arte conceitual 2D; não são modelos 3D ou telas funcionais. O Claude integra logos e cria/adapta a representação 3D simples seguindo essas referências.

## 8. Menu e HUD — especificação para integração

Menu: logo, subtítulo “Domestique. Posicione. Defenda.”, Jogar, Controles, Créditos e Sair. Créditos com os quatro integrantes e indicação das ferramentas utilizadas conforme regras da disciplina. Mouse livre no menu; capturado somente no jogo.

HUD: vida real da base (número e barra), DIA/NOITE, ameaças da onda, objetivo contextual, comando F quando houver aliado próximo e progresso de domesticação durante E. Contador deve distinguir inimigos ainda não criados dos já neutralizados, sem anunciar vitória prematura. Sem barra de HP do jogador enquanto não existir sistema real.

Vitória: “Noite defendida”, retorno ao dia e instrução de preparação. Derrota: “O refúgio caiu”, Reiniciar e Menu. Pausa e opções devem bloquear entradas do jogo; N não inicia onda atrás do menu. Botões legíveis em 1280×720; foco de teclado visível; não depender de Output para entender o objetivo.

## 9. Trilha principal

`assets/refugio_loop.wav`: proposta instrumental original sintetizada para esta entrega, 32 segundos, 120 BPM, 16 compassos em 4/4. Base tonal em ré menor, percussão suave, baixo e motivo melódico curto. Sem samples externos ou voz. Loop com sinais periódicos e caudas envolvidas no início; volume inicial de integração sugerido: -12 dB. Validar a audição em fones e a transição do loop dentro da Godot.

## 10. Monetização — proposta conceitual

Protótipo acadêmico gratuito. Para uma versão comercial futura, proposta de compra única, com demonstração gratuita e eventuais expansões de conteúdo. Sem venda de força dos dinossauros, caixas aleatórias ou anúncios durante combate. Preço, público comercial e plataforma de distribuição dependem de pesquisa futura; não há checkout ou cobrança na AC1.

## 11. Estado real e critérios de entrega

O histórico anexado está desatualizado: a Unidade 3 consta como aprovada em 25/09 no progress-tracker. Aliados, dia/noite e onda estão implementados, com testes headless históricos registrados, mas playtest manual dessas partes ainda pendente. Esses testes não foram repetidos nesta preparação.

Pendências: integrar arte, menu/HUD, áudio e encontro diurno; validar física/combate/resultado/reinício; preencher responsáveis reais e publicar recursos nos cards do Trello. A aprovação acadêmica dos formatos deve ser conferida pelo grupo. O mapa está desenhado, mas sua decoração ainda não foi aplicada à cena.

Fontes locais: `docs/context/game-overview.md`, `technical-decisions.md`, `progress-tracker.md`, Specs 001–006, `project.godot` e scripts de `scenes/`. Este documento registra o estado encontrado e propostas da AC1; não substitui silenciosamente as Specs.
