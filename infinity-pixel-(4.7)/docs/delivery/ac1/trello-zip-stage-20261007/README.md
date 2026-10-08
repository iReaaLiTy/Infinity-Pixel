# Jadefall: Guardiões do Refúgio

Protótipo acadêmico da **Inity Pixel** para AC1 da FIAP School. **Jadefall: Guardiões do Refúgio** é um jogo de ação 3D e tower defense: explore, colete, domestique criaturas, construa defesas e proteja o Refúgio durante ondas noturnas.

## Abrir e jogar

1. Use **Godot 4.6.2**, renderer GL Compatibility. “(4.7)” é apenas o rótulo da pasta/aplicação.
2. Importe o `project.godot` **desta pasta**. Não use as cópias vizinhas.
3. Aguarde a importação e pressione F6 apenas para cena isolada ou **F5 para o projeto completo** (`scenes/ui/main.tscn`).
4. Clique **JOGAR**. Explore de dia; a noite começa automaticamente após 90 s. Defenda até neutralizar toda a onda. A destruição do Refúgio encerra a sessão.

| Entrada | Ação |
|---|---|
| WASD / mouse | Mover / mirar |
| Clique esquerdo | Atacar, coletar ou confirmar construção |
| E segurado | Domesticar; recuperar marco liberado de dia |
| F | Seguir/ficar com aliado de dia |
| C | Torre/melhoria no ponto defensivo de dia |
| I / B | Inventário / construção |
| R / botão direito | Girar / cancelar posicionamento |
| H segurado | Cura na Fogueira |
| Esc | Fechar painel/cancelar posição; pausar/retomar |

T/N são debug desativado. [Controles completos e regras](docs/ac1/GDD_AC1.md).

## Sistemas e estrutura

- `scenes/player`, `scenes/enemies`: movimento, mira, combate, vida/respawn, domesticação, aliados e navegação.
- `scenes/world`: mapa, Refúgio, coleta, inventário de materiais, Fogueira, Armadilha, torres/PD, dia/noite e territórios.
- `scenes/ui`: menu, HUD, pausa, áudio; `scenes/visuals`: modelos low-poly.
- `assets/audio`: composição original e mixagens; `assets/ui`: identidade existente.
- `docs/specs`, `docs/context`, `docs/validation`: contratos, decisões e histórico.
- `docs/delivery/ac1`: **[entrega atual](docs/delivery/ac1/README.md)**. Materiais antigos em `docs/ac1` podem refletir versões anteriores; GDD foi atualizado.
- `tests`, `tools`: regressões e geração de evidências.

Teste no Windows: `./tools/test_ac1.ps1`; com renderização: `./tools/test_ac1.ps1 -Rendered`. O runner usa o caminho Godot informado para esta máquina; adapte `$engine` se executar em outra. Resultados em `docs/delivery/ac1/evidence`.

Equipe registrada: Murilo Cassetti, Heitor Crispim, Pedro Ferreira, Juan Carlos. Funções individuais e Game Designer a confirmar. Produção assistida por IA conforme [proveniência](docs/ac1/ASSETS.md).

Status: protótipo, sem loja, multiplayer ou save persistente. Spec 015 aguarda aprovação manual do grupo. [Preparação/publicação GitHub](docs/delivery/ac1/GITHUB.md).
