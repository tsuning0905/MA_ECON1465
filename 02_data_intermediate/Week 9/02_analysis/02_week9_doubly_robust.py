"""
02_week9_doubly_robust.py
=========================
Week 9 report, RCT track (called by 00_master/00_master.py after
02_week6_benchmark.py (biased sample) and 02_week7_matching_ipw.py (IPW / matching)).

  D  = local            1 = neighbourhood randomly assigned to Local, 0 = Central
  Y  = exempt           1 = collector registered the property as tax-exempt
  S  = owner_age        selection variable of the Week 6 biased sample (Recipe B, gamma = 1)
  X  = owner_female, main_tribe (Luluwa), job_gov (owner works for the state)

Doubly robust (AIPW) estimation with econml.dr. Two nuisance models, cross-fitted:
  outcome model     mu_d(x) = E[Y | D=d, x]   GradientBoostingRegressor (tuned below)
  propensity model  e(x)    = Pr(D=1 | x)     logistic regression (same logit as Week 7)
Pseudo-outcome  psi = mu1 - mu0 + D (Y - mu1) / e - (1-D) (Y - mu0) / (1-e);  ATE = mean of the
fitted CATE (= mean psi for a final stage with an intercept).

Sections (match the report)
  0. Nuisance-model tuning: grouped 5-fold CV on the biased sample
                                       -> 03_output/week9/table1_nuisance_cv.{csv,tex}
  1. Step 1-2: four EconML DR learners on the biased sample with S, plus one nuisance swap
  2. Step 2: positivity, e_hat(S,X) and e_hat(X) side by side
                                       -> 03_output/week9/figure1_overlap.{pdf,png}
  3. Step 3: the same learners with S removed from the covariates
  4. Step 4: bootstrap CIs, comparison with tau_RCT, tau_naive, IPW, matching
                                       -> 03_output/week9/table2_dr_estimates.{csv,tex}
                                          03_output/week9/table3_comparison.{csv,tex}
                                          03_output/week9/figure2_estimates.{pdf,png}
                                          03_output/week9/bootstrap_dr_draws.csv
  5. Part 2: the main DR learner on the full experimental sample
  All numbers quoted in the report     -> 03_output/week9/numbers.json

Inputs : data_intermediate/final_exemption.csv.gz      (01_preanalysis.py)
         data_intermediate/week6_biased_sample.csv.gz  (02_week6_benchmark.py)
         03_output/week7/numbers.json                  (02_week7_matching_ipw.py)
Seed   : 1465 (learners, CV folds, bootstrap).
Packages: pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, scikit-learn 1.9.1, econml 0.17.0,
          matplotlib 3.11.2, joblib (pinned in requirements.txt).
"""
from __future__ import annotations

import json
import os
import warnings
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from econml.dr import DRLearner, ForestDRLearner, LinearDRLearner, SparseLinearDRLearner
from joblib import Parallel, delayed
from sklearn.ensemble import (GradientBoostingClassifier, GradientBoostingRegressor,
                              RandomForestClassifier, RandomForestRegressor)
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.metrics import log_loss, mean_squared_error
from sklearn.model_selection import GroupKFold

warnings.filterwarnings("ignore")
os.environ.setdefault("PYTHONWARNINGS", "ignore")   # silence warnings in joblib workers too

ROOT = Path(os.environ.get("ECO1465_ROOT", Path(__file__).resolve().parents[1]))
INTER = ROOT / "data_intermediate"
OUT = ROOT / "03_output" / "week9"
OUT.mkdir(parents=True, exist_ok=True)

SEED = 1465
N_BOOT = int(os.environ.get("ECO1465_NBOOT", "200"))   # bootstrap draws; every learner refit per draw
N_FOLDS = 5           # cross-fitting folds, formed by neighbourhood
N_JOBS = int(os.environ.get("ECO1465_JOBS", "-1"))
X_COVS = ["owner_female", "main_tribe", "job_gov"]
COVS_S = ["owner_age"] + X_COVS               # S included
COVS_NOS = X_COVS                             # S removed (hidden-confounder check)
NUM: dict = {"seed": SEED, "n_boot": N_BOOT, "n_folds": N_FOLDS}

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------
raw = pd.read_csv(INTER / "final_exemption.csv.gz")
full = raw.dropna(subset=["exempt", "local"] + COVS_S).reset_index(drop=True)
biased = pd.read_csv(INTER / "week6_biased_sample.csv.gz").reset_index(drop=True)
W7 = json.loads((ROOT / "03_output" / "week7" / "numbers.json").read_text())
NUM.update({"n_full": len(full), "n_biased": len(biased),
            "n_biased_treated": int(biased["local"].sum()),
            "n_biased_control": int((1 - biased["local"]).sum()),
            "n_clusters_biased": int(biased["a7"].nunique())})


