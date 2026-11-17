# MA_ECON1465 — Week 9 (RCT track: doubly robust estimation)

ECO1465 (Applied Causal Machine Learning) project on Balán, Bergeron, Tourek & Weigel (2022),
*Local Elites as State Capacity*, AER 112(3). Research question: when neighbourhood chiefs (Local)
instead of state agents (Central) collect the property tax, do exemptions rise, and are the extra
exemptions justified or discretionary favours?

Week 9 runs doubly robust (AIPW) learners from `econml.dr` on the **biased sample** built in Week 6
(Recipe B, α = 0, γ = 1, S = owner age, seed 1465), with S in the covariates and with S removed,
and once on the **full experimental sample**. Estimates are compared with the experimental
benchmark, the naive estimate and the Week 7 IPW / matching estimates.

  Y = `exempt` · D = `local` · S = `owner_age` · X = `owner_female`, `main_tribe`, `job_gov`

## How to reproduce everything (one command)

```bash
git clone https://github.com/tsuning0905/MA_ECON1465.git
cd MA_ECON1465/02_data_intermediate/Week9
pip install -r requirements.txt          # Python 3.11+; Graphviz `dot` needed for the Week 6 DAG figure
python 00_master/00_master.py            # ~25 min on 2 cores (the Week 9 bootstrap refits 11 models x 200 draws)
cd 03_output/week9 && pdflatex report_week9.tex   # optional: rebuild the report PDF
```
- `0_RawData/` is found automatically in this folder or any parent folder (in the repo: `MA_ECON1465/0_RawData/`). It is only read, never written.
- Quick test run: `ECO1465_NBOOT=20 python 00_master/00_master.py` (point estimates unchanged, CIs rough).
- `ECO1465_JOBS` sets the number of parallel workers (default: all cores).

## Folder structure and run order

| Step | File | Reads | Writes |
|---|---|---|---|
| 0 | `00_master/00_master.py` | — | runs steps 1–4 in order, sets the project root |
| 1 | `01_preanalysis/01_preanalysis.py` | `0_RawData/**` (read only) | `data_intermediate/analysis_data.csv.gz`, `final_exemption.csv.gz`, `final_endline.csv.gz` |
| 2 | `02_analysis/02_week6_benchmark.py` | `data_intermediate/final_exemption.csv.gz` | `03_output/week6/*`, `data_intermediate/week6_biased_sample.csv.gz` |
| 3 | `02_analysis/02_week7_matching_ipw.py` | `final_exemption.csv.gz`, `week6_biased_sample.csv.gz` | `03_output/week7/*` |
| 4 | `02_analysis/02_week9_doubly_robust.py` | `final_exemption.csv.gz`, `week6_biased_sample.csv.gz`, `03_output/week7/numbers.json` | `03_output/week9/*` |

Steps 1–3 are unchanged copies of the Week 7 code; they rebuild the identical biased sample (2,740 properties)
and the Week 7 estimates that Week 9 is compared against.

## Outputs → Week 9 report

| Output (`03_output/week9/`) | Week 9 report |
|---|---|
| `table1_nuisance_cv.{tex,csv}` | Step 1, Table 1: grouped 5-fold CV for the outcome and propensity models |
| `figure1_overlap.{pdf,png}` | Step 2, Figure 1: cross-fitted propensity scores, S included vs S removed |
| `table2_dr_estimates.{tex,csv}` | Steps 2–3, Table 2: five DR learners, S included vs S removed, bootstrap SE / CI |
| `table3_comparison.{tex,csv}` | Step 4, Table 3: DR vs τ̂_RCT, τ̂_naive, Week 7 IPW and matching; Part 2 full-sample DR |
| `figure2_estimates.{pdf,png}` | Step 4, Figure 2: all estimates with 95% CIs |
| `bootstrap_dr_draws.csv` | all 200 bootstrap draws for every learner / specification |
| `numbers.json` | every number quoted in the text |
| `report_week9.tex` / `.pdf` | the report |

## Methods (step 4)
- Outcome model μ_d(x): `GradientBoostingRegressor` (lr 0.05; depth 3, 100 trees, min leaf 100, chosen by GroupKFold CV by neighbourhood on the biased sample).
- Propensity model e(x): logistic regression on the same covariates (the Week 7 logit; lower CV log loss than a boosted classifier).
- DR learners: `DRLearner` (GBR final stage), `LinearDRLearner` (main), `SparseLinearDRLearner`, `ForestDRLearner`, plus `LinearDRLearner` with random-forest nuisances as a nuisance-model check.
- Cross-fitting: 5 folds formed by neighbourhood (`GroupKFold`). ATE = mean CATE over the sample.
- Bootstrap: 200 draws resampling neighbourhoods `a7`; nuisances and final stage refit in every draw; percentile 95% CI.

## Reproducibility notes
- Seed **1465** for the biased sample, all learners, CV folds and bootstraps (draw *b* uses seed 1465 + *b*).
- Package versions pinned in `requirements.txt`.
