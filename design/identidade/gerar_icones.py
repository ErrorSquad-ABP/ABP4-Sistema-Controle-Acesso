"""Gera os ícones do app (web e Android) a partir de marca.svg.

Uso, na raiz do repositório:
    python -m pip install -r design/identidade/requirements.txt
    python design/identidade/gerar_icones.py

A geometria vem só de marca.svg (atributos d dos paths "escudo" e "check").
O script reescreve as variantes SVG desta pasta, a prévia e os arquivos de
ícone em mobile/web e mobile/android. Rode de novo sempre que a marca mudar.
"""

from __future__ import annotations

import re
from pathlib import Path

import pymupdf

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
WEB = RAIZ / 'mobile' / 'web'
RES = RAIZ / 'mobile' / 'android' / 'app' / 'src' / 'main' / 'res'

TINTA = '#0A0A0A'  # texto/fundo escuro do design system
PAPEL = '#FAFAFA'  # fundo claro do design system
CAIXA = 24.0  # viewBox da marca

ANDROID_LEGADO = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def ler_marca() -> dict[str, str]:
    texto = (AQUI / 'marca.svg').read_text(encoding='utf-8')
    paths = dict(re.findall(r'<path id="([^"]+)" d="([^"]+)"', texto))
    if set(paths) != {'escudo', 'check'}:
        raise SystemExit('marca.svg precisa dos paths "escudo" e "check"')
    return paths


def glifo(paths: dict[str, str], cor: str, traco: float, lado: float, total: float) -> str:
    """Marca centrada num quadro de `total` px, ocupando `lado` px; `traco` em unidades da marca."""
    escala = lado / CAIXA
    desloc = (total - lado) / 2
    corpo = ''.join(f'<path d="{d}"/>' for d in paths.values())
    return (f'<g transform="translate({desloc:.3f} {desloc:.3f}) scale({escala:.5f})" fill="none" stroke="{cor}" '
            f'stroke-width="{traco}" stroke-linecap="round" stroke-linejoin="round">{corpo}</g>')


def svg(total: float, conteudo: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total:g} {total:g}" '
            f'width="{total:g}" height="{total:g}">{conteudo}</svg>\n')


def ladrilho(lado: float, raio: float, cor: str) -> str:
    """Quadrado de cantos arredondados como path com arcos Bezier exatos (rect rx varia entre renderizadores)."""
    r = min(raio, lado / 2)
    k = r * (1 - 0.5522847498)  # distancia do ponto de controle ao canto
    l = lado
    d = (f'M{r:.2f} 0 H{l - r:.2f} C{l - k:.2f} 0 {l:.2f} {k:.2f} {l:.2f} {r:.2f} '
         f'V{l - r:.2f} C{l:.2f} {l - k:.2f} {l - k:.2f} {l:.2f} {l - r:.2f} {l:.2f} '
         f'H{r:.2f} C{k:.2f} {l:.2f} 0 {l - k:.2f} 0 {l - r:.2f} '
         f'V{r:.2f} C0 {k:.2f} {k:.2f} 0 {r:.2f} 0 Z')
    return f'<path d="{d}" fill="{cor}"/>'


def icone(paths: dict[str, str]) -> str:
    """Uso geral (manifest "any", apple-touch, launcher legado): ladrilho arredondado."""
    t = 1024
    return svg(t, ladrilho(t, 230, TINTA) + glifo(paths, PAPEL, 1.7, 640, t))


def maskable(paths: dict[str, str]) -> str:
    """Sangrado: o sistema recorta; a marca fica dentro do círculo seguro de 80%."""
    t = 1024
    return svg(t, f'<rect width="{t}" height="{t}" fill="{TINTA}"/>' + glifo(paths, PAPEL, 1.7, 520, t))


def favicon(paths: dict[str, str]) -> str:
    """Aba do navegador: marca maior e traço mais grosso para ler em 16-32 px."""
    t = 1024
    return svg(t, ladrilho(t, 200, TINTA) + glifo(paths, PAPEL, 2.4, 820, t))


def png(conteudo: str, destino: Path, px: int) -> None:
    doc = pymupdf.open(stream=conteudo.encode('utf-8'), filetype='svg')
    pagina = doc[0]
    zoom = px / pagina.rect.width
    pix = pagina.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), alpha=True)
    destino.parent.mkdir(parents=True, exist_ok=True)
    pix.save(str(destino))
    print(f'{destino.relative_to(RAIZ)}  {pix.width}x{pix.height}')


