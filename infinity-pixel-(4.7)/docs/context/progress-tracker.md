# Progress Tracker

## Ciclo 1 — Núcleo Jogável

### Unidade 1 — Setup do projeto Godot + Spec 001 (controle do jogador)

**Status:** CONCLUÍDA — playtest aprovado em 2026-09-18.

**O que foi implementado:**
- Projeto Godot 4 criado (`project.godot`).
- `scenes/player/player.tscn` + `player.gd`: RF-AGE-001 (movimento 3D livre,
  câmera terceira pessoa) e RF-AGE-002 (ataque corpo a corpo com alcance,
  cooldown e dano).
- `scenes/test/damage_dummy.tscn` + `damage_dummy.gd`: alvo de teste
  temporário (não é parte de nenhuma Spec). Ainda existe como arquivo, mas
  não está mais instanciado em `prototype_area.tscn` desde a Unidade 2.
- `scenes/world/prototype_area.tscn`: cena principal do Ciclo 1.

**Resultado do playtest (2026-09-18):**
- WASD: funcionando. Câmera com o mouse: funcionando.
- Ataque com o botão esquerdo: **falhou na primeira rodada** (nenhum efeito
  visível). Correção aplicada: ação `attack` criada no Input Map
  (`project.godot`), golpe passou a consultar `get_overlapping_bodies()` no
  momento do clique (em vez de lista mantida por sinais) e ganhou log no
  Output. Segunda rodada: ataque acionado, alvo atingido, 20 de dano
  recebido — **aprovado**.
- Valores provisórios (6 m/s, 2 m, 0,8 s, 20 de dano): ainda sem avaliação
  de "sensação" registrada — o playtest só validou que a mecânica funciona.

### Unidade 2 — Spec 002 (dinossauro selvagem)

**Status:** CONCLUÍDA — playtest aprovado em 2026-09-18.

**Resultado do playtest (2026-09-18), todos OK:** apenas um WildDino ativo por
vez; spawn com T; caminhada até o território; detecção e perseguição do
jogador; ataque de 15 de dano com cooldown de 1 s; ataque do jogador; HP
descendo de 20 em 20; perda do alvo ao se afastar e retorno ao território;
morte após 80 HP; novo spawn depois da morte. Falhas encontradas e
corrigidas no caminho: referência nula ao ponto de spawn (ver abaixo) e
acúmulo de vários inimigos ao apertar T. Sensação dos valores (80 HP, 15 de
dano, 1 s, 8 m, 4 m/s) ainda sem avaliação registrada.

**Histórico da implementação:**

**O que foi implementado:**
- `scenes/enemies/wild_dino.tscn` + `wild_dino.gd`: RF-AGE-003 (avança
  automaticamente ao território) e RF-AGE-004 (detecta jogador/domesticado a
  8 m, persegue e ataca o mais próximo, cooldown de 1 s, volta a avançar se
  o alvo morre ou sai do alcance). Valores: 80 HP, 15 de dano, 1 s, 8 m,
  4 m/s. Rótulo de HP sobre o inimigo (feedback temporário de playtest).
- `scenes/test/wave_test_trigger.gd`: gatilho **temporário** (tecla T) que
  spawna um dinossauro. Será substituído pela onda real (Spec 005). Antes de
  apertar T, nenhum inimigo existe no mapa (RF-AGE-003, 1º critério).
- `scenes/world/prototype_area.tscn`: adicionados marcador de território
  (`Territory`, grupo `territory`, em z=-15), ponto de spawn (z=+15) e o
  gatilho de teste. O alvo de teste da Unidade 1 foi removido da cena.
- `player.gd`: entra nos grupos `player` e `damageable`; `take_damage()`
  provisório que só imprime o dano. `player.tscn`: `collision_mask` 1 → 5
  (passa a colidir com criaturas, layer 3).
- `project.godot`: ação `test_spawn_enemy` (tecla T).

**Correções pós-playtest (2026-09-18):**
- `wave_test_trigger.gd`: referência nula ao ponto de spawn corrigida
  (`NodePath` + `get_node_or_null`). Depois, T acumulava vários inimigos;
  agora o gatilho guarda o inimigo de teste atual e o remove antes de criar
  outro (no máximo 1 ativo, T também reinicia o teste). Vale só para o
  gatilho temporário; a lógica de onda da Spec 005 é independente.
- O inimigo de teste recebe o nome `WildDino` para logs legíveis.
- Confirmado por leitura: nenhum log roda a cada quadro em `wild_dino.gd`.

**Decisões pendentes devolvidas ao Game Design (não inventadas):**
1. Vida do jogador, morte e respawn: só existe a regra "morte não é derrota"
   (`technical-decisions.md`). Sem valores, o jogador não tem HP nesta unidade.
2. Alcance do golpe do inimigo: a Spec 002 só define alcance de detecção
   (8 m). Usado 2 m provisoriamente (constante `ATTACK_REACH`).
3. "Para de avançar e ataca": interpretado como perseguir até o alcance do
   golpe. Confirmar se é essa a intenção.
4. Ao chegar no território o inimigo só para e registra no log. Dano à base é
   da Spec 005.

### Unidade 3 — Spec 003 (domesticação)

**Status:** CONCLUÍDA — playtest manual aprovado em 2026-09-25, após a
correção do 4º relato. Ver "4º relato" e "Playtest manual da correção" abaixo.
Os logs `[DEBUG DOMESTICACAO]` seguem ligados (`DEBUG := true`) até o grupo
decidir desligá-los.

**Status anterior:** implementada e validada em playtest (2026-09-23) — bug de
domesticação (E não registrava, dino morria por ataque normal do jogador)
diagnosticado e corrigido. RF-AGE-017 (`is_domesticable`) adicionado na mesma
sessão — ver Unidade 4.

**O que foi implementado:**
- `scenes/player/domestication_channel.gd` (nó `DomesticationChannel` filho
  do Player): RF-AGE-005 e RF-AGE-006. Procura o dinossauro selvagem mais
  próximo dentro de 3 m; se a vida estiver em ≤ 30% (≤ 24 de 80 HP) mostra
  "Segure E para domesticar"; segurando E por 2 s, converte. Soltar E ou
  afastar-se (> 3 m, ou trocar de alvo) zera o progresso.
- `wild_dino.gd`: `can_be_domesticated()`, `domesticate()` e `set_prompt()`.
  Ao domesticar: sai do grupo `wild_dino`, entra em `domesticated`, para de
  atacar e de avançar, fica verde e é renomeado `DinoDomesticado`. Mantém o
  HP atual. Seguir/ficar/defender são da Unidade 4 (Spec 004).
- `wild_dino.tscn`: `PromptLabel3D` (aviso sobre a cabeça, feedback
  temporário).
- `project.godot`: ação `domesticate` (tecla E).
- `wave_test_trigger.gd`: T só remove o dinossauro **selvagem** anterior; um
  aliado domesticado permanece no mapa.

**Bug relatado no 1º playtest:** com o dinossauro em 20/80 HP e o texto "Segure
E" visível, segurar E por ~2 s não concluiu a domesticação; ele continuou
atacando e morreu (o playtester deu um 4º golpe com o mouse, 20 → 0).
Análise: sem conflito entre E e ataque/morte; suspeita de que a ação
`domesticate` não estava carregada na sessão do editor. Correção: E lido
também via `Input.is_physical_key_pressed(KEY_E)` (como o WASD) e logs de
início/conclusão da canalização. Aguardando reteste.

**2º playtest (mesmo bug):** nenhum log de canalização apareceu. Simulação
headless (Godot 4.6.2 console, script fora do projeto) com o código em disco
concluiu a domesticação em ~2 s (HP mantido, dino permanece, fica verde,
para de atacar), então a lógica está correta e o problema está em o E real
não chegar ao script ou o Godot rodar versão antiga dos arquivos. Adicionados
logs `[DEBUG DOMESTICACAO]` temporários (com intervalo de 0,5 s), aviso de
versão do script na inicialização (`v3-diagnostico`) e detecção do E também
por evento (`_input`). Remover os logs após a validação.

**3º playtest — resolvido (2026-09-23):** confirmado que a tecla E estava
sendo detectada corretamente (`E pressionado: true` nos logs). A morte
relatada era um golpe de ataque normal do jogador enquanto E **não** estava
pressionado no momento — comportamento correto (combate deve funcionar
normalmente fora da canalização). Corrigido no mesmo playtest: WildDino
ganhou o estado `is_being_domesticated`, que zera velocidade e impede
perseguição/ataque durante a canalização (antes só existia o bloqueio do
ataque do Player via `player.gd`). Domesticação completa validada
ponta-a-ponta (0.5/1.0/1.5/2.0s de progresso, `Estado: DOMESTICADO`, HP
mantido, dino não morre, para de atacar). Logs `[DEBUG DOMESTICACAO]`
mantidos por enquanto (ver item de limpeza pendente).

