"""
01_preanalysis_week3.py
=======================
Week-3 analysis dataset for the research question:

    Does replacing central-state collectors (Central, tmt==1) with local chiefs
    (Local, tmt==2) change how often properties are exempted from the property
    tax, and for which households is the effect larger?

Inputs  (read-only, never overwritten):
    0_RawData/0.6campaign/registration_noPII.csv   property registration visit
                                                   (tmt, exempt, why_exempt, house)
    0_RawData/0.1Baseline/baseline_noPII.csv       2017 household baseline survey
                                                   (pre-treatment covariates)
    0_RawData/0.7randomization/stratum.csv         randomization strata
    0_RawData/0.2chief/chief_tribe_info.csv        tribe of chief and state collectors

Output:
    data_intermediate/week3_exemption_analysis.csv  one row per property

Run from 00_master/00_master.py, or directly:  python 01_preanalysis/01_preanalysis_week3.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# 0. Paths (relative to the repo root, so nobody has to edit them)
# ---------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "0_RawData"
INTER = ROOT / "data_intermediate"
INTER.mkdir(exist_ok=True)

SPECIAL_CODES = [88, 97, 98, 99, 888, 999, 8888, 9999, 99999, 999999, -1]
LEGAL_SENIOR_AGE = 55  # Balan et al. (2022), Sec. I: owners aged 55+ are legally exempt


def stata_date(s: pd.Series) -> pd.Series:
    """Date string -> Stata daily date (days since 1960-01-01), used for the paper's time bins."""
    return (pd.to_datetime(s, errors="coerce") - pd.Timestamp("1960-01-01")).dt.days


# ---------------------------------------------------------------------------
# 1. Registration visits: treatment, exemption decision, house type
# ---------------------------------------------------------------------------
reg = pd.read_csv(RAW / "0.6campaign" / "registration_noPII.csv", low_memory=False)

# Keep the Central vs Local comparison only, drop the pilot neighbourhoods,
# and keep properties where the collector recorded an exemption decision.
reg = reg[reg["tmt"].isin([1, 2]) & (reg["pilot"] == 0) & reg["exempt"].notna()].copy()
reg = reg.drop_duplicates("compound1")

reg["local"] = (reg["tmt"] == 2).astype(int)                 # treatment dummy
reg["exempt"] = reg["exempt"].astype(int)                    # outcome: 1 = exempted
# Reason for exemption (why_exempt codes: 2 senior, 3 gov. pension, 4 disabled, 5 widow)
reg["exempt_senior"] = (reg["why_exempt"] == 2).astype(int)
reg["exempt_widow"] = (reg["why_exempt"] == 5).astype(int)
reg["exempt_other"] = (reg["exempt"].eq(1) & ~reg["why_exempt"].isin([2, 5])).astype(int)

# Time fixed effects: same two-month bins as Table A9.do (Central vs Local cut points)
reg["today_alt"] = stata_date(reg["today"])
reg["time_fe"] = pd.cut(reg["today_alt"], bins=[21355, 21415, 21475, 21532],
                        right=False, labels=False)
reg["time_fe"] = reg["time_fe"].fillna(-1).astype(int)       # -1 = date missing

reg = reg[["compound1", "a7", "local", "tmt", "exempt", "exempt_senior", "exempt_widow",
           "exempt_other", "why_exempt", "house", "time_fe"]]

# ---------------------------------------------------------------------------
# 2. Baseline (2017) household covariates: all measured BEFORE randomization
# ---------------------------------------------------------------------------
bl = pd.read_csv(RAW / "0.1Baseline" / "baseline_noPII.csv", low_memory=False)
bl_cols = ["age", "sex", "edu", "inc_mo", "hh_size", "kga_born", "work_gov1",
           "renters_b", "tribe"] + [f"possessions_{k}" for k in range(1, 7)]

# A baseline household links to a property through compound_code (or compound_code2)
links = []
for key in ["compound_code", "compound_code2"]:
    tmp = bl.loc[bl[key].notna() & (bl[key] != 999999), [key] + bl_cols]
    links.append(tmp.rename(columns={key: "compound1"}))
