"""
00_master.py  -  run everything in order. Usage (from anywhere):  python 00_master/00_master.py

Tested with: Python 3.11, pandas 3.0.5, numpy 2.5.3, statsmodels 0.15.0,
scikit-learn 1.9.1, matplotlib 3.11.2
Install:  pip install pandas numpy statsmodels scikit-learn matplotlib
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = [
    "01_preanalysis/01_preanalysis_week3.py",   # raw data -> data_intermediate/
    "02_analysis/02_analysis_week3.py",         # data_intermediate -> 03_output/week3/
]
for step in STEPS:
    print(f"\n=== running {step} ===")
    subprocess.run([sys.executable, str(ROOT / step)], check=True, cwd=ROOT)
print("\nAll steps finished. Outputs are in 03_output/")