**4º relato (2026-09-25) — reaberta, AGUARDANDO VALIDAÇÃO MANUAL:** com
20/80 HP, segurar E não concluía; às vezes nem havia log de início, às vezes
o dinossauro morria ou sumia. Não havia MCP da Godot configurado nesta sessão
(`mcpServers` vazio). A investigação foi feita pelos arquivos e por
simulação headless (`Godot_v4.6.2_console --headless --script`, cena
`prototype_area.tscn` real, T/E enviados como eventos de teclado). Com o
código anterior, 7 verificações falharam. Causas comprovadas:
1. **T spawnava o Carnotauro** (`is_domesticable = false`), repontado na
   Unidade 4. Ele nunca fica elegível: sem aviso, sem log de início, e um
   novo T o remove ("sumiu"). Continuar atacando o mata (morte normal).
2. **Alvo = selvagem mais próximo, elegível ou não:** um selvagem com HP
   cheio mais perto que o de 20 HP apagava o aviso e bloqueava o E.
3. **Troca de alvo zerava o progresso:** com dois elegíveis a ≤ 3 m (ex.:
   onda), a alternância do "mais próximo" cancelava a canalização
   continuamente.
Correção: `WaveTestTrigger.enemy_scene` voltou para `wild_dino.tscn`;
`domestication_channel.gd` (v5-alvo-elegivel) escolhe o selvagem **elegível**
mais próximo e **trava o alvo** durante a canalização. O cancelamento só
acontece se E for solto, se o jogador sair do alcance ou se o alvo se tornar
inválido. O motivo sempre é registrado no log. Os logs de diagnóstico agora
aparecem só em mudanças de estado.
Verificação headless após a correção: 26/26 OK (fluxo T → 3 golpes → E 2 s;
aliado permanece, 20/80, verde, fora de `wild_dino`, não ataca nem vai ao
Territory; T preserva o aliado; soltar E e sair do alcance cancelam e zeram;
selvagem de 80 HP mais perto não bloqueia; dois elegíveis não zeram;
selvagem morre com 4 golpes; Carnotauro continua não elegível). **Não
substitui o playtest manual.**
Efeito colateral na Unidade 4: T não gera mais o Carnotauro. Para testar a
RF-AGE-017, troque `enemy_scene` do `WaveTestTrigger` no Inspector.

**Playtest manual da correção (2026-09-25) — resultados demonstrados:**

*Confirmado por logs do Output (editor, `v5-alvo-elegivel`):*
- A ação `domesticate` chega ao script, o Player é encontrado e o WildDino
  com 20/80 HP é reconhecido como elegível.
- Soltar E cancela: `cancelada: tecla_liberada (progresso 1.3 s descartado)`.
- Sair do alcance cancela: `cancelada: fora_do_alcance`, 3 ocorrências (0.7 s,
  1.6 s e 0.2 s), com distâncias de 3.06 m e 3.10 m, acima do alcance de 3 m.
- Depois dos cancelamentos, a nova tentativa recomeçou em 0 e chegou a
  `progresso=2.0/2.0`, depois `WildDino foi domesticado com 20/80 HP (nao
  removido)` e `concluida: aliado=true hp=20/80`.
- T criou outro selvagem e **preservou o aliado** no momento do spawn.
- O desaparecimento posterior foi **morte em combate**, não remoção:
  `[ALIADO] recebeu 15 de dano. HP: 5/80`, depois `HP: 0/80` e
  `[ALIADO] DinoDomesticado foi derrotado`. Esse comportamento é previsto na
  Spec 002 (RF-AGE-004: o selvagem ataca domesticados) e na Spec 004 (o
  aliado pode ser ferido por hostis). Não é defeito, e HP, dano e regras de
  combate não foram alterados.

*Evidência visual disponível:* um print mostra o aliado verde no mapa.

*Indício, sem prova completa:* no último teste, sem criar outro selvagem, o
Output não mostrou ataque ao Player nem morte do aliado. A ausência de log
não prova o comportamento visual.

*Confirmado visualmente pelo playtester (2026-09-25):*
1. O texto de progresso ("Domesticando... x / 2.0 s") apareceu na tela
   durante a canalização.
2. Depois de concluir, e antes de criar novos inimigos, o aliado verde ficou
   cerca de 10 s com `HP 20/80`, sem atacar o Player e sem ir ao Territory.

*Modo SEGUINDO:* o aliado segue o jogador (`[ALIADO] Modo: SEGUINDO`).
Esse comportamento já existia antes desta correção. É a RF-AGE-007 da
Spec 004, implementada na Unidade 4 em 2026-09-23 (`wild_dino.gd`, sem
alteração nesta correção). Por isso, ao "não caminhar para o Territory",
o esperado é o aliado acompanhar o jogador. Nada foi expandido ou removido.

*Defeito comprovado pendente:* nenhum.

**Decisões pendentes devolvidas ao Game Design (não inventadas):**
1. Distância de "aproximar" e de "afastar-se" da domesticação: não está na
   Spec 003. Usado 3 m provisoriamente (`INTERACTION_RANGE`).
2. O que acontece com a vida do dinossauro ao domesticar (cura? mantém?):
   não definido. Mantém o HP atual.
3. Como o jogador vê a "opção de domesticação": não definido; usado texto 3D
   temporário sobre o dinossauro (UI real fica para ciclo de UI).

### Unidade 4 — Spec 004 (dinossauro domesticado) + RF-AGE-017 + Spec 006 (dia/noite) + Spec 005 (onda real)

**Status:** implementada; validada por verificação headless (chamadas diretas
via `godot --headless --script`, 27/27 checks OK); **aguardando playtest
manual no editor** para a parte de movimento/física (seguir, ficar, defesa
por área, timing real do spawn), que a verificação headless não cobre.

**O que foi implementado (2026-09-23):**
- `scenes/enemies/wild_dino.gd`: RF-AGE-007/008 (aliado segue o jogador por
  padrão; comando `command_stay` — tecla F, a até 3 m do aliado — faz ele
  ficar no ponto atual e defender um raio de 8 m contra `wild_dino`,
  retornando ao ponto quando o alvo morre ou sai do raio). RF-AGE-017:
  `@export var is_domesticable` consultado direto por `can_be_domesticated()`
  — sem checar nome de node/cena. RF-AGE-018: dano/velocidade recalculados a
  partir de `BASE_ATTACK_DAMAGE`/`BASE_SPEED` a cada chamada (nunca
  acumulam), usando `DayNightManager.night_damage_multiplier`/
  `night_speed_multiplier` só fora do estado de aliado. RF-AGE-012: ao
  chegar ao território, passa a atacar a Base com o mesmo padrão de cooldown
  do ataque ao jogador (reaproveita `_try_attack`).
- `scenes/enemies/carnotauro.tscn` (novo): mesma cena/script do WildDino,
  `is_domesticable = false`, cor diferente (roxo escuro) só para
  identificação em teste. Nome "Carnotauro" é placeholder, sem arte final.
- `scenes/world/day_night_manager.gd` (novo, autoload `DayNightManager`):
  RF-AGE-013/014/015/016. Estados DIA/NOITE, `start_night()` acionado pela
  tecla N (ação `start_night`), `report_wave_victory()` (chamado pelo
  WaveManager) volta a DIA, `report_defeat()` (chamado pela Base) trava em
  fim de sessão sem retorno a DIA. Expõe `night_damage_multiplier = 1.30`,
  `night_speed_multiplier = 1.20`, `night_health_multiplier = 1.00`
  (PROVISÓRIO, configurável no Inspector).
- `scenes/world/base.gd` (novo, anexado ao node `Territory` já existente —
  não foi criado node novo nem renomeado): RF-AGE-012. `max_health = 100`
  (PROVISÓRIO), `take_damage()`, grupos `base`/`damageable`, aciona
  `DayNightManager.report_defeat()` ao chegar a 0 HP.
- `scenes/world/wave_manager.gd` (novo, node `WaveManager` em
  `prototype_area.tscn`): RF-AGE-010/011. Spawna 3 WildDino (domesticáveis)
  com 2 s de intervalo ao receber `night_started`; ao derrotar todos, chama
  `report_wave_victory()`.
