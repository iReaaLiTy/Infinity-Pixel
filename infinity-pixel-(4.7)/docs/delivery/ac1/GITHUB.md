# Git/GitHub — situação auditada

O repositório `.git` fica na pasta pai `Infinity-Pixel`, não dentro deste projeto. O remoto local é `https://github.com/iReaaLiTy/Infinity-Pixel.git`. **Esta pasta atual estava inteira não rastreada** na auditoria. Ter origin configurado não significa que esta versão esteja no GitHub; acesso remoto não foi testado e nada foi publicado.

A cópia vizinha `Tower Defense` possui alterações preexistentes e caches `.godot` rastreados. Nenhum arquivo/índice dessa cópia foi alterado. Não há arquivos desta pasta atual no índice; o ZIP antigo local não comprova entrega atual. O projeto tem três WAVs de aproximadamente 14,3 MB cada, necessários como áudio; `.godot`, ZIP, PCK e AVI são derivados que não precisam entrar no commit.

Foram preparados `README.md` e `.gitignore` locais. O ignore protege esta pasta, mas não remove caches já rastreados de outros projetos. Não usar `git add .` na pasta pai.

## Passos manuais de publicação, após revisar

No PowerShell, a partir da pasta pai:

```powershell
Set-Location -LiteralPath 'C:\Users\ppfti\OneDrive\Desktop\TDnovo\Infinity-Pixel'
git status --short
git remote -v
git add -- 'infinity-pixel-(4.7)/'
git diff --cached --stat
git diff --cached --name-only
```

Conferir que o índice contém **somente** os arquivos pretendidos da pasta atual. Se já houver outros arquivos staged, parar e revisá-los antes de fazer commit; não executar commit de alterações desconhecidas. Depois, por decisão do responsável:

```powershell
git commit -m "Organiza prototipo atual e entrega AC1"
git push origin main
```

Autenticar na conta correta se solicitado. Se o push for rejeitado por divergência, não usar force; revisar a diferença com o remoto. O branch `main` foi encontrado no config local; confirmar com `git branch --show-current` antes de publicar.

Após publicar, abrir o repositório no navegador e conferir o `project.godot` desta subpasta, o GDD atualizado e a pasta de entrega. Anexar ao card o link da subpasta/commit correto. Publicação e limpeza de caches de outras cópias permanecem externas ao escopo desta tarefa.
