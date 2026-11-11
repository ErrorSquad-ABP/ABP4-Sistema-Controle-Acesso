import html
import json
from pathlib import Path

from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.util import Inches, Pt
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CAP = HERE / 'capturas'
INK, PAPER, MUTED, GREEN, RED = '0A0A0A', 'F6F7F2', '6E756F', '137A4A', 'BF3333'
prs = Presentation()
prs.slide_width, prs.slide_height = Inches(16), Inches(9)
prs.core_properties.title = 'ABP 4DSM — Sprint 2 / Integração'
prs.core_properties.author = 'ErrorSquad · FATEC Jacareí'
pages = []
notes = []


def box(s, x, y, w, h, color, radius=False):
    shape = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE,
                              Inches(x / 100), Inches(y / 100), Inches(w / 100), Inches(h / 100))
    shape.fill.solid()
    shape.fill.fore_color.rgb = RGBColor.from_string(color)
    shape.line.fill.background()
    pages[-1].append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;background:#{color};border-radius:{24 if radius else 0}px"></div>')


def text(s, value, x, y, w, h, size=28, color=INK, bold=False, mono=False):
    shape = s.shapes.add_textbox(Inches(x / 100), Inches(y / 100), Inches(w / 100), Inches(h / 100))
    tf = shape.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    for i, line in enumerate(value.split('\n')):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.text = line
        p.font.name = 'Consolas' if mono else 'Figtree'
        p.font.size = Pt(size * .72)
        p.font.bold = bold
        p.font.color.rgb = RGBColor.from_string(color)
        p.line_spacing = 1.18
        p.space_after = Pt(0)
    family = 'Consolas,monospace' if mono else 'Figtree,Arial,sans-serif'
    pages[-1].append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:{w}px;height:{h}px;font:{700 if bold else 400} {size}px/1.18 {family};color:#{color};white-space:pre-wrap;overflow-wrap:break-word">{html.escape(value)}</div>')


def image(s, name, x, y, w, h):
    path = CAP / name
    iw, ih = Image.open(path).size
    scale = min(w / iw, h / ih)
    pw, ph = iw * scale, ih * scale
    left, top = x + (w - pw) / 2, y + (h - ph) / 2
    s.shapes.add_picture(str(path), Inches(left / 100), Inches(top / 100), Inches(pw / 100), Inches(ph / 100))
    pages[-1].append(f'<img alt="{html.escape(name)}" src="capturas/{name}" style="position:absolute;left:{left}px;top:{top}px;width:{pw}px;height:{ph}px">')


def phone(s, name, x, y, w=260):
    iw, ih = Image.open(CAP / name).size
    h = w * ih / iw
    box(s, x - 8, y - 8, w + 16, h + 16, '292D29', True)
    image(s, name, x, y, w, h)


def slide(label, source, dark=False, note=''):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    pages.append([])
    bg, fg = (INK, PAPER) if dark else (PAPER, INK)
    box(s, 0, 0, 1600, 900, bg)
    text(s, label.upper(), 80, 58, 1440, 30, 17, 'ACB4AC' if dark else MUTED)
    box(s, 80, 820, 1440, 1, '343A34' if dark else 'D7DDD5')
    text(s, 'ERRORSQUAD / REVIEW 2', 80, 843, 350, 25, 15, fg)
    text(s, source, 440, 843, 980, 35, 14, 'ACB4AC' if dark else MUTED)
    text(s, f'{len(pages):02} / 12', 1440, 843, 90, 25, 15, fg)
    s.notes_slide.notes_text_frame.text = note + '\n\nFonte: ' + source
    notes.append(note)
    return s


def heading(s, value, dark=False, size=58, width=1440):
    text(s, value, 80, 123, width, 160, size, PAPER if dark else INK, True)


s = slide('FATEC Jacareí / ABP 4DSM', 'Sprint 2 · 22/10–11/11/2026 · main a0625d7', True,
          '0:40 — A Sprint 1 apresentou a fundação. Hoje mostramos o app tomando decisões com a API, com persistência e retorno MQTT. As capturas são da execução de 11/11; não são mockups. Câmera/GPS e terminal são simulados, com backend e banco reais.')
