"""
01_preanalysis.py
=================
Project One, ECO1465 - "Do Local Chiefs Grant More Discretionary Tax Exemptions?"

Reads raw data (0_RawData/, never modified), cleans it and builds every variable
used in the paper. Output (all in data_intermediate/):

    midline_noPII.dta                 unzipped copy of 0_RawData/0.9midline/midline_noPII.dta.zip
    analysis_data.csv.gz              Python port of the authors' analysis_data.dta (01_preanalysis/01a_data_construction.py)
    final_property.csv.gz             FINAL DATASET: one row per property, Central + Local neighbourhoods
    final_neighbourhood.csv           one row per neighbourhood (221), for balance and spillover checks
    variable_dictionary.csv           name / label / source of every variable in final_property

Sections
    0. Paths and settings
    1. Unzip midline and run the authors' data construction (port)
    2. Sample: Central (tmt=1) and Local (tmt=2) neighbourhoods
    3. Outcomes: exemptions by stated reason, discretionary exemptions, bribes
    4. Owner covariates (pre-determined) and missing-value handling
    5. Chief covariates and owner-chief co-ethnicity (pre-randomization chief survey)
    6. Geography: distances, transport cost, predicted property value, adjacent arms
    7. Sample flags and save

Run from anywhere:  python 01_preanalysis/01_preanalysis.py   (00_master/00_master.py calls it)
No randomness in this file.
"""
from __future__ import annotations

import runpy
import sys
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd

# =============================================================================
# 0. Paths and settings
# =============================================================================
ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "0_RawData"
INTER = ROOT / "data_intermediate"
INTER.mkdir(exist_ok=True)

LEGAL_AGE = 55          # Congolese law: owners aged 55+ are exempt (paper, footnote 24)
ALT_AGES = [50, 60, 65]  # robustness cut-offs
SPECIAL = [88, 97, 98, 99, 888, 999, 8888, 9999, 99999, 999999]


def rd(rel: str, **kw) -> pd.DataFrame:
    return pd.read_csv(RAW / rel, encoding="utf-8-sig", low_memory=False, **kw)


def clean_num(s: pd.Series, lo=None, hi=None) -> pd.Series:
    s = pd.to_numeric(s, errors="coerce")
    s = s.mask(s.isin(SPECIAL))
    if lo is not None:
        s = s.mask(s < lo)
    if hi is not None:
        s = s.mask(s > hi)
    return s


def clean_tribe(s: pd.Series) -> pd.Series:
    s = s.astype("string").str.upper().str.strip()
    bad = s.isna() | s.str.contains(r"^[0-9.]+$|^\.|NEVEUT|NESAIS|DOESN|INSEREZ|PARCELLE|BELGE|ELLENE", regex=True)
    return s.mask(bad)


# =============================================================================
# 1. Unzip midline and run the authors' data construction
# =============================================================================
mid_dta = INTER / "midline_noPII.dta"
if not mid_dta.exists():
    with zipfile.ZipFile(RAW / "0.9midline" / "midline_noPII.dta.zip") as z:
        z.extract("midline_noPII.dta", INTER)
    print("unzipped midline ->", mid_dta)

if not (INTER / "analysis_data.csv.gz").exists() or "--rebuild" in sys.argv:
    print("running 01_preanalysis/01a_data_construction.py (port of 2_Data_Construction.do) ...")
    runpy.run_path(str(ROOT / "01_preanalysis" / "01a_data_construction.py"), run_name="__main__")

a = pd.read_csv(INTER / "analysis_data.csv.gz", low_memory=False)

# =============================================================================
# 2. Sample: Central and Local neighbourhoods (the 221 polygons of the paper's C vs L comparison)
# =============================================================================
d = a[a["tmt"].isin([1, 2])].copy().reset_index(drop=True)
d["local"] = (d["tmt"] == 2).astype(int)                   # treatment D
# two-month time fixed effect, identical cut points to Table4.do / TableA9.do
d["time_fe"] = pd.cut(d["today_alt"], [21355, 21415, 21475, 21532], right=False, labels=False)
d["house_band"] = d["house"]                                 # 1 periphery / 2 maison moyenne (paper's house FE)

# =============================================================================
# 3. Outcomes
# =============================================================================
reg = d["exempt"].notna()                                    # collector recorded an exemption decision
why = d["why_exempt"]
reasons = {"exempt_age": [2], "exempt_widow": [5], "exempt_pension": [3],
           "exempt_handicap": [4], "exempt_otherreason": [1, 6, 7, 8, 9]}