- `scenes/test/wave_test_trigger.gd`: papel ajustado (comentário + remoção
  do rename fixo `"WildDino"`) — a tecla T agora spawna o **Carnotauro** (não
  domesticável) para testar RF-AGE-017 isoladamente; a onda real (3
  WildDino) é o `WaveManager`, disparado por N.
- `scenes/player/player.gd` e `scenes/player/domestication_channel.gd`:
  bloqueiam movimento/ataque/domesticação quando
  `DayNightManager.is_game_over` (RF-AGE-016).
- `project.godot`: `[autoload] DayNightManager`; ações `start_night` (N) e
  `command_stay` (F).
- `scenes/world/prototype_area.tscn`: node `WaveManager` adicionado; script
  da Base anexado ao `Territory`; `WaveTestTrigger.enemy_scene` repontado
  para `carnotauro.tscn`.

**Verificação headless (não substitui playtest manual):** script temporário
`godot --headless --script` chamou diretamente `can_be_domesticated()`,
`domesticate()`, `take_damage()`, `DayNightManager.start_night()/
report_wave_victory()/report_defeat()` e `Base.take_damage()` — 27/27
passaram, incluindo "buff noturno nunca acumula entre noites" e "dinossauro
`is_domesticable = false` nunca fica elegível mesmo com HP baixo". Não cobre
fisica de movimento (seguir/ficar/perseguir) nem o timing real de spawn —
isso precisa do editor.

**Decisões pendentes devolvidas ao Game Design (não inventadas):**
1. Distância de parar de seguir o aliado (2,5 m) e alcance do comando
   "ficar" (3 m): não estão na Spec 004. Provisórios.
2. Tecla do comando "ficar" (F) e de "Iniciar Noite" (N): não especificadas
   na Grill, escolhidas por analogia com a letra da palavra (como E para
   "domesticar").
3. Nome definitivo da variante não domesticável (hoje "Carnotauro",
   placeholder) — registrado em `003-domesticacao.md`.
4. Restart após derrota: não implementado (Spec 006 não define como) — hoje
   só reiniciando o projeto no editor.

**Próxima unidade recomendada:** playtest manual completo (Teste 1 a 9 do
pedido do aluno) no editor, focado principalmente em seguir/ficar/defesa por
área (RF-AGE-007/008) e no timing real da onda — únicas partes não cobertas
pela verificação headless.

## AC1 (entrega 04/10/2026) — integração de apresentação

Legenda: **implementado** (código no projeto) · **teste técnico** (headless,
Godot 4.6.2 console) · **aprovado pelo usuário** (playtest manual confirmado).

### Bloco 1 — núcleo e fluxo de apresentação

**Status:** implementado + teste técnico 38/38 OK (2026-09-30).
**Aprovado pelo usuário:** pendente (checkpoint de playtest do Bloco 1).

**Auditoria (2026-09-30):** núcleo de domesticação, alvo travado,
cancelamentos, seguir/ficar, defesa, dano à base, contagem da onda e retorno
ao dia estavam corretos na verificação. Lacunas comprovadas e corrigidas:
1. Não havia encontro diurno sem T → `EncounterSpawner` em (-10, +5).
2. F reposicionava aliados durante a noite, contrariando RF-AGE-009 (Spec
   005, CONFIRMADO) → F só vale de DIA (`DayNightManager.can_command_allies()`).
3. T não era desativável → `debug_enabled` no `WaveTestTrigger` + só em build
   de depuração; bloqueado no fim de jogo.

**Arquivos:** `scenes/world/encounter_spawner.gd` (novo),
`scenes/world/prototype_area.tscn` (nó `EncounterSpawner`),
`scenes/enemies/wild_dino.gd` (`territorial`, `leash_radius`, `home_position`,
sinal `command_rejected`, F bloqueado à noite), `day_night_manager.gd`
(`can_command_allies`), `scenes/test/wave_test_trigger.gd`.

**Comportamento do encontro (provisório, fora das Specs):** WildDino normal
(80 HP, mesmos valores) com `territorial = true`: não avança até a base; só
persegue jogador/aliado que esteja a até 12 m (`leash_radius`) do ponto de
origem e depois volta para ele. Inimigos de onda não mudaram. A cada novo DIA
o spawner cria outro encontro só se o anterior deixou de ser selvagem
(domesticado ou morto); aliados nunca são removidos. O encontro não conta
para a onda.

**Divergência documentada:** o texto histórico da Unidade 4 diz que T gera o
Carnotauro; o estado correto desde 2026-09-25 é T gerar o `wild_dino.tscn`
domesticável. O Carnotauro (`is_domesticable = false`) segue disponível
trocando `enemy_scene` no Inspector.

**Teste técnico (headless, cena real, teclas por `Input.parse_input_event`):**
encontro único no início sem T; parado sem jogador; persegue quando atraído;
volta à origem; nunca fere a base; 3 golpes reais (área de ataque) → 20/80;
soltar E e sair do alcance zeram sem remover a criatura; E 2 s domestica com
HP 20/80; F dia alterna ficar/seguir; N → noite; exatamente 3 spawns em
0,1/2,1/4,1 s; sem vitória antes do 3º spawn mesmo com 2 mortos; F à noite
ignorado; domesticar o último inimigo → vitória e DIA; novo dia repõe o
encontro domesticado e não duplica um ainda selvagem; ex-inimigo aliado morto
depois não altera a onda; T desligado não cria nada; derrota com base a 0
no último inimigo → fim de jogo, sem retorno ao dia, sem cura, WASD
bloqueado. **Não substitui o playtest manual** (sensação, câmera, física
real com o mouse).

## Como testar a Unidade 4 (dia/noite, aliado, buff noturno, base)

1. Rodar a cena principal (F5), Output visível.
> **Atualização 2026-09-25:** T voltou a spawnar o WildDino domesticável
> (correção da Unidade 3). Para os passos com Carnotauro abaixo, troque
> `WaveTestTrigger.enemy_scene` para `carnotauro.tscn` no Inspector.

2. **Teste 1 (regressão):** T ainda spawna o Carnotauro agora — para
   recriar o WildDino domesticável manualmente neste teste, use a onda
   (passo 5) ou reaproveite um WildDino já existente na cena. Reduza o HP a
   20/80, segure E por 2 s: deve completar (`Estado: DOMESTICADO`), sem
   atacar durante a canalização.
3. **Teste 2:** aperte T (spawna Carnotauro), reduza o HP a 20/80 (3
   golpes), aproxime-se e segure E: nada deve acontecer (sem prompt, sem
   progresso), e ele continua hostil.
4. **Teste 3 (aliado):** com um dino já domesticado, ele deve seguir você.
   Aproxime-se (≤3 m) e aperte F: ele para no lugar ("[ALIADO] ... vai FICAR
   em ..."). Traga um WildDino/Carnotauro hostil para perto (≤8 m do ponto
   onde ele ficou): o aliado deve ir atacar e voltar ao ponto depois.
5. **Teste 4/5/6:** aperte N ("Iniciar Noite"): estado muda para NOITE, 3
   WildDino spawnam com 2 s de intervalo (`[NOITE] Inimigo spawnado x/3`).
   Ataques e velocidade dos hostis devem estar visivelmente maiores (+30%
   dano, +20% velocidade) — o aliado não deve receber esse bônus.
6. **Teste 7/8:** derrote os 3 inimigos da onda: `[NOITE] ... Vitoria da
   noite`, estado volta a DIA, e os stats dos próximos hostis (se testar de
   novo) devem voltar ao valor-base exato (não acumular).
7. **Teste 9:** deixe um ou mais WildDino chegarem ao território (disco
   azul) sem impedi-los; eles devem atacá-lo repetidamente. Quando a Base
   chegar a 0 HP: `Base destruida — DERROTA`, e depois disso WASD/ataque/E
   não devem ter mais efeito (F5 para reiniciar).

## Como testar a Unidade 3

Diagnóstico: `const DEBUG := true` em `scenes/player/domestication_channel.gd`
(false desliga os logs `[DEBUG DOMESTICACAO]`; os logs `[Domesticacao]` de
início/cancelamento/conclusão continuam). Ao rodar, o Output deve mostrar
`script carregado (v5-alvo-elegivel)`; outra versão = editor com arquivo antigo.

1. F5 na cena principal (`prototype_area.tscn`), Output visível. Confirmar
   WASD, câmera e ataque.
2. T: WildDino **vermelho** (não roxo). Atacar 3 vezes: 80 → 60 → 40 → 20.
3. Parar de atacar, ficar a ≤ 3 m: aparece "Segure E para domesticar".
4. Segurar E menos de 2 s e soltar: `cancelada: tecla_liberada`, sem dano.
5. Segurar E de novo e afastar-se (> 3 m): `cancelada: fora_do_alcance`;
   ao voltar, a nova tentativa recomeça em 0.