box(s, 885, 0, 715, 820, '171D18')
text(s, 'O acesso\nganhou um\nfluxo real.', 80, 210, 810, 360, 87, PAPER, True)
text(s, 'Sprint 2 / Integração', 85, 635, 740, 60, 34, PAPER)
text(s, 'APP  ·  API  ·  BANCO  ·  MQTT', 85, 711, 760, 50, 20, 'A6D5B8')
phone(s, 'app-android-home.png', 925, 210, 250)
phone(s, 'app-android-liberado.png', 1240, 140, 250)

s = slide('01 / Evolução', 'S1: fundação · S2: integração e decisão · evidências na main', note=
          '0:50 — Antes havia login mock, contratos e demonstração de comandos. Agora o login é real e a API valida autorização, QR e distância. O pedido deixa evento, comando e ACK. Não confundir isso com produto completo ou homologação física.')
heading(s, 'Do contrato à decisão de acesso.')
text(s, 'SPRINT 1', 80, 302, 620, 35, 19, MUTED)
text(s, 'A fundação', 80, 360, 620, 65, 48, INK, True)
text(s, 'Login de demonstração\nRotas e contratos definidos\nComando MQTT simulado', 80, 470, 650, 210, 32, MUTED)
box(s, 780, 310, 2, 400, 'CFD6CD')
text(s, 'SPRINT 2', 890, 302, 620, 35, 19, GREEN)
text(s, 'O fluxo integrado', 890, 360, 620, 65, 48, INK, True)
text(s, 'Sessão autenticada\nRegras aplicadas no servidor\nEvento + comando + ACK', 890, 470, 630, 210, 32)
text(s, 'A tela mostra o resultado. A autorização continua no backend.', 80, 735, 1420, 45, 26, GREEN)

s = slide('02 / App no aparelho', 'Capturas de tela do APK em Android 15 · Android Debug · API local real', note=
          '1:00 — Este não é o build web: é o APK rodando no celular. Login real contra a API, sessão persistida e Home. Fechei e reabri o app: a sessão voltou sem pedir senha, o que aparece na segunda captura. A lista de autorizações ainda não existe no app.')
phone(s, 'app-android-login.png', 118, 168, 240)
phone(s, 'app-android-home.png', 420, 168, 240)
text(s, 'Entrar de verdade.\nContinuar com\nsegurança.', 800, 205, 720, 245, 58, INK, True)
text(s, 'Login na API, não um mock.\nSessão restaurada ao reabrir.\nSaída explícita da conta.', 800, 500, 720, 185, 30)
text(s, 'APK debug · Android · tela real do aparelho', 800, 740, 720, 40, 20, GREEN)

s = slide('03 / Câmera e GPS reais', 'APK em aparelho físico · API/worker/PostgreSQL/Mosquitto locais · 11/11 16:10', note=
          '1:20 — Três telas do mesmo aparelho: o scanner lendo o QR exibido no monitor, o acesso liberado com a posição a 6,8 m e o negado a 1.207,9 m. A câmera e o GPS são os do celular; a API, o banco e o worker são reais. Para o segundo caso, movi o local no banco 1,2 km e li o mesmo QR de novo. O motivo exibido vem do backend, não do app.')
heading(s, 'Ler, decidir e mostrar no aparelho.', size=52)
phone(s, 'app-android-scanner.jpg', 120, 250, 232)
phone(s, 'app-android-liberado.png', 452, 250, 232)
phone(s, 'app-android-negado.png', 784, 250, 232)
text(s, '6,8 m', 1070, 330, 460, 80, 62, GREEN, True)
text(s, 'posição real do celular\ndentro dos 100 m', 1070, 418, 470, 90, 25)
text(s, '1.207,9 m', 1070, 560, 460, 80, 62, RED, True)
text(s, 'fora do raio: negado com\nOUT_OF_RANGE no backend', 1070, 648, 480, 90, 25)

