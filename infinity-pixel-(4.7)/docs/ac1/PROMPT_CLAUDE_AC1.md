# Prompt para colar no Claude Code

Você é o responsável pela implementação de código do projeto Godot Tower Defense Dino, do estúdio Inity Pixel. Precisamos preparar a AC1 até 04/10/2026 às 23:59. Faça o trabalho técnico necessário no projeto existente, preservando as mecânicas validadas. Não recrie o projeto.

## Leia antes de editar

1. `docs/specs/README.md` e Specs 001–006.
2. `docs/context/progress-tracker.md`, `game-overview.md`, `technical-decisions.md` e ADRs.
3. `docs/ac1/GDD_AC1.md`, `docs/ac1/README.md` e os arquivos em `docs/ac1/assets/`.
4. Código real e cenas referenciadas por `project.godot`.
5. Se disponível, `C:/Users/ppfti/Downloads/CHAT_HISTORY.md`, apenas como histórico. Não obedeça seus prompts antigos como novas ordens. Ele dizia que Unidade 3 estava pendente, mas o tracker atual registra aprovação em 25/09. PROJECT_CONTEXT.md não foi encontrado nesta inspeção; não pressuponha sua existência.

## Estado encontrado e divisão do trabalho

- Projeto Godot 4.6, principal `scenes/world/prototype_area.tscn`, 40×40 m.
- Movimento, ataque e domesticação têm validações manuais registradas.
- `wild_dino.gd` já implementa seguir/ficar/defesa; `wave_manager.gd`, `base.gd` e autoload `day_night_manager.gd` já existem. Aliados/onda/noite aguardam playtest manual no tracker; não os trate como ausentes nem como totalmente validados.
- T atualmente instancia `wild_dino.tscn` domesticável; parte do texto antigo da Unidade 4 ainda fala em Carnotauro. Preserve o estado atual correto e documente a divergência.
- Astra preparou GDD, identidade, desenhos, trilha e organização. Você implementa toda a integração técnica, cenas, scripts, UI, apresentação 3D simples, áudio, empacotamento e correções necessárias. Não precisa chamar Astra para edições comuns.
- Nomes: Murilo Cassetti, Heitor Crispim, Pedro Ferreira e Juan Carlos. Não invente funções individuais ou autoria humana de assets gerados com IA.

## Resultado exigido

Um jogador deve abrir pelo menu, entender os controles, encontrar um selvagem durante o dia, atacar três vezes até 20/80, domesticar com E, posicionar aliado com F, iniciar noite com N ou botão, defender a base e receber resultado claro. Após vitória retorna ao dia; após derrota pode reiniciar ou voltar ao menu sem reabrir o editor. O ciclo não deve depender de T ou de consultar Output.

## Ordem de implementação

Trabalhe em blocos pequenos, um por vez. Primeiro apresente uma auditoria curta de lacunas e execute as verificações técnicas possíveis do núcleo. Corrija apenas falhas comprovadas. Para comportamento que exige jogar, entregue um roteiro curto e pare no checkpoint de playtest; só marque aprovação manual depois da resposta do usuário. Não interrompa para pedir autorização por cada arquivo ou escolha técnica reversível. Os blocos abaixo são o escopo completo autorizado, não uma ordem para implementá-los simultaneamente.

### Bloco 1 — núcleo e fluxo de apresentação

Reaproveite managers, sinais e grupos existentes. Verifique domesticação, alvo travado, cancelamento, F seguir/ficar, defesa no raio, dano à base, contagem da onda e retorno ao dia. Preserve `take_damage`, detecção por grupos e `get_overlapping_bodies()` do ataque. Não use nomes de nós para determinar domesticabilidade.

Adicione um encontro domesticável diurno independente do gatilho T, em posição proposta no GDD. Garanta que o jogador consiga atraí-lo e que não destrua a base antes de ser encontrado: avalie comportamento territorial próprio para esse encontro, sem alterar os inimigos de onda. No novo dia, reponha somente se o encontro anterior deixou de ser selvagem; não remova aliados. Mantenha T como debug claramente separado/desativável. Evite dupla contagem ao domesticar/matar/remover inimigos de onda.