6. Segurar E por 2 s parado: o progresso sobe no texto e no log e
   `concluida: aliado=true hp=20/80` aparece no log.
7. Conferir: continua no mapa, verde, `HP 20/80`, não ataca o jogador, não
   vai ao Territory (segue o jogador — comportamento da Unidade 4).
8. T: aliado permanece; surge novo WildDino com 80 HP e IA normal. Atenção:
   pela Spec 002 o selvagem ataca aliados; com 20 HP o aliado morre em 2
   golpes se o selvagem o alcançar.
9. No novo selvagem: perseguição/ataque/retorno normais e morte com 4 golpes.

## Como testar a Unidade 2

1. Rodar a cena principal (F5), Output visível.
2. Explorar o mapa: não deve existir nenhum inimigo.
3. Apertar **T**: aparece um dinossauro vermelho em z=+15 e o log mostra o
   spawn. Ele caminha em direção ao disco azul (território, z=-15).
4. Ficar longe da rota (> 8 m): ele passa direto e log "chegou ao
   território" ao alcançar o disco.
5. Repetir com T e entrar a menos de 8 m: ele desvia, persegue e ataca a cada
   1 s (`[Player] recebeu 15 de dano`), sem atacar mais rápido que isso.
6. Atacar de volta (botão esquerdo): 4 golpes de 20 derrubam os 80 HP; o
   rótulo de HP desce e ele some ao morrer.
7. Afastar-se > 8 m durante a perseguição: ele volta a caminhar ao território.

## AC1 — integração 0.2 em 30/09/2026 (nova execução)

Pedido atual substituiu a divisão histórica entre assistentes. Backup do projeto feito antes das alterações. O encontro territorial já existia ao iniciar esta execução; foi preservado.

Implementados menu/HUD/resultados/pausa/volume, reset de sessão, cancelamento de E por estado/foco, vitória diferida com prioridade da base destruída, modelos 3D e cenário, key art aplicada ao menu, trilha de 112 s e mixagens de estado. Gameplay e valores-base preservados. T desabilitado por padrão.

Verificados nesta sessão: MCP STDIO (386 ferramentas + versão/config/run/log/stop), importação, 32 checks automatizados headless e com janela, captura em duas resoluções, demonstração com ataques/IA reais, exportação e startup do PCK. Os testes de setembro registrados acima continuam sendo históricos.

Divergências documentadas: `game-overview` ainda descreve progressão/segunda área futuras; AC1 usa uma arena. Spec 002 trata inimigos de onda; encontro diurno é territorial e independente. Spec 005 proíbe pausa para reposicionar: pausa AC1 congela tudo e não permite F noturno. O GDD antigo dizia encontro/menu/arte/áudio pendentes e ainda mencionava divisão entre agentes; foi atualizado. O arquivo recebido já usava Godot 4.7, não a 4.6.2 da máquina anterior.

Pendências humanas/externas: playtest livre, audição, aprovação de direção visual/história/monetização; responsáveis e Game Designer; Trello e autorização de publicação; templates para app standalone. Evidências e roteiro em `docs/ac1/TESTES_AC1.md`. PCK depende de Godot instalada.

## Spec 007 — Câmera Estratégica 3D (2026-10-03)

**Status:** implementada + verificação automatizada 31/31 OK (janela real,
Godot 4.6.2, eventos de teclado/mouse reais). **Aprovada pelo usuário em
2026-10-03.**

**Arquivos:**
- `scenes/player/strategic_camera.gd` (novo): `Camera3D` `top_level`, segue a
  posição do Player com suavização e não herda rotação. Exporta `distance` 20,
  `pitch_degrees` 50, `yaw_degrees` 0, `focus_offset` (0, 1, 0) e
  `follow_smoothing` 8. FOV 50 no próprio `fov`. Também expõe
  `planar_direction()` e `screen_to_ground()`.
- `scenes/player/player.tscn`: `SpringArm3D` + `Camera3D` substituídos pelo nó
  `StrategicCamera`.
- `scenes/player/player.gd`: WASD relativo à câmera; o jogador vira para o
  ponto do chão sob o cursor; o ataque passou de `_input` para
  `_unhandled_input` (clique na UI não ataca). Quando o próprio clique vira o
  jogador, o golpe espera um passo de física para a `AttackArea3D` atualizar.
  Removidos `MOUSE_SENSITIVITY`, as constantes de pitch sem uso e a captura do
  mouse. `_try_attack()`, dano, alcance, cooldown e fogo amigo sem alteração.
- `scenes/ui/main.gd`: cursor `VISIBLE` ao jogar e retomar (antes
  `CAPTURED`); painéis da HUD com `MOUSE_FILTER_STOP`; retícula central
  removida; textos "Mouse câmera" → "Mouse mirar".
- `tests/acceptance.gd`: o check "mouse gira a câmera" virou "mouse não gira
  a câmera estratégica", e o clique de ataque agora mira o dino pela tela.
  Não executado nesta unidade, porque grava em `docs/ac1/evidence`.
- Docs: `docs/specs/007-camera-estrategica.md` (novo), índice de specs, nota
  em `001-controle-jogador.md`, ADR 0003, `cycle.md`, `learning-journal.md`.

**Verificação automatizada (script temporário fora do projeto):** câmera
atual/perspectiva/top_level/pitch; cursor visível; girar o Player não gira a
câmera; W/S/A/D = -Z/+Z/-X/+X na tela; com yaw 45° W segue a frente da
câmera; câmera converge sobre o jogador (erro 0,00 m) e ele fica no centro da
tela; borda da arena bloqueia (x = 19,60); clique sobre o dino ao lado vira o
jogador e acerta (inclusive no mesmo quadro do clique); clique oposto não
acerta; cooldown (2 cliques rápidos = 1 golpe); clique no painel da HUD não
ataca nem inicia cooldown; 3 golpes → 20/80; E inicia, soltar cancela,
afastar cancela, pausa cancela e congela; retomar mantém o cursor visível;
E por 2 s domestica com 20/80; ataque não fere aliado; Carnotauro
enfraquecido não é domesticável. Startup pelo MCP: nenhum erro novo (só o
warning antigo de `wild_dino.gd:218`). **Não substitui o playtest manual.**

**Pendências / observações:**
- Rótulos 3D sobre as criaturas (HP, "Segure E") ficaram pequenos a 20 m. A
  HUD continua mostrando HP/prompt. Fora do escopo; está em pergunta aberta
  na Spec 007.
- Árvores altas perto da borda esquerda podem cobrir parte da visão (sem
  oclusão).
- A faixa inferior da HUD (~140 px) não aceita clique de ataque.

## Spec 008 — Continuidade noite → dia + limpeza da HUD (2026-10-03)

**Status:** implementada + verificação automatizada. **Aguardando aprovação
do grupo e playtest manual.** Specs 009+ não iniciadas.

**Arquivos:**
- `scenes/ui/main.gd`:
  - `_victory()` não chama mais o modal. Incrementa "Noites defendidas", toca
    o jingle já existente (`audio.result(true)`) e mostra o aviso
    `DawnToast` ("AMANHECEU · DIA • PREPARAÇÃO", topo central, 2,5 s + fade
    0,5 s, `MOUSE_FILTER_IGNORE`). Não pausa, não muda `screen`, não mexe no
    cursor e não cancela a canalização.
  - `_result()` foi removido. `_defeat()` monta a tela "O refúgio caiu"
    (Reiniciar/Menu) diretamente, com a mesma pausa de antes.
  - O botão "Continuar no dia" e o texto "Noite defendida" não existem mais.
  - HUD: a linha de comandos saiu. O painel inferior virou compacto
    (centralizado, cresce com o texto) com objetivo curto, dica só de
    contexto e barra de canalização só durante a canalização.
  - Pausa: `_show_pause_menu()` separado de `pause_game()`, com o novo
    botão "Controles".
  - `show_controls(back, tips)`: lista em duas colunas a partir da constante
    `CONTROLS`. "Voltar" e ESC voltam ao menu de pausa. O "Controles" do menu
    principal usa a mesma lista, mais as dicas de antes.
- `tests/acceptance.gd`:
  - A vitória agora espera `screen == "playing"`, sem pausa e sem modal (era
    `screen == "victory"` + `resume_game()`). `check_no_early_victory` usa
    `victory_count`.
  - Corrigido o check de clique da Spec 007, que não tinha sido executado
    naquela unidade. O cursor real é levado ao alvo antes do clique, a espera
    pela câmera suavizada é de 1,5 s, e a mira é desligada para o resto da
    suíte.
