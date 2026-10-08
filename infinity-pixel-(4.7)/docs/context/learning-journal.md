# Learning Journal

## 2026-09-17 — Unidade 1: controle do jogador

**O que foi ensinado/aplicado:**

- **SpringArm3D** para câmera em terceira pessoa: ele projeta um raio na
  direção -Z e encurta automaticamente a distância da câmera quando bate em
  algo (parede, chão), evitando que a câmera atravesse cenário. Por isso o
  `collision_mask` da SpringArm3D importa (definido para a layer do chão).

- **Corpo gira com o mouse X, câmera só inclina no Y:** em vez de dois
  pivôs independentes (um para corpo, outro para câmera), o script gira o
  `Player` inteiro no eixo Y a cada movimento do mouse. Isso mantém "para
  onde o personagem olha" e "para onde ele ataca" sempre sincronizados, sem
  lógica extra — foi uma escolha para simplificar RF-AGE-002 (ataque na
  direção em que o personagem está olhando).

- **Área de ataque consultada no momento do golpe:** a `AttackArea3D` fica
  sempre monitorando e o clique chama `get_overlapping_bodies()`.
  *Correção após o playtest:* a primeira versão mantinha uma lista via
  sinais `body_entered`/`body_exited`, e o ataque não funcionou no
  playtest. Consultar a área na hora do golpe é mais robusto (não depende
  de nenhum evento ter disparado) e o custo de uma chamada por clique é
  irrelevante.

- **Contrato `take_damage()` + grupo `"damageable"`:** qualquer nó que
  implemente esse método e esteja nesse grupo pode ser atingido pelo
  jogador, sem o `player.gd` precisar conhecer o tipo específico do alvo.
  Isso é o que vai permitir que o dinossauro selvagem (Spec 002) seja
  atacável sem tocar no código do jogador.

- **Camadas de colisão (collision layers/masks):** layer 1 = mundo/chão,
  layer 2 = jogador, layer 3 = criaturas (reservada para Specs 002/004). A
  `AttackArea3D` só escuta a layer 3, então o chão nunca aparece na lista de
  alvos por engano.

- **Input Map em vez de checar o evento cru:** o ataque agora é a ação
  `attack` (Project Settings → Input Map). Assim o botão pode ser
  remapeado sem tocar no código, e `event.is_action_pressed("attack")`
  funciona igual para mouse, teclado ou controle.

- **Lição do playtest:** um sistema que "parece certo no código" mas não
  dá nenhum feedback é impossível de diagnosticar. Ganhou um `print` no
  golpe — feedback temporário de teste é barato e vale a pena.

**Dúvidas/decisões que ficaram para o playtest:**

- Os quatro valores provisórios de RF-AGE-001/002 (velocidade, alcance,
  cooldown, dano) foram testados só quanto ao funcionamento; a avaliação de
  "sensação" (as perguntas de protótipo das Specs) ainda está em aberto.

## 2026-09-18 — Unidade 2: dinossauro selvagem (playtest aprovado)

Playtest: todos os critérios OK (um inimigo por vez, spawn, caminhada,
detecção, perseguição, ataque com cooldown, dano ao inimigo, perda de alvo,
morte, novo spawn). Duas falhas antes: referência nula ao spawn e acúmulo de
inimigos por T — ambas no gatilho de teste, não no inimigo.

**O que foi ensinado/aplicado:**

- **Máquina de estados simples sem enum:** o inimigo decide a cada
  `_physics_process` se tem alvo (persegue e ataca) ou não (avança ao
  território). Sem estado guardado além do alvo atual, o "volta a avançar
  quando o alvo morre ou sai do alcance" sai de graça, porque a decisão é
  recalculada todo quadro.

- **Detecção por distância + grupos, sem `Area3D`:** o inimigo percorre os
  grupos `player` e `domesticated` e escolhe o mais próximo dentro de 8 m.
  Para poucos alvos é mais simples que montar uma `Area3D` com máscara e
  lista de overlap (que já nos deu problema na Unidade 1). Trade-off: não
  escala para centenas de alvos e ignora linha de visão.