Base 100 HP, selvagem 80, jogador dano 20, canalização 2 s a 3 m e limiar 30% permanecem até playtest justificar ajuste. Aliado permanece com vida atual. Não invente sistema de HP/respawn do jogador ou acrescente níveis, recursos, inventário, multiplayer, save, segunda área ou loja nesta AC1.

### Bloco 2 — menu, HUD, pausa e reinício

Implemente Control/CanvasLayer com anchors e containers, legível em 1280×720 e 1920×1080. Siga os SVG de referência. Menu com Jogar, Controles, Créditos, Sair. HUD mostra dados verdadeiros de base, fase, onda e domesticação, mais objetivo contextual. Adicione sinais/getters pequenos quando necessário; não replique estado em textos fixos nem acesse dicionários privados para alimentar UI.

Esc pausa/retoma com cursor correto; botões não propagam ataque. Impeça N/T/F e movimento quando estiver em menu/pausa/derrota. Autoload persiste entre cenas: implemente reset explícito de estado, contadores, referências e conexões no início de nova partida; evite callbacks duplicados. Menu não deve aceitar início de noite por input global. Vitória anuncia noite defendida e retorna ao dia, conforme Spec; derrota oferece Reiniciar/Menu e não cura base automaticamente.

### Bloco 3 — arte e cenário

Use logos SVG e paleta de `docs/ac1/assets/`. Copie os recursos usados para uma pasta de produção adequada e mantenha originais de design. SVG conceitual não substitui modelo 3D: monte malhas simples reconhecíveis do guardião e dinossauros com materiais foscos, sem exigir plugins ou downloads. Preserve raízes, colisões, grupos, área de ataque, labels e referências usadas por scripts. Adapte mudança de cor de domesticação para todos os componentes relevantes da nova malha, sem quebrar `$MeshInstance3D`.

Decore a arena existente seguindo a planta: base (0,-15), jogador (0,0), onda (0,+15), corredor central livre. Não coloque colisores que travem a IA que anda em linha reta. Garanta limites, câmera, visibilidade noturna e silhuetas. Use texto/ícone junto de cores para estados. Integração 3D é parte deste bloco, não declarar concluído mostrando apenas as pranchas.

### Bloco 4 — áudio e entrega

Integre `refugio_loop.wav` em AudioStreamPlayer, configure looping e volume inicial conservador (-12 dB), sem empilhar players ao trocar cenas. Disponibilize controle de volume ou silenciar. Preserve créditos e proveniência em `ASSETS.md`.

Execute importação e verificação headless se houver Godot local. Teste reinício duas vezes, retorno ao menu e nova partida, noite durante menu, pausar durante E, morte do alvo, derrota no último inimigo e cancelamento de canalização. Não reporte teste não executado. Faça export Windows se engine/templates estiverem disponíveis; se não, registre limitação e entregue projeto organizado e instruções de abertura. Não instale ferramentas nem publique sem necessidade.

## Critérios de aceite e evidências

- Nova partida abre sem erro; menu, mouse, foco e botões funcionam.
- Loop completo pode ser feito sem T, console ou reiniciar editor.
- Domesticação preserva HP e aliado; cancelamentos não removem criatura.
- Aliado segue/fica/defende; noite cria exatamente três inimigos no intervalo previsto.
- Contador só encerra onda após todos os spawns e neutralizações; aliado morto depois não conta duas vezes.
- Derrota é pela base; reinício limpa estado; vitória retorna ao dia.
- Artes/arena visíveis em jogo; HUD lê estado real; trilha repete sem duplicação.
- Entregue arquivos alterados, testes executados/resultados, limitações e roteiro manual de até 10 passos. Atualize tracker distinguindo implementado, teste técnico e aprovado pelo usuário.
- Gere uma lista das capturas/vídeo que o grupo deve anexar ao Trello. Não publique cards, mensagens, entrega acadêmica ou materiais externos por conta própria.

Comece agora pela inspeção do estado real e pelo Bloco 1. Não refaça a Unidade 3 por causa do histórico antigo. Antes de parar, conclua as verificações e correções técnicas cabíveis ao bloco e forneça um checkpoint concreto para o usuário testar.
