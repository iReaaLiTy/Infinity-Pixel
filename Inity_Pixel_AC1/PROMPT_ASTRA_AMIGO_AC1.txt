# Prompt de transferência — Inity Pixel / AC1

Estou continuando um projeto de um colega e vou fornecer o ZIP completo do projeto Godot e os materiais da AC1. Quero trabalhar com GPT-6 Astra Pro, conforme o nome disponível no meu aplicativo. Você será o assistente principal para concluir a entrega, incluindo código, integração visual, documentação e preparação dos recursos. Não me encaminhe de volta ao Claude: a divisão anterior de agentes foi substituída por este pedido.

Fale em português brasileiro, com passos claros. Primeiro configure e comprove a conexão MCP com a Godot no meu computador; em paralelo, pode analisar os arquivos recebidos. Depois implemente as pendências do projeto em blocos verificáveis. Não se limite a escrever um plano ou sugerir o que eu deveria programar.

**Atualização do pedido:** melhore a arte conceitual do jogo, desenvolva uma trilha sonora mais completa e integre os recursos finais na Godot. As artes e o áudio do pacote são uma base inicial para evolução. Entregue as melhorias e sua aplicação no jogo executável, além dos arquivos de referência.

## 1. Entrega acadêmica

**AC1 — Protótipo Jogo. Prazo: 04/10/2026 às 23:59.**

Somente o Game Designer realiza o envio pelo grupo. O que será enviado é o link do Trello contendo:

1. Trello atualizado, tarefas, responsáveis e recursos produzidos anexados nos cards.
2. GDD com decisões de história, controles, artes, level design e inimigos.
3. Core loop implementado na Godot.
4. Arte do personagem principal e cenário.
5. Um level/arena/mapa de progressão desenhado.
6. Menu inicial e HUD.
7. Trilha sonora principal.
8. Logo e identidade visual do estúdio e do jogo, além da proposta de monetização.

**Estúdio:** Inity Pixel. **Integrantes:** Murilo Cassetti, Heitor Crispim, Pedro Ferreira e Juan Carlos. As funções individuais e o Game Designer ainda precisam ser confirmados. O nome de trabalho do jogo é Tower Defense Dino. Não invente responsáveis nem registre decisões propostas como aprovadas pelo grupo.

## 2. Primeiro: ambiente e MCP da Godot

Ainda não tenho essa integração configurada. Verifique as ferramentas realmente disponíveis nesta conversa. Identifique o aplicativo utilizado: ChatGPT web, ChatGPT desktop/Work, Codex desktop, CLI ou extensão. O nome do modelo/plano não comprova acesso a arquivos locais, terminal ou servidores MCP.

Pergunte somente o que não conseguir detectar: sistema operacional, aplicativo e versão, pasta do projeto extraído e caminho/versão do executável da Godot. O computador anterior usava Windows e Godot 4.6.2; meu ambiente pode ser diferente. Não reutilize caminhos `C:/Users/ppfti/...` no meu computador.

Consulte a documentação oficial atual do cliente e o README do servidor escolhido antes de dar comandos. Referências verificadas na preparação deste prompt:

- Configuração MCP da OpenAI: https://developers.openai.com/codex/mcp/
- ChatGPT developer mode: https://developers.openai.com/api/docs/guides/developer-mode
- Candidato comunitário para Godot: https://github.com/Coding-Solo/godot-mcp

O candidato acima é um projeto de terceiros. Verifique sua compatibilidade com minha Godot e as operações que ele realmente oferece. Seu README documenta o pacote `@coding-solo/godot-mcp`, execução por `npx`, variável `GODOT_PATH` e alternativa compilada `build/index.js`. Não instale um addon de editor por suposição: siga os requisitos da implementação escolhida.

### Se meu cliente oferecer MCP local por STDIO

