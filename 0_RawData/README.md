# 0_RawData — Data Guide

Raw (de-identified, "noPII") input data for the ECO1465 replication / extension of

> Balán, Bergeron, Tourek & Weigel (2022). *Local Elites as State Capacity: How City Chiefs Use Local Information to Increase Tax Compliance in the D.R. Congo.* AER 112(3). Replication package: <http://doi.org/10.3886/E147561V1> (AEA RCT Registry AEARCTR-0003308).

Setting: the **2018 property-tax campaign in Kananga** (Kasaï-Central province, DRC). ~356 neighborhoods (*polygons*, id `a7`) were randomly assigned to who collects the tax: state agents (**Central**), neighborhood chiefs (**Local**), state agents with chiefs' information (**CLI**), or chief + agent teams (**CXL**).

> **Rule:** nothing in `0_RawData/` is ever edited or overwritten. All cleaning writes to `0.2data_intermediate/` (generated data) and `03_output/` (tables/figures).

---

## 1. What is in this folder

| Folder | File | Rows × Cols | Unit of observation | Unique key | Data collected (`today`/`date`) | Used by (original Stata code) |
|---|---|---|---|---|---|---|
| `0.1Baseline` | `baseline_noPII.csv` | **EMPTY (0 bytes)** | household (baseline survey) | `compound1` | — | Table 1, 3, 5, 8, 9, many appendix |
| `0.2chief` | `chief_collector_candidates.csv` | 3,132 × 10 | chief-candidate × neighborhood | (`a7`,`code`) | — | Table 3, A2–A4 |
| | `chief_collector_candidates_campaignupdated.csv` | 3,132 × 10 | same, updated after campaign | (`a7`,`code`) | — | A8, A14, A15, A27 |
| | `chief_consultations.csv` | **EMPTY (0 bytes)** | chief consultation by collectors | — | — | Fig 1, Table 8, A12, A21, A22 |
| | `chief_info.csv` | 4,343 × 14 | household that a chief was quizzed about | `code` | — | Fig A7, A19, Table A23 |
| | `chief_knowledge.csv` | 356 × 134 | neighborhood chief (knowledge quiz) | `a7` | 2019-08 → 2019-10-25 | Fig A7, A19 |
| | `chief_knowledge_neighborhoods.csv` | 364 × 6 | neighborhood | `a7` | — | Fig A4 |
| | `chief_survey_noPII.csv` | 1,102 × 329 | chief | `code` | 2017-12-18 → 2019-09-18 | Fig A4, Table A1, A8, A14, A15, A27, A43, A44 |
| | `chief_survey_randbasis_noPII.csv` | 1,084 × 466 | chief (pre-randomization version) | `code` | 2017-12-18 → 2018-05-17 | Table 3, A2–A4 |
| | `chief_tribe_info.csv` | 46,761 × 10 | property (chief & collectors' tribe) | none (`a7` repeats) | — | Table A9, A31 |
| `0.3collector` | `campaign_collector_info.csv` | 363 × 343 | neighborhood (assigned collectors' info, `col1_*`, `col2_*`) | `a7` | 2018-04-06 → 2019-03-25 | Fig A4, A19, Table A1, A8, A14, A15, A27, A39–A42 |
| | `collector_baseline_noPII.csv` | 530 × 135 | collector / chief-assistant baseline survey | `colcode` (not unique) | 2016-09-23 → 2019-04-10 | Fig A4, Table A1, A8, A14, A15, A27, A43, A44 |
| | `collector_chars.csv` | 106 × 93 | state collector | `colcode` | — | Table A39 |
| | `collector_endline_noPII.csv` | 413 × 282 | collector endline survey | `code` (not unique) | 2019-03-13 → 2020-02-29 | Table A14, A43, A44 |
| | `collector_knowledge_clean.csv` | 379 × 136 | collector × neighborhood knowledge quiz | (`code`,`a7`) | 2020-02-12 → 2020-03-16 | Fig A19 |
| `0.4endline` | `endline_round1_noPII.csv` | 5,602 × 960 | household (property owner), endline round 1 | `compound_code` (not unique: 5,569 rows / 4,369 ids) | 2019-03-22 → 2019-09-13 | Fig 1, Table 1, 3, 5, 8, 9 and many appendix |
| | `endline_round2_noPII.csv` | 1,753 × 536 | household, endline round 2 | `code` | 2019-12-11 → 2020-03-03 | (no do-file loads it) |
| | `endline_2016campaign_noPII.csv` | 3,600 × 1,591 | household surveyed after the **2016** campaign | `s3_code` | 2017-01-18 → 2017-06-02 | Table 3, A2–A4 |
| `0.5tax` | `taxroll_noPII.csv` | 47,930 × 12 | property on the tax roll | `compound1` | registration dates Mar–Apr 2018 | data construction |
| | `tax_payments_noPII.csv` | 3,733 × 28 | **paid** property (receipt) | `compound1` | 2018-02-27 → 2019-01-30 | data construction, Fig A20 |
| | `tax_payment_timing_noPII.csv` | 4,732 × 19 | payment transaction recorded on a handheld TDM device | none (one property can have several records) | 2018-06-15 → 2019-01-30 | Fig A20 |
| | `tax_payments_neighborhoods.csv` | 356 × 14 | neighborhood (**2016** campaign compliance) | `a7` | programme start Apr–Nov 2016 | Table 3, A2–A4 |
| `0.6campaign` | `fliers_campaign.csv` | 58,634 × 28 | property flier (assigned rate & message) | `code` | — | data construction |
| | `registration_noPII.csv` | 48,034 × 105 | property registration ("cartography") visit | `compound1` (56 dups) | 2018-02-26 → 2018-12-11 | data construction |
| | `campaign_2016_neighborhoods.csv` | 434 × 13 | neighborhood in 2016 campaign | `a7` | 2016-05-19 → 2016-12-30 | data construction |
| `0.7randomization` | `randomization_assignment.csv` | 356 × 37 | neighborhood | `a7` | — | Table 3, A2–A4 |
| | `randomization_schedule.csv` | 356 × 9 | neighborhood (month & collectors assigned) | `a7` | campaign months 1–7 | data construction |
| | `stratum.csv` | 356 × 13 | neighborhood (randomization strata) | `a7` | — | almost every table (strata FE) |
| `0.8geography` | `hh_distances.csv` | 45,178 × 7 | property | `compound1` | — | Table A8, A14, A15, A24, A25, A27 |
| | `neighborhood_centroids.csv` | 443 × 2 | neighborhood | `a7` | — | Fig A21, A22 |
| | `neighborhood_transport_cost.csv` | 346 × 2 | neighborhood | `a7` | — | Fig A15, A21, A22, Table A45 |
| (root) | `Data_Construction` | Python script (no extension) | — | — | — | Python port of `Dofiles/2_Data_Construction.do` |
| `codebook/` | one `.md` per file + `codebook_all_variables.csv` | — | **every variable** (5,346 rows) | — | — | generated by `codebook/make_codebook.py` |

**Variable-level detail (every column: type, % non-missing, range, value counts, special codes) is in [`codebook/`](codebook/).** Open e.g. [`codebook/0.5tax__tax_payments_noPII.md`](codebook/0.5tax__tax_payments_noPII.md), or filter `codebook/codebook_all_variables.csv` by `file`.

---

## 2. Timeline of data collection

```
2016 May–Dec   2016 property-tax campaign (campaign_2016_neighborhoods, tax_payments_neighborhoods)
2017 Jan–Jun   Endline survey of 2016 campaign (endline_2016campaign_noPII)
2017 Dec–2018 May   Chief survey used for randomization (chief_survey_randbasis_noPII)
2018 Feb–Dec   2018 campaign: registration / cartography (registration_noPII, taxroll_noPII, fliers_campaign)
2018 Feb–2019 Jan   Tax payments (tax_payments_noPII, tax_payment_timing_noPII)
2019 Mar–Sep   Household endline round 1 (endline_round1_noPII)
2019 Mar–2020 Feb   Collector endline (collector_endline_noPII)
2019 Aug–Oct   Chief knowledge quiz (chief_knowledge, chief_info)
2019 Dec–2020 Mar   Household endline round 2 (endline_round2_noPII)
2020 Feb–Mar   Collector knowledge quiz (collector_knowledge_clean)
```

The 2018 campaign ran in **7 monthly waves** (`randomization_schedule.month` = 1…7); each neighborhood was treated in one month.

---

## 3. Identifiers and how files link

| Key | Meaning | Level | Found in |
|---|---|---|---|
| `a7` | neighborhood / polygon id (356 in the 2018 experiment; `treatment==0` marks 5 pilot polygons, and flier pilot polygons 200–203, 207, 208, 210 are dropped in construction) | neighborhood | almost every file (`polygon` in `tax_payments_noPII` = same id) |
| `compound1` | property (compound) id on the tax roll | property | `taxroll`, `registration`, `tax_payments`, `tax_payment_timing`, `hh_distances` |
| `compound_code` | property id in household endline round 1 (match to `compound1`) | property | `endline_round1_noPII` |
| `code` | **context-dependent!** chief id in `chief_survey*`; flier id in `fliers_campaign`; respondent/collector id in collector & endline files | varies | many |
| `chef_code` | chief id | chief | `chief_knowledge`, `fliers_campaign`, `randomization_schedule`, collector files |
| `colcode`, `col_code`, `collector_ID` | tax-collector id | collector | collector files, `tax_payments_noPII`, `tax_payment_timing_noPII` |
| `stratum` | randomization stratum (use as fixed effect) | neighborhood | `stratum.csv`, `randomization_assignment.csv` |
| `s3_code` | respondent id, 2016-campaign endline | household | `endline_2016campaign_noPII` |

```
                         stratum.csv / randomization_assignment.csv / randomization_schedule.csv   (a7)
                                               │ m:1 on a7
fliers_campaign (code, a7) ──► registration_noPII (compound1, a7) ──1:1──► taxroll_noPII (compound1)
                                               │ 1:1 on compound1                    │
                                  tax_payments_noPII (compound1)       hh_distances (compound1)
                                               │
                           endline_round1_noPII (compound_code ≈ compound1)
Neighborhood-level add-ons (m:1 on a7): campaign_collector_info, chief_knowledge(_neighborhoods),
neighborhood_centroids, neighborhood_transport_cost, tax_payments_neighborhoods
```

---

## 4. Treatment and key coding

**Treatment arm** — `treatment` (randomization files, fliers, endline) / `tmt` (registration):

| Code | Arm | Who collects | # neighborhoods |
|---|---|---|---|
| 0 | Pilot | — (drop) | 5 |
| 1 | **Central** | state collectors | 110 |
| 2 | **Local** | neighborhood chief | 110 |
| 3 | **CLI** — Central + Local Information | state collectors, after consulting the chief | 80 |
| 4 | **CXL** — Central × Local | chief and state collector together | 51 |

The paper builds dummies `t_c = (tmt==1)`, `t_l = (tmt==2)`, `t_cli = (tmt==3)`, `t_cxl = (tmt==4)`.

**Other codes worth knowing**

| Variable | Values |
|---|---|
| `house` (registration, tax payments) | 1 = periphery / low-value house; 2 = *maison moyenne* (mid/high value); 3 = villa |
| `rate` (fliers) | randomly assigned tax rate for periphery houses: 1500, 2000, 2500, 3000 Congolese francs (CF) |
| `amountCF` (tax payments) | amount paid in CF (1500–3000 periphery; 6600/8800/11000/13200 for higher-value houses) |
| `rand_msg_bin` / `treatment_fr` (fliers) | randomly assigned flier message (central-enforcement, local-enforcement, public goods, trust in state, plain reminder); text is in **French** (`_fr`) and **Tshiluba** (`_tsh`) |
| `paid` (tax_payments_noPII) | 1 = paid, 3 = paid as bonus at registration, missing = no entry |
| `exempt` (registration) | 1 = property claimed/declared exempt |
| `sex` | 0 = female, 1 = male (do-file `label define gender`) |

Outcome of interest in this project: `taxes_paid` (0/1) and `taxes_paid_amt` (CF) are **not raw variables** — they are constructed in `Data_Construction` / `2_Data_Construction.do` from `tax_payments_noPII` (+ the missing midline file, see §7).

---

## 5. Formats and conventions

- **File format:** comma-separated `.csv`, UTF-8 **with BOM**. Read with `pd.read_csv(path, encoding="utf-8-sig", low_memory=False)`.
- **Converted from Stata `.dta`.** Value labels were lost in export, so categorical variables are numeric codes; meanings come from the survey instruments (available from the authors on request) and the do-files.
- **Stata missing values** appear as an empty cell or the string `"."` (also `.d` = don't know, `.r` = refused in some text columns). Convert `"."` to missing before use.
- **Survey special codes** (numeric): `97`, `98`, `99`, `88`, `999`, `9999`, `99999`, `999999` usually mean *other / don't know / refused / not applicable*; `-1` also appears. They are flagged per variable in the `special_codes` column of the codebook. Check before taking means (e.g. `liquidity_bind_date = 9999`, `visits = 99999`, `compound1 = 999999` = unknown).
- **Dates come in several formats** — always parse explicitly:
  - ISO `YYYY-MM-DD` / `YYYY-MM-DD HH:MM:SS` → `today`, `start`, `end` (SurveyCTO tablets)
  - `DD-MM-YYYY 00:00:00` → `tax_payment_timing_noPII.date` (day first!)
  - `27-Nov-18`, `Sep 7, 2018`, `12 mars 2018`, `9 octobre 2018` (French month names) → `taxroll_noPII.DateRDV / Date / DatePaye`, `registration_noPII.today_fr`
  - Stata daily numbers (days since 1960-01-01), e.g. `collector_endline_noPII.date_f = 22308`
  - `date` / `date_f` columns with a single value (e.g. `28 Jan 2021`) are **data-export stamps, not survey dates**.
- **Currency:** CF (Congolese franc); `*USD` columns use the `rateUSD` exchange rate.
- **Survey timing:** `start`/`end` = interview start/end timestamp; `today` = interview date. Suffixes in `endline_2016campaign_noPII` mark merged sub-surveys: `_s1`, `_s2`, `_s2n`, `_ss`, `_rr`, `_reunion`.

---

## 6. Variable families (how to read survey variable names)

Survey columns are named after questionnaire items. Common families (meaning inferred from names + do-files; confirm in the instruments):

| Prefix / pattern | Meaning |
|---|---|
| `a7`, `a7b`, `a7c`, `a7_check` | neighborhood id and enumerator checks of it |
| `sex`, `age`, `edu`, `job`, `tribe`, `subtribe`, `religion`, `born_kga`, `move_kga`, `kga_*` | respondent demographics (`kga` = Kananga) |
| `possessions_*`, `inc_mo`, `inc_wk`, `roof`, `fence`, `walls`, `hh_size` | wealth / income / housing quality |
| `trust*` | trust in institutions (chief, state, tax ministry DGRKOC, …) |
| `corr*`, `gov1_end`, `gov2_end` | perceived corruption; `gov*` are 0–1000 allocation questions (share of 1000 CF), `corr14` is a 1–7 scale |
| `elect*`, `civ*`, `pol*` | elections, civic and political participation |
| `salongo_*` | *salongo* (community work) obligations |
| `tax_*`, `pay_*`, `paid_*`, `taxsource_*`, `solicited_*`, `required_*` | tax knowledge, payment, who solicited it, other fees (e.g. market-vendor fee) |
| `visit*`, `vis_*`, `nb_visit*` | collector visits to the property |
| `bribe*` | bribe requests / payments |
| `receipt*` | tax-receipt possession and checks |
| `chef_*`, `chief_*` | questions about / answered by the neighborhood chief |
| `col1_*`, `col2_*` | first / second collector assigned to the neighborhood |
| `cash_fee_month2_1 … _31`, `liquidity_bind_date_1 … _31` | multi-select day-of-month dummies (which day cash was available / liquidity binding) |
| `provide*`, `satisfaction*`, `responsible*`, `demand*` | public-goods provision and attribution of responsibility |
| `consci`, `extrav`, `optim`, `intrin`, `introj`, `amotiv`, `extern`, `maze_*`, `math*`, `read*` | collector personality / motivation scales, maze & literacy tests (collector endline) |
| `*_o`, `*_other` | free-text "other, specify" answers (French) |
| `*_end`, `*_endline` | variable measured at endline (vs. baseline) |
| `*_fr`, `*_tsh` | French / Tshiluba version of a text |

---

## 7. Known issues — read before analysis

1. **Two files are empty (0 bytes):** `0.1Baseline/baseline_noPII.csv` and `0.2chief/chief_consultations.csv`. Anything needing household baseline covariates or chief consultations (Table 1, 3, 5, 8, 9, Figure 1, …) cannot run until they are re-exported from the replication package.
2. **Files in the original package but not here:** `midline_noPII` (monitoring survey — needed to build `taxes_paid`, `visited`, `exempt_monitoring`), `concessions_chefferies.csv`, `property_values_MLestimates.csv`, `adjacent_neighborhoods`, `resident_info_quiz`, `fliers_pilot_set1-3.xlsx`. `Data_Construction` already warns and skips missing inputs.
3. `chief_collector_candidates.csv` and `..._campaignupdated.csv` have identical shape but different content (checksums differ) — use the one the target table uses.
4. Neighborhood counts differ across files (334–443) because some include 2016-only or pilot polygons. Restrict to the 356 polygons in `randomization_assignment.csv` and drop `treatment == 0`.
5. Duplicate keys: `registration_noPII.compound1` has 56 duplicates (revisits); `endline_round1.compound_code` is not fully unique; collector files repeat `code`. The construction code keeps the most complete/latest record.
6. Implausible timestamps from tablet clocks (e.g. `1923-08-27`, `1982-01-01`) appear in `start`/`today` of a few rows of `chief_knowledge`, `endline_round1`, `endline_2016campaign`.
7. Many variables are **all missing** (294 columns, mostly skip-pattern items); check `kind = all_missing` in the codebook.

---

## 8. Quick start

```python
from pathlib import Path
import pandas as pd

RAW = Path("0_RawData")                                   # relative to repo root
assign = pd.read_csv(RAW / "0.7randomization/randomization_assignment.csv", encoding="utf-8-sig")
assign = assign[assign["treatment"] != 0]                 # drop pilot
codebook = pd.read_csv(RAW / "codebook/codebook_all_variables.csv")
codebook[codebook["file"].str.contains("tax_payments_noPII")]
```

**Regenerate the codebook** (only reads raw data; deterministic):

```bash
pip install pandas==2.2.2 tabulate==0.9.0
python 0_RawData/codebook/make_codebook.py
```

Last checked against the repository: 2026-10-24.
