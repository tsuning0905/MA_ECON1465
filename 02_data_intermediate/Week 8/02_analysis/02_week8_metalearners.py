"""
02_week8_metalearners.py
========================
Week 8 report, RCT track (called by 00_master/00_master.py after 01_preanalysis.py).

  Y = exempt        1 = collector registered the property as tax-exempt
  T = local         1 = neighbourhood randomly assigned to Local (chief), 0 = Central
  X = owner_age, owner_female, main_tribe (Luluwa), job_gov   (pre-treatment covariates = COVS)

Sample: the FULL experimental sample (not the Week 6 biased sample).

Sections (match the report)
  0. Benchmark tau_RCT: OLS of Y on T + X, SE clustered by neighbourhood (a7)
  1. Base learner: GradientBoostingRegressor, hyper-parameters picked by 5-fold
     GroupKFold CV (folds = neighbourhoods) on the S-learner outcome model
                                          -> 03_output/week8/table0_gbr_cv.csv
  2. S-, T-, X-learner (econml.metalearners), CATE for every property
                                          -> data_intermediate/week8_cate.csv.gz
  3. ATE = mean CATE, bootstrap SE / 95% CI (resample neighbourhoods, refit all learners)
                                          -> 03_output/week8/table1_ate.{csv,tex}
                                          -> 03_output/week8/bootstrap_ate_draws.csv
  4. CATE histograms                      -> 03_output/week8/figure1_cate_hist.{pdf,png}
  5. CATE by owner age vs experimental estimate by age bin
                                          -> 03_output/week8/figure2_cate_by_age.{pdf,png}
  6. Mean CATE by subgroup vs experimental subgroup ATE
                                          -> 03_output/week8/table2_subgroups.{csv,tex}
  All numbers quoted in the report        -> 03_output/week8/numbers.json

Input : data_intermediate/final_exemption.csv.gz (from 01_preanalysis.py)
Seed  : 1465 (GBR random_state, CV folds, bootstrap).
Packages: pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, scikit-learn 1.9.1,
          matplotlib 3.11.2, econml 0.17.0 (pinned in requirements.txt).
"""
from __future__ import annotations

import json
import os
import warnings
from itertools import product
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import GroupKFold, cross_val_score
from econml.metalearners import SLearner, TLearner, XLearner

warnings.filterwarnings("ignore")

ROOT = Path(os.environ.get("ECO1465_ROOT", Path(__file__).resolve().parents[1]))
INTER = ROOT / "data_intermediate"
OUT = ROOT / "03_output" / "week8"
OUT.mkdir(parents=True, exist_ok=True)

SEED = 1465
N_BOOT = 200
COVS = ["owner_age", "owner_female", "main_tribe", "job_gov"]
NUM: dict = {"seed": SEED, "n_boot": N_BOOT, "covariates": COVS}

raw = pd.read_csv(INTER / "final_exemption.csv.gz")
full = raw.dropna(subset=["exempt", "local"] + COVS).reset_index(drop=True)
NUM["n_full"], NUM["n_local"] = len(full), int(full["local"].sum())
NUM["n_central"], NUM["n_neigh"] = int((1 - full["local"]).sum()), int(full["a7"].nunique())

# ---------------------------------------------------------------------------
# 4. Week 8: S-, T-, X-learners on the FULL experimental sample
# ---------------------------------------------------------------------------
# Needs from the top of the script: full, COVS, SEED, NUM, OUT, np, pd, plt,
# GradientBoostingRegressor, SLearner, TLearner, XLearner.
#
#   Y = exempt        (outcome)
#   T = local         (randomised treatment)
#   X = owner_age, owner_female, main_tribe, job_gov   (pre-treatment covariates = COVS)

Y = full["exempt"].to_numpy(dtype=float)
T = full["local"].to_numpy(dtype=int)
X = full[COVS].to_numpy(dtype=float)
G = full["a7"].to_numpy()

# 4.0 Benchmark (same regression as Weeks 6-7)
m_rct = smf.ols("exempt ~ local + " + " + ".join(COVS), full) \
    .fit(cov_type="cluster", cov_kwds={"groups": full["a7"]})
