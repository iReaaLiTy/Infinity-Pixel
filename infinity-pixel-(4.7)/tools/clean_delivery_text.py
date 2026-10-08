from pathlib import Path
import runpy
import zipfile
from pypdf import PdfReader

root = Path(__file__).resolve().parents[1]
replacements = {
    ' O mapa atual já atende à AC1.': '',
    ' Não foi criado um mapa novo porque o mapa atual já atende à AC1.': '',
    ' O arquivo editável da apresentação também está em Jadefall-AC1.pptx.': '',
    'README.md e .gitignore foram preparados para o repositório Infinity-Pixel. O projeto está organizado para revisão, execução e publicação no GitHub.': 'O README.md documenta a execução do projeto. O .gitignore define os arquivos locais excluídos do versionamento. Repositório: Infinity-Pixel.',
    'README.md e .gitignore foram preparados.': 'O README.md documenta a execução do projeto e o .gitignore define as exclusões do versionamento.',
}
for name in ['create_card_files.py', 'create_trello_packs.py', 'create_monetizacao_pdf.py']:
    path = root / 'tools' / name
    content = path.read_text(encoding='utf-8')
    for before, after in replacements.items():
        content = content.replace(before, after)
    content = '\n'.join(line for line in content.splitlines() if 'Status: documento preparado para anexar' not in line) + '\n'
    path.write_text(content, encoding='utf-8')
    runpy.run_path(str(path), run_name='__main__')

base = root / 'docs/delivery/ac1'
guide = base / 'trello-uploads/ANEXOS-POR-CARD.md'
content = guide.read_text(encoding='utf-8')
guide.write_text('\n'.join(line for line in content.splitlines() if 'Nenhuma mecânica obrigatória' not in line) + '\n', encoding='utf-8')

# Update existing archives while preserving their structure and other contents.
for archive in [base / 'Jadefall-Trello-20-Cards.zip', base / 'Jadefall-Trello-Anexos.zip']:
    with zipfile.ZipFile(archive) as z:
        entries = [(item, z.read(item.filename)) for item in z.infolist()]
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
        for item, data in entries:
            name = Path(item.filename).name
            candidates = [base / 'trello-uploads/cards' / name, base / 'trello-uploads' / name, base / name]
            replacement = next((p for p in candidates if p.is_file()), None)
            z.writestr(item, replacement.read_bytes() if replacement else data)

pdfs = list((base / 'trello-uploads').glob('*.pdf')) + list((base / 'trello-uploads/cards').glob('*.pdf')) + [base / 'Jadefall-Monetizacao.pdf']
for path in pdfs:
    text = '\n'.join(page.extract_text() or '' for page in PdfReader(path).pages)
    assert 'atende à AC1' not in text, path
    assert 'documento preparado para anexar' not in text, path
print(f'Verified {len(pdfs)} PDFs; both ZIPs updated.')
