# Spec 009 — Registro de validação (2026-10-03)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.
Execução por CLI com caminho explícito; nenhuma alteração pelo MCP de destino
inconsistente. Arquivos atuais das Specs 007/008 preservados.

## Resultados automatizados

| Execução | Resultado |
|---|---|
| `tests/physics_contracts.tscn`, headless, física 60 Hz | 23/23 |
| `tests/physics_contracts.tscn`, renderização GL, física 60 Hz | 23/23 |
| `tests/acceptance.tscn`, headless | 33/33 |
| `tests/acceptance.tscn`, janela/renderização GL | 36/36 |

Relatórios finais de execução estão em `spec009-evidence/` (JSON). As capturas
da regressão ficaram em `%TEMP%/infinity-spec009-appdata/Godot/app_userdata/Infinity Pixel (4.7)/spec009-regression/`.
Não foram sobrescritas as evidências históricas em `docs/ac1/evidence`.

### Física e integração

- Cenas reais de Player/WildDino/Carnotauro e 66 StaticBody3D com primitivas,
  máscaras corretas e escala unitária.
- Cápsula do Player bloqueada em árvore, pedra, pilar e núcleo, por consulta
  `test_move` e por 45 passos reais de `move_and_slide` em cada aproximação.
- Movimento diagonal por 60 passos contra o limite lateral desliza sem atravessar.
- Câmera top-level/FOV preservados, rotação independente do Player, tecla W
  sintética movendo o personagem na direção da câmera.
- Clique sintético em painel da HUD não aciona cooldown. Controles abre na
  pausa e Voltar mantém a pausa.
- IA atual percorre spawn → base sem alvo interferindo e causa dano real:
  100 → 85 → 70 → 55. Colisor do núcleo permite alcançar distância de ataque.
- Conversão em aliado mantém máscara e 20 HP.

### Regressão de gameplay

A suíte acceptance existente confirmou inicialização/menu, clique de ataque
pelo cursor (execução com renderização), três golpes → 20/80, canalização E,
cancelamento ao soltar/afastar/pausar, alvo travado, conversão com HP preservado,
proteção de aliado, seguir/ficar/defender, Carnotauro não domesticável, noite,
três spawns escalonados, neutralização única, vitória sem pausa/modal, aliado
preservado, reposição do encontro, derrota/reinícios e prioridade de derrota
no mesmo quadro. Ver JSON para a lista de cada check.

## Diagnóstico e limites das evidências

- Nenhum erro de parsing, colisão ou física nas execuções finais.
- O ambiente restrito emite `Failed to read the root certificate store` no
  startup, inclusive nas duas suítes; não é um erro de física.
- A suíte acceptance headless ainda emite o aviso de ObjectDB no encerramento,
  já registrado no tracker anterior à Spec 009. A execução com renderização
  terminou sem esse aviso.
- A suíte física headless também apresenta aviso de encerramento de áudio;
  `--verbose` identifica AudioStreamPlaybackWAV/AudioStreamWAV e `bond.wav`
  ainda em uso. Não são corpos/shapes vazando. A suíte física com renderização
  encerrou sem esse aviso. Nenhum sistema de áudio foi alterado nesta Spec.
- O teste físico inicialmente usava IDs com hífen e aproximava Trunk0 por um
  trecho que atingia outra árvore. IDs corrigidos no gerador; aproximação de
  teste limitada ao sólido selecionado. Resultado final: 23/23.
- A primeira importação não conseguiu gravar cache fora do sandbox. Execuções
  seguintes usaram APPDATA/LOCALAPPDATA temporários; não se alterou configuração
  persistente do sistema. Não se utilizam esses erros iniciais como aprovação.
- Teste automatizado de input não equivale à avaliação humana da sensação de
  movimento, áudio, encaixe visual das primitivas ou todos os pontos do mapa.

## Reproduzir

Com o executável Godot configurado no PATH e terminal na raiz do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_collisions.ps1
godot --headless --path . --fixed-fps 60 res://tests/physics_contracts.tscn
godot --path . --rendering-method gl_compatibility res://tests/acceptance.tscn -- --evidence-dir=user://spec009-regression
```

O teste físico grava `user://spec009-physics.json`; aceita `-- --report=<arquivo>`.
Acceptance aceita `--evidence-dir` sem alterar sua pasta histórica por padrão.

## TESTE MANUAL NECESSÁRIO

1. Iniciar pelo menu; conferir câmera elevada, WASD e cursor.
2. Andar contra árvores e pedras de ambos os lados, pilares e núcleo do refúgio.
3. Contornar cada forma em diagonal; procurar quinas que prendam, bloqueios
   invisíveis distantes do mesh ou passagens estreitas injustas.
4. Dar três ataques em WildDino, segurar E, levar o aliado pelo corredor e usar F.
5. Abrir pausa → Controles → Voltar/ESC; retomar e iniciar noite com N.
6. Defender uma noite completa; confirmar retorno contínuo ao dia e aliados.
7. Em outra partida, permitir a queda do refúgio; confirmar derrota/reinício.

**Limitações conhecidas:** criaturas continuam sobrepondo-se e perseguindo
diretamente; obstáculos periféricos podem interromper perseguição/retorno.
Não há linha de visão para dano/domesticação. Plataforma/anel baixos permanecem
decorativos. Nenhuma dessas limitações foi encoberta por offsets ou nova IA.
Spec 010 permanece pendente de autorização após aprovação manual da Spec 009.
