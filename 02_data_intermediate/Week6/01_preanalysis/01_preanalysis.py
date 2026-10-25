"""
01_preanalysis.py
=================
Step 1 of the pipeline (called by 00_master/00_master.py).

What it does
  A. Stages the raw files: 0_RawData/ is split into sub-folders, but the
     data-construction port (0_RawData/Data_Construction) reads flat file
     names. We link every raw file into data_intermediate/raw_staging/ and
     unzip the midline .dta there. 0_RawData/ itself is never written to.
  B. Runs 0_RawData/Data_Construction (Python port of
     Dofiles/2_Data_Construction.do). Output:
       data_intermediate/analysis_data.csv.gz        (property level)
  C. Builds the variables for the research question (Local vs Central and
     exemptions / bribes / favouritism) and saves the final dataset:
       data_intermediate/final_exemption.csv.gz      (property level, Central + Local)
       data_intermediate/final_endline.csv.gz        (endline-household level, Central + Local)

Inputs : 0_RawData/**  (read only)
Outputs: data_intermediate/*
"""
from __future__ import annotations

import os
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(os.environ.get("ECO1465_ROOT", Path(__file__).resolve().parents[1]))
RAW = ROOT / "0_RawData"
INTER = ROOT / "data_intermediate"
STAGE = INTER / "raw_staging"
INTER.mkdir(exist_ok=True)
STAGE.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# A. Stage raw files (symlinks, so nothing is copied or overwritten)
# ---------------------------------------------------------------------------
for f in RAW.glob("0.*/*"):
    if f.suffix in {".csv", ".xlsx", ".dta"}:
        link = STAGE / f.name
        if not link.exists():
            link.symlink_to(f.resolve())
mid_zip = RAW / "0.9midline" / "midline_noPII.dta.zip"
if not (STAGE / "midline_noPII.dta").exists():
    with zipfile.ZipFile(mid_zip) as z:
        z.extractall(STAGE)

# ---------------------------------------------------------------------------
# B. Run the data-construction script with local paths
# ---------------------------------------------------------------------------
if not (INTER / "analysis_data.csv.gz").exists():
    src = (RAW / "Data_Construction").read_text(encoding="utf-8")
    start = src.index("# ---- Colab")
    end = src.index("OUT_DIR.mkdir(exist_ok=True)")
    src = (src[:start]
           + f"DATA_DIR = Path(r'{STAGE}')\nOUT_DIR = Path(r'{INTER}')\n"
           + src[end:])
    exec(compile(src, "Data_Construction", "exec"), {"__name__": "data_construction"})

# ---------------------------------------------------------------------------
# C1. Property-level final dataset (registration + monitoring)
# ---------------------------------------------------------------------------
a = pd.read_csv(INTER / "analysis_data.csv.gz", low_memory=False)
a = a[a["tmt"].isin([1, 2])].copy()                  # Central (1) vs Local (2)
a["local"] = (a["tmt"] == 2).astype(int)             # D: 1 = chief collects

# Exemption reason codes in registration (`why_exempt`), matched to the tax-roll
# labels (Exempte): 2 = elderly (troisieme age), 3 = state pensioner,
# 4 = handicapped, 5 = widow, 6 = orphanage, 7 = convent, 8 = church, 9 = school.
w = a["why_exempt"]
a["exempt_elderly"] = np.where(a["exempt"].notna(), ((a["exempt"] == 1) & (w == 2)).astype(float), np.nan)
a["exempt_widow"] = np.where(a["exempt"].notna(), ((a["exempt"] == 1) & (w == 5)).astype(float), np.nan)
a["exempt_otherreason"] = np.where(
    a["exempt"].notna(), ((a["exempt"] == 1) & ~w.isin([2, 5])).astype(float), np.nan)

# Enumerator disagrees with the collector's exemption decision (Table 5, row 2)
a["enum_disagrees_exempt"] = np.where(
    a["exempt"].notna() & a["exempt_enum"].notna(),
    (a["exempt"] != a["exempt_enum"]).astype(float), np.nan)

# Owner characteristics (monitoring survey; fixed traits, not moved by treatment)
a["owner_age"] = a["age_prop"].where(a["age_prop"].between(15, 110))
a["owner_female"] = 1 - a["sex_prop"]                 # sex_prop: 1 = male, 0 = female
a["owner_old"] = np.where(a["owner_age"].notna(), (a["owner_age"] >= 55).astype(float), np.nan)

# "Discretionary" (unjustified) exemption: the collector cites a reason the
# owner's own traits contradict. Legal age threshold for the elderly
# exemption is 55 (paper, Section IA).
#   elderly reason but owner younger than 55, or widow reason but owner is male
unjust = (((a["exempt"] == 1) & (w == 2) & (a["owner_age"] < 55))
          | ((a["exempt"] == 1) & (w == 5) & (a["owner_female"] == 0)))
known = a["exempt"].notna() & a["owner_age"].notna() & a["owner_female"].notna()
a["exempt_discretionary"] = np.where(known, unjust.astype(float), np.nan)

# House type (1 = low-value periphery house, 2 = high-value)
a["house_high"] = np.where(a["house"].notna(), (a["house"] == 2).astype(float), np.nan)

keep = ["compound1", "a7", "stratum", "tmt", "local", "house", "house_high",
        "exempt", "exempt_enum", "why_exempt", "exempt_elderly", "exempt_widow",
        "exempt_otherreason", "enum_disagrees_exempt", "exempt_discretionary",
        "owner_age", "owner_female", "owner_old", "main_tribe", "job_gov",
        "taxes_paid", "bribe_combined", "today_alt", "today_carto"]
keep = [c for c in keep if c in a.columns]
a[keep].to_csv(INTER / "final_exemption.csv.gz", index=False, compression="gzip")
print("final_exemption:", a[keep].shape)

# ---------------------------------------------------------------------------
# C2. Endline household dataset: favouritism question and bribes (Table 5 logic)
# ---------------------------------------------------------------------------
e = pd.read_csv(STAGE / "endline_round1_noPII.csv", low_memory=False)
e = e[e["tot_complete"] == 1].copy()
e.loc[e["compound_code_prev"].notna() & (e["compound_code_prev"] != 3), "compound_code"] = e["compound_code_prev"]
for c in ["bribe2a", "bribe2b", "bribe3"]:
    if c in e:
        e["bribe"] = e["bribe"].fillna(e[c])
tmt = a.groupby("a7")[["tmt", "stratum"]].max().reset_index()
e = e.merge(tmt, on="a7", how="inner")
e["local"] = (e["tmt"] == 2).astype(int)
# exempt_tribe / exempt_otribe: would the chief exempt someone of his own / another
# tribe? (0/1/2 scale). Table5.do standardises exempt_tribe into coethnic_bias_chief.
e["coethnic_bias_chief"] = (e["exempt_tribe"] - e["exempt_tribe"].mean()) / e["exempt_tribe"].std()
e["bias_gap"] = e["exempt_tribe"] - e["exempt_otribe"]
ekeep = ["code", "compound_code", "a7", "stratum", "tmt", "local", "bribe",
         "exempt_tribe", "exempt_otribe", "coethnic_bias_chief", "bias_gap"]
ekeep = [c for c in ekeep if c in e.columns]
e[ekeep].to_csv(INTER / "final_endline.csv.gz", index=False, compression="gzip")
print("final_endline:", e[ekeep].shape)
