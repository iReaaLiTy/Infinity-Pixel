# Infinity Pixel — GDD da AC1

**Inity Pixel · versão 0.2 · 30/09/2026**  
Equipe: Murilo Cassetti, Heitor Crispim, Pedro Ferreira e Juan Carlos. Funções e Game Designer: **a confirmar**. Entrega informada: **04/10/2026, 23:59**, pelo Game Designer, via link do Trello.

## Conceito e recorte

Aventura 3D em terceira pessoa e defesa de território: enfraquecer uma criatura, formar um vínculo e posicioná-la para proteger um refúgio. A escolha é preservar um inimigo como aliado ou eliminá-lo. A domesticação mantém a vida restante; o jogador precisa apoiar seu aliado frágil.

A AC1 contém uma arena e uma onda de três inimigos, repetível depois da vitória. Não implementa níveis, inventário, expansão, segunda região, multiplayer, save ou compras. As referências históricas do grupo são Dungeon Defenders, ARK e World of Warcraft; a progressão de RPG dessas referências permanece fora desta entrega.

## História — proposta, não aprovação do grupo

Uma comunidade de um vale fantástico protege seu refúgio contra criaturas noturnas. Seu guardião aprende a formar vínculos com dinossauros e transforma ameaças em companheiros. O cristal âmbar, os estandartes e o lenço jade comunicam abrigo e vínculo. Humanos e dinossauros coexistem como fantasia; não há pretensão de reconstituição histórica. O nome exibido do jogo foi atualizado para **Infinity Pixel** a pedido do usuário; o grupo ainda precisa revisar a identidade. O protagonista segue sem nome próprio aprovado.

## Fluxo implementado

Menu → Jogar → encontro diurno → três ataques → E por 2 s → aliado segue → F no posto → N inicia noite → defesa → resultado.

Vitória só quando os três spawns já aconteceram e todas as ameaças foram mortas ou domesticadas. O estado global volta ao dia, a tela “Noite defendida” permite continuar e os aliados sobreviventes permanecem. Novo encontro territorial aparece somente se o anterior deixou de ser selvagem.

A base com zero HP encerra a tentativa. Derrota oferece Reiniciar e Menu. Se a última ameaça e a base morrerem no mesmo quadro, derrota tem prioridade. Reinício limpa autoload, onda e cena; há um só diretor de áudio.

O encontro diurno já estava implementado nos arquivos recebidos: foi preservado, testado e integrado à apresentação. Se o jogador o matar, pode reiniciar pelo Esc ou enfrentar a onda e domesticar uma ameaça elegível. O encontro não ataca a base.

## Controles e estados

| Entrada | Ação |
|---|---|
| WASD | Mover, 6 m/s |
| Mouse | Câmera em terceira pessoa |
| Clique esquerdo | Golpe frontal por sobreposição, 20 de dano, 0,8 s de intervalo |
| E segurado | Canalizar domesticação por 2 s, até 3 m |
| F perto do aliado | Alternar seguir/ficar no dia; pode atingir mais de um aliado próximo |
| N | Iniciar noite durante a preparação |
| Esc | Pausar/retomar; Reiniciar, Menu e volume disponíveis na pausa |

Mouse capturado em jogo e livre nos menus. Pausa congela o mundo, cancela a canalização e mantém a música atenuada. Perda de foco pausa a partida. F não reposiciona aliados à noite; pausar não permite reposicioná-los. T permanece como recurso de depuração desabilitado por padrão, dispensável no core loop.

## Regras e valores preservados

| Sistema | Implementação |
|---|---|
| Jogador | Sem HP funcional; recebe feedback de ataque, mas não há barra fictícia nem derrota por morte do avatar |
| Selvagem | 80 HP; dano 15; velocidade 4 m/s; detecção 8 m; ataque a até 2 m, intervalo 1 s |
| Elegibilidade | Domesticável, vivo, com HP ≤30%; três golpes deixam 20/80; quatro matam |
| Canalização | Alvo travado durante o progresso; soltar E, sair do alcance, invalidar o alvo ou pausar cancela |
| Aliado | Mantém HP; segue por padrão; ficar defende raio de 8 m; sem dano amigável do jogador |
| Carnotauro | Variante provisória com `is_domesticable=false`, chifres e cor distinta; disponível como cena/teste, não adicionada à onda padrão |
| Base | 100 HP, sem regeneração automática entre noites |
| Onda | Três inimigos, intervalos de 2 s; domesticar neutraliza sem dupla contagem na morte posterior |
| Noite | Dano hostil ×1,30 (=19,5); velocidade ×1,20 (=4,8 m/s); sem bônus para aliados |
| Encontro | Territorial em (-10,+5), limite de perseguição de 12 m em torno da origem; não altera IA de onda |

