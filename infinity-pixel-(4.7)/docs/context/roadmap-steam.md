# Roadmap realista até um lançamento comercial (Steam)

Data: 09/10/2026. **O jogo não está pronto para lançamento.** Os testes
automatizados verificam regras e estabilidade, não diversão, retenção nem
qualidade de produto. Este roadmap separa o que existe do que falta.

## Onde estamos: protótipo avançado / início de vertical slice

Existe: um mapa (48 × 52 m), ciclo dia/noite com ondas, combate corpo a corpo
com preparação visível do inimigo, domesticação e aliados, coleta, 2
construções, torres em 6 pontos, 3 territórios, tutorial jogável, HUD,
inventário, configurações básicas, 25 suítes de teste automatizadas.

Não existe: salvamento, progressão de longo prazo, conteúdo além da primeira
hora, efeitos sonoros variados, localização, controle (gamepad), exportação
testada em máquina limpa, página de loja.

## Fase 1 — Vertical slice (6–10 semanas)
Meta: 20–30 minutos que representam o jogo final em qualidade.
- Aprovar e implementar P1–P3 (`propostas-game-design.md`).
- Áudio: efeitos para golpe, impacto, coleta, construção, domesticação,
  torre e ambiente dia/noite (ver `audio-auditoria.md`).
- Arte: modelos próprios do herói e dos dinossauros (hoje primitivas
  facetadas), animações com esqueleto (ataque, dano, corrida).
- Playtests com 5+ pessoas de fora do grupo, com roteiro e métricas
  (tempo até a 1ª domesticação, mortes na 1ª noite, abandono).

## Fase 2 — Alpha (2–3 meses)
- Salvamento/carregamento (fim de cada noite) e sessões longas estáveis.
- Conteúdo: 7–10 noites com variantes (P4, P5), 2º mapa ou expansão.
- Suporte a gamepad; remapeamento de teclas; legendas/textos acessíveis.
- Exportação Windows automatizada (`export_presets.cfg`), teste em máquina
  limpa sem Godot instalado; relatório de travamentos.

## Fase 3 — Beta (1–2 meses)
- Balanceamento por dados de playtest; dificuldade selecionável.
- Localização (PT-BR/EN no mínimo).
- Desempenho medido em 3+ máquinas (incluindo uma Iris Xe na tomada e na
  bateria); meta 60 FPS no pior 1% em cenários vivos.
- Licenças: inventário de todos os assets e fontes (`docs/ac1/ASSETS.md`),
  créditos completos.

## Fase 4 — Release candidate
- Página da Steam, trailer, capturas, cápsulas; demo (Steam Next Fest).
- Integração Steamworks (conquistas, nuvem) — **não feita e fora do escopo
  atual**.
- Congelamento de conteúdo, só correções; plano de patch pós-lançamento.

## Riscos principais
- Escopo: um time acadêmico pequeno; priorizar profundidade de um mapa a
  vários mapas rasos.
- Arte de personagens é o maior salto de qualidade pendente.
- Diversão de longo prazo ainda não validada (P6 + salvamento).
