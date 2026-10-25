"""
02_analysis.py
==============
Project One, ECO1465 - "Do Local Chiefs Grant More Discretionary Tax Exemptions?"

Builds every table and figure of the paper from data_intermediate/final_property.csv.gz
(made by 01_preanalysis.py). Section numbers follow the order of the paper.

    Section                                   Output (03_output/tables, 03_output/figures) = paper numbering
    -----------------------------------------------------------------------------------------
    S1  Summary statistics                    Table 1   table1_sumstats
    S2  Exemption-age profile                 Figure 1  fig1_exempt_by_age
    S3  Balance and attrition                 Table 2   table2_balance;  Figure 3 fig3_balance
    S4  SUTVA: neighbourhood network          Figure 4  fig4_network;    Table 3 table3_spillover
    S5  DAGs                                  Figure 2 (a)-(c) fig2a_dag1, fig2b_dag2, fig2c_dag3
    S6  Replication of the paper              Table 4   table4_replication
    S7  Main causal estimates (ATE)           Table 5   table5_ate
    S8  Effect by owner age                   Figure 5  fig5_effect_by_age
    S9  Heterogeneity (OLS interactions)      Table 6   table6_heterogeneity
    S10 Ridge and Lasso                       Figure 6  fig6a_ridge, fig6b_lasso; Table 7 table7_regularization
    S11 Robustness + randomization inference  Table 8   table8_robustness; Figure 7 fig7_ri
    S12 Tree, bagging, random forest, boosting Figure 8 fig8_tree, Table 9 table9_ml_errors,
                                              Figure 9 fig9_rf_importance, Figure 10 fig10_pdp
    -----------------------------------------------------------------------------------------
Section-specific variables (age bins, interaction terms, standardized features) are created
inside the section that uses them.

Run:  python 02_analysis/02_analysis.py            (all sections)
      python 02_analysis/02_analysis.py S7 S9      (only some sections)
Seed: 1465 for every random step (train/test split, CV folds, forests, boosting, permutations).
"""
from __future__ import annotations

import subprocess
import sys
import warnings
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import pandas as pd
import statsmodels.api as sm
import statsmodels.formula.api as smf
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LassoCV, Lasso, Ridge, LinearRegression
from sklearn.model_selection import GroupKFold, GroupShuffleSplit
from sklearn.metrics import mean_squared_error
from sklearn.tree import DecisionTreeRegressor, plot_tree

warnings.filterwarnings("ignore")

# =============================================================================
# 0. Setup
# =============================================================================
ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "data_intermediate"
TAB = ROOT / "03_output" / "tables"
FIG = ROOT / "03_output" / "figures"
TAB.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)

SEED = 1465
rng = np.random.default_rng(SEED)
C_CEN, C_LOC, C_GREY = "#4C72B0", "#DD8452", "#9a9a9a"
plt.rcParams.update({"font.family": "serif", "font.size": 9, "axes.spines.top": False,
                     "axes.spines.right": False, "figure.dpi": 150, "savefig.bbox": "tight"})
FE = ["stratum", "house_band", "time_fe"]
CONTROLS = ["owner_age", "female", "luluwa", "work_gov", "family_gov", "employed", "walls_good",
            "coethnic_chief", "log_pred_value", "dist_city_center"]
LABEL = {"local": "Local", "owner_age": "Owner age", "female": "Owner female", "luluwa": "Owner Luluwa",
         "work_gov": "Owner works for state", "family_gov": "Relative works for state",
         "employed": "Owner employed", "walls_good": "Good walls", "coethnic_chief": "Co-ethnic with chief",
         "log_pred_value": "Log predicted value", "dist_city_center": "Distance to centre (km)",
         "chief_luluwa": "Chief Luluwa", "chief_age": "Chief age", "years_avenue": "Years on avenue",
         "log_transport_cost": "Log transport cost", "assigned_rate": "Assigned tax rate",
         "elig_age55": "Owner 55+", "tmt_2016": "2016 campaign arm"}

ONLY = [a for a in sys.argv[1:] if a.startswith("S")]


def run(sec: str) -> bool:
    return not ONLY or sec in ONLY


# ---------------------------------------------------------------- data
F = pd.read_csv(INTER / "final_property.csv.gz", low_memory=False)
NB = pd.read_csv(INTER / "final_neighbourhood.csv")
REG = F[F.s_registered == 1].copy()          # 14,381 registered properties, 221 neighbourhoods
OWN = F[F.s_owner == 1].copy()               # owner-linked sample (age and sex observed)


# ---------------------------------------------------------------- helpers
def add_missing_dummies(df: pd.DataFrame, cols: list[str]) -> tuple[pd.DataFrame, list[str]]:
    """Fill missing controls with the sample mean and add a missing indicator (as in the paper)."""
    df = df.copy()
    out = []
    for c in cols:
        if df[c].isna().any():
            df[f"m_{c}"] = df[c].isna().astype(float)
            df[c] = df[c].fillna(df[c].mean())
            out.append(f"m_{c}")
    return df, cols + out


def ols(df: pd.DataFrame, y: str, rhs: list[str], fe=FE, cluster="a7", keep=("local",)):
    """OLS with fixed effects as dummies and SEs clustered by neighbourhood."""
    use = df.dropna(subset=[y] + [c for c in rhs if c in df] + list(fe)).copy()
    f = f"{y} ~ " + " + ".join(rhs + [f"C({c})" for c in fe]) if (rhs or fe) else f"{y} ~ 1"
    m = smf.ols(f, use).fit(cov_type="cluster", cov_kwds={"groups": use[cluster]})
    cmean = use.loc[use.local == 0, y].mean() if "local" in use else np.nan
    return {"m": m, "b": m.params, "se": m.bse, "p": m.pvalues, "N": int(m.nobs),
            "J": use[cluster].nunique(), "r2": m.rsquared, "cmean": cmean, "data": use}


def stars(p: float) -> str:
    return "^{***}" if p < 0.01 else "^{**}" if p < 0.05 else "^{*}" if p < 0.1 else ""


def fmt_b(b, p, d=3):
    return f"${b:.{d}f}{stars(p)}$"


def fmt_se(se, d=3):
    return f"$({se:.{d}f})$"


def write_table(name: str, header: list[str], rows: list[list[str]], caption: str, label: str,
                notes: str, colspec: str | None = None, groups: list[tuple[str, int]] | None = None,
                size: str = "\\footnotesize", csv_rows: list[list] | None = None, landscape=False):
    """Journal-style booktabs table -> .tex (full table environment), .csv and .xlsx."""
    ncol = len(header)
    colspec = colspec or ("l" + "c" * (ncol - 1))
    lines = [f"\\begin{{table}}[!htbp]\\centering{size}", f"\\caption{{{caption}}}\\label{{{label}}}",
             "\\begin{threeparttable}", f"\\begin{{tabular}}{{{colspec}}}", "\\toprule"]
    if groups:
        g, cm, start = [], [], 1
        for txt, span in groups:
            g.append(f"\\multicolumn{{{span}}}{{c}}{{{txt}}}" if txt else " & " * (span - 1))
            if txt:
                cm.append(f"\\cmidrule(lr){{{start}-{start + span - 1}}}")
            start += span
        lines.append(" & ".join(g) + " \\\\")
        lines.append(" ".join(cm))
    lines.append(" & ".join(header) + " \\\\")
    lines.append("\\midrule")
    for r in rows:
        if r == ["\\midrule"]:
            lines.append("\\midrule")
        elif len(r) == 1:
            lines.append(f"\\multicolumn{{{ncol}}}{{l}}{{{r[0]}}} \\\\")
        else:
            lines.append(" & ".join(r) + " \\\\")
    lines += ["\\bottomrule", "\\end{tabular}", "\\begin{tablenotes}[flushleft]\\scriptsize",
              f"\\item \\textit{{Notes:}} {notes}", "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}"]
    (TAB / f"{name}.tex").write_text("\n".join(lines))

    def clean(x):
        return (str(x).replace("$", "").replace("^{***}", "***").replace("^{**}", "**").replace("^{*}", "*")
                .replace("\\textit{", "").replace("\\textbf{", "").replace("}", "").replace("\\hspace{1em}", "  ")
                .replace("\\,", "").replace("\\times", "x").replace("\\geq", ">=").replace("\\%", "%"))
    body = csv_rows if csv_rows is not None else [[clean(c) for c in r] for r in rows if r != ["\\midrule"]]
    width = max(len(r) for r in body + [header])
    body = [r + [""] * (width - len(r)) for r in body]
    df = pd.DataFrame(body, columns=[clean(h) for h in header] + [""] * (width - ncol))
    df.to_csv(TAB / f"{name}.csv", index=False)
    df.to_excel(TAB / f"{name}.xlsx", index=False)