bl = pd.concat(links).drop_duplicates("compound1", keep="first")

num = [c for c in bl_cols if c != "tribe"]
bl[num] = bl[num].replace(SPECIAL_CODES, np.nan)
bl["tribe"] = bl["tribe"].replace([".", "8888", "9999", ".d", ".n"], np.nan)

bl["female"] = (bl["sex"] == 2).astype(float).where(bl["sex"].notna())
bl["senior_bl"] = (bl["age"] >= LEGAL_SENIOR_AGE).astype(float).where(bl["age"].notna())
bl["log_income"] = np.log1p(bl["inc_mo"])
bl["assets"] = bl[[f"possessions_{k}" for k in range(1, 7)]].sum(axis=1, min_count=1)
bl["luluwa"] = (bl["tribe"] == "LULUWA").astype(float).where(bl["tribe"].notna())

df = reg.merge(bl, on="compound1", how="inner", validate="1:1")  # baseline sample only

# ---------------------------------------------------------------------------
# 3. Co-ethnicity with the collector (same rule as Table A9.do)
#    Local: owner's tribe == chief's tribe; Central: owner's tribe == either state agent's tribe
# ---------------------------------------------------------------------------
ct = pd.read_csv(RAW / "0.2chief" / "chief_tribe_info.csv", low_memory=False)
ct = ct[["a7", "chef_tribe", "col1_tribe", "col2_tribe"]].drop_duplicates("a7")
for c in ["chef_tribe", "col1_tribe", "col2_tribe"]:
    ct[c] = ct[c].replace([".", "9999", "8888", "7777", "0"], np.nan)
df = df.merge(ct, on="a7", how="left", validate="m:1")

local_match = df["tribe"] == df["chef_tribe"]
central_match = (df["tribe"] == df["col1_tribe"]) | (df["tribe"] == df["col2_tribe"])
df["coethnic"] = np.where(df["local"] == 1, local_match, central_match).astype(float)
known = df["tribe"].notna() & np.where(df["local"] == 1, df["chef_tribe"].notna(),
                                       df["col1_tribe"].notna() | df["col2_tribe"].notna())
df.loc[~known, "coethnic"] = np.nan

# ---------------------------------------------------------------------------
# 4. "Discretionary" (not legally justified) senior exemption
#    Exempted for old age although the owner was under 55 at baseline (age is one year older
#    at registration, so we allow one year: baseline age < 54 counts as unjustified).
# ---------------------------------------------------------------------------
df["unjust_senior"] = (df["exempt_senior"].eq(1) & (df["age"] < LEGAL_SENIOR_AGE - 1)).astype(float)
df.loc[df["age"].isna(), "unjust_senior"] = np.nan

# ---------------------------------------------------------------------------
# 5. Missing covariates: fill with the sample mean and add a missing dummy, so every
#    model (OLS / Ridge / Lasso) uses the same observations.
# ---------------------------------------------------------------------------
COVARS = ["age", "female", "edu", "log_income", "hh_size", "kga_born", "work_gov1",
          "renters_b", "assets", "luluwa", "coethnic"]
for c in COVARS:
    if df[c].isna().any():
        df[f"{c}_miss"] = df[c].isna().astype(int)
        df[c] = df[c].fillna(df[c].mean())

df = df.merge(pd.read_csv(RAW / "0.7randomization" / "stratum.csv")[["a7", "stratum"]],
              on="a7", how="left", validate="m:1")

keep = (["compound1", "a7", "stratum", "time_fe", "house", "local", "tmt", "exempt",
         "exempt_senior", "exempt_widow", "exempt_other", "unjust_senior", "senior_bl"]
        + COVARS + [c for c in df.columns if c.endswith("_miss")])
df = df[keep].sort_values("compound1")
df.to_csv(INTER / "week3_exemption_analysis.csv", index=False)

print(f"[01_preanalysis_week3] saved {len(df):,} properties in {df['a7'].nunique()} neighbourhoods")
print(df.groupby("local")[["exempt", "exempt_senior", "exempt_widow", "unjust_senior"]].mean().round(3))
