from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image, PageBreak

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/delivery/ac1/trello-uploads"
OUT.mkdir(parents=True, exist_ok=True)
EV = ROOT / "docs/delivery/ac1/evidence"

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="TitleJ", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=23, leading=28, textColor=colors.HexColor("#24554A"), spaceAfter=10))
styles.add(ParagraphStyle(name="H2J", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=15, leading=19, textColor=colors.HexColor("#24554A"), spaceBefore=10, spaceAfter=5))
styles.add(ParagraphStyle(name="BodyJ", parent=styles["BodyText"], fontSize=10, leading=14, textColor=colors.HexColor("#26332F"), spaceAfter=6))
styles.add(ParagraphStyle(name="SmallJ", parent=styles["BodyText"], fontSize=8.5, leading=11, textColor=colors.HexColor("#56635E")))
styles.add(ParagraphStyle(name="CellJ", parent=styles["BodyText"], fontSize=8.3, leading=10.5, textColor=colors.HexColor("#26332F")))
styles.add(ParagraphStyle(name="HeadJ", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8.3, leading=10.5, textColor=colors.white))

def P(text, style="BodyJ"):
    return Paragraph(text.replace("\n", "<br/>"), styles[style])

def footer(canvas, doc):
    canvas.saveState(); canvas.setStrokeColor(colors.HexColor("#69BE9B")); canvas.line(20*mm, 14*mm, 190*mm, 14*mm)
    canvas.setFont("Helvetica", 8); canvas.setFillColor(colors.HexColor("#56635E")); canvas.drawString(20*mm, 9*mm, "Inity Pixel · Jadefall: Guardiões do Refúgio")
    canvas.drawRightString(190*mm, 9*mm, str(doc.page)); canvas.restoreState()

def build(name, title, subtitle, sections, images=()):
    path = OUT / name
    doc = SimpleDocTemplate(str(path), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm, topMargin=16*mm, bottomMargin=18*mm)
    story = [P(title, "TitleJ"), P(subtitle, "SmallJ"), Spacer(1, 3*mm)]
    for heading, body in sections:
        story += [P(heading, "H2J"), P(body)]
    for img_path, caption in images:
        p = ROOT / img_path
        if p.exists():
            story += [Spacer(1, 4*mm), Image(str(p), width=160*mm, height=85*mm, kind="proportional"), P(caption, "SmallJ")]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return path

build("01-Marketing-Branding.pdf", "Marketing, marca e monetização", "Cards: Definir logo do estúdio e IDV · Tela de contribuição/frase de venda · Criar Press Release · Definir modelo de monetização", [
    ("Identidade", "Estúdio: Inity Pixel. Jogo: Jadefall: Guardiões do Refúgio. Paleta: verde profundo, floresta, jade, âmbar, coral e creme. O logo do jogo usa JADEFALL em âmbar, GUARDIÕES DO REFÚGIO em jade, faixa de pedra e cristais laterais."),
    ("Frase de venda", "Jadefall: forme um vínculo com a criatura que você quase derrotou, organize sua defesa e proteja o Refúgio quando a noite chegar."),
    ("Monetização", "Protótipo acadêmico gratuito. Proposta futura: compra única com demonstração gratuita. Hipótese de planejamento: R$ 19,90. Não monetizar vidas, respawns, criaturas fortes, recursos, territórios, tempo de construção, recompensas aleatórias ou vantagem competitiva."),
    ("Press release", "Jadefall combina exploração, coleta, domesticação e defesa de território. O jogador pode eliminar uma ameaça ou transformá-la em aliado; durante a noite, ondas crescentes atacam o Refúgio."),
], [("docs/delivery/ac1/evidence/main_menu_Windows/menu_1280x720.png", "Menu real com a identidade aplicada." )])