def reg(d, covs):
    rhs = " + ".join(["local"] + covs)
    return smf.ols(f"exempt ~ {rhs}", d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})


tau_rct = reg(full, COVS_S).params["local"]
tau_naive = reg(biased, X_COVS).params["local"]
NUM.update({"tau_rct": tau_rct, "tau_naive": tau_naive})
for k in ["tau_rct", "tau_naive"]:               # same code as Weeks 6-7, must agree
    assert abs(NUM[k] - W7[k]) < 1e-10, k

# ---------------------------------------------------------------------------
# 0. Nuisance tuning (grouped CV by neighbourhood, biased sample, S + X)
# ---------------------------------------------------------------------------
# Outcome model: small grid for GBR (lr 0.05 as in Week 8); compared with OLS and a constant.
# Propensity model: logit vs gradient-boosted classifier vs constant, by log loss.
Xb, Yb, Db, Gb = (biased[COVS_S].astype(float).to_numpy(), biased["exempt"].to_numpy(),
                  biased["local"].to_numpy(), biased["a7"].to_numpy())
gkf = GroupKFold(n_splits=N_FOLDS)
XD = np.column_stack([Xb, Db])                 # outcome model sees D as a feature (as EconML does)


def cv_score(make, X, y, kind):
    pred = np.empty(len(y))
    for tr, te in gkf.split(X, y, Gb):
        m = make().fit(X[tr], y[tr])
        pred[te] = m.predict_proba(X[te])[:, 1] if kind == "prob" else m.predict(X[te])
    return log_loss(y, pred) if kind == "prob" else mean_squared_error(y, pred)


grid = [(d, n, leaf) for d in (2, 3) for n in (100, 200) for leaf in (50, 100)]
cv_rows = []
for d, n, leaf in grid:
    mse = cv_score(lambda: GradientBoostingRegressor(learning_rate=0.05, max_depth=d, n_estimators=n,
                                                     min_samples_leaf=leaf, random_state=SEED),
                   XD, Yb, "reg")
    cv_rows.append({"model": "Outcome", "learner": f"GBR depth {d}, {n} trees, leaf {leaf}",
                    "metric": "MSE", "cv_loss": mse, "depth": d, "trees": n, "leaf": leaf})
best = min((r for r in cv_rows), key=lambda r: r["cv_loss"])
GBR_PAR = dict(learning_rate=0.05, max_depth=best["depth"], n_estimators=best["trees"],
               min_samples_leaf=best["leaf"], random_state=SEED)
cv_rows.append({"model": "Outcome", "learner": "OLS (linear in S, X, D)", "metric": "MSE",
                "cv_loss": cv_score(LinearRegression, XD, Yb, "reg")})
cv_rows.append({"model": "Outcome", "learner": "Constant (mean)", "metric": "MSE",
                "cv_loss": float(np.mean((Yb - Yb.mean()) ** 2))})
cv_rows.append({"model": "Propensity", "learner": "Logit on S, X (Week 7)", "metric": "Log loss",
                "cv_loss": cv_score(lambda: LogisticRegression(C=1e6, max_iter=5000), Xb, Db, "prob")})
cv_rows.append({"model": "Propensity", "learner": "Gradient-boosted classifier", "metric": "Log loss",
                "cv_loss": cv_score(lambda: GradientBoostingClassifier(**GBR_PAR), Xb, Db, "prob")})
cv_rows.append({"model": "Propensity", "learner": "Constant (share Local)", "metric": "Log loss",
                "cv_loss": log_loss(Db, np.full(len(Db), Db.mean()))})