- **Grupos como contrato de papéis:** `damageable` (pode receber dano, ADR
  0001), `player`, `domesticated` (Spec 004, ainda não existe), `territory`
  (marcador de destino) e `wild_dino`. O inimigo não conhece a classe do
  jogador nem do futuro aliado.

- **Camadas de colisão para corpos:** jogador (layer 2) e inimigo (layer 3)
  agora se bloqueiam mutuamente (`mask` do jogador 1+3 = 5, do inimigo 1+2 =
  3). Inimigos não colidem entre si por enquanto.

- **`look_at` só no plano XZ** para o corpo virar para o destino sem
  inclinar; o "nariz" (caixa) na frente da cápsula mostra a direção.

- **Gatilho de teste separado da Spec:** `wave_test_trigger.gd` deixa claro
  que o spawn por tecla é provisório; a Spec 005 troca só esse nó.

- **Lição do playtest (referência nula):** `@export var x: Node3D` recebendo
  um `NodePath` escrito à mão na `.tscn` ficou `null` e causou
  "Invalid access ... on a base object of type 'Nil'". Corrigido usando
  `@export var x_path: NodePath` + `get_node_or_null()` no `_ready`, com
  `push_error` se o nó não for achado. Referências a nós entre irmãos são
  mais seguras quando resolvidas e validadas no próprio script.

**Dúvidas/decisões que ficaram para o playtest:**

- Alcance do golpe do inimigo (2 m) não está na Spec — decisão pendente.
- Vida/morte/respawn do jogador indefinidos — o jogador só registra dano.
- Sensação dos valores: 80 HP, 15 de dano, 1 s, 8 m, 4 m/s.

## 2026-09-18 — Unidade 3: domesticação

**O que foi ensinado/aplicado:**

- **Separar "quem decide" de "quem sofre":** a lógica de canalização (tecla,
  distância, tempo) fica num nó `DomesticationChannel` filho do jogador; o
  dinossauro só oferece uma pequena API (`can_be_domesticated`,
  `domesticate`, `set_prompt`). Assim o `wild_dino.gd` não conhece a tecla E
  nem o jogador, e o `player.gd` não cresce.

- **Limiar como fração do HP máximo:** `hp <= MAX_HP * 0.3`. Se o HP máximo
  mudar no playtest, o limiar acompanha sem outro ajuste. Com 20 de dano por
  golpe, o 3º golpe deixa 20 HP (≤ 24) e a opção aparece; o 4º mataria.

- **Cancelar por transição de estado:** o progresso é uma variável que só
  cresce enquanto E está pressionada e o mesmo alvo continua em alcance;
  qualquer outra situação zera. Não há timer para cancelar: "reiniciar do
  zero" sai de graça de zerar a variável.

- **Conversão por grupos:** domesticar = sair de `wild_dino` e entrar em
  `domesticated`. O dinossauro passa a ser alvo dos outros selvagens e deixa
  de ser candidato à domesticação, sem trocar de cena nem de script (Spec 004
  vai apenas acrescentar o comportamento de aliado).

- **Input Map desde o início:** ação `domesticate` (E), seguindo a lição do
  ataque na Unidade 1.

**Dúvidas/decisões que ficaram para o playtest:**

- Distância de domesticação (3 m) não está na Spec — decisão pendente.
- Vida ao domesticar: mantém o HP atual (baixo). Cura? Decisão pendente.
- Sensação dos valores: 30% de limiar e 2 s de canalização.

## 2026-09-25 — Unidade 3: bug de domesticação reaberto

**O que foi ensinado/aplicado:**

- **Reproduzir antes de corrigir:** uma simulação headless da cena real,
  com T e E enviados como eventos de teclado, comprovou 3 causas. Nenhuma
  estava na leitura do E: (1) T gerava a variante não domesticável; (2) o
  alvo era o selvagem mais próximo, mesmo que não fosse elegível; (3) a
  troca de alvo zerava o progresso.
