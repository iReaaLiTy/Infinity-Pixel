# Validação — Vale de Jade (017A etapas 3–4, 018, 019), HUD (017B/020) e Tutorial (022)

Data: 09/10/2026. Base: `a3f8d41` (017A etapas 1–2 + inimigo noturno, já em `origin/main`).
Execução autônoma autorizada pelo usuário (fases A–H). **Sem push.** Nada foi aprovado
manualmente: todas as specs abaixo aguardam o playtest do usuário. A Spec 015 mantém o
status documental (aguardando aprovação formal).

Máquina: Intel Iris Xe, GL Compatibility, Godot 4.6.2, janela 1280 × 720 (e 1920 × 1080 na HUD).
Evidências: `vale-de-jade-evidence/` (ver `LEIA-ME.txt`).

## Estado de cada entrega

| Entrega | Implementado | Testado (sem janela) | Testado (com janela) | Playtest manual |
|---|---|---|---|---|
| Inimigo noturno azul-violeta (Fase B) | sim (já estava em `a3f8d41`) | sim | sim | **pendente** |
| 017A — Refúgio, chão, trilhas, paredões, pontos de defesa, luz | sim | sim | sim | **pendente** |
| 018 — Floresta, Região Rochosa, ruína, entradas, coletáveis, marcos | sim | sim | sim | **pendente** |
| 019 — Criaturas e combate (feedback visual) | sim | sim | sim | **pendente** |
| HUD extraída de `main.gd` (refatoração) | sim | sim | sim | **pendente** |
| 017B/020 — HUD e leitura de recursos | sim | sim | sim | **pendente** |
| 022 — Tutorial jogável | sim | sim (35 checks) | sim (35 checks) | **pendente** |
| Propostas de economia G1–G6 | não (fora do autorizado) | — | — | — |

## Fase A — estado encontrado

- `main` = `origin/main` = `a3f8d41` ("sss"), árvore limpa, sem stash.
- `a3f8d41` já continha a 017A etapas 1–2 **e** a identidade do inimigo noturno
  (`docs/validation/night-enemy.md`, `tests/night_enemy_visual`). A tarefa interrompida pelo
  reinício estava **concluída e enviada**; nada parcial nos arquivos.
- Linha de base reexecutada: **19/19 suítes, 663 checks, 0 falhas** (idêntico ao relatório anterior).

## Fase B — inimigos noturnos

Confirmado nos arquivos, no teste (16/16) e nas capturas. Único resíduo corrigido nesta
execução: o rótulo sobre o inimigo dizia "SELVAGEM"; agora diz **INVASOR** em violeta.

## Fase C/D — Vale de Jade (017A etapas 3–4 + 018)

Tudo gerado por ferramentas (pipeline reproduzível: `tools/build_first_map.gd` →
`build_refuge_art.gd` + `build_valley_art.gd`). **Navmesh e `arena_collision.tscn` com o mesmo
hash; os 87 corpos estáticos, as fontes de colisão e as 44 posições de gameplay iguais à linha
de base** (`visual_invariants` 14/14).

- **Chão (uma malha em blocos 3 × 3):** grama em tons médios com manchas suaves (fim do amarelo
  lavado), Floresta Oeste verde-azulada escura, Região Rochosa verde-acinzentada com líquens,
  clareira mais clara, sombra de copa sob as árvores, pé dos paredões escurecido. Cor por vértice
  (transições suaves) com variação por triângulo (facetado).
- **Trilhas:** terra batida nas mesmas posições e larguras (dados compartilhados em
  `tools/valley_layout.gd`), borda escura irregular, grama pisada em volta, pedrinhas rentes;
  rotas noturnas mais marcadas que as trilhas selvagens. As malhas antigas continuam como
  **dados ocultos** (os testes leem os trechos).
- **Refúgio:** plataforma facetada em 2 níveis com friso jade (mesma pegada da antiga), pátio de
  lajes com degraus, braseiros de pedra com chama âmbar e estandartes em T sobre os sólidos já
  existentes, rosácea de pedra no posto central, moldura de madeira com estacas na área de
  construção, torre de vigia jade além do paredão sul.
- **Pontos de defesa:** os 6 no estilo jade + **anel jade tracejado** rente ao chão — resolve a
  baixa legibilidade de longe apontada na Etapa 2. Torre facetada (mesma API e alturas).
- **Paredões:** colunas de rocha facetada em volta do vale inteiro (não só o trecho sul), com
  **passagens abertas nas 3 entradas das ondas** e **monólitos escuros com runa azul-violeta** que
  acendem à noite ("por aqui vem a ameaça"). Montanhas facetadas ao fundo.
