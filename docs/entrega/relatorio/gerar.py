"""Gera o relatorio ABNT (DOCX e PDF) a partir de relatorio.md.

Uso (dentro de docs/entrega/relatorio):
    python gerar.py            # rascunho em build/: relatorio.docx e relatorio.pdf
    python gerar.py --final    # recusa pendencias/links quebrados e grava relatorio-final.pdf
    python gerar.py --so-docx  # nao chama o Word/LibreOffice

A matriz de requisitos (../matriz-requisitos.md) e o indice de evidencias
(../README.md) sao lidos na hora: o relatorio nao copia esses dados a mao.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_COLOR_INDEX, WD_LINE_SPACING, WD_TAB_ALIGNMENT, WD_TAB_LEADER
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

AQUI = Path(__file__).resolve().parent
ENTREGA = AQUI.parent
FONTE = AQUI / 'relatorio.md'
MATRIZ = ENTREGA / 'matriz-requisitos.md'
INDICE = ENTREGA / 'README.md'
SAIDA = AQUI / 'build'
FINAL = AQUI / 'relatorio-final.pdf'

FAMILIA = 'Arial'
MONO = 'Courier New'
LARGURA_TEXTO_CM = 16.0  # A4 (21 cm) - 3 cm (esq.) - 2 cm (dir.)

PENDENTE_RE = re.compile(r'\[PENDENTE:[^\]]*\]')
INLINE_RE = re.compile(
    r'(?P<pend>\[PENDENTE:[^\]]*\])'
    r'|(?P<link>\[(?P<ltxt>[^\]]+)\]\((?P<lurl>[^)]+)\))'
    r'|(?P<bold>\*\*(?P<btxt>.+?)\*\*)'
    r'|(?P<code>`(?P<ctxt>[^`]+)`)'
    r'|(?P<ital>(?<![\w*])\*(?P<itxt>[^*\s][^*]*?)\*(?![\w*]))'
)

PRETEXTUAIS = {'RESUMO', 'ABSTRACT', 'LISTA DE ABREVIATURAS E SIGLAS', 'LISTA DE QUADROS', 'SUMÁRIO'}
POSTEXTUAIS = ('REFERÊNCIAS', 'APÊNDICE', 'ANEXO', 'GLOSSÁRIO')


# --------------------------------------------------------------------------- dados

@dataclass
class Tabela:
    cabecalho: list[str]
    linhas: list[list[str]]


@dataclass
class Relato:
    pendencias: list[tuple[int, str]] = field(default_factory=list)
    erros: list[str] = field(default_factory=list)
    avisos: list[str] = field(default_factory=list)


def celulas(linha: str) -> list[str]:
    return [c.strip() for c in linha.strip().strip('|').split('|')]


def tabelas_markdown(texto: str) -> list[tuple[str, Tabela]]:
    """Devolve (titulo da secao ##, tabela) para cada tabela pipe do arquivo."""
    resultado, secao, linhas = [], '', texto.splitlines()
    i = 0
    while i < len(linhas):
        linha = linhas[i]
        if linha.startswith('## '):
            secao = linha[3:].strip()
        if linha.startswith('|') and i + 1 < len(linhas) and re.match(r'^\|[\s:|-]+\|$', linhas[i + 1].strip()):
            cab = celulas(linha)
            corpo = []
            i += 2
            while i < len(linhas) and linhas[i].startswith('|'):
                corpo.append(celulas(linhas[i]))
                i += 1
            resultado.append((secao, Tabela(cab, corpo)))
            continue
        i += 1
    return resultado


def sem_marcas(texto: str) -> str:
    return re.sub(r'[*`]', '', texto).strip()


def chave_status(status: str) -> str:
    s = sem_marcas(status).lower()
    for origem, destino in (('ã', 'a'), ('í', 'i'), ('ó', 'o'), (' ', '_')):
        s = s.replace(origem, destino)
    return s


GRUPOS = {'Requisitos funcionais': 'RF', 'Requisitos não funcionais': 'RNF', 'Restrições de projeto': 'RP'}
STATUS_VALIDOS = {'atendido', 'parcial', 'nao_atendido', 'nao_comprovado'}
REFERENCIA_RE = re.compile(r'`[^`]+`|#\d+|\]\([^)]+\)|\b(US|DT)-\d+')
LINK_RE = re.compile(r'\]\(([^)#\s]+)(#[^)]*)?\)')


def ler_matriz(relato: Relato) -> tuple[list[tuple[str, Tabela]], dict[str, str]]:
    texto = MATRIZ.read_text(encoding='utf-8')
    grupos = [(s, t) for s, t in tabelas_markdown(texto) if s in GRUPOS]
    valores: dict[str, str] = {}
    for secao, tabela in grupos:
        sigla = GRUPOS[secao]
        contagem = {k: [] for k in STATUS_VALIDOS}
        for linha in tabela.linhas:
            ident, status, evidencia = linha[0], linha[2], linha[3] if len(linha) > 3 else ''
            chave = chave_status(status)
            if chave not in STATUS_VALIDOS:
                relato.erros.append(f'matriz: {ident} com status desconhecido "{status}"')
                continue
            contagem[chave].append(ident)
            if not evidencia.strip():
                relato.erros.append(f'matriz: {ident} sem evidência nem lacuna declarada')
            elif chave == 'atendido' and not REFERENCIA_RE.search(evidencia):
                relato.erros.append(f'matriz: {ident} "Atendido" sem referência verificável (arquivo, PR ou card)')
            verificar_links(evidencia, MATRIZ.parent, f'matriz {ident}', relato)
        valores[f'{sigla}.total'] = str(len(tabela.linhas))
        for chave, ids in contagem.items():
            valores[f'{sigla}.{chave}'] = str(len(ids))
            valores[f'{sigla}.lista.{chave}'] = juntar(ids)
    if len(grupos) != 3:
        relato.erros.append('matriz: esperadas as tabelas RF, RNF e RP')
    total = sum(int(valores.get(f'{g}.total', 0)) for g in GRUPOS.values())
    valores['total'] = str(total)
    for chave in STATUS_VALIDOS:
        valores[f'total.{chave}'] = str(sum(int(valores.get(f'{g}.{chave}', 0)) for g in GRUPOS.values()))
    revisao = re.search(r'revisto em \*\*([^*]+)\*\*', texto)
    valores['matriz.revisao'] = revisao.group(1) if revisao else '[data não encontrada]'
    atualizado = re.search(r'atualizado em \*\*([^*]+)\*\*', texto)
    valores['matriz.atualizacao'] = atualizado.group(1) if atualizado else valores['matriz.revisao']
    return grupos, valores


def juntar(itens: list[str]) -> str:
    if not itens:
        return 'nenhum'
    if len(itens) == 1:
        return itens[0]
    return ', '.join(itens[:-1]) + ' e ' + itens[-1]


def ler_indice(relato: Relato) -> Tabela | None:
    for _, tabela in tabelas_markdown(INDICE.read_text(encoding='utf-8')):
        if tabela.cabecalho and tabela.cabecalho[0].lower().startswith('evidência'):
            for linha in tabela.linhas:
                verificar_links(linha[0], INDICE.parent, f'índice {sem_marcas(linha[1])}', relato)
            return tabela
    relato.erros.append('índice de evidências não encontrado em docs/entrega/README.md')
    return None


def verificar_links(texto: str, base: Path, origem: str, relato: Relato) -> None:
    for alvo, _ in LINK_RE.findall(texto):
        if alvo.startswith(('http://', 'https://', 'mailto:')):
            continue
        if not (base / alvo).exists():
            relato.erros.append(f'{origem}: link quebrado para {alvo}')


# --------------------------------------------------------------------------- docx: base

def configurar(doc: Document) -> None:
    st = doc.styles
    normal = st['Normal']
    normal.font.name = FAMILIA
    normal.font.size = Pt(12)
    normal.element.rPr.rFonts.set(qn('w:eastAsia'), FAMILIA)
    pf = normal.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)
    pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    pf.widow_control = True

    def titulo(nome: str, negrito: bool, caixa_alta: bool, quebra: bool) -> None:
        s = st[nome]
        s.font.name = FAMILIA
        s.font.size = Pt(12)
        s.font.bold = negrito
        s.font.italic = False
        s.font.all_caps = caixa_alta
        s.font.color.rgb = RGBColor(0, 0, 0)
        rpr = s.element.get_or_add_rPr()
        fontes = rpr.find(qn('w:rFonts'))
        if fontes is None:
            fontes = OxmlElement('w:rFonts')
            rpr.append(fontes)
        for atributo in ('w:ascii', 'w:hAnsi', 'w:eastAsia', 'w:cs'):
            fontes.set(qn(atributo), FAMILIA)
        for tema in ('w:asciiTheme', 'w:hAnsiTheme', 'w:eastAsiaTheme', 'w:cstheme'):
            fontes.attrib.pop(qn(tema), None)
        p = s.paragraph_format
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
        p.space_before = Pt(0 if quebra else 18)
        p.space_after = Pt(18)
        p.first_line_indent = Cm(0)
        p.keep_with_next = True
        p.page_break_before = quebra

    titulo('Heading 1', True, True, True)
    titulo('Heading 2', True, False, False)
    titulo('Heading 3', False, False, False)

    pre = st.add_style('Titulo sem indicativo', WD_STYLE_TYPE.PARAGRAPH)
    pre.base_style = normal
    pre.font.bold = True
    pre.font.all_caps = True
    pre.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pre.paragraph_format.space_after = Pt(18)
    pre.paragraph_format.first_line_indent = Cm(0)
    pre.paragraph_format.page_break_before = True

    corpo = st.add_style('Corpo', WD_STYLE_TYPE.PARAGRAPH)
    corpo.base_style = normal
    corpo.paragraph_format.first_line_indent = Cm(1.25)

    alinea = st.add_style('Alinea', WD_STYLE_TYPE.PARAGRAPH)
    alinea.base_style = normal
    alinea.paragraph_format.left_indent = Cm(1.25 + 0.75)
    alinea.paragraph_format.first_line_indent = Cm(-0.75)

    legenda = st.add_style('Legenda ABNT', WD_STYLE_TYPE.PARAGRAPH)
    legenda.base_style = normal
    legenda.font.size = Pt(10)
    legenda.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    legenda.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    legenda.paragraph_format.first_line_indent = Cm(0)
    legenda.paragraph_format.keep_with_next = True

    celula = st.add_style('Celula', WD_STYLE_TYPE.PARAGRAPH)
    celula.base_style = normal
    celula.font.size = Pt(10)
    celula.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    celula.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    celula.paragraph_format.first_line_indent = Cm(0)

    codigo = st.add_style('Codigo', WD_STYLE_TYPE.PARAGRAPH)
    codigo.base_style = normal
    codigo.font.name = MONO
    codigo.font.size = Pt(10)
    codigo.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    codigo.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    codigo.paragraph_format.left_indent = Cm(1.25)

    referencia = st.add_style('Referencia', WD_STYLE_TYPE.PARAGRAPH)
    referencia.base_style = normal
    referencia.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
    referencia.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
    referencia.paragraph_format.first_line_indent = Cm(0)
    referencia.paragraph_format.space_after = Pt(12)

    for nivel, negrito in ((1, True), (2, False), (3, False)):
        # builtin=True + styleId TOC<n>: o Word usa este estilo no campo TOC em vez do padrao dele
        toc = st.add_style(f'toc {nivel}', WD_STYLE_TYPE.PARAGRAPH, builtin=True)
        toc.element.styleId = f'TOC{nivel}'
        toc.base_style = normal
        toc.paragraph_format.space_after = Pt(0)
        toc.font.bold = negrito
        toc.font.all_caps = nivel == 1
        p = toc.paragraph_format
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        p.first_line_indent = Cm(0)
        p.left_indent = Cm(0)
        p.tab_stops.add_tab_stop(Cm(LARGURA_TEXTO_CM), WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)