- **Uma mudança numa unidade pode quebrar o teste de outra:** repontar o T
  para o Carnotauro (Unidade 4) inviabilizou o roteiro da Unidade 3. Quem
  troca um gatilho de teste precisa revisar os roteiros que dependem dele.
- **Filtrar pelo critério da ação, não só pela distância:** o candidato à
  domesticação deve ser o elegível mais próximo; aviso e interação usam a
  mesma função (`can_be_domesticated`).
- **Travar o alvo durante uma ação contínua:** enquanto a canalização for
  válida, o alvo não muda. Isso evita que um detalhe físico, como dois
  dinossauros se empurrando, zere o progresso.
- **Objetos liberados e tipagem:** passar um nó já liberado para um
  parâmetro tipado (`dino: Node3D`) gera erro. Em funções de verificação
  como `_is_alive`, use um parâmetro sem tipo e `is_instance_valid` antes
  de qualquer outra chamada.
- **Logs por mudança de estado:** o diagnóstico só registra o E pressionado
  ou liberado, o motivo do bloqueio e o progresso a cada 0,5 s. Isso separa
  "o E não chegou" de "o E chegou, mas uma condição bloqueou".

**Dúvidas/decisões que ficaram para o playtest:**

- Segurar E depois de concluir inicia a canalização em outro selvagem
  elegível no alcance, se houver. Deve exigir soltar e apertar de novo?
  (Não definido na Spec 003.)

**Resultado do playtest (2026-09-25):** os logs confirmaram detecção do E,
elegibilidade, cancelamento por tecla e por distância (3.06 m e 3.10 m > 3 m),
reinício em zero e conclusão com 20/80. O "desaparecimento" após o T foi o
novo selvagem matando o aliado de 20 HP, como a Spec 002 prevê. Isso não é
defeito. **Lição:** separar "o log prova" de "o log não mostrou nada". A
ausência de log de ataque não prova o comportamento visual, então o
progresso na tela e a estabilidade do aliado seguem pendentes.

**Encerramento (2026-09-25):** o playtester confirmou visualmente o texto de
progresso na tela e o aliado estável por cerca de 10 s (20/80, sem atacar,
sem ir ao Territory). Unidade 3 concluída.

## 2026-10-03 — Spec 007: câmera estratégica

- **`top_level = true`:** um nó filho que ignora o transform do pai. A câmera
  fica organizada dentro da cena do Player, mas copia só a posição dele
  (por código) e nunca a rotação. É a forma mais barata de "seguir sem
  girar".
- **Suavização independente de FPS:** `lerp(alvo, 1 - exp(-k * delta))` em
  vez de `lerp(alvo, k * delta)`. O resultado é o mesmo a 30 ou 144 Hz, e
  `k = 0` vira "sem suavização".
- **Movimento relativo à câmera:** pegar a frente (`-basis.z`) e a direita
  (`basis.x`) da câmera, zerar o Y e normalizar. Assim W é "para cima na
  tela" mesmo com a câmera inclinada.
- **Mouse → mundo:** `project_ray_origin/normal` + `Plane.intersects_ray`
  dão o ponto do chão sob o cursor, sem precisar de colisor no chão.
- **`_input` × `_unhandled_input`:** `_input` recebe o evento antes da GUI.
  Por isso, com cursor visível, o ataque foi para `_unhandled_input`, e
  botões e painéis que consomem o clique impedem o golpe.
- **Overlap só atualiza no passo de física:** girar a `AttackArea3D` e
  consultar `get_overlapping_bodies()` no mesmo quadro devolve a lista
  antiga. `SceneTree.physics_frame` é emitido *antes* do passo, então foram
  necessários dois `await` para garantir um passo completo. O teste
  automatizado pegou isso: com um único `await` o clique que virava o
  jogador errava o alvo.