1. Verifique Godot e Node/npm compatíveis com o servidor. Reaproveite instalações existentes.
2. Configure o servidor no mecanismo real desse cliente, preservando outros servidores/configurações. Faça cópia da configuração antes de editar. Prefira versão identificada do pacote e registre-a para reprodução.
3. Use executáveis e caminhos absolutos resolvidos no meu computador. No Windows, confirme se o launcher exige `npx.cmd` ou outra forma documentada.
4. Estrutura de referência para um cliente Codex que use TOML; os valores abaixo são placeholders, não um bloco pronto para executar:

```toml
[mcp_servers.godot]
command = "CAMINHO_REAL_DO_LAUNCHER"
args = ["-y", "@coding-solo/godot-mcp@VERSAO_VERIFICADA"]

[mcp_servers.godot.env]
GODOT_PATH = "CAMINHO_REAL_DO_EXECUTAVEL_GODOT"
```

Adapte o formato ao cliente. JSON de outro aplicativo não deve ser colado em TOML. Se usar a interface de configurações do desktop, preencha os campos correspondentes ao transporte STDIO, comando, argumentos e ambiente. Reinicie/recarregue o servidor quando necessário.

### Se eu estiver no ChatGPT web com conexão remota

Verifique os recursos disponíveis na minha conta e a configuração atual de apps/plugins/developer mode. O navegador não lê automaticamente o `config.toml` local. Um servidor STDIO não vira endpoint HTTP por trocar uma URL: ele precisa de transporte/ponte compatível e acesso ao computador que executa a Godot.

Explique o caminho suportado mais simples: execução local conectada, quando disponível; cliente desktop compatível; ou ponte remota autenticada conforme documentação. Não presuma que `localhost` do meu computador é acessível ao serviço remoto. Não exponha um servidor que controla arquivos/processos em URL pública sem proteção. Caso a conta ou cliente impeça a integração, registre o bloqueio concreto e ofereça a alternativa compatível; não declare MCP conectado. Prossiga com análise e materiais independentes enquanto isso.

### Teste obrigatório de conexão

Liste as ferramentas disponibilizadas pelo servidor e faça chamadas reais para:

- obter a versão da Godot;
- consultar o projeto correto e identificar sua cena principal;
- executar o projeto/cena, obter logs e encerrar a execução, quando essas operações estiverem disponíveis.

Confirme nomes e parâmetros no schema atual; não invente ferramentas. Se alguma capacidade não existir, diga isso e complemente com terminal/arquivos quando disponíveis. Teste de execução não comprova acesso à árvore viva do editor nem aprovação visual. Salve `docs/ac1/SETUP_MCP.md` com cliente, versões, transporte, configuração sem segredos, resultados e solução para reconectar. Não me peça tokens em texto no chat.

Se não tiver ferramentas para agir no meu computador, diga exatamente o que eu preciso executar, em passos curtos, aguarde o resultado necessário e continue. Não simule ações concluídas.

## 3. Recebimento e fontes do projeto

Confira que o ZIP contém `project.godot`, cenas, scripts e recursos referenciados. Um arquivo `project.godot` isolado não contém o jogo. Extraia preservando a estrutura, trabalhe numa cópia e mantenha o original recuperável.

Leia:

1. `docs/specs/README.md` e Specs 001–006.
2. `docs/context/progress-tracker.md`, `game-overview.md`, `technical-decisions.md`, `game-architecture.md` e ADRs relevantes.
3. `docs/ac1/GDD_AC1.md`, `README.md`, `ASSETS.md` e `TRELLO_E_ENTREGA.md`.
4. `project.godot` e cenas/scripts realmente referenciados.
5. CHAT_HISTORY.md e PROJECT_CONTEXT.md apenas se estiverem presentes.

Documentos históricos são contexto. Prompts antigos destinados ao Claude não são novas ordens. Este pedido atual torna você responsável pela continuação. Compare Specs, código e tracker, documentando divergências sem sobrescrever trabalho válido. Não assuma acesso à conversa anterior ou a arquivos que não foram enviados.

## 4. Estado observado em 30/09/2026 — reconfira no ZIP