def savefig(fig, name: str):
    fig.savefig(FIG / f"{name}.pdf")
    fig.savefig(FIG / f"{name}.png", dpi=200)
    plt.close(fig)


def nfmt(x):
    return f"{int(x):,}"


RESULTS: dict = {}   # numbers quoted in the text, saved to 03_output/tables/key_numbers.csv


# =============================================================================
# S1. Table 1 - Summary statistics
# =============================================================================
if run("S1"):
    def srow(df, v, lab, pct=False):
        x = df[v].dropna()
        c = df.loc[df.local == 0, v].dropna().mean()
        l = df.loc[df.local == 1, v].dropna().mean()
        f = (lambda z: f"{z:.3f}") if not pct else (lambda z: f"{z:.1f}")
        return [lab, nfmt(len(x)), f(x.mean()), f(x.std()), f(c), f(l)]

    rows = [["\\textit{Panel A. Registered properties (collector records)}"]]
    for v, lab in [("local", "Local (chief collects)"), ("exempt", "Exempted by collector"),
                   ("exempt_age", "\\hspace{1em}Reason: old age"), ("exempt_widow", "\\hspace{1em}Reason: widow"),
                   ("exempt_other_all", "\\hspace{1em}Reason: other"), ("enum_disagrees", "Enumerator disagrees with collector")]:
        rows.append(srow(REG, v, lab))
    rows.append(srow(F[F.s_midline == 1], "bribe_midline", "Paid a bribe (midline)"))
    rows += [["\\midrule"], ["\\textit{Panel B. Owner-linked sample (owner age and sex observed)}"]]
    for v, lab in [("exempt", "Exempted by collector"), ("exempt_age", "\\hspace{1em}Reason: old age"),
                   ("just_age", "\\hspace{2em}owner 55 or older"), ("disc_age", "\\hspace{2em}owner under 55 (discretionary)"),
                   ("exempt_widow", "\\hspace{1em}Reason: widow"), ("disc_widow", "\\hspace{2em}owner male (discretionary)"),
                   ("exempt_no_basis", "Exempt, man under 55, no pension/disability"),
                   ("owner_age", "Owner age (years)"), ("elig_age55", "Owner 55 or older"),
                   ("age_guessed", "Age reported as a band"), ("female", "Owner female"), ("luluwa", "Owner Luluwa"),
                   ("coethnic_chief", "Co-ethnic with neighbourhood chief"), ("work_gov", "Owner works for the state"),
                   ("family_gov", "Relative works for the state"), ("employed", "Owner employed"),
                   ("walls_good", "Good walls (brick/cement/good mud brick)"), ("log_pred_value", "Log predicted property value"),
                   ("dist_city_center", "Distance to city centre (km)")]:
        rows.append(srow(OWN, v, lab))
    write_table("table1_sumstats", ["Variable", "N", "Mean", "SD", "Central", "Local"], rows,
                "Summary statistics, Central and Local neighbourhoods", "tab:sumstats",
                f"Panel A uses the {nfmt(len(REG))} properties in the {REG.a7.nunique()} Central and Local "
                f"neighbourhoods for which the collector recorded an exemption decision; the bribe row uses properties "
                f"matched to the midline survey. Panel B uses the {nfmt(len(OWN))} registered properties whose owner's "
                f"age and sex are reported in the midline survey ({OWN.a7.nunique()} neighbourhoods). Discretionary "
                f"exemptions are those whose stated reason contradicts the owner's recorded traits. Central and Local "
                f"columns report raw means by arm.", colspec="lrrrrr")
    RESULTS.update({"N_reg": len(REG), "J_reg": REG.a7.nunique(), "N_own": len(OWN), "J_own": OWN.a7.nunique(),
                    "N_all": len(F), "exempt_mean": REG.exempt.mean(), "age_share_exempt": REG.exempt_age.mean(),
                    "widow_share": REG.exempt_widow.mean(), "guess_share": OWN.age_guessed.mean()})
    print("S1 done")

# =============================================================================
# S2. Figure 1 - Exemption by owner age and arm
# =============================================================================
if run("S2"):
    df = OWN.copy()
    bins = [18, 30, 40, 45, 50, 55, 60, 65, 70, 80, 106]
    df["age_bin"] = pd.cut(df.owner_age, bins, right=False)
    mids = [(b0 + b1) / 2 for b0, b1 in zip(bins[:-1], [80, 30, 40, 45, 50, 55, 60, 65, 70, 80, 90][1:])]
    mids = [24, 35, 42.5, 47.5, 52.5, 57.5, 62.5, 67.5, 75, 85]
    fig, axes = plt.subplots(1, 3, figsize=(9.2, 2.9), sharex=True)
    for ax, (y, t) in zip(axes, [("exempt", "(a) Any exemption"), ("exempt_age", "(b) Exempt for old age"),
                                 ("exempt_widow", "(c) Exempt as widow")]):
        for arm, col, lab, off in [(0, C_CEN, "Central", -0.6), (1, C_LOC, "Local", 0.6)]:
            g = df[df.local == arm].groupby("age_bin", observed=False)[y]
            m, s, n = g.mean(), g.std(), g.size()
            ci = 1.96 * s / np.sqrt(n)
            ax.errorbar(np.array(mids) + off, m.values, yerr=ci.values, fmt="o-", ms=3, lw=1.2, capsize=2,
                        color=col, label=lab)
        ax.axvline(55, ls="--", color="k", lw=0.8)
        ax.set_title(t, fontsize=9)
        ax.set_xlabel("Owner age (years)")
        ax.set_ylim(0, None)
    axes[0].set_ylabel("Share of properties")
    axes[0].legend(frameon=False, loc="upper left")
    axes[1].text(55.8, axes[1].get_ylim()[1] * 0.92, "legal age 55", fontsize=7)
    fig.tight_layout()
    savefig(fig, "fig1_exempt_by_age")
    # numbers for the text
    young = df[df.owner_age < 55]
    RESULTS.update({"oldage_u55_C": young.loc[young.local == 0, "exempt_age"].mean(),
                    "oldage_u55_L": young.loc[young.local == 1, "exempt_age"].mean(),
                    "widow_u55_C": young.loc[young.local == 0, "exempt_widow"].mean(),
                    "widow_u55_L": young.loc[young.local == 1, "exempt_widow"].mean(),
                    "any_u55_C": young.loc[young.local == 0, "exempt"].mean(),
                    "any_u55_L": young.loc[young.local == 1, "exempt"].mean()})
    print("S2 done")