NUM["tau_rct"], NUM["se_rct"] = float(m_rct.params["local"]), float(m_rct.bse["local"])
NUM["tau_dim"] = float(Y[T == 1].mean() - Y[T == 0].mean())

# 4.1 Base learner: tune GBR once by grouped CV on the S-learner outcome model mu(T, X)
grid = {"max_depth": [2, 3], "n_estimators": [100, 300], "min_samples_leaf": [20, 100]}
XT = np.column_stack([T, X])
cv = GroupKFold(n_splits=5, shuffle=True, random_state=SEED)
cv_rows = []
for md, ne, ml in product(*grid.values()):
    gbr = GradientBoostingRegressor(max_depth=md, n_estimators=ne, min_samples_leaf=ml,
                                    learning_rate=0.05, random_state=SEED)
    mse = -cross_val_score(gbr, XT, Y, groups=G, cv=cv, scoring="neg_mean_squared_error").mean()
    cv_rows.append({"max_depth": md, "n_estimators": ne, "min_samples_leaf": ml, "cv_mse": mse})
cv_tab = pd.DataFrame(cv_rows).sort_values("cv_mse").reset_index(drop=True)
cv_tab.to_csv(OUT / "table0_gbr_cv.csv", index=False)
BEST = {k: int(cv_tab.loc[0, k]) for k in grid}
NUM["gbr_best"] = BEST
NUM["cv_mse_best"] = float(cv_tab.loc[0, "cv_mse"])
NUM["mse_constant"] = float(Y.var())


def gbr():
    return GradientBoostingRegressor(learning_rate=0.05, random_state=SEED, **BEST)


def fit_learners(y, t, x):
    """Return CATE arrays (S, T, X) evaluated on the full-sample X."""
    s = SLearner(overall_model=gbr()).fit(y, t, X=x)
    tl = TLearner(models=gbr()).fit(y, t, X=x)
    # X-learner: propensity is known by design (neighbourhood randomisation), so a
    # constant model = share Local; no estimated score is needed in an RCT.
    xl = XLearner(models=gbr(), propensity_model=DummyClassifier(strategy="prior")).fit(y, t, X=x)
    return {"S": s.effect(X), "T": tl.effect(X), "X": xl.effect(X)}


# 4.2 CATEs on the full sample
cate = fit_learners(Y, T, X)
LEARNERS = ["S", "T", "X"]
NAMES = {"S": "S-learner", "T": "T-learner", "X": "X-learner"}
cate_df = full[["a7", "local", "exempt"] + COVS].copy()
for k in LEARNERS:
    cate_df[f"cate_{k}"] = cate[k]
cate_df.to_csv(INTER / "week8_cate.csv.gz", index=False)

# 4.3 ATE + cluster bootstrap (resample neighbourhoods, refit every learner, CATE on full X)
rng = np.random.default_rng(SEED)
groups = {k: v.index.values for k, v in full.groupby("a7")}
keys = np.array(list(groups))
boot = np.empty((N_BOOT, 3))
for b in range(N_BOOT):
    idx = np.concatenate([groups[k] for k in rng.choice(keys, size=len(keys), replace=True)])
    cb = fit_learners(Y[idx], T[idx], X[idx])
    boot[b] = [cb[k].mean() for k in LEARNERS]
pd.DataFrame(boot, columns=[f"ate_{k}" for k in LEARNERS]).to_csv(OUT / "bootstrap_ate_draws.csv",
                                                                  index_label="draw")

rows = []
for j, k in enumerate(LEARNERS):
    c = cate[k]
    rows.append({"learner": NAMES[k], "ate": c.mean(), "boot_se": boot[:, j].std(ddof=1),
                 "ci_lo": np.percentile(boot[:, j], 2.5), "ci_hi": np.percentile(boot[:, j], 97.5),
                 "gap_vs_rct": c.mean() - NUM["tau_rct"],
                 "cate_sd": c.std(), "cate_p05": np.percentile(c, 5), "cate_p50": np.median(c),
                 "cate_p95": np.percentile(c, 95), "share_negative": (c < 0).mean()})