def margens(secao) -> None:
    secao.page_width, secao.page_height = Cm(21), Cm(29.7)
    secao.top_margin, secao.left_margin = Cm(3), Cm(3)
    secao.bottom_margin, secao.right_margin = Cm(2), Cm(2)
    secao.header_distance = Cm(2)
    secao.footer_distance = Cm(1.25)


def campo(paragrafo, instrucao: str, texto: str = '') -> None:
    def fld(tipo: str):
        run = paragrafo.add_run()
        el = OxmlElement('w:fldChar')
        el.set(qn('w:fldCharType'), tipo)
        run._r.append(el)
        return run

    fld('begin')
    run = paragrafo.add_run()
    instr = OxmlElement('w:instrText')
    instr.set(qn('xml:space'), 'preserve')
    instr.text = f' {instrucao} '
    run._r.append(instr)
    fld('separate')
    paragrafo.add_run(texto)
    fld('end')


def numeracao_inicial(secao, inicio: int) -> None:
    pg = OxmlElement('w:pgNumType')
    pg.set(qn('w:start'), str(inicio))
    secao._sectPr.append(pg)


def repetir_cabecalho(linha) -> None:
    trpr = linha._tr.get_or_add_trPr()
    el = OxmlElement('w:tblHeader')
    el.set(qn('w:val'), 'true')
    trpr.append(el)


