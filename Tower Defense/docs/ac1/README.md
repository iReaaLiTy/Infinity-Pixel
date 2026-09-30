# Infinity Pixel — entrega AC1 0.2

Jogo do estúdio Inity Pixel. O nome foi atualizado de Tower Defense Dino para Infinity Pixel a pedido do usuário; revisão da identidade pelo grupo segue pendente.

Abra `galeria.html` para consultar a apresentação, as pranchas, as capturas e ouvir as faixas. O GDD reflete o protótipo integrado. Atribuições pessoais, Trello, playtest e audição finais aguardam o grupo.

## Jogar

No Mac desta máquina, abra `jogo/delivery/Jogar.command`, que usa a Godot já instalada e `delivery/InfinityPixel.pck`. Para editar: importe `Tower Defense/project.godot` na Godot 4.7.2 e execute F6 em `scenes/ui/main.tscn` ou F5 (projeto).

Cena inicial: `scenes/ui/main.tscn`. Arena: `scenes/world/prototype_area.tscn`. Todo o projeto está no ZIP `delivery/Inity_Pixel_AC1_Projeto.zip`; `.godot` não é necessária, pois a engine reimporta os recursos.

Controles: WASD, mouse, clique para golpear, E por 2 s após três golpes, F para posicionar no dia, N para iniciar a noite, Esc para pausa. O jogador não tem HP; a derrota depende da base.

## O que consultar

- `GDD_AC1.md`: regras, recorte, decisões e propostas.
- `MATRIZ_ENTREGA.md`: oito itens, evidências, responsáveis pendentes.
- `TRELLO_E_ENTREGA.md`: oito cards completos, sem publicação externa.
- `ASSETS.md` e `IMAGEGEN_PROMPT.txt`: fontes, ferramentas e créditos.
- `SETUP_MCP.md`: configuração, versão e chamadas reais.
- `TESTES_AC1.md`: resultados executados e roteiro humano.
- `evidence/`: screenshots, schemas, relatórios e logs.
- `assets/final/`: pranchas finais em SVG/PNG.

## Exportação

O PCK foi exportado e iniciou na Godot instalada. Ele contém os dados do jogo e **não é um aplicativo independente**. Templates de exportação não foram encontrados. Para gerar o aplicativo: na Godot 4.7.2, abrir Editor → Manage Export Templates, instalar a versão compatível; depois Project → Export → preset macOS → Export Project. Testar o aplicativo resultante antes do envio. A assinatura/notarização para distribuição pública não faz parte desta entrega acadêmica local.

Veja a [documentação oficial de exportação](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).

## Estado de aprovação

Implementação e verificações automatizadas concluídas; não significam aprovação acadêmica/humana. O vídeo é uma demonstração automatizada, com posições organizadas para filmagem. Sem publicação no Trello nem atribuição inventada. O Game Designer faz o envio final.

Os prompts antigos destinados ao Claude e os SVGs iniciais foram preservados como histórico. A divisão de agentes neles foi substituída pelo pedido atual. O backup anterior à implementação permanece em `jogo/backups/`.