cv = pd.DataFrame(cv_rows)
cv.to_csv(OUT / "table1_nuisance_cv.csv", index=False)
NUM["gbr_params"] = {k: v for k, v in GBR_PAR.items() if k != "random_state"}
NUM["cv"] = cv[["model", "learner", "cv_loss"]].to_dict("records")

with open(OUT / "table1_nuisance_cv.tex", "w") as fh:
    fh.write("\\begin{tabular}{llr}\n\\toprule\nModel & Learner & CV loss \\\\\n\\midrule\n")
    show = cv[(cv.model == "Propensity") | ~cv.learner.str.startswith("GBR")
              | (cv.cv_loss == best["cv_loss"])]
    for _, r in show.iterrows():
        tag = " (chosen)" if (r.learner.startswith("GBR") or r.learner.startswith("Logit")) else ""
        fh.write(f"{r.model} ({r.metric}) & {r.learner}{tag} & {r.cv_loss:.4f} \\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")


# ---------------------------------------------------------------------------
# Learners
# ---------------------------------------------------------------------------
def gbr():
    return GradientBoostingRegressor(**GBR_PAR)


def logit():
    return LogisticRegression(C=1e6, max_iter=5000)   # ~unpenalised, same as the Week 7 logit


LEARNERS = {
    # key: (label, constructor)
    "dr_gbr": ("DRLearner, GBR final stage",
               lambda: DRLearner(model_propensity=logit(), model_regression=gbr(), model_final=gbr(),
                                 cv=GroupKFold(N_FOLDS), random_state=SEED)),
    "dr_linear": ("LinearDRLearner (main)",
                  lambda: LinearDRLearner(model_propensity=logit(), model_regression=gbr(),
                                          cv=GroupKFold(N_FOLDS), random_state=SEED)),
    "dr_sparse": ("SparseLinearDRLearner",
                  lambda: SparseLinearDRLearner(model_propensity=logit(), model_regression=gbr(),
                                                cv=GroupKFold(N_FOLDS), random_state=SEED)),
    "dr_forest": ("ForestDRLearner",
                  lambda: ForestDRLearner(model_propensity=logit(), model_regression=gbr(),
                                          cv=GroupKFold(N_FOLDS), n_estimators=200,
                                          min_samples_leaf=50, random_state=SEED)),
    "dr_linear_rf": ("LinearDRLearner, random-forest nuisances",
                     lambda: LinearDRLearner(
                         model_propensity=RandomForestClassifier(n_estimators=200, min_samples_leaf=50,
                                                                 random_state=SEED),
                         model_regression=RandomForestRegressor(n_estimators=200, min_samples_leaf=50,
                                                                random_state=SEED),
                         cv=GroupKFold(N_FOLDS), random_state=SEED)),
}
SPECS = {"S": COVS_S, "noS": COVS_NOS}


def fit_ate(d: pd.DataFrame, key: str, covs: list[str]) -> float:
    X = d[covs].astype(float).to_numpy()
    m = LEARNERS[key][1]()
    m.fit(d["exempt"].to_numpy(), d["local"].to_numpy(), X=X, groups=d["a7"].to_numpy())
    return float(m.ate(X))


def draw_sample(d: pd.DataFrame, seed: int) -> pd.DataFrame:
    """Resample neighbourhoods with replacement (the unit of randomisation)."""
    rng = np.random.default_rng(seed)
    groups = {k: v.index.values for k, v in d.groupby("a7")}
    keys = np.array(list(groups))
    draw = rng.choice(keys, size=len(keys), replace=True)
    # a neighbourhood drawn twice keeps one label, so both copies fall in the same
    # cross-fitting fold (no copy of a test unit sits in the training folds)
    return pd.concat([d.loc[groups[k]] for k in draw], ignore_index=True)


def one_draw(b: int, d: pd.DataFrame, jobs: list[tuple[str, str]]) -> dict:
    db = draw_sample(d, SEED + b)
    return {f"{k}__{s}": fit_ate(db, k, SPECS[s]) for k, s in jobs}


# ---------------------------------------------------------------------------
# 1 + 3. Point estimates on the biased sample, with S and with S removed
# ---------------------------------------------------------------------------
point = {f"{k}__{s}": fit_ate(biased, k, SPECS[s]) for k in LEARNERS for s in SPECS}

