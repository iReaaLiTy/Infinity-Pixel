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
