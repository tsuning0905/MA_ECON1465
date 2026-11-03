"""
02_week7_matching_ipw.py
========================
Week 7 report, RCT track (called by 00_master/00_master.py after
02_week6_benchmark.py, which builds the biased sample).

  D  = local            1 = neighbourhood randomly assigned to Local, 0 = Central
  Y  = exempt           1 = collector registered the property as tax-exempt
  S  = owner_age        selection variable of the Week 6 biased sample (Recipe B, gamma = 1)
  X  = owner_female, main_tribe (Luluwa), job_gov (owner works for the state)

Propensity score (main specification): logit of D on S + X, fit on the biased sample.

Sections (match the report)
  1. Propensity score + positivity check -> 03_output/week7/figure1_positivity.{pdf,png}
  2. Estimators on the biased sample:
       nearest-neighbour matching on e_hat (ATE and ATT; Abadie-Imbens SE)
       IPW, Horvitz-Thompson (divide by N) and normalised (Hajek)
       DoWhy propensity_score_matching / propensity_score_weighting (cross-check)
                                          -> 03_output/week7/table2_estimates.{csv,tex}
     Balance before / after              -> 03_output/week7/table1_balance.{csv,tex}
  3. Recipe B check: logit of D on standardised S vs gamma
                                          -> 03_output/week7/table3_gamma_check.{csv,tex}
  4. Bootstrap of the IPW ATE (500 draws, resampling neighbourhoods, propensity
     score re-estimated in every draw)   -> 03_output/week7/figure2_bootstrap_ipw.{pdf,png}
  All numbers quoted in the report       -> 03_output/week7/numbers.json

Inputs : data_intermediate/final_exemption.csv.gz      (from 01_preanalysis.py)
         data_intermediate/week6_biased_sample.csv.gz  (from 02_week6_benchmark.py)
Seed   : 1465 (bootstrap).
Packages: pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, matplotlib 3.11.2, dowhy 0.14
          (pinned in requirements.txt).
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
import statsmodels.api as sm
import statsmodels.formula.api as smf

warnings.filterwarnings("ignore")

ROOT = Path(os.environ.get("ECO1465_ROOT", Path(__file__).resolve().parents[1]))
INTER = ROOT / "data_intermediate"
OUT = ROOT / "03_output" / "week7"
OUT.mkdir(parents=True, exist_ok=True)

SEED = 1465
N_BOOT = 500
GAMMA = 1.0                                   # Recipe B parameter used in Week 6
X_COVS = ["owner_female", "main_tribe", "job_gov"]
COVS = ["owner_age"] + X_COVS                 # propensity-score covariates (S + X)
NUM: dict = {"seed": SEED, "n_boot": N_BOOT, "gamma": GAMMA, "ps_covariates": COVS}

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------
raw = pd.read_csv(INTER / "final_exemption.csv.gz")
full = raw.dropna(subset=["exempt", "local"] + COVS).reset_index(drop=True)
biased = pd.read_csv(INTER / "week6_biased_sample.csv.gz").reset_index(drop=True)
NUM["n_full"], NUM["n_biased"] = len(full), len(biased)
NUM["n_biased_treated"] = int(biased["local"].sum())
NUM["n_biased_control"] = int((1 - biased["local"]).sum())


def reg(d, y="exempt", covs=None):
    rhs = " + ".join(["local"] + (covs or []))
    return smf.ols(f"{y} ~ {rhs}", d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})


def pscore(d: pd.DataFrame) -> np.ndarray:
    """Logit of D on S + X; returns e_hat."""
    Xm = sm.add_constant(d[COVS].astype(float))
    return sm.Logit(d["local"].astype(float), Xm).fit(disp=0).predict(Xm).to_numpy()


def ipw(d: pd.DataFrame, e: np.ndarray, normalised: bool = False) -> float:
    D, Y = d["local"].to_numpy(), d["exempt"].to_numpy()
    w1, w0 = D / e, (1 - D) / (1 - e)
    if normalised:                             # Hajek: divide by the sum of weights
        return (w1 * Y).sum() / w1.sum() - (w0 * Y).sum() / w0.sum()
    return (w1 * Y).sum() / len(d) - (w0 * Y).sum() / len(d)   # Horvitz-Thompson: divide by N


def nn_match(e: np.ndarray, D: np.ndarray, Y: np.ndarray):
    """1-nearest-neighbour matching on e_hat, with replacement; tied twins are averaged.

    Returns tau_ATE, tau_ATT, Abadie-Imbens (2006) SE for each, and K
    (how many times each unit is used as a twin, in weight units).
    """
    N = len(Y)
    Yhat1, Yhat0 = np.where(D == 1, Y, np.nan), np.where(D == 0, Y, np.nan)
    K = np.zeros(N)
    sig2 = np.zeros(N)
    idx = np.arange(N)
    for i in range(N):
        other = idx[D != D[i]]
        dist = np.abs(e[other] - e[i])
        twins = other[dist <= dist.min() + 1e-12]
        K[twins] += 1 / len(twins)
        if D[i] == 1:
            Yhat0[i] = Y[twins].mean()
        else:
            Yhat1[i] = Y[twins].mean()
        # conditional variance: match to the nearest unit of the SAME group
        same = idx[(D == D[i]) & (idx != i)]
        ds = np.abs(e[same] - e[i])
        nb = same[ds <= ds.min() + 1e-12]
        J = len(nb)
        sig2[i] = J / (J + 1) * (Y[i] - Y[nb].mean()) ** 2
    ite = Yhat1 - Yhat0
    tau_ate, tau_att = ite.mean(), ite[D == 1].mean()
    # Abadie-Imbens (2006) variance, M = 1 (propensity score treated as known)
    v_ate = (((ite - tau_ate) ** 2) + (K ** 2 + K) * sig2).sum() / N ** 2
    N1 = D.sum()
    # ATT: only treated units are matched, so K counts uses by treated units only
    KT = np.zeros(N)
    for i in idx[D == 1]:
        other = idx[D == 0]
        dist = np.abs(e[other] - e[i])
        twins = other[dist <= dist.min() + 1e-12]
        KT[twins] += 1 / len(twins)
    v_att = (((ite[D == 1] - tau_att) ** 2).sum()
             + ((KT[D == 0] ** 2 - KT[D == 0]) * sig2[D == 0]).sum()) / N1 ** 2
    return tau_ate, np.sqrt(v_ate), tau_att, np.sqrt(v_att), K


def cluster_boot(d: pd.DataFrame, stat, rng) -> np.ndarray:
    """Resample neighbourhoods (the unit of randomisation), keep all their properties."""
    groups = {k: v.index.values for k, v in d.groupby("a7")}
    keys = np.array(list(groups))
    out = np.empty(N_BOOT)
    for b in range(N_BOOT):
        draw = rng.choice(keys, size=len(keys), replace=True)
        out[b] = stat(d.loc[np.concatenate([groups[k] for k in draw])].reset_index(drop=True))
    return out


# ---------------------------------------------------------------------------
# 0. Benchmarks carried over from Week 6 (recomputed here, same code)
# ---------------------------------------------------------------------------
m_rct = reg(full, covs=COVS)
NUM["tau_rct"], NUM["se_rct"] = m_rct.params["local"], m_rct.bse["local"]
NUM["tau_dim_biased"] = (biased.loc[biased.local == 1, "exempt"].mean()
                         - biased.loc[biased.local == 0, "exempt"].mean())
m_naive = reg(biased, covs=X_COVS)
NUM["tau_naive"], NUM["se_naive"] = m_naive.params["local"], m_naive.bse["local"]
m_adj = reg(biased, covs=COVS)
NUM["tau_reg_adj"], NUM["se_reg_adj"] = m_adj.params["local"], m_adj.bse["local"]
# IPW on the full sample: D is random there, so there is nothing to correct
e_full = pscore(full)
NUM["tau_ipw_full"] = ipw(full, e_full)
NUM["ps_full_range"] = [float(e_full.min()), float(e_full.max())]

# ---------------------------------------------------------------------------
# 1. Propensity score on the biased sample + positivity check
# ---------------------------------------------------------------------------
D, Y = biased["local"].to_numpy(), biased["exempt"].to_numpy()
e = pscore(biased)
biased["e_hat"] = e
NUM["ps_range_local"] = [float(e[D == 1].min()), float(e[D == 1].max())]
NUM["ps_range_central"] = [float(e[D == 0].min()), float(e[D == 0].max())]
NUM["share_outside_05_95"] = float(((e < 0.05) | (e > 0.95)).mean())
NUM["share_outside_10_90"] = float(((e < 0.10) | (e > 0.90)).mean())
w_ht = np.where(D == 1, 1 / e, 1 / (1 - e))
NUM["max_weight"] = float(w_ht.max())
NUM["weight_sum_local"] = float(w_ht[D == 1].sum())
NUM["weight_sum_central"] = float(w_ht[D == 0].sum())
NUM["share_weight_top1pct"] = float(np.sort(w_ht)[-int(0.01 * len(w_ht)):].sum() / w_ht.sum())
# effective sample size (Kish) by group
for g, nm in [(1, "local"), (0, "central")]:
    wg = w_ht[D == g]
    NUM[f"ess_{nm}"] = float(wg.sum() ** 2 / (wg ** 2).sum())

bins = np.linspace(0, 1, 41)
fig, ax = plt.subplots(figsize=(6.0, 3.0))
ax.hist(e[D == 1], bins=bins, weights=w_ht[D == 1], color="#DD8452", alpha=0.25,
        label="Local, IPW-weighted")
ax.hist(e[D == 0], bins=bins, weights=-w_ht[D == 0], color="#4C72B0", alpha=0.25,
        label="Central, IPW-weighted")
ax.hist(e[D == 1], bins=bins, color="#DD8452", alpha=0.9,
        label=f"Local (n={NUM['n_biased_treated']:,})")
ax.hist(e[D == 0], bins=bins, weights=-np.ones((D == 0).sum()), color="#4C72B0", alpha=0.9,
        label=f"Central (n={NUM['n_biased_control']:,})")
ax.axhline(0, color="black", lw=0.6)
for x in (0.05, 0.95):
    ax.axvline(x, ls=":", lw=0.8, color="grey")
ax.set_xlim(0, 1)
yt = ax.get_yticks()
ax.set_yticks(yt)
ax.set_yticklabels([f"{abs(int(t))}" for t in yt])
ax.set_xlabel(r"Estimated propensity score $\hat e(x)=\Pr(\mathrm{Local}\mid S,X)$")
ax.set_ylabel("Properties (Local up, Central down)")
ax.set_title("Biased sample: positivity check", fontsize=9)
ax.legend(fontsize=6.5, frameon=False, loc="upper left", ncol=2)
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure1_positivity.{ext}", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------------------
# 2. Matching and IPW estimates on the biased sample
# ---------------------------------------------------------------------------
t_ate, se_ate, t_att, se_att, K = nn_match(e, D, Y)
t_ipw = ipw(biased, e)
t_hajek = ipw(biased, e, normalised=True)
NUM.update({"tau_psm_ate": t_ate, "se_psm_ate": se_ate, "tau_psm_att": t_att,
            "se_psm_att": se_att, "tau_ipw": t_ipw, "tau_ipw_hajek": t_hajek,
            "n_controls_used_as_twins": int(((K > 0) & (D == 0)).sum()),
            "n_treated_used_as_twins": int(((K > 0) & (D == 1)).sum())})

# Bootstrap (Section 4): IPW only. For nearest-neighbour matching the bootstrap
# is not valid (Abadie and Imbens 2008), so matching uses the Abadie-Imbens SE.
rng = np.random.default_rng(SEED)
boot_ipw = cluster_boot(biased, lambda d: ipw(d, pscore(d)), rng)
boot_hajek = cluster_boot(biased, lambda d: ipw(d, pscore(d), normalised=True), rng)
NUM["boot_ipw"] = {"se": float(boot_ipw.std(ddof=1)),
                   "lo": float(np.percentile(boot_ipw, 2.5)),
                   "hi": float(np.percentile(boot_ipw, 97.5))}
NUM["boot_hajek"] = {"se": float(boot_hajek.std(ddof=1)),
                     "lo": float(np.percentile(boot_hajek, 2.5)),
                     "hi": float(np.percentile(boot_hajek, 97.5))}
pd.DataFrame({"draw": np.arange(N_BOOT), "ipw_ht": boot_ipw, "ipw_hajek": boot_hajek}) \
    .to_csv(OUT / "bootstrap_ipw_draws.csv", index=False)

# DoWhy cross-check: the score is fit by DoWhy on the back-door set of DAG 2 (owner_age)
from dowhy import CausalModel  # noqa: E402

gml_graph = """graph [directed 1
  node [id "owner_age" label "owner_age"]
  node [id "owner_female" label "owner_female"]
  node [id "main_tribe" label "main_tribe"]
  node [id "job_gov" label "job_gov"]
  node [id "local" label "local"]
  node [id "exempt" label "exempt"]
  edge [source "owner_age" target "local"]
  edge [source "owner_age" target "exempt"]
  edge [source "owner_female" target "exempt"]
  edge [source "main_tribe" target "exempt"]
  edge [source "job_gov" target "exempt"]
  edge [source "local" target "exempt"]
]"""
dw = biased[["local", "exempt"] + COVS].copy()
dw["local"] = dw["local"].astype(bool)
model = CausalModel(data=dw, treatment="local", outcome="exempt", graph=gml_graph)
estimand = model.identify_effect(proceed_when_unidentifiable=True)
dw_psm = model.estimate_effect(estimand, method_name="backdoor.propensity_score_matching",
                               target_units="ate").value
dw_ipw = model.estimate_effect(estimand, method_name="backdoor.propensity_score_weighting",
                               target_units="ate",
                               method_params={"weighting_scheme": "ips_weight"}).value
dw_ipwn = model.estimate_effect(estimand, method_name="backdoor.propensity_score_weighting",
                                target_units="ate",
                                method_params={"weighting_scheme": "ips_normalized_weight"}).value
NUM.update({"dowhy_psm_ate": float(dw_psm), "dowhy_ipw": float(dw_ipw),
            "dowhy_ipw_norm": float(dw_ipwn),
            "dowhy_backdoor_vars": estimand.get_backdoor_variables()})

rows = [
    ("Full", "Benchmark: regression Y on D + S + X ($\\hat\\tau^{RCT}$)", "ATE", NUM["tau_rct"],
     NUM["se_rct"], "cluster"),
    ("Full", "IPW (score on S + X)", "ATE", NUM["tau_ipw_full"], np.nan, ""),
    ("Biased", "Difference in means", "--", NUM["tau_dim_biased"], np.nan, ""),
    ("Biased", "Naive: regression Y on D + X, no S ($\\hat\\tau^{naive}$)", "--", NUM["tau_naive"],
     NUM["se_naive"], "cluster"),
    ("Biased", "PS matching, 1-NN with replacement", "ATE", t_ate, se_ate, "AI"),
    ("Biased", "PS matching, 1-NN with replacement", "ATT", t_att, se_att, "AI"),
    ("Biased", "IPW, Horvitz--Thompson (divide by $N$)", "ATE", t_ipw, NUM["boot_ipw"]["se"], "boot"),
    ("Biased", "IPW, normalised weights (Hajek)", "ATE", t_hajek, NUM["boot_hajek"]["se"], "boot"),
    ("Biased", "DoWhy PS matching (score on S only)", "ATE", dw_psm, np.nan, ""),
    ("Biased", "DoWhy IPW, ips\\_weight (score on S only)", "ATE", dw_ipw, np.nan, ""),
    ("Biased", "Week 6: regression Y on D + S + X", "--", NUM["tau_reg_adj"], NUM["se_reg_adj"], "cluster"),
]
tab1 = pd.DataFrame(rows, columns=["sample", "estimator", "target", "tau", "se", "se_type"])
tab1["ci_lo"] = np.where(tab1.se_type == "boot",
                         [NUM["boot_ipw"]["lo"] if "Horvitz" in s else NUM["boot_hajek"]["lo"]
                          for s in tab1.estimator], np.nan)
tab1["ci_hi"] = np.where(tab1.se_type == "boot",
                         [NUM["boot_ipw"]["hi"] if "Horvitz" in s else NUM["boot_hajek"]["hi"]
                          for s in tab1.estimator], np.nan)
tab1["share_of_bias_removed"] = (NUM["tau_naive"] - tab1["tau"]) / (NUM["tau_naive"] - NUM["tau_rct"])
tab1.to_csv(OUT / "table2_estimates.csv", index=False)

# Balance: standardised mean differences before and after
def smd(x, d, w=None):
    w = np.ones(len(x)) if w is None else w
    m1 = np.average(x[d == 1], weights=w[d == 1])
    m0 = np.average(x[d == 0], weights=w[d == 0])
    s = np.sqrt((x[d == 1].var(ddof=1) + x[d == 0].var(ddof=1)) / 2)   # unweighted pooled SD
    return m1, m0, (m1 - m0) / s


w_match = 1 + K                                  # each unit counts once + once per use as a twin
bal = []
for v, lab in [("owner_age", "Owner age (S)"), ("owner_old", "Owner 55 or older"),
               ("owner_female", "Owner female"), ("main_tribe", "Owner Luluwa"),
               ("job_gov", "Owner works for state")]:
    xb = biased[v].to_numpy(dtype=float)
    _, _, smd_full = smd(full[v].to_numpy(dtype=float), full["local"].to_numpy())
    m1, m0, s_raw = smd(xb, D)
    i1, i0, s_ipw = smd(xb, D, w_ht)
    k1, k0, s_m = smd(xb, D, w_match)
    bal.append({"covariate": lab, "smd_full": smd_full, "central": m0, "local": m1,
                "smd_raw": s_raw, "ipw_central": i0, "ipw_local": i1, "smd_ipw": s_ipw,
                "match_central": k0, "match_local": k1, "smd_match": s_m})
bal = pd.DataFrame(bal)
bal.to_csv(OUT / "table1_balance.csv", index=False)

# ---------------------------------------------------------------------------
# 3. Recipe B check: logit of D on standardised S in the biased sample
# ---------------------------------------------------------------------------
# Same standardisation as the Week 6 recipe (full-sample mean and SD).
# Recipe B implies logit Pr(D=1 | S, kept) = log(p / (1-p)) + gamma*S, p = Local share in full sample:
#   Pr(D=1|S,kept) = p L(gS) / [p L(gS) + (1-p) L(-gS)],  and L(gS)/L(-gS) = exp(gS).
mu, sd = full["owner_age"].mean(), full["owner_age"].std()
gc = biased.assign(S_std=(biased["owner_age"] - mu) / sd)
lg = smf.logit("local ~ S_std", gc).fit(disp=0, cov_type="cluster", cov_kwds={"groups": gc["a7"]})
lg_x = smf.logit("local ~ S_std + owner_female + main_tribe + job_gov", gc) \
    .fit(disp=0, cov_type="cluster", cov_kwds={"groups": gc["a7"]})
p_full = full["local"].mean()
gam = pd.DataFrame([
    {"model": "D on S_std", "coef_S": lg.params["S_std"], "se_S": lg.bse["S_std"],
     "const": lg.params["Intercept"], "N": int(lg.nobs)},
    {"model": "D on S_std + X", "coef_S": lg_x.params["S_std"], "se_S": lg_x.bse["S_std"],
     "const": lg_x.params["Intercept"], "N": int(lg_x.nobs)},
])
gam.to_csv(OUT / "table3_gamma_check.csv", index=False)
NUM.update({"logit_gamma_hat": lg.params["S_std"], "logit_gamma_se": lg.bse["S_std"],
            "logit_gamma_ci": [float(x) for x in lg.conf_int().loc["S_std"]],
            "logit_const": lg.params["Intercept"], "theory_const": float(np.log(p_full / (1 - p_full))),
            "logit_gamma_hat_withX": lg_x.params["S_std"],
            "logit_x_pvalues": {c: float(lg_x.pvalues[c]) for c in X_COVS}})

# ---------------------------------------------------------------------------
# 4. Bootstrap figure (IPW ATE)
# ---------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(6.0, 2.8))
ax.hist(boot_ipw, bins=40, color="#8C8C8C", alpha=0.85, label="Bootstrap draws, IPW (HT)")
ax.axvline(t_ipw, color="black", lw=1.4, label=f"IPW estimate {t_ipw:.3f}")
ax.axvline(NUM["boot_ipw"]["lo"], color="black", ls="--", lw=0.8, label="95% percentile CI")
ax.axvline(NUM["boot_ipw"]["hi"], color="black", ls="--", lw=0.8)
ax.axvline(NUM["tau_rct"], color="#2E8B57", lw=1.6, label=f"Benchmark RCT {NUM['tau_rct']:.3f}")
ax.axvline(NUM["tau_naive"], color="#C0392B", lw=1.6, label=f"Naive {NUM['tau_naive']:.3f}")
ax.set_xlabel("ATE of Local on exempt (biased sample)")
ax.set_ylabel("Draws")
ax.set_title(f"IPW ATE: {N_BOOT} cluster-bootstrap draws (neighbourhoods), seed {SEED}", fontsize=9)
ax.legend(fontsize=6.5, frameon=False, loc="upper right")
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure2_bootstrap_ipw.{ext}", dpi=200)
plt.close(fig)

# ---------------------------------------------------------------------------
# LaTeX tables
# ---------------------------------------------------------------------------
def f3(x):
    return "" if pd.isna(x) else f"{x:.3f}"


with open(OUT / "table2_estimates.tex", "w") as fh:
    fh.write("\\begin{tabular}{lllccc}\n\\toprule\nSample & Estimator & Target & $\\hat\\tau$ & SE & 95\\% CI\\\\\n\\midrule\n")
    for r in tab1.itertuples():
        mark = {"cluster": "$^c$", "AI": "$^a$", "boot": "$^b$"}.get(r.se_type, "")
        se = f"{f3(r.se)}{mark}" if not pd.isna(r.se) else ""
        ci = f"[{f3(r.ci_lo)}, {f3(r.ci_hi)}]" if not pd.isna(r.ci_lo) else ""
        fh.write(f"{r.sample} & {r.estimator} & {r.target} & {f3(r.tau)} & {se} & {ci}\\\\\n")
        if r.Index in (1, 3, 7):
            fh.write("\\addlinespace\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

with open(OUT / "table1_balance.tex", "w") as fh:
    fh.write("\\begin{tabular}{lccccccc}\n\\toprule\n"
             " & Full & \\multicolumn{3}{c}{Biased, unweighted} & \\multicolumn{2}{c}{After IPW} & After matching\\\\\n"
             "\\cmidrule(lr){2-2}\\cmidrule(lr){3-5}\\cmidrule(lr){6-7}\\cmidrule(lr){8-8}\n"
             "Covariate & SMD & Central & Local & SMD & Central/Local & SMD & SMD\\\\\n\\midrule\n")
    for r in bal.itertuples():
        fmt = (lambda x: f"{x:.1f}") if r.covariate.startswith("Owner age") else f3
        fh.write(f"{r.covariate} & {f3(r.smd_full)} & {fmt(r.central)} & {fmt(r.local)} & {f3(r.smd_raw)} & "
                 f"{fmt(r.ipw_central)}/{fmt(r.ipw_local)} & {f3(r.smd_ipw)} & {f3(r.smd_match)}\\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

with open(OUT / "table3_gamma_check.tex", "w") as fh:
    fh.write("\\begin{tabular}{lcccc}\n\\toprule\nLogit model (biased sample) & $\\hat\\gamma$ (coef.\\ on std.\\ $S$) & SE & Constant & $N$\\\\\n\\midrule\n")
    for r in gam.itertuples():
        fh.write(f"{r.model.replace('_', chr(92) + '_')} & {f3(r.coef_S)} & {f3(r.se_S)} & {f3(r.const)} & {r.N:,}\\\\\n")
    fh.write(f"Recipe B (true value) & {GAMMA:.3f} & & {NUM['theory_const']:.3f} & \\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

(OUT / "numbers.json").write_text(json.dumps(NUM, indent=2, default=float))
print(tab1.round(4).to_string())
print(bal.round(3).to_string())
print(gam.round(3).to_string())
print(json.dumps({k: v for k, v in NUM.items() if not isinstance(v, (list, dict))}, indent=1, default=float))
