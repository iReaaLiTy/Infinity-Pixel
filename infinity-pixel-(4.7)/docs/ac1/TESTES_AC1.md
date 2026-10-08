# Verificação da AC1 — 30/09/2026

## Executado nesta sessão

- MCP STDIO real: descoberta de 386 ferramentas, leitura de versão/configuração, início headless, logs e parada. Ver `SETUP_MCP.md`.
- Importação do projeto na Godot 4.7.2. Correções de sintaxe TSCN realizadas até importação sem erro de parse.
- `tests/acceptance.tscn`: 32 verificações passaram em headless; 35 passaram com renderização OpenGL/Metal no macOS. As três adicionais clicam em Jogar e enviam movimento e clique do mouse pelo viewport real. Relatórios JSON em `evidence/acceptance_headless.json` e `acceptance_macOS.json`.
- Capturas do menu/HUD em 1280×720 e 1920×1080, pausa, domesticação, aliado e resultados; `tests/showcase.tscn` captura pranchas e cenário em execução.
- Demonstração de 34,23 s pelo Movie Maker, com áudio: ataques por overlap, domesticação, posicionamento F, onda, vitória, retorno ao dia, derrota por inimigos atacando a base (8,5 s após iniciar a tentativa de derrota) e reinício. O roteiro reposiciona atores para filmagem e não representa playtest humano.
- PCK exportado e inicialização testada pela Godot instalada. Sem aplicativo standalone, pois templates ausentes.
- Após a mudança de nome para Infinity Pixel, menu e galeria foram atualizados, as 35 verificações gráficas passaram novamente, a demonstração foi regravada e `InfinityPixel.pck` iniciou sem erro.
- WAVs: duração, canais, pico, RMS, samples clipados e descontinuidade das extremidades analisados. Sem clipping; loop marcado e playback verificado na engine. Qualidade auditiva não foi aprovada por análise numérica.

## Cobertura automatizada

N no menu; clique em Jogar no macOS; encontro territorial; base preservada na preparação; movimento do mouse gira a câmera e clique esquerdo ataca no macOS; três ataques deixam 20/80; E inicia; soltar cancela; pausa cancela sem prender alvo; N bloqueado em pausa; alvo travado com outro elegível próximo; HP mantido; visual aliado; dano amigável filtrado; seguir; F ficar; defesa automática; primeiro spawn; conversão/morte posterior sem dupla neutralização; três spawns em intervalos próximos de 2 s; vitória somente após três; aliado preservado; encontro reposto no dia; derrota/reinício duas vezes; cancelamento por distância; Carnotauro inelegível; derrota prioritária no mesmo quadro; diretor de áudio único; conexões sem acúmulo; playback em loop; mudo real.

Após relato de mouse inoperante no MacBook, a camada raiz da interface passou a ignorar eventos de mouse e o jogador passou a recebê-los em `_input`. Isso corrige câmera e golpe; E requer três golpes no selvagem, e F requer um aliado a até 3 m durante o dia. O teste gráfico confirma a cadeia completa até domesticar e comandar o aliado.

A suíte organiza posições, congela alguns alvos para isolar hipóteses e usa chamadas de dano para cenários de resultado. A demonstração complementar usa ataques normais e a IA real contra a base. Nenhum desses testes equivale a validação humana de dificuldade, sensação de controle ou música.

## Playtest humano pendente — roteiro concreto

1. Abrir o menu, Controles e Créditos; ajustar volume. Começar sem tecla T.
2. Ir até o encontro em (-10,+5), girando a câmera com o mouse. Observar colisões nas bordas e árvores próximas da câmera.
3. Dar três golpes. Segurar E e soltar antes de 2 s: cancelar. Repetir e sair do alcance: cancelar. Repetir e pausar: cancelar sem prender o dino.
4. Concluir E. Confirmar aliado com 20/80, colar jade e estado seguir. Atacar perto dele e verificar ausência de dano amigável.
5. Levar ao posto (0,-7), pressionar F, iniciar N. Apoiar o aliado: ele tem pouca vida. Confirmar três spawns e resultado após neutralizar todos.
6. Continuar no dia: aliado sobrevivente permanece e encontro necessário reaparece. Reiniciar duas vezes, voltar ao menu e jogar novamente.
7. Outra tentativa: ficar longe do corredor e deixar a base cair; conferir Derrota → Reiniciar/Menu.
8. Ouvir tema completo e passagem 112→0 s; trocar dia/noite, pausar, silenciar, voltar ao menu. Avaliar timbre, volume, ruído e transições em fone/alto-falante.
9. Anotar dispositivo, resolução, versão Godot, passos, esperado/observado e evidência. Só marcar “aprovado” quando o grupo confirmar.

## Limitações observadas

Player continua sem HP: não há invulnerabilidade temporária/respawn implementados nem barra fictícia. A força dos aliados a 20 HP merece avaliação humana. Alguns logs arredondam dano 19,5 para 20. Aviso de duas instâncias ObjectDB no encerramento apareceu em algumas execuções; não houve erro de gameplay bloqueador. Limpeza de players de áudio no encerramento foi acrescentada e os logs finais são preservados.

Testes históricos de setembro no tracker foram mantidos como históricos. Resultados acima são desta execução.

## Reproduzir

```sh
"/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/juancarlos/Downloads/jogo/Tower Defense" res://tests/acceptance.tscn
```

Para capturas, executar `res://tests/showcase.tscn` com janela. Para vídeo, usar `--fixed-fps 30 --write-movie demonstracao.avi res://tests/demo.tscn`. Essas cenas são de teste e ficam excluídas do PCK.