# =============================================================================
# S3. Table 2 / Figure 2 - Balance and attrition
# =============================================================================
if run("S3"):
    rows, plot = [], []
    MID = F[(F.s_midline == 1)].copy()          # every property matched to the midline survey
    owner_vars = [("owner_age", "Owner age"), ("elig_age55", "Owner 55 or older"), ("female", "Owner female"),
                  ("luluwa", "Owner Luluwa"), ("coethnic_chief", "Co-ethnic with chief"),
                  ("work_gov", "Owner works for the state"), ("family_gov", "Relative works for the state"),
                  ("employed", "Owner employed"), ("years_avenue", "Years on the avenue"), ("walls_good", "Good walls"),
                  ("log_pred_value", "Log predicted property value"), ("dist_city_center", "Distance to city centre")]

    def bal_cells(df, v, fe=("stratum",), cluster="a7"):
        r = ols(df, v, ["local"], fe=list(fe), cluster=cluster)
        return r, [f"{r['cmean']:.3f}", fmt_b(r["b"]["local"], r["p"]["local"]) + " " + fmt_se(r["se"]["local"])]

    rows.append(["\\textit{Panel A. Owner traits (midline survey)}"])
    for v, lab in owner_vars:
        r1, c1 = bal_cells(MID, v)
        r2, c2 = bal_cells(OWN, v)
        sd = r1["data"][v].std()
        plot.append((lab, r1["b"]["local"] / sd, r1["se"]["local"] / sd, r2["b"]["local"] / sd, r2["se"]["local"] / sd))
        rows.append([lab] + c1 + [f"{r1['p']['local']:.2f}"] + c2 + [f"{r2['p']['local']:.2f}"])
        RESULTS[f"bal_mid_{v}_p"], RESULTS[f"bal_own_{v}_b"], RESULTS[f"bal_own_{v}_p"] = r1["p"]["local"], r2["b"]["local"], r2["p"]["local"]
    names = [v for v, _ in owner_vars if v != "elig_age55"]
    jt_cells = []
    for df in (MID, OWN):
        jt, jx = add_missing_dummies(df, names)
        r = ols(jt, "local", jx, fe=["stratum"])
        w = r["m"].wald_test(" , ".join(f"{n} = 0" for n in names), use_f=True, scalar=True)
        jt_cells.append((float(w.statistic), float(w.pvalue), r["N"]))
    rows.append([f"Joint $F$-test ($p$-value)", "", f"{jt_cells[0][0]:.2f}", f"{jt_cells[0][1]:.2f}", "",
                 f"{jt_cells[1][0]:.2f}", f"{jt_cells[1][1]:.2f}"])
    rows.append(["Properties", "", nfmt(jt_cells[0][2]), "", "", nfmt(jt_cells[1][2]), ""])
    RESULTS.update({"joint_F_mid": jt_cells[0][0], "joint_p_mid": jt_cells[0][1],
                    "joint_F_own": jt_cells[1][0], "joint_p_own": jt_cells[1][1]})
    rows += [["\\midrule"], ["\\textit{Panel B. Neighbourhood chief (pre-randomization chief survey), one row per neighbourhood}"]]
    NBc = NB.copy()
    NBc["a7c"] = NBc.a7
    for v, lab in [("chief_age", "Chief age"), ("chief_female", "Chief female"), ("chief_luluwa", "Chief Luluwa"),
                   ("chief_edu", "Chief education (0--4)"), ("appoint_yr", "Year chief appointed"),
                   ("salongo_freq", "Salongo frequency"), ("dist_city_center", "Distance to city centre")]:
        r, c = bal_cells(NBc, v, cluster="a7c")
        sd = r["data"][v].std()
        plot.append((lab.replace("--", "-") + (" (nbhd)" if v == "dist_city_center" else ""),
                     r["b"]["local"] / sd, r["se"]["local"] / sd, np.nan, np.nan))
        rows.append([lab] + c + [f"{r['p']['local']:.2f}", "", "", ""])
    rows += [["\\midrule"], ["\\textit{Panel C. Sample selection (attrition)}"]]
    attr = [(F, "s_registered", "Exemption decision recorded (all properties)"),
            (F, "s_midline", "Matched to midline survey (all properties)"),
            (REG, "s_owner", "In owner-linked sample (registered)"),
            (OWN, "age_guessed", "Owner age reported as a band")]
    for df, v, lab in attr:
        r, c = bal_cells(df, v)
        rows.append([lab] + c + [f"{r['p']['local']:.2f}", "", "", ""])
        RESULTS[f"attr_{v}_b"], RESULTS[f"attr_{v}_p"] = r["b"]["local"], r["p"]["local"]
    write_table("table2_balance", ["", "Central", "Local $-$ Central", "$p$", "Central", "Local $-$ Central", "$p$"],
                rows, "Balance of pre-determined traits and attrition", "tab:balance",
                "Each cell regresses the variable on the Local indicator with stratum fixed effects; standard errors "
                "clustered by neighbourhood in parentheses (robust in Panel B, one observation per neighbourhood). "
                f"The left block uses all {nfmt(len(MID))} properties matched to the midline survey; the right block "
                "uses the owner-linked analysis sample (exemption decision recorded, owner age and sex observed). "
                "Chief traits come from the chief survey used for randomization (December 2017--May 2018). The joint "
                "test regresses Local on all Panel A traits except the 55+ indicator, with missing-value indicators. "
                "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
                colspec="lcccccc", groups=[("", 1), ("All midline properties", 3), ("Owner-linked sample", 3)],
                size="\\scriptsize")
    # Figure 2: standardized differences, two samples
    pl = pd.DataFrame(plot, columns=["var", "d1", "s1", "d2", "s2"]).iloc[::-1].reset_index(drop=True)
    fig, ax = plt.subplots(figsize=(5.6, 4.6))
    y = np.arange(len(pl))
    ax.errorbar(pl.d1, y + 0.15, xerr=1.96 * pl.s1, fmt="o", color=C_CEN, ecolor=C_CEN, ms=4, capsize=2, lw=0.8,
                label="All midline properties / neighbourhoods")
    ax.errorbar(pl.d2, y - 0.15, xerr=1.96 * pl.s2, fmt="s", color=C_LOC, ecolor=C_LOC, ms=4, capsize=2, lw=0.8,
                label="Owner-linked analysis sample")
    ax.axvline(0, color="k", lw=0.8)
    for x in (-0.1, 0.1):
        ax.axvline(x, color=C_GREY, ls=":", lw=0.8)
    ax.set_yticks(y)
    ax.set_yticklabels(pl["var"])
    ax.set_xlabel("Local $-$ Central, in SD of the variable (95% CI)")
    ax.legend(frameon=False, fontsize=7, loc="lower center", bbox_to_anchor=(0.4, 1.0), ncol=2)
    fig.tight_layout()
    savefig(fig, "fig3_balance")
    print("S3 done")

# =============================================================================
# S4. SUTVA - neighbourhood adjacency network and spillover test
# =============================================================================
if run("S4"):
    adj = pd.read_csv(ROOT / "0_RawData/0.8geography/adjacent_neighborhoods.csv", thousands=",")
    asg = pd.read_csv(ROOT / "0_RawData/0.7randomization/randomization_assignment.csv", encoding="utf-8-sig")
    arm = dict(zip(asg.a7.astype(int), asg.treatment.astype(int)))
    G = nx.Graph()
    G.add_nodes_from([a for a, t in arm.items() if t > 0])
    for s_, n_ in zip(adj.src_poly_nm.astype(int), adj.nbr_poly_nm.astype(int)):
        if s_ in G and n_ in G:
            G.add_edge(s_, n_)
    pos = nx.kamada_kawai_layout(G)
    fig, ax = plt.subplots(figsize=(6.2, 5.0))
    nx.draw_networkx_edges(G, pos, ax=ax, edge_color="#cccccc", width=0.5)
    for t, col, lab, sz in [(3, C_GREY, "Other arms (CLI, CXL)", 10), (4, C_GREY, None, 10),
                            (1, C_CEN, "Central", 22), (2, C_LOC, "Local", 22)]:
        nodes = [n for n in G if arm[n] == t]
        nx.draw_networkx_nodes(G, pos, nodelist=nodes, node_color=col, node_size=sz, ax=ax, label=lab,
                               edgecolors="white", linewidths=0.3)
    ax.legend(frameon=False, loc="upper left", fontsize=8)
    ax.axis("off")
    savefig(fig, "fig4_network")
    # mixing: share of Central-Local edges vs expected under random labels
    cl = [(u, v) for u, v in G.edges if {arm[u], arm[v]} == {1, 2}]
    RESULTS.update({"n_edges": G.number_of_edges(), "n_cl_edges": len(cl),
                    "mean_adj_local_C": NB.loc[NB.local == 0, "share_adj_local"].mean(),
                    "mean_adj_local_L": NB.loc[NB.local == 1, "share_adj_local"].mean()})
    # spillover regressions
    rows, cols = [], []
    specs = [("exempt", REG), ("exempt_age", REG), ("exempt", OWN), ("exempt_age", OWN), ("disc_age", OWN)]
    res = [ols(df, y, ["local", "share_adj_local"]) for y, df in specs]
    res_c = [ols(df[df.local == 0], y, ["share_adj_local"]) for y, df in specs]
    rows.append(["Local"] + [fmt_b(r["b"]["local"], r["p"]["local"]) for r in res])
    rows.append([""] + [fmt_se(r["se"]["local"]) for r in res])
    rows.append(["Share of adjacent neighbourhoods Local"] + [fmt_b(r["b"]["share_adj_local"], r["p"]["share_adj_local"]) for r in res])
    rows.append([""] + [fmt_se(r["se"]["share_adj_local"]) for r in res])
    rows.append(["\\midrule"])
    rows.append(["Same, Central properties only"] + [fmt_b(r["b"]["share_adj_local"], r["p"]["share_adj_local"]) for r in res_c])
    rows.append([""] + [fmt_se(r["se"]["share_adj_local"]) for r in res_c])
    rows.append(["\\midrule"])
    rows.append(["Sample"] + ["Registered", "Registered", "Owner", "Owner", "Owner"])
    rows.append(["Observations"] + [nfmt(r["N"]) for r in res])
    rows.append(["Clusters"] + [str(r["J"]) for r in res])
    write_table("table3_spillover", ["", "Exempt", "Old age", "Exempt", "Old age", "Old age, $<55$"], rows,
                "SUTVA check: do neighbouring Local arms change exemptions?", "tab:spill",
                "OLS with stratum, house-type and two-month time fixed effects; standard errors clustered by "
                "neighbourhood. The share of adjacent neighbourhoods assigned to Local is computed from the city's "
                "polygon adjacency file over all adjacent experimental neighbourhoods. Because assignment of the "
                "neighbours is also random, its coefficient tests for spillovers. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.")
    RESULTS.update({"spill_exempt_b": res[0]["b"]["share_adj_local"], "spill_exempt_p": res[0]["p"]["share_adj_local"],
                    "spill_age_p": res[1]["p"]["share_adj_local"], "spill_disc_p": res[4]["p"]["share_adj_local"]})
    print("S4 done")