s = slide('04 / Backend', 'Swagger/OpenAPI da aplicação · captura local de /docs · a0625d7', note=
          '1:00 — Auth e administração existem na API: usuários, autorizações e histórico. O QR vale 25 s; o servidor confere assinatura, terminal, usuário, vigência, usos e geofence limitada a 100 m. Negativa de negócio é uma decisão HTTP 200, não uma falha de transporte. As telas administrativas do app ainda não foram entregues.')
heading(s, 'As regras não ficam no celular.', size=58)
image(s, 'api-qr.png', 80, 274, 1030, 480)
text(s, '25 s', 1170, 302, 330, 90, 65, GREEN, True)
text(s, 'validade do QR assinado', 1170, 389, 340, 65, 25)
text(s, '100 m', 1170, 510, 330, 90, 65, INK, True)
text(s, 'teto da geofence\nvalidado no servidor', 1170, 598, 350, 90, 25)
text(s, 'JWT + perfis · janela · usos · local', 80, 771, 1050, 32, 22, GREEN)

s = slide('05 / Banco', 'Saída de SELECT real / psql · PostgreSQL 17 local · dados fictícios', True, note=
          '1:00 — Esta é a saída real da consulta, não uma tabela inventada para o slide. Temos NFC autorizado e desconhecido; QR autorizado e negado por distância. O traço no ACK do QR fora do raio é esperado: não houve comando de abertura. Os IDs completos e a consulta estão junto aos slides.')
heading(s, 'Cada tentativa deixa rastro.', True)
text(s, 'Método, decisão, motivo, distância e confirmação do comando.', 80, 246, 1400, 55, 30, 'BAC3B9')
image(s, 'banco-recorte.png', 80, 325, 1440, 430)
text(s, 'Evento auditável. Sem liberar acesso por ausência de regra.', 80, 767, 1420, 40, 25, 'A6D5B8')

s = slide('06 / MQTT', 'Mensagens observadas no Mosquitto local · terminal simulado · payloads sanitizados', True, note=
          '1:00 — O observador assinou o broker real. Cada comando tem commandId e o ACK responde ao mesmo ID. QoS 1 não significa que a cancela física abriu. Aqui o terminal é o simulador do projeto; na bancada NFC registrada, o servo também estava desabilitado.')
heading(s, 'Comando enviado. Retorno correlacionado.', True, size=54)
image(s, 'mqtt-foco.png', 80, 282, 990, 495)
text(s, 'QoS 1', 1150, 340, 350, 70, 60, PAPER, True)
text(s, 'Sem retain em\ncomandos e ACKs.', 1150, 435, 350, 100, 29, 'BAC3B9')
text(s, 'commandId', 1150, 600, 350, 50, 32, 'A6D5B8', True)
text(s, 'Une mensagem,\nexecução e banco.', 1150, 665, 350, 90, 29, PAPER)

s = slide('07 / ESP32 e NFC', 'Firmware da main / nfc.cpp · PR #67 · placa real contra o EMQX (06/11)', note=
          '1:10 — A placa real conectou no EMQX por TLS, leu a tag, publicou a tentativa, recebeu a decisão e deu feedback. O RC522 entrou no fluxo e uma apresentação não gera uma sequência de pedidos. O perfil físico separa pinos do TFT legado. O servo estava desabilitado nessa montagem: o ACK confirma feedback, não abertura física.')
heading(s, 'A placa real entrou no fluxo.', size=54)
box(s, 80, 300, 800, 390, '111713', True)
source = (ROOT / 'firmware/src/modules/nfc.cpp').read_text(encoding='utf-8')
snippet = '\n'.join(line.strip() for line in source.splitlines() if any(key in line for key in
                 ['PICC_WakeupA(', 'PICC_ReadCardSerial()', 'formatUid(', 'PICC_HaltA()', 'presentation.observe(', 'publisher == nullptr']))
