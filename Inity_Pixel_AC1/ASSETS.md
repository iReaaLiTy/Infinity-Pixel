# Recursos e proveniência

Todos os recursos desta pasta foram produzidos nesta sessão com auxílio de IA para a proposta acadêmica da Inity Pixel. Não há imagens, fontes ou samples baixados de terceiros. Não declarar autoria manual de um integrante que não fez o recurso. Conferir as regras da disciplina sobre uso de IA e registrar as ferramentas na entrega.

| Recurso | Uso e formato |
|---|---|
| logo_inity_pixel.svg | Marca do estúdio; vetor, fundo transparente |
| logo_jogo.svg | Nome de trabalho do jogo; vetor, fundo transparente |
| personagem.svg | Prancha conceitual 2D do guardião; referência de modelagem |
| cenario.svg | Ilustração conceitual da clareira; referência de ambiente |
| arena_planta.svg | Planta 40×40 m, coordenadas e circulação |
| menu.svg / hud.svg | Mockups; não são interface funcional |
| refugio_loop.wav | Composição/síntese procedural original, estéreo PCM 16-bit, 44,1 kHz, 32 s |

`gerar_assets.py` preserva as formas vetoriais e a composição procedural para edição/reprodução. SVG usa fontes locais de sistema, sem redistribuir arquivos de fonte. Logos são propostas; não foi feita pesquisa de registro de marca.

Há versões PNG dos sete SVGs para anexar ao Trello e visualizar sem editor vetorial. `preview.png` reúne as pranchas para revisão. SVGs foram validados como XML e renderizados; a prévia foi inspecionada visualmente. WAV foi verificado quanto a duração, canais e frequência de amostragem, sem aprovação auditiva humana nesta sessão.

Áudio: 120 BPM, 16 compassos, progressão Dm–Bb–F–C repetida quatro vezes. Camadas: motivo pentatônico, baixo, acordes suaves, pulso grave e ruído percussivo gerado numericamente. Render com caudas circulares e limitação de pico; não usa referência a artista. Aprovação musical depende de audição humana. Para importar na Godot, habilitar loop no WAV e validar a passagem final→início.
