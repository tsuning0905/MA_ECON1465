"""
02_week6_benchmark.py
=====================
Week 6 report, RCT track (called by 00_master/00_master.py after 01_preanalysis.py).

Research question: does chief collection (Local) instead of state collection
(Central) change tax exemptions, and are the extra exemptions justified?

  D  = local            1 = neighbourhood randomly assigned to Local, 0 = Central
  Y  = exempt           1 = collector registered the property as tax-exempt
  S  = owner_age        owner's age in years (selection variable, Benchmark Exercise)
  X  = owner_female, main_tribe (Luluwa), job_gov (owner works for the state)

Sections (match the report)
  1. Experimental benchmark      -> 03_output/week6/table1_benchmark.{csv,tex}
                                    03_output/week6/table2_exemption_reasons.{csv,tex}
  2. Biased sample (Recipe B)    -> data_intermediate/week6_biased_sample.csv.gz
                                    03_output/week6/table3_balance.{csv,tex}
                                    03_output/week6/figure1_overlap.{pdf,png}
  3. Naive estimate              -> 03_output/week6/table1_benchmark.* (rows 3-4)
  4. DoWhy on the biased sample  -> 03_output/week6/dowhy_log.txt
                                    03_output/week6/figure2_dag2.{pdf,png}
  All numbers quoted in the report -> 03_output/week6/numbers.json

Seed: 1465 for the biased sample, the bootstrap and DoWhy refuters.
Packages: pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0, matplotlib 3.11.2,
          dowhy 0.14, networkx 3.7, graphviz (system `dot`) for the DAG figure.
"""
from __future__ import annotations

import io
import json
import os
import subprocess
from contextlib import redirect_stdout
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

ROOT = Path(os.environ.get("ECO1465_ROOT", Path(__file__).resolve().parents[1]))
INTER = ROOT / "data_intermediate"
OUT = ROOT / "03_output" / "week6"
OUT.mkdir(parents=True, exist_ok=True)

SEED = 1465
N_BOOT = 500
ALPHA, GAMMA = 0.0, 1.0           # Recipe B parameters
X_COVS = ["owner_female", "main_tribe", "job_gov"]
COVS = ["owner_age"] + X_COVS
NUM: dict = {"seed": SEED, "n_boot": N_BOOT, "alpha": ALPHA, "gamma": GAMMA}

# ---------------------------------------------------------------------------
# Data: full experimental sample (Central + Local, complete cases)
# ---------------------------------------------------------------------------
raw = pd.read_csv(INTER / "final_exemption.csv.gz")
NUM["n_registered_with_exempt"] = int(raw["exempt"].notna().sum())
full = raw.dropna(subset=["exempt", "local"] + COVS).reset_index(drop=True)
NUM["n_full"] = len(full)
NUM["n_full_treated"] = int(full["local"].sum())
NUM["n_full_control"] = int((1 - full["local"]).sum())
NUM["n_clusters_full"] = int(full["a7"].nunique())


def dim(d: pd.DataFrame, y: str = "exempt") -> float:
    return d.loc[d["local"] == 1, y].mean() - d.loc[d["local"] == 0, y].mean()


def reg(d: pd.DataFrame, y: str = "exempt", covs: list[str] | None = None):
    rhs = " + ".join(["local"] + (covs or []))
    return smf.ols(f"{y} ~ {rhs}", d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})


def cluster_boot(d: pd.DataFrame, stat, rng) -> np.ndarray:
    """Bootstrap by neighbourhood (the unit of randomisation)."""
    groups = {k: v.index.values for k, v in d.groupby("a7")}
    keys = np.array(list(groups))
    out = np.empty(N_BOOT)
    for b in range(N_BOOT):
        draw = rng.choice(keys, size=len(keys), replace=True)
        idx = np.concatenate([groups[k] for k in draw])
        out[b] = stat(d.loc[idx])
    return out


def row(name, d, est, boot, se=None):
    lo, hi = np.percentile(boot, [2.5, 97.5])
    return {"estimate": name, "sample": d, "tau": est, "cluster_se": se,
            "boot_lo": lo, "boot_hi": hi}