for k, v in reasons.items():
    d[k] = np.where(reg, why.isin(v).astype(float), np.nan)
d["exempt_pension_hand"] = d["exempt_pension"] + d["exempt_handicap"]
d["exempt_other_all"] = d["exempt_pension_hand"] + d["exempt_otherreason"]
# exempt with a missing reason: counted in "other"
d.loc[reg & (d["exempt"] == 1) & why.isna(), "exempt_other_all"] = 1

# independent enumerator's call (Table 5 row 2 of the paper)
d["enum_disagrees"] = np.where(reg & d["exempt_enum"].notna(),
                               (d["exempt"] != d["exempt_enum"]).astype(float), np.nan)

# midline bribe (authors' bribe_combined, Table 5 row 5)
d["bribe_midline"] = d["bribe_combined"]

# =============================================================================
# 4. Owner covariates (pre-determined traits reported in the midline survey)
# =============================================================================
d["owner_age"] = clean_num(d["age_prop"], 18, 105)
d["age_guessed"] = np.where(d["owner_age"].notna(), d["age_prop_guess"].notna().astype(float), np.nan)
sexp = clean_num(d["sex_prop"])
d["female"] = np.where(sexp.isin([0, 1]), 1 - sexp, np.nan)            # sex_prop: 1 male, 0 female
d["luluwa"] = d["main_tribe"]
d["work_gov"] = d["work_gov"]
d["family_gov"] = clean_num(d["job_gov"]).where(lambda s: s.isin([0, 1]))
d["employed"] = d["employed"]
d["salaried"] = d["salaried"]
d["years_avenue"] = clean_num(d["move_ave"], 0, 96)
walls = clean_num(d["walls"])
d["walls_good"] = np.where(walls.isin([0, 1, 2, 3, 4]), (walls >= 2).astype(float), np.nan)   # good mud brick, brick, cement
d["walls_brick"] = np.where(walls.isin([0, 1, 2, 3, 4]), (walls >= 3).astype(float), np.nan)
roof = clean_num(d["roof"])
d["roof_metal"] = np.where(roof.between(1, 7), (roof >= 6).astype(float), np.nan)
d["assigned_rate"] = d["assign_flier_rate"]                   # randomized at property level (periphery houses)
d["owner_tribe"] = clean_tribe(d["tribe"])
d["owner_subtribe"] = clean_num(d["subtribe"])

# legal eligibility by age and discretionary ("favour") exemptions
age = d["owner_age"]
d["elig_age55"] = np.where(age.notna(), (age >= LEGAL_AGE).astype(float), np.nan)
d["owner_male_under55"] = np.where(age.notna() & d["female"].notna(),
                                   ((age < LEGAL_AGE) & (d["female"] == 0)).astype(float), np.nan)
ok_age = reg & age.notna()
d["disc_age"] = np.where(ok_age, ((d["exempt_age"] == 1) & (age < LEGAL_AGE)).astype(float), np.nan)
d["just_age"] = np.where(ok_age, ((d["exempt_age"] == 1) & (age >= LEGAL_AGE)).astype(float), np.nan)
for c in ALT_AGES:
    d[f"disc_age{c}"] = np.where(ok_age, ((d["exempt_age"] == 1) & (age < c)).astype(float), np.nan)
ok_sex = reg & d["female"].notna()
d["disc_widow"] = np.where(ok_sex, ((d["exempt_widow"] == 1) & (d["female"] == 0)).astype(float), np.nan)
ok_both = ok_age & d["female"].notna()
d["disc_any"] = np.where(ok_both, ((d["disc_age"] == 1) | (d["disc_widow"] == 1)).astype(float), np.nan)
# reason-free measure: exempted although the owner is a man under 55 and not exempted as pensioner/disabled
d["exempt_no_basis"] = np.where(ok_both, ((d["exempt"] == 1) & (d["owner_male_under55"] == 1)
                                          & (d["exempt_pension_hand"] == 0)).astype(float), np.nan)

# =============================================================================
# 5. Chief covariates and owner-chief co-ethnicity
#    The chief named on each property's tax letter (fliers_campaign.chef_code) is linked to the
#    chief survey used for randomization (Dec 2017 - May 2018, before assignment).
# =============================================================================
fl = rd("0.6campaign/fliers_campaign.csv", usecols=["a7", "chef_code"])
chief_of = fl.dropna(subset=["chef_code"]).groupby("a7")["chef_code"].agg(lambda s: s.mode().iloc[0]).rename("chef_code_nb")
cs = rd("0.2chief/chief_survey_randbasis_noPII.csv")[["code", "tribe", "subtribe", "age", "sex", "edu"]]
cs = cs.rename(columns={"code": "chef_code_nb", "tribe": "chief_tribe", "subtribe": "chief_subtribe",
                        "age": "chief_age", "sex": "chief_sex", "edu": "chief_edu"})
