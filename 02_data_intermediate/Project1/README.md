# MA_ECON1465 — Project One

**Do Local Chiefs Grant More Discretionary Tax Exemptions? Evidence from a Randomized Tax Collection Experiment in Kananga, D.R. Congo**
Tsu Ning Tsao (ECO1465 Applied Causal Machine Learning, University of Toronto, Fall 2026)

Extension of Balán, Bergeron, Tourek & Weigel (2022), *AER* 112(3). Replication package: <https://doi.org/10.3886/E147561V1>.

---

## Run everything (one command)

```bash
git clone https://github.com/tsuning0905/MA_ECON1465.git
cd MA_ECON1465
pip install -r requirements.txt          # Python 3.13; exact versions inside
python 00_master/00_master.py            # ~6 minutes: data -> Tables 1-9, Figures 1-10 -> paper PDF
```

Options: `--rebuild` re-runs the port of the authors' data construction even if its output exists;
`--no-paper` skips LaTeX. No path needs editing: every script finds the repository root from its own location.

Non-Python tools: **Graphviz** `dot` for the DAG figures (`apt install graphviz` / `brew install graphviz`),
and **pdflatex** (TeX Live / MacTeX) for the paper; if pdflatex is missing the master script skips the PDF and still writes all tables and figures.

## Folder layout

| Folder | What is in it | Edited by hand? |
|---|---|---|
| `0_RawData/` | raw de-identified data from the replication package + codebook (`0_RawData/README.md`) | **never** — read-only |
| `00_master/00_master.py` | sets paths and runs steps 1–3 in order | – |
| `01_preanalysis/01a_data_construction.py` | Python port of the authors' `Dofiles/2_Data_Construction.do` | – |
| `01_preanalysis/01_preanalysis.py` | sample, outcomes, covariates, missing values → final dataset | – |
| `02_analysis/02_analysis.py` | every table and figure, sections S1–S12 in paper order | – |
| `data_intermediate/` | all generated data (not pushed; rebuilt by step 1) | no |
| `03_output/tables/` | `tableN_*.tex / .csv / .xlsx`, `key_numbers.csv` (numbers quoted in the text) | no |
| `03_output/figures/` | `figN_*.pdf / .png` | no |
| `03_output/paper/main.tex` → `main.pdf` | the paper; `\input`s the tables and figures above | text only |
| `Dofiles/` | the authors' original Stata code (reference only) | – |

## Pipeline

1. **`01_preanalysis/01_preanalysis.py`**
   - unzips `0_RawData/0.9midline/midline_noPII.dta.zip` into `data_intermediate/` (raw zip untouched);
   - runs `01a_data_construction.py` → `data_intermediate/analysis_data.csv.gz` (= authors' `analysis_data.dta`; reproduces their Table 4 col. 1: 0.023, N = 28,872, 221 clusters);
   - keeps Central (`tmt=1`) and Local (`tmt=2`) neighbourhoods and builds all variables:
     exemption by reason (`why_exempt`: 2 old age, 5 widow, 3 pension, 4 disability), discretionary exemptions
     (old age & owner < 55; widow & owner male; cut-offs 50/60/65 for robustness), reason-free `exempt_no_basis`,
     owner covariates (special codes 88/97–99/8888/9999 → missing), co-ethnicity with the chief from the
     pre-randomization chief survey, distance, predicted property value, share of adjacent neighbourhoods in Local;
   - writes `final_property.csv.gz` (one row per property), `final_neighbourhood.csv`, `variable_dictionary.csv`.
2. **`02_analysis/02_analysis.py`** — run a subset with e.g. `python 02_analysis/02_analysis.py S7 S11`.
3. **`03_output/paper/main.tex`** compiled twice by the master script.

## Output ↔ paper

| Paper | File (`03_output/`) | Section in `02_analysis.py` |
|---|---|---|
| Table 1 Summary statistics | `tables/table1_sumstats` | S1 |
| Figure 1 Exemptions by owner age | `figures/fig1_exempt_by_age` | S2 |
| Figure 2 (a)–(c) DAGs | `figures/fig2a_dag1`, `fig2b_dag2`, `fig2c_dag3` | S5 |
| Table 2 / Figure 3 Balance and attrition | `tables/table2_balance`, `figures/fig3_balance` | S3 |
| Figure 4 / Table 3 SUTVA: network and spillovers | `figures/fig4_network`, `tables/table3_spillover` | S4 |
| Table 4 Replication of the paper | `tables/table4_replication` | S6 |
| Table 5 Main ATE | `tables/table5_ate` | S7 |
| Figure 5 Effect by owner age | `figures/fig5_effect_by_age` | S8 |
| Table 6 Heterogeneity (interactions) | `tables/table6_heterogeneity` | S9 |
| Figure 6 / Table 7 Ridge, Lasso, PDS-Lasso | `figures/fig6a_ridge`, `fig6b_lasso`, `tables/table7_regularization` | S10 |
| Table 8 / Figure 7 Robustness, randomization inference | `tables/table8_robustness`, `figures/fig7_ri` | S11 |
| Figure 8 Tree, Table 9 errors, Figure 9 importance, Figure 10 PDP | `figures/fig8_tree`, `tables/table9_ml_errors`, `figures/fig9_rf_importance`, `figures/fig10_pdp` | S12 |

## Randomness

Seed **1465** everywhere: train/test split by neighbourhood (`GroupShuffleSplit`), grouped CV folds, forests,
boosting, permutation importance and the 2,000 randomization-inference draws. The only random step in the authors'
construction (a bonus split not used here) is seeded with their seed 12345999.

## Notes

- `data_intermediate/` replaces the old folder `0.2data_intermediate ` (its name ends in a space); that folder can be deleted.
- `0_RawData/0.8geography/neighborhood_transport_cost.csv` holds campaign costs, which depend on treatment, so it is not used as a covariate.
