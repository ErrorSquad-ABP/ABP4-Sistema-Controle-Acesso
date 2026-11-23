# Relatório ABNT — US-36

Relatório final do projeto no formato ABNT. O texto fica em [`relatorio.md`](relatorio.md) e o [`gerar.py`](gerar.py) monta o DOCX e o PDF com capa, folha de rosto, resumo, abstract, lista de siglas, sumário, texto, referências e apêndices.

A matriz de requisitos ([`../matriz-requisitos.md`](../matriz-requisitos.md)) e o índice de evidências ([`../README.md`](../README.md)) **não são copiados**: o gerador os lê na hora e monta os Apêndices A e B e as contagens do texto. Quem atualiza a matriz atualiza o relatório na próxima geração.

## Como gerar

```bash
cd docs/entrega/relatorio
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # Linux/macOS: .venv/bin/python
.venv/Scripts/python gerar.py
```

Saída em `build/` (ignorada pelo git): `relatorio.docx` e `relatorio.pdf`. O PDF sai pelo **Word** (Windows), que atualiza o sumário e os números de página e gera os marcadores do PDF. Sem Word, o script usa o LibreOffice, que **não** atualiza o sumário: nesse caso, abra o DOCX no Word e atualize o sumário antes de exportar.

| Opção | Efeito |
|---|---|
| (nenhuma) | rascunho em `build/`, com as pendências destacadas em amarelo |
| `--so-docx` | gera só o DOCX |
| `--final` | recusa a geração se houver `[PENDENTE: ...]` ou erro de validação; se passar, grava `relatorio-final.pdf` nesta pasta, que é o arquivo versionado da entrega |

## O que o gerador valida

- Toda linha da matriz tem status conhecido e uma evidência ou lacuna declarada.
- Todo requisito **Atendido** cita algo verificável: arquivo entre crases, PR (`#NN`), link ou card (`US-XX`/`DT-XX`).
- Os links relativos da matriz e do índice de evidências apontam para arquivos existentes.
- Placeholders `{{...}}` desconhecidos, imagens ausentes e quadros com larguras erradas viram erro.

Na primeira execução, nove linhas da matriz marcadas como Atendido (RNF10, RNF12, RP03 a RP06 e RP08 a RP10) não apontavam para nenhum arquivo, e elas foram completadas com os workflows, contratos e pastas que as comprovam.

## Convenções do `relatorio.md`

| Escrita | Resultado |
|---|---|
| bloco `---` no início | metadados da capa e da folha de rosto (`autores` separados por `;`) |
| `# RESUMO`, `# ABSTRACT`, `# LISTA DE ABREVIATURAS E SIGLAS` | elementos pré-textuais, centralizados e fora do sumário |
| `<!-- sumario -->` | campo de sumário (níveis 1 a 3) |
| `# 1 TÍTULO`, `## 1.1 Título`, `### 1.1.1 Título` | seções numeradas; o primeiro `# 1` inicia o texto e a numeração visível das páginas |
| `# REFERÊNCIAS`, `# APÊNDICE A — ...` | elementos pós-textuais, centralizados e no sumário |
| `- item` / `1. passo` | alínea (`–`) / passo numerado (`1)`) com recuo |
| `Quadro: título {larguras=3,6,7}` + tabela + `Fonte: ...` | quadro numerado, larguras em cm (somam 16) |
| `Figura: título` + `![](figuras/x.png){largura=14}` + `Fonte: ...` | figura numerada; imagens em `figuras/` |
| tabela sem `Quadro:` antes | lista de duas colunas sem bordas (siglas) |
| `<!-- matriz -->` / `<!-- evidencias -->` | Apêndice A / Apêndice B lidos dos arquivos de origem |
| `{{RF.atendido}}`, `{{RNF.lista.parcial}}`, `{{total}}`... | contagens da matriz (`RF`, `RNF`, `RP` ou `total`; `atendido`, `parcial`, `nao_atendido`, `nao_comprovado`; `.lista.` devolve os IDs) |
| `[PENDENTE: ...]` | destaque amarelo; bloqueia o `--final` |

## Formatação aplicada

A4; margens de 3 cm (superior e esquerda) e 2 cm (inferior e direita); Arial 12 no texto e 10 em quadros, legendas e natureza do trabalho; espaçamento 1,5 e recuo de 1,25 cm no texto; espaço simples nas referências, separadas por uma linha em branco. Seções primárias em caixa alta e negrito, sempre em página nova; secundárias em negrito. Páginas contadas a partir da folha de rosto e numeradas a partir da Introdução, no canto superior direito. Citações no sistema autor-data, com o autor em maiúsculas e minúsculas, como na NBR 10520:2023. Referências no formato da NBR 6023:2018.

## Pendências do rascunho atual

O rascunho foi gerado da `main` em `0fb1292` (23/11/2026, já com o PR #73) e tem 11 marcadores `[PENDENTE: ...]`. A lista sai no terminal a cada geração. Os principais são:

1. Resultado da Sprint 3 e da retrospectiva, depois da Review 3 de 25/11.
2. Resultados da US-34 (hardware real) e figura de arquitetura da US-35.
3. Regenerar depois de integrar a US-33, que muda o RNF02 na matriz, e as demais histórias da S3.
4. Números do CI no commit final.
5. Nomes completos dos autores, orientador ou avaliador na folha de rosto e título exato do edital.

## Conferência antes da versão final

- [ ] PRs de que o relatório depende integrados (US-33, US-34, US-35 e US-38) e matriz revisada depois deles.
- [ ] `python gerar.py --final` passa sem pendência nem erro.
- [ ] **Fontes:** Arial em todo o PDF (no Acrobat ou no leitor do navegador, em Propriedades → Fontes, ou `pdffonts`); nenhuma fonte substituta.
- [ ] **Sumário:** todos os títulos numerados, as referências e os apêndices aparecem, com as páginas iguais às do texto; os elementos pré-textuais ficam fora.
- [ ] **Referências:** toda citação do texto tem referência e toda referência é citada; ordem alfabética; links abertos e "Acesso em" na data da conferência.
- [ ] Capa e folha de rosto com nomes completos e o nome do professor conferidos.
- [ ] Nenhum dado sensível: senha, token, UID completo, `.env` ou URL com credencial.
- [ ] Revisão por par registrada abaixo.

## Registro da revisão por par

Uma pessoa que **não** escreveu a seção revisa o PDF gerado e anota aqui o commit revisado, o que encontrou e o que foi corrigido. Depois da revisão, só correções apontadas por ela entram antes do `--final`.

| Data | Revisor(a) | Commit do PDF | Seções revisadas | Achados | Resolvido em |
|---|---|---|---|---|---|
| | | | | | |