- Docs: `docs/specs/008-continuidade-noite-dia-hud.md` (novo), índice, nota
  em `006` (RF-AGE-015), `cycle.md`, `learning-journal.md`.

**Verificação automatizada (2026-10-03):**
- Script temporário Spec 008 (janela real, fora do projeto): 35/35.
  - HUD sem comandos; painel 386×48 px; barra oculta.
  - N inicia a noite; 3 spawns reais; sem vitória com 2/3; contagem 3/2/1.
  - Na última ameaça: DIA sem pausa, sem modal, sem "Noite defendida", sem
    "Continuar no dia"; aviso aparece e some.
  - Aliado permanece; jogador anda logo após; câmera da Spec 007 intacta.
  - ESC → Controles → Voltar/ESC → pausa → ESC retoma.
  - Derrota com tela; derrota tem prioridade no mesmo quadro.
  - Reiniciar/menu: 1 diretor de áudio, sem conexões duplicadas.
- Regressão Spec 007: 31/31.
- `tests/acceptance.gd`: 36/36 em janela, 33/33 headless. As evidências de
  `docs/ac1/evidence` foram salvas antes e restauradas depois (sem
  diferenças). Os JSON desta execução ficaram fora do projeto.
- Startup pelo MCP: só o warning antigo de `wild_dino.gd:218`.
- O `WARNING: ObjectDB instances leaked at exit` do acceptance headless já
  aparecia antes da Spec 007 (cópia de referência). Não é novo.

## Spec 009 — Contratos físicos, colisões e obstáculos (2026-10-03)

**Status:** implementada e verificada; **aguardando playtest e aprovação**.
Specs 010/011 não iniciadas. O usuário confirmou o amanhecer contínuo da
Spec 008; a câmera 007 e os scripts atuais de gameplay foram preservados.

**Arquivos criados:** `scenes/world/arena_collision.tscn`,
`tools/build_collisions.ps1`, `tests/physics_contracts.gd/.tscn`,
`docs/specs/009-contratos-fisicos-colisoes-obstaculos.md`,
`docs/validation/spec009.md` e relatórios JSON em `docs/validation/spec009-evidence`.

**Arquivos modificados:** `project.godot` (nomes de camadas),
`scenes/player/player.tscn` (mask 13), ambas as cenas de criaturas
`wild_dino.tscn`/`carnotauro.tscn` (mask 11), `prototype_area.tscn` (instância
de colisões), `tests/acceptance.gd` (destino opcional para evidências), índice
de specs, cycle, journal e notas complementares nos ADRs 0001/0002.

**Implementação:** 42 troncos, 16 pedras, 3 peças do arco, 4 postes e 1
núcleo do refúgio receberam primitivas StaticBody3D/CollisionShape3D sem
escala não uniforme. Chão/limites preservados. Area de ataque layer 0/mask 4;
criaturas ainda sem colisão entre si. Base com núcleo estreito para preservar
o alcance de ataque atual; plataforma baixa decorativa. Gerador lê a arte
atual e não modifica meshes/código de gameplay.

**Verificação:** física 23/23 headless e 23/23 com renderização; acceptance
33/33 headless e 36/36 com renderização. Movimento contra árvore/pedra/arco/
núcleo, deslizamento, máscara de aliados, câmera, input, HUD/Controles e
percurso real spawn → dano à base. Regressão de combate, domesticação,
aliados, ondas, amanhecer contínuo e derrota passou. Evidências históricas
AC1 não sobrescritas. Detalhes/limitações em `../validation/spec009.md`.

**TESTE MANUAL NECESSÁRIO:** contorno de quinas/obstáculos periféricos,
encaixe visual e partida completa. IA direta pode parar atrás de sólidos;
empilhamento e navegação continuam pendentes da Spec 010. Não há linha de
visão para ataques/domesticação; nenhuma mudança nesse contrato.

## Spec 010 — Navegação, avoidance e movimentação em grupo (2026-10-03)

**Status:** implementada e verificada; **aguardando playtest visual (A–E) e
aprovação**. Spec 009 aprovada manualmente pelo usuário. Spec 011 não iniciada.

**Ponto de partida:** o pedido dizia que outro assistente tinha começado a Spec
010, mas os arquivos atuais não continham nada dela:
- sem spec, ADR, navegação, avoidance ou testes;
- tracker e cycle diziam "não iniciadas";
- git sem stash/branch/commit novo.

A implementação partiu do estado da Spec 009, sem desfazer nada.

**Arquivos criados:**
- `tools/bake_navmesh.gd`;
- `scenes/world/arena_navmesh.tres`;
- `scenes/enemies/approach_slots.gd`;
- `tests/navigation_contracts.gd/.tscn`;
- `docs/specs/010-navegacao-avoidance-criaturas.md`;
- `docs/context/adr/0004-navegacao-navmesh-slots-avoidance.md`;
- `docs/validation/spec010.md` e `spec010-evidence/` (JSON).

**Arquivos modificados:**
- `scenes/world/prototype_area.tscn`: nó `NavigationRegion` e grupo
  `navigation_source` em Ground/ArenaArt/ArenaCollision.
- `scenes/enemies/wild_dino.tscn` e `carnotauro.tscn`: `NavigationAgent3D`.
- `scenes/player/player.tscn`: `NavigationObstacle3D`.
- `scenes/enemies/wild_dino.gd`: navegação, slots, avoidance, recuperação,
  busca de alvo a cada 0,15 s.
- `scenes/world/wave_manager.gd`: spawns separados.
- Índice de specs, cycle e journal.

**Preservado sem alteração:**
- máscaras/camadas da Spec 009;
- HP 80, dano 15 (noite ×1,3), velocidades 4 m/s (noite ×1,2);
- alcances 2 m / 1,5 m / 8 m, raio de defesa 8 m;
- domesticação (30%, E 2 s, 3 m, cancelamentos), F só de dia;
- câmera, mira, HUD, Controles e amanhecer contínuo.

**Mudança pequena de comportamento:**
- aliado em FICAR considera que chegou ao posto a 0,3 m (antes 0,2 m);
- a busca de alvo tem latência de até 0,15 s.

**Verificação:** navegação 38/38 headless e janela; física 23/23 nos dois
modos; acceptance 33/33 headless e 36/36 janela; regressões 007 (31/31) e
008 (35/35); startup pelo MCP sem erros nem warnings. Detalhes, problemas
corrigidos e limites em `../validation/spec010.md`.

**TESTE MANUAL NECESSÁRIO:**
- A: noite com 3 inimigos sem fila;
- B: contorno de árvore/pedra;
- C: correr com 3 perseguidores;
- D: vários aliados seguindo;
- E: ataque distribuído ao refúgio.

## Correção — orientação visual do Player (2026-10-04)

**Status:** aprovada pelo usuário junto com a Spec 010.

`rotation.y` do Player continua sendo a mira lógica do ataque (cursor e
`AttackArea3D`). O `Visual` ganhou orientação própria, guiada pela direção
do WASD, com virada suave só em Y. Durante o golpe, encara a mira por 0,3 s.
Teste: `tests/player_facing.tscn` (37/37).

## Spec 011 — HP, dano, morte, respawn e HUD do jogador (2026-10-04)

**Status:** **aprovada pelo usuário (2026-10-04)**, após o playtest manual
(A–G). Specs 007–010 aprovadas pelo usuário.

**Arquivos criados:**
- `docs/specs/011-vida-morte-respawn-jogador.md`;
- `tests/player_health.gd/.tscn`;
- `docs/validation/spec011.md` e `spec011-evidence/` (JSON).

**Arquivos modificados:**
- `scenes/player/player.gd`:
  - `max_hp` 100, `take_damage` real;
  - janela de 0,6 s, morte única e respawn em 2 s com proteção de 1,5 s;
  - sinais `health_changed`/`died`/`respawned`.
- `scenes/player/player.tscn`: nó `RespawnTimer`.
- `scenes/world/prototype_area.tscn`: Marker3D `PlayerSpawn` e
  `respawn_point_path` do Player.
- `scenes/player/domestication_channel.gd`: Player morto não canaliza.
- `scenes/ui/main.gd`:
  - JOGADOR x/100 com barra, ligado aos sinais;
  - aviso "VOCÊ CAIU";
  - dica de Controles atualizada.
- Índice de specs, cycle, journal e ADR 0001 (complemento).

