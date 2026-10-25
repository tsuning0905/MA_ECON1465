"""
01b_build_exemption_data.py
===========================
Builds the analysis dataset for the exemption / favoritism research question.

Research question
-----------------
Does assigning tax collection to neighbourhood chiefs (Local, tmt == 2) instead of
state collectors (Central, tmt == 1) change exemptions and bribery, and for which
households is the effect larger?  Assignment is random at the neighbourhood (a7)
level, so Local - Central is the causal effect of the collector type (no IV needed).

Input  (read-only)
    data_intermediate/analysis_data.csv.gz         <- 01a_data_construction.py
    0_RawData/0.8geography/hh_distances.csv
    0_RawData/0.8geography/neighborhood_transport_cost.csv
    0_RawData/0.2chief/chief_tribe_info.csv
Output
    data_intermediate/exemption_analysis.csv.gz    one row per property, Local + Central

Variable definitions (all generated here, documented once)
----------------------------------------------------------
Outcomes
    exempt               1 if the collector recorded the property as exempt at registration
    exempt_elderly       1 if exempt and the recorded reason is old age  (why_exempt == 2)
    exempt_widow         1 if exempt and the recorded reason is widow    (why_exempt == 5)
    exempt_other_reason  1 if exempt for any other reason (pensioner, disabled, church, ...)
    exempt_elderly_u60   1 if exempted for old age BUT the owner's surveyed age is < AGE_CUTOFF
                         ("discretionary" old-age exemption). Defined only when owner age is known.
    exempt_elderly_u55   same with a 55 cutoff (robustness)
    bribe                1 if the household reports paying a bribe (midline bribe_combined)
Features (pre-treatment or fixed household / neighbourhood characteristics)
    local, owner_age, owner_female, owner_luluwa, coethnic_collector, job_gov, house_mm,
    walls, rate (randomized tax rate), tmt_2016, dist_center, transport_cost, commune
Sample flag
    survey_sample        1 if owner age and sex are observed (monitoring survey); the
                         week-4 prediction models use this subsample.

Note on widows: there is no marital-status variable, and the owner of record may be a
deceased husband, so widow exemptions cannot be checked against household data.
Note on coethnic_bias_chief (endline exempt_tribe): it is measured after treatment and
the paper (Table 5) uses it as an outcome, so it is NOT used as a feature here.
"""
from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import pandas as pd

REPO_DIR = Path(os.environ.get("REPO_DIR", Path(__file__).resolve().parents[1]))
RAW = REPO_DIR / "0_RawData"
INT = REPO_DIR / "data_intermediate"

AGE_CUTOFF = 60            # assumed legal age for the old-age ("troisieme age") exemption
MISSING_TRIBE = {"", ".", "9999", "8888", "7777", "0"}

# ------------------------------------------------------------------ load
a = pd.read_csv(INT / "analysis_data.csv.gz", low_memory=False)
d = a[a["tmt"].isin([1, 2]) & a["exempt"].notna()].copy()

hd = pd.read_csv(RAW / "0.8geography" / "hh_distances.csv")[["compound1", "dist_city_center"]]
tc = pd.read_csv(RAW / "0.8geography" / "neighborhood_transport_cost.csv")
ct = pd.read_csv(RAW / "0.2chief" / "chief_tribe_info.csv")
ct = ct[["a7", "chef_tribe", "col1_tribe", "col2_tribe"]].drop_duplicates("a7")

d = (d.merge(hd.drop_duplicates("compound1"), on="compound1", how="left")
       .merge(tc, on="a7", how="left")
       .merge(ct, on="a7", how="left"))

# ------------------------------------------------------------------ treatment
d["local"] = (d["tmt"] == 2).astype(int)

# ------------------------------------------------------------------ outcomes
d["exempt"] = d["exempt"].astype(int)
d["exempt_elderly"] = ((d["exempt"] == 1) & (d["why_exempt"] == 2)).astype(int)
d["exempt_widow"] = ((d["exempt"] == 1) & (d["why_exempt"] == 5)).astype(int)
d["exempt_other_reason"] = d["exempt"] - d["exempt_elderly"] - d["exempt_widow"]

age_known = d["age_prop"].notna()
for cut in (AGE_CUTOFF, 55):
    v = ((d["exempt_elderly"] == 1) & (d["age_prop"] < cut)).astype(float)
    d[f"exempt_elderly_u{cut}"] = v.where(age_known)

d["bribe"] = d["bribe_combined"]

# ------------------------------------------------------------------ features
d["owner_age"] = d["age_prop"]
d["owner_female"] = 1 - d["sex_prop"]                 # sex_prop: 1 male, 0 female
d["owner_luluwa"] = d["main_tribe"]
d["house_mm"] = d["mm"]                               # 1 = brick/better house
d["dist_center"] = d["dist_city_center"]
d["transport_cost"] = d["transport_costs"]


def _clean_tribe(s: pd.Series) -> pd.Series:
    s = s.astype("object").where(s.notna(), "").astype(str).str.strip().str.upper()
    return s.where(~s.isin(MISSING_TRIBE), "")


own = _clean_tribe(d["tribe"])
chef, c1, c2 = (_clean_tribe(d[c]) for c in ["chef_tribe", "col1_tribe", "col2_tribe"])
# Owner shares the tribe of whoever collects (paper Table A9 'tribe_match'):
#   Local  -> the chief;   Central -> either of the two state collectors
match_l = np.where((own != "") & (chef != ""), (own == chef).astype(float), np.nan)
match_c = np.where((own != "") & (c1 != "") & (c2 != ""),
                   ((own == c1) | (own == c2)).astype(float), np.nan)
d["coethnic_collector"] = np.where(d["local"] == 1, match_l, match_c)

d["survey_sample"] = (d["owner_age"].notna() & d["owner_female"].notna()).astype(int)

KEEP = ["compound1", "a7", "stratum", "tmt", "local", "survey_sample",
        "exempt", "exempt_elderly", "exempt_widow", "exempt_other_reason",
        "exempt_elderly_u60", "exempt_elderly_u55", "bribe", "taxes_paid",
        "owner_age", "owner_female", "owner_luluwa", "coethnic_collector", "job_gov",
        "house_mm", "walls", "rate", "tmt_2016", "dist_center", "transport_cost", "commune"]
out = d[KEEP].sort_values(["a7", "compound1"]).reset_index(drop=True)
out.to_csv(INT / "exemption_analysis.csv.gz", index=False, compression="gzip")

print("exemption_analysis:", out.shape, "| neighbourhoods:", out["a7"].nunique(),
      "| survey sample:", int(out["survey_sample"].sum()))
print(out.groupby("local")[["exempt", "exempt_elderly", "exempt_widow",
                            "exempt_elderly_u60", "bribe"]].mean().round(4))
print("coethnic_collector coverage:", out["coethnic_collector"].notna().groupby(out["local"]).mean().round(3).to_dict())
