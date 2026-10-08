# Auditoria inicial AC1 — 07/10/2026

Fonte de verdade confirmada: `infinity-pixel-(4.7)/project.godot`, Godot 4.6.2, entrada `scenes/ui/main.tscn`. Auditoria por código, cenas, assets, Specs 001–015, registros de validação e documentação AC1. Estados abaixo descrevem o material **antes das alterações desta entrega**; existência de código não equivale a teste novo aprovado.

| Requisito | Status | Onde existe | O que falta | Ação necessária |
|---|---|---|---|---|
| Trello atualizado e responsáveis | PARCIAL | Screenshots dos cards em Feito; docs/ac1/TRELLO_E_ENTREGA.md | Quadro, anexos e nomes por função não verificados | Preparar checklist de anexação; fechamento externo pelo grupo |
| GDD e história | PARCIAL | docs/ac1/GDD_AC1.md; docs/context | GDD 0.2 contradiz Specs atuais; lore ainda proposta | Atualizar o GDD existente, separar implementado/planejado |
| Controles | PARCIAL | project.godot; main.gd; player.gd | GDD diz mouse=câmera e N normal | Documentar mira, C/I/B/R/H e debug inativo |
| Core loop | COMPLETO | scenes/player, enemies, world; tests | Revalidar execução atual | Rodar suites existentes sem redesign |
| Arte personagem/criaturas/cenário | COMPLETO | scenes/visuals; docs/ac1/assets/final | Evidências atuais do mapa | Capturar execução e reutilizar modelos/pranchas |
| Level/arena/mapa desenhado | PARCIAL | world_regions.tscn; prototype_area.tscn; planta AC1 antiga | Planta antiga de 40×40; mapa atual 48×52 | Captura panorâmica real e mapa documental atualizado |
| Menu inicial e HUD | COMPLETO | scenes/ui/main.gd e main.tscn | Revalidar entrada, áudio, HP, relógio, recursos e PD | Smoke automatizado com renderização |
| Trilha principal | COMPLETO | assets/audio/refugio_principal.wav; audio_director.gd; compose_score.py | Escuta humana da mixagem | Manter original, documentar principal/calma/combate |
| Logo/identidade do estúdio | COMPLETO | assets/ui/inity_mark.svg; docs/ac1/assets/logo_inity_pixel.svg; final/identidade.* | Aprovação do grupo | Organizar fontes sem renomear Inity Pixel |
| Logo/identidade do jogo | PARCIAL | game_icon.svg; menu atual; logo_jogo.svg antigo | Logo antigo diz Tower Defense Dino, jogo diz Infinity Pixel | Derivar assinatura vetorial da identidade existente com nome atual |
| Monetização | PARCIAL | Seção curta do GDD | Proposta defendível separada | Documento compra única, protótipo gratuito, sem loja |
| Press Release | AUSENTE | Não encontrado nos documentos inventariados | Texto específico atual | Criar release sem promessas de lançamento |
| GitHub | PARCIAL | .git da pasta pai; origin iReaaLiTy/Infinity-Pixel | Pasta atual não versionada, sem README/.gitignore local | Preparar localmente, documentar publicação manual |
| Apresentação final | AUSENTE | Galeria HTML e pranchas antigas, sem PPTX encontrado no projeto correto | Roteiro e deck atual | Produzir apresentação com screenshots reais |
| Moodboard | PARCIAL | Pranchas de identidade, personagens e cenário | Síntese visual atual com materiais/ambiente/UI | Montar moodboard do próprio projeto |

## Divergências comprovadas

- GDD antigo: jogador sem HP, dano 20, sem inventário/expansão, arena 40×40, N inicia noite. Atual: HP 100, dano 15, inventário, construção e territórios, arena X −24…24/Z −24…28, dia automático de 90 s; N apenas debug desativado.
- Nome do projeto: `Infinity Pixel (4.7)` (rótulo, não versão da engine); jogo: **Infinity Pixel**; estúdio: **Inity Pixel**. Arte antiga `logo_jogo.svg` diz Tower Defense Dino. Preservar como histórico.
- Specs 013C/013D/014 têm aprovação manual registrada; 015 implementada, com aprovação manual ainda pendente no registro. Não converter teste automatizado em aprovação humana.
- Git está um nível acima e rastreia arquivos de outra cópia, inclusive cache `.godot`. Esta pasta inteira aparece como não rastreada. Não mexer no índice ou arquivos das outras cópias. Remoto configurado não prova publicação desta versão.
- Prazo mostrado no enunciado: 04/10/2026 23:59, anterior à data desta auditoria. Aceitação de envio posterior depende da escola.

## Decisão de escopo

Nenhum sistema novo de gameplay é necessário pelos requisitos encontrados. Atualizar documentação, organizar identidade/evidências e testar. Corrigir gameplay somente se os testes demonstrarem bloqueador real. Sem publicação externa, commit ou alteração de outros projetos.
