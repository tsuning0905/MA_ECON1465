"""
02_analysis_week3.py
====================
Week-3 report: OLS, Ridge and Lasso on the exemption outcome.

Input : data_intermediate/week3_exemption_analysis.csv   (from 01_preanalysis_week3.py)
Output: 03_output/week3/
    Table1_OLS_exemption.tex / .csv      Section 1 (OLS)
    Figure1_Ridge.pdf / .png             Section 2 (Ridge path + CV curve)
    Figure2_Lasso.pdf / .png             Section 3 (Lasso path + CV curve)
    penalized_coefficients.csv           Ridge/Lasso coefficients at lambda_min and lambda_1se

Model (same X for all three estimators):
    exempt_i = b0 + b1 Local_j + X_i'g + (Local_j * X_i)'d + stratum FE + house FE + time FE + e_i
    X = pre-treatment baseline covariates; SEs clustered by neighbourhood (a7).

For Ridge/Lasso the fixed effects and missing-value dummies are nuisance controls: they are
partialled out of y and of every feature first (Frisch-Waugh-Lovell), so they are not penalized.
Cross-validation folds are grouped by neighbourhood, because treatment is assigned by neighbourhood.
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from sklearn.linear_model import Lasso, Ridge
from sklearn.model_selection import GroupKFold

SEED = 1465
np.random.seed(SEED)

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data_intermediate" / "week3_exemption_analysis.csv"
OUT = ROOT / "03_output" / "week3"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA)

COVARS = ["age", "female", "edu", "log_income", "hh_size", "kga_born", "work_gov1",
          "renters_b", "assets", "luluwa", "coethnic"]
LABELS = {"age": "Age", "female": "Female", "edu": "Education", "log_income": "Log income",
          "hh_size": "HH size", "kga_born": "Born in Kananga", "work_gov1": "Works for gov.",
          "renters_b": "Renters", "assets": "Assets", "luluwa": "Luluwa", "coethnic": "Co-ethnic"}
# Missing-value dummies; drop duplicates (several covariates are missing for the same rows)
MISS = list(df[[c for c in df.columns if c.endswith("_miss")]].T.drop_duplicates().index)

# Table/figure-specific variables: centre covariates at the sample mean before interacting,
# so the Local coefficient is the effect for an average household (not for age = 0).
for c in COVARS:
    df[c] = df[c] - df[c].mean()
    df[f"localX{c}"] = df["local"] * df[c]
INTER = [f"localX{c}" for c in COVARS]
FE = "C(stratum) + C(house) + C(time_fe)"

# ===========================================================================
# Table 1. OLS
# ===========================================================================
specs = [  # (column title, outcome, regressors)
    ("Exempt", "exempt", ["local"]),
    ("Exempt", "exempt", ["local"] + COVARS + MISS),
    ("Exempt", "exempt", ["local"] + COVARS + INTER + MISS),
    ("Senior", "exempt_senior", ["local"] + COVARS + INTER + MISS),
    ("Widow", "exempt_widow", ["local"] + COVARS + INTER + MISS),
    ("Unjust. senior", "unjust_senior", ["local"] + COVARS + INTER + MISS),
]
SHOW = ["local", "age", "coethnic", "female", "localXage", "localXcoethnic", "localXfemale",
        "localXlog_income", "localXassets"]
SHOW_LAB = {"local": "Local", **LABELS, **{f"localX{c}": f"Local $\\times$ {LABELS[c]}" for c in COVARS}}

def stars(p):
    return "^{***}" if p < 0.01 else "^{**}" if p < 0.05 else "^{*}" if p < 0.1 else ""

results, rows = [], []
for title, y, xs in specs:
    d = df.dropna(subset=[y])
    xs = [x for x in xs if d[x].std() > 0]      # e.g. age_miss is all 0 once age is required
    m = smf.ols(f"{y} ~ {' + '.join(xs)} + {FE}", data=d).fit(
        cov_type="cluster", cov_kwds={"groups": d["a7"]})
    results.append((title, y, m, d))
    for v in m.params.index:
        rows.append({"column": len(results), "outcome": y, "variable": v, "coef": m.params[v],
                     "se": m.bse[v], "p": m.pvalues[v], "N": int(m.nobs)})
pd.DataFrame(rows).to_csv(OUT / "Table1_OLS_exemption.csv", index=False)

ncol = len(results)
tex = [r"\begin{table}[!htbp]\centering\footnotesize",
       r"\caption{OLS: effect of Local (vs Central) collection on tax exemptions}",
       r"\label{tab:ols}",
       r"\begin{tabular}{l" + "c" * ncol + "}", r"\hline\hline",
       " & " + " & ".join(f"({i+1})" for i in range(ncol)) + r" \\",
       " & " + " & ".join(t for t, *_ in results) + r" \\ \hline"]
for v in SHOW:
    b, s = [], []
    for _, _, m, _ in results:
        if v in m.params:
            b.append(f"${m.params[v]:.3f}{stars(m.pvalues[v])}$")
            s.append(f"({m.bse[v]:.3f})")
        else:
            b.append(""); s.append("")
    tex += [SHOW_LAB[v] + " & " + " & ".join(b) + r" \\", " & " + " & ".join(s) + r" \\"]
tex.append(r"\hline")
tex.append("Baseline covariates & " + " & ".join("No" if i == 0 else "Yes" for i in range(ncol)) + r" \\")
tex.append("Local $\\times$ covariates & " + " & ".join("Yes" if i >= 2 else "No" for i in range(ncol)) + r" \\")
tex.append("Stratum, house, time FE & " + " & ".join(["Yes"] * ncol) + r" \\")
tex.append("Central mean & " + " & ".join(f"{d.loc[d.local == 0, y].mean():.3f}" for _, y, _, d in results) + r" \\")
tex.append("Observations & " + " & ".join(f"{int(m.nobs):,}" for _, _, m, _ in results) + r" \\")
tex.append("Clusters & " + " & ".join(str(d['a7'].nunique()) for *_, d in results) + r" \\")
tex.append("$R^2$ & " + " & ".join(f"{m.rsquared:.3f}" for _, _, m, _ in results) + r" \\")
tex += [r"\hline\hline", r"\end{tabular}",
        r"\begin{minipage}{0.97\linewidth}\vspace{3pt}\scriptsize "
        r"Notes: Unit is a property registered by a collector in a Central or Local neighbourhood "
        r"and matched to the 2017 baseline survey. Exempt = collector recorded the property as tax-exempt; "
        r"Senior/Widow = exempted for that reason; Unjust.\ senior = exempted as a senior although the owner "
        r"was under 55 at baseline. Covariates are centred at the sample mean, so Local is the effect for an average household. Columns (2)--(6) also control for HH size, education, log income, "
        r"born in Kananga, works for government, renters, assets, Luluwa and missing-value dummies; "
        r"columns (3)--(6) interact every covariate with Local. Only key coefficients are shown. "
        r"Standard errors clustered by neighbourhood in parentheses. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$."
        r"\end{minipage}", r"\end{table}"]
(OUT / "Table1_OLS_exemption.tex").write_text("\n".join(tex))

# ===========================================================================
# Figures 1-2. Ridge and Lasso (outcome: exempt, full specification as column 3)
# ===========================================================================
FEATS = ["local"] + COVARS + INTER
FEAT_LAB = {"local": "Local", **LABELS, **{f"localX{c}": f"Local×{LABELS[c]}" for c in COVARS}}

# Partial out the unpenalized nuisance controls (FE + missing dummies)
nuis = pd.get_dummies(df[["stratum", "house", "time_fe"]].astype(str), drop_first=True).astype(float)
Z = np.column_stack([np.ones(len(df)), nuis.values, df[MISS].values])
def resid(v):
    beta, *_ = np.linalg.lstsq(Z, v, rcond=None)
    return v - Z @ beta
y = resid(df["exempt"].values.astype(float))
X = np.column_stack([resid(df[f].values.astype(float)) for f in FEATS])
X = (X - X.mean(0)) / X.std(0)          # standardize so penalties are comparable
y = y - y.mean()
groups = df["a7"].values

def path_and_cv(model_cls, lambdas, n_folds=10):
    coefs = np.array([model_cls(alpha=a, max_iter=50000).fit(X, y).coef_ for a in lambdas])
    cv = GroupKFold(n_splits=n_folds, shuffle=True, random_state=SEED)
    mse = np.zeros((n_folds, len(lambdas)))
    for k, (tr, te) in enumerate(cv.split(X, y, groups)):
        for j, a in enumerate(lambdas):
            fit = model_cls(alpha=a, max_iter=50000).fit(X[tr], y[tr])
            mse[k, j] = np.mean((y[te] - fit.predict(X[te])) ** 2)
    mean, se = mse.mean(0), mse.std(0, ddof=1) / np.sqrt(n_folds)
    j_min = int(np.argmin(mean))
    j_1se = int(np.max(np.where(mean <= mean[j_min] + se[j_min])[0]))  # largest lambda within 1 SE
    return coefs, mean, se, j_min, j_1se

ridge_l = np.logspace(-1, 5, 60)
lasso_l = np.logspace(-4.5, -0.8, 60)
res = {"Ridge": (ridge_l, *path_and_cv(Ridge, ridge_l)),
       "Lasso": (lasso_l, *path_and_cv(Lasso, lasso_l))}

HIGHLIGHT = {"local": "#1f4e79", "localXage": "#c0392b", "localXcoethnic": "#27ae60",
             "localXfemale": "#8e44ad", "age": "#e67e22"}

for fig_no, name in [(1, "Ridge"), (2, "Lasso")]:
    lam, coefs, mean, se, j_min, j_1se = res[name]
    fig, ax = plt.subplots(1, 2, figsize=(11, 3.9))
    for i, f in enumerate(FEATS):
        if f in HIGHLIGHT:
            ax[0].plot(np.log10(lam), coefs[:, i], color=HIGHLIGHT[f], lw=2.2, label=FEAT_LAB[f])
        else:
            ax[0].plot(np.log10(lam), coefs[:, i], color="0.75", lw=0.9)
    for j, ls in [(j_min, "--"), (j_1se, ":")]:
        for a in ax:
            a.axvline(np.log10(lam[j]), color="0.3", ls=ls, lw=1)
    ax[0].axhline(0, color="0.5", lw=0.6)
    ax[0].set_xlabel(r"$\log_{10}(\lambda)$"); ax[0].set_ylabel("Standardized coefficient")
    ax[0].set_title(f"{name} coefficient path (grey = other covariates)")
    ax[0].legend(fontsize=7.5, frameon=False, loc="center right")
    ax[1].errorbar(np.log10(lam), mean, yerr=se, fmt="o", ms=3, color="#c0392b",
                   ecolor="0.6", elinewidth=0.8, capsize=2)
    ax[1].set_xlabel(r"$\log_{10}(\lambda)$"); ax[1].set_ylabel("10-fold CV MSE")
    ax[1].set_title(f"{name} cross-validation (folds grouped by neighbourhood)")
    ax[1].text(0.02, 0.95, r"-- $\lambda_{min}$    $\cdots$ $\lambda_{1se}$", transform=ax[1].transAxes,
               fontsize=8, va="top")
    fig.tight_layout()
    for ext in ["pdf", "png"]:
        fig.savefig(OUT / f"Figure{fig_no}_{name}.{ext}", dpi=200, bbox_inches="tight")
    plt.close(fig)

# Coefficients at the CV-chosen lambdas (for the text comparison)
out = pd.DataFrame({"variable": FEATS})
for name in ["Ridge", "Lasso"]:
    lam, coefs, mean, se, j_min, j_1se = res[name]
    out[f"{name}_lambda_min"] = coefs[j_min]
    out[f"{name}_lambda_1se"] = coefs[j_1se]
    print(f"{name}: lambda_min={lam[j_min]:.4g}, lambda_1se={lam[j_1se]:.4g}, "
          f"CV MSE min={mean[j_min]:.4f}, CV MSE at largest lambda={mean[-1]:.4f}")
ols_std = np.linalg.lstsq(np.column_stack([np.ones(len(y)), X]), y, rcond=None)[0][1:]
out.insert(1, "OLS_standardized", ols_std)
out.round(4).to_csv(OUT / "penalized_coefficients.csv", index=False)
print(out.round(4).to_string(index=False))
print("[02_analysis_week3] outputs written to", OUT)