# ---------------------------------------------------------------------------
# 1. Experimental benchmark (full sample)
# ---------------------------------------------------------------------------
rng = np.random.default_rng(SEED)
rows = []
t_dim = dim(full)
b_dim = cluster_boot(full, dim, rng)
rows.append(row("Difference in means", "Full", t_dim, b_dim))
m_rct = reg(full, covs=COVS)
t_rct = m_rct.params["local"]
b_rct = cluster_boot(full, lambda d: reg(d, covs=COVS).params["local"], rng)
rows.append(row("Regression: Y on D + age, female, Luluwa, state job", "Full", t_rct, b_rct,
                m_rct.bse["local"]))
NUM["central_mean_full"] = full.loc[full.local == 0, "exempt"].mean()
NUM["tau_dim_full"], NUM["tau_rct"], NUM["se_rct"] = t_dim, t_rct, m_rct.bse["local"]
NUM["p_rct"] = m_rct.pvalues["local"]
NUM["dim_all_registered"] = dim(raw.dropna(subset=["exempt"]))

# Exemption reasons: where does the extra exemption come from? (full sample)
reasons = []
for y, lab in [("exempt", "Any exemption"), ("exempt_elderly", "Reason: elderly"),
               ("exempt_widow", "Reason: widow"), ("exempt_otherreason", "Reason: other"),
               ("exempt_discretionary", "Discretionary (reason contradicts owner traits)"),
               ("enum_disagrees_exempt", "Enumerator disagrees with collector")]:
    d = full.dropna(subset=[y])
    m = reg(d, y=y, covs=COVS)
    reasons.append({"outcome": lab, "central_mean": d.loc[d.local == 0, y].mean(),
                    "local_mean": d.loc[d.local == 1, y].mean(), "tau": m.params["local"],
                    "se": m.bse["local"], "p": m.pvalues["local"], "N": int(m.nobs)})
reasons = pd.DataFrame(reasons)
reasons.to_csv(OUT / "table2_exemption_reasons.csv", index=False)
NUM["reasons"] = reasons.to_dict("records")

# Among exempt properties: share of exemptions that are discretionary
ex = full[full["exempt"] == 1]
NUM["share_discretionary_central"] = ex.loc[ex.local == 0, "exempt_discretionary"].mean()
NUM["share_discretionary_local"] = ex.loc[ex.local == 1, "exempt_discretionary"].mean()

# ---------------------------------------------------------------------------
# 2. Biased sample, Recipe B (keep with logistic rule on standardised S)
# ---------------------------------------------------------------------------
rng_sel = np.random.default_rng(SEED)
S_std = (full["owner_age"] - full["owner_age"].mean()) / full["owner_age"].std()
sign = np.where(full["local"] == 1, 1, -1)       # +gamma treated, -gamma control
u = ALPHA + GAMMA * sign * S_std
p_keep = 1 / (1 + np.exp(-u))
keep = rng_sel.uniform(size=len(full)) < p_keep
biased = full[keep].copy().reset_index(drop=True)
biased.to_csv(INTER / "week6_biased_sample.csv.gz", index=False, compression="gzip")
NUM["n_biased"] = len(biased)
NUM["n_biased_treated"] = int(biased["local"].sum())
NUM["n_biased_control"] = int((1 - biased["local"]).sum())

bal = []
for v, lab in [("owner_age", "Owner age (S)"), ("owner_old", "Owner 55 or older"),
               ("owner_female", "Owner female"), ("main_tribe", "Owner Luluwa"),
               ("job_gov", "Owner works for state")]:
    r = {"covariate": lab}
    for nm, d in [("full", full), ("biased", biased)]:
        mC, mL = d.loc[d.local == 0, v].mean(), d.loc[d.local == 1, v].mean()
        p = reg(d.dropna(subset=[v]), y=v).pvalues["local"]
        r.update({f"{nm}_central": mC, f"{nm}_local": mL, f"{nm}_p": p})
    bal.append(r)