# cross-fitted nuisances of the main learner: overlap + a transparent AIPW by hand
def nuisances(d, covs):
    X = d[covs].astype(float).to_numpy()
    D, Y, G = d["local"].to_numpy(), d["exempt"].to_numpy(), d["a7"].to_numpy()
    e, m1, m0 = np.empty(len(d)), np.empty(len(d)), np.empty(len(d))
    for tr, te in GroupKFold(N_FOLDS).split(X, Y, G):
        e[te] = logit().fit(X[tr], D[tr]).predict_proba(X[te])[:, 1]
        mu = gbr().fit(np.column_stack([X[tr], D[tr]]), Y[tr])
        m1[te] = mu.predict(np.column_stack([X[te], np.ones(len(te))]))
        m0[te] = mu.predict(np.column_stack([X[te], np.zeros(len(te))]))
    psi = m1 - m0 + D * (Y - m1) / e - (1 - D) * (Y - m0) / (1 - e)
    return e, m1, m0, psi


e_S, m1_S, m0_S, psi_S = nuisances(biased, COVS_S)
e_noS, _, _, psi_noS = nuisances(biased, COVS_NOS)
NUM["aipw_by_hand_S"] = float(psi_S.mean())
NUM["aipw_by_hand_noS"] = float(psi_noS.mean())
NUM["outcome_only_S"] = float((m1_S - m0_S).mean())      # regression (plug-in) part alone
NUM["ps_range_S"] = [float(e_S.min()), float(e_S.max())]
NUM["ps_range_noS"] = [float(e_noS.min()), float(e_noS.max())]
NUM["share_outside_05_95_S"] = float(((e_S < 0.05) | (e_S > 0.95)).mean())
NUM["share_outside_10_90_S"] = float(((e_S < 0.10) | (e_S > 0.90)).mean())
NUM["max_ipw_weight_S"] = float(np.where(Db == 1, 1 / e_S, 1 / (1 - e_S)).max())

# ---------------------------------------------------------------------------
# 2. Overlap figure: e_hat(S, X) vs e_hat(X) (cross-fitted)
# ---------------------------------------------------------------------------
bins = np.linspace(0, 1, 41)
fig, axes = plt.subplots(1, 2, figsize=(7.4, 2.7), sharey=True)
for ax, e, ttl in [(axes[0], e_S, r"(a) $\hat e(S,X)$: S included"),
                   (axes[1], e_noS, r"(b) $\hat e(X)$: S removed")]:
    ax.hist(e[Db == 1], bins=bins, color="#DD8452", label=f"Local (n={int(Db.sum()):,})")
    ax.hist(e[Db == 0], bins=bins, weights=-np.ones((Db == 0).sum()), color="#4C72B0",
            label=f"Central (n={int((1 - Db).sum()):,})")
    ax.axhline(0, color="black", lw=0.6)
    for x in (0.05, 0.95):
        ax.axvline(x, ls=":", lw=0.8, color="grey")
    ax.set_xlim(0, 1)
    ax.set_title(ttl, fontsize=9)
    ax.set_xlabel("Cross-fitted propensity score, Pr(Local | covariates)", fontsize=8)
yt = axes[0].get_yticks()
axes[0].set_yticks(yt)
axes[0].set_yticklabels([f"{abs(int(t))}" for t in yt])
axes[0].set_ylabel("Properties (Local up, Central down)", fontsize=8)
axes[0].legend(fontsize=7, frameon=False, loc="upper left")
fig.suptitle("Biased sample (N = 2,740)", fontsize=9)
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure1_overlap.{ext}", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------------------
# 4. Bootstrap: 200 neighbourhood draws, every learner and both specs refit
# ---------------------------------------------------------------------------
jobs_b = [(k, s) for k in LEARNERS for s in SPECS]
boot_b = pd.DataFrame(Parallel(n_jobs=N_JOBS)(delayed(one_draw)(b, biased, jobs_b)
                                              for b in range(N_BOOT)))

# Part 2: main learner on the full experimental sample
point["dr_linear__full"] = fit_ate(full, "dr_linear", COVS_S)
boot_f = pd.DataFrame(Parallel(n_jobs=N_JOBS)(delayed(one_draw)(b, full, [("dr_linear", "S")])
                                              for b in range(N_BOOT)))
