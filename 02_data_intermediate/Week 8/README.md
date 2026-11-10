# MA_ECON1465 — Week 8 (RCT track: S-, T-, X-learners on the full experimental sample)

ECO1465 project on Balán, Bergeron, Tourek & Weigel (2022), *Local Elites as State Capacity*, AER 112(3).
Week 8 estimates the effect of Local (chief) vs Central tax collection on exemptions with three meta
learners, on the **full experimental sample** (5,645 properties, 202 neighbourhoods). The Week 6 biased
sample is not used.

  Y = `exempt` · T = `local` · X = `owner_age`, `owner_female`, `main_tribe`, `job_gov`

## How to reproduce everything (one command)

```bash
git clone https://github.com/tsuning0905/MA_ECON1465.git
cd MA_ECON1465/02_data_intermediate/Week8
pip install -r requirements.txt
python 00_master/00_master.py            # ~2.5 minutes; no paths to edit
cd 03_output/week8 && pdflatex report_week8.tex   # optional: rebuild the report PDF
```
`0_RawData/` is found automatically in this folder or any parent folder and is only read, never written.
If `pip install econml` is slow to resolve, `pip install --no-deps econml==0.17.0 sparse` is enough for the meta learners.

## Folder structure and run order

| Step | File | Reads | Writes |
|---|---|---|---|
| 0 | `00_master/00_master.py` | — | runs steps 1–2 in order, sets the project root |
| 1 | `01_preanalysis/01_preanalysis.py` | `0_RawData/**` (read only) | `data_intermediate/final_exemption.csv.gz`, … |
| 2 | `02_analysis/02_week8_metalearners.py` | `data_intermediate/final_exemption.csv.gz` | `03_output/week8/*`, `data_intermediate/week8_cate.csv.gz` |

## Outputs → Week 8 report

| Output (`03_output/week8/`) | Week 8 report |
|---|---|
| `table0_gbr_cv.csv` | Step 1: grouped 5-fold CV for the GBR base learner |
| `table1_ate.{tex,csv}`, `bootstrap_ate_draws.csv` | Table 1: ATE (bootstrap SE/CI) and CATE distribution per learner |
| `figure1_cate_hist.{pdf,png}` | Figure 1: CATE histograms (S, T, X) |
| `figure2_cate_by_age.{pdf,png,csv}` | Figure 2: mean CATE by owner age vs experimental estimate per bin |
| `table2_subgroups.{tex,csv}` | Table 2: mean CATE by subgroup vs experimental subgroup ATE |
| `numbers.json` | every number quoted in the text |
| `report_week8.tex` / `.pdf` | the report |

## Methods (step 2)
- Base learner: `GradientBoostingRegressor` (lr 0.05; depth, trees, min leaf picked by GroupKFold CV by neighbourhood).
- `econml.metalearners.SLearner / TLearner / XLearner`; X-learner uses the known design propensity (share Local).
- ATE = mean CATE; bootstrap 200 draws resampling neighbourhoods `a7`, all learners refit in each draw.

## Reproducibility notes
- Seed **1465** for GBR, CV folds and bootstrap. Versions pinned in `requirements.txt`.