bal = pd.DataFrame(bal)
bal.to_csv(OUT / "table3_balance.csv", index=False)

fig, ax = plt.subplots(figsize=(5.2, 2.6))
bins = np.arange(15, 106, 5)
ax.hist(biased.loc[biased.local == 0, "owner_age"], bins=bins, alpha=0.55, density=True,
        label=f"Central (n={NUM['n_biased_control']:,})", color="#4C72B0")
ax.hist(biased.loc[biased.local == 1, "owner_age"], bins=bins, alpha=0.55, density=True,
        label=f"Local (n={NUM['n_biased_treated']:,})", color="#DD8452")
ax.axvline(55, ls="--", lw=0.8, color="grey", label="Legal threshold (55)")
ax.set_xlabel("Owner age (S), years"); ax.set_ylabel("Density")
ax.set_title("Biased sample: overlap of S by treatment", fontsize=9)
ax.legend(fontsize=7, frameon=False)
fig.tight_layout()
for ext in ["pdf", "png"]:
    fig.savefig(OUT / f"figure1_overlap.{ext}", dpi=200)
plt.close(fig)
NUM["age_range_biased"] = [biased.groupby("local")["owner_age"].min().tolist(),
                           biased.groupby("local")["owner_age"].max().tolist()]

# ---------------------------------------------------------------------------
# 3. Naive estimate on the biased sample (no S)
# ---------------------------------------------------------------------------
rng_b = np.random.default_rng(SEED + 1)
t_ndim = dim(biased)
rows.append(row("Difference in means", "Biased", t_ndim, cluster_boot(biased, dim, rng_b)))
m_naive = reg(biased, covs=X_COVS)
t_naive = m_naive.params["local"]
rows.append(row("Regression: Y on D + female, Luluwa, state job (no S)", "Biased", t_naive,
                cluster_boot(biased, lambda d: reg(d, covs=X_COVS).params["local"], rng_b),
                m_naive.bse["local"]))
m_adj = reg(biased, covs=COVS)
rows.append(row("Regression: Y on D + S + X (backdoor adjustment)", "Biased", m_adj.params["local"],
                cluster_boot(biased, lambda d: reg(d, covs=COVS).params["local"], rng_b),
                m_adj.bse["local"]))
NUM["tau_dim_biased"], NUM["tau_naive"] = t_ndim, t_naive
NUM["tau_adj_ols_biased"] = m_adj.params["local"]
tab1 = pd.DataFrame(rows)
tab1.to_csv(OUT / "table1_benchmark.csv", index=False)

# ---------------------------------------------------------------------------
# 4. DoWhy on the biased sample (DAG 2)
# ---------------------------------------------------------------------------
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
log = io.StringIO()
with redirect_stdout(log):
    print("=== Step 1: model ===")
    model = CausalModel(data=dw, treatment="local", outcome="exempt", graph=gml_graph)
    print("treatment:", model._treatment, "| outcome:", model._outcome)
    print("\n=== Step 2: identify ===")
    estimand = model.identify_effect(proceed_when_unidentifiable=True)
    print(estimand)
    print("\n=== Step 3: estimate ===")
    estimate = model.estimate_effect(identified_estimand=estimand,
                                     method_name="backdoor.linear_regression",
                                     test_significance=True)
    print("estimate.value =", estimate.value)
    print("\n=== Step 4: refute ===")
    np.random.seed(SEED)
    refute_cc = model.refute_estimate(estimand, estimate, method_name="random_common_cause",
                                      random_seed=SEED, num_simulations=100)
    print(refute_cc)
    refute_subset = model.refute_estimate(estimand, estimate, method_name="data_subset_refuter",
                                          subset_fraction=0.4, random_seed=SEED,
                                          num_simulations=100)
    print(refute_subset)