boot_b["dr_linear__full"] = boot_f["dr_linear__S"]
boot_b.insert(0, "draw", np.arange(N_BOOT))
boot_b.to_csv(OUT / "bootstrap_dr_draws.csv", index=False)


def summ(col):
    v = boot_b[col].to_numpy()
    t = point[col]
    return {"tau": t, "se": float(v.std(ddof=1)), "lo": float(np.percentile(v, 2.5)),
            "hi": float(np.percentile(v, 97.5)),
            "bias_removed": float((tau_naive - t) / (tau_naive - tau_rct))}


NUM["dr"] = {c: summ(c) for c in point}

# ---------------------------------------------------------------------------
# Tables
# ---------------------------------------------------------------------------
rows = []
for k, (lab, _) in LEARNERS.items():
    a, b = NUM["dr"][f"{k}__S"], NUM["dr"][f"{k}__noS"]
    rows.append({"learner": lab, "tau_S": a["tau"], "se_S": a["se"], "lo_S": a["lo"], "hi_S": a["hi"],
                 "tau_noS": b["tau"], "se_noS": b["se"], "lo_noS": b["lo"], "hi_noS": b["hi"]})
t1 = pd.DataFrame(rows)
t1.to_csv(OUT / "table2_dr_estimates.csv", index=False)
with open(OUT / "table2_dr_estimates.tex", "w") as fh:
    fh.write("\\begin{tabular}{lcccc}\n\\toprule\n"
             " & \\multicolumn{2}{c}{S included (covariates S, X)} & \\multicolumn{2}{c}{S removed (X only)} \\\\\n"
             "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\n"
             "DR learner & ATE (SE) & 95\\% CI & ATE (SE) & 95\\% CI \\\\\n\\midrule\n")
    for _, r in t1.iterrows():
        fh.write(f"{r.learner} & {r.tau_S:.3f} ({r.se_S:.3f}) & [{r.lo_S:.3f}, {r.hi_S:.3f}] & "
                 f"{r.tau_noS:.3f} ({r.se_noS:.3f}) & [{r.lo_noS:.3f}, {r.hi_noS:.3f}] \\\\\n")
    fh.write("\\midrule\n"
             f"\\multicolumn{{5}}{{l}}{{Benchmarks: $\\hat\\tau^{{\\,\\mathrm{{RCT}}}}={tau_rct:.3f}$ (full sample), "
             f"$\\hat\\tau^{{\\,\\mathrm{{naive}}}}={tau_naive:.3f}$ (biased sample, no S)}} \\\\\n"
             "\\bottomrule\n\\end{tabular}\n")