## 2026-10-03 — Spec 008: noite → dia sem interrupção

- **Estado × apresentação:** a regra (DIA após vencer a onda) já estava no
  `DayNightManager`. O que interrompia o jogo era só a UI (`_result`
  pausando a árvore). Separar os dois deixou a mudança pequena e sem risco
  para a lógica de onda/derrota.
- **Aviso passageiro com `Tween`:** `tween_interval` → `tween_property`
  (`modulate:a`) → `tween_callback(queue_free)`. Como o aviso fica sob `main`
  (`PROCESS_MODE_ALWAYS`), ele termina de sumir mesmo se o jogador pausar.
- **Uma fonte de verdade para controles:** a constante `CONTROLS` alimenta as
  duas telas (menu principal e pausa), em vez de duas strings que podem
  divergir.
- **Teste com mouse real:** eventos sintéticos não movem o cursor do sistema.
  Se o jogo lê `get_mouse_position()` a cada quadro, o teste precisa
  `Input.warp_mouse()`. Com câmera suavizada, também precisa esperar a câmera
  alcançar um teleporte antes de converter mundo → tela.

## 2026-10-03 — Spec 009: contratos físicos e obstáculos

- **Camada versus máscara:** camada 4 corresponde ao bit 8. Acrescentar
  construções levou Player de mask 5 para 13 e criaturas de 3 para 11;
  o sensor de ataque permaneceu layer 0/mask 4.
- **Colisão e alcance devem concordar:** um colisor na plataforma inteira
  impediria o dinossauro de alcançar 1,5 m do Territory. O núcleo de raio
  0,55 m permite a cápsula de raio 0,5 m aproximar-se e atacar de verdade.
- **Forma simples e escala unitária:** dimensões das meshes entram no shape;
  não se coloca CollisionShape sob mesh com escala não uniforme. A cena
  física separada é editável e regenerável a partir da arte atual.
- **Teste de bloqueio precisa isolar a aproximação:** no bosque, iniciar
  longe de uma árvore pode colidir com outra antes. A suíte verifica tanto
  o corpo atingido na consulta quanto movimento real até a superfície.
- **Obstáculo não é navegação:** colisão impede atravessar, mas não ensina
  a IA direta a contornar. Mantido o corredor central e adiada para a Spec
  010 a solução de navegação/empilhamento, sem offsets improvisados.

## 2026-10-03 — Spec 010: navegação e grupos

- **Colisão ≠ navegação (de novo):** a Spec 009 impediu atravessar; a
  navmesh ensina o caminho. Assar a partir dos **colisores** (não da arte)
  garante que a malha e a física concordam sobre o que é sólido.
- **Ilhas na navmesh:** objetos baixos e largos (pedra de 0,85 m, topo do
  arco) viram pequenas áreas "andáveis" desconectadas. `region_min_size`
  (área mínima do Recast) as remove; sem isso a busca de "ponto mais próximo"
  pode parar em cima da pedra.
- **Altura conta:** a superfície da navmesh fica acima do chão físico. O
  `NavigationAgent3D` mede chegada em 3D. Destino no y do chão = "nunca
  alcançável". Projetar o destino na superfície resolveu.
- **Avoidance não é separação final:** o RVO desvia quem anda. Para o grupo
  não disputar o mesmo ponto, cada criatura precisa de um destino próprio
  (slot), estável e liberado explicitamente.
- **Quem está parado sai do avoidance:** assim vira obstáculo fixo para os
  outros e não é empurrado para fora do alcance do golpe.
- **"Mais perto" não é "cercar":** com o slot mais próximo, todos que vêm do
  mesmo lado enchem o mesmo lado. Somar um prêmio por distância angular aos
  slots ocupados espalha o grupo.
- **Medir o que importa:** um teste que olhava `home_position` (gravada antes
  do spawn posicionar a criatura) acusou spawns iguais. Medir a posição real
  no quadro do spawn mostrou o problema verdadeiro (todos no ponto 0).

