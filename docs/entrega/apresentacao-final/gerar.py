import html
from pathlib import Path

from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.util import Inches, Pt
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
CAP = HERE / 'capturas'
INK, PAPER, MUTED, GREEN, RED = '0A0A0A', 'F6F7F2', '6E756F', '137A4A', 'BF3333'
prs = Presentation()
prs.slide_width, prs.slide_height = Inches(16), Inches(9)
prs.core_properties.title = 'ABP 4DSM — Controle de acesso, ponta a ponta'
prs.core_properties.author = 'ErrorSquad · FATEC Jacareí'
pages = []


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


def phone(s, name, x, y, w=250):
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
    text(s, 'ERRORSQUAD / ABP 4DSM', 80, 843, 400, 25, 15, fg)
    text(s, source, 500, 843, 920, 35, 14, 'ACB4AC' if dark else MUTED)
    text(s, f'{len(pages):02} / 12', 1440, 843, 90, 25, 15, fg)
    s.notes_slide.notes_text_frame.text = note + '\n\nFonte: ' + source
    return s


def heading(s, value, dark=False, size=58):
    text(s, value, 80, 123, 1440, 160, size, PAPER if dark else INK, True)


# 01 — capa
s = slide('FATEC Jacareí / ABP 4DSM', 'Entrega final · 11/11/2026 · main a0625d7 + feat/app-figma-1-1', True,
          '40s — O projeto saiu do papel: app, API, banco, broker e terminal conversando. Tudo o que aparece aqui foi executado; as telas são do APK rodando em um Motorola g86 5G.')
box(s, 880, 0, 720, 820, '171D18')
text(s, 'O acesso\nque a gente\nconstruiu.', 80, 200, 780, 360, 84, PAPER, True)
text(s, 'Controle de acesso ponta a ponta', 85, 640, 760, 50, 30, PAPER)
text(s, 'APP  ·  API  ·  BANCO  ·  BROKER  ·  TERMINAL', 85, 706, 780, 50, 18, 'A6D5B8')
phone(s, 'app-autorizacoes.png', 930, 205, 240)
phone(s, 'app-scanner.png', 1200, 160, 240)

# 02 — o produto
s = slide('01 / O produto', 'Fluxo executado no aparelho: login → QR → decisão → registro', note=
          '50s — Uma frase para o problema: liberar acesso sem confiar no celular. O app pede, a API decide com QR assinado, janela, usos e distância; o banco registra; o terminal recebe o comando. O celular nunca decide sozinho.')
heading(s, 'Um app, um terminal, uma decisão.')
for i, (titulo, corpo) in enumerate([
    ('App', 'Autentica, lê o QR\ne pede o acesso'),
    ('API', 'Valida QR, janela,\nusos e 100 m'),
    ('Banco', 'Evento, comando\ne ACK registrados'),
    ('Terminal', 'Recebe o comando\ne devolve o ACK'),
]):
    x = 80 + i * 370
    text(s, titulo.upper(), x, 330, 320, 40, 20, GREEN, True)
    text(s, corpo, x, 390, 330, 140, 30, INK)
text(s, 'A regra não fica no celular.', 80, 620, 1440, 60, 40, INK, True)
text(s, 'Nesta demonstração o terminal do QR é simulado: sem ESP32 conectado e sem ACK de movimento.', 80, 700, 1440, 50, 24, MUTED)

# 03 — entrar e autorizações
s = slide('02 / App', 'APK debug em Android 15 · tema escuro · API local real', note=
          '1min — Login real contra a API e a tela principal do design: Minhas autorizações, com abas e o cartão de uso. Não há Home inventada: o app abre direto no que o Figma define.')
phone(s, 'app-entrar.png', 150, 200, 260)
phone(s, 'app-autorizacoes.png', 460, 200, 260)
text(s, 'Entrar de verdade.', 820, 240, 700, 60, 48, INK, True)
text(s, 'Sessão que sobrevive ao fechar o app.\nMinhas autorizações no formato do design:\nabas, status, janela e usos restantes.', 820, 330, 700, 180, 28)
text(s, 'Tema claro e escuro com os mesmos tokens.', 820, 560, 700, 40, 22, GREEN)

# 04 — detalhe e vazio
s = slide('03 / Detalhe', 'Sem frame para o erro de rede: usa o cartão de estados do design', note=
          '50s — O detalhe mostra local, período, usos e pessoa; a janela multidia aparece com as duas datas. O estado vazio existe de verdade: é o que um administrador vê ao entrar.')
phone(s, 'app-detalhe.png', 150, 200, 260)
phone(s, 'app-vazio.png', 460, 200, 260)
text(s, 'Cada autorização tem contexto.', 820, 240, 700, 60, 46, INK, True)
text(s, 'Local, período, usos e pessoa na mesma tela.\nStatus, janela e usos restantes coerentes.\nVazio, carregando e erro previstos.', 820, 330, 700, 180, 28)

