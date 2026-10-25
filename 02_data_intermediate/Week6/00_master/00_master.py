"""
00_master.py — run the whole ECO1465 pipeline from raw data to outputs.

Usage (from anywhere):
    python 00_master/00_master.py
The repo root is found from this file's location; no path needs editing.
On Colab: clone the repo, `pip install -r requirements.txt`, then run this file.

Order
  01_preanalysis/01_preanalysis.py      raw data -> data_intermediate/ (final datasets)
  02_analysis/02_week6_benchmark.py     Week 6: benchmark, biased sample, DoWhy -> 03_output/week6/
"""
import os
import runpy
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ["ECO1465_ROOT"] = str(ROOT)

STEPS = [
    "01_preanalysis/01_preanalysis.py",
    "02_analysis/02_week6_benchmark.py",
]

for step in STEPS:
    t0 = time.time()
    print(f"\n===== {step} =====")
    runpy.run_path(str(ROOT / step), run_name="__main__")
    print(f"----- done in {time.time() - t0:.0f}s")