# =============================================================================
# S5. DAGs (graphviz 'dot' must be installed; see README)
# =============================================================================
if run("S5"):
    common = 'graph [rankdir=LR, fontname="Times", nodesep=0.35, ranksep=0.55, splines=true, bgcolor="white"];\n' \
             'node [shape=box, style="rounded", fontname="Times", fontsize=12, penwidth=1.0];\n' \
             'edge [color="#555555", arrowsize=0.7];\n'
    dags = {
        "fig2a_dag1": f"""digraph G {{ {common}
          coin [label="Coin flip\\n(best of 100 draws)"]; strat [label="Stratum\\n(location, 2016 arm,\\nchief experience)"];
          D [label="Local (D)", penwidth=2]; Y [label="Exempt (Y)", penwidth=2];
          X [label="Owner traits X\\nage, sex, tribe, job, wealth"]; W [label="Widowed\\n(unobserved)", style="rounded,dashed"];
          C [label="Co-ethnic\\nwith chief"]; H [label="House band\\n(FE)"];
          coin -> D; strat -> D; strat -> Y; strat -> C; X -> Y; X -> W; W -> Y; X -> C; C -> Y; H -> Y; X -> H;
          D -> Y [color="black", penwidth=2]; }}""",
        "fig2b_dag2": f"""digraph G {{ {common}
          S [label="Owner age (S)", color="#C0392B", fontcolor="#C0392B"]; D [label="Local (D)", penwidth=2];
          Y [label="Exempt (Y)", penwidth=2]; W [label="Widowed\\n(unobserved)", style="rounded,dashed"];
          E [label="Employment"]; X [label="Sex, tribe"];
          S -> D [color="#C0392B", penwidth=1.6]; S -> Y [color="#C0392B", penwidth=1.6];
          S -> W [color="#C0392B"]; W -> Y [color="#C0392B"]; S -> E [color="#C0392B"]; E -> Y [color="#C0392B"];
          X -> Y; X -> W; D -> Y [color="black", penwidth=2]; }}""",
        "fig2c_dag3": f"""digraph G {{ {common}
          D [label="Local (D)", penwidth=2]; Y [label="Exempt for old age (Y)", penwidth=2];
          M [label="Chief knowledge\\nand discretion (M)", style="rounded,dashed", color="#B9770E"];
          L [label="Stated reason\\n(collector's label)", color="#B9770E"];
          U [label="Personal tie\\nto chief (U)", style="rounded,dashed"]; B [label="Endline\\nco-ethnic bias (C)"];
          A [label="Owner age"];
          D -> M; M -> Y; M -> L; D -> L; L -> Y; U -> Y; D -> B; U -> B; A -> Y; A -> L;
          D -> Y [color="black", penwidth=2]; }}""",
    }
    for name, src in dags.items():
        for ext in ("pdf", "png"):
            subprocess.run(["dot", f"-T{ext}", "-Gdpi=220", "-o", str(FIG / f"{name}.{ext}")],
                           input=src.encode(), check=True)
    print("S5 done")

# =============================================================================
# S6. Table 4 - Replication of the paper (Table 4 col. 1 and Table A9)
# =============================================================================
if run("S6"):
    CL = F.copy()
    res = [ols(CL, "taxes_paid", ["local"], fe=["stratum"])]
    for y in ["exempt", "exempt_age", "exempt_widow", "exempt_pension", "exempt_handicap", "enum_disagrees"]:
        res.append(ols(REG, y, ["local"]))
    hdr = ["", "Paid tax", "Exempt", "Senior", "Widow", "Pension", "Disability", "Enum.\\ disagrees"]
    rows = [["Local"] + [fmt_b(r["b"]["local"], r["p"]["local"]) for r in res],
            [""] + [fmt_se(r["se"]["local"]) for r in res], ["\\midrule"],
            ["Stratum FE"] + ["Yes"] * 7, ["House and time FE"] + ["No"] + ["Yes"] * 6,
            ["Central mean"] + [f"{r['cmean']:.3f}" for r in res],
            ["Observations"] + [nfmt(r["N"]) for r in res], ["Clusters"] + [str(r["J"]) for r in res],
            ["$R^2$"] + [f"{r['r2']:.3f}" for r in res],
            ["Paper"] + ["Tab.\\ 4(1)"] + ["Tab.\\ A9"] * 5 + ["Tab.\\ 5(2)"]]
    write_table("table4_replication", hdr, rows, "Replication of the original estimates", "tab:replication",
                "Column 1 reproduces Table 4, column 1 of Bal\\'an et al.\\ (2022) on all properties in Central and "
                "Local neighbourhoods. Columns 2--7 use registered properties with a recorded exemption decision and "
                "follow the specification of their Table A9 (stratum, house-type and two-month time fixed effects). "
                "Standard errors clustered by neighbourhood. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.")
    RESULTS.update({"rep_tax_b": res[0]["b"]["local"], "rep_tax_se": res[0]["se"]["local"], "rep_tax_N": res[0]["N"],
                    "rep_ex_b": res[1]["b"]["local"], "rep_ex_se": res[1]["se"]["local"], "rep_ex_cm": res[1]["cmean"],
                    "rep_age_b": res[2]["b"]["local"], "rep_age_se": res[2]["se"]["local"], "rep_age_cm": res[2]["cmean"],
                    "rep_wid_b": res[3]["b"]["local"], "rep_wid_se": res[3]["se"]["local"],
                    "rep_enum_b": res[6]["b"]["local"], "rep_enum_p": res[6]["p"]["local"]})
    print("S6 done")

# =============================================================================
# S7. Table 5 - Main ATE on exemptions by reason and discretionary exemptions (owner sample)
# =============================================================================
OUTCOMES = [("exempt", "Any"), ("exempt_age", "Old age"), ("exempt_widow", "Widow"), ("exempt_other_all", "Other"),
            ("just_age", "Old age, 55+"), ("disc_age", "Old age, $<$55"), ("disc_widow", "Widow, male"),
            ("disc_any", "Any discr."), ("exempt_no_basis", "No basis")]
if run("S7"):
    own_c, xc = add_missing_dummies(OWN, CONTROLS)
    rA = [ols(OWN, y, ["local"]) for y, _ in OUTCOMES]
    rB = [ols(own_c, y, ["local"] + xc) for y, _ in OUTCOMES]
    hdr = [""] + [f"({i + 1})" for i in range(len(OUTCOMES))]
    sub = [""] + [l for _, l in OUTCOMES]
    rows = [sub, ["\\midrule"], ["\\textit{Panel A. Fixed effects only}"],
            ["Local"] + [fmt_b(r["b"]["local"], r["p"]["local"]) for r in rA],
            [""] + [fmt_se(r["se"]["local"]) for r in rA],
            ["$R^2$"] + [f"{r['r2']:.3f}" for r in rA], ["\\midrule"],
            ["\\textit{Panel B. Adding owner covariates}"],
            ["Local"] + [fmt_b(r["b"]["local"], r["p"]["local"]) for r in rB],
            [""] + [fmt_se(r["se"]["local"]) for r in rB],
            ["$R^2$"] + [f"{r['r2']:.3f}" for r in rB], ["\\midrule"],
            ["Central mean"] + [f"{r['cmean']:.3f}" for r in rA],
            ["Effect / Central mean"] + [f"{r['b']['local'] / r['cmean']:.2f}" for r in rA],
            ["Observations"] + [nfmt(r["N"]) for r in rA], ["Clusters"] + [str(r["J"]) for r in rA]]
    write_table("table5_ate", hdr, rows, "Effect of chief collection on exemptions, by stated reason and legal basis",
                "tab:ate",
                "Owner-linked sample. Each column is a 0/1 outcome: (1) any exemption; (2)--(4) exemption by the reason "
                "the collector recorded; (5) old-age exemption of an owner aged 55 or older (legal); (6) old-age "
                "exemption of an owner under 55; (7) widow exemption of a male owner; (8) column 6 or 7; (9) exemption "
                "of a man under 55 who is not exempted as a pensioner or disabled, whatever the stated reason. "
                "All regressions include stratum, house-type and two-month time fixed effects; Panel B adds owner age, "
                "sex, Luluwa, own and relative state job, employment, wall quality, co-ethnicity with the chief, log "
                "predicted value and distance to the centre (missing values set to the mean with indicators). Standard "
                "errors clustered by neighbourhood. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
                size="\\scriptsize")
    for (y, _), r, rb in zip(OUTCOMES, rA, rB):
        RESULTS.update({f"ate_{y}_b": r["b"]["local"], f"ate_{y}_se": r["se"]["local"], f"ate_{y}_p": r["p"]["local"],
                        f"ate_{y}_cm": r["cmean"], f"ateX_{y}_b": rb["b"]["local"], f"ateX_{y}_p": rb["p"]["local"],
                        f"ate_{y}_N": r["N"]})
    RESULTS["own_reg_N"], RESULTS["own_reg_J"] = rA[0]["N"], rA[0]["J"]
    print("S7 done")