## 2026-10-04 — Spec 011: vida, morte e respawn do jogador

- **Contrato pequeno aguenta:** `take_damage(amount)` (ADR 0001) bastou.
  Invulnerabilidade, morte e respawn ficam dentro de quem recebe o dano; quem
  ataca não precisou mudar.
- **Invulnerabilidade é do alvo:** com uma janela por inimigo, três dinos
  ainda acertariam juntos. Uma janela no Player resolve o cerco sem tocar
  no cooldown das criaturas.
- **Sair do grupo é a integração mínima:** a IA busca alvos por grupos
  (ADR 0002). Tirar o Player morto do grupo `player` fez inimigos de onda
  voltarem ao refúgio e o territorial voltar para casa, sem mexer na Spec 010.
- **Timer de nó, não de árvore:** um `Timer` filho do Player pausa com o
  jogo e some com o mundo ao reiniciar. Um timer da SceneTree poderia
  disparar sobre um Player já liberado.
- **Tempo de jogo em testes:** com `--fixed-fps` em headless o jogo corre
  mais rápido que o relógio. Medir respawn em ms de parede deu 0,21 s;
  em quadros de física, 2,00 s.

## 2026-10-04 — Spec 012: primeiro mapa (continuação de trabalho interrompido)

- **Disco > resumo:** o relato do assistente anterior falava em 10 arquivos.
  O disco tinha mais (gerador do mapa, regiões, executor de testes, gerador
  legado bloqueado). Sem git na pasta, a data de modificação foi o diff.
- **Edição não aplicada também é estado:** a última mudança do Astra
  (`srgb_to_linear`) só existia no gerador. Regerar a teria aplicado e
  escurecido o mapa. Antes de rodar um gerador herdado, conferir se a
  cena salva bate com ele.
- **Ler a cena como o Godot lê:** um parser de texto procurando
  `position =` não enxerga `transform = Transform3D(...)`. Instanciar a
  cena e ler `position/rotation/scale` elimina essa classe de erro.
- **Specs interagem nos testes:** a suíte de navegação (Spec 010) foi
  escrita antes de o Player ter vida. Com a Spec 011, os perseguidores o
  matavam no meio da medição. Corrigiu-se a fixture, não o contrato.
- **Câmera fixa define onde pode haver árvore:** olhando para −Z, uma copa
  a até ~3,5 m do lado +Z de uma trilha esconde quem anda nela. Árvores ficam
  atrás; pedras baixas ficam na frente. Virou verificação automática.

## 2026-10-04 — Spec 013: relógio e ciclo automático

- **Uma fonte de verdade:** o autoload que já guardava DIA/NOITE ganhou o
  relógio. HUD, onda, dano noturno e visual continuaram consultando o mesmo
  lugar, e quase nada fora dele mudou.
- **Relógio ≠ regra:** o horário só apresenta o tempo. A noite termina pela
  onda, não pelas 06:00. Segurar o relógio em 05:59 evita "inimigos
  sumindo" e mantém uma única condição de vitória.
- **Tempo de jogo, não de sistema:** somar o `delta` só quando `can_play()`
  dá pausa, menu e derrota de graça, e testes acelerados determinísticos
  com `--fixed-fps`.
- **Testes antigos e contratos novos:** a checagem de mesmo quadro do
  acceptance continuava "passando" depois que a Noite 2 ganhou 4 inimigos,
  mas deixou de testar o que dizia. Teste verde nem sempre é teste válido.
- **Rotas como dado:** intercalar os pontos por rota (índice % 3) fez a
  distribuição em rodízio sair sem um sistema novo de rotas.

## 2026-10-04 — Spec 013B: economia e torres

- **Recompensar onde a contagem já é única:** o WaveManager já garantia que
  cada inimigo sai da onda uma vez. Pendurar a recompensa ali, só para
  "morreu", deu proteção contra pagamento duplo e contra o "farm"
  domesticar → matar sem nenhum controle extra.