cs["chief_tribe"] = clean_tribe(cs["chief_tribe"])
cs["chief_subtribe"] = clean_num(cs["chief_subtribe"])
cs["chief_female"] = np.where(cs["chief_sex"].isin([1, 2]), (cs["chief_sex"] == 2).astype(float), np.nan)
cs = cs.drop_duplicates("chef_code_nb")
chief_nb = chief_of.reset_index().merge(cs, on="chef_code_nb", how="left")
d = d.merge(chief_nb[["a7", "chief_tribe", "chief_subtribe", "chief_age", "chief_female", "chief_edu"]],
            on="a7", how="left")
d["chief_luluwa"] = np.where(d["chief_tribe"].notna(), (d["chief_tribe"] == "LULUWA").astype(float), np.nan)
both = d["owner_tribe"].notna() & d["chief_tribe"].notna()
d["coethnic_chief"] = np.where(both, (d["owner_tribe"] == d["chief_tribe"]).astype(float), np.nan)
bsub = d["owner_subtribe"].notna() & d["chief_subtribe"].notna()
d["cosubtribe_chief"] = np.where(bsub, (d["owner_subtribe"] == d["chief_subtribe"]).astype(float), np.nan)

# =============================================================================
# 6. Geography
# =============================================================================
dist = rd("0.8geography/hh_distances.csv")[["compound1", "dist_city_center"]].drop_duplicates("compound1")
d = d.drop(columns=["dist_city_center"], errors="ignore").merge(dist, on="compound1", how="left")
tc = rd("0.8geography/neighborhood_transport_cost.csv")
d = d.merge(tc, on="a7", how="left")
d["log_transport_cost"] = np.log(d["transport_costs"])
pv = pd.read_csv(RAW / "0.8geography/property_values_MLestimates.csv", usecols=["compound1", "pred_value"], low_memory=False)
pv["compound1"] = pd.to_numeric(pv["compound1"], errors="coerce")
pv = pv.dropna().drop_duplicates("compound1")
d = d.merge(pv, on="compound1", how="left")
d["log_pred_value"] = np.log(d["pred_value"].where(d["pred_value"] > 0))
d["commune_id"] = d["a7"].astype(int).astype(str).str[0].astype(int)        # first digit of polygon id = commune

# share of adjacent neighbourhoods assigned to Local (for the SUTVA / spillover check)
adj = pd.read_csv(RAW / "0.8geography/adjacent_neighborhoods.csv", thousands=",")
adj = adj.rename(columns={"src_poly_nm": "a7", "nbr_poly_nm": "nbr"})[["a7", "nbr"]].astype(int)
adj = pd.concat([adj, adj.rename(columns={"a7": "nbr", "nbr": "a7"})]).drop_duplicates()
asg = rd("0.7randomization/randomization_assignment.csv")[["a7", "treatment"]].astype(int)
adj = adj.merge(asg.rename(columns={"a7": "nbr", "treatment": "nbr_tmt"}), on="nbr", how="inner")
spill = adj.groupby("a7").agg(n_adjacent=("nbr", "size"),
                              share_adj_local=("nbr_tmt", lambda s: (s == 2).mean()),
                              share_adj_chief=("nbr_tmt", lambda s: s.isin([2, 4]).mean())).reset_index()
d = d.merge(spill, on="a7", how="left")

# =============================================================================
# 7. Sample flags, missing-value dummies and save
# =============================================================================
d["s_registered"] = reg.astype(int)                                       # exemption decision recorded
d["s_midline"] = (d["_merge_flier_carto_rep_monit"] == 3).astype(int)     # matched to the midline survey
d["s_owner"] = (reg & d["owner_age"].notna() & d["female"].notna()).astype(int)   # main owner-linked sample
d["s_analysis_time"] = d["time_fe"].notna().astype(int)

ML_X = ["owner_age", "female", "luluwa", "work_gov", "family_gov", "employed", "years_avenue",
        "walls_good", "roof_metal", "coethnic_chief", "chief_luluwa", "chief_age",
        "dist_city_center", "log_transport_cost", "log_pred_value", "assigned_rate"]
