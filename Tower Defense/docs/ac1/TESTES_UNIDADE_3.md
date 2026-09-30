# Unidade 3 — revalidação de 30/09/2026

**Status: correções técnicas verificadas; playtest humano pendente.**
O usuário reabriu a unidade. A aprovação histórica de 25/09 é preservada
como histórico, sem encerrar esta revisão. Câmera, movimento, colisões,
construção, dano, HP, alcance de 3 m e duração de 2 s não foram alterados.

## Defeitos reproduzidos e corrigidos

1. A canalização reconhecia E por ação, tecla física ou evento de teclado,
   mas o bloqueio do clique consultava apenas a ação. Com E lógico sem
   código físico, a canalização começava, mas um clique matava o alvo de
   20 HP. Chamadas diretas de `_try_attack()` também ignoravam E. Agora o
   bloqueio está na entrada do ataque e consulta a mesma leitura da
   canalização, antes de iniciar cooldown ou aplicar dano.
2. Um alvo com `queue_free()` pendente ainda era válido até sair da árvore.
   Se a canalização terminasse nesse intervalo, ele emitia conversão e era
   removido logo depois. Agora a validade também exige ausência de remoção
   pendente. O teste executa o último passo no mesmo quadro da solicitação
   de remoção para verificar essa condição de forma determinística.

Esses cenários foram reproduzidos com eventos sintéticos e cenas reais.
Isso não prova que sejam a causa de todos os relatos históricos de falha
de domesticação.

## Resultados desta revisão

Engine: **Godot 4.7.2**, macOS, Apple M4; janela com OpenGL/Metal.

| Verificação final | Resultado | Evidência |
|---|---|---|
| Regressão específica, headless | 26 passaram, 0 falharam | [JSON](evidence/domestication_headless.json) |
| Regressão específica, janela | 26 passaram, 0 falharam | [JSON](evidence/domestication_macOS.json) |
| Integração AC1, headless | 32 passaram, 0 falharam | [JSON](evidence/acceptance_u3_headless.json) |
| Integração AC1, janela | 35 passaram, 0 falharam | [JSON](evidence/acceptance_u3_macOS.json) |

A suíte AC1 já passava antes da correção (32 verificações headless), mas
não cobria os defeitos acima. A primeira regressão específica apresentou
19 verificações aprovadas e 3 falhas: duas entradas de ataque e remoção
pendente. Ver [log anterior à correção](evidence/domestication_before.log).
A suíte final inclui também retorno do ataque após soltar E e preservação
do aliado pelo gatilho T. Não se trata de 119 cenários distintos: há
cobertura repetida entre execuções com e sem janela.

A regressão específica cobre HP acima do limiar, três golpes, aviso,
E físico e alternativo, ataque bloqueado sem cooldown, retorno do ataque,
seleção entre vários alvos, alvo travado, conversão com HP preservado,
Carnotauro sem falsa opção, T desligado/ligado, cancelamento por distância,
pausa, foco, morte, remoção e derrota. A integração preserva verificações
de seguir/ficar, defesa, dano amigável, ondas, vitória, derrota e reinício.

Limites: atores são reposicionados e alguns têm física suspensa para
isolar hipóteses; foco é simulado por notificação. A execução gráfica usa
cliques pelo viewport, sem operador humano. A qualidade dos controles,
leitura visual e dificuldade continuam exigindo playtest humano.
As execuções headless emitiram diagnóstico de certificados do macOS;
a integração headless também reportou duas instâncias ObjectDB no
encerramento. Todos os processos finais saíram com código 0 e não houve
erro de script. O diagnóstico ObjectDB já consta no histórico da AC1.

## Reproduzir

Executar a regressão específica:

```sh
"/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/juancarlos/Documents/GitHub/Infinity-Pixel/Tower Defense" res://tests/domestication_regression.tscn
```

Remover `--headless` para a janela; evitar trocar o foco durante a execução.
Os relatórios específicos são gravados em `docs/ac1/evidence/`.

Para executar a integração sem sobrescrever capturas históricas:

```sh
mkdir -p /tmp/infinity-pixel-u3-acceptance
INFINITY_PIXEL_EVIDENCE_DIR=/tmp/infinity-pixel-u3-acceptance "/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path "/Users/juancarlos/Documents/GitHub/Infinity-Pixel/Tower Defense" res://tests/acceptance.tscn
```

Remover `--headless` para incluir os testes de clique e movimento do mouse.
O diretório indicado deve existir. Os JSON finais desta execução foram
copiados para `evidence/acceptance_u3_*.json`; as capturas antigas permanecem.

## Playtest humano para fechar a unidade

1. Abrir este projeto na Godot. F5 → Jogar. Confirmar WASD, câmera e golpe.
   Encontrar o selvagem à esquerda, próximo de (-10, +5); T é dispensável.
2. Com o selvagem saudável, E não deve mostrar opção ou progresso. Dar
   três golpes, respeitando 0,8 s de cooldown: 80 → 60 → 40 → 20 HP.
3. A até 3 m, iniciar E e soltar antes de 2 s. Repetir afastando-se.
   Em ambos os casos, progresso zera e o selvagem volta a agir.
4. Iniciar E, pausar com Esc e soltar E durante a pausa. Retomar: não pode
   continuar sozinho. Repetir trocando de janela e voltando ao jogo.
5. Segurar E e clicar antes de concluir: o clique não deve tirar HP.
   Manter E por 2 s: aliado permanece com 20/80, recebe visual de aliado,
   segue o Player e deixa de atacá-lo. Observar por cerca de 10 s sem ondas.
6. Atacar perto do aliado: não deve perder HP. No dia, F a até 3 m alterna
   seguir/ficar. Em outra tentativa, sem segurar E, o quarto golpe deve
   matar normalmente. Não confundir morte posterior por hostis com remoção
   causada pela domesticação.
7. Registrar dispositivo, passos, esperado/observado e confirmação visual.
   Só marcar a Unidade 3 como concluída após aprovação humana explícita.

Carnotauro e múltiplos alvos têm cobertura técnica na cena de regressão.
Para inspecionar o Carnotauro manualmente, usar o Inspector **remoto** do
`WaveTestTrigger` na partida em debug: ligar `debug_enabled`, configurar
`enemy_scene` para `carnotauro.tscn` e pressionar T. A alteração remota não
precisa ser salva no projeto. Enfraquecê-lo e segurar E não deve mostrar
aviso, progresso ou conversão.

Diagnóstico opcional: `DEBUG := true` em `domestication_channel.gd` mostra
`v6-entrada-e-ciclo-de-vida`; no padrão `false`, logs de início, cancelamento
e conclusão continuam disponíveis. O executável/PCK em `delivery/` não foi
reexportado; este playtest deve usar o projeto-fonte atualizado.