- **Natureza (018):** árvores em 3 espécies (copa larga, pinheiro, árvore-jade), rochas facetadas
  com musgo/líquen — trocando só malha e material dos nós antigos (transform intacto).
  **Coletáveis distintos:** árvore de copa amarelada com corte de machado; rocha escura com
  cristais de minério azul e âmbar.
- **Ruína do Arco** facetada sobre os mesmos sólidos; **marcos de território** facetados com
  faixa de runas na cor do estado; contorno de território tracejado.
- **Luz do meio-dia:** o arco do Sol foi girado 0,7 rad (`SUN_AZIMUTH_OFFSET`). Ao meio-dia a luz
  vem de trás-direita em vez de exatamente atrás da câmera: as faces ganham volume e as sombras
  aparecem. Horários, energia, cores, ambiente, relógio e durações **não mudaram**
  (`sky_cycle` 45/45, `day_cycle` 43/43). Capturas nas 6 horas de referência.

Novo no `visual_invariants` (+2): `ValleyArt` sem corpo físico e fora de `navigation_source`;
nenhum vértice acima de 0,3 m na área andável fora de um sólido existente.

## Fase E — criaturas e combate (019)

Só apresentação: velocidade, rumo, alvo, dano e instante do dano iguais
(`creature_motion` 32/32, `gameplay_stability` 15/15, `domestication_regression` 26/26).

- Respiração em repouso; recuo visual curto e lampejo leve (overlay por ator) ao receber dano;
  faíscas de impacto; explosão na cor da criatura ao ser eliminada.
- Domesticação: **anel jade** sob o selvagem que já pode ser domesticado; um segundo anel cresce
  com o progresso de E; anéis e lascas jade ao concluir; aviso em jade.
- Rótulos maiores e coloridos por tipo: ALIADO (+ FICAR) jade, GUARDIÃO âmbar, INVASOR violeta,
  SELVAGEM creme. Losango jade sobre o aliado em FICAR.
- Torre: lasca jade facetada apontada para o alvo, com rastro e faísca no impacto (mesmo
  `BOLT_TIME`, dano na chegada como antes); anel jade sob o inimigo mirado.
- Coleta: lascas facetadas a cada golpe (madeira e pedra).

## Fase F — HUD

1. **Refatoração (commit separado):** a HUD saiu de `main.gd` para `scenes/ui/hud.gd` sem mudar
   comportamento; `main.gd` (1272 → ~700 linhas) expõe os mesmos campos por encaminhadores.
   Validada antes do redesenho: 19/19 sem janela, menu 27/27 com janela.
2. **Redesenho (sem mudar textos conferidos pelos testes nem a economia):** painéis com estilo
   único; ícones de jogador e do cristal; barra do período (âmbar de dia, violeta à noite) com
   sol/lua; "+N" empilhados (antes se sobrepunham e cobriam o inventário); avisos empilhados;
   alerta "NOITE N · INVASORES A CAMINHO"; custos em falta em vermelho com "(faltam N)";
   coletável ao alcance com anel âmbar e dica com a recompensa. Conferido em 1280 × 720 e
   1920 × 1080 (`comparacao/hud_*`).

## Fase G — tutorial (Spec 022)

Ver `docs/specs/022-tutorial-jogavel.md`. 13 etapas no jogo real, avanço só por ação real,
instância isolada (relógio segurado só até a noite, 2 inimigos, sem guardião rochoso), sem
travas (selvagem derrotado, aliado morto, jogador caído), Reiniciar/Sair pela pausa, tela final.

## Testes (execuções reais)

| Execução | Resultado |
|---|---|
| Linha de base (`a3f8d41`), sem janela | 19/19 suítes, 663 checks, 0 falhas |
| Final, sem janela, `--fixed-fps 60` | **20/20 suítes, 700 checks, 0 falhas** |
| Final, com janela, `--fixed-fps 60` (cópia com observador de foco) | **21/21 suítes, 730 checks, 0 falhas, 0 perdas de foco** |

Nenhuma expectativa de teste antiga foi alterada. Novos checks: `visual_invariants` +2,
`tests/tutorial` 35. Aviso preexistente sem relação: `1 resources still in use at exit`.

Problemas encontrados e corrigidos durante a execução: erros de tipagem GDScript nos geradores
e na HUD extraída; lâminas de grama pretas (verso com normal invertida); 4 vértices do lintel do
arco exatamente na face do sólido; sobra de código no marco de território; o script de
execução local contava errado os erros do stderr (corrigido antes das execuções finais).

## Desempenho (com janela, sem vsync, 10 s por vista, 2 rodadas cada)

