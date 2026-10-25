# MA_ECON1465

ECO1465 (Applied Causal Machine Learning) project on Balán, Bergeron, Tourek & Weigel (2022),
*Local Elites as State Capacity*, AER 112(3). Research question: when neighbourhood chiefs (Local)
instead of state agents (Central) collect the property tax, do exemptions rise, and are the extra
exemptions justified or discretionary favours?

## How to reproduce everything (one command)

```bash
git clone https://github.com/tsuning0905/MA_ECON1465.git
cd MA_ECON1465
pip install -r requirements.txt          # Python 3.11+; also needs Graphviz `dot` for the DAG figure
python 00_master/00_master.py            # ~2 minutes; no paths to edit
```
On Colab: `!git clone ...`, `%cd MA_ECON1465`, `!pip install -r requirements.txt`, `!python 00_master/00_master.py`.

## Folder structure and run order

| Step | File | Reads | Writes |
|---|---|---|---|
| 0 | `00_master/00_master.py` | — | runs steps 1–2 in order, sets the repo root |
| 1 | `01_preanalysis/01_preanalysis.py` | `0_RawData/**` (read only) | `data_intermediate/analysis_data.csv.gz`, `final_exemption.csv.gz` (property level), `final_endline.csv.gz` (endline household level) |
| 2 | `02_analysis/02_week6_benchmark.py` | `data_intermediate/final_exemption.csv.gz` | `03_output/week6/*`, `data_intermediate/week6_biased_sample.csv.gz` |

- `0_RawData/` — raw de-identified data, never edited (see `0_RawData/README.md` and `0_RawData/codebook/`).
  `0_RawData/Data_Construction` is the Python port of `Dofiles/2_Data_Construction.do`; step 1 runs it.
- `data_intermediate/` — all generated data. `raw_staging/` (links to raw files + unzipped midline) is rebuilt by step 1 and not committed.
- `03_output/` — final tables (`.tex`, `.csv`) and figures (`.pdf`, `.png`).
- `Dofiles/` — the authors' original Stata replication code (reference only).

## Outputs → report

| Output (`03_output/week6/`) | Week 6 report |
|---|---|
| `table1_benchmark.{tex,csv}` | Table 1: $\hat\tau^{RCT}$, $\hat\tau^{naive}$, DoWhy |
| `table2_exemption_reasons.{tex,csv}` | Table 2: exemptions by reason, discretionary exemptions |
| `table3_balance.{tex,csv}` | Table 3: balance, full vs biased sample |
| `figure1_overlap.{pdf,png}` | Figure 1: overlap of S (owner age) |
| `figure2_dag2.{pdf,png}` | Figure 2: DAG 2 |
| `dowhy_log.txt` | DoWhy output (Sections 4.2–4.4) |
| `numbers.json` | every number quoted in the text |
| `report_week6.tex` / `.pdf` | the report (compile with `pdflatex` in that folder) |

## Key variables (`final_exemption.csv.gz`)

`local` (D: 1 = Local, 0 = Central; `tmt`==2 vs 1) · `exempt` (Y: collector registered property as exempt) ·
`exempt_elderly`, `exempt_widow`, `exempt_otherreason` (exempt by stated reason) ·
`exempt_discretionary` (reason contradicts owner traits: "elderly" but owner < 55, or "widow" but owner male) ·
`enum_disagrees_exempt` (independent enumerator disagrees) · `owner_age` (S), `owner_female`, `main_tribe`, `job_gov` · `a7` neighbourhood (cluster) · `stratum`.

## Reproducibility notes
- Seed **1465** for the biased sample, the cluster bootstrap (500 draws, resampling neighbourhoods) and DoWhy refuters.
- Package versions pinned in `requirements.txt` (pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, matplotlib 3.11.2, dowhy 0.14, networkx 3.7).
- Standard errors are clustered by neighbourhood `a7`, the unit of randomisation.
