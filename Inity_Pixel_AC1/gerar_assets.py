from pathlib import Path
from html import escape
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent
A = ROOT / 'assets'
A.mkdir(exist_ok=True)
BG, GREEN, MINT, GOLD, RED, WHITE = '#102B2A','#24554A','#69BE8C','#E7AE58','#D9705D','#F2E8CE'

def text(x,y,s,size=22,color=WHITE,weight=400):
    return f'<text x="{x}" y="{y}" fill="{color}" font-family="Segoe UI,Arial,sans-serif" font-size="{size}" font-weight="{weight}">{escape(s)}</text>'
def rect(x,y,w,h,c,r=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}" rx="{r}"/>'
def path(d,c,stroke='none',sw=1):
    return f'<path d="{d}" fill="{c}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>'
def circle(x,y,r,c):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}"/>'
def save(name,body,w=1200,h=800,bg=BG):
    (A/name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img"><title>{escape(name)}</title>'+ (rect(0,0,w,h,bg) if bg else '')+body+'</svg>',encoding='utf-8')
def head(kicker,title):
    return text(48,44,kicker,16,MINT,600)+text(48,97,title,40,WHITE,700)
def footer(s):
    return text(48,765,s,16,'#B1C9BA')
def tree(x,y,scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">'+path('M -8 0 L 8 0 L 5 -75 L -5 -75','#795A3E')+path('M 0 -155 L -58 -55 L 0 -70 L 58 -55 Z',GREEN)+path('M 0 -155 L 0 -70 L 58 -55 Z','#34715B')+'</g>'
def hero(x,y,s=1,side=False):
    b=path('M -34 70 L -4 70 L -10 148 L -35 148 Z M 4 70 L 34 70 L 40 148 L 12 148 Z','#263B38')
    b+=path('M -38 -23 L 32 -23 L 47 80 L -49 80 Z',GOLD)+path('M -38 -23 L 0 0 L -49 80 Z','#B7783D')
    b+=path('M -39 -15 L -59 49 L -74 43 L -55 -24 Z M 32 -23 L 63 25 L 50 39 L 23 -2 Z','#C68B60')
    b+=path('M -23 -78 L 22 -78 L 31 -42 L 12 -22 L -20 -28 L -32 -49 Z','#DDA16E')
    b+=path('M -32 -51 L -37 -77 L -14 -94 L 22 -83 L 30 -64 L 1 -72 L -19 -50 Z','#243632')
    b+=path('M -33 -24 L 33 -26 L 17 0 L -31 -8 Z M -23 -8 L -51 28 L -53 -9 Z',MINT)
    b+=rect(-42,43,81,12,'#533D31')+rect(-35,142,29,15,'#533D31')+rect(10,142,36,15,'#533D31')
    b+=path('M 57 32 L 105 -8', 'none','#795A3E',10)+path('M 84 -8 L 105 -31 L 129 -8 L 105 7 Z','#A4B7AD')
    b+=circle(14,-52,3,BG)
    return f'<g transform="translate({x} {y}) scale({s})">{b}</g>'
def dino(x,y,s=1,c=MINT):
    return f'<g transform="translate({x} {y}) scale({s})">'+path('M -80 0 L -35 -20 L 5 -20 L 35 -60 L 75 -58 L 90 -35 L 47 -24 L 30 17 L 8 22 L 12 55 L -5 55 L -15 20 L -35 20 L -30 50 L -48 50 L -53 14 L -110 -20 Z',c)+circle(65,-46,4,BG)+path('M 50 -30 L 76 -31','none',BG,3)+'</g>'

# Original geometric marks, transparent for game integration.
mark=''
for x,y in [(0,0),(24,0),(48,0),(0,24),(48,24),(0,48),(24,48),(48,48),(24,72)]:
    mark+=rect(30+x,28+y,18,18,MINT if x!=24 else GOLD,2)
save('logo_inity_pixel.svg',mark+text(135,72,'INITY PIXEL',48,WHITE,800)+text(138,108,'ESTÚDIO DE JOGOS',17,MINT,600),650,145,None)
save('logo_jogo.svg',path('M 35 28 L 100 28 L 100 84 L 67 112 L 35 84 Z',GREEN,GOLD,4)+path('M 48 63 L 60 44 L 84 44 L 91 59 L 71 66 L 69 87 L 56 81 Z',MINT)+text(130,66,'TOWER DEFENSE',42,WHITE,800)+text(130,118,'DINO',52,GOLD,800),650,150,None)

b=head('INITY PIXEL / ARTE DE PERSONAGEM / PROPOSTA 01','O guardião do refúgio')
b+=rect(48,135,585,558,'#173A35',22)+circle(330,408,192,'#20483D')+hero(325,390,1.7)
b+=text(690,205,'SILHUETA',16,MINT,700)+text(690,246,'Guardião • corpo a corpo',25,WHITE,600)
for y,s in [(297,'Lenço: vínculo com os aliados'),(339,'Túnica âmbar: leitura no cenário'),(381,'Arma curta: alcance de 2 metros'),(423,'Botas e base de apoio largas'),(465,'Formas simples para modelo 3D')]: b+=text(690,y,s,19)
for i,c in enumerate([BG,GREEN,MINT,GOLD,RED,WHITE]): b+=rect(690+i*70,523,52,52,c,8)
b+=text(690,621,'Arte conceitual 2D editável.',19,MINT)+text(690,651,'Modelagem e animação: integração futura.',17)
b+=footer('TOWER DEFENSE DINO • Proposta visual da AC1 • 30/09/2026')
save('personagem.svg',b)

b=head('INITY PIXEL / AMBIENTE / PROPOSTA 01','Clareira do Refúgio')
b+=rect(48,135,1104,545,'#A6C4AC',16)+circle(954,231,58,GOLD)
b+=path('M 48 392 L 234 201 L 402 389 L 564 226 L 777 405 L 941 284 L 1152 422 L 1152 680 L 48 680 Z','#608C77')
b+=path('M 48 477 L 309 340 L 538 445 L 808 373 L 1152 459 L 1152 680 L 48 680 Z',GREEN)
b+=path('M 443 680 L 556 439 L 675 439 L 938 680 Z','#B29663')
for x,y,s in [(155,500,1.4),(252,577,1.1),(1011,503,1.6),(1101,600,1.3),(420,448,.65)]: b+=tree(x,y,s)
b+=path('M 359 606 L 399 522 L 445 529 L 466 613 Z','#7E9483')+rect(409,448,7,120,'#71533B')+path('M 416 448 L 481 463 L 416 489 Z',GOLD)
b+=hero(590,550,.54)+dino(745,570,.65)+text(72,717,'Corredor aberto • base com estandarte • vegetação lateral • leitura clara ao anoitecer',21)
b+=footer('Ilustração de direção de arte; não representa uma captura da Godot.')
save('cenario.svg',b)

b=head('INITY PIXEL / LEVEL DESIGN / 40 × 40 METROS','Arena 01 · Clareira do Refúgio')
b+=rect(55,145,560,560,'#1D4238',8)
for i in range(9):
    q=55+i*70; z=145+i*70
    b+=path(f'M {q} 145 V 705 M 55 {z} H 615','none','#315748')
# North on top is -Z; 14 pixels per world meter.
def point(x,z): return 335+x*14,425+z*14
b+=rect(265,155,140,540,'#806F48',12)
for label,x,z,c in [('BASE',0,-15,GOLD),('JOGADOR',0,0,WHITE),('ONDA',0,15,RED),('ENCONTRO',-10,5,MINT),('POSTO',0,-7,MINT)]:
    xx,yy=point(x,z); b+=circle(xx,yy,14,c)+text(xx+22,yy+7,label,16,c,700)
b+=f'<circle cx="335" cy="327" r="112" fill="none" stroke="{MINT}" stroke-width="2" stroke-dasharray="8 8"/>'
b+=path('M 390 616 L 390 282 M 377 300 L 390 282 L 403 300','none',GOLD,5)
b+=text(680,186,'FLUXO DA PARTIDA',17,MINT,700)
for y,s in [(232,'01  Reconheça a base e os controles'),(280,'02  Encontre e domestique o selvagem'),(328,'03  Conduza o aliado ao posto'),(376,'04  Inicie a noite e defenda a rota')]: b+=text(680,y,s,21)
for y,s in [(446,'Norte = -Z • Sul = +Z'),(483,'Base (0, -15) / Onda (0, +15)'),(520,'Encontro proposto (-10, +5)'),(557,'Posto proposto (0, -7) • raio 8 m'),(594,'Cada quadrícula = 5 × 5 m'),(631,'Corredor livre = 10 m de largura'),(668,'Vegetação e pedras nas laterais')]: b+=text(680,y,s,19)
b+=footer('Posições em X/Z. Piso existente preservado. Encontro/posto/decoração são propostas de integração.')
save('arena_planta.svg',b)

b=rect(0,0,1200,800,BG)+path('M 700 800 L 830 0 L 1200 0 L 1200 800 Z','#1B4038')
for x,y,s in [(860,670,2),(1100,470,2.1),(980,800,1.8)]: b+=tree(x,y,s)
b+=text(72,75,'INITY PIXEL',20,MINT,700)+text(72,180,'TOWER DEFENSE',47,WHITE,800)+text(72,253,'DINO',76,GOLD,800)+text(76,306,'Domestique. Posicione. Defenda.',23)
for y,s,c in [(365,'JOGAR',GOLD),(444,'CONTROLES',GREEN),(523,'CRÉDITOS',GREEN),(602,'SAIR',GREEN)]: b+=rect(76,y,365,58,c,10)+text(104,y+38,s,21,BG if c==GOLD else WHITE,700)
b+=dino(855,566,1.45)+hero(1050,606,.8)+text(76,750,'AC1 · PROTÓTIPO · MOCKUP DE INTERFACE',16,MINT)
save('menu.svg',b)

b=rect(0,0,1200,800,'#426657')+path('M 340 800 L 560 180 L 660 180 L 1000 800 Z','#887B57')
for x,y,s in [(140,380,1.6),(1010,435,1.7),(250,650,1.4)]: b+=tree(x,y,s)
b+=hero(585,588,.8)+dino(735,444,.7)+dino(603,291,.5,RED)
b+=rect(28,26,285,110,BG,12)+text(48,59,'REFÚGIO',16,MINT,700)+text(48,91,'BASE 100 / 100',23,WHITE,700)+rect(48,107,240,10,GREEN,5)+rect(48,107,240,10,MINT,5)
b+=rect(875,26,297,110,BG,12)+text(897,61,'NOITE · ONDA 1',24,GOLD,700)+text(897,101,'Ameaças restantes: 3',20)
b+=rect(373,29,452,53,BG,10)+text(403,63,'Defenda o refúgio com seu aliado',21)
b+=rect(390,645,420,67,BG,10)+text(423,674,'Segure E para domesticar',22)+rect(416,689,366,8,GREEN,4)+rect(416,689,220,8,MINT,4)
b+=rect(28,741,1144,40,BG,8)+text(46,768,'WASD Mover   •   Mouse Câmera   •   Clique Atacar   •   E Domesticar   •   F Seguir/Ficar   •   Esc Pausa',19)
b+=text(33,722,'MOCKUP: valores ilustrativos; a interface final deve ler o estado real.',15,WHITE)
save('hud.svg',b)

# Seamless periodic composition. Each event tail wraps around the loop boundary.
sr=44100; duration=32; n=sr*duration
mix=np.zeros((n,2),dtype=np.float64); rng=np.random.default_rng(20260930)
def event(start,freq,length,amp,pan=0,kind='pluck'):
    t=np.arange(int(sr*length))/sr
    if kind=='pluck': sig=(np.sin(2*np.pi*freq*t)+.25*np.sin(2*np.pi*2*freq*t))*np.exp(-4*t)*np.minimum(t/.008,1)
    elif kind=='pad': sig=(np.sin(2*np.pi*freq*t)+.15*np.sin(2*np.pi*2*freq*t))*np.sin(np.pi*t/length)**2
    elif kind=='kick': sig=np.sin(2*np.pi*(48*t+55*.025*(1-np.exp(-t/.025))))*np.exp(-15*t)*np.minimum(t/.004,1)
    else: sig=rng.normal(0,1,len(t))*np.exp(-45*t)*np.minimum(t/.002,1)
    idx=(int(start*sr)+np.arange(len(t)))%n
    mix[idx,0]+=amp*sig*np.sqrt((1-pan)/2)
    mix[idx,1]+=amp*sig*np.sqrt((1+pan)/2)
def hz(m): return 440*2**((m-69)/12)
chords=[(50,53,57),(46,50,53),(41,45,48),(48,52,55)]
motifs=[[74,77,81,77],[70,74,77,74],[69,72,77,72],[72,76,79,76]]
for bar in range(16):
    start=bar*2; chord=chords[bar%4]
    for j,m in enumerate(chord): event(start,hz(m+12),2.7,.052,(j-1)*.45,'pad')
    event(start,hz(chord[0]-12),1.85,.18,0,'pad')
    for beat in range(4):
        if beat in (0,2): event(start+beat*.5,50,.38,.22,0,'kick')
        event(start+beat*.5+.25,0,.12,.038,.35 if beat%2 else -.35,'noise')
        event(start+beat*.5,hz(motifs[bar%4][beat]),1.4,.105,-.22 if beat%2 else .22)
mix-=mix.mean(axis=0)
mix*=.78/max(np.abs(mix).max(),1e-9)
pcm=np.rint(mix*32767).astype('<i2')
with wave.open(str(A/'refugio_loop.wav'),'wb') as out:
    out.setnchannels(2);out.setsampwidth(2);out.setframerate(sr);out.writeframes(pcm.tobytes())

labels={'logo_inity_pixel.svg':'Marca do estúdio','logo_jogo.svg':'Marca do jogo','personagem.svg':'Personagem principal','cenario.svg':'Cenário','arena_planta.svg':'Planta da arena','menu.svg':'Menu inicial — mockup','hud.svg':'HUD — mockup'}
cards=''.join(f'<section><h2>{v}</h2><a href="assets/{k}"><img src="assets/{k}" alt="{v}"></a></section>' for k,v in labels.items())
html='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Inity Pixel · AC1</title><style>body{margin:0;background:#0b201f;color:#f2e8ce;font:18px/1.6 system-ui}main{max-width:1100px;margin:auto;padding:48px 24px}h1{font-size:48px;line-height:1.1}h2{font-size:24px}p{max-width:850px}a{color:#69be8c}section{background:#102b2a;padding:24px;margin:24px 0;border-radius:18px}img{width:100%;height:auto;display:block}audio{width:100%}small{color:#b1c9ba}nav{display:flex;flex-wrap:wrap;gap:24px}</style><main><small>INITY PIXEL / PRIMEIRA ENTREGA / 04 OUT 2026</small><h1>Tower Defense Dino</h1><p>Pacote de proposta visual e documentação para a AC1. Artes conceituais editáveis; integração na Godot e validação pelo grupo ainda pendentes.</p><p>Murilo Cassetti · Heitor Crispim · Pedro Ferreira · Juan Carlos</p><nav><a href="GDD_AC1.md">GDD</a><a href="PROMPT_CLAUDE_AC1.md">Prompt do Claude</a><a href="TRELLO_E_ENTREGA.md">Cards do Trello</a><a href="ASSETS.md">Recursos e créditos</a></nav>'''+cards+'''<section><h2>Trilha principal · Refúgio</h2><p>Composição procedural original · 32 segundos · 120 BPM · estéreo. Ouça e aprove antes de integrar.</p><audio controls loop src="assets/refugio_loop.wav"></audio></section><small>Proposta criada com auxílio de IA. Sem alteração dos scripts ou cenas do jogo.</small></main></html>'''
(ROOT/'galeria.html').write_text(html,encoding='utf-8')
print(f'Criados {len(labels)} SVGs, WAV e galeria em {ROOT}')
print(f'Audio: {duration}s; peak={np.abs(mix).max():.3f}; boundary_delta={np.max(np.abs(mix[-1]-mix[0])):.6f}')