**Preservado sem alteração:**
- dano das criaturas (15, ×1,3 à noite), cooldown de 1 s, alcances;
- IA e navegação da Spec 010;
- camadas e máscaras da Spec 009 (o Player só zera a camada enquanto
  está morto);
- domesticação, ataque do Player (20, 0,8 s), câmera e mira;
- amanhecer contínuo e "O refúgio caiu".

**Verificação:** Spec 011 47/47 headless e janela; facing 37/37; física
23/23; navegação 38/38; acceptance 33/33 headless e 36/36 janela. Detalhes
em `../validation/spec011.md`.

**TESTE MANUAL NECESSÁRIO:** A dano, B invulnerabilidade cercado, C morte,
D respawn, E proteção, F refúgio cai, G combate depois do respawn.

## Spec 012 — Primeiro mapa, regiões e estrutura do mundo (2026-10-04)

**Status:** **aprovada pelo usuário (2026-10-04)** após exploração visual
manual.

**Origem:** iniciada pelo GPT-6 Astra e interrompida por limite de uso. O
projeto não é rastreado pelo git, então o trabalho dele foi auditado por
data de modificação. Detalhes em `../validation/spec012.md`.

**Do Astra (preservado):**
- vale 48 × 52 m;
- `world_regions.tscn` (zonas, trilhas, marcadores);
- PlayerSpawn (0, 1, −10) e 3 entradas noturnas via `spawn_offsets`;
- `build_first_map.gd` e `build_collisions.gd` com leitura nativa de
  Transform3D;
- suítes `world_layout`/`map_showcase`.

**Corrigido/completado:**
- dupla conversão sRGB que escurecia o mapa;
- região rochosa: blocos grandes e árvores levadas para o bosque;
- bifurcação única em (0, 6);
- estreitamentos sem obstáculo na trilha;
- copas do lado da câmera fora das trilhas;
- colisor de pedra com a altura visual;
- fixture de HP no teste de navegação (o Player morria no meio da medição);
- verificações novas em `world_layout`: correspondência visual/colisor,
  ilhas, oclusão e densidade dos biomas;
- documentação (Spec 012, validação, índice, cycle, journal).

**Arquivos (total da Spec 012):**
- criados:
  - `tools/build_first_map.gd`, `tools/build_collisions.gd`,
    `tools/test_spec012.ps1`;
  - `scenes/world/world_regions.tscn`;
  - `tests/world_layout.gd/.tscn` e `tests/map_showcase.gd/.tscn`;
  - `docs/specs/012-primeiro-mapa-regioes.md`;
  - `docs/validation/spec012.md` e `spec012-evidence/`;
- modificados:
  - `scenes/visuals/arena_art.tscn`;
  - `scenes/world/prototype_area.tscn`, `arena_collision.tscn` e
    `arena_navmesh.tres`;
  - `tools/build_collisions.ps1`, `tools/build_visuals.py`;
  - `tests/physics_contracts.gd`, `tests/navigation_contracts.gd`;
  - índice de specs, cycle e journal.

**Preservado sem alteração:**
- câmera;
- combate (Player 20, WildDino 80/15, ×1,3 à noite);
- domesticação;
- vida, morte e respawn;
- IA, avoidance e slots;
- contratos de camadas;
- 66 sólidos.

**Verificação:** world_layout 57/57; player_health 47/47; facing 37/37;
física 23/23; navegação 38/38 (headless e janela); acceptance 33/33
headless e 36/36 janela (1 crash intermitente em 4 execuções).

**TESTE MANUAL NECESSÁRIO:**
- base, BuildZone e saída;
- bifurcação, bosque e região rochosa;
- oclusão por árvores e colisões;
- estreitamentos;
- noite com 3 direções;
- morte e respawn.

## Ajuste pós-012 — Menu principal com cara de jogo (2026-10-04)

**Status:** **aprovado visualmente pelo usuário (2026-10-04)**.

**Fundo:** o próprio vale (arte da Spec 012, sem scripts de gameplay), por
`scenes/ui/menu_backdrop.gd`, com câmera lenta.

**Tela:**
- logo INFINITY/PIXEL em camadas, com cristais;
- JOGAR em destaque, CONTROLES e CRÉDITOS lado a lado, SAIR discreto;
- áudio num ícone no canto.

**Movido para Créditos:** os textos institucionais.

**Testes:** `tests/main_menu.tscn` (29/29, com janela). O `acceptance`
passou a procurar o botão "JOGAR" sem diferenciar maiúsculas.

## Spec 013 — Relógio, ciclo automático e ataques noturnos (2026-10-04)

**Status:** implementada e verificada; **aguardando playtest manual e
aprovação**. Spec 014 não iniciada.

**Arquitetura:** o relógio fica no `DayNightManager`, fonte única de:
- estado, horário, dia e noites defendidas;
- sinais `night_warning`/`night_started`/`day_started`/`game_over`.

**Arquivos criados:**
- `docs/specs/013-relogio-ciclo-ataques-noturnos.md`;
- `tests/day_cycle.gd/.tscn`;
- `tests/cycle_showcase.gd/.tscn` (captura visual);
- `docs/validation/spec013.md` e `spec013-evidence/`.

**Arquivos modificados:**
- `scenes/world/day_night_manager.gd`:
  - relógio, contadores e aviso;
  - noite automática às 18:00;
  - N só com `debug_force_night_key`.
- `scenes/world/wave_manager.gd`: `enemy_count_for_night` (3 + noite − 1)
  e desvio de spawn dentro da mesma rota.
- `scenes/ui/main.gd`:
  - painel "DIA N • PREPARAÇÃO" + relógio + contagem;
  - aviso de anoitecer e "AMANHECEU · DIA N";
  - `victory_count` lê `nights_defended`;
  - N fora dos Controles e dos objetivos.
- `tests/acceptance.gd`: a checagem de mesmo quadro usa `wave.enemy_count`.
- Índice de specs, cycle e journal.

**Valores:** 08:00 → 18:00 em 180 s; noite visual 18:00 → 06:00 em 90 s
(segura em 05:59 enquanto há inimigos); aviso aos 30 s; contagem nos 10 s
finais.

**Preservado:**
- HP, dano (15 / 19,5) e velocidade das criaturas; 2 s entre spawns;
- domesticação, Player e respawn;
- navegação, rotas e mapa;
- amanhecer sem modal e prioridade da derrota.

**Verificação:** day_cycle 43/43; world_layout 57/57; player_health 47/47;
facing 37/37; física 23/23; navegação 38/38; acceptance 33/33 headless e
36/36 janela; main_menu 29/29. Sem crash 139 nesta rodada.

**TESTE MANUAL NECESSÁRIO:**
- relógio e pausa;
- aviso e contagem;
- noite automática com 3 rotas;
- amanhecer no Dia 2;
- Noite 2 com 4 inimigos;
- morte noturna;
- 05:59 segurando;
- derrota e reinício;
- tecla N inativa.

**Ajuste de balanceamento da Spec 013 (2026-10-04, após o primeiro
playtest):**
- dia 180 → **90 s**;
- relógio noturno 90 → **45 s**;
- aviso 30 → **20 s**;
- contagem mantida em 10 s.

A noite continua terminando só pela onda (05:59 seguro). Suíte nova
`tests/day_cycle_real.tscn` com os tempos reais: 15/15. Regressões verdes.
Spec 013 segue **aguardando aprovação manual**.

## Spec 013B — Economia, pontos de defesa e torres fixas (2026-10-04)

**Status:** implementada e verificada; **aguardando playtest manual e
aprovação**. A Spec 013 foi **validada funcionalmente quanto ao ciclo** no
playtest. Ele mostrou Noite 1 difícil e Noite 2 insustentável, e daí veio
esta etapa entre a 013 e a 014. Spec 014 não iniciada.

**Valores iniciais:**
- 30 pontos iniciais;
- +15 por inimigo da onda morto;
- Torre L1 30, L2 30, L3 45;
- dano 10 / 15 / 20, intervalo 1,0 / 0,85 / 0,70 s, alcance 8 / 9 / 10 m.

**Arquivos criados:**
- `scenes/world/defense_economy.gd`, `defense_slots.gd`, `defense_slot.gd`,
  `defense_tower.gd`;
- `tests/defense_economy.gd/.tscn`, `tests/defense_showcase.gd/.tscn`;
- `docs/specs/013b-economia-defesas-fixas.md`;
- `docs/validation/spec013b.md` e `spec013b-evidence/`.

**Arquivos modificados:**
- `scenes/world/wave_manager.gd`: sinal `wave_enemy_defeated` e grupo
  `wave_enemy`;
