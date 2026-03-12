# Notas metodológicas — apoio à redistribuição e desigualdade (Latinobarómetro)

## Escopo
- Janela temporal alvo: 2000–2024.
- Unidade analítica final principal: país-ano.
- Unidade intermediária opcional: microdados harmonizados por onda.

## Decisões de harmonização
1. **Não assumir estabilidade de códigos**: a harmonização é guiada por `docs/variable_crosswalk.csv`.
2. **Pontos já ancorados (template inicial)**:
   - 2023/2024: justiça distributiva = `P17ST`; desigualdade aceitável = `P61ST`.
   - 2020: justiça distributiva = `Q19ST.A` (a confirmar no questionário oficial).
3. **Demais anos (2000–2022, exceto 2020)**:
   - inicialmente vazios no template e dependentes do dicionário integrado 1981–2024 + questionários da onda.

## Missing values
Regras implementadas no pipeline (passíveis de ajuste por onda após inspeção da documentação):
- `DK / Don’t know`, `No answer`, `Not applicable` são convertidos para `NA`.
- Códigos numéricos especiais recodificados para `NA`: `8, 9, 88, 89, 98, 99, 888, 999`.

## Pesos amostrais
- O script busca automaticamente nomes comuns de peso (`weight`, `wt`, `pondera`, `factor`, `wgt`, `peso`, `fexp`).
- Se nenhum peso é encontrado com segurança na onda, a agregação dessa onda é não ponderada e o fato é registrado nas tabelas de cobertura.

## Riscos de comparabilidade temporal
- Mudanças no wording da pergunta entre ondas.
- Mudanças na escala de resposta (número de categorias e direção semântica).
- Mudanças de universo (população-alvo, filtros, subamostras).
- Mudanças de desenho amostral e/ou variável de peso.
- Ondas sem observação da pergunta ou com codificação ambígua no dicionário.

## Checklist recomendado antes da análise substantiva final
1. Validar o crosswalk ano a ano com o dicionário integrado e questionário da onda.
2. Verificar frequências das respostas em anos-chave (ex.: 2000, 2010, 2020, 2023/2024).
3. Confirmar direção ordinal (valores maiores = maior crítica à desigualdade).
4. Auditar tratamento de missing por onda.
5. Revisar cobertura de países por ano.