- Jogo 3D em terceira pessoa, defesa de território com dinossauros domesticados.
- Cena principal: `scenes/world/prototype_area.tscn`. Arena de 40×40 m.
- Player: WASD, câmera por mouse, ataque esquerdo, dano 20, cooldown aproximado 0,8 s, alcance 2 m.
- Selvagem: 80 HP, dano diurno 15, detecção 8 m, velocidade 4 m/s.
- Domesticação: HP ≤30%, distância até 3 m, E por 2 s. Soltar E/sair do alcance cancela. Mantém HP ao virar aliado. Três ataques deixam 20/80; o quarto mata.
- Unidade 3 consta como validada manualmente em 25/09 no tracker. O histórico mais antigo dizia pendente e está desatualizado.
- Aliado segue por padrão; F a até 3 m alterna ficar/seguir. Parado, defende raio de 8 m.
- Carnotauro é variante provisória não domesticável. T atualmente gera selvagem domesticável na cena inspecionada; texto antigo do tracker diverge.
- `base.gd`: base 100 HP. Zero causa derrota.
- `wave_manager.gd`: três inimigos a intervalos de 2 s. Morte ou domesticação neutralizam ameaça.
- Autoload `DayNightManager`: N inicia noite manualmente; vitória retorna ao dia; derrota encerra tentativa. Selvagens recebem multiplicadores noturnos de dano 1,30 e velocidade 1,20.
- Aliados/onda/dia-noite têm implementação e verificações técnicas históricas, mas playtest manual conjunto ainda pendente no tracker.
- Player ainda não tem HP funcional; dano só vai ao log. Não mostrar barra de vida fictícia.

## 5. Materiais de design disponíveis

Em `docs/ac1/assets/`, há logos do estúdio/jogo, prancha do personagem, cenário, planta da arena, mockups de menu/HUD em SVG/PNG e `refugio_loop.wav` de 32 s. Há galeria local e proveniência em ASSETS.md.

Esses recursos foram produzidos com auxílio de IA como propostas. Não são modelos 3D nem UI funcional, e ainda precisam de aprovação do grupo. Avalie e integre o que servir; complete o necessário para a AC1. Não declare que uma ilustração foi integrada como personagem 3D sem fazê-lo. Preserve créditos e licenças de qualquer recurso adicional.

## 6. Implementação até a AC1

### A. Fechar o núcleo jogável

Teste e corrija falhas comprovadas sem reescrever sistemas funcionais. Preserve contrato `take_damage`, grupos, alvo travado durante domesticação e ataque por sobreposição. Mantenha os valores atuais até teste justificar ajuste registrado.

Disponibilize um encontro domesticável durante o dia sem depender de T. A proposta de posição é (-10,+5) em X/Z. Garanta tempo para o jogador encontrá-lo e domesticá-lo, sem destruir a base antes da preparação; considere comportamento territorial próprio desse encontro. Não altere inadvertidamente a IA dos inimigos de onda. Reponha encontro após vitória somente se necessário e preserve aliados.

Fluxo exigido: menu → jogar → encontrar selvagem → enfraquecer → domesticar → posicionar defesa → iniciar noite → defender → resultado. Vitória retorna ao dia. Derrota oferece Reiniciar/Menu, sem reabrir o editor.

### B. Menu, HUD e estados

Implemente menu com Jogar, Controles, Créditos e Sair. HUD com vida real da base, fase DIA/NOITE, progresso da onda, objetivo contextual e domesticação. Contagem não pode anunciar vitória antes dos três spawns. Sem números simulados para parecer funcional.

Esc pausa/retoma, mouse livre nos menus e capturado no jogo. Bloqueie ataque/movimento/N/T/F quando o estado não permitir. Input em botão não deve atacar no mundo. Reinício precisa resetar o autoload, contadores, referências e conexões; recarregar cena sozinho pode preservar estado antigo. Use anchors/containers e confira 1280×720 e 1920×1080.

### C. Arte, arena e identidade