def android_vetor(paths: dict[str, str]) -> str:
    """Primeiro plano adaptativo (108 dp): marca de 50 dp, dentro da zona segura de 66 dp."""
    lado = 50.4
    escala = lado / CAIXA
    desloc = (108 - lado) / 2
    corpo = ''.join(
        f'\n        <path\n            android:pathData="{d}"\n            android:strokeColor="#FFFFFFFF"\n'
        f'            android:strokeWidth="1.7"\n            android:strokeLineCap="round"\n'
        f'            android:strokeLineJoin="round" />'
        for d in paths.values())
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Gerado por design/identidade/gerar_icones.py a partir de marca.svg. Não editar à mão. -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp"\n    android:height="108dp"\n'
            '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
            f'    <group\n        android:translateX="{desloc:.1f}"\n        android:translateY="{desloc:.1f}"\n'
            f'        android:scaleX="{escala:.2f}"\n        android:scaleY="{escala:.2f}">{corpo}\n    </group>\n'
            '</vector>\n')


ADAPTATIVO = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Gerado por design/identidade/gerar_icones.py. Android 8+ usa este ícone; abaixo disso, os PNGs mipmap. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'''

COR_FUNDO = f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Gerado por design/identidade/gerar_icones.py. -->
<resources>
    <color name="ic_launcher_background">{TINTA}</color>
</resources>
'''


def previa(paths: dict[str, str]) -> str:
    """Folha de conferência: tamanhos reais e as máscaras de launcher mais comuns."""
    largura, altura = 1200, 600
    partes = [f'<rect width="{largura}" height="{altura}" fill="{PAPEL}"/>']

    def interno(conteudo: str) -> str:
        return conteudo[conteudo.index('>') + 1:conteudo.rindex('</svg>')]

    # linha 1: o icone de uso geral nos tamanhos reais de uso; o favicon em 32 e 16
    x = 40
    for px, fonte in ((256, icone), (192, icone), (96, icone), (48, icone), (32, favicon), (16, favicon)):
        partes.append(f'<g transform="translate({x} {40 + (256 - px)}) scale({px / 1024})">{interno(fonte(paths))}</g>')
        x += px + 40
    # linha 2: maskable recortado pelas mascaras comuns de launcher (circulo, squircle,
    # quadrado arredondado), desenhadas como a propria forma porque o fundo e cor unica
    marca = glifo(paths, PAPEL, 1.7, 520, 1024)
    for i, raio in enumerate((512, 300, 120)):
        partes.append(f'<g transform="translate({40 + i * 240} 360) scale({200 / 1024})">'
                      f'{ladrilho(1024, raio, TINTA)}{marca}</g>')
    # zona segura do maskable (circulo de 80%) em vermelho
    partes.append(f'<g transform="translate(760 360) scale({200 / 1024})">{interno(maskable(paths))}'
                  f'<circle cx="512" cy="512" r="410" fill="none" stroke="#DC2626" stroke-width="8"/></g>')
    return svg_retangular(largura, altura, ''.join(partes))


def svg_retangular(w: int, h: int, conteudo: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{conteudo}</svg>\n'


def main() -> None:
    paths = ler_marca()
    variantes = {'icone.svg': icone(paths), 'icone-maskable.svg': maskable(paths), 'favicon.svg': favicon(paths)}
    for nome, conteudo in variantes.items():
        (AQUI / nome).write_text(conteudo, encoding='utf-8')

    png(variantes['favicon.svg'], WEB / 'favicon.png', 32)
    png(variantes['icone.svg'], WEB / 'icons' / 'Icon-192.png', 192)
    png(variantes['icone.svg'], WEB / 'icons' / 'Icon-512.png', 512)
    png(variantes['icone-maskable.svg'], WEB / 'icons' / 'Icon-maskable-192.png', 192)
    png(variantes['icone-maskable.svg'], WEB / 'icons' / 'Icon-maskable-512.png', 512)

    for densidade, px in ANDROID_LEGADO.items():
        png(variantes['icone.svg'], RES / f'mipmap-{densidade}' / 'ic_launcher.png', px)
    escritos = {
        RES / 'drawable' / 'ic_launcher_foreground.xml': android_vetor(paths),
        RES / 'mipmap-anydpi-v26' / 'ic_launcher.xml': ADAPTATIVO,
        RES / 'values' / 'ic_launcher_background.xml': COR_FUNDO,
    }
    for destino, conteudo in escritos.items():
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_text(conteudo, encoding='utf-8', newline='\n')
        print(destino.relative_to(RAIZ))

    png(previa(paths), AQUI / 'previa.png', 1200)


if __name__ == '__main__':
    main()
