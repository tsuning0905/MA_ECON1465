# MA_ECON1465 — Local chiefs, exemptions and favoritism

ECO1465 (Applied Causal Machine Learning) project extending
Balán, Bergeron, Tourek & Weigel (2022), *Local Elites as State Capacity*, AER 112(3).
Replication package: <http://doi.org/10.3886/E147561V1>.

**Research question.** Does assigning property-tax collection to neighbourhood chiefs
(Local, `tmt == 2`) instead of state collectors (Central, `tmt == 1`) change exemptions
and bribery, and for which households is the effect larger? Assignment is random by
neighbourhood (`a7`), so Local − Central is a causal effect; no IV is needed.

## Run everything (one command)

```bash
pip install -r requirements.txt      # exact versions used
python 00_master/00_master.py        # raw data -> data_intermediate -> 03_output (~3 min)
```

Rerun only the analysis: `python 00_master/00_master.py --from 02`.
No paths need editing: every script locates the repo from its own position.

## Folder layout

| Folder | Content | Written by |
|---|---|---|
| `0_RawData/` | Raw de-identified data + codebooks (`0_RawData/README.md`). **Never edited.** | — |
| `00_master/00_master.py` | Sets paths, runs every step below in order | — |
| `01_preanalysis/` | Cleaning and variable construction | — |
| `data_intermediate/` | All generated data | `01_preanalysis/*` |
| `02_analysis/` | One script per report / table group | — |
| `03_output/` | Final tables (`.tex`, `.csv`) and figures (`.pdf`, `.png`) | `02_analysis/*` |
| `Dofiles/` | Original Stata replication code (reference only) | — |

## Pipeline

| Step | Script | Input | Output |
|---|---|---|---|
| 01a | `01_preanalysis/01a_data_construction.py` | `0_RawData/**` | `data_intermediate/analysis_data.csv.gz`, `combined_data.csv.gz` |
| 01b | `01_preanalysis/01b_build_exemption_data.py` | `analysis_data.csv.gz`, geography, chief tribe | `data_intermediate/exemption_analysis.csv.gz` |
| 02_week4 | `02_analysis/02_week4_trees.py` | `exemption_analysis.csv.gz` | `03_output/week4/*` |

01a is a Python port of the package's `2_Data_Construction.do` (originally
`0_RawData/Data_Construction`); it unzips `midline_noPII.dta.zip` into
`data_intermediate/` (that 190 MB copy is git-ignored and rebuilt on each run).

## Output map — Week 4 report

| Report item | File in `03_output/week4/` |
|---|---|
| Figure 1 (regression tree) | `figure_w4_1_regression_tree.pdf` |
| Appendix: tree CV path | `figure_w4_1b_tree_cv.pdf` |
| Table 1 (RF importance) | `table_w4_2_rf_importance.tex` / `.csv`, `figure_w4_2_rf_importance.pdf` |
| Table 2 (prediction errors) | `table_w4_3_model_errors.tex` / `.csv` |
| Appendix: boosting CV path | `figure_w4_3_boosting_cv.pdf` |
| Context: OLS Local effects | `table_w4_0_ols_effects.tex` / `.csv` |
| All numbers quoted in text | `week4_numbers.json` |

## Key variable definitions (built in `01b`)

- `exempt`: collector recorded the property as exempt at registration.
  `exempt_elderly` (reason = old age), `exempt_widow` (reason = widow), `exempt_other_reason`.
- `exempt_elderly_u60` (`_u55`): exempted for old age but the surveyed owner is under 60 (55).
  A proxy for discretionary exemptions; the 60 cutoff is an assumption. Widow exemptions
  cannot be checked: there is no marital-status variable.
- `coethnic_collector`: owner's tribe matches the chief (Local) or either state collector
  (Central), following the paper's Table A9 `tribe_match`.
- The endline `coethnic_bias_chief` is post-treatment (an outcome in paper Table 5) and is
  not used as a feature.
- In the prediction models, missing feature values are coded `-1`.

## Reproducibility rules

- Seed `SEED = 0` for every split, CV, forest, boosting and permutation step.
- Train/test split and CV folds are grouped by neighbourhood (`a7`).
- File names: no spaces, no non-ASCII characters, underscores only.