def sem_divisao(linha) -> None:
    trpr = linha._tr.get_or_add_trPr()
    trpr.append(OxmlElement('w:cantSplit'))


# --------------------------------------------------------------------------- docx: texto

class Escritor:
    def __init__(self, valores: dict[str, str], relato: Relato):
        self.doc = Document()
        configurar(self.doc)
        margens(self.doc.sections[0])
        self.valores = valores
        self.relato = relato
        self.quadros = 0
        self.figuras = 0
        self.linha_atual = 0
        self.textual_iniciado = False
        self.pretextual_iniciado = False

    # ---- texto inline
    def expandir(self, texto: str) -> str:
        def troca(m: re.Match) -> str:
            chave = m.group(1).strip()
            if chave not in self.valores:
                self.relato.erros.append(f'linha {self.linha_atual}: placeholder desconhecido {{{{{chave}}}}}')
                return m.group(0)
            return self.valores[chave]

        return re.sub(r'\{\{([^}]+)\}\}', troca, texto)

    def inline(self, paragrafo, texto: str, negrito: bool = False, italico: bool = False, mono: bool = False) -> None:
        texto = self.expandir(texto)
        pos = 0
        for m in INLINE_RE.finditer(texto):
            if m.start() > pos:
                self.run(paragrafo, texto[pos:m.start()], negrito, italico, mono)
            if m.group('pend'):
                self.relato.pendencias.append((self.linha_atual, m.group('pend')))
                r = self.run(paragrafo, m.group('pend'), True, italico, False)
                r.font.highlight_color = WD_COLOR_INDEX.YELLOW
            elif m.group('link'):
                self.inline(paragrafo, m.group('ltxt'), negrito, italico, mono)
            elif m.group('bold'):
                self.inline(paragrafo, m.group('btxt'), True, italico, mono)
            elif m.group('code'):
                self.run(paragrafo, m.group('ctxt'), negrito, italico, True)
            elif m.group('ital'):
                self.inline(paragrafo, m.group('itxt'), negrito, True, mono)
            pos = m.end()
        if pos < len(texto):
            self.run(paragrafo, texto[pos:], negrito, italico, mono)

    def run(self, paragrafo, texto: str, negrito: bool, italico: bool, mono: bool):
        r = paragrafo.add_run(texto)
        r.bold = negrito or None
        r.italic = italico or None
        if mono:
            r.font.name = MONO
            r.font.size = Pt(max(8, (paragrafo.style.font.size or Pt(12)).pt - 1))
        return r

    def paragrafo(self, texto: str, estilo: str = 'Corpo', alinhamento=None):
        p = self.doc.add_paragraph(style=estilo)
        if alinhamento is not None:
            p.alignment = alinhamento
        self.inline(p, texto)
        return p

    # ---- elementos pre-textuais
    def centro(self, texto: str, negrito: bool = False, antes: float = 0, destino=None):
        p = (destino or self.doc).add_paragraph(style='Normal')
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(antes)
        self.inline(p, texto, negrito=negrito)
        return p

    def titulo_capa(self, meta: dict[str, str], antes: float) -> None:
        p = self.centro(meta['titulo'].upper(), negrito=True, antes=antes)
        if meta.get('subtitulo'):
            self.inline(p, ': ' + meta['subtitulo'])

    def capa(self, meta: dict[str, str]) -> None:
        """Capa na secao 1; local e ano no rodape, que os prende ao pe da pagina."""
        for chave in ('instituicao', 'faculdade', 'curso'):
            self.centro(meta[chave].upper(), negrito=True)
        for i, autor in enumerate(a.strip() for a in meta['autores'].split(';')):
            self.centro(autor.upper(), antes=48 if i == 0 else 0)
        self.titulo_capa(meta, antes=110)
        rodape = self.doc.sections[0].footer
        rodape.paragraphs[0].style = self.doc.styles['Normal']
        rodape.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
        self.inline(rodape.paragraphs[0], meta['local'].upper())
        self.centro(meta['ano'], destino=rodape)

    def folha_de_rosto(self, meta: dict[str, str]) -> None:
        """Secao propria: conta a partir de 1 (a capa nao conta) e herda o rodape da capa."""
        nova = self.doc.add_section(WD_SECTION.NEW_PAGE)
        margens(nova)
        numeracao_inicial(nova, 1)
        for autor in (a.strip() for a in meta['autores'].split(';')):
            self.centro(autor.upper())
        self.titulo_capa(meta, antes=120)
        for chave, espaco in (('natureza', 48), ('orientador', 12)):
            p = self.doc.add_paragraph(style='Normal')
            p.paragraph_format.left_indent = Cm(8)
            p.paragraph_format.space_before = Pt(espaco)
            p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            self.inline(p, meta[chave])
            for r in p.runs:
                r.font.size = Pt(10)

    def nova_secao(self, cabecalho_com_pagina: bool) -> None:
        nova = self.doc.add_section(WD_SECTION.NEW_PAGE)
        margens(nova)
        for pg in nova._sectPr.findall(qn('w:pgNumType')):  # copiado da folha de rosto: a contagem continua
            nova._sectPr.remove(pg)
        nova.footer.is_linked_to_previous = False  # sem local/ano daqui em diante
        nova.header.is_linked_to_previous = False
        cab = nova.header.paragraphs[0]
        if cabecalho_com_pagina:
            cab.alignment = WD_ALIGN_PARAGRAPH.RIGHT
            cab.style = self.doc.styles['Normal']
            campo(cab, 'PAGE', '1')
            for r in cab.runs:
                r.font.size = Pt(10)

    def sumario(self) -> None:
        p = self.doc.add_paragraph(style='Titulo sem indicativo')
        p.add_run('SUMÁRIO')
        p = self.doc.add_paragraph(style='Normal')
        campo(p, 'TOC \\o "1-3" \\h \\z', 'Abra no Word e atualize o sumário (F9).')

    # ---- secoes
    def titulo(self, nivel: int, texto: str) -> None:
        limpo = sem_marcas(texto).upper()
        if nivel == 1 and limpo in PRETEXTUAIS:
            primeiro = not self.pretextual_iniciado
            if primeiro:
                self.nova_secao(cabecalho_com_pagina=False)
                self.pretextual_iniciado = True
            p = self.doc.add_paragraph(style='Titulo sem indicativo')
            if primeiro:
                p.paragraph_format.page_break_before = False
            self.inline(p, texto)
            return
        if nivel == 1 and not self.textual_iniciado and re.match(r'^\d', limpo):
            self.nova_secao(cabecalho_com_pagina=True)
            self.textual_iniciado = True
            p = self.doc.add_paragraph(style='Heading 1')
            p.paragraph_format.page_break_before = False
            self.inline(p, texto)
            return
        p = self.doc.add_paragraph(style=f'Heading {nivel}')
        if nivel == 1 and limpo.startswith(POSTEXTUAIS):
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        self.inline(p, texto)

    def alinea(self, marcador: str, texto: str) -> None:
        p = self.doc.add_paragraph(style='Alinea')
        p.add_run(marcador + '\t')
        p.paragraph_format.tab_stops.add_tab_stop(Cm(2.0))
        self.inline(p, texto)

    def legenda(self, tipo: str, titulo: str) -> None:
        if tipo == 'Quadro':
            self.quadros += 1
            numero = self.quadros
        else:
            self.figuras += 1
            numero = self.figuras
        p = self.doc.add_paragraph(style='Legenda ABNT')
        p.paragraph_format.space_before = Pt(12)
        self.run(p, f'{tipo} {numero} — ', True, False, False)
        self.inline(p, titulo)

    def fonte(self, texto: str) -> None:
        p = self.doc.add_paragraph(style='Legenda ABNT')
        p.paragraph_format.keep_with_next = False
        p.paragraph_format.space_after = Pt(12)
        self.inline(p, texto)

    def tabela(self, tabela: Tabela, larguras: list[float] | None = None, cabecalho: bool = True, bordas: bool = True) -> None:
        linhas = ([tabela.cabecalho] if cabecalho else []) + tabela.linhas
        colunas = len(linhas[0])
        t = self.doc.add_table(rows=len(linhas), cols=colunas)
        t.style = self.doc.styles['Table Grid'] if bordas else self.doc.styles['Normal Table']
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        if larguras is None:
            larguras = [LARGURA_TEXTO_CM / colunas] * colunas
        for i, valores in enumerate(linhas):
            linha = t.rows[i]
            sem_divisao(linha)
            if i == 0 and cabecalho:
                repetir_cabecalho(linha)
            for j in range(colunas):
                celula = linha.cells[j]
                celula.width = Cm(larguras[j])
                p = celula.paragraphs[0]
                p.style = self.doc.styles['Celula']
                texto = valores[j] if j < len(valores) else ''
                self.inline(p, texto, negrito=(i == 0 and cabecalho))
        if not bordas:
            for linha in t.rows:
                for celula in linha.cells:
                    for p in celula.paragraphs:
                        p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE

    def figura(self, caminho: Path, largura_cm: float) -> None:
        if not caminho.exists():
            self.relato.erros.append(f'linha {self.linha_atual}: imagem não encontrada {caminho}')
            return
        p = self.doc.add_paragraph(style='Normal')
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.keep_with_next = True
        p.add_run().add_picture(str(caminho), width=Cm(largura_cm))

    def quebra(self) -> None:
        self.doc.add_paragraph(style='Normal').add_run().add_break(WD_BREAK.PAGE)


