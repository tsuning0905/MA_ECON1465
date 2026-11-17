"""
00_master.py — run the whole ECO1465 Week 9 pipeline from raw data to outputs.

Usage (from anywhere):
    python 00_master/00_master.py
The project root is found from this file's location; no path needs editing.
Raw data (0_RawData/) is looked up in this folder or any parent folder (in the repo
it is MA_ECON1465/0_RawData) and is only read, never written.
On Colab: clone the repo, `pip install -r requirements.txt`, then run this file.

Order
  01_preanalysis/01_preanalysis.py          raw data -> data_intermediate/ (final datasets)
  02_analysis/02_week6_benchmark.py         Week 6: benchmark, biased sample (seed 1465)
                                            -> 03_output/week6/, data_intermediate/week6_biased_sample.csv.gz
  02_analysis/02_week7_matching_ipw.py      Week 7: PS matching and IPW (compared against in Week 9)
                                            -> 03_output/week7/
  02_analysis/02_week9_doubly_robust.py     Week 9: DR learners on the biased sample (with / without S),
                                            bootstrap CIs, DR on the full sample -> 03_output/week9/

Optional environment variables: ECO1465_JOBS (parallel workers, default all cores),
ECO1465_NBOOT (Week 9 bootstrap draws, default 200; use e.g. 20 for a quick test run).
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
    "02_analysis/02_week7_matching_ipw.py",
    "02_analysis/02_week9_doubly_robust.py",
]

for step in STEPS:
    t0 = time.time()
    print(f"\n===== {step} =====")
    runpy.run_path(str(ROOT / step), run_name="__main__")
    print(f"----- done in {time.time() - t0:.0f}s")
