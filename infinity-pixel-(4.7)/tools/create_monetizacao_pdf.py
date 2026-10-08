from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak

output = "docs/delivery/ac1/Jadefall-Monetizacao.pdf"
doc = SimpleDocTemplate(output, pagesize=A4, rightMargin=20*mm, leftMargin=20*mm, topMargin=18*mm, bottomMargin=18*mm)
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="Cover", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=28, leading=34, alignment=TA_CENTER, textColor=colors.HexColor("#E7AE58"), spaceAfter=14))
styles.add(ParagraphStyle(name="Sub", parent=styles["Normal"], fontSize=13, leading=18, alignment=TA_CENTER, textColor=colors.HexColor("#69BE9B"), spaceAfter=28))
styles.add(ParagraphStyle(name="H", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=16, leading=20, textColor=colors.HexColor("#24554A"), spaceBefore=12, spaceAfter=7))
styles.add(ParagraphStyle(name="Body2", parent=styles["BodyText"], fontSize=10.5, leading=15, textColor=colors.HexColor("#26332F"), spaceAfter=8))
styles.add(ParagraphStyle(name="Small", parent=styles["BodyText"], fontSize=8.5, leading=12, textColor=colors.HexColor("#56635E")))

story = []
story.append(Spacer(1, 28*mm))
story.append(Paragraph("JADEFALL", styles["Cover"]))
story.append(Paragraph("Guardiões do Refúgio", styles["Cover"]))
story.append(Paragraph("Modelo de monetização · Inity Pixel", styles["Sub"]))
story.append(Paragraph("PROPOSTA PARA A AC1", styles["H"]))
story.append(Paragraph("O protótipo da AC1 é gratuito para fins acadêmicos. Para uma futura versão comercial, a proposta é uma compra única acompanhada de uma demonstração gratuita.", styles["Body2"]))
story.append(Paragraph("Modelo escolhido", styles["H"]))
story.append(Paragraph("Compra única, sem loja dentro do protótipo. A hipótese de planejamento é R$ 19,90 para uma futura versão completa. Esse valor ainda não é preço publicado nem resultado de pesquisa de mercado.", styles["Body2"]))

cell = ParagraphStyle(name="Cell", parent=styles["BodyText"], fontSize=8.5, leading=11, textColor=colors.HexColor("#26332F"))
head = ParagraphStyle(name="CellHead", parent=cell, fontName="Helvetica-Bold", textColor=colors.white)
data = [[Paragraph("O jogador recebe", head), Paragraph("O que não será monetizado", head)],
        [Paragraph("Acesso ao jogo completo definido para a versão comercial, com as mecânicas centrais de exploração, domesticação e defesa.", cell), Paragraph("Vidas, respawns, criaturas mais fortes, recursos, territórios, tempo de construção, recompensas aleatórias ou vantagem competitiva.", cell)],
        [Paragraph("Uma demonstração gratuita para conhecer combate, domesticação e defesa antes da compra.", cell), Paragraph("Anúncios obrigatórios, energia, assinatura, loot boxes ou pagamentos para acelerar o progresso.", cell)]]
table = Table(data, colWidths=[82*mm, 82*mm], repeatRows=1)
table.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (-1,0), colors.HexColor("#24554A")),
    ("TEXTCOLOR", (0,0), (-1,0), colors.white),
    ("FONTNAME", (0,0), (-1,0), "Helvetica-Bold"),
    ("FONTSIZE", (0,0), (-1,-1), 9),
    ("LEADING", (0,0), (-1,-1), 12),
    ("VALIGN", (0,0), (-1,-1), "TOP"),
    ("GRID", (0,0), (-1,-1), .5, colors.HexColor("#A9B8B0")),
    ("BACKGROUND", (0,1), (-1,-1), colors.HexColor("#F2E8CE")),
    ("LEFTPADDING", (0,0), (-1,-1), 8), ("RIGHTPADDING", (0,0), (-1,-1), 8),
    ("TOPPADDING", (0,0), (-1,-1), 7), ("BOTTOMPADDING", (0,0), (-1,-1), 7),
]))
story.append(table)
story.append(Paragraph("Por que combina com o jogo", styles["H"]))
story.append(Paragraph("Jadefall foi projetado para sessões de estratégia e experimentação. O jogador pode perder, aprender e reconstruir sem pagar para acelerar. Um modelo simples também é adequado ao escopo de um estúdio acadêmico e evita a operação de uma economia virtual.", styles["Body2"]))
story.append(Paragraph("Decisão para o card", styles["H"]))
story.append(Paragraph("Protótipo gratuito; hipótese comercial de compra única com demonstração gratuita. Preço de planejamento: R$ 19,90. Nenhuma monetização será adicionada à AC1.", styles["Body2"]))
story.append(Spacer(1, 16*mm))

def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#69BE9B"))
    canvas.line(20*mm, 14*mm, 190*mm, 14*mm)
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#56635E"))
    canvas.drawString(20*mm, 9*mm, "Inity Pixel · Jadefall: Guardiões do Refúgio")
    canvas.drawRightString(190*mm, 9*mm, f"{doc.page}")
    canvas.restoreState()

doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(output)
