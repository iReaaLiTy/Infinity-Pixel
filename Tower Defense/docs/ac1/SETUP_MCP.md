# MCP — configuração e comprovação em 30/09/2026

Cliente desta conversa: Codex desktop local, dentro de ChatGPT.app 26.924.22138; codex-cli 0.158.0-alpha.2.1. macOS 27.0 (26A428), Apple M4. Terminal e arquivos locais disponíveis. Nome de modelo/plano não foi usado como prova de conectividade.

## Ambiente confirmado

- Projeto: `/Users/juancarlos/Downloads/jogo/Tower Defense`.
- Godot: `/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official.ed1daf0bf`.
- Node: `/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node`, v24.21.0.
- npm: 12.1.0, obtido pelo Corepack já incluído no aplicativo.
- Servidor preservado do pedido original: `@yanhuifair/godot-mcp@1.12.3`. README requer Godot 4.x e Node >=18; compatibilidade básica comprovada por chamadas reais. A alternativa Coding-Solo não foi instalada.
- Transporte: STDIO local. Nenhum endpoint público foi criado.

## Configuração sem segredos

Em `~/.codex/config.toml` (outros servidores preservados):

```toml
[mcp_servers.godot-mcp]
command = "/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules/corepack/shims/npx"
args = ["-y", "@yanhuifair/godot-mcp@1.12.3", "-p", "/Users/juancarlos/Downloads/jogo/Tower Defense"]

[mcp_servers.godot-mcp.env]
PATH = "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin:/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules/corepack/shims:/usr/bin:/bin"
GODOT_PATH = "/Users/juancarlos/Downloads/Godot.app/Contents/MacOS/Godot"
```

Cópia privada da configuração anterior: `~/.codex/config.toml.ac1-backup-20260930`. Ela não integra o pacote acadêmico. Backup dos arquivos originais do projeto: `../backups/Tower_Defense_antes_AC1_20260930.zip`, relativo à pasta `jogo`.

## Teste real

As ferramentas novas não estavam expostas nativamente no catálogo desta conversa. Foi usado um cliente MCP local pelo SDK, que iniciou o mesmo servidor instalado, realizou `initialize`, `tools/list` e `tools/call`. Isso comprova conexão STDIO real; não equivale a disponibilidade automática das ferramentas no chat atual.

| Chamada | Resultado |
|---|---|
| `tools/list` | 386 ferramentas; schemas completos em `evidence/mcp_tools.json` |
| `get_godot_version {}` | 4.7.2, binário e plataforma corretos |
| `read_project_config {}` | Na chamada original, Tower Defense Dino e cena `scenes/world/prototype_area.tscn`; depois, o nome do jogo foi alterado para Infinity Pixel |
| `get_status {}` | servidor funcional; pontes de editor e runtime desconectadas |
| `run_project {"headless":true}` | processo da Godot iniciado |
| `monitor_output {}` | engine e encontro (-10,0.5,5) registrados, sem erro de script na execução com permissões locais |
| `stop_project {}` | processos iniciados pelo servidor encerrados |

A primeira tentativa sob sandbox registrou bloqueio de gravação de logs. A repetição autorizada fora dele funcionou. Os resultados dessa repetição estão em `evidence/mcp_results.json`. A cena principal FINAL mudou para `scenes/ui/main.tscn`; ela instancia a arena existente ao jogar. Testes da entrega final usaram a Godot diretamente, com logs separados.

## Limitações e reconexão

Reinicie o cliente para reler a configuração e confira `codex mcp get godot-mcp`. Se o aplicativo ou a Godot mudarem de pasta, atualize os caminhos acima. Depois de conectar, faça `get_godot_version`, `read_project_config` e `get_status` antes de operar.

Nenhum addon foi instalado: o README do servidor exige addon para a ponte do editor e autoload para a ponte de runtime, enquanto operações de arquivos e processos usadas aqui funcionam sem isso. Portanto, não há declaração de acesso à árvore viva do editor. As capturas e a demonstração foram produzidas pela execução real de cenas de teste Godot, usando sua API de renderização e Movie Maker.

Referências consultadas: [MCP no Codex](https://learn.chatgpt.com/docs/extend/mcp?surface=cli), [README do servidor escolhido](https://github.com/yanhuifair/Godot-MCP). Fonte executável da verificação local: `jogo/tooling/mcp_probe.mjs`; usa o cache npm da máquina e não é necessária para jogar.