# 05 — scanner e perfil
s = slide('04 / Câmera e perfil', 'Câmera do aparelho lendo o QR exibido no monitor', note=
          '1min — O scanner é o do aparelho, não uma simulação. E o perfil traz edição de nome e alternância de tema, com acessibilidade AA.')
phone(s, 'app-scanner.png', 150, 200, 260)
phone(s, 'app-perfil-claro.png', 460, 200, 260)
text(s, 'Ler, decidir e mostrar.', 820, 240, 700, 60, 46, INK, True)
text(s, 'Câmera e GPS reais no pedido.\nPerfil edita o nome e troca o tema.\nContraste AA e fonte ampliada suportados.', 820, 330, 700, 180, 28)

# 06 — admin autorizações
s = slide('05 / Administração', 'Telas sem frame no Figma, derivadas dos tokens do design', note=
          '1min — Duas telas que não existiam no design e foram construídas com a mesma identidade: administração de autorizações e de usuários. Ambas exigem papel ADMIN na API.')
phone(s, 'app-admin-autorizacoes.png', 150, 200, 260)
phone(s, 'app-admin-usuarios.png', 460, 200, 260)
text(s, 'Administrar sem sair do app.', 820, 240, 700, 60, 44, INK, True)
text(s, 'Criar, filtrar e cancelar autorizações.\nUsuários com papel, situação e histórico\nde acessos. 403 e 409 tratados.', 820, 330, 700, 180, 28)

# 07 — locais
s = slide('06 / Locais', 'Cadastro executado no aparelho e conferido no PostgreSQL', note=
          '1min — O cadastro de local foi feito de verdade: preenchi no aparelho, salvou, voltou para a lista. Confirmei a linha no banco: Portaria, raio 100 m. A lista só aparece para ADMIN.')
phone(s, 'app-novo-local.png', 150, 200, 260)
phone(s, 'app-locais-criado.png', 460, 200, 260)
text(s, 'Cadastro que chega no banco.', 820, 240, 700, 60, 44, INK, True)
text(s, 'Latitude, longitude e raio validados\nno app e na API (1 a 100 m).\nLocal novo aparece na lista na hora.', 820, 330, 700, 180, 28)

# 08 — arquitetura
s = slide('07 / Arquitetura', 'Vercel · Neon · Render · EMQX Cloud · ESP32', True, note=
          '1min — Quatro peças hospedadas e o terminal. A API é serverless; o worker mantém a sessão MQTT; o banco guarda evento, comando e deduplicação; o broker entrega ao ESP32 por TLS.')
heading(s, 'Quatro serviços, um fluxo.', True)
for i, (nome, detalhe) in enumerate([
    ('APP', 'Flutter · Android'),
    ('API', 'Express · Vercel'),
    ('BANCO', 'Neon · PostgreSQL'),
    ('BROKER', 'EMQX · TLS 8883'),
]):
    x = 80 + i * 300
    box(s, x, 320, 270, 160, '171D18', True)
    text(s, nome, x + 24, 350, 220, 40, 28, PAPER, True)
    text(s, detalhe, x + 24, 405, 230, 60, 20, 'A6D5B8')
text(s, 'APP → HTTPS → API → Postgres', 80, 540, 900, 45, 30, PAPER, True)
text(s, 'API → MQTT → BROKER → ESP32 → ACK', 80, 595, 900, 45, 30, PAPER, True)
text(s, 'O worker no Render mantém a própria conexão MQTT e o relay da outbox; acompanha o status do terminal.', 80, 680, 1400, 50, 24, 'BAC3B9')

# 09 — no ar
s = slide('08 / Está no ar', 'Verificações de 11/11: /health, /healthz e logs', True, note=
          '1min — Não é demo local: a API está na Vercel no commit a0625d7 com banco ok; o worker no Render está live, conectado ao EMQX; o banco é o Neon. O QR vale 25 s e a geofence é 100 m.')
heading(s, 'Publicado, não só commitado.', True)
for i, (nome, estado, detalhe) in enumerate([
    ('API', 'a0625d7', 'database ok'),
    ('WORKER', 'live', 'mqtt conectado'),
    ('BANCO', 'Neon', 'migrations aplicadas'),
    ('BROKER', 'EMQX', 'TLS 8883'),
]):
    x = 80 + i * 370
    text(s, nome, x, 330, 330, 40, 20, 'A6D5B8', True)
    text(s, estado, x, 380, 340, 80, 46, PAPER, True)
    text(s, detalhe, x, 470, 340, 60, 24, 'BAC3B9')
text(s, 'Worker: assina access-events, status e acks; expurgos de comando e deduplicação com ok.', 80, 600, 1440, 60, 26, PAPER)