(OUT / "dowhy_log.txt").write_text(log.getvalue())
NUM["dowhy_estimate"] = float(estimate.value)
NUM["dowhy_backdoor_vars"] = estimand.get_backdoor_variables()
NUM["refute_cc_new"] = float(refute_cc.new_effect)
NUM["refute_cc_p"] = float(refute_cc.refutation_result["p_value"])
NUM["refute_subset_new"] = float(refute_subset.new_effect)
NUM["refute_subset_p"] = float(refute_subset.refutation_result["p_value"])

# DAG 2 figure (graphviz)
dot = r"""digraph G { rankdir=LR; node [shape=ellipse, fontname=Helvetica, fontsize=11];
 S [label="S: owner age", style=filled, fillcolor="#FDE2C8"];
 D [label="D: Local", style=filled, fillcolor="#DCE8F5"];
 Y [label="Y: exempt", style=filled, fillcolor="#DCE8F5"];
 X [label="X: female, Luluwa,\nstate job"];
 S -> D [color="#C0392B", penwidth=2.2]; S -> Y [color="#C0392B", penwidth=2.2];
 D -> Y [penwidth=1.6]; X -> Y; }"""
for ext in ["pdf", "png"]:
    subprocess.run(["dot", f"-T{ext}", "-o", str(OUT / f"figure2_dag2.{ext}")],
                   input=dot.encode(), check=True)

# ---------------------------------------------------------------------------
# LaTeX tables
# ---------------------------------------------------------------------------
def f3(x):
    return f"{x:.3f}"


with open(OUT / "table1_benchmark.tex", "w") as fh:
    fh.write("\\begin{tabular}{llccc}\n\\toprule\nSample & Estimator & $\\hat\\tau$ & Cluster SE & Bootstrap 95\\% CI\\\\\n\\midrule\n")
    for r in rows:
        se = "" if pd.isna(r["cluster_se"]) or r["cluster_se"] is None else f3(r["cluster_se"])
        fh.write(f"{r['sample']} & {r['estimate']} & {f3(r['tau'])} & {se} & [{f3(r['boot_lo'])}, {f3(r['boot_hi'])}]\\\\\n")
    fh.write(f"Biased & DoWhy backdoor linear regression & {f3(estimate.value)} & & \\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

with open(OUT / "table2_exemption_reasons.tex", "w") as fh:
    fh.write("\\begin{tabular}{lccccc}\n\\toprule\nOutcome (0/1) & Central & Local & $\\hat\\tau$ & SE & $N$\\\\\n\\midrule\n")
    for r in reasons.itertuples():
        star = "***" if r.p < .01 else "**" if r.p < .05 else "*" if r.p < .1 else ""
        fh.write(f"{r.outcome} & {f3(r.central_mean)} & {f3(r.local_mean)} & {f3(r.tau)}{star} & {f3(r.se)} & {r.N:,}\\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

with open(OUT / "table3_balance.tex", "w") as fh:
    fh.write("\\begin{tabular}{lcccccc}\n\\toprule\n & \\multicolumn{3}{c}{Full sample} & \\multicolumn{3}{c}{Biased sample}\\\\\n\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}\n"
             "Covariate & Central & Local & $p$ & Central & Local & $p$\\\\\n\\midrule\n")
    for r in bal.itertuples():
        fmt = (lambda x: f"{x:.1f}") if r.covariate.startswith("Owner age") else f3
        fh.write(f"{r.covariate} & {fmt(r.full_central)} & {fmt(r.full_local)} & {f3(r.full_p)} & "
                 f"{fmt(r.biased_central)} & {fmt(r.biased_local)} & {f3(r.biased_p)}\\\\\n")
    fh.write(f"$N$ & {NUM['n_full_control']:,} & {NUM['n_full_treated']:,} & & {NUM['n_biased_control']:,} & {NUM['n_biased_treated']:,} & \\\\\n")
    fh.write("\\bottomrule\n\\end{tabular}\n")

NUM["table1"] = tab1.to_dict("records")
NUM["balance"] = bal.to_dict("records")
(OUT / "numbers.json").write_text(json.dumps(NUM, indent=2, default=float))
print(tab1.round(4).to_string())
print(reasons.round(4).to_string())
print(bal.round(3).to_string())
print(log.getvalue())