# --------------------------------------------------------------------------- leitura do markdown

LARGURAS = {
    'matriz': [1.5, 4.6, 2.1, 7.8],
    'evidencias': [4.2, 2.6, 7.4, 1.8],
}


def front_matter(linhas: list[str]) -> tuple[dict[str, str], int]:
    if not linhas or linhas[0].strip() != '---':
        raise SystemExit('relatorio.md precisa começar com o bloco --- de metadados')
    meta, i = {}, 1
    while linhas[i].strip() != '---':
        if ':' in linhas[i]:
            chave, valor = linhas[i].split(':', 1)
            meta[chave.strip()] = valor.strip()
        i += 1
    faltando = {'instituicao', 'faculdade', 'curso', 'autores', 'titulo', 'natureza', 'orientador', 'local', 'ano'} - meta.keys()
    if faltando:
        raise SystemExit(f'metadados faltando: {", ".join(sorted(faltando))}')
    return meta, i + 1


def montar(relato: Relato) -> Document:
    grupos, valores = ler_matriz(relato)
    indice = ler_indice(relato)
    linhas = FONTE.read_text(encoding='utf-8').splitlines()
    meta, i = front_matter(linhas)
    esc = Escritor(valores, relato)
    for n, valor in enumerate(meta.values()):
        esc.linha_atual = n + 2
        for pend in PENDENTE_RE.findall(valor):
            relato.pendencias.append((n + 2, pend))
    pend_meta = len(relato.pendencias)
    esc.capa(meta)
    esc.folha_de_rosto(meta)
    # os PENDENTE da capa/folha de rosto ja foram contados acima
    del relato.pendencias[pend_meta:]

    legenda_pendente: tuple[str, str] | None = None
    larguras_quadro: list[float] | None = None
    paragrafo: list[str] = []

    def fechar_paragrafo() -> None:
        if paragrafo:
            esc.paragrafo(' '.join(s.strip() for s in paragrafo))
            paragrafo.clear()

    while i < len(linhas):
        linha = linhas[i]
        esc.linha_atual = i + 1
        bruto = linha.strip()

        if bruto.startswith('<!--') and bruto.endswith('-->'):
            fechar_paragrafo()
            diretiva = bruto[4:-3].strip()
            if diretiva == 'sumario':
                esc.sumario()
            elif diretiva == 'quebra':
                esc.quebra()
            elif diretiva.startswith('matriz'):
                for secao, tabela in grupos:
                    esc.legenda('Quadro', f'{secao} do edital e evidências')
                    esc.tabela(tabela, LARGURAS['matriz'])
                    esc.fonte(f'Fonte: `docs/entrega/matriz-requisitos.md`, revista em {valores["matriz.revisao"]} '
                              f'e atualizada em {valores["matriz.atualizacao"]}.')
            elif diretiva == 'evidencias' and indice is not None:
                esc.legenda('Quadro', 'Índice de evidências por card')
                esc.tabela(indice, LARGURAS['evidencias'])
                esc.fonte('Fonte: `docs/entrega/README.md` e `docs/entrega/evidencias/`.')
            # comentarios comuns sao ignorados
            i += 1
            continue

        if bruto.startswith('```'):
            fechar_paragrafo()
            i += 1
            while i < len(linhas) and not linhas[i].strip().startswith('```'):
                p = esc.doc.add_paragraph(style='Codigo')
                p.add_run(linhas[i])
                i += 1
            i += 1
            continue

        cab = re.match(r'^(#{1,3}) (.+)$', linha)
        if cab:
            fechar_paragrafo()
            esc.titulo(len(cab.group(1)), cab.group(2).strip())
            i += 1
            continue

        leg = re.match(r'^(Quadro|Figura): (.+?)(?:\s*\{larguras=([\d.,\s]+)\})?$', bruto)
        if leg:
            fechar_paragrafo()
            legenda_pendente = (leg.group(1), leg.group(2))
            larguras_quadro = [float(x) for x in leg.group(3).split(',')] if leg.group(3) else None
            esc.legenda(*legenda_pendente)
            i += 1
            continue

        img = re.match(r'^!\[[^\]]*\]\(([^)]+)\)(\{largura=([\d.]+)\})?$', bruto)
        if img:
            fechar_paragrafo()
            esc.figura((AQUI / img.group(1)).resolve(), float(img.group(3) or 12))
            i += 1
            continue

        if bruto.startswith('Fonte:'):
            fechar_paragrafo()
            esc.fonte(bruto)
            legenda_pendente = None
            i += 1
            continue

        if bruto.startswith('|'):
            fechar_paragrafo()
            bloco = []
            while i < len(linhas) and linhas[i].strip().startswith('|'):
                bloco.append(linhas[i])
                i += 1
            if legenda_pendente is None:
                # sem legenda "Quadro:" = lista de duas colunas (siglas), sem cabecalho nem bordas
                linhas_lista = [celulas(b) for b in bloco if not re.match(r'^\|[\s:|-]+\|$', b.strip())]
                esc.tabela(Tabela([], linhas_lista), [3.0, 13.0], cabecalho=False, bordas=False)
            else:
                tabela = tabelas_markdown('\n'.join(bloco))[0][1]
                if larguras_quadro and len(larguras_quadro) != len(tabela.cabecalho):
                    relato.erros.append(f'linha {i}: larguras do quadro não batem com o número de colunas')
                    larguras_quadro = None
                esc.tabela(tabela, larguras_quadro)
            continue

        ali = re.match(r'^(-|\d+\.|[a-z]\)) (.+)$', bruto)
        if ali:
            fechar_paragrafo()
            marcador = ali.group(1)
            if marcador == '-':
                marcador = '–'
            elif marcador.endswith('.'):
                marcador = marcador[:-1] + ')'
            texto = ali.group(2)
            while i + 1 < len(linhas) and linhas[i + 1].startswith('  ') and linhas[i + 1].strip():
                i += 1
                texto += ' ' + linhas[i].strip()
            esc.alinea(marcador, texto)
            i += 1
            continue

        if not bruto:
            fechar_paragrafo()
            i += 1
            continue

        paragrafo.append(linha)
        i += 1

    fechar_paragrafo()
    aplicar_referencias(esc.doc)
    return esc.doc