text(s, snippet, 112, 335, 735, 320, 20, 'D8E7D9', mono=True)
text(s, 'Leitura NFC → MQTT\nDecisão no backend\nLED / display / buzzer', 960, 325, 550, 210, 34, INK, True)
text(s, 'Uma tentativa por apresentação.\nGPIOs documentados.\nBuild físico + Wokwi + TLS/OLED.', 960, 575, 550, 140, 27, MUTED)
text(s, 'BANCADA: ESP32 real no EMQX por TLS; servo desabilitado nessa montagem.', 80, 753, 1440, 55, 22, RED)

s = slide('08 / Consistência', 'Medição local de 11/11 · capturas/idempotencia.json · mesmo requestId', note=
          '0:50 — Foram feitos dois POSTs reais com o mesmo requestId. O primeiro consumiu um uso; repetir devolveu o mesmo evento e não consumiu outro. Os números 5, 6 e 6 são valores observados no banco de demonstração, não uma expectativa ilustrativa.')
heading(s, 'Repetir o pedido não repete o consumo.', size=54)
idem = json.loads((CAP / 'idempotencia.json').read_text(encoding='utf-8'))
for x, value, label in [(80, idem['before'], 'ANTES DO PEDIDO'), (590, idem['afterFirstRequest'], 'APÓS O PRIMEIRO'), (1100, idem['afterSameRequestId'], 'APÓS REPETIR O ID')]:
    text(s, str(value), x, 323, 400, 190, 160, GREEN if x == 1100 else INK, True)
    box(s, x, 535, 400, 2, 'C7CEC4')
    text(s, label, x, 570, 420, 40, 20, MUTED)
text(s, 'O mesmo evento. Um único uso adicional.', 80, 680, 1440, 60, 37, INK, True)
text(s, 'requestId ' + idem['requestId'], 80, 765, 1440, 35, 21, MUTED, mono=True)

s = slide('09 / Qualidade', 'CI main a0625d7 / run 43046423082 · Flutter local · validações em 11/11', True, note=
          '0:50 — O CI da main passou 460 testes de backend com banco e seed, em 53 arquivos, e 31 E2E. Localmente o Flutter passou análise e 215 testes. O firmware passou suíte host e builds físico, Wokwi e TLS/OLED. Isso é evidência de software, não substitui testes físicos de câmera, GPS ou energia.')
heading(s, 'Integração coberta por execução.', True)
for x, value, label, caption in [(80, '460', 'BACKEND', 'CI · PostgreSQL + seed'), (590, '215', 'FLUTTER', 'Testes locais + análise limpa'), (1100, '31', 'E2E', 'API + worker + broker + banco')]:
    text(s, value, x, 325, 430, 155, 132, PAPER, True)
    text(s, label, x, 508, 430, 40, 22, 'A6D5B8', True)
    text(s, caption, x, 568, 430, 90, 25, 'BAC3B9')
box(s, 80, 707, 1440, 2, '343A34')
text(s, 'Firmware: regressão de PUBACK lento + timing do servo com e sem TLS.', 80, 743, 1440, 50, 27, PAPER)

s = slide('10 / Está no ar', 'Verificação em 11/11 · /health, /healthz e log do worker · evidências em docs/entrega', note=
          '1:00 — O sistema não é uma maquete: app, API, banco, broker e worker estão publicados e conversando agora. O app decide com a API real; a API grava no Neon; o worker no Render assina o broker e responde. Não há número de histórias aqui: o que importa é o que roda.')

heading(s, 'Fizemos. Está no ar.', size=62)
text(s, 'Cinco peças, um fluxo de decisão — do celular ao terminal.', 80, 255, 1440, 45, 30, MUTED)
cards = [
    ('APP', 'FLUTTER', 'login, scanner\ne resultado', 'capturas reais'),
    ('API', 'VERCEL', 'a0625d7\ndatabase ok', '/health'),
    ('BANCO', 'NEON', 'eventos, comandos\ne ACK', 'produção'),
    ('BROKER', 'EMQX', 'TLS 8883\nQR de 25 s', 'produção'),
    ('WORKER', 'RENDER', 'mqtt conectado\n/healthz ok', 'no ar'),
]
for i, (name, platform, body, detail) in enumerate(cards):
    x = 80 + i * 300
    box(s, x, 330, 270, 300, 'EDF0E9', True)
    text(s, name, x + 24, 356, 222, 40, 30, INK, True)
    text(s, platform, x + 24, 400, 222, 30, 17, GREEN, True)
    text(s, body, x + 24, 448, 222, 110, 24, INK)
    text(s, detail, x + 24, 566, 222, 40, 18, MUTED, mono=True)