# 10 — qualidade
s = slide('09 / Qualidade', 'flutter test · npm test · CI na main', note=
          '50s — 640 testes no app, 433 no backend, 31 E2E com banco e broker temporários. O CI roda na main; a revisão independente encontrou cinco problemas e todos foram corrigidos com regressão.')
heading(s, 'O que sustenta o "está pronto".')
for x, valor, rotulo, legenda in [
    (80, '640', 'FLUTTER', 'inclui acessibilidade 2.0x'),
    (590, '433', 'BACKEND', 'API + domínio + rotas'),
    (1100, 'E2E', 'INTEGRAÇÃO', 'banco e broker reais'),
]:
    text(s, valor, x, 330, 430, 150, 120, INK, True)
    text(s, rotulo, x, 500, 430, 40, 22, GREEN, True)
    text(s, legenda, x, 555, 430, 60, 24, MUTED)
text(s, 'Revisão independente apontou problemas reais; todos foram corrigidos com teste de regressão.', 80, 690, 1440, 50, 26, INK, True)

# 11 — limites
s = slide('10 / O que falta', 'Escopo honesto: bancada física e distribuição', note=
          '1min — O fluxo QR está demonstrado de ponta a ponta em software. O que falta é bancada e distribuição: servo e cancela, heartbeat do terminal, modo offline e build release assinado. Dizer isso protege a entrega.')
heading(s, 'Fluxo QR demonstrado. Física pendente.')
for i, (titulo, corpo) in enumerate([
    ('Servo e cancela', 'ACK confirma feedback;\no movimento físico não foi validado'),
    ('Heartbeat', 'status online hoje vem\ndo simulador, não do firmware'),
    ('Modo offline', 'fila local no terminal\nsegue fora do escopo'),
    ('Release', 'APK usado é debug;\npublicação em loja não feita'),
]):
    x = 80 + i * 370
    text(s, titulo, x, 330, 330, 45, 24, RED, True)
    text(s, corpo, x, 390, 340, 130, 26, INK)

# 12 — encerramento
s = slide('11 / Fechamento', 'Repositório e evidências disponíveis para inspeção', note=
          '40s + perguntas — Fechar com o que é demonstrável: o fluxo roda no aparelho, decide na API e registra no banco. Equipe: João Victor Lopes Rosa, Felipe Pacheco, Carlos Santo, Caio Araujo, Leonardo da Silva Irineu e Arthur Facchinetti.')
text(s, 'Do celular\nao terminal.\nCom rastro.', 80, 190, 900, 365, 80, INK, True)
text(s, 'Demonstração e perguntas.', 85, 620, 900, 65, 36, GREEN, True)
text(s, 'João Victor Lopes Rosa · Felipe Pacheco\nCarlos Santo · Caio Araujo\nLeonardo da Silva Irineu · Arthur Facchinetti', 85, 706, 900, 110, 22, MUTED)
phone(s, 'app-autorizacoes.png', 1080, 150, 268)

assert len(pages) == len(prs.slides) == 12
for number, s in enumerate(prs.slides, 1):
    for shape in s.shapes:
        assert shape.left >= 0 and shape.top >= 0, (number, shape.name)
        assert shape.left + shape.width <= prs.slide_width + 10, (number, shape.name)
        assert shape.top + shape.height <= prs.slide_height + 10, (number, shape.name)

prs.save(HERE / 'ABP4DSM-Entrega-Final.pptx')
fonts = '../../../mobile/assets/fonts/figtree/'
styles = f'''@font-face{{font-family:Figtree;src:url('{fonts}Figtree-Regular.ttf');font-weight:400}}
@font-face{{font-family:Figtree;src:url('{fonts}Figtree-Bold.ttf');font-weight:700}}
*{{box-sizing:border-box}}body{{margin:0;background:#222}}section{{position:relative;width:1600px;height:900px;break-after:page;overflow:hidden}}
@page{{size:1600px 900px;margin:0}}@media print{{body{{background:white}}section:last-child{{break-after:auto}}}}'''
deck = HERE / 'apresentacao.html'
deck.write_text('<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>ABP4DSM · Entrega final</title><style>' + styles + '</style><body>'
                + ''.join('<section>' + ''.join(page) + '</section>' for page in pages) + '</body></html>', encoding='utf-8')
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width': 1600, 'height': 900}, device_scale_factor=1)
    page.goto(deck.as_uri())
    page.evaluate('document.fonts.ready')
    assert page.locator('section').count() == 12
    assert page.evaluate('Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0)')
    page.pdf(path=str(HERE / 'ABP4DSM-Entrega-Final.pdf'), print_background=True, prefer_css_page_size=True)
    for i in range(12):
        page.locator('section').nth(i).screenshot(path=str(HERE / f'previa-{i+1:02}.png'))
    browser.close()
print('12 slides da entrega final gerados.')