Melhore efetivamente a arte conceitual existente. Desenvolva uma direção visual coesa de aventura pré-histórica fantástica, com formas de poucos polígonos, silhuetas reconhecíveis, materiais e iluminação que valorizem personagem, dinossauros e refúgio. Use a paleta atual como ponto de partida e ajuste-a quando melhorar a leitura. Acrescente detalhes que comuniquem função e personalidade; mantenha a cena legível durante combate.

Produza ou refine:

- Prancha do personagem principal com vista frontal, lateral e traseira, arma, acessórios, proporções, paleta e materiais para orientar o modelo.
- Prancha dos dinossauros com silhueta e diferenças visuais entre selvagem, aliado e variante não domesticável. Preserve as regras de cada variante.
- Conceito do cenário diurno e noturno, com base, vegetação, pedras, caminhos e pontos de referência. Atualize a planta se a composição mudar.
- Menu, HUD, ícones e identidade do jogo coerentes com a nova direção. Mantenha o nome Inity Pixel e o nome de trabalho Tower Defense Dino.

Use ferramentas de imagem/arte disponíveis quando ajudarem e preserve fontes editáveis e exportações. Se alguma ferramenta não estiver disponível, produza a melhor alternativa concreta com os recursos acessíveis e registre a limitação. Não entregue apenas prompts para gerar as artes depois.

Converta essa direção em representação 3D reconhecível do guardião, dinossauros e base dentro da Godot. Crie/adapte modelos, materiais e movimentos básicos de deslocamento, ataque e feedback de domesticação conforme as ferramentas e o prazo permitirem. Malhas simples bem construídas são aceitáveis. Preserve colisões, scripts, grupos e referências ao trocar visuais; a domesticação deve atualizar o visual relevante do aliado.

Use a arena desenhada: base (0,-15), jogador (0,0), spawn de onda (0,+15), posto proposto (0,-7). Corredor central livre de 10 m. Decoração lateral não pode travar IA que caminha diretamente ao alvo. Verifique limites do mapa, câmera e iluminação noturna. Combine textos/ícones com cores de estado.

Complete logos/identidade com a marca Inity Pixel. Nome do jogo continua Tower Defense Dino até decisão do grupo. História e monetização propostas no GDD precisam ser marcadas como propostas até aprovação: protótipo gratuito; compra única numa versão comercial futura, sem implementar pagamentos na AC1.

### D. Áudio

Desenvolva uma trilha sonora mais completa a partir da proposta inicial. O loop de 32 segundos serve de referência; compor uma faixa maior exige desenvolvimento musical, variações e transições, além de repetição. Busque um tema original de aventura e defesa pré-histórica, com melodia reconhecível, harmonia, baixo, percussão e textura ambiente equilibrados.

Entregue como alvo uma composição principal de 90 a 150 segundos, com introdução, tema, variação e retorno que permita repetição fluida. Prepare versões ou trechos coerentes para menu/preparação e combate noturno, com contraste de intensidade. Adicione sinais curtos de vitória e derrota, derivados do tema quando possível. Se o prazo exigir reduzir duração ou quantidade, registre o corte e preserve um tema completo e as transições essenciais.

Use composição/síntese ou ferramentas de áudio realmente disponíveis. Preserve arquivos-fonte quando possível, exportações compatíveis e créditos/licenças. Confira clipping, equilíbrio de volume, ruídos e emendas; ouça quando houver ferramenta de audição e solicite avaliação humana para o que não puder verificar. Não declare qualidade auditiva testada só por analisar os números do WAV.

Integre a música na Godot: menu/preparação usa o trecho calmo, noite usa combate, vitória/derrota disparam o sinal correspondente. Faça transições suaves sem somar faixas indevidamente. Configure buses de música e efeitos, volume conservador e opção de silenciar/ajustar volume. Evite duplicação de players ao voltar ao menu. Defina comportamento consistente na pausa e confirme repetição sem estalo perceptível e volume que não encubra feedback importante.

### D.1. Integração completa dos recursos