for c in ML_X:
    d[f"miss_{c}"] = d[c].isna().astype(int)

keep = (["compound1", "a7", "stratum", "tmt", "local", "time_fe", "house_band", "today_alt", "commune_id",
         "tmt_2016", "taxes_paid", "taxes_paid_amt", "exempt", "why_exempt"]
        + list(reasons) + ["exempt_pension_hand", "exempt_other_all", "enum_disagrees", "exempt_enum",
                           "bribe_midline", "know_eachother"]
        + ["owner_age", "age_guessed", "female", "luluwa", "work_gov", "family_gov", "employed", "salaried",
           "years_avenue", "walls_good", "walls_brick", "roof_metal", "assigned_rate", "owner_tribe", "owner_subtribe",
           "elig_age55", "owner_male_under55", "disc_age", "just_age"] + [f"disc_age{c}" for c in ALT_AGES]
        + ["disc_widow", "disc_any", "exempt_no_basis",
           "chief_tribe", "chief_subtribe", "chief_age", "chief_female", "chief_edu", "chief_luluwa",
           "coethnic_chief", "cosubtribe_chief", "dist_city_center", "transport_costs", "log_transport_cost",
           "pred_value", "log_pred_value", "n_adjacent", "share_adj_local", "share_adj_chief",
           "s_registered", "s_midline", "s_owner", "s_analysis_time"]
        + [f"miss_{c}" for c in ML_X])
final = d[keep].copy()
final.to_csv(INTER / "final_property.csv.gz", index=False, compression="gzip")

# neighbourhood file: arm, strata, chief traits, 2016 compliance, sample counts
ra = rd("0.7randomization/randomization_assignment.csv")[["a7", "joncomp2016", "chef_collect_ever", "salongo_freq", "appoint_yr"]]
nb = (final.groupby("a7").agg(tmt=("tmt", "first"), local=("local", "first"), stratum=("stratum", "first"),
                              n_properties=("compound1", "size"), n_registered=("s_registered", "sum"),
                              n_owner=("s_owner", "sum"), chief_age=("chief_age", "first"),
                              chief_female=("chief_female", "first"), chief_luluwa=("chief_luluwa", "first"),
                              chief_edu=("chief_edu", "first"), transport_costs=("transport_costs", "first"),
                              dist_city_center=("dist_city_center", "mean"), share_adj_local=("share_adj_local", "first"),
                              n_adjacent=("n_adjacent", "first"))
      .reset_index().merge(ra, on="a7", how="left"))
nb.to_csv(INTER / "final_neighbourhood.csv", index=False)

labels = {
    "local": "Treatment D: 1 = chief collects (tmt=2), 0 = state agents (tmt=1)",
    "exempt": "Collector registered the property as exempt (registration)",
    "exempt_age": "Exempt, stated reason old age (why_exempt=2)",
    "exempt_widow": "Exempt, stated reason widow (why_exempt=5)",
    "exempt_pension_hand": "Exempt, stated reason state pensioner or disability (3,4)",
    "exempt_other_all": "Exempt for any reason other than old age or widow",
    "enum_disagrees": "Independent enumerator's exemption call differs from collector's",
    "bribe_midline": "Paid a bribe, midline survey (authors' bribe_combined)",
    "owner_age": "Owner age (midline; guessed bands set to mid-point as in the do-file)",
    "elig_age55": "Owner aged 55 or older (legal old-age threshold)",
    "disc_age": "Exempt for old age although owner is under 55",
    "just_age": "Exempt for old age and owner is 55 or older",
    "disc_widow": "Exempt as widow although owner is male",
    "disc_any": "disc_age or disc_widow",
    "exempt_no_basis": "Exempt although owner is a man under 55 and not a pensioner or disabled",
    "coethnic_chief": "Owner's tribe equals the tribe of the neighbourhood chief (pre-randomization chief survey)",
    "cosubtribe_chief": "Owner's sub-tribe (clan) equals the chief's sub-tribe",
    "share_adj_local": "Share of adjacent neighbourhoods assigned to Local",
    "s_owner": "Main owner-linked sample: exemption recorded and owner age and sex observed",
}
pd.DataFrame({"variable": final.columns,
              "label": [labels.get(c, "") for c in final.columns],
              "n_nonmissing": final.notna().sum().values}).to_csv(INTER / "variable_dictionary.csv", index=False)

print(f"final_property: {final.shape}; registered={final.s_registered.sum()}, owner sample={final.s_owner.sum()}, "
      f"neighbourhoods={final.a7.nunique()}")