def aplicar_referencias(doc: Document) -> None:
    """Paragrafos apos o titulo REFERÊNCIAS: alinhados a esquerda, espaco simples."""
    dentro = False
    for p in doc.paragraphs:
        if p.style.name.startswith('Heading 1'):
            dentro = sem_marcas(p.text).upper() == 'REFERÊNCIAS'
            continue
        if dentro and p.style.name == 'Corpo':
            p.style = doc.styles['Referencia']


# --------------------------------------------------------------------------- pdf

def exportar_pdf(docx: Path, pdf: Path) -> str:
    word = shutil.which('powershell') or shutil.which('powershell.exe')
    if word:
        script = (
            "$ErrorActionPreference='Stop';"
            "$w=New-Object -ComObject Word.Application;$w.Visible=$false;$w.DisplayAlerts=0;"
            f"try{{$d=$w.Documents.Open('{docx}',$false,$false);"
            "foreach($t in $d.TablesOfContents){$t.Update()};$null=$d.Fields.Update();"
            "foreach($t in $d.TablesOfContents){$t.Update()};"
            "$d.Save();"
            f"$d.ExportAsFixedFormat('{pdf}',17,$false,0,0,0,0,0,$true,$true,1,$true,$true,$false);"
            "$d.Close(0)}finally{$w.Quit()}"
        )
        r = subprocess.run([word, '-NoProfile', '-NonInteractive', '-Command', script], capture_output=True, text=True)
        if r.returncode == 0 and pdf.exists():
            return 'Word (sumário e números de página atualizados)'
        print('aviso: Word indisponível ou falhou:', (r.stderr or r.stdout).strip()[:400], file=sys.stderr)
    soffice = shutil.which('soffice') or next((str(p) for p in (
        Path('C:/Program Files/LibreOffice/program/soffice.exe'),
        Path('/usr/bin/soffice'),
        Path('/Applications/LibreOffice.app/Contents/MacOS/soffice')) if p.exists()), None)
    if soffice:
        subprocess.run([soffice, '--headless', '--convert-to', 'pdf', '--outdir', str(pdf.parent), str(docx)], check=True,
                       capture_output=True)
        return 'LibreOffice (ATENÇÃO: o sumário não é atualizado; abra o DOCX no Word e atualize antes da entrega)'
    raise SystemExit('sem Word nem LibreOffice para gerar o PDF; use --so-docx')