- **Grupo como contrato de alvo:** `wave_enemy` (posto no spawn, tirado na
  neutralização) + `wild_dino` + não `domesticated`. A torre não precisa
  conhecer Player, aliados ou refúgio para nunca atacá-los.
- **Estado de sessão na cena do mundo:** economia e torres vivem no mundo.
  Reiniciar recria tudo; não houve código de reset.
- **Teste que falha nem sempre acusa o código:** três falhas iniciais eram
  do cenário do teste: a torre mirou o inimigo mais próximo, um objeto já
  liberado, um HP já reduzido pela torre. Um diagnóstico isolado separou bug
  de teste antes de qualquer correção.
- **Uma regra para o volume:** "slider 0 ⇔ mudo", mais guardar o último
  volume diferente de zero, eliminou estados inconsistentes entre ícone e
  slider.

## 2026-10-04 — Spec 013C: o clique que sumia

- **Reproduzir antes de corrigir:** o "primeiro clique não fere" não
  aparecia com o dino parado (38/38 acertos). Só o cenário real — clicar
  quando o dino *parece* colado (~3 m) — mostrou 0/8. A causa era o cooldown
  de um golpe no vazio engolindo o clique seguinte, não a mira nem a física.
- **Corrigir a causa, não o sintoma:** em vez de "dois ataques por clique",
  o golpe no vazio passou a recuperar rápido e um clique perto do fim do
  cooldown fica guardado, saindo uma única vez.
- **Resolver no momento certo:** consultar a forma do golpe no próprio
  clique (na rotação atual) eliminou a dependência da sobreposição do passo
  anterior e um caminho real de golpe duplo.
- **Teste com janela tem mouse de verdade:** o cursor do sistema sobre o
  jogo ativa a mira contínua. Testes que fixam a rotação à mão precisam
  isolar o mouse real; provado com o cursor dentro e fora da janela.
- **Não assinar sinal global por objeto:** 14 recursos assinando
  `day_started` quebrariam a verificação de "reinícios não acumulam
  conexões". Comparar `day_number` só enquanto esgotado dá o mesmo resultado
  sem tocar no autoload.

## 2026-10-05 — Spec 013D: construção, cura e testes com janela

- **Fundação antes de paredes:** começar o posicionamento com estruturas
  que não mudam a navegação (fogueira com avoidance, armadilha sem corpo)
  validou receita → fantasma → validação → posicionamento sem tocar em
  navmesh e rotas.
- **Gasto atômico na fonte:** `spend_resources(wood, stone)` no próprio
  `ResourceStock` evita "meio pagamento" e uma segunda contagem.
- **Teclas simuladas chegam no quadro de processo:** com janela e quadros
  perdidos, vários passos de física cabem num quadro; esperar só física não
  garante a entrega do evento.
- **Testar a hipótese antes de "consertar":** a suspeita de perda de foco
  era falsa. O log mostrou a tecla chegando depois da verificação, e a
  opção criada para o foco foi removida.
- **Pausa não chama `_physics_process`:** cancelamentos "ao pausar" precisam
  de `NOTIFICATION_PAUSED` (contribuição preservada de outra sessão).
- **Máquina sobrecarregada muda o resultado com janela:** o avoidance
  responde por quadro desenhado. Com FPS baixo, a IA anda menos que os
  testes esperam; `--fixed-fps` separa o problema do código do problema da
  máquina.

## 2026-10-06 — Spec 014: céu, luz e o que a câmera realmente vê

- **Medir antes de desenhar:** a câmera estratégica não mostra o céu. Trocar
  o fundo por magenta e contar pixels em 6 pontos (0%) evitou implementar
  Lua e estrelas que ninguém veria no jogo; a decisão voltou ao usuário.
- **Hora contínua, mesma fonte:** `clock_hours()` deriva do mesmo
  `phase_elapsed` do relógio da HUD. O visual não tem relógio; pausa,
  derrota e reinício funcionam "de graça".
