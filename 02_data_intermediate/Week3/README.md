# MA_ECON1465

ECO1465 (Applied Causal Machine Learning) project built on Balán, Bergeron, Tourek & Weigel (2022),
*Local Elites as State Capacity*, AER 112(3). Raw data guide: [`0_RawData/README.md`](0_RawData/README.md).

**Research question.** Does having local chiefs (Local, `tmt==2`) instead of central state agents
(Central, `tmt==1`) collect the property tax change how often properties are exempted, and for which
households is the effect larger (e.g. co-ethnics of the collector)? Treatment is randomized by
neighbourhood, so the Local–Central difference is causal (no IV needed).

## How to reproduce everything

```bash
pip install pandas numpy statsmodels scikit-learn matplotlib
python 00_master/00_master.py
```

Tested with Python 3.11, pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, scikit-learn 1.9.1,
matplotlib 3.11.2. Paths are relative to the repo root, so nothing needs editing. Random seed: 1465.

## Folder structure

| Folder | What it holds |
|---|---|
| `0_RawData/` | raw de-identified data, **never overwritten** |
| `00_master/00_master.py` | runs every script below in order |
| `01_preanalysis/01_preanalysis_week3.py` | reads raw data, cleans, builds variables, saves the analysis dataset |
| `data_intermediate/` | all generated data (`week3_exemption_analysis.csv`) |
| `02_analysis/02_analysis_week3.py` | produces every table and figure, sectioned in report order |
| `03_output/week3/` | final tables (.tex/.csv), figures (.pdf/.png) and the compiled report |
| `Dofiles/` | original Stata replication code (reference only) |

## Week 3 outputs (report order)

| Report item | File | Script section |
|---|---|---|
| Table 1 – OLS | `03_output/week3/Table1_OLS_exemption.tex` / `.csv` | `02_analysis_week3.py` › Table 1 |
| Figure 1 – Ridge path + CV | `03_output/week3/Figure1_Ridge.pdf` / `.png` | › Figures 1–2 |
| Figure 2 – Lasso path + CV | `03_output/week3/Figure2_Lasso.pdf` / `.png` | › Figures 1–2 |
| Coefficients at λ_min / λ_1se | `03_output/week3/penalized_coefficients.csv` | › Figures 1–2 |
| Report | `03_output/week3/report_week3.tex` → `report_week3.pdf` (compile with `pdflatex`) | — |

## Week 3 sample and variables

- Properties registered in Central or Local neighbourhoods (`registration_noPII.csv`, pilot excluded)
  with a recorded exemption decision, matched to the 2017 baseline survey: 1,163 properties, 172 neighbourhoods.
- `exempt` (collector exempted the property), `exempt_senior` / `exempt_widow` (by stated reason),
  `unjust_senior` (exempted as a senior but owner under 55 at baseline; legal age from the paper, Sec. I).
- `coethnic`: owner's tribe equals the chief's (Local) or either state agent's (Central) tribe, as in `Dofiles/Tables_Figures/TableA9.do`.
- Note: the old folder `0.2data_intermediate ` (with a trailing space) is no longer used; generated data go to `data_intermediate/`.