Logs e HUD arredondam alguns valores para apresentação; o dano noturno usa 19,5 internamente. Valores não foram rebalanceados. O aliado recém-domesticado é frágil: avaliação de dificuldade depende do grupo.

## Level design aplicado

Arena de 40 × 40 m. Coordenadas X/Z: jogador (0,0), base (0,-15), entrada da onda (0,+15), encontro (-10,+5), posto (0,-7). Caminho central de terra de 8 m dentro de um corredor sem colisores de 10 m. Árvores, pedras e samambaias ocupam as laterais; arco sinaliza a entrada, cristal e estandartes marcam a base.

Quatro limites físicos evitam sair do piso. Decoração lateral não tem colisão de gameplay, preservando a IA de movimento direto. Grandes árvores próximas da câmera deixam de renderizar para reduzir oclusão. A câmera ainda precisa de avaliação humana nas bordas. Rochas distantes compõem o horizonte, sem segunda área jogável.

## Arte aplicada e referências

Direção de poucos polígonos, materiais foscos e silhuetas distintas. Guardião com túnica âmbar, lenço jade, bolsa, botas e machado de pedra. Dino bípede com focinho, cauda, crista e garras; ao domesticar, ganha colar jade e crista verde. Carnotauro tem chifres e paleta violeta. Personagens usam pivôs animados para passos, golpe, oscilação da cauda e feedback de dano/domesticação.

Modelos editáveis estão em `scenes/visuals/*.tscn`; fonte geradora em `tools/build_visuals.py`. Não são uma ilustração usada como modelo: há malhas reais instanciadas nas cenas existentes. Colisões e scripts de gameplay foram preservados.

Pranchas finais SVG/PNG em `docs/ac1/assets/final/`: guardião frente/lado/costas, variantes, iluminação dia/noite e identidade. Derivam das malhas e capturas reais para manter a referência coerente com o protótipo. A nova arte de apresentação ImageGen está em `assets/ui/keyart.png`, aplicada ao menu; é uma ilustração de direção artística, com detalhamento superior às malhas simples do jogo.

Paleta: verde profundo #102B2A, floresta #24554A, jade #69BE9B, âmbar #E7AE58, coral #C76C4C, creme #F2E8CE. Marca Inity Pixel no menu; ícone de cristal na aplicação; título do jogo em tipografia clara. Os SVGs antigos foram preservados como histórico, não como evidência da interface final.

## Interface

Menu com Jogar, Controles, Créditos, Sair e volume/silenciar. HUD usa base real, estado DIA/NOITE, spawns criados, ameaças neutralizadas/ativas, objetivo contextual, instruções e progresso real da domesticação. Sem números simulados. Verificação visual em 1280×720 e 1920×1080 documentada em `evidence/`.

## Música e áudio

Tema original **Passos do Refúgio**, 112 segundos, 120 BPM, ré menor, 56 compassos. Estrutura: 4 compassos de introdução, 16 de tema A, 16 de variação, 8 de ponte, 8 de retorno e 4 de transição. Melodia de flauta sintetizada, mallets, harmonia, baixo e percussão; sem samples de terceiros.

`refugio_principal.wav` é a composição de referência. `refugio_calm.wav` serve ao menu e ao dia; `refugio_combat.wav` muda densidade rítmica e intensidade na noite. Há sinais de vitória/derrota de 4 s e efeitos de golpe/vínculo. Fontes em `tools/compose_score.py`.

Um player de música faz saída e entrada suaves, evitando duas trilhas contínuas sobrepostas; um player separado toca sinais curtos. Buses Music/SFX; volume inicial conservador; pausa atenua a música e mantém a posição; mudo afeta ambos os buses. WAVs sem clipping na análise e amostras extremas compatíveis com loop. Playback na engine verificado; aprovação musical e emenda audível dependem de audição humana.

## Monetização — proposta conceitual

Protótipo acadêmico gratuito. Proposta para futura versão comercial: compra única com demonstração gratuita. Preço e expansão futura dependem de pesquisa e decisão do grupo. Sem loja, pagamentos, loot boxes ou venda de vantagem na AC1.

## Validação e entrega

32 verificações automatizadas passaram em modo headless e 35 com renderização no macOS. Cobrem menu clicável, câmera e ataque por mouse, canalização, cancelamento, alvo travado, HP preservado, aliado, ondas, vitória, derrota, reinícios, conexões e áudio. Uma demonstração automatizada de 34 s registrou golpes por overlap, domesticação, vitória e derrota real por ataques à base. Os testes não substituem playtest livre nem audição/aprovação do grupo.

Projeto completo, PCK e iniciador local preparados; PCK depende de uma Godot compatível. Templates de exportação não encontrados na máquina; aplicativo independente não entregue. Trello não publicado: link e funções não recebidos, nem autorização de escrita no quadro. Consulte `TESTES_AC1.md`, `MATRIZ_ENTREGA.md` e `TRELLO_E_ENTREGA.md`.
