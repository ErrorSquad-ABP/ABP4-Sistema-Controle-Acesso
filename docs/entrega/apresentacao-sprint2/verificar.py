import json
import re
from pathlib import Path

import pymupdf
from pptx import Presentation
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
pdf = pymupdf.open(HERE / 'ABP4DSM-Sprint2-Apresentacao.pdf')
assert len(pdf) == 12
for page in pdf:
    assert abs(page.rect.width / page.rect.height - 16 / 9) < .001
    assert len(page.get_text().strip()) > 60
    assert not re.search(r'TODO|TBD|COLE_O_LINK', page.get_text())

prs = Presentation(HERE / 'ABP4DSM-Sprint2-Apresentacao.pptx')
assert len(prs.slides) == 12
assert abs(prs.slide_width / prs.slide_height - 16 / 9) < .001
for i, slide in enumerate(prs.slides, 1):
    assert slide.has_notes_slide
    assert len(slide.notes_slide.notes_text_frame.text) > 80
    assert any(shape.has_text_frame and shape.text.strip() for shape in slide.shapes)
    for shape in slide.shapes:
        assert shape.left >= 0 and shape.top >= 0, (i, shape.name)
        assert shape.left + shape.width <= prs.slide_width + 10, (i, shape.name)
        assert shape.top + shape.height <= prs.slide_height + 10, (i, shape.name)

forbidden = {'password', 'secret', 'accessToken', 'refreshToken', 'qrToken', 'uid', 'valueHash', 'cookie', 'authorization'}

def check_fields(value):
    if isinstance(value, dict):
        assert not forbidden.intersection(value), forbidden.intersection(value)
        for child in value.values():
            check_fields(child)
    elif isinstance(value, list):
        for child in value:
            check_fields(child)

evidence = json.loads((HERE / 'capturas/execucao-local.json').read_text(encoding='utf-8'))
check_fields(evidence)
assert evidence['commit'] == 'a0625d7'
assert evidence['health']['database'] == 'ok'
assert {e['decision'] for e in evidence['events']} == {'GRANTED', 'DENIED'}
assert {e['method'] for e in evidence['events']} == {'NFC', 'QR'}
assert any(e['reason'] == 'OUT_OF_RANGE' for e in evidence['events'])
assert any(e['reason'] == 'INVALID_CREDENTIAL' for e in evidence['events'])
assert all(c['ackStatus'] == 'executed' for c in evidence['commands'])
for message in evidence['trace']:
    if message['topic'].endswith(('/commands', '/acks')):
        assert message['qos'] == 1 and not message['retain']

idem = json.loads((HERE / 'capturas/idempotencia.json').read_text(encoding='utf-8'))
check_fields(idem)
assert idem['afterFirstRequest'] == idem['before'] + 1
assert idem['afterSameRequestId'] == idem['afterFirstRequest']
assert idem['sameEvent'] is True
assert idem['firstDecision'] == idem['retryDecision'] == 'GRANTED'

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width':1600,'height':900})
    page.goto((HERE / 'apresentacao.html').as_uri())
    page.evaluate('document.fonts.ready')
    assert page.locator('section').count() == 12
    assert page.evaluate('Array.from(document.images).every(i=>i.complete&&i.naturalWidth>0)')
    overflows = page.evaluate('''() => [...document.querySelectorAll('section')].flatMap((s,i)=>
      [...s.querySelectorAll('div')].filter(e=>e.textContent.trim()).flatMap(e=>{
        const range=document.createRange();range.selectNodeContents(e);
        const a=range.getBoundingClientRect(),b=e.getBoundingClientRect();
        return a.bottom>b.bottom+2||a.right>b.right+2?[{slide:i+1,text:e.textContent}]:[];
      }))''')
    assert not overflows, overflows
    browser.close()

print('OK: 12 slides/PDF, 16:9, notas, formas, HTML sem overflow e evidencias sanitizadas consistentes.')