d_main = NUM["dr"]["dr_linear__S"]
d_nos = NUM["dr"]["dr_linear__noS"]
d_full = NUM["dr"]["dr_linear__full"]
comp = [
    ("Full", "Benchmark: OLS of Y on D + S + X ($\\hat\\tau^{\\,\\mathrm{RCT}}$)", tau_rct, W7["se_rct"], "cluster", None, None),
    ("Full", "DR, LinearDRLearner (Part 2)", d_full["tau"], d_full["se"], "boot", d_full["lo"], d_full["hi"]),
    ("Biased", "Naive: OLS of Y on D + X, no S ($\\hat\\tau^{\\,\\mathrm{naive}}$)", tau_naive, W7["se_naive"], "cluster", None, None),
    ("Biased", "Week 7: PS matching, 1-NN (ATE)", W7["tau_psm_ate"], W7["se_psm_ate"], "AI", None, None),
    ("Biased", "Week 7: IPW, Horvitz--Thompson", W7["tau_ipw"], W7["boot_ipw"]["se"], "boot", W7["boot_ipw"]["lo"], W7["boot_ipw"]["hi"]),
    ("Biased", "Week 7: IPW, Hajek (normalised)", W7["tau_ipw_hajek"], W7["boot_hajek"]["se"], "boot", W7["boot_hajek"]["lo"], W7["boot_hajek"]["hi"]),
    ("Biased", "Week 9: DR, LinearDRLearner, S included", d_main["tau"], d_main["se"], "boot", d_main["lo"], d_main["hi"]),
    ("Biased", "Week 9: DR, ForestDRLearner, S included", NUM["dr"]["dr_forest__S"]["tau"], NUM["dr"]["dr_forest__S"]["se"], "boot", NUM["dr"]["dr_forest__S"]["lo"], NUM["dr"]["dr_forest__S"]["hi"]),
    ("Biased", "Week 9: DR, LinearDRLearner, S removed", d_nos["tau"], d_nos["se"], "boot", d_nos["lo"], d_nos["hi"]),
]
t2 = pd.DataFrame(comp, columns=["sample", "estimator", "tau", "se", "se_type", "ci_lo", "ci_hi"])
t2["gap_to_rct"] = t2["tau"] - tau_rct
t2["share_of_bias_removed"] = (tau_naive - t2["tau"]) / (tau_naive - tau_rct)
t2.to_csv(OUT / "table3_comparison.csv", index=False)
sup = {"cluster": "c", "boot": "b", "AI": "a"}
with open(OUT / "table3_comparison.tex", "w") as fh:
    fh.write("\\begin{tabular}{llccccc}\n\\toprule\nSample & Estimator & ATE & SE & 95\\% CI & "
             "Gap to $\\hat\\tau^{\\,\\mathrm{RCT}}$ & Bias removed \\\\\n\\midrule\n")
    for i, r in t2.iterrows():
        ci = f"[{r.ci_lo:.3f}, {r.ci_hi:.3f}]" if pd.notna(r.ci_lo) else "--"
        br = "--" if r["sample"] == "Full" else f"{100 * r.share_of_bias_removed:.0f}\\%"
        fh.write(f"{r['sample']} & {r.estimator} & {r.tau:.3f} & {r.se:.3f}$^{sup[r.se_type]}$ & {ci} & "
                 f"{r.gap_to_rct:+.3f} & {br} \\\\\n")
        if i in (1, 5):
            fh.write("\\midrule\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

# ---------------------------------------------------------------------------
# Figure 2: estimates with CIs vs benchmark and naive
# ---------------------------------------------------------------------------
plot = t2.iloc[::-1].reset_index(drop=True)
fig, ax = plt.subplots(figsize=(6.6, 3.3))
for i, r in plot.iterrows():
    col = "#C44E52" if "removed" in r.estimator else ("#4C72B0" if "DR" in r.estimator else "#555555")
    lo, hi = (r.ci_lo, r.ci_hi) if pd.notna(r.ci_lo) else (r.tau - 1.96 * r.se, r.tau + 1.96 * r.se)
    ax.plot([lo, hi], [i, i], color=col, lw=1.6)
    ax.plot(r.tau, i, "o", color=col, ms=5)
ax.axvline(tau_rct, color="black", ls="--", lw=0.9, label=r"$\hat\tau^{RCT}$")
ax.axvline(tau_naive, color="grey", ls=":", lw=1.1, label=r"$\hat\tau^{naive}$")
ax.axvline(0, color="black", lw=0.4)
labels = [f"[{r['sample']}] " + r.estimator.replace("$\\hat\\tau^{\\,\\mathrm{RCT}}$", r"$\hat\tau^{RCT}$")
          .replace("$\\hat\\tau^{\\,\\mathrm{naive}}$", r"$\hat\tau^{naive}$").replace("--", "-")
          for _, r in plot.iterrows()]
ax.set_yticks(range(len(plot)))
ax.set_yticklabels(labels, fontsize=7)
ax.set_xlabel("Effect of Local on Pr(exempt)", fontsize=8)
ax.legend(fontsize=7, frameon=True, loc="center right")
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure2_estimates.{ext}", dpi=200)
plt.close(fig)

(OUT / "numbers.json").write_text(json.dumps(NUM, indent=2, default=float))
print(t1.round(4).to_string())
print(t2[["sample", "estimator", "tau", "se", "ci_lo", "ci_hi", "share_of_bias_removed"]].round(4).to_string())
print({k: NUM[k] for k in ["aipw_by_hand_S", "aipw_by_hand_noS", "outcome_only_S", "ps_range_S", "ps_range_noS"]})
print(cv.round(4).to_string())
