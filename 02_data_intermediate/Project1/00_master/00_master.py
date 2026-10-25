"""
00_master.py - run the whole ECO1465 Project One pipeline, in order.

    python 00_master/00_master.py              # everything: data -> tables/figures -> paper PDF
    python 00_master/00_master.py --rebuild    # also re-run the port of the authors' data construction
    python 00_master/00_master.py --no-paper   # skip compiling the LaTeX paper

Steps
  1. 01_preanalysis/01_preanalysis.py   raw data (0_RawData/, read-only) -> data_intermediate/final_property.csv.gz
                              (calls 01_preanalysis/01a_data_construction.py the first time, or with --rebuild)
  2. 02_analysis/02_analysis.py      final data -> 03_output/tables (.tex/.csv/.xlsx), 03_output/figures (.pdf/.png)
  3. 03_output/paper/main.tex -> 03_output/paper/main.pdf  (needs pdflatex; skipped with a warning if missing)

All paths are relative to this file, so the repository can be cloned anywhere.
"""
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]   # repository root
PY = sys.executable
args = sys.argv[1:]


def step(name, cmd, cwd=ROOT):
    t0 = time.time()
    print(f"\n=== {name} ===", flush=True)
    subprocess.run(cmd, cwd=cwd, check=True)
    print(f"--- {name} finished in {time.time() - t0:.0f}s", flush=True)


step("1. Pre-analysis (clean data, build variables)",
     [PY, "01_preanalysis/01_preanalysis.py"] + (["--rebuild"] if "--rebuild" in args else []))
step("2. Analysis (Tables 1-9, Figures 1-10)", [PY, "02_analysis/02_analysis.py"])

if "--no-paper" not in args:
    if shutil.which("pdflatex"):
        for _ in range(2):   # twice, for cross-references
            step("3. Compile paper", ["pdflatex", "-interaction=nonstopmode", "-halt-on-error", "main.tex"],
                 cwd=ROOT / "03_output" / "paper")
        print("\nPaper:", ROOT / "03_output" / "paper" / "main.pdf")
    else:
        print("\n[warning] pdflatex not found - 03_output/paper/main.tex not compiled (tables and figures are in 03_output/)")
