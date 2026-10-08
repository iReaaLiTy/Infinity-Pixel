from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/delivery/ac1/trello-uploads/cards"
OUT.mkdir(parents=True, exist_ok=True)
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="CardTitle", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=22, leading=27, textColor=colors.HexColor("#24554A"), spaceAfter=12))
styles.add(ParagraphStyle(name="CardBody", parent=styles["BodyText"], fontSize=11, leading=16, textColor=colors.HexColor("#26332F"), spaceAfter=8))
styles.add(ParagraphStyle(name="CardSmall", parent=styles["BodyText"], fontSize=8.5, leading=11, textColor=colors.HexColor("#56635E")))

def p(text, style="CardBody"):
    return Paragraph(text.replace("\n", "<br/>"), styles[style])

def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#69BE9B")); canvas.line(20*mm, 14*mm, 190*mm, 14*mm)
    canvas.setFont("Helvetica", 8); canvas.setFillColor(colors.HexColor("#56635E"))
    canvas.drawString(20*mm, 9*mm, "Inity Pixel · Jadefall: Guardiões do Refúgio")
    canvas.drawRightString(190*mm, 9*mm, str(doc.page)); canvas.restoreState()

cards = [
 ("01-logo-estudio-idv.pdf", "Definir logo do estúdio e IDV", "Estúdio: Inity Pixel. Jogo: Jadefall: Guardiões do Refúgio. A identidade usa verde profundo, jade, âmbar, coral e creme. O logo final combina JADEFALL em âmbar, GUARDIÕES DO REFÚGIO em jade, faixa de pedra e cristais laterais.", "docs/delivery/ac1/evidence/main_menu_Windows/menu_1280x720.png"),
 ("02-frase-venda.pdf", "Tela de contribuição / Frase de venda", "Frase de venda: Jadefall: forme um vínculo com a criatura que você quase derrotou, organize sua defesa e proteja o Refúgio quando a noite chegar.", None),
 ("03-apresentacao-final.pdf", "Criar apresentação final", "Apresentação final do protótipo Jadefall: conceito, loop de jogo, controles, mapa, personagens, sistemas, áudio, identidade e validação.", None),
 ("04-press-release.pdf", "Criar Press Release do jogo", "Jadefall combina exploração, coleta, domesticação e defesa de território. O jogador pode eliminar uma ameaça ou transformá-la em aliado; durante a noite, ondas crescentes atacam o Refúgio.", None),
 ("05-gdd-decisoes.pdf", "Registrar decisões de design no GDD", "Decisões registradas: loop explorar → coletar → combater/domesticar → recuperar território → construir/preparar → sobreviver à noite. A arena tem aproximadamente 48 × 52 m, com Refúgio ao sul, bosque oeste, região rochosa leste e ruína ao norte.", "docs/delivery/ac1/evidence/map_showcase_Windows/11_overview_diagnostic.png"),
 ("06-testes.pdf", "Testes", "Validação headless aprovada: territory 68/68; sky_cycle 45/45; build_heal 68/68; healing_actions 7/7; combat_collect 46/46; defense_economy 35/35; day_cycle 43/43; day_cycle_real 15/15; world_layout 57/57; player_health 47/47; player_facing 37/37; physics_contracts 23/23; navigation_contracts 38/38; acceptance 33/33. Menu renderizado: 27/27.", None),
 ("07-personagens.pdf", "Personagens", "Guardião low-poly com machado, túnica âmbar e lenço jade. WildDino possui 80 HP e pode ser domesticado até 30% de HP. Carnotauro é uma variante não domesticável.", "docs/delivery/ac1/evidence/art/guardian_frente.png"),
 ("08-tilemaps.pdf", "TileMaps", "A arena usa rotas centrais e laterais, seis pontos de torre, recursos em duas regiões e dois marcos territoriais.", "docs/delivery/ac1/evidence/map_showcase_Windows/11_overview_diagnostic.png"),
 ("09-moodboard.pdf", "Criar moodboard visual", "Direção visual: floresta estilizada low-poly, pedras claras, vegetação em camadas, ruínas antigas, jade luminoso, âmbar quente e contraste entre dia ensolarado e noite azulada.", "docs/delivery/ac1/evidence/main_menu_Windows/menu_1280x720.png"),
 ("10-power-ups.pdf", "Power Ups", "A Fogueira cura 25 HP, possui duas cargas por dia e recarga de 25 s. A Armadilha de Espinhos causa 15 de dano, possui três cargas e limite de três estruturas.", None),
 ("11-controle-players.pdf", "Controle do players", "WASD move; mouse mira; clique ataca/coleta; E domestica ou recupera marco; F alterna aliado; C torre; I inventário; B construção; R gira; H cura; botão direito cancela; Esc fecha painel ou pausa.", "docs/delivery/ac1/evidence/main_menu_Windows/menu_controles.png"),
 ("12-github.pdf", "Configurar GitHub", "O README.md documenta a execução do projeto. O .gitignore define os arquivos locais excluídos do versionamento. Repositório: Infinity-Pixel.", None),
 ("13-armadilhas-inimigos.pdf", "Sistema de armadilhas e inimigos", "Inimigos atacam o Refúgio durante ondas noturnas. O jogador pode combater ou domesticar criaturas compatíveis. Armadilhas de Espinhos protegem rotas e causam dano aos invasores.", None),
 ("14-tela-menu.pdf", "Tela de menu", "O menu possui JOGAR, CONTROLES, CRÉDITOS, volume/mudo e SAIR. JOGAR instancia a arena real do protótipo.", "docs/delivery/ac1/evidence/main_menu_Windows/menu_1280x720.png"),
 ("15-coletaveis.pdf", "Coletáveis", "Árvores têm 30 HP e rendem 10 madeiras; pedras têm 45 HP e rendem 6 pedras. Os recursos reaparecem ao amanhecer.", None),
 ("16-hud.pdf", "Mensagens e HUD do game", "O HUD exibe HP do jogador e do Refúgio, dia/hora/fase, onda, madeira, pedra, Pontos de Defesa, territórios, domesticação, aliado, construção e objetivos.", "docs/delivery/ac1/evidence/hud_showcase_Windows/hud_atual_dia_1920.png"),
 ("17-posicionamento-fases.pdf", "Posicionamento e organização dos elementos / fases", "O Refúgio fica ao sul; bosque e madeira ficam a oeste; pedras e área rochosa ficam a leste; ruínas e corredor norte orientam a progressão. Torres e marcos distribuem objetivos pela arena.", "docs/delivery/ac1/evidence/map_showcase_Windows/11_overview_diagnostic.png"),
 ("18-mensagens-jogo.pdf", "Mensagens durante o jogo", "Mensagens orientam domesticação, construção, cura, entrada de território, aproximação da noite, defesa do Refúgio, vitória e derrota.", None),
 ("19-trilha-sonora.pdf", "Trilha sonora", "Passos do Refúgio é uma composição original de 112 s. O runtime alterna refugio_calm.wav no menu/dia e refugio_combat.wav na noite, com transição e loop pelo AudioDirector.", None),
 ("20-efeitos-sonoros.pdf", "Efeitos sonoros", "strike.wav é o golpe; bond.wav é o vínculo/domesticação; victory.wav e defeat.wav sinalizam resultado. Os arquivos ficam em assets/audio e são carregados nos buses Music/SFX.", None),
]

for filename, title, body, image_path in cards:
    path = OUT / filename
    doc = SimpleDocTemplate(str(path), pagesize=A4, rightMargin=18*mm, leftMargin=18*mm, topMargin=20*mm, bottomMargin=18*mm)
    story = [p(title, "CardTitle"), p(body)]
    if image_path:
        image = ROOT / image_path
        if image.exists():
            story += [Spacer(1, 5*mm), Image(str(image), width=160*mm, height=85*mm, kind="proportional")]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(f"Created {len(cards)} individual card files in {OUT}")
