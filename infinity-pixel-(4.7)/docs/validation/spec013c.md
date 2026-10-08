# Spec 013C — Registro de validação (2026-10-04)

Projeto executado: `C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel\infinity-pixel-(4.7)`.
Godot **4.6.2.stable.official.71f334935**, GL Compatibility em Windows.

## Causa do "primeiro clique sem dano" (reproduzida antes de corrigir)

Foram usados scripts temporários de diagnóstico (removidos depois) com
cliques reais via `push_input`:

| Cenário | Primeiro clique com dano |
|---|---|
| Dino parado a 1,7 m, 5 rumos, 1280×720 e 1920×1080 | 20/20 |
| Dino parado a 1,8–2,4 m, rumos laterais (erro de mira 14–29°) | 18/18 |
| IA ativa, clique quando o dino chega a 2,3 m | 8/8 |
| IA ativa, clique a ~3,2 m ("parece colado") e de novo ao chegar | **0/8** |

O golpe no vazio iniciava 0,8 s de cooldown, e o clique seguinte, já no
alcance, era descartado. Também havia um caminho de **golpe duplo**: com a
mira girando, o golpe esperava 2 quadros antes de iniciar o cooldown.
Correções na RF-CMB-002 da spec.

## Resultados automatizados (execução final)

| Suíte | Headless | Janela GL |
|---|---|---|
| `tests/combat_collect.tscn` (013C) | 46/46 | 46/46 |
| `tests/defense_economy.tscn` (013B) | 35/35 | 35/35 |
| `tests/main_menu.tscn` | — | 27/27 |
| `tests/day_cycle.tscn` (013) | 43/43 | 43/43 |
| `tests/day_cycle_real.tscn` (013) | 15/15 | — |
| `tests/world_layout.tscn` (012) | 57/57 | 57/57 |
| `tests/player_health.tscn` (011) | 47/47 | 47/47 |
| `tests/player_facing.tscn` | 37/37 | 37/37 |
| `tests/physics_contracts.tscn` (009) | 23/23 | 23/23 |
| `tests/navigation_contracts.tscn` (010) | 38/38 | 38/38 |
| `tests/acceptance.tscn` | 33/33 | 36/36 |

Sem crash 139. Os JSONs estão em `spec013c-evidence/`.

## Testes antigos ajustados (e por quê)

**Mudanças de contrato pedidas nesta spec:**

| Teste | Antes | Agora | Motivo |
|---|---|---|---|
| acceptance | 3 golpes → 20/80; clique → 60 | 4 golpes → 20/80; clique → 65 | Golpe 20 → 15. Com 3 golpes o dino ficava em 35/80 (não elegível) e 6 passos de domesticação/aliado falhavam em cascata |
| acceptance | domesticado com 20 HP | 80 HP | Domesticação restaura a vida |
| player_health | ataque 20 → 60; domesticado 20 | 15 → 65; domesticado 80 | Idem |
| physics_contracts | domesticar preserva HP 20 | restaura 80 (máscara física igual) | Idem |
| day_cycle | "DIA 1 • PREPARAÇÃO", "Noites defendidas: N" | "DIA 1" + relógio, "PREPARAÇÃO · Noites: N", onda em `onda_text` | Novo layout da HUD |
| defense_economy | 30 iniciais (30 → 0, 15, 30…) | 40 iniciais (+10 em cada saldo); painel "PONTO DE CONSTRUÇÃO" | Pontos iniciais 30 → 40 |

**Problemas de ambiente, não regressões, provados com o cursor dentro e fora
da janela:**

| Teste | Problema | Ajuste |
|---|---|---|
| player_facing, player_health (só com janela) | O cursor real do sistema sobre a janela gera movimento de mouse e ativa a mira contínua, que é correta no jogo, mudando a rotação que o teste fixou à mão. Cursor fora: 37/37 e 47/47; dentro: 27/37 e 46/47 | Essas suítes desligam a entrada de mouse do Player, porque medem teclado e vida, não mira. A mira por clique é coberta por `combat_collect`. Revalidadas com o cursor dentro da janela: 37/37 e 47/47 |

**Detalhes do teste da 013B:** o "+15" pode vir com nome sufixado
("PointsGain2") quando um anterior ainda está sumindo. O teste passou a
aceitar o prefixo.

## Verificação visual

Capturas em `spec013c-evidence/views/` pela câmera real:

| Captura | Conferido |
|---|---|
| `hud_antes_*` × `hud_depois_*` (1920×1080, dia e noite) | Antes: faixa contínua de ~1240 × 175 px. Depois: três grupos separados, ~125 px de altura; centro livre; números legíveis |
| Prévia no ponto vazio | Anel de 8 m ao redor do ponto e painel "PONTO DE CONSTRUÇÃO · Custo 30 · [C] CONSTRUIR" |
| Torre construída | Anel real de 8 m; painel "NÍVEL 1 · Alcance 8"; de longe, anel discreto |
| Posto antigo (0, −7) | Sem o texto "POSTO DE DEFESA" |
| Dinos diurnos | Um na clareira do bosque e outro na região rochosa |
| Árvore | Treme no golpe; no 2º golpe tomba; "+10 MADEIRA"; HUD Madeira 10 |
| Pedra | Lascas a cada golpe; quebra no 3º; "+6 PEDRA" (corrigido para não cortar na borda) |
| Domesticação | "ALIADO 80/80 HP"; "+15 PONTOS" de um inimigo da onda |

**Correção feita depois da primeira captura:** o "+6 PEDRA" saía cortado na
borda direita e ficava sobre o "ESC pausa". Agora fica abaixo do "ESC pausa"
e limitado à largura da tela. O "ESC pausa" ganhou contorno para ficar
legível em fundo claro.

## Limites conhecidos

- O buffer de clique (0,35 s) e a recuperação do golpe no vazio (0,3 s) são
  valores novos, sem playtest.
- Os recursos não estão na navmesh: o desvio vem do avoidance. Uma criatura
  pode raspar num recurso antes de contorná-lo; por isso os recursos ficam
  fora das rotas.
- As árvores coletáveis se distinguem pela copa mais quente e pelo corte no
  tronco. Precisa de playtest para confirmar se são reconhecíveis.
- Madeira e Pedra ainda não têm uso.
- O octógono do posto antigo continua no mapa, sem texto (pergunta em aberto
  na spec).

## TESTE MANUAL NECESSÁRIO

1. **Clique:** bater no dino de perto e "um pouco antes" de ele chegar.
   O primeiro clique no alcance deve sempre ferir, e nunca dar dois golpes.
2. **Sequência:** 80 → 65 → 50 → 35 → 20, domesticar e ver 80/80.
3. **Encontros:** achar os dois (bosque e pedras); ao amanhecer, os que
   faltam voltam.
4. **Torre:** anel de alcance ao chegar perto; prévia no ponto vazio.
5. **Coleta:** árvores (2 golpes, +10 Madeira) e pedras (3 golpes, +6 Pedra);
   conferir que voltam no amanhecer.
6. **HUD em 1920×1080:** legibilidade e espaço livre.
7. **Economia:** 40 pontos no início, construir, ondas dando +15.