- `scenes/world/prototype_area.tscn`: `DefenseEconomy` e `DefenseSlots` com
  6 pontos;
- `project.godot`: ação `build_interact` (C);
- `scenes/ui/main.gd`:
  - painel de pontos e "+15";
  - painel contextual de construção e avisos;
  - C nos Controles;
  - ícone de som com slider abaixo no menu;
- `scenes/ui/audio_director.gd`: `last_nonzero_volume`;
- `tests/main_menu.gd`: trecho de áudio atualizado para a nova UI.

**Preservado:**
- quantidade e atributos dos inimigos, dano noturno, spawn;
- ciclo da Spec 013, mapa, navegação, vida, domesticação;
- design do menu.

**Verificação:** defense_economy 35/35 headless e janela; main_menu 27/27;
day_cycle 43/43; day_cycle_real 15/15; world_layout 57/57; player_health
47/47; facing 37/37; física 23/23; navegação 38/38; acceptance 33/33 e
36/36. Sem crash 139.

**TESTE MANUAL NECESSÁRIO:**
- volume do menu;
- construir no Dia 1;
- Noite 1 com a torre;
- 45 pontos no Dia 2 e a escolha entre segunda torre e melhoria;
- bloqueio noturno;
- Noite 2;
- domesticação sem pontos;
- reinício.

## Spec 013C — Combate, coleta, dinos diurnos e HUD compacta (2026-10-04)

**Status:** implementada e verificada; **aguardando playtest manual e
aprovação**. A 013B ficou **funcional, com playtest realizado**, aguardando
este polimento. Spec 014 não iniciada.

**Origem (playtest da 013B):**
- primeiro clique nem sempre feria;
- golpe deveria ser 15;
- domesticado sem vida cheia;
- um só dino diurno;
- alcance das torres invisível;
- texto 3D de debug;
- HUD grande;
- sem coleta.

**Causa do clique (reproduzida):** um golpe no vazio, com o dino a ~3 m
parecendo colado, iniciava 0,8 s de cooldown e descartava o clique seguinte,
já no alcance (0/8 tentativas). Também havia um caminho de golpe duplo (2
quadros de espera antes do cooldown).

**Correção:**
- golpe resolvido no clique;
- mira no corpo clicado;
- vazio recupera em 0,3 s;
- buffer de um clique.

**Valores:**
- golpe 15;
- domesticação → 80/80;
- 40 pontos iniciais;
- 2 encontros diurnos;
- anel de alcance 8 / 9 / 10 m;
- 8 árvores (30 HP, +10 Madeira);
- 6 pedras (45 HP, +6 Pedra);
- recursos voltam no amanhecer.

**Arquivos criados:**
- `scenes/world/resource_stock.gd`, `collectable_resource.gd`,
  `range_ring.gd`;
- `tests/combat_collect.gd/.tscn`;
- `tests/collect_showcase.gd/.tscn`, `tests/hud_showcase.gd/.tscn`;
- `docs/specs/013c-combate-coleta-hud.md`;
- `docs/validation/spec013c.md` e `spec013c-evidence/`.

**Arquivos modificados:**
- `scenes/player/player.gd`: golpe, clique, buffer e mira;
- `scenes/enemies/wild_dino.gd`: vida cheia ao domesticar;
- `scenes/world/encounter_spawner.gd`: N pontos;
- `scenes/world/defense_economy.gd`: 40;
- `scenes/world/defense_tower.gd` e `defense_slot.gd`: anel, prévia e
  losango;
- `scenes/world/prototype_area.tscn`: `ResourceStock` + 14 coletáveis;
- `scenes/visuals/arena_art.tscn`: sem `PostLabel`;
- `tools/build_first_map.gd`;
- `scenes/ui/menu_backdrop.gd`;
- `scenes/ui/main.gd`: HUD compacta, recursos, "+N", painel do ponto,
  dicas;
- testes antigos atualizados para os contratos novos;
- índice, cycle e journal.

**Verificação:** todas as suítes verdes headless e com janela (013C 46/46).
Sem crash 139.

**TESTE MANUAL NECESSÁRIO:**
- clique no dino (perto e "um pouco antes");
- 80 → 20 → domesticar → 80;
- dois encontros e reposição no amanhecer;
- anéis e prévia de alcance;
- coleta e volta dos recursos;
- HUD em 1920×1080;
- economia com 40 pontos.

## Spec 013D — Inventário, construção com recursos e cura (2026-10-05)

**Status:** implementada, verificada e **aprovada manualmente**
(playtest de 2026-10-06). A 013C foi **aprovada manualmente** (2026-10-04).
**Spec 014: próxima** (não iniciada).

**Entregue:**
- inventário (I), que não pausa;
- gasto atômico de Madeira/Pedra no mesmo `ResourceStock`;
- fundação da construção (`BuildPlacer`): B, fantasma com pegada
  verde/vermelha, R gira, clique constrói, botão direito/ESC cancela;
- validação por zona (BuildZone / rotas noturnas), sólidos, estruturas,
  refúgio, pontos de defesa, Player e chão navegável;
- só de dia.

**Fogueira de Cura** (20 Madeira + 12 Pedra, máximo 1):
- segurar H a até 2,5 m por 3 s dá +25 (máximo 100);
- cancela ao sair do alcance, levar dano, morrer, atacar, soltar H ou pausar;
- 2 cargas por ciclo, que voltam a 2 no amanhecer;
- recarga de 25 s.

**Armadilha de Espinhos** (15 Madeira + 6 Pedra, máximo 3):
- 15 de dano só em inimigos da onda, 1 por passagem, 0,35 s entre
  ativações;
- 3 cargas, depois some;
- sem corpo nem obstáculo de navegação.

**Arquivos criados:**
- `scenes/world/build_recipes.gd`, `build_placer.gd`,
  `healing_campfire.gd`, `spike_trap.gd`;
- `tests/build_heal.gd/.tscn`, `tests/healing_actions.gd/.tscn`,
  `tests/build_showcase.gd/.tscn`, `tools/test_spec013d.ps1`;
- `docs/specs/013d-inventario-construcao-cura.md`;
- `docs/validation/spec013d.md` e `spec013d-evidence/`.

**Arquivos modificados:**
- `scenes/world/resource_stock.gd`: gasto atômico;
- `scenes/player/player.gd`: `heal()` e clique de construir não ataca;
- `scenes/world/prototype_area.tscn`: `Structures` e `BuildPlacer`;
- `project.godot`: I, B, R, H;
- `scenes/ui/main.gd`: inventário, menu, painel de posicionamento, barra
  "CURANDO", avisos, ESC, Controles;
- `tests/defense_economy.gd`: espera em tempo de jogo;
- índice, cycle e journal.

**Continuidade:** a conexão caiu durante a validação. O trabalho salvo foi
mantido, e a contribuição de outra sessão ("pausar cancela a cura") foi
preservada.

**Verificação:**
- build_heal 68/68 headless e com janela;
- todas as regressões verdes headless;
- com janela: verdes, sendo navigation 38/38 com `--fixed-fps` (máquina com
  FPS baixo por falta de memória) e acceptance 36/36 com o cursor fora da
  janela;
- 1 crash 139 intermitente no acceptance (a execução seguinte passou).

**Revisão final (2026-10-05, sessão única):** auditoria após o conflito de
duas sessões; nada inconsistente no código. Confirmados: atacar e pausar
cancelam a cura; domesticação/posicionamento cancelam uma cura em andamento;
`build_heal` com 68 checagens. `tests/healing_actions.tscn` (7 checagens)
registrado. Corrigida uma instabilidade **só do teste** `healing_actions`
(construía antes de a navmesh do mapa sincronizar, ~1 em 5, e travava).
Final: todas as 12 suítes verdes headless (build_heal 68/68,
healing_actions 7/7); com janela build_heal 68/68, healing_actions 7/7,
combat_collect 46/46, acceptance 36/36, main_menu 27/27. Capturas refeitas.

**Playtest manual (2026-10-06): APROVADO.** Inventário, coleta,
construção, Fogueira de Cura (cura, cargas, recarga), Armadilha de Espinhos,
economia, amanhecer e integração com o restante do gameplay funcionando
corretamente. Sem mudanças de gameplay ou balanceamento após o playtest.

**013C aprovada manualmente; 013D aprovada manualmente; Spec 014 é a
próxima (não iniciada).**

## Spec 014 — Céu, iluminação e transição visual do dia/noite (2026-10-06)