# =============================================================================
# S8. Figure 7 - Local effect by owner age band
# =============================================================================
if run("S8"):
    df = OWN.copy()
    edges = [18, 40, 50, 55, 60, 70, 106]
    labs = ["<40", "40-49", "50-54", "55-59", "60-69", "70+"]
    df["ab"] = pd.cut(df.owner_age, edges, right=False, labels=range(len(labs))).astype(int)
    for k in range(len(labs)):
        df[f"L_{k}"] = df.local * (df.ab == k)
    fig, axes = plt.subplots(1, 3, figsize=(9.2, 2.7), sharey=True)
    for ax, (y, t) in zip(axes, [("exempt", "(a) Any exemption"), ("exempt_age", "(b) Old-age exemption"),
                                 ("exempt_widow", "(c) Widow exemption")]):
        r = ols(df, y, [f"L_{k}" for k in range(len(labs))], fe=FE + ["ab"])
        b = np.array([r["b"][f"L_{k}"] for k in range(len(labs))])
        se = np.array([r["se"][f"L_{k}"] for k in range(len(labs))])
        x = np.arange(len(labs))
        cols = [C_GREY if k < 3 else C_LOC for k in x]
        ax.bar(x, b, color=cols, alpha=0.85, width=0.6)
        ax.errorbar(x, b, yerr=1.96 * se, fmt="none", ecolor="k", capsize=2, lw=0.8)
        ax.axhline(0, color="k", lw=0.7)
        ax.axvline(2.5, color="k", ls="--", lw=0.8)
        ax.set_xticks(x)
        ax.set_xticklabels(labs)
        ax.set_title(t, fontsize=9)
        ax.set_xlabel("Owner age")
        if y == "exempt_age":
            RESULTS.update({f"byage_age_{k}": b[k] for k in range(len(labs))})
            RESULTS.update({f"byage_age_se_{k}": se[k] for k in range(len(labs))})
        if y == "exempt_widow":
            RESULTS.update({f"byage_wid_{k}": b[k] for k in range(len(labs))})
        if y == "exempt":
            RESULTS.update({f"byage_any_{k}": b[k] for k in range(len(labs))})
    axes[0].set_ylabel("Local $-$ Central (share)")
    fig.tight_layout()
    savefig(fig, "fig5_effect_by_age")
    print("S8 done")

# =============================================================================
# S9. Table 6 - Heterogeneity with OLS interactions
# =============================================================================
if run("S9"):
    mods = [("elig_age55", "Owner 55+"), ("female", "Owner female"), ("coethnic_chief", "Co-ethnic with chief"),
            ("family_gov", "Relative works for state")]
    rows = []
    for y, ttl in [("exempt", "Any exemption"), ("exempt_age", "Old-age exemption"), ("exempt_widow", "Widow exemption")]:
        res = []
        for m_, _ in mods:
            df = OWN.dropna(subset=[m_]).copy()
            df["LxM"] = df.local * df[m_]
            res.append(ols(df, y, ["local", m_, "LxM"]))
        rows.append([f"\\textit{{Outcome: {ttl}}}"])
        rows.append(["Local"] + [fmt_b(r["b"]["local"], r["p"]["local"]) for r in res])
        rows.append([""] + [fmt_se(r["se"]["local"]) for r in res])
        rows.append(["Moderator $M$"] + [fmt_b(r["b"][m_], r["p"][m_]) for r, (m_, _) in zip(res, mods)])
        rows.append([""] + [fmt_se(r["se"][m_]) for r, (m_, _) in zip(res, mods)])
        rows.append(["Local $\\times M$"] + [fmt_b(r["b"]["LxM"], r["p"]["LxM"]) for r in res])
        rows.append([""] + [fmt_se(r["se"]["LxM"]) for r in res])
        rows.append(["Observations"] + [nfmt(r["N"]) for r in res])
        rows.append(["\\midrule"])
        for r, (m_, _) in zip(res, mods):
            RESULTS[f"het_{y}_{m_}_b"], RESULTS[f"het_{y}_{m_}_p"] = r["b"]["LxM"], r["p"]["LxM"]
            RESULTS[f"het_{y}_{m_}_L"], RESULTS[f"het_{y}_{m_}_Lp"] = r["b"]["local"], r["p"]["local"]
            RESULTS[f"het_{y}_{m_}_M"] = r["b"][m_]
    rows = rows[:-1]
    write_table("table6_heterogeneity", ["Moderator $M$:"] + [l for _, l in mods], rows,
                "Heterogeneous effects: OLS with Local $\\times$ moderator interactions", "tab:het",
                "Owner-linked sample. Each column interacts Local with one pre-determined moderator (not centred, so "
                "Local is the effect when $M=0$). Co-ethnicity compares the owner's tribe with the tribe of the "
                "neighbourhood chief reported in the pre-randomization chief survey, so it is defined in both arms. "
                "Stratum, house-type and two-month time fixed effects; standard errors clustered by neighbourhood. "
                "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", colspec="lcccc")
    print("S9 done")