ate_tab = pd.DataFrame(rows)
ate_tab.to_csv(OUT / "table1_ate.csv", index=False)
for r, k in zip(ate_tab.itertuples(), LEARNERS):
    NUM[f"ate_{k}"] = {c: float(getattr(r, c)) for c in ate_tab.columns if c != "learner"}
NUM["corr_cate"] = {f"{a}{b}": float(np.corrcoef(cate[a], cate[b])[0, 1])
                    for a, b in [("S", "T"), ("S", "X"), ("T", "X")]}

# 4.4 Figure 1: CATE histograms
COL = {"S": "#4C72B0", "T": "#DD8452", "X": "#55A868"}
fig, axes = plt.subplots(1, 3, figsize=(7.5, 2.4), sharey=True)
bins = np.linspace(-0.25, 0.30, 45)
for ax, k in zip(axes, LEARNERS):
    ax.hist(np.clip(cate[k], bins[0], bins[-1]), bins=bins, color=COL[k], alpha=0.85)
    ax.axvline(cate[k].mean(), color="black", lw=1.2, label=f"ATE {cate[k].mean():.3f}")
    ax.axvline(NUM["tau_rct"], color="#C0392B", ls="--", lw=1.0,
               label=rf"$\hat\tau^{{RCT}}$ {NUM['tau_rct']:.3f}")
    ax.axvline(0, color="grey", lw=0.5)
    ax.set_title(f"{NAMES[k]} (SD {cate[k].std():.3f})", fontsize=8.5)
    ax.set_xlabel(r"CATE: change in $\Pr(\mathrm{exempt})$", fontsize=7.5)
    ax.tick_params(labelsize=7)
    ax.legend(fontsize=6, frameon=False, loc="upper right")
axes[0].set_ylabel("Properties", fontsize=7.5)
fig.suptitle(f"Full experimental sample (N = {NUM['n_full']:,}): CATE of Local on exemption",
             fontsize=9)
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure1_cate_hist.{ext}", dpi=200)
plt.close(fig)

# 4.5 Figure 2: CATE by owner age vs the experimental estimate within age bins
AGE_BINS = [0, 36, 46, 55, 65, 75, 200]          # left-closed, so 55 starts a bin (legal threshold)
AGE_LAB = ["<36", "36-45", "46-54", "55-64", "65-74", "75+"]
cate_df["age_bin"] = pd.cut(cate_df["owner_age"], AGE_BINS, labels=AGE_LAB, right=False)
exp_age = []
for lab, d in cate_df.groupby("age_bin", observed=True):
    m = smf.ols("exempt ~ local", d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})
    exp_age.append({"age_bin": lab, "n": len(d), "tau": m.params["local"], "se": m.bse["local"],
                    **{f"cate_{k}": d[f"cate_{k}"].mean() for k in LEARNERS}})
exp_age = pd.DataFrame(exp_age)
exp_age.to_csv(OUT / "figure2_cate_by_age.csv", index=False)
NUM["by_age"] = exp_age.drop(columns="age_bin").set_index(exp_age["age_bin"].astype(str)) \
    .to_dict(orient="index")

fig, ax = plt.subplots(figsize=(6.0, 3.4))
xs = np.arange(len(exp_age))
ax.errorbar(xs, exp_age["tau"], yerr=1.96 * exp_age["se"], fmt="o", color="black", ms=4,
            capsize=3, lw=0.9, label="Experimental: diff. in means within bin (95% CI)")
for j, k in enumerate(LEARNERS):
    ax.plot(xs + (j - 1) * 0.12, exp_age[f"cate_{k}"], marker="s", ms=3.5, lw=1.2, color=COL[k],
            label=f"{NAMES[k]}: mean CATE in bin")
ax.axhline(0, color="grey", lw=0.5)
ax.axhline(NUM["tau_rct"], color="#C0392B", ls="--", lw=0.8, label=r"$\hat\tau^{RCT}$")
ax.axvline(2.5, color="grey", ls=":", lw=0.8)
ax.text(2.55, -0.075, "legal 'elderly' threshold (55)", fontsize=6, va="bottom")
ax.set_xticks(xs)
ax.set_xticklabels([f"{a}\n(n={n:,})" for a, n in zip(exp_age["age_bin"], exp_age["n"])], fontsize=7)
ax.set_xlabel("Owner age", fontsize=8)
ax.set_ylabel("Effect of Local on exempt", fontsize=8)
ax.set_title("Full experimental sample: heterogeneity by owner age", fontsize=9)
ax.legend(fontsize=6, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.32), ncol=3)
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure2_cate_by_age.{ext}", dpi=200, bbox_inches="tight")
plt.close(fig)

