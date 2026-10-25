"""
00_master.py -- run the whole project from raw data to final outputs.

Usage (from anywhere):
    python 00_master/00_master.py            # run every step
    python 00_master/00_master.py --from 02  # skip data construction, rerun analysis only

Every script reads its paths from the REPO_DIR environment variable set below,
so nobody has to edit paths by hand. Steps run in the order listed in STEPS.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parents[1]

STEPS = [
    # ---- 01 pre-analysis: raw data -> data_intermediate/ ----------------------
    ("01a", "01_preanalysis/01a_data_construction.py",   # port of 2_Data_Construction.do
     "data_intermediate/analysis_data.csv.gz"),
    ("01b", "01_preanalysis/01b_build_exemption_data.py",
     "data_intermediate/exemption_analysis.csv.gz"),
    # ---- 02 analysis: data_intermediate/ -> 03_output/ ------------------------
    ("02_week4", "02_analysis/02_week4_trees.py",        # Week 4: tree, bagging, RF, boosting
     "03_output/week4/"),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="start", default="01a",
                    help="first step to run (prefix match on the step id)")
    args = ap.parse_args()

    env = dict(os.environ, REPO_DIR=str(REPO_DIR), PYTHONHASHSEED="0")
    started = False
    for step_id, script, output in STEPS:
        started = started or step_id.startswith(args.start)
        if not started:
            continue
        t0 = time.time()
        print(f"\n=== [{step_id}] {script}  ->  {output}", flush=True)
        subprocess.run([sys.executable, str(REPO_DIR / script)], env=env, check=True)
        print(f"=== [{step_id}] done in {time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