# =============================================================================
# S10. Ridge and Lasso on exempt_age with Local x covariate interactions
# =============================================================================
if run("S10"):
    XV = ["owner_age", "female", "luluwa", "work_gov", "family_gov", "employed", "walls_good",
          "coethnic_chief", "log_pred_value", "dist_city_center", "years_avenue"]
    df, xall = add_missing_dummies(OWN.dropna(subset=["time_fe"]), XV)
    for v in XV:
        df[f"Lx_{v}"] = df.local * (df[v] - df[v].mean())
    feats = ["local"] + XV + [f"Lx_{v}" for v in XV]
    miss = [c for c in xall if c.startswith("m_")]
    # partial out fixed effects and missing dummies (FWL), then standardize
    Z = pd.get_dummies(df[FE].astype(int).astype(str), drop_first=True).astype(float)
    Z = pd.concat([Z, df[miss]], axis=1)
    Z.insert(0, "const", 1.0)
    Zm = Z.values

    def resid(v):
        beta, *_ = np.linalg.lstsq(Zm, v, rcond=None)
        return v - Zm @ beta
    y = resid(df["exempt_age"].values.astype(float))
    X = np.column_stack([resid(df[c].values.astype(float)) for c in feats])
    X = (X - X.mean(0)) / X.std(0)
    y = y - y.mean()
    groups = df.a7.values
    folds = list(GroupKFold(n_splits=10).split(X, y, groups))
    HL = {"local": ("Local", C_CEN), "owner_age": ("Age", "#E67E22"), "Lx_owner_age": ("Local$\\times$Age", "#C0392B"),
          "Lx_female": ("Local$\\times$Female", "#8E44AD"), "Lx_coethnic_chief": ("Local$\\times$Co-ethnic", "#27AE60")}
    tabrows = {}

    def path_and_cv(kind):
        if kind == "ridge":
            lams = np.logspace(-1, 5, 60)
            mk = lambda l: Ridge(alpha=l)
        else:
            lams = np.logspace(-4.5, -0.8, 60)
            mk = lambda l: Lasso(alpha=l, max_iter=20000)
        coefs = np.array([mk(l).fit(X, y).coef_ for l in lams])
        cv = np.zeros((len(lams), len(folds)))
        for j, (tr, te) in enumerate(folds):
            for i, l in enumerate(lams):
                m = mk(l).fit(X[tr], y[tr])
                cv[i, j] = mean_squared_error(y[te], m.predict(X[te]))
        mse, se = cv.mean(1), cv.std(1) / np.sqrt(len(folds))
        imin = int(np.argmin(mse))
        i1se = int(np.max(np.where(mse <= mse[imin] + se[imin])[0]))
        return lams, coefs, mse, se, imin, i1se

    for kind, fname, title in [("ridge", "fig6a_ridge", "Ridge"), ("lasso", "fig6b_lasso", "Lasso")]:
        lams, coefs, mse, se, imin, i1se = path_and_cv(kind)
        fig, (a1, a2) = plt.subplots(1, 2, figsize=(9.2, 3.0))
        for j, c in enumerate(feats):
            if c in HL:
                continue
            a1.plot(np.log10(lams), coefs[:, j], color="#cfcfcf", lw=0.8)
        for j, c in enumerate(feats):
            if c in HL:
                a1.plot(np.log10(lams), coefs[:, j], color=HL[c][1], lw=1.6, label=HL[c][0])
        for a in (a1, a2):
            a.axvline(np.log10(lams[imin]), ls="--", color="k", lw=0.7)
            a.axvline(np.log10(lams[i1se]), ls=":", color="k", lw=0.9)
        a1.set_xlabel("$\\log_{10}(\\lambda)$")
        a1.set_ylabel("Standardized coefficient")
        a1.set_title(f"{title} coefficient path (grey = other features)", fontsize=9)
        a1.legend(frameon=False, fontsize=7)
        a2.errorbar(np.log10(lams), mse * 1e3, yerr=se * 1e3, fmt="o", ms=2.5, color="#C0392B", ecolor="#999999",
                    capsize=1.5, lw=0.6)
        a2.set_xlabel("$\\log_{10}(\\lambda)$")
        a2.set_ylabel("10-fold CV MSE ($\\times 10^3$)")
        a2.set_title(f"{title} CV, folds grouped by neighbourhood", fontsize=9)
        fig.tight_layout()
        savefig(fig, fname)
        tabrows[kind] = {"min": dict(zip(feats, coefs[imin])), "1se": dict(zip(feats, coefs[i1se])),
                         "lmin": lams[imin], "l1se": lams[i1se], "nz_min": int((np.abs(coefs[imin]) > 1e-10).sum()),
                         "nz_1se": int((np.abs(coefs[i1se]) > 1e-10).sum()), "mse_min": mse[imin], "mse_1se": mse[i1se]}
    # OLS on the same standardized design for comparison
    olsc = dict(zip(feats, LinearRegression().fit(X, y).coef_))
    show = ["local", "owner_age", "female", "coethnic_chief", "Lx_owner_age", "Lx_female", "Lx_coethnic_chief",
            "Lx_family_gov", "Lx_luluwa"]
    lab = {"local": "Local", "owner_age": "Age", "female": "Female", "coethnic_chief": "Co-ethnic with chief",
           "Lx_owner_age": "Local $\\times$ Age", "Lx_female": "Local $\\times$ Female",
           "Lx_coethnic_chief": "Local $\\times$ Co-ethnic", "Lx_family_gov": "Local $\\times$ Relative in state job",
           "Lx_luluwa": "Local $\\times$ Luluwa"}

    def f4(v):
        return "0" if abs(v) < 1e-10 else f"{v:.4f}"
    rows = [[lab[c], f4(olsc[c]), f4(tabrows["ridge"]["min"][c]), f4(tabrows["ridge"]["1se"][c]),
             f4(tabrows["lasso"]["min"][c]), f4(tabrows["lasso"]["1se"][c])] for c in show]
    rows += [["\\midrule"],
             ["$\\lambda$", "--", f"{tabrows['ridge']['lmin']:.1f}", f"{tabrows['ridge']['l1se']:.1f}",
              f"{tabrows['lasso']['lmin']:.4f}", f"{tabrows['lasso']['l1se']:.4f}"],
             ["Non-zero coefficients (of 23)", "23", str(tabrows["ridge"]["nz_min"]), str(tabrows["ridge"]["nz_1se"]),
              str(tabrows["lasso"]["nz_min"]), str(tabrows["lasso"]["nz_1se"])],
             ["CV MSE ($\\times 10^3$)", "--", f"{tabrows['ridge']['mse_min'] * 1e3:.3f}",
              f"{tabrows['ridge']['mse_1se'] * 1e3:.3f}", f"{tabrows['lasso']['mse_min'] * 1e3:.3f}",
              f"{tabrows['lasso']['mse_1se'] * 1e3:.3f}"]]
    # post-double-selection lasso ATE (Belloni, Chernozhukov and Hansen 2014)
    pds = {}
    base = OWN.dropna(subset=["time_fe"]).copy()
    base, xall2 = add_missing_dummies(base, XV)
    cand = xall2 + [f"sq_{v}" for v in ["owner_age", "log_pred_value", "dist_city_center"]]
    for v in ["owner_age", "log_pred_value", "dist_city_center"]:
        base[f"sq_{v}"] = (base[v] - base[v].mean()) ** 2
    Zc = (base[cand] - base[cand].mean()) / base[cand].std()
    for yv in ["exempt_age", "disc_age", "exempt"]:
        sel = set()
        for target in [yv, "local"]:
            lcv = LassoCV(cv=GroupKFold(10).split(Zc, base[target], base.a7), random_state=SEED,
                          max_iter=20000).fit(Zc, base[target])
            sel |= {c for c, b in zip(cand, lcv.coef_) if abs(b) > 1e-10}
        r = ols(base, yv, ["local"] + sorted(sel))
        pds[yv] = (r["b"]["local"], r["se"]["local"], r["p"]["local"], len(sel))
    rows += [["\\midrule"], ["\\textit{Post-double-selection Lasso ATE of Local}"]]
    for yv, lb in [("exempt", "Any exemption"), ("exempt_age", "Old-age exemption"), ("disc_age", "Old age, owner $<55$")]:
        b, se, p, k = pds[yv]
        rows.append([f"\\hspace{{1em}}{lb}", fmt_b(b, p), fmt_se(se), f"{k} controls selected", "", ""])
        RESULTS.update({f"pds_{yv}_b": b, f"pds_{yv}_se": se, f"pds_{yv}_p": p, f"pds_{yv}_k": k})
    write_table("table7_regularization", ["", "OLS", "Ridge $\\lambda_{min}$", "Ridge $\\lambda_{1se}$",
                                          "Lasso $\\lambda_{min}$", "Lasso $\\lambda_{1se}$"], rows,
                "Ridge and Lasso: does any Local $\\times$ covariate interaction predict old-age exemptions?",
                "tab:reg",
                "Outcome: exempt for old age, owner-linked sample. Features: Local, 11 owner covariates and their 11 "
                "interactions with Local (covariates centred), all standardized after partialling out stratum, "
                "house-type and time fixed effects and missing-value indicators. $\\lambda$ chosen by 10-fold "
                "cross-validation with folds grouped by neighbourhood; $\\lambda_{1se}$ is the largest $\\lambda$ "
                "within one standard error of the minimum. The bottom panel selects controls (covariates, missing "
                "indicators and squares) with a Lasso for the outcome and a Lasso for Local, then runs OLS with the "
                "union and the fixed effects; standard errors clustered by neighbourhood. "
                "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", colspec="lccccc")
    for k_ in ["ridge", "lasso"]:
        for c in show:
            RESULTS[f"{k_}_min_{c}"] = tabrows[k_]["min"][c]
            RESULTS[f"{k_}_1se_{c}"] = tabrows[k_]["1se"][c]
        RESULTS[f"{k_}_nz_min"], RESULTS[f"{k_}_nz_1se"] = tabrows[k_]["nz_min"], tabrows[k_]["nz_1se"]
    RESULTS.update({f"ols_std_{c}": olsc[c] for c in show})
    print("S10 done")