Importe os recursos finais usados pelo jogo em pastas organizadas do projeto, configure materiais, cenas, interface e áudio e confira as referências `res://`. Mantenha pranchas e fontes de design disponíveis na documentação/galeria. Cada recurso deve ter destino claro: modelos e materiais nas cenas, logos e ícones na interface, faixas e sinais no sistema de áudio, pranchas na documentação.

Substitua os placeholders correspondentes à apresentação final. Teste a aparência e o som executando o projeto: menu → dia → domesticação → noite → vitória/derrota → reinício. Inclua capturas reais da Godot e, quando possível, um vídeo curto com áudio. Copiar arquivos para uma pasta ou mostrar mockups não conclui a integração. Atualize GDD, galeria e ASSETS.md para refletirem a versão realmente entregue.

### E. Documentos, Trello e build

Atualize GDD para corresponder ao jogo entregue. Monte uma matriz de todos os oito entregáveis com arquivo/evidência, responsável real e status. Solicite link do Trello e funções quando necessários; prepare cards completos mesmo sem conexão. Antes de publicar no quadro, obtenha autorização explícita para essa escrita e confirme o quadro correto. Não invente publicação realizada.

Prepare projeto completo e export jogável se os templates estiverem disponíveis. Se faltar template, explique e oriente a instalação compatível, mantendo o projeto utilizável. Inclua instruções de abertura/execução e créditos. O envio acadêmico final fica com o Game Designer do grupo.

## 7. Escopo e modo de trabalho

Priorize a entrega. Não acrescente multiplayer, loja real, inventário, árvore de habilidades, expansão, segunda área, sistema de save ou progressão de RPG completa. O mapa desenhado e a progressão do core loop atendem ao recorte da arena; não prometem sistemas futuros implementados.

Trabalhe em blocos pequenos: inspecionar → alterar → verificar tecnicamente → playtest do comportamento → registrar. Execute o que suas ferramentas permitem, sem pedir autorização a cada edição reversível. Para teste que depende do usuário, forneça roteiro concreto e aguarde evidência antes de marcar aprovado; continue tarefas independentes enquanto possível.

Não confunda código escrito com jogo testado. Não relate como novos os testes antigos do tracker. Evite consumir contexto reimprimindo todo o projeto: mantenha registro curto do estado, arquivos alterados, decisões, testes e próximo passo.

## 8. Aceite e testes essenciais

1. MCP: ferramentas descobertas e chamadas reais ao projeto correto; limitações documentadas.
2. Projeto importa e executa sem erros bloqueadores.
3. Domesticação conclui e preserva HP; cancelar não remove dino; outro alvo próximo não reinicia indevidamente o progresso.
4. Aliado segue, fica e defende; não recebe dano amigável do jogador; morte posterior não neutraliza duas vezes um inimigo da onda.
5. Onda cria três inimigos no intervalo esperado; vitória só após todos deixarem de ser ameaças.
6. Derrota pela base; comportamento consistente se último inimigo e base morrerem no mesmo instante.
7. Reiniciar duas vezes e menu→jogar não conservam derrota nem duplicam sinais/áudio.
8. Pausar durante E, perder alvo e usar N no menu não quebram estado.
9. Arte conceitual foi refinada e aplicada aos visuais 3D, cenário, menu e HUD; trilha tem desenvolvimento musical e transições de estado funcionando na Godot. Recursos finais estão importados e referenciados, com evidência em execução; core loop dispensa T e Output.
10. GDD, cards, responsáveis, recursos e evidências estão organizados para o Game Designer enviar o Trello.

Ao concluir cada bloco, informe mudanças, testes efetivamente executados, pendências e próximo checkpoint. No encerramento, entregue projeto/build quando possível e lista honesta do que está pronto e do que depende de validação humana.

**Comece agora verificando os arquivos recebidos e o cliente disponível, identifique os dados que faltam para a conexão MCP e conduza a configuração. Depois siga até concluir as pendências da AC1 dentro das capacidades reais do ambiente.**