Antes = cópia de `a3f8d41`; depois = código final. Mesma sonda (`tests/perf_probe.tscn
--live`). Vistas estáticas com o jogo congelado; "vivo" = IA, torres, efeitos rodando.
FPS médio / pior 1% (rodada 1 · rodada 2).

| Vista | Antes | Depois | Chamadas (antes → depois) | Primitivas |
|---|---|---|---|---|
| padrão 12:00 | 163/82 · 158/87 | **191/79 · 196/99** | 1115 → 943 | 67k → 97k |
| padrão 17:30 | 252/104 · 233/121 | 247/121 · 241/137 | 562 → 904 | 35k → 94k |
| padrão 21:00 | 184/90 · 187/98 | **222/77 · 224/96** | 1013 → 597 | 62k → 80k |
| Refúgio 12:00 | 164/89 · 171/95 | **194/82 · 186/98** | 1045 → 922 | 63k → 96k |
| ponto oeste 21:00 | 159/91 · 162/87 | **198/111 · 206/109** | 1442 → 937 | 86k → 97k |
| vivo: dia com dinossauros | 136/65 · 130/67 | **170/75 · 164/78** | 1617 → 1105 | 95k → 113k |
| vivo: noite, 3 invasores, 3 torres, aliado | 132/69 · 160/60 | **184/66 · 185/63** | 1290 → 986 | 78k → 103k |
| vivo: onda de 10 invasores, 3 torres | 119/59 · 132/63 | **136/72 · 147/63** | 1826 → 1600 | 110k → 137k |

- A 1ª versão da arte nova tinha 171k primitivas e pior 1% ~10–15% abaixo do antes. Causa:
  o paredão inteiro numa malha (sem culling, redesenhado em todas as fatias da sombra) e o chão
  numa malha só. Correção: paredões sem sombra projetada e um por lado; chão e tufos em blocos
  3 × 3. Resultado acima (tabela "Depois").
- **Meta de 60 FPS:** atingida em todas as vistas medidas **nesta máquina**, inclusive o pior 1%
  (mínimo medido 62,8). Não é garantia para outras máquinas. Limitações: 10 s por vista,
  janela 1280 × 720, a variação entre rodadas iguais chega a ~20% no pior 1%.

## Pendências e limitações conhecidas

- **Playtest manual de tudo** (roteiro abaixo). Nenhuma spec foi marcada como aprovada.
- O inimigo noturno é calibrado para a noite; ao meio-dia parece cinza-escuro (só aparece de
  dia em capturas de diagnóstico).
- O cristal da torre à noite fica quase branco (emissão alta, comportamento já existente).
- `valley_art.tscn` tem ~6 MB (malhas geradas em texto, como o resto do pipeline).
- Economia G1–G6, noites especiais, antecipação da noite, renda passiva por território: **não
  implementados** (fora do autorizado). Nenhum custo, recompensa, dano ou vida mudou.
- Tutorial: não ensina recuperar marco de território, armadilha, melhoria de torre nem cura.

## Roteiro de playtest manual

1. **Menu:** o fundo mostra o vale novo; os botões JOGAR, CONTROLES, CRÉDITOS, TUTORIAL e SAIR.
2. **JOGAR, dia:** o chão está verde equilibrado (não amarelo)? As trilhas de terra são fáceis de
   seguir? O Refúgio parece o centro da base? Ao meio-dia há volume e sombras?
3. Ande até os pontos de defesa: o anel jade tracejado é reconhecível de longe? Erga uma torre (C).
4. **Floresta Oeste e Região Rochosa:** dá para distinguir árvores/rochas coletáveis da decoração?
   Colete: aparece o anel âmbar e a dica com a recompensa? Os "+N" ficam legíveis?
5. **Domesticação:** enfraqueça o guardião (4 golpes). Aparece o anel jade? Ao segurar E, o anel
   interno cresce? Ao concluir há o efeito jade? Aperte F: aparece "ALIADO · FICAR" e o losango?
6. **Inventário (I) e construção (B):** os custos em falta aparecem em vermelho com "(faltam N)"?
7. **Noite:** alerta "NOITE 1 · INVASORES A CAMINHO"; invasores azul-violeta com rótulo INVASOR;
   runas das entradas acesas; anel de alvo da torre e lascas; o Refúgio é o ponto mais claro?
8. Confira a movimentação dos dinossauros (sem tremedeira nem giros) e o desempenho percebido.
9. **TUTORIAL:** faça as 13 etapas. Teste também: derrotar o selvagem em vez de domesticar,
   morrer, ESC → Reiniciar, ESC → Sair do tutorial e depois JOGAR (o relógio deve andar).
10. Em 1920 × 1080: a HUD continua sem sobreposição?
