# Progress Tracker

## Estado vigente — revisão de 30/09/2026

A nova proposta mantém o Tower Defense central e prevê exploração,
domesticação seletiva, construção da própria base, área para criaturas e
ciclo gradual de dia/noite, com câmera elevada em perspectiva 3/4.
O incremento autorizado nesta revisão é **somente documentação e
correção/revalidação da Unidade 3**. Câmera, colisões, construção e ciclo
visual ficam para incrementos seguintes.

**Unidade 3: correções técnicas implementadas; playtest humano pendente.**
Não marcar concluída com base nos registros históricos abaixo. Resultados,
limites da verificação e roteiro atual: `docs/ac1/TESTES_UNIDADE_3.md`.

Estado real do projeto: F5 abre `scenes/ui/main.tscn`; Jogar cria o encontro
diurno sem T. O gatilho T está desligado por padrão e só funciona em debug
quando `debug_enabled` é ligado. Diagnóstico detalhado da domesticação
está desligado (`DEBUG := false`), mas logs de estado continuam ativos.

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

**Status atual (30/09/2026):** REABERTA — correções técnicas implementadas;
aguardando nova validação humana, conforme solicitação atual do usuário.

**Revisão atual:** ataque passou a consultar a mesma leitura de E usada
pela canalização, inclusive o evento alternativo de teclado; a proteção
fica em `_try_attack()` antes de consumir cooldown. Alvos marcados para
remoção deixam de ser válidos imediatamente, evitando conversão no mesmo
quadro do `queue_free()`. Script: `v6-entrada-e-ciclo-de-vida`.
Spec 003 agora registra alcance, seleção/travamento, cancelamentos e HP
preservado. Câmera, física, dano, tempo de 2 s e alcance de 3 m preservados.

**Histórico de 25/09/2026:** havia aprovação manual após a correção do 4º
relato, descrita abaixo. Ela não substitui a aprovação desta revisão.
Naquele momento os logs detalhados estavam ligados; atualmente `DEBUG`
está desligado por padrão.

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

> Roteiro histórico. Na versão atual, F5 abre o menu, T está desligado por
> padrão e há encontro diurno sem T. Use `docs/ac1/TESTES_AC1.md` para o fluxo
> integrado e `docs/ac1/TESTES_UNIDADE_3.md` para domesticação.

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

Roteiro vigente e comandos de teste em `docs/ac1/TESTES_UNIDADE_3.md`.
F5 → Jogar → encontro à esquerda → três golpes → E por 2 s a até 3 m.
Confirmar cancelamentos, bloqueio do clique enquanto E está pressionado,
aliado com 20/80 HP e seguir sem atacar o Player.

Diagnóstico detalhado opcional: `DEBUG := true` em
`scenes/player/domestication_channel.gd`; a versão atual é
`v6-entrada-e-ciclo-de-vida`. Com `DEBUG := false`, início/cancelamento/
conclusão continuam no Output; ausência do anúncio de versão é esperada.

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