# =============================================================================
# S11. Robustness and randomization inference
# =============================================================================
if run("S11"):
    ys = [("exempt_age", "Old age"), ("disc_age", "Old age, below cut-off"), ("exempt", "Any exemption"),
          ("exempt_no_basis", "No basis")]
    rows = []

    def cell(r):
        return [fmt_b(r["b"]["local"], r["p"]["local"]), fmt_se(r["se"]["local"])]

    def add(label, res, note=""):
        rows.append([label] + [fmt_b(r["b"]["local"], r["p"]["local"]) if r else "--" for r in res])
        rows.append([""] + [fmt_se(r["se"]["local"]) if r else "" for r in res])

    add("(1) Baseline (Table 5, Panel A)", [ols(OWN, y, ["local"]) for y, _ in ys])
    for c in [50, 60, 65]:
        add(f"({[50, 60, 65].index(c) + 2}) Cut-off age {c}", [None, ols(OWN, f"disc_age{c}", ["local"]), None, None])
    exact = OWN[OWN.age_guessed == 0]
    add("(5) Exact ages only (drop age bands)", [ols(exact, y, ["local"]) for y, _ in ys])
    add("(6) Stratum FE only", [ols(OWN, y, ["local"], fe=["stratum"]) for y, _ in ys])
    add("(7) No fixed effects", [ols(OWN, y, ["local"], fe=[]) for y, _ in ys])
    nbm = OWN.groupby("a7").agg({**{y: "mean" for y, _ in ys}, "local": "first", "stratum": "first"}).reset_index()
    nbm["a7c"] = nbm.a7
    add("(8) Neighbourhood means", [ols(nbm, y, ["local"], fe=["stratum"], cluster="a7c") for y, _ in ys])
    # logit average marginal effect
    lg = []
    for y, _ in ys:
        use = OWN.dropna(subset=[y, "time_fe"])
        try:
            m = smf.logit(f"{y} ~ local + C(stratum) + C(house_band) + C(time_fe)", use).fit(
                disp=0, cov_type="cluster", cov_kwds={"groups": use.a7}, method="bfgs", maxiter=2000)
            me = m.get_margeff(at="overall").summary_frame().loc["local"]
            lg.append({"b": {"local": me["dy/dx"]}, "se": {"local": me["Std. Err."]}, "p": {"local": me["Pr(>|z|)"]}})
        except Exception:
            m = smf.logit(f"{y} ~ local + C(stratum)", use).fit(disp=0, cov_type="cluster",
                                                                cov_kwds={"groups": use.a7}, method="bfgs", maxiter=2000)
            me = m.get_margeff(at="overall").summary_frame().loc["local"]
            lg.append({"b": {"local": me["dy/dx"]}, "se": {"local": me["Std. Err."]}, "p": {"local": me["Pr(>|z|)"]}})
    add("(9) Logit, average marginal effect", lg)
    add("(10) Control for share of Local neighbours", [ols(OWN, y, ["local", "share_adj_local"]) for y, _ in ys])
    own_c, xc = add_missing_dummies(OWN, CONTROLS)
    add("(11) Owner covariates (Table 5, Panel B)", [ols(own_c, y, ["local"] + xc) for y, _ in ys])
    add("(12) Registered sample, any owner data", [ols(REG, "exempt_age", ["local"]), None, ols(REG, "exempt", ["local"]), None])
    # (13) all midline-matched owners; an unrecorded exemption decision counts as "not exempt"
    M0 = F[(F.s_midline == 1) & F.owner_age.notna() & F.female.notna()].copy()
    M0["exempt_age"] = M0.exempt_age.fillna(0)
    M0["exempt"] = M0.exempt.fillna(0)
    M0["disc_age"] = ((M0.exempt_age == 1) & (M0.owner_age < 55)).astype(float)
    M0["exempt_no_basis"] = M0.exempt_no_basis.fillna(0)
    add("(13) All midline owners, unrecorded = 0", [ols(M0, y, ["local"]) for y, _ in ys])
    r13 = ols(M0, "disc_age", ["local"])
    RESULTS.update({"m0_disc_b": r13["b"]["local"], "m0_disc_p": r13["p"]["local"], "N_m0": r13["N"],
                    "m0_age_b": ols(M0, "exempt_age", ["local"])["b"]["local"], "m0_age_p": ols(M0, "exempt_age", ["local"])["p"]["local"]})

    # randomization inference: re-draw Local across neighbourhoods within strata, 2,000 permutations
    NPERM = 2000
    ri = {}
    nbs = OWN.groupby("a7").agg(stratum=("stratum", "first"), local=("local", "first")).reset_index()
    for y, _ in ys:
        use = OWN.dropna(subset=[y, "time_fe"]).copy()
        Z = pd.get_dummies(use[FE].astype(int).astype(str), drop_first=True).astype(float).values
        Z = np.column_stack([np.ones(len(use)), Z])
        Q, _ = np.linalg.qr(Z)
        ry = use[y].values - Q @ (Q.T @ use[y].values)

        def coef(dv):
            rd_ = dv - Q @ (Q.T @ dv)
            return (rd_ @ ry) / (rd_ @ rd_)
        b0 = coef(use.local.values.astype(float))
        idx = use.a7.map(dict(zip(nbs.a7, range(len(nbs))))).values
        draws = np.empty(NPERM)
        prng = np.random.default_rng(SEED)
        strata = nbs.stratum.values
        for k in range(NPERM):
            perm = nbs.local.values.copy()
            for s_ in np.unique(strata):
                ii = np.where(strata == s_)[0]
                perm[ii] = prng.permutation(perm[ii])
            draws[k] = coef(perm[idx].astype(float))
        ri[y] = (b0, draws, (np.abs(draws) >= abs(b0)).mean())
    rows.append(["\\midrule"])
    rows.append(["Randomization-inference $p$ (2,000 draws)"] + [f"{ri[y][2]:.3f}" for y, _ in ys])
    rows.append(["Central mean"] + [f"{OWN.loc[OWN.local == 0, y].mean():.3f}" for y, _ in ys])
    write_table("table8_robustness", ["Specification", "Old age", "Old age, owner $<$ cut-off", "Any exemption",
                                      "No basis"], rows,
                "Robustness of the Local effect", "tab:robust",
                "Owner-linked sample unless stated. Each cell is the coefficient on Local (standard error clustered by "
                "neighbourhood). Rows 2--4 move the age cut-off that defines a discretionary old-age exemption (legal "
                "cut-off 55). Row 5 drops owners whose age the respondent gave as a five-year band. Row 8 collapses to "
                "neighbourhood means (robust SE). Row 9 reports logit average marginal effects. Row 12 uses all "
                f"registered properties. The randomization-inference $p$-value re-assigns Local across neighbourhoods "
                f"within strata {NPERM:,} times (seed {SEED}) and compares $|\\hat\\beta|$ with the permutation "
                "distribution. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", colspec="lcccc", size="\\scriptsize")
    fig, axes = plt.subplots(1, 3, figsize=(9.2, 2.6))
    for ax, y, t in zip(axes, ["exempt_age", "disc_age", "exempt"],
                        ["(a) Old-age exemption", "(b) Old age, owner under 55", "(c) Any exemption"]):
        b0, dr, p = ri[y]
        ax.hist(dr, bins=50, color=C_GREY, alpha=0.8)
        ax.axvline(b0, color=C_LOC, lw=2)
        ax.set_title(f"{t}\nRI $p$ = {p:.3f}", fontsize=9)
        ax.set_xlabel("Placebo coefficient on Local")
    axes[0].set_ylabel("Count")
    fig.tight_layout()
    savefig(fig, "fig7_ri")
    RESULTS.update({f"ri_{y}": ri[y][2] for y, _ in ys})
    r_ex = ols(exact, "disc_age", ["local"])
    RESULTS.update({"exact_disc_b": r_ex["b"]["local"], "exact_disc_p": r_ex["p"]["local"], "N_exact": r_ex["N"]})
    for c in [50, 60, 65]:
        r = ols(OWN, f"disc_age{c}", ["local"])
        RESULTS[f"disc{c}_b"], RESULTS[f"disc{c}_p"] = r["b"]["local"], r["p"]["local"]
    print("S11 done")