**Status:** implementada, verificada e **aprovada manualmente** (playtest de
2026-10-06). 013C e 013D aprovadas manualmente. **Spec 015: próxima** (não
iniciada).

**Auditoria:** o visual antigo só alternava 2 estados (tween de 1,5 s). A
câmera estratégica (pitch 50°, FOV 50°) **não enxerga o céu** (0% medido em
6 pontos). Decisão do usuário: céu real + sinais no chão.

**Entregue:**
- `DayNightVisual` reescrito como controlador do ambiente: lê
  `DayNightManager.clock_hours()` (novo, só leitura) e interpola 19
  quadros-chave por hora — Sol (direção, cor, energia, sombra), Lua (a mesma
  luz direcional, fria, das 19:00 às 05:15), luz ambiente, exposição,
  neblina leve, céu em shader (gradiente, Sol, Lua, estrelas);
- estrelas que surgem/somem uma a uma no céu e 120 pontinhos que cintilam
  no gramado (1 MultiMesh);
- brilho noturno: refúgio (núcleo, tochas e luz local nova sem sombra),
  Fogueira (luz/chama; cura intacta), cristal e disparo das torres, pontas
  da armadilha (sem luz);
- 05:59 → 08:00: o visual percorre o amanhecer em ~2,7 s, sem flash;
- pausa e derrota congelam; Reiniciar volta à manhã com Environment novo.

**Arquivos criados:** `scenes/world/day_night_sky.gdshader`,
`scenes/world/night_glints.gdshader`, `tests/sky_cycle.gd/.tscn`,
`tests/sky_showcase.gd/.tscn`, `tools/test_spec014.ps1`,
`docs/specs/014-ceu-iluminacao-progressiva.md`, `docs/validation/spec014.md`
e `spec014-evidence/`.

**Arquivos modificados:** `scenes/world/day_night_visual.gd` (reescrito),
`day_night_manager.gd` (`clock_hours()`), `healing_campfire.gd`,
`defense_tower.gd`, `spike_trap.gd` (só `set_night_glow()` visual); índice,
cycle e journal.

**Verificação:** sky_cycle 45/45 headless e com janela; todas as regressões
verdes headless e com janela (acceptance 33/33 e 36/36, main_menu 27/27).
Corrigida uma regressão real (lambdas acumulando conexões a cada
Reiniciar). Custo medido ≤ 0,04 ms/quadro.

**Playtest manual (2026-10-06): APROVADO.** Ciclo visual validado durante o
gameplay. Sem mudanças de gameplay, iluminação ou balanceamento após o
playtest.

**013C aprovada manualmente; 013D aprovada manualmente; 014 aprovada
manualmente; Spec 015 é a próxima (não iniciada).**

## Spec 015 — Territórios controlados e expansão da base (2026-10-06)

**Status:** implementada e verificada; **aguardando playtest manual e
aprovação**. 013C, 013D e 014 aprovadas manualmente. Spec 016 não iniciada.

**Entregue:**
- `TerritoryManager` (mundo): Refúgio (CONTROLLED), Floresta Oeste e Região
  Rochosa (WILD) sobre o mapa da 012; estados WILD → READY_TO_CLAIM →
  CONTROLLED;
- guardiões = os encontros diurnos da 013C (derrotar **ou** domesticar
  libera uma vez; sem pontos, fora da onda, sem duplicar no amanhecer);
- marco de pedra com cristal (apagado / dourado / jade); segurar E 2 s, de
  dia, com cancelamentos;
- prioridade de E: alvo domesticável vence; uma segurada = uma interação;
- anel de energia + aviso curto; contorno discreto; aviso ao entrar na
  região;
- `BuildPlacer`: zona de base = BuildZone ou território recuperado; recusa
  "Território selvagem…" e "Bloquearia uma rota noturna";
- HUD "TERRITÓRIOS 1/3", dica, barra e objetivo.

**Arquivos criados:** `scenes/world/territory_manager.gd`,
`territory_marker.gd`, `tests/territory.gd/.tscn`,
`tests/territory_showcase.gd/.tscn`, `tools/test_spec015.ps1`,
`docs/specs/015-territorios-controlados.md`, `docs/validation/spec015.md` e
`spec015-evidence/`.

**Arquivos modificados:** `prototype_area.tscn`, `build_placer.gd`,
`domestication_channel.gd`, `wild_dino.gd`, `main.gd`; índice, cycle e
journal.

**Verificação:** territory 68/68 headless e com janela; todas as regressões
verdes nos dois modos (acceptance 33/33 e 36/36, main_menu 27/27). Nenhum
teste antigo alterado. Custo ≈ 0,4 ms/quadro no bosque.

**TESTE MANUAL NECESSÁRIO:** roteiro em `docs/validation/spec015.md`.

## P0/P1 — Estabilidade pós-Astra e movimentação das criaturas (2026-10-08)

**Status:** **P0 e P1 aprovadas manualmente (playtest de 2026-10-08).**
P2 (documentação e consolidação) em andamento; P3 (tutorial jogável), P4
(game design e UX), P5 (visual noturno) e P6 (QA final) não iniciadas. A
Spec 015 continua registrada como aguardando aprovação formal (o fluxo de
território funcionou no playtest de P0/P1).

**Contexto:** o GPT-6 Astra foi interrompido por limite de uso no meio de
uma auditoria de QA; o merge de 2026-10-08 deixou marcadores de conflito
commitados em `domestication_channel.gd`.

**Astra (preservado e validado):** histerese de troca de alvo (0,75 m), giro
limitado a 8 rad/s, pernas pela velocidade real, dano ≤ 0 ignorado, queda do
recurso cancelada ao restaurar, ataque revalidado durante construção/E,
`tests/gameplay_stability`.

**Claude — P0:** conflito resolvido; regressão da Spec 015 corrigida com
`DomesticationChannel.blocks_attack()` (E da domesticação bloqueia o ataque;
E da recuperação do marco não — o golpe a cancela, RF-TER-005);
`domestication_regression` alinhado à 013C (26/26); `day_cycle` lê o relógio
no sinal da transição (estável sem `--fixed-fps`); `acceptance` e
`domestication_regression` não sobrescrevem mais evidência versionada; +6
checks de clique real no `gameplay_stability`.

**Claude — P1:** causa da tremedeira = destino de navegação defasado (o
agente só recebia destino novo após 0,5 m, a chegada usava o destino atual
com 0,25 m; poucos centímetros normalizados para 4 m/s) + rumo pela
velocidade do avoidance. Soluções em `wild_dino.gd`: último trecho segue o
destino atual, rumo pela velocidade real suavizada, histerese de 0,6 m no
slot de ataque. Teste novo `tests/creature_motion` (13 cenários, 32 checks).

**Verificação:** sem janela (`--fixed-fps 60`) 17 suítes, 635 checks, 0
falhas; com janela 18 suítes, 665 checks verdes na execução válida (falhas
da 1ª tentativa = pausa por perda de foco). Passos curtos: 25 reversões e 57
inversões de giro → 0 e 8. Detalhes, limitações e evidências em
`docs/validation/p0-p1.md`.

## Spec 017A (etapas 1–2) e inimigo noturno (2026-10-09)

**Status:** implementados e testados (`a3f8d41`, enviado pelo usuário);
aguardando playtest manual. Registros: `docs/validation/017a.md` e
`docs/validation/night-enemy.md`.

## Execução autônoma — Vale de Jade, criaturas, HUD e tutorial (2026-10-09)

**Status:** implementado; testado sem janela (20/20 suítes, 700 checks) e com
janela (21/21, 730 checks); **aguardando playtest manual**. Nenhuma spec foi
marcada como aprovada. Registro completo, desempenho e roteiro de playtest:
`docs/validation/visual-hud-tutorial.md`. Commits locais (sem push):

| Commit | Conteúdo | Spec |
|---|---|---|
| `b9ce6b7` | Refúgio, chão, trilhas, paredões, natureza, coletáveis, marcos, luz do meio-dia | 017A (3–4), 018 |
| `e474fe9` | Feedback visual de criaturas e combate, rótulos por tipo, anel de domesticação | 019 |
| `a888114` | HUD extraída de `main.gd` para `scenes/ui/hud.gd` (sem mudar comportamento) | 017B (refatoração) |
| `a94207e` | Redesenho da HUD e leitura de recursos | 017B/020 |
| `f545741` | Tutorial jogável | 022 |
| (último) | Otimização de desempenho da arte do vale + evidências e documentação | 018 / QA |

Pendências: playtest; propostas de economia G1–G6 não implementadas (fora do
autorizado). A Spec 015 continua aguardando aprovação formal.