build("02-GDD-GameDesign.pdf", "Game Design e arte aplicada", "Cards: Registrar decisões de design no GDD · Personagens · TileMaps · Criar moodboard visual · Power Ups · Posicionamento e organização dos elementos/fases · Sistema de armadilhas e inimigos · Coletáveis", [
    ("GDD", "O loop atual é explorar → coletar → combater/domesticar → recuperar território → construir/preparar → sobreviver à noite → repetir. A arena mede aproximadamente 48 × 52 m, com Refúgio ao sul, bosque oeste, região rochosa leste e corredor de ruína ao norte."),
    ("Personagens e inimigos", "Guardião low-poly com machado, túnica âmbar e lenço jade. WildDino possui 80 HP e pode ser domesticado com HP até 30%. Carnotauro é variante não domesticável e não é inimigo padrão da onda."),
    ("TileMaps e fases", "A progressão usa uma arena única com rotas centrais e laterais, seis pontos de torre, recursos em duas regiões e dois marcos territoriais."),
    ("Power Ups", "A Fogueira é o power-up de recuperação: cura 25 HP, tem duas cargas por dia e recarga de 25 s. A Armadilha de Espinhos é uma defesa consumível de rota: 15 dano, três cargas e limite de três estruturas."),
    ("Coletáveis", "Árvores têm 30 HP e rendem 10 madeiras; pedras têm 45 HP e rendem 6 pedras. O mesmo golpe do jogador coleta os recursos, que reaparecem ao amanhecer."),
], [("docs/delivery/ac1/evidence/map_showcase_Windows/11_overview_diagnostic.png", "Mapa real em câmera de apresentação."), ("docs/delivery/ac1/evidence/art/guardian_frente.png", "Personagem principal." )])

build("03-UI-Gameplay.pdf", "Interface e experiência de jogo", "Cards: Criar apresentação final · Tela de menu · Mensagens e HUD do game · Mensagens durante o jogo · Controle do players", [
    ("Menu", "O menu possui JOGAR, CONTROLES, CRÉDITOS, volume/mudo e SAIR. JOGAR instancia a arena real; a tela de controles usa a tabela canônica do projeto."),
    ("HUD", "Exibe HP do jogador e do Refúgio, dia/hora/fase, onda, madeira, pedra, Pontos de Defesa, territórios, domesticação, aliado, construção e objetivos contextuais."),
    ("Mensagens", "Mensagens orientam domesticação, construção, cura, entrada de território, aproximação da noite, defesa do Refúgio, vitória e derrota. O fluxo de pausa permite retomar, reiniciar e retornar ao menu."),
    ("Controles", "WASD move; mouse mira; clique ataca/coleta; E domestica ou recupera marco; F alterna aliado; C torre; I inventário; B construção; R gira; H cura; botão direito cancela; Esc fecha painel ou pausa."),
], [("docs/delivery/ac1/evidence/main_menu_Windows/menu_controles.png", "Tela real de controles."), ("docs/delivery/ac1/evidence/hud_showcase_Windows/hud_atual_dia_1920.png", "HUD real durante o dia."), ("docs/delivery/ac1/evidence/sky_showcase_Windows/08_2100_noite.png", "HUD real durante a noite." )])

build("04-Audio.pdf", "Áudio do jogo", "Cards: Trilha sonora · Efeitos sonoros", [
    ("Trilha principal", "Passos do Refúgio é uma composição original de 112 s. O runtime alterna refugio_calm.wav no menu/dia e refugio_combat.wav na noite, com transição e loop pelo AudioDirector."),
    ("Efeitos", "strike.wav é o golpe; bond.wav é o vínculo/domesticação; victory.wav e defeat.wav sinalizam resultado. Os arquivos estão em assets/audio e são carregados por players separados em buses Music/SFX."),
    ("Proveniência", "A documentação do projeto registra composição sintetizada sem samples externos. Testes verificam reprodução e estados; a audição humana do grupo ainda é necessária para aprovar musicalidade, emenda e volume."),
], [])

build("05-GitHub-Testes.pdf", "Código, GitHub e validação", "Cards: Configurar GitHub · Testes", [
    ("GitHub", "O README.md documenta a execução do projeto e o .gitignore define as exclusões do versionamento. O remoto local é https://github.com/iReaaLiTy/Infinity-Pixel, mas a publicação desta pasta ainda precisa ser feita manualmente após revisar o staging. Não executar git add . na pasta pai sem conferir os arquivos."),
    ("Testes", "As regressões headless passaram: territory 68/68; sky_cycle 45/45; build_heal 68/68; healing_actions 7/7; combat_collect 46/46; defense_economy 35/35; day_cycle 43/43; day_cycle_real 15/15; world_layout 57/57; player_health 47/47; player_facing 37/37; physics_contracts 23/23; navigation_contracts 38/38; acceptance 33/33."),
    ("Evidência visual", "O menu renderizado passou 27/27. Capturas de mapa, HUD, territórios, construção, áudio/iluminação e arte estão em docs/delivery/ac1/evidence."),
], [])

print("PDF packs created in", OUT)