# 4.6 Table 2: mean CATE by subgroup vs experimental subgroup ATE
SUB = [("owner_age >= 55", "Owner 55 or older"), ("owner_age < 55", "Owner under 55"),
       ("owner_female == 1", "Owner female"), ("owner_female == 0", "Owner male"),
       ("main_tribe == 1", "Owner Luluwa"), ("main_tribe == 0", "Owner not Luluwa"),
       ("job_gov == 1", "Owner works for state"), ("job_gov == 0", "Owner not state")]
sub_rows = []
for q, lab in SUB:
    d = cate_df.query(q)
    m = smf.ols("exempt ~ local", d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})
    sub_rows.append({"subgroup": lab, "n": len(d), "tau_exp": m.params["local"], "se_exp": m.bse["local"],
                     **{f"cate_{k}": d[f"cate_{k}"].mean() for k in LEARNERS}})
sub_tab = pd.DataFrame(sub_rows)
sub_tab.to_csv(OUT / "table2_subgroups.csv", index=False)
NUM["subgroups"] = sub_tab.set_index("subgroup").to_dict(orient="index")


# LaTeX tables
def f3(x):
    return f"{x:.3f}"


with open(OUT / "table1_ate.tex", "w") as fh:
    fh.write("\\begin{tabular}{lcccccccc}\n\\toprule\n"
             " & \\multicolumn{3}{c}{ATE (mean CATE)} & & \\multicolumn{4}{c}{CATE distribution}\\\\\n"
             "\\cmidrule(lr){2-4}\\cmidrule(lr){6-9}\n"
             "Learner & $\\hat\\tau$ & SE$^b$ & 95\\% CI$^b$ & $\\hat\\tau-\\hat\\tau^{RCT}$ & SD & P5 & P95 & Share $<0$\\\\\n\\midrule\n")
    fh.write(f"Benchmark $\\hat\\tau^{{RCT}}$ (OLS, $Y$ on $T$ and $X$) & {f3(NUM['tau_rct'])} & "
             f"{f3(NUM['se_rct'])}$^c$ & & & & & & \\\\\n\\addlinespace\n")
    for r in ate_tab.itertuples():
        fh.write(f"{r.learner} & {f3(r.ate)} & {f3(r.boot_se)} & [{f3(r.ci_lo)}, {f3(r.ci_hi)}] & "
                 f"{r.gap_vs_rct:+.3f} & {f3(r.cate_sd)} & {f3(r.cate_p05)} & {f3(r.cate_p95)} & "
                 f"{r.share_negative:.2f}\\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

with open(OUT / "table2_subgroups.tex", "w") as fh:
    fh.write("\\begin{tabular}{lrcccc}\n\\toprule\n"
             " & & Experimental & \\multicolumn{3}{c}{Mean CATE in subgroup}\\\\\n\\cmidrule(lr){4-6}\n"
             "Subgroup & $N$ & diff.\\ in means (SE$^c$) & S & T & X\\\\\n\\midrule\n")
    for i, r in enumerate(sub_tab.itertuples()):
        fh.write(f"{r.subgroup} & {r.n:,} & {f3(r.tau_exp)} ({f3(r.se_exp)}) & {f3(r.cate_S)} & "
                 f"{f3(r.cate_T)} & {f3(r.cate_X)}\\\\\n")
        if i % 2 == 1 and i < len(sub_tab) - 1:
            fh.write("\\addlinespace\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

(OUT / "numbers.json").write_text(json.dumps(NUM, indent=2, default=float))
print(cv_tab.round(5).to_string())
print(ate_tab.round(4).to_string())
print(exp_age.round(3).to_string())
print(sub_tab.round(3).to_string())
print({k: NUM[k] for k in ["tau_rct", "se_rct", "tau_dim", "gbr_best", "corr_cate"]})
