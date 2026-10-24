"""
make_codebook.py
----------------
Auto-generates a variable-level codebook for every CSV in 0_RawData/.

Outputs (written to 0_RawData/codebook/, raw CSVs are only READ, never modified):
  - codebook_all_variables.csv   one row per (file, variable)
  - <folder>__<file>.md          one browsable Markdown table per raw file

Run from the repository root:
    python 0_RawData/codebook/make_codebook.py

Requirements: Python >= 3.9, pandas >= 1.5 (pip install pandas==2.2.2)
No randomness is used, so no seed is needed.
"""
from __future__ import annotations

import re
import warnings
from pathlib import Path

import pandas as pd

warnings.filterwarnings("ignore")

RAW_DIR = Path(__file__).resolve().parents[1]          # .../0_RawData
OUT_DIR = Path(__file__).resolve().parent              # .../0_RawData/codebook

ID_NAMES = {"a7", "compound1", "compound", "compound_code", "code", "chef_code",
            "colcode", "col_code", "collector_id", "s3_code", "hh_code",
            "tdmnumber", "tdm", "polygon", "stratum", "key", "metainstanceid"}
STATA_MISSING_STR = {".", ".a", ".b", ".c", ".d", ".n", ".r", ".s", ""}
SPECIAL_CODES = [-99, -98, -97, -9, -1, 88, 97, 98, 99, 777, 888, 999, 9999, 99999, 999999]


def looks_datetime(s: pd.Series) -> str | None:
    """Return 'datetime', 'date' or 'time' if a string column parses as such."""
    v = s.dropna().astype(str).str.strip()
    v = v[~v.isin(STATA_MISSING_STR)]
    if len(v) == 0:
        return None
    sample = v.sample(min(len(v), 300), random_state=0)   # deterministic sample
    if sample.str.fullmatch(r"\d{1,2}:\d{2}(:\d{2})?(\s?[AP]M)?").mean() > 0.8:
        return "time"
    parsed = pd.to_datetime(sample, errors="coerce", dayfirst=False)
    if parsed.notna().mean() < 0.8:
        return None
    has_clock = sample.str.contains(r"\d{1,2}:\d{2}").mean() > 0.5
    return "datetime" if has_clock else "date"


def classify(name: str, s: pd.Series) -> str:
    nonmiss = s.dropna()
    if pd.api.types.is_object_dtype(s):
        nonmiss = nonmiss[~nonmiss.astype(str).str.strip().isin(STATA_MISSING_STR)]
    if len(nonmiss) == 0:
        return "all_missing"
    low = name.lower()
    if low in ID_NAMES or re.search(r"(^|_)(id|code)\d*$", low):
        return "id_key"
    if pd.api.types.is_numeric_dtype(s):
        u = nonmiss.unique()
        if set(u) <= {0, 1}:
            return "binary_0_1"
        if len(u) <= 12 and all(float(x).is_integer() for x in u):
            return "categorical_int"
        return "numeric_continuous"
    dt = looks_datetime(s)
    if dt:
        return dt
    if nonmiss.nunique() <= 20:
        return "categorical_text"
    return "free_text"


def describe(name: str, s: pd.Series, n_rows: int) -> dict:
    kind = classify(name, s)
    obj = pd.api.types.is_object_dtype(s)
    clean = s.dropna()
    if obj:
        clean = clean[~clean.astype(str).str.strip().isin(STATA_MISSING_STR)]
    row = {
        "variable": name,
        "storage": str(s.dtype),
        "kind": kind,
        "n_nonmissing": int(len(clean)),
        "pct_nonmissing": round(100 * len(clean) / n_rows, 1) if n_rows else 0.0,
        "n_unique": int(clean.nunique()),
        "min": "", "max": "", "values_or_examples": "", "special_codes": "",
    }
    if len(clean) == 0:
        return row
    if kind in {"date", "datetime"}:
        d = pd.to_datetime(clean, errors="coerce")
        row["min"], row["max"] = str(d.min())[:19], str(d.max())[:19]
    elif pd.api.types.is_numeric_dtype(s):
        row["min"], row["max"] = f"{clean.min():g}", f"{clean.max():g}"
        found = [f"{c}(n={int((clean == c).sum())})" for c in SPECIAL_CODES if (clean == c).any()]
        row["special_codes"] = "; ".join(found)
    if kind in {"binary_0_1", "categorical_int", "categorical_text"}:
        vc = clean.value_counts().sort_index()
        row["values_or_examples"] = "; ".join(f"{k}={v}" for k, v in vc.head(12).items())
    elif kind in {"free_text", "id_key", "time"} or obj:
        ex = [str(x)[:30].replace("|", "/") for x in clean.unique()[:3]]
        row["values_or_examples"] = " / ".join(ex)
    return row


def main() -> None:
    all_rows = []
    for path in sorted(RAW_DIR.rglob("*.csv")):
        if OUT_DIR in path.parents:
            continue
        rel = path.relative_to(RAW_DIR).as_posix()
        try:
            df = pd.read_csv(path, low_memory=False)
        except pd.errors.EmptyDataError:
            print(f"[EMPTY FILE] {rel}")
            all_rows.append({"file": rel, "variable": "(file is empty)", "kind": "EMPTY"})
            continue
        rows = [describe(c, df[c], len(df)) for c in df.columns]
        for r in rows:
            r["file"] = rel
        all_rows.extend(rows)

        md = OUT_DIR / (rel.replace("/", "__").replace(".csv", ".md"))
        tab = pd.DataFrame(rows).drop(columns="file")
        header = (f"# Codebook: `0_RawData/{rel}`\n\n"
                  f"- Rows: **{len(df):,}**  |  Columns: **{df.shape[1]:,}**\n"
                  f"- Auto-generated by `make_codebook.py`. See `0_RawData/README.md` for "
                  f"the unit of observation, keys, timing and meaning of variable families.\n"
                  f"- `kind` is inferred from the data; `special_codes` flags values such as "
                  f"99/999/9999 that usually mean don't know / refused / not applicable.\n\n")
        md.write_text(header + tab.to_markdown(index=False), encoding="utf-8")
        print(f"[ok] {rel}: {len(df):,} rows x {df.shape[1]} cols")

    cols = ["file", "variable", "storage", "kind", "n_nonmissing", "pct_nonmissing",
            "n_unique", "min", "max", "values_or_examples", "special_codes"]
    pd.DataFrame(all_rows).reindex(columns=cols).to_csv(
        OUT_DIR / "codebook_all_variables.csv", index=False, encoding="utf-8")


if __name__ == "__main__":
    main()
