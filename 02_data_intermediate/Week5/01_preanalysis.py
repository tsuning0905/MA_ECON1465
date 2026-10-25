"""
01_preanalysis.py  --  ECO1465 Week 5 report, Tsu Ning Tsao
Reads raw data (never overwritten), builds variables, saves analysis files to
data_intermediate/.

Inputs (0_RawData/)
  0.5tax/taxroll_noPII.csv                       2018 tax roll, one row per compound; Exempte = exemption reason
  0.7randomization/randomization_assignment.csv  treatment arm and stratum per neighborhood (a7)
  0.1Baseline/baseline_noPII.csv                 2017 household baseline (pre-treatment covariates)
  0.2chief/chief_survey_randbasis_noPII.csv      pre-randomization chief survey (chief tribe)
  0.8geography/property_values_MLestimates.csv   predicted property value per compound
  0.4endline/endline_round1_noPII.csv            endline survey (self-reported bribe)
Outputs (data_intermediate/)
  w5_compound.csv   compound level, Central (treatment 1) and Local (treatment 2) only
  w5_endline.csv    endline respondents, Central and Local only
"""
import os
import numpy as np
import pandas as pd

ROOT = os.environ.get("PROJ_ROOT", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "0_RawData")
INT = os.path.join(ROOT, "data_intermediate")
os.makedirs(INT, exist_ok=True)

# ---- 1. Treatment assignment ------------------------------------------------
rand = pd.read_csv(os.path.join(RAW, "0.7randomization/randomization_assignment.csv"))
rand = rand[["a7", "treatment", "stratum", "chef_collect_ever"]]

# ---- 2. Outcomes from the tax roll -----------------------------------------
tax = pd.read_csv(os.path.join(RAW, "0.5tax/taxroll_noPII.csv"), low_memory=False)
tax = tax.merge(rand, on="a7", how="left")
tax = tax[tax["treatment"].isin([1, 2])].copy()
tax["local"] = (tax["treatment"] == 2).astype(int)
tax["exempt"] = tax["Exempte"].notna().astype(int)
tax["exempt_elderly"] = (tax["Exempte"] == "Troisieme age").astype(int)
tax["exempt_widow"] = (tax["Exempte"] == "Veuve").astype(int)
tax["exempt_other"] = tax["exempt"] - tax["exempt_elderly"] - tax["exempt_widow"]

# ---- 3. Pre-treatment household covariates (2017 baseline) ------------------
# age_head is almost entirely missing (17 values); respondent age is used.
b = pd.read_csv(os.path.join(RAW, "0.1Baseline/baseline_noPII.csv"), low_memory=False)
b = b[b["compound_code"].notna()].copy()
b["female"] = np.where(b["sex_r"].isin(["Male", "Female"]), (b["sex_r"] == "Female").astype(float), np.nan)
for c in ["age", "edu", "hh_size", "job1", "ave_move"]:
    b[c] = pd.to_numeric(b[c], errors="coerce")
b["no_job"] = np.where(b["job1"].isna(), np.nan, (b["job1"] == 0).astype(float))
base = (b.groupby("compound_code")
          .agg(age=("age", "max"), female=("female", "max"), edu=("edu", "mean"),
               hh_size=("hh_size", "mean"), no_job=("no_job", "max"),
               year_moved=("ave_move", "mean"), tribe=("tribe", "first"))
          .reset_index())
base["old"] = np.where(base["age"].isna(), np.nan, (base["age"] >= 60).astype(float))

# ---- 4. Chief tribe -> pre-treatment coethnic indicator ---------------------
# chief_tribe_info.csv records the chief tribe only in Local neighborhoods, so the
# pre-randomization chief survey (covers all arms) is used; modal tribe per a7.
cs = pd.read_csv(os.path.join(RAW, "0.2chief/chief_survey_randbasis_noPII.csv"),
                 low_memory=False, usecols=["a7", "tribe"])
cs = cs[cs["tribe"].notna() & (cs["tribe"] != "INSEREZ_SA_TRIBU")]
chief = cs.groupby("a7")["tribe"].agg(lambda s: s.mode().iloc[0]).rename("chef_tribe").reset_index()

# ---- 5. Property value (machine-learning estimate, all compounds) -----------
pv = pd.read_csv(os.path.join(RAW, "0.8geography/property_values_MLestimates.csv"),
                 usecols=["compound1", "pred_value"])
pv["log_value"] = np.log(pv["pred_value"])

# ---- 6. Merge and derived variables -----------------------------------------
df = (tax.merge(base, left_on="compound1", right_on="compound_code", how="left")
         .merge(chief, on="a7", how="left")
         .merge(pv[["compound1", "log_value"]], on="compound1", how="left"))
df["linked"] = df["age"].notna().astype(int)
df["coethnic"] = np.where(df["tribe"].isna() | df["chef_tribe"].isna(), np.nan,
                          (df["tribe"] == df["chef_tribe"]).astype(float))
df["unjustified_elderly"] = np.where(df["old"].isna(), np.nan,
                                     ((df["exempt_elderly"] == 1) & (df["old"] == 0)).astype(float))

keep = ["compound1", "a7", "stratum", "treatment", "local", "chef_collect_ever",
        "exempt", "exempt_elderly", "exempt_widow", "exempt_other",
        "age", "old", "female", "edu", "hh_size", "no_job", "year_moved", "log_value",
        "tribe", "chef_tribe", "coethnic", "linked", "unjustified_elderly"]
df[keep].to_csv(os.path.join(INT, "w5_compound.csv"), index=False)

# ---- 7. Endline bribe --------------------------------------------------------
end = pd.read_csv(os.path.join(RAW, "0.4endline/endline_round1_noPII.csv"),
                  low_memory=False, usecols=["a7", "bribe"])
end = end.merge(rand[["a7", "treatment", "stratum"]], on="a7", how="left")
end = end[end["treatment"].isin([1, 2])].copy()
end["local"] = (end["treatment"] == 2).astype(int)
end.to_csv(os.path.join(INT, "w5_endline.csv"), index=False)

print(f"w5_compound.csv: {len(df):,} compounds, {df['a7'].nunique()} neighborhoods, "
      f"{int(df['linked'].sum()):,} linked to baseline")
print(f"w5_endline.csv: {len(end):,} respondents, {int(end['bribe'].notna().sum()):,} answered bribe")