text(s, 'Software e hardware no mesmo fluxo, cada peça com evidência de execução.', 80, 700, 1440, 55, 30, GREEN, True)
text(s, 'O que ainda falta é bancada, não integração.', 80, 760, 1440, 40, 24, MUTED)

s = slide('11 / Próximos passos', 'S3 · 12–25/11/2026 · repositório e evidências disponíveis para inspeção', note=
          '0:50 + perguntas — Fechar com o que já é demonstrável: um pedido produz decisão rastreável, do celular ao broker. A próxima validação é no celular e no terminal físicos, incluindo o servo e a alimentação. Se houver demo ao vivo, usar o roteiro do README e manter a identificação das entradas simuladas. Equipe: João Victor Lopes Rosa, Felipe Pacheco, Carlos Santo, Caio Araujo, Leonardo da Silva Irineu e Arthur Facchinetti.')
text(s, 'Do celular\nao terminal.\nCom rastro.', 80, 190, 900, 365, 83, INK, True)
text(s, 'Demonstração e perguntas.', 85, 622, 900, 65, 36, GREEN, True)
text(s, 'João Victor Lopes Rosa · Felipe Pacheco\nCarlos Santo · Caio Araujo\nLeonardo da Silva Irineu · Arthur Facchinetti', 85, 706, 900, 110, 22, MUTED)
phone(s, 'app-android-liberado.png', 1080, 150, 280)

assert len(pages) == len(prs.slides) == 12
for number, s in enumerate(prs.slides, 1):
    for shape in s.shapes:
        assert shape.left >= 0 and shape.top >= 0, (number, shape.name)
        assert shape.left + shape.width <= prs.slide_width + 10, (number, shape.name)
        assert shape.top + shape.height <= prs.slide_height + 10, (number, shape.name)
        if shape.has_text_frame:
            assert not any(t in shape.text for t in ['TODO', 'TBD', 'COLE_O_LINK'])

prs.save(HERE / 'ABP4DSM-Sprint2-Apresentacao.pptx')
fonts = '../../../mobile/assets/fonts/figtree/'
styles = f'''@font-face{{font-family:Figtree;src:url('{fonts}Figtree-Regular.ttf');font-weight:400}}
@font-face{{font-family:Figtree;src:url('{fonts}Figtree-Bold.ttf');font-weight:700}}
*{{box-sizing:border-box}}body{{margin:0;background:#222}}section{{position:relative;width:1600px;height:900px;break-after:page;overflow:hidden}}
@page{{size:1600px 900px;margin:0}}@media print{{body{{background:white}}section:last-child{{break-after:auto}}}}'''
sections = ''.join('<section>' + ''.join(page) + '</section>' for page in pages)
deck = HERE / 'apresentacao.html'
deck.write_text('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>ABP4DSM / Sprint 2</title><style>' + styles + '</style><body>' + sections + '</body></html>', encoding='utf-8')
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width':1600,'height':900},device_scale_factor=1)
    page.goto(deck.as_uri())
    page.evaluate('document.fonts.ready')
    assert page.locator('section').count() == 12
    assert page.evaluate('Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0)')
    page.pdf(path=str(HERE / 'ABP4DSM-Sprint2-Apresentacao.pdf'), print_background=True, prefer_css_page_size=True)
    for i in range(12):
        page.locator('section').nth(i).screenshot(path=str(HERE / f'previa-{i+1:02}.png'))
    browser.close()
print('12 slides gerados: PPTX editavel, PDF vetorial e HTML com Figtree.')