def main() -> None:
    args = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    args.add_argument('--final', action='store_true', help='recusa pendências e grava relatorio-final.pdf')
    args.add_argument('--so-docx', action='store_true', help='gera só o DOCX')
    opcoes = args.parse_args()

    relato = Relato()
    doc = montar(relato)
    SAIDA.mkdir(exist_ok=True)
    docx = SAIDA / 'relatorio.docx'
    doc.core_properties.title = 'Sistema integrado de controle de acesso'
    doc.core_properties.author = 'ErrorSquad'
    doc.core_properties.language = 'pt-BR'
    doc.save(docx)
    print(f'DOCX: {docx}')

    for erro in relato.erros:
        print(f'ERRO: {erro}')
    for linha, pend in relato.pendencias:
        print(f'PENDENTE (relatorio.md:{linha}): {pend}')
    print(f'{len(relato.pendencias)} pendência(s), {len(relato.erros)} erro(s).')

    if opcoes.final and (relato.pendencias or relato.erros):
        raise SystemExit('--final recusado: resolva as pendências e os erros acima.')
    if opcoes.so_docx:
        return
    pdf = SAIDA / 'relatorio.pdf'
    if pdf.exists():
        pdf.unlink()
    via = exportar_pdf(docx, pdf)
    print(f'PDF: {pdf} — via {via}')
    if opcoes.final:
        shutil.copyfile(pdf, FINAL)
        print(f'versão final: {FINAL}')


if __name__ == '__main__':
    main()