# =============================================================================
# S12. Tree, bagging, random forest, boosting (Y = exempt)
# =============================================================================
if run("S12"):
    MLX = ["local", "owner_age", "female", "luluwa", "work_gov", "family_gov", "employed", "years_avenue",
           "walls_good", "coethnic_chief", "chief_luluwa", "chief_age", "dist_city_center", "log_pred_value",
           "assigned_rate", "tmt_2016"]
    df = OWN.dropna(subset=["exempt"]).reset_index(drop=True)
    gss = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=SEED)
    tr, te = next(gss.split(df, groups=df.a7))
    med = df.iloc[tr][MLX].median()
    X = df[MLX].fillna(med)
    Xtr, Xte = X.iloc[tr], X.iloc[te]
    gtr = df.a7.iloc[tr].values
    RESULTS.update({"ml_ntr": len(tr), "ml_nte": len(te), "ml_jtr": len(set(gtr)), "ml_jte": df.a7.iloc[te].nunique()})
    cvf = list(GroupKFold(10).split(Xtr, groups=gtr))

    def cv_mse(model, Xa, ya):
        out = []
        for a_, b_ in cvf:
            model.fit(Xa.iloc[a_], ya.iloc[a_])
            out.append(mean_squared_error(ya.iloc[b_], model.predict(Xa.iloc[b_])))
        return np.mean(out), np.std(out) / np.sqrt(len(out))

    results = {}

    def fit_all(yname):
        ytr, yte = df[yname].iloc[tr], df[yname].iloc[te]
        out = {"Mean only (benchmark)": (mean_squared_error(yte, np.full(len(yte), ytr.mean())), np.nan)}
        lr = LinearRegression().fit(Xtr, ytr)
        out["OLS (linear probability)"] = (mean_squared_error(yte, lr.predict(Xte)), np.nan)
        # pruned tree: alpha by grouped CV with 1-SE rule
        path = DecisionTreeRegressor(random_state=SEED, min_samples_leaf=20).cost_complexity_pruning_path(Xtr, ytr)
        alphas = np.unique(path.ccp_alphas)
        alphas = alphas[np.linspace(0, len(alphas) - 2, 40).astype(int)]
        cvs = [cv_mse(DecisionTreeRegressor(random_state=SEED, min_samples_leaf=20, ccp_alpha=a), Xtr, ytr) for a in alphas]
        m_ = np.array([c[0] for c in cvs]); s_ = np.array([c[1] for c in cvs])
        best = alphas[np.max(np.where(m_ <= m_.min() + s_[m_.argmin()])[0])]
        tree = DecisionTreeRegressor(random_state=SEED, min_samples_leaf=20, ccp_alpha=best).fit(Xtr, ytr)
        out["Regression tree (pruned)"] = (mean_squared_error(yte, tree.predict(Xte)), np.nan)
        bag = RandomForestRegressor(n_estimators=500, max_features=None, min_samples_leaf=5, oob_score=True,
                                    random_state=SEED, n_jobs=-1).fit(Xtr, ytr)
        out[f"Bagging ($m=p={len(MLX)}$)"] = (mean_squared_error(yte, bag.predict(Xte)), mean_squared_error(ytr, bag.oob_prediction_))
        # RF: choose m by OOB error
        oob = {}
        for m in [2, 3, 4, 5, 6, 8]:
            rf_ = RandomForestRegressor(n_estimators=300, max_features=m, min_samples_leaf=5, oob_score=True,
                                        random_state=SEED, n_jobs=-1).fit(Xtr, ytr)
            oob[m] = mean_squared_error(ytr, rf_.oob_prediction_)
        mbest = min(oob, key=oob.get)
        rf = RandomForestRegressor(n_estimators=500, max_features=mbest, min_samples_leaf=5, oob_score=True,
                                   random_state=SEED, n_jobs=-1).fit(Xtr, ytr)
        out[f"Random forest ($m={mbest}$)"] = (mean_squared_error(yte, rf.predict(Xte)), mean_squared_error(ytr, rf.oob_prediction_))
        # boosting: number of trees by grouped CV on the training set
        B = 800
        errs = np.zeros(B)
        for a_, b_ in cvf:
            gb = GradientBoostingRegressor(n_estimators=B, learning_rate=0.01, max_depth=3, subsample=0.8,
                                           random_state=SEED).fit(Xtr.iloc[a_], ytr.iloc[a_])
            errs += np.array([mean_squared_error(ytr.iloc[b_], p) for p in gb.staged_predict(Xtr.iloc[b_])])
        Bbest = int(np.argmin(errs) + 1)
        gb = GradientBoostingRegressor(n_estimators=Bbest, learning_rate=0.01, max_depth=3, subsample=0.8,
                                       random_state=SEED).fit(Xtr, ytr)
        out[f"Boosting ($B={Bbest}$, $\\lambda=0.01$, $d=3$)"] = (mean_squared_error(yte, gb.predict(Xte)), np.nan)
        return out, tree, rf, Bbest, mbest, best

    res_ex, tree, rf, Bbest, mbest, alpha = fit_all("exempt")
    res_age, tree_age, rf_age, _, _, _ = fit_all("exempt_age")
    base_ex = res_ex["Mean only (benchmark)"][0]
    base_age = res_age["Mean only (benchmark)"][0]
    rows = []
    for (k, (mse, oob)), (k2, (mse2, _)) in zip(res_ex.items(), res_age.items()):
        rows.append([k, f"{mse:.4f}", f"{np.sqrt(mse):.4f}", f"{100 * (mse / base_ex - 1):+.1f}",
                     "--" if np.isnan(oob) else f"{oob:.4f}", f"{mse2:.4f}", f"{100 * (mse2 / base_age - 1):+.1f}"])
    write_table("table9_ml_errors", ["Model", "Test MSE", "Test RMSE", "\\% vs mean", "OOB MSE", "Test MSE",
                                     "\\% vs mean"], rows,
                "Out-of-sample error of tree-based models", "tab:ml",
                f"Owner-linked sample split 80/20 by neighbourhood ({RESULTS['ml_jtr']} training and "
                f"{RESULTS['ml_jte']} test neighbourhoods; {nfmt(len(te))} test properties; seed {SEED}). "
                f"{len(MLX)} pre-determined features including Local. MSE of a 0/1 outcome is the Brier score. The "
                "tree's complexity parameter (1-SE rule) and the number of boosting iterations are chosen by 10-fold "
                "CV grouped by neighbourhood inside the training set; the random forest's $m$ is chosen by OOB error. "
                "OOB MSE is computed on the training set.", colspec="lcccccc",
                groups=[("", 1), ("$Y$ = any exemption", 4), ("$Y$ = old-age exemption", 2)])
    for k, (mse, oob) in res_ex.items():
        RESULTS[f"ml_{k.split(' ')[0].lower()}"] = mse
    RESULTS.update({"ml_mbest": mbest, "ml_B": Bbest, "ml_leaves": tree.get_n_leaves(), "ml_depth": tree.get_depth(),
                    "ml_base": base_ex})
    # Figure 11: tree for exempt
    names = [LABEL.get(c, c) for c in MLX]
    fig, ax = plt.subplots(figsize=(10, 4.6))
    plot_tree(tree, feature_names=names, filled=True, impurity=False, rounded=True, precision=2, fontsize=7,
              ax=ax, max_depth=4)
    ax.set_title(f"Pruned regression tree for P(exempt) ({tree.get_n_leaves()} leaves; value = share exempt)", fontsize=9)
    savefig(fig, "fig8_tree")
    # Figure 12: importance
    mdi = pd.Series(rf.feature_importances_, index=names).sort_values()
    pi = permutation_importance(rf, Xte, df.exempt.iloc[te], n_repeats=20, random_state=SEED,
                                scoring="neg_mean_squared_error")
    pim = pd.Series(pi.importances_mean, index=names).loc[mdi.index] * 1e3
    pis = pd.Series(pi.importances_std, index=names).loc[mdi.index] * 1e3
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(8.6, 3.8), sharey=True)
    a1.barh(mdi.index, mdi.values, color=C_CEN)
    a1.set_title("Impurity decrease (MDI), training data", fontsize=9)
    a2.barh(pim.index, pim.values, xerr=pis.values, color=C_LOC)
    a2.axvline(0, color="k", lw=0.6)
    a2.set_title("Permutation: test MSE increase ($\\times 10^3$)", fontsize=9)
    fig.tight_layout()
    savefig(fig, "fig9_rf_importance")
    pd.DataFrame({"MDI": mdi, "perm_mse_x1000": pim, "perm_sd": pis}).to_csv(TAB / "table9b_rf_importance.csv")
    RESULTS.update({"imp_top": mdi.index[-1], "imp_local_rank_mdi": int(len(mdi) - list(mdi.index).index("Local")),
                    "perm_local": pim["Local"], "perm_age": pim["Owner age"], "perm_female": pim["Owner female"]})
    # Figure 13: partial dependence of P(old-age exemption) on age, Local = 0 vs 1 (random forest on exempt_age)
    grid = np.arange(25, 86, 1.0)
    pdp = {}
    for arm in (0, 1):
        vals = []
        for g in grid:
            Xg = X.copy()
            Xg["owner_age"], Xg["local"] = g, arm
            vals.append(rf_age.predict(Xg).mean())
        pdp[arm] = np.array(vals)
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(8.6, 2.8))
    a1.plot(grid, pdp[0], color=C_CEN, label="Local = 0 (Central)")
    a1.plot(grid, pdp[1], color=C_LOC, label="Local = 1")
    a1.axvline(55, ls="--", color="k", lw=0.8)
    a1.set_xlabel("Owner age")
    a1.set_ylabel("Partial dependence, P(old-age exempt)")
    a1.legend(frameon=False)
    a2.plot(grid, (pdp[1] - pdp[0]) * 100, color="k")
    a2.axhline(0, color=C_GREY, lw=0.7)
    a2.axvline(55, ls="--", color="k", lw=0.8)
    a2.set_xlabel("Owner age")
    a2.set_ylabel("Local $-$ Central (pp)")
    fig.tight_layout()
    savefig(fig, "fig10_pdp")
    RESULTS.update({"pdp_gap_u55": float((pdp[1] - pdp[0])[grid < 55].mean()),
                    "pdp_gap_55p": float((pdp[1] - pdp[0])[grid >= 55].mean())})
    print("S12 done")

# =============================================================================
# Save the numbers quoted in the text
# =============================================================================
kn = TAB / "key_numbers.csv"
old = pd.read_csv(kn).set_index("key")["value"].to_dict() if kn.exists() else {}
old.update({k: v for k, v in RESULTS.items()})
pd.DataFrame({"key": list(old), "value": list(old.values())}).to_csv(kn, index=False)
print("key numbers ->", kn)
