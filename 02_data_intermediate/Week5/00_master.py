"""
00_master.py  --  Week 5 report (ECO1465), Tsu Ning Tsao
Run this file only:  python 00_master.py
It sets the project root, runs every script in order and compiles 03_report.tex.

Requirements (tested): Python 3.11, pandas 2.x, numpy, statsmodels 0.15.0, scikit-learn, matplotlib 3.11
  pip install pandas numpy statsmodels scikit-learn matplotlib
  plus graphviz (dot) for the DAGs and a LaTeX install (pdflatex) for the report PDF
Folder layout expected under the project root:
  0_RawData/  (raw, never overwritten)   data_intermediate/  (generated)   03_output/  (tables, figures)
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("PROJ_ROOT", os.path.dirname(HERE))
env = dict(os.environ, PROJ_ROOT=ROOT)

for script in ["01_preanalysis.py", "02_analysis.py"]:
    print(f"\n===== running {script} =====")
    subprocess.run([sys.executable, os.path.join(HERE, script)], check=True, env=env)
# ---- compile the report (needs a LaTeX install with pdflatex) ----
import shutil
out = os.path.join(ROOT, "03_output")
shutil.copy(os.path.join(HERE, "03_report.tex"), out)
for _ in range(2):
    subprocess.run(["pdflatex", "-interaction=nonstopmode", "03_report.tex"], cwd=out,
                   check=True, stdout=subprocess.DEVNULL)
shutil.copy(os.path.join(out, "03_report.pdf"), os.path.join(out, "Week5_Report_TsuNingTsao.pdf"))
print("\nDone. Outputs are in", os.path.join(ROOT, "03_output"))
