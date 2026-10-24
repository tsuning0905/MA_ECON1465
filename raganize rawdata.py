"""
organize_rawdata.py
Clean up MA_ECON1465/0_RawData:
  1. Fix folder names with stray spaces (e.g. "0.2chief " -> "0.2chief") and merge them.
  2. Move every loose CSV in the repo root into a numbered subfolder of 0_RawData.

Usage (run from anywhere):
    python organize_rawdata.py /path/to/MA_ECON1465            # preview only
    python organize_rawdata.py /path/to/MA_ECON1465 --apply    # actually move files

In Colab:  !python organize_rawdata.py /content/MA_ECON1465 --apply
If the folder is a git repo, files are moved with `git mv` so history is kept.
"""
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

# ---- Edit this mapping if you want different groups --------------------------
# Each CSV goes to the first group whose rule matches (prefix or exact name).
GROUPS = [
    ("0.1Baseline",      ["baseline_"]),
    ("0.2chief",         ["chief_"]),
    ("0.3collector",     ["collector_", "campaign_collector_info"]),
    ("0.4endline",       ["endline_"]),
    ("0.5tax",           ["tax_", "taxroll_"]),
    ("0.6campaign",      ["campaign_", "fliers_", "registration_"]),
    ("0.7randomization", ["randomization_", "stratum"]),
    ("0.8geography",     ["hh_distances", "neighborhood_"]),
]
OTHER = "0.9other"   # anything that matches no rule
# -------------------------------------------------------------------------------


def clean_name(name: str) -> str:
    """Remove leading/trailing spaces and turn full-width characters into normal ones."""
    return unicodedata.normalize("NFKC", name).strip()


def pick_group(filename: str) -> str:
    for folder, rules in GROUPS:
        if any(filename.startswith(r) for r in rules):
            return folder
    return OTHER


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    repo = Path(sys.argv[1]).expanduser().resolve()
    apply = "--apply" in sys.argv
    raw = repo / "0_RawData"
    use_git = (repo / ".git").exists() and shutil.which("git")

    def move(src: Path, dst: Path):
        rel_src, rel_dst = src.relative_to(repo), dst.relative_to(repo)
        if dst.exists():
            print(f"  SKIP (already exists): {rel_dst}")
            return
        print(f"  {rel_src}  ->  {rel_dst}")
        if not apply:
            return
        dst.parent.mkdir(parents=True, exist_ok=True)
        if use_git:
            r = subprocess.run(["git", "-C", str(repo), "mv", str(rel_src), str(rel_dst)],
                               capture_output=True, text=True)
            if r.returncode == 0:
                return
        shutil.move(str(src), str(dst))  # not tracked by git, or git mv failed

    print("PREVIEW (nothing is moved; add --apply to run)\n" if not apply else "APPLYING\n")

    # Step 1: fix bad folder names inside 0_RawData and merge duplicates
    print("Step 1: fix folder names")
    for d in sorted(p for p in raw.iterdir() if p.is_dir()):
        good = clean_name(d.name)
        if good != d.name:
            print(f"  bad name: {d.name!r} -> {good!r}")
            for f in sorted(d.iterdir()):
                move(f, raw / good / f.name)
            if apply and not any(d.iterdir()):
                d.rmdir()

    # Step 2: move loose CSVs from the repo root into 0_RawData/<group>/
    print("\nStep 2: sort loose CSVs")
    for f in sorted(repo.glob("*.csv")):
        move(f, raw / pick_group(f.name) / f.name)

    # Summary
    if apply:
        print("\nResult:")
        for d in sorted(p for p in raw.iterdir() if p.is_dir()):
            print(f"  {d.name}/  ({len(list(d.glob('*.csv')))} csv)")
        if use_git:
            print("\nNow commit:  git add -A && git commit -m 'Organize raw data' && git push")


if __name__ == "__main__":
    main()