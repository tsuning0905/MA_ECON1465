"""
02_week4_trees.py  --  Week 4 report: trees, bagging, random forest, boosting
=============================================================================
Research question: does chief collection (Local) instead of state collection
(Central) change exemptions / bribery, and for whom?

Input   data_intermediate/exemption_analysis.csv.gz   (<- 01b_build_exemption_data.py)
Output  03_output/week4/
    table_w4_0_ols_effects.{tex,csv}       OLS Local-Central effects (context for Sec. 1)
    figure_w4_1_regression_tree.{pdf,png}  Report Figure 1: pruned regression tree
    figure_w4_1b_tree_cv.{pdf,png}         CV error vs number of leaves (pruning path)
    table_w4_2_rf_importance.{tex,csv}     Report Table 1: RF importance (MDI + permutation)
    figure_w4_2_rf_importance.{pdf,png}    same as a bar chart
    table_w4_3_model_errors.{tex,csv}      Report Table 2: test MSE / RMSE by model
    figure_w4_3_boosting_cv.{pdf,png}      boosting CV error vs number of trees
    week4_numbers.json                     every number quoted in the report text

Design
    Prediction target  Y = exempt (0/1)   -> MSE here is the Brier score
    Sample             Local + Central properties in the household-survey subsample
                       (owner age and sex observed), so splits are interpretable
    Train / test       80/20 split BY NEIGHBOURHOOD (a7), since treatment varies by a7
    Tuning             10-fold GroupKFold on the training set only; the test set is
                       used once, at the end (boosting iterations are NOT chosen on test)
    Missing features   coded -1 (trees can split them off); listed in the README
    Seed               SEED = 0 for every random step
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import GridSearchCV, GroupKFold, GroupShuffleSplit
from sklearn.tree import DecisionTreeRegressor, export_text, plot_tree

SEED = 0
REPO_DIR = Path(os.environ.get("REPO_DIR", Path(__file__).resolve().parents[1]))
INT = REPO_DIR / "data_intermediate"
OUT = REPO_DIR / "03_output" / "week4"
OUT.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({"font.size": 9, "savefig.bbox": "tight", "figure.dpi": 150})


def save(fig, name):
    for ext in ("pdf", "png"):
        fig.savefig(OUT / f"{name}.{ext}")
    plt.close(fig)


df = pd.read_csv(INT / "exemption_analysis.csv.gz")
NUM = {}  # numbers quoted in the report

# =============================================================================
# Table W4-0. OLS Local effects (stratum FE, SE clustered by neighbourhood)
#   Context for Section 1: what OLS already tells us, to compare with the tree.
# =============================================================================
OLS_OUTCOMES = [("exempt", "Exempt (any reason)"),
                ("exempt_elderly", "Exempt: old age"),
                ("exempt_widow", "Exempt: widow"),
                ("exempt_other_reason", "Exempt: other reason"),
                ("exempt_elderly_u60", "Old-age exempt, owner $<$60"),
                ("exempt_elderly_u55", "Old-age exempt, owner $<$55"),
                ("bribe", "Reports paying a bribe")]


def ols_local(data, y):
    s = data[[y, "local", "stratum", "a7"]].dropna()
    m = smf.ols(f"{y} ~ local + C(stratum)", data=s).fit(
        cov_type="cluster", cov_kwds={"groups": s["a7"]})
    return dict(outcome=y, coef=m.params["local"], se=m.bse["local"],
                p=m.pvalues["local"], central_mean=s.loc[s.local == 0, y].mean(),
                n=int(m.nobs), clusters=s["a7"].nunique())


rows = [dict(ols_local(df, y), label=lab) for y, lab in OLS_OUTCOMES]
# heterogeneity by owner age, survey sample
sv = df[df.survey_sample == 1]
for lab, sub in [("Exempt, owner $<$60", sv[sv.owner_age < 60]),
                 ("Exempt, owner $\\geq$60", sv[sv.owner_age >= 60])]:
    rows.append(dict(ols_local(sub, "exempt"), label=lab))
ols = pd.DataFrame(rows)
ols.to_csv(OUT / "table_w4_0_ols_effects.csv", index=False)


def stars(p):
    return "***" if p < .01 else "**" if p < .05 else "*" if p < .1 else ""


with open(OUT / "table_w4_0_ols_effects.tex", "w") as f:
    f.write("\\begin{tabular}{lcccc}\n\\hline\n"
            "Outcome & Local $-$ Central & (SE) & Central mean & N \\\\\n\\hline\n")
    for r in ols.itertuples():
        f.write(f"{r.label} & {r.coef:.4f}{stars(r.p)} & ({r.se:.4f}) & "
                f"{r.central_mean:.4f} & {r.n:,} \\\\\n")
    f.write("\\hline\n\\end{tabular}\n")
for r in ols.itertuples():
    NUM[f"ols_{r.outcome}_{r.label[:12]}"] = dict(coef=r.coef, se=r.se, p=r.p,
                                                   central_mean=r.central_mean, n=r.n)

# =============================================================================
# Prediction set-up (shared by every model below)
# =============================================================================
d = df[df.survey_sample == 1].copy()
d = pd.concat([d, pd.get_dummies(d["commune"].astype(int), prefix="commune", dtype=int)], axis=1)
FEATURES = ["local", "owner_age", "owner_female", "owner_luluwa", "coethnic_collector",
            "job_gov", "house_mm", "walls", "rate", "tmt_2016", "dist_center",
            "transport_cost"] + sorted(c for c in d.columns if c.startswith("commune_"))
LABELS = {"local": "Local (chief collects)", "owner_age": "Owner age",
          "owner_female": "Owner female", "owner_luluwa": "Owner Luluwa",
          "coethnic_collector": "Coethnic with collector", "job_gov": "Gov. job in household",
          "house_mm": "Brick house", "walls": "Wall material", "rate": "Assigned tax rate",
          "tmt_2016": "2016 campaign arm", "dist_center": "Distance to centre",
          "transport_cost": "Transport cost", "commune_1": "Commune 1",
          "commune_2": "Commune 2", "commune_3": "Commune 3", "commune_4": "Commune 4"}
X = d[FEATURES].fillna(-1).astype(float)
y = d["exempt"].to_numpy(float)
g = d["a7"].to_numpy()

tr, te = next(GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED).split(X, y, g))
Xtr, Xte, ytr, yte, gtr = X.iloc[tr], X.iloc[te], y[tr], y[te], g[tr]
cv = GroupKFold(n_splits=10)
NUM["sample"] = dict(n=len(d), n_train=len(tr), n_test=len(te),
                     a7_train=int(len(set(gtr))), a7_test=int(len(set(g[te]))),
                     p=len(FEATURES), exempt_rate=float(y.mean()))


def mse(p):
    return float(np.mean((yte - p) ** 2))


errors = {}
errors["Mean only (benchmark)"] = dict(test_mse=mse(np.full(len(yte), ytr.mean())))
errors["OLS (linear probability)"] = dict(
    test_mse=mse(LinearRegression().fit(Xtr, ytr).predict(Xte)))

# =============================================================================
# Figure W4-1. Regression tree, pruned by cost complexity (alpha via 10-fold CV)
# =============================================================================
MIN_LEAF = 50   # each leaf needs >= 50 properties so leaf means are not noise
big = DecisionTreeRegressor(min_samples_leaf=MIN_LEAF, random_state=SEED).fit(Xtr, ytr)
alphas = big.cost_complexity_pruning_path(Xtr, ytr).ccp_alphas[:-1]
grid = GridSearchCV(DecisionTreeRegressor(min_samples_leaf=MIN_LEAF, random_state=SEED),
                    {"ccp_alpha": alphas}, cv=cv, scoring="neg_mean_squared_error",
                    refit=True).fit(Xtr, ytr, groups=gtr)
tree = grid.best_estimator_
errors["Regression tree (pruned)"] = dict(test_mse=mse(tree.predict(Xte)),
                                          cv_mse=-grid.best_score_)
NUM["tree"] = dict(alpha=float(grid.best_params_["ccp_alpha"]), leaves=int(tree.get_n_leaves()),
                   depth=int(tree.get_depth()), uses_local=bool((tree.tree_.feature == 0).any()))
(OUT / "tree_rules.txt").write_text(export_text(tree, feature_names=FEATURES, decimals=2))

fig, ax = plt.subplots(figsize=(10.5, 4.6))
plot_tree(tree, feature_names=[LABELS[f] for f in FEATURES], filled=True, rounded=True,
          impurity=False, precision=2, fontsize=9, ax=ax)
ax.set_title(f"Regression tree for P(exempt), pruned by 10-fold CV "
             f"({tree.get_n_leaves()} leaves; value = share exempt)", fontsize=10)
save(fig, "figure_w4_1_regression_tree")

# CV curve: mean CV MSE (+/- 1 SE) against number of leaves
res = pd.DataFrame(grid.cv_results_)
res["leaves"] = [DecisionTreeRegressor(min_samples_leaf=MIN_LEAF, ccp_alpha=a, random_state=SEED)
                 .fit(Xtr, ytr).get_n_leaves() for a in res["param_ccp_alpha"]]
res["se"] = res["std_test_score"] / np.sqrt(cv.get_n_splits())
fig, ax = plt.subplots(figsize=(5, 3))
ax.errorbar(res["leaves"], -res["mean_test_score"], yerr=res["se"], fmt="o-", ms=3, capsize=2)
ax.axvline(tree.get_n_leaves(), ls="--", c="grey")
ax.set_xscale("log"); ax.set_xlabel("Number of leaves"); ax.set_ylabel("10-fold CV MSE")
save(fig, "figure_w4_1b_tree_cv")

# =============================================================================
# Bagging and random forest (500 trees; OOB error reported as well)
# =============================================================================
P = len(FEATURES)
MTRY = max(1, round(P / 3))    # standard regression default m = p/3
bag = RandomForestRegressor(n_estimators=500, max_features=P, oob_score=True,
                            random_state=SEED, n_jobs=-1).fit(Xtr, ytr)
rf = RandomForestRegressor(n_estimators=500, max_features=MTRY, oob_score=True,
                           random_state=SEED, n_jobs=-1).fit(Xtr, ytr)
for name, m in [(f"Bagging (m = p = {P})", bag), (f"Random forest (m = {MTRY})", rf)]:
    errors[name] = dict(test_mse=mse(m.predict(Xte)),
                        oob_mse=float(np.mean((ytr - m.oob_prediction_) ** 2)))

# =============================================================================
# Table W4-2. Random forest importance: impurity (MDI) and test-set permutation
# =============================================================================
perm = permutation_importance(rf, Xte, yte, n_repeats=20, random_state=SEED,
                              scoring="neg_mean_squared_error", n_jobs=-1)
imp = pd.DataFrame({"feature": FEATURES, "label": [LABELS[f] for f in FEATURES],
                    "mdi": rf.feature_importances_, "perm_mse_increase": perm.importances_mean,
                    "perm_se": perm.importances_std / np.sqrt(20)})
imp = imp.sort_values("mdi", ascending=False).reset_index(drop=True)
imp["mdi_rank"] = np.arange(1, len(imp) + 1)
imp["perm_rank"] = imp["perm_mse_increase"].rank(ascending=False).astype(int)
imp.to_csv(OUT / "table_w4_2_rf_importance.csv", index=False)
with open(OUT / "table_w4_2_rf_importance.tex", "w") as f:
    f.write("\\begin{tabular}{lcccc}\n\\hline\n Feature & MDI & Rank & "
            "Permutation $\\Delta$MSE ($\\times 10^3$) & Rank \\\\\n\\hline\n")
    for r in imp.itertuples():
        f.write(f"{r.label} & {r.mdi:.3f} & {r.mdi_rank} & {1e3 * r.perm_mse_increase:.2f} & "
                f"{r.perm_rank} \\\\\n")
    f.write("\\hline\n\\end{tabular}\n")
NUM["importance"] = imp[["feature", "mdi", "mdi_rank", "perm_mse_increase", "perm_rank"]].to_dict("records")

fig, axes = plt.subplots(1, 2, figsize=(7.5, 3.3), sharey=True)
order = imp.iloc[::-1]
axes[0].barh(order["label"], order["mdi"], color="#4C72B0")
axes[0].set_title("Impurity decrease (MDI), training data")
axes[1].barh(order["label"], 1e3 * order["perm_mse_increase"],
             xerr=1e3 * order["perm_se"], color="#DD8452")
axes[1].set_title("Permutation: test MSE increase ($\\times10^3$)")
axes[1].axvline(0, c="k", lw=.6)
save(fig, "figure_w4_2_rf_importance")

# =============================================================================
# Boosting: number of trees chosen by 10-fold grouped CV inside the training set
# =============================================================================
LR, DEPTH, B_MAX = 0.01, 3, 1500
curves = []
for f_tr, f_va in cv.split(Xtr, ytr, gtr):
    m = GradientBoostingRegressor(n_estimators=B_MAX, learning_rate=LR, max_depth=DEPTH,
                                  random_state=SEED).fit(Xtr.iloc[f_tr], ytr[f_tr])
    curves.append([np.mean((ytr[f_va] - p) ** 2) for p in m.staged_predict(Xtr.iloc[f_va])])
cv_curve = np.mean(curves, axis=0)
B_best = int(np.argmin(cv_curve) + 1)
boost = GradientBoostingRegressor(n_estimators=B_best, learning_rate=LR, max_depth=DEPTH,
                                  random_state=SEED).fit(Xtr, ytr)
errors[f"Boosting (B = {B_best}, $\\lambda$ = {LR}, d = {DEPTH})"] = dict(
    test_mse=mse(boost.predict(Xte)), cv_mse=float(cv_curve.min()))
NUM["boosting"] = dict(B_best=B_best, lr=LR, depth=DEPTH)

fig, ax = plt.subplots(figsize=(5, 3))
ax.plot(np.arange(1, B_MAX + 1), cv_curve)
ax.axvline(B_best, ls="--", c="grey")
ax.set_xlabel("Number of boosting iterations"); ax.set_ylabel("10-fold CV MSE")
save(fig, "figure_w4_3_boosting_cv")

# =============================================================================
# Table W4-3. Prediction errors on the held-out neighbourhoods
# =============================================================================
err = pd.DataFrame(errors).T.reset_index(names="model")
err["test_rmse"] = np.sqrt(err["test_mse"])
base = err.loc[0, "test_mse"]
err["pct_vs_mean"] = 100 * (err["test_mse"] / base - 1)
err.to_csv(OUT / "table_w4_3_model_errors.csv", index=False)
with open(OUT / "table_w4_3_model_errors.tex", "w") as f:
    f.write("\\begin{tabular}{lcccc}\n\\hline\nModel & Test MSE & Test RMSE & "
            "\\% vs mean & OOB MSE \\\\\n\\hline\n")
    for r in err.itertuples():
        oob = f"{r.oob_mse:.4f}" if pd.notna(getattr(r, "oob_mse", np.nan)) else "--"
        f.write(f"{r.model} & {r.test_mse:.4f} & {r.test_rmse:.4f} & {r.pct_vs_mean:+.1f} & {oob} \\\\\n")
    f.write("\\hline\n\\end{tabular}\n")
NUM["errors"] = err.to_dict("records")

(OUT / "week4_numbers.json").write_text(json.dumps(NUM, indent=2, default=float))
print(ols[["label", "coef", "se", "p", "central_mean", "n"]].round(4).to_string())
print(json.dumps(NUM["tree"]), json.dumps(NUM["sample"]))
print((OUT / "tree_rules.txt").read_text())
print(imp[["label", "mdi", "mdi_rank", "perm_mse_increase", "perm_rank"]].round(4).to_string())
print(err.round(4).to_string())
