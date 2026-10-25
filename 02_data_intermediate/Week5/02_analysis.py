"""
02_analysis.py  --  ECO1465 Week 5 report, Tsu Ning Tsao
Reads data_intermediate/, writes all tables, figures and report numbers to 03_output/.

  Figure 1  DAG 1 (experiment), DAG 2 (biased sample, S = age), DAG 3 (mediator / collider)
  Figure 2  Exemption rate by age group, Central neighborhoods (how well S predicts Y)
  Table 1   Candidate selection variables S: predictive power in Central, joint model, balance
  Table 2   Correlations among the pre-treatment X variables
  Table 3   Effect of Local vs Central on exemptions (main, by reason, secondary outcomes)
  numbers.tex  every number quoted in the report text, as LaTeX macros

Estimator: OLS / linear probability model, stratum fixed effects for treatment
effects, standard errors clustered by neighborhood (a7), the level of randomization.
Requires graphviz (`dot`) on the PATH for Figure 1.
"""
import os
import subprocess
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

np.random.seed(1465)  # nothing below is random; set by convention

ROOT = os.environ.get("PROJ_ROOT", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INT = os.path.join(ROOT, "data_intermediate")
OUT = os.path.join(ROOT, "03_output")
os.makedirs(OUT, exist_ok=True)

df = pd.read_csv(os.path.join(INT, "w5_compound.csv"))
end = pd.read_csv(os.path.join(INT, "w5_endline.csv"))
lk = df[df["linked"] == 1].copy()          # compounds linked to the baseline survey
cen = lk[lk["local"] == 0].copy()          # Central (control) group only
NUM = {}                                    # numbers quoted in the report


def cl(formula, d):
    return smf.ols(formula, d).fit(cov_type="cluster", cov_kwds={"groups": d["a7"]})


def ate(d, y, rhs="local + C(stratum)", term="local"):
    d = d.dropna(subset=[y] + [v for v in ["coethnic"] if v in rhs])
    m = cl(f"{y} ~ {rhs}", d)
    return dict(central_mean=d.loc[d["local"] == 0, y].mean(), coef=m.params[term], se=m.bse[term],
                p=m.pvalues[term], n=int(m.nobs), clusters=d["a7"].nunique())


def to_tex(t, name, fmt):
    t.to_csv(os.path.join(OUT, f"{name}.csv"), index=False)
    with open(os.path.join(OUT, f"{name}.tex"), "w") as f:
        f.write(t.to_latex(index=False, escape=False, na_rep="", formatters=fmt, column_format="l" + "r" * (t.shape[1] - 1)))


# ============================================================ Table 1 ========
CAND = [("age", "Age of respondent (years)"), ("old", "Respondent aged 60+"),
        ("no_job", "Respondent has no job"), ("edu", "Education level"),
        ("female", "Female respondent"), ("hh_size", "Household size"),
        ("log_value", "Log predicted property value"), ("coethnic", "Coethnic with chief")]
rows = []
for v, lab in CAND:
    k = cen.dropna(subset=[v])
    m = cl(f"exempt ~ {v}", k)
    bal = cl(f"{v} ~ local + C(stratum)", lk.dropna(subset=[v]))
    rows.append(dict(var=v, Candidate=lab, coef=m.params[v], se=m.bse[v], R2=m.rsquared,
                     AUC=roc_auc_score(k["exempt"], k[v]), n=int(m.nobs), bal_p=bal.pvalues["local"]))
t1 = pd.DataFrame(rows).sort_values("R2", ascending=False)
# joint model: does age keep its predictive power once the other X are held fixed?
jv = ["age", "no_job", "edu", "female", "hh_size", "log_value"]
kj = cen.dropna(subset=jv)
mj = cl("exempt ~ " + " + ".join(jv), kj)
t1["joint"] = t1["var"].map(lambda v: mj.params.get(v, np.nan))
t1["joint_se"] = t1["var"].map(lambda v: mj.bse.get(v, np.nan))
f3 = lambda x: "" if pd.isna(x) else f"{x:.3f}"
f4 = lambda x: "" if pd.isna(x) else f"{x:.4f}"
t1_out = t1[["Candidate", "coef", "se", "R2", "AUC", "joint", "n", "bal_p"]].rename(columns={
    "coef": "Coef.", "se": "SE", "R2": "$R^2$", "AUC": "AUC", "joint": "Joint coef.", "n": "N", "bal_p": "Balance $p$"})
to_tex(t1_out, "Table1_candidates_S",
       {"Coef.": f4, "SE": f4, "$R^2$": f3, "AUC": f3, "Joint coef.": f4, "N": lambda x: f"{int(x):,}", "Balance $p$": f3})
a = t1.set_index("var")
NUM.update(SageCoef=f"{a.loc['age','coef']*100:.2f}", SageR=f"{a.loc['age','R2']:.3f}",
           SageAUC=f"{a.loc['age','AUC']:.2f}", SageN=f"{int(a.loc['age','n']):,}",
           SageBal=f"{a.loc['age','bal_p']:.2f}", SoldCoef=f"{a.loc['old','coef']*100:.1f}",
           SoldR=f"{a.loc['old','R2']:.3f}", SnextR=f"{t1.iloc[2]['R2']:.3f}",
           SjointAge=f"{mj.params['age']*100:.2f}", SjointN=f"{int(mj.nobs):,}",
           SjointR=f"{mj.rsquared:.3f}", SvalR=f"{a.loc['log_value','R2']:.4f}")
NUM["SratioR"] = f"{a.loc['age','R2'] / a.loc['log_value','R2']:.0f}"

# ============================================================ Table 2 ========
xv = ["age", "female", "edu", "no_job", "hh_size", "log_value", "coethnic"]
lab = {"age": "Age", "female": "Female", "edu": "Education", "no_job": "No job", "hh_size": "HH size",
       "log_value": "Log value", "coethnic": "Coethnic"}
cor = lk[xv].corr().round(2)
cor.index = [lab[v] for v in xv]; cor.columns = [lab[v] for v in xv]
cor = cor.where(np.tril(np.ones(cor.shape, dtype=bool)))
t2 = cor.reset_index().rename(columns={"index": ""})
to_tex(t2, "Table2_X_correlations", {c: (lambda x: "" if pd.isna(x) else f"{x:.2f}") for c in t2.columns[1:]})
NUM.update(CageEdu=f"{lk[['age','edu']].corr().iloc[0,1]:.2f}", CageJob=f"{lk[['age','no_job']].corr().iloc[0,1]:.2f}",
           CageFem=f"{lk[['age','female']].corr().iloc[0,1]:.2f}", CfemEdu=f"{lk[['female','edu']].corr().iloc[0,1]:.2f}")

# ============================================================ Table 3 ========
rows = []
for y, labl, d, rhs, term in [
        ("exempt", "Any exemption", df, "local + C(stratum)", "local"),
        ("exempt_elderly", "\\quad Old age (Troisieme age)", df, "local + C(stratum)", "local"),
        ("exempt_widow", "\\quad Widow (Veuve)", df, "local + C(stratum)", "local"),
        ("exempt_other", "\\quad Other reasons", df, "local + C(stratum)", "local"),
        ("exempt", "Any exemption, linked sample", lk, "local + C(stratum)", "local"),
        ("exempt", "Any exemption, linked sample, + age", lk.dropna(subset=["age"]), "local + age + C(stratum)", "local"),
        ("unjustified_elderly", "Old-age exemption, respondent $<60$", lk, "local + C(stratum)", "local"),
        ("exempt", "Local $\\times$ coethnic (interaction)", lk, "local * coethnic + C(stratum)", "local:coethnic"),
        ("bribe", "Self-reported bribe (endline)", end, "local + C(stratum)", "local")]:
    r = ate(d, y, rhs, term); r["Outcome"] = labl; rows.append(r)
t3 = pd.DataFrame(rows)
to_tex(t3[["Outcome", "central_mean", "coef", "se", "p", "n", "clusters"]].rename(columns={
    "central_mean": "Central mean", "coef": "Local effect", "se": "SE", "p": "$p$", "n": "N", "clusters": "Clusters"}),
    "Table3_ATE_exemptions",
    {"Central mean": f3, "Local effect": f3, "SE": f3, "$p$": f3, "N": lambda x: f"{int(x):,}", "Clusters": lambda x: f"{int(x)}"})
g = lambda i, k: t3.iloc[i][k]
NUM.update(Nall=f"{int(g(0,'n')):,}", Nnb=f"{int(g(0,'clusters'))}", Nlinked=f"{len(lk):,}",
           Mexempt=f"{g(0,'central_mean')*100:.1f}", Eexempt=f"{g(0,'coef')*100:.1f}", SEexempt=f"{g(0,'se')*100:.1f}",
           Eold=f"{g(1,'coef')*100:.1f}", SEold=f"{g(1,'se')*100:.1f}", Pold=f"{g(1,'p'):.2f}",
           Ewid=f"{g(2,'coef')*100:.1f}", SEwid=f"{g(2,'se')*100:.1f}",
           Elk=f"{g(4,'coef')*100:.1f}", Elkage=f"{g(5,'coef')*100:.1f}",
           Mun=f"{g(6,'central_mean')*100:.1f}", Eun=f"{g(6,'coef')*100:.1f}", Pun=f"{g(6,'p'):.2f}",
           Eco=f"{g(7,'coef')*100:.1f}", Pco=f"{g(7,'p'):.2f}",
           Mbr=f"{g(8,'central_mean')*100:.1f}", Ebr=f"{g(8,'coef')*100:.1f}", Pbr=f"{g(8,'p'):.2f}",
           Nbr=f"{int(g(8,'n')):,}")

# ============================================================ Figure 1 =======
DOT_BASE = """
  rankdir=LR; nodesep=0.18; ranksep=0.45; splines=true;
  node [shape=box, style="rounded", fontname="Helvetica", fontsize=11, height=0.32, margin="0.08,0.03"];
  edge [color="#777777", arrowsize=0.6];
  coin [label="Coin flip"]; strat [label="Stratum\\n(geography)"];
  D [label="Local (D)", penwidth=2]; Y [label="Exempt (Y)", penwidth=2];
  age [label="Age"]; sex [label="Sex"]; wid [label="Widowed\\n(unobserved)", style="rounded,dashed"];
  edu [label="Education"]; job [label="Employment"]; val [label="Property value"];
  eth [label="Ethnicity"]; coe [label="Coethnic\\nwith chief"];
  coin -> D; strat -> D; D -> Y [penwidth=2, color="#333333"];
  age -> wid; sex -> wid; age -> edu; sex -> edu; age -> job; edu -> job; edu -> val; job -> val;
  eth -> coe; strat -> coe; strat -> val;
  age -> Y; wid -> Y; job -> Y; val -> Y; coe -> Y;
"""


def dot(name, body):
    src = os.path.join(OUT, f"{name}.dot")
    with open(src, "w") as f:
        f.write("strict digraph G {" + body + "}")
    for ext in ("pdf", "png"):
        subprocess.run(["dot", f"-T{ext}", "-Gdpi=200", src, "-o", os.path.join(OUT, f"{name}.{ext}")], check=True)


dot("Figure1a_DAG1_experiment", DOT_BASE)
dot("Figure1b_DAG2_biased", DOT_BASE + """
  age [color="#c0392b", penwidth=2, fontcolor="#c0392b", label="Age (S)"];
  age -> D [color="#c0392b", penwidth=2.2];
  age -> Y [color="#c0392b", penwidth=2.2]; age -> wid [color="#c0392b", penwidth=2.2];
  wid -> Y [color="#c0392b", penwidth=2.2]; age -> job [color="#c0392b", penwidth=2.2];
  job -> Y [color="#c0392b", penwidth=2.2];
""")
dot("Figure1c_DAG3_mediator", """
  rankdir=LR; nodesep=0.3; ranksep=0.6;
  node [shape=box, style="rounded", fontname="Helvetica", fontsize=11, height=0.32];
  edge [color="#777777", arrowsize=0.6];
  D [label="Local (D)", penwidth=2]; Y [label="Exempt (Y)", penwidth=2];
  M [label="Chief knowledge and discretion (M)\\nendline coethnic_bias_chief", style="rounded,dashed", color="#d68910"];
  U [label="Personal tie to chief\\n(unobserved U)", style="rounded,dashed"];
  D -> M; M -> Y; D -> Y [label=" direct", fontsize=9, fontname="Helvetica"]; U -> M; U -> Y;
  {rank=same; M; U}
""")

# ============================================================ Figure 2 =======
cen["age_grp"] = pd.cut(cen["age"], [0, 29, 39, 49, 59, 69, 200],
                        labels=["<30", "30-39", "40-49", "50-59", "60-69", "70+"])
gr = cen.groupby("age_grp", observed=True)["exempt"].agg(["mean", "count", "std"])
gr["ci"] = 1.96 * gr["std"] / np.sqrt(gr["count"])
fig, ax = plt.subplots(figsize=(6.2, 2.9))
ax.bar(range(len(gr)), gr["mean"] * 100, color=["#9aa5b1"] * 4 + ["#c0392b"] * 2, width=0.62)
ax.errorbar(range(len(gr)), gr["mean"] * 100, yerr=gr["ci"] * 100, fmt="none", ecolor="#333333", capsize=3, lw=1)
for i, (m_, n_) in enumerate(zip(gr["mean"], gr["count"])):
    ax.text(i, m_ * 100 + gr["ci"].iloc[i] * 100 + 1.2, f"{m_*100:.0f}%", ha="center", fontsize=8.5)
    ax.text(i, -5.5, f"n={n_}", ha="center", fontsize=7.5, color="#555555")
ax.set_xticks(range(len(gr))); ax.set_xticklabels(gr.index)
ax.set_ylim(-8, max(gr["mean"] * 100 + gr["ci"] * 100) + 8); ax.axhline(0, color="black", lw=0.6)
ax.set_xlabel("Age of baseline respondent (2017)"); ax.set_ylabel("Compounds exempt (%)")
ax.spines[["top", "right"]].set_visible(False)
plt.tight_layout()
for ext in ("png", "pdf"):
    plt.savefig(os.path.join(OUT, f"Figure2_exempt_by_age_central.{ext}"), dpi=200, bbox_inches="tight")
plt.close()
NUM.update(Fyoung=f"{gr['mean'].iloc[0]*100:.0f}", Fold=f"{gr['mean'].iloc[-1]*100:.0f}")

# ============================================================ numbers ========
with open(os.path.join(OUT, "numbers.tex"), "w") as f:
    for k, v in NUM.items():
        v = "0.0" if v == "-0.0" else v
        f.write(f"\\newcommand{{\\{k}}}{{{v}}}\n")

pd.set_option("display.width", 200)
print(t1_out.round(4).to_string(index=False))
print(t2.to_string(index=False))
print(t3[["Outcome", "central_mean", "coef", "se", "p", "n", "clusters"]].round(4).to_string(index=False))
print(NUM)
