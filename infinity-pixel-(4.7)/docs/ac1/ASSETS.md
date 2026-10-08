# Recursos e proveniência — entrega 0.2

Produção assistida por IA para a Inity Pixel. Não atribuir autoria manual a um integrante sem confirmação. Papéis e aprovação artística pertencem ao grupo. Os recursos iniciais foram preservados; não há texturas, modelos, fontes ou samples de terceiros adicionados ao jogo.

| Recurso final | Fonte editável | Destino efetivo |
|---|---|---|
| Guardião 3D, arma, bolsa, lenço | `scenes/visuals/guardian.tscn`, `tools/build_visuals.py` | `scenes/player/player.tscn` |
| Dino selvagem/aliado | `scenes/visuals/dino.tscn`, script de animação | `scenes/enemies/wild_dino.tscn`; colar e crista mudam na domesticação |
| Carnotauro | `scenes/visuals/carno.tscn` | Cena de variante não domesticável; teste, fora da onda padrão |
| Refúgio, árvores, pedras, posto e arco | `scenes/visuals/arena_art.tscn`, gerador Python | Arena real `scenes/world/prototype_area.tscn` |
| Passos do Refúgio: principal/calma/combate | `tools/compose_score.py` | WAVs em `assets/audio`; calma e combate carregadas por `audio_director.gd` |
| Vitória, derrota, golpe e vínculo | Mesmo compositor, sem samples | Players e buses reais na Godot |
| Arte de apresentação | ImageGen integrado; prompt preservado em `IMAGEGEN_PROMPT.txt` | `assets/ui/keyart.png`, fundo do menu |
| Marca de pixel e ícone de cristal | `assets/ui/inity_mark.svg`, `game_icon.svg` | Menu e ícone do projeto |
| Menu, HUD e telas de estado | `scenes/ui/main.gd` | Interface funcional; capturas em `evidence/` |
| Pranchas guardião, dinos, cenário e identidade | `assets/final/*.svg`, `tools/build_boards.py` | Galeria/documentação; PNGs para anexar ao Trello |
| Planta da arena | `assets/arena_planta.svg` | Coordenadas preservadas; esquema descrito no GDD |

Caminhos de código e recursos de jogo acima são relativos à raiz do projeto. Caminhos `assets/final` e `evidence` são relativos a esta pasta AC1.

## Técnicas e direitos

Malhas de primitivas com baixa subdivisão, materiais e animações por pivôs criados nesta execução. Colisores originais preservados. Arquivos TSCN permitem ajustar cada nó no editor; os geradores preservam a fonte procedural. A prancha do personagem é uma referência de modelagem com vistas do modelo implementado, não uma promessa de modelo futuro. Nenhum rig esquelético, captura de movimento ou asset store foi usado.

Ilustração de menu gerada com a ferramenta ImageGen integrada. Sem referência a artista ou imagem de terceiros. O arquivo PNG é a exportação raster; não há alegação de fonte vetorial/camadas desse bitmap. Fontes editáveis existem para modelos, interface, pranchas, ícones e áudio.

Composição original sintetizada em Python/numpy: 32 kHz, estéreo, PCM 16-bit. Tema de 112 s, duas mixagens de estado também de 112 s, sinais de 4 s. Resultados numéricos em `evidence/audio_metrics.json`: nenhum sample clipado; pico aproximadamente −2,85 dBFS antes do volume da engine. Playback/estado de loop testados; nenhuma ferramenta de audição avaliativa estava disponível ao assistente. Ouvir e aprovar musicalidade, ruídos, emenda e equilíbrio é tarefa humana pendente.

O vídeo `delivery/Demonstracao_AC1.avi` foi capturado pela Godot Movie Maker: 1027 frames, 30 FPS, 34,23 s, com áudio da engine. A demonstração reposiciona atores para enquadramento e usa ataques/canalização reais; é uma gravação automatizada, não playtest humano. As screenshots de cenário e turnarounds usam câmeras de apresentação explicitamente identificadas.

Godot Engine: licença MIT ([licença oficial](https://godotengine.org/license/)); editor e runtime não foram redistribuídos no pacote. O MCP de terceiros é ferramenta de desenvolvimento e não está incluído no jogo. A fonte padrão Godot e fontes do sistema são usadas sem copiar arquivos de fonte de terceiros. Os logos são propostas; não houve pesquisa de marca registrada. Confirmar regras da disciplina sobre crédito a ferramentas de IA.