- **Quadros-chave em vez de estados:** uma tabela por hora interpolada é
  fácil de ajustar e não tem bordas onde piscar.
- **Sol alto ilumina mais o chão:** manter a energia constante estourou o
  meio-dia; a energia precisa cair quando o Sol sobe.
- **Neblina colorida domina tudo:** pouca densidade já tinge o mapa inteiro
  na câmera de cima; o pôr do sol ficou bonito ao reduzir neblina e
  saturação.
- **Lambdas em sinais de autoload não se desligam sozinhas:** um mundo
  recriado a cada Reiniciar acumulava conexões. Métodos se desligam quando
  o nó é liberado; o teste antigo de `acceptance` pegou.
- **Uma luz, dois astros:** trocar Sol ↔ Lua na mesma luz direcional quando a
  energia está perto de 0 evita o custo de duas sombras e não aparece.
- **Playtest aprovado (2026-10-06):** o ciclo visual foi validado em
  gameplay sem ajustes depois da entrega; os sinais no chão (luz da Lua e
  estrelas no gramado) bastaram para comunicar a noite sem mexer na câmera.

## 2026-10-06 — Spec 015: territórios com o que já existia

- **Reusar o encontro como guardião** resolveu o amanhecer de graça: o
  spawner só recria ponto vazio, e o território só marca guardião enquanto
  está selvagem e sem neutralização. Nenhuma regra nova de reaparecimento.
- **Neutralização como evento único:** sinais `died`/`domesticated` com
  `CONNECT_ONE_SHOT` e o outro desligado na hora; a morte posterior do
  aliado não chega ao território.
- **"Uma segurada = uma interação"** precisa de dono da segurada, não de
  prioridade por quadro: sem isso, terminar uma domesticação perto do marco
  já pronto ativaria o marco com o mesmo E.
- **Sondar o mapa antes de escolher pontos** (cilindro + navmesh + distância
  de rota) evitou marcos e testes em cima de árvores ou rotas.
- **Medir desempenho intercalando configurações:** uma medição isolada
  indicou 1 ms; intercalando, o custo real ficou em ~0,4 ms.

## 2026-10-08 — P0/P1: o dino que "chegava" onde já estava

- **Destino de navegação e checagem de chegada precisam ser o mesmo ponto.**
  O agente recebia destino novo só depois de 0,5 m; a chegada usava o
  destino atual com 0,25 m. No intervalo, a criatura mirava um ponto onde já
  estava, e poucos centímetros normalizados viravam 4 m/s em direção
  aleatória. A hipótese de "falta de histerese" estava errada: medir antes de
  corrigir mudou a solução.
- **Distâncias do NavigationAgent3D são 3D:** com a navmesh ~0,5 m acima da
  origem, `target_desired_distance` = 0,25 nunca é atingido.
- **Olhar para a velocidade do avoidance faz o corpo tremer** em grupo; a
  velocidade real suavizada (0,12 s) filtra o ruído e mantém curvas reais.
- **Teste de movimento precisa provar que algo se moveu:** com o jogo
  pausado, toda janela "parada" passa. Os checks de trajeto mínimo pegaram
  isso na primeira execução com janela.
- **Ler estado no sinal, não depois de esperar quadro:** o relógio anda no
  `_process`; o teste esperava `physics_frame` e via 18:01.
- **Um conflito de regras pede um dono, não uma prioridade:** E da
  domesticação bloqueia o ataque, E do marco não — o `e_hold_owner` da
  Spec 015 já resolvia. Um teste que chama a função direto não cobre o clique
  real.
- **Testes com janela no Windows:** o jogo pausa ao perder o foco; `timeout`
  do bash não mata o Godot nativo; caminhos longos de `APPDATA` estouram o
  limite de 260 caracteres no cache de shaders; `frame_post_draw` espera
  para sempre se a janela não desenha.
- **Playtest aprovado (2026-10-08):** movimentação, domesticação, aliados e
  territórios sem regressões.
