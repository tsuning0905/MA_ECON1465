# MA_ECON1465 — Week 7 (RCT track: propensity score matching and IPW)

ECO1465 (Applied Causal Machine Learning) project on Balán, Bergeron, Tourek & Weigel (2022),
*Local Elites as State Capacity*, AER 112(3). Research question: when neighbourhood chiefs (Local)
instead of state agents (Central) collect the property tax, do exemptions rise, and are the extra
exemptions justified or discretionary favours?

Week 7 runs propensity score matching and IPW on the **biased sample** built in Week 6
(Recipe B, α = 0, γ = 1, S = owner age, seed 1465) and compares them with the experimental benchmark.

## How to reproduce everything (one command)

```bash
git clone https://github.com/tsuning0905/MA_ECON1465.git
cd MA_ECON1465/02_data_intermediate/Week7
pip install -r requirements.txt          # Python 3.11+; Graphviz `dot` needed for the Week 6 DAG figure
python 00_master/00_master.py            # ~1.5 minutes; no paths to edit
cd 03_output/week7 && pdflatex report_week7.tex   # optional: rebuild the report PDF
```
The raw data folder `0_RawData/` is found automatically in this folder or any parent folder
(in the repo: `MA_ECON1465/0_RawData/`). It is only read, never written.
On Colab: `!git clone ...`, `%cd MA_ECON1465/02_data_intermediate/Week7`, `!pip install -r requirements.txt`, `!python 00_master/00_master.py`.

## Folder structure and run order

| Step | File | Reads | Writes |
|---|---|---|---|
| 0 | `00_master/00_master.py` | — | runs steps 1–3 in order, sets the project root |
| 1 | `01_preanalysis/01_preanalysis.py` | `0_RawData/**` (read only) | `data_intermediate/analysis_data.csv.gz`, `final_exemption.csv.gz`, `final_endline.csv.gz` |
| 2 | `02_analysis/02_week6_benchmark.py` | `data_intermediate/final_exemption.csv.gz` | `03_output/week6/*`, `data_intermediate/week6_biased_sample.csv.gz` |
| 3 | `02_analysis/02_week7_matching_ipw.py` | `final_exemption.csv.gz`, `week6_biased_sample.csv.gz` | `03_output/week7/*` |

- `data_intermediate/` — all generated data (`raw_staging/` holds links to raw files and is rebuilt by step 1, not committed).
- `03_output/week6/`, `03_output/week7/` — final tables (`.tex`, `.csv`) and figures (`.pdf`, `.png`).

## Outputs → Week 7 report

| Output (`03_output/week7/`) | Week 7 report |
|---|---|
| `figure1_positivity.{pdf,png}` | Figure 1: propensity score overlap, Local vs Central, raw and IPW-weighted |
| `table1_balance.{tex,csv}` | Table 1: SMD before / after IPW and matching |
| `table2_estimates.{tex,csv}` | Table 2: benchmark, naive, PS matching (ATE, ATT), IPW (HT, Hajek), DoWhy |
| `table3_gamma_check.{tex,csv}` | Table 3: logit of D on standardised S vs γ = 1 |
| `figure2_bootstrap_ipw.{pdf,png}`, `bootstrap_ipw_draws.csv` | Figure 2: bootstrap distribution of the IPW ATE |
| `numbers.json` | every number quoted in the text |
| `report_week7.tex` / `.pdf` | the report |


## Methods (step 3)
- Propensity score: logit of `local` on `owner_age`, `owner_female`, `main_tribe`, `job_gov`.
- Matching: 1 nearest neighbour on ê with replacement, tied twins averaged; Abadie–Imbens (2006) SE.
  No bootstrap for matching (not valid, Abadie & Imbens 2008).
- IPW: Horvitz–Thompson (divide by N, DoWhy `ips_weight`) and normalised (Hajek).
- Bootstrap: 500 draws resampling neighbourhoods `a7`, propensity score re-fit in each draw.

## Reproducibility notes
- Seed **1465** for the biased sample, all bootstraps and DoWhy refuters.
- Package versions pinned in `requirements.txt` (pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, scipy 1.18.1,
  matplotlib 3.11.2, dowhy 0.14, networkx 3.7, scikit-learn 1.9.1).
