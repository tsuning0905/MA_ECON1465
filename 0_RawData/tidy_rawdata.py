"""
tidy_rawdata.py
---------------
Tidies the folder 0_RawData/ WITHOUT changing the content of any data file.

What it does (every step is safe to run again; a second run changes nothing):
  1. Moves data files sitting loose in 0_RawData/ into their sub-folder
     (e.g. 0_RawData/baseline_noPII.csv -> 0_RawData/0.1Baseline/baseline_noPII.csv).
       - if the sub-folder copy is EMPTY (0-2 bytes, e.g. only a line break), it is
         replaced by the full copy;
       - if the sub-folder copy is byte-identical, the loose duplicate is removed;
       - if both exist and differ, NOTHING is touched and a warning is printed.
  2. Moves codebook files (*.md per data file, codebook_all_variables.csv,
     make_codebook.py) into 0_RawData/codebook/.
  3. Checks: empty files, files > 100 MB (GitHub hard limit), file names with
     spaces / non-ASCII characters, CSVs with blank rows.
  4. Writes 0_RawData/codebook/checksums_sha256.csv (size + SHA-256 of every
     data file) so anyone can verify the raw data were never edited.

Moving a file never changes its bytes; the script verifies the SHA-256
before and after each move and stops if they differ.

Run from the repository root:
    python 0_RawData/tidy_rawdata.py            # do it
    python 0_RawData/tidy_rawdata.py --dry-run  # only show what would happen

Requirements: Python >= 3.9, standard library only. No randomness -> no seed.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import re
import shutil
import sys
from pathlib import Path

RAW = Path(__file__).resolve().parent            # .../0_RawData
CODEBOOK = RAW / "codebook"

# --------------------------------------------------------------------------
# Where every raw data file belongs (file name -> sub-folder of 0_RawData)
# Add a line here when a new raw file is added to the project.
# --------------------------------------------------------------------------
DESTINATION = {
    # 0.1 household baseline survey (2017)
    "baseline_noPII.csv": "0.1Baseline",
    # 0.2 chiefs
    "chief_collector_candidates.csv": "0.2chief",
    "chief_collector_candidates_campaignupdated.csv": "0.2chief",
    "chief_consultations.csv": "0.2chief",
    "chief_info.csv": "0.2chief",
    "chief_knowledge.csv": "0.2chief",
    "chief_knowledge_neighborhoods.csv": "0.2chief",
    "chief_survey_noPII.csv": "0.2chief",
    "chief_survey_randbasis_noPII.csv": "0.2chief",
    "chief_tribe_info.csv": "0.2chief",
    "resident_info_quiz.csv": "0.2chief",          # photos shown in the chief knowledge quiz
    # 0.3 collectors
    "campaign_collector_info.csv": "0.3collector",
    "collector_baseline_noPII.csv": "0.3collector",
    "collector_chars.csv": "0.3collector",
    "collector_endline_noPII.csv": "0.3collector",
    "collector_knowledge_clean.csv": "0.3collector",
    # 0.4 household endline surveys
    "endline_2016campaign_noPII.csv": "0.4endline",
    "endline_round1_noPII.csv": "0.4endline",
    "endline_round2_noPII.csv": "0.4endline",
    # 0.5 tax administrative data
    "taxroll_noPII.csv": "0.5tax",
    "tax_payments_noPII.csv": "0.5tax",
    "tax_payment_timing_noPII.csv": "0.5tax",
    "tax_payments_neighborhoods.csv": "0.5tax",
    # 0.6 campaign
    "campaign_2016_neighborhoods.csv": "0.6campaign",
    "fliers_campaign.csv": "0.6campaign",
    "registration_noPII.csv": "0.6campaign",
    "fliers_pilot_set1.xlsx": "0.6campaign",
    "fliers_pilot_set2.xlsx": "0.6campaign",
    "fliers_pilot_set3.xlsx": "0.6campaign",
    # 0.7 randomization
    "randomization_assignment.csv": "0.7randomization",
    "randomization_schedule.csv": "0.7randomization",
    "stratum.csv": "0.7randomization",
    # 0.8 geography / property
    "hh_distances.csv": "0.8geography",
    "neighborhood_centroids.csv": "0.8geography",
    "neighborhood_transport_cost.csv": "0.8geography",
    "adjacent_neighborhoods.csv": "0.8geography",
    "concessions_chefferies.csv": "0.8geography",
    "property_values_MLestimates.csv": "0.8geography",
    # 0.9 midline (monitoring) survey. The .dta is 193 MB (> GitHub's 100 MB limit),
    # so it is stored zipped; pandas reads it directly: pd.read_stata("....dta.zip")
    "midline_noPII.dta.zip": "0.9midline",
    "midline_noPII.dta": "0.9midline",
}

CODEBOOK_PATTERN = re.compile(r"^0\.\d+[A-Za-z]+__.+\.md$")     # e.g. 0.2chief__chief_info.md
CODEBOOK_FILES = {"codebook_all_variables.csv", "make_codebook.py"}
DATA_SUFFIXES = {".csv", ".xlsx", ".xls", ".dta", ".zip"}
EMPTY_MAX_BYTES = 2            # a file with only "\r\n" counts as empty
GITHUB_LIMIT = 100 * 1024**2


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def is_empty(path: Path) -> bool:
    return path.stat().st_size <= EMPTY_MAX_BYTES


def safe_move(src: Path, dst: Path, dry: bool) -> None:
    print(f"  MOVE  {src.relative_to(RAW)}  ->  {dst.relative_to(RAW)}")
    if dry:
        return
    before = sha256(src)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()                      # only reached when dst is empty
    shutil.move(str(src), str(dst))
    if sha256(dst) != before:
        sys.exit(f"STOP: checksum changed while moving {src.name}")


def remove(path: Path, why: str, dry: bool) -> None:
    print(f"  DEL   {path.relative_to(RAW)}  ({why})")
    if not dry:
        path.unlink()


def step1_place_data(dry: bool) -> None:
    print("\n[1] Put loose data files into their sub-folders")
    for src in sorted(p for p in RAW.iterdir() if p.is_file()):
        sub = DESTINATION.get(src.name)
        if sub is None:
            continue
        dst = RAW / sub / src.name
        if not dst.exists():
            safe_move(src, dst, dry)
        elif is_empty(dst) and not is_empty(src):
            print(f"  (sub-folder copy is empty: {dst.stat().st_size} bytes)")
            safe_move(src, dst, dry)
        elif sha256(src) == sha256(dst):
            remove(src, "identical copy already in " + sub, dry)
        else:
            print(f"  WARN  {src.name}: copy in root and in {sub}/ differ -> left untouched, check by hand")
    # empty sub-folder file AND no full copy anywhere -> warn
    for sub in sorted({*DESTINATION.values()}):
        for p in sorted((RAW / sub).glob("*")) if (RAW / sub).exists() else []:
            loose = RAW / p.name
            fixable = loose.exists() and not is_empty(loose)   # only true in --dry-run
            if p.is_file() and is_empty(p) and not fixable:
                print(f"  WARN  {p.relative_to(RAW)} is empty ({p.stat().st_size} bytes) - re-upload it")


def step2_place_codebook(dry: bool) -> None:
    print("\n[2] Put codebook files into 0_RawData/codebook/")
    for src in sorted(p for p in RAW.iterdir() if p.is_file()):
        if CODEBOOK_PATTERN.match(src.name) or src.name in CODEBOOK_FILES:
            dst = CODEBOOK / src.name
            if dst.exists() and sha256(dst) == sha256(src):
                remove(src, "identical copy already in codebook/", dry)
            elif dst.exists():
                # old auto-generated file vs. newer one: keep the codebook/ version,
                # make_codebook.py regenerates it anyway
                remove(src, "older version; codebook/ copy is kept", dry)
            else:
                safe_move(src, dst, dry)


def step3_checks() -> list[Path]:
    print("\n[3] Checks")
    data_files = sorted(p for p in RAW.rglob("*")
                        if p.is_file() and p.suffix.lower() in DATA_SUFFIXES
                        and CODEBOOK not in p.parents)
    ok = True
    for p in data_files:
        rel = p.relative_to(RAW).as_posix()
        size = p.stat().st_size
        if is_empty(p):
            print(f"  EMPTY      {rel} ({size} bytes)"); ok = False
        if size > GITHUB_LIMIT:
            print(f"  >100MB     {rel} ({size/1024**2:.0f} MB): GitHub will reject it; zip it"); ok = False
        if re.search(r"\s|[^\x00-\x7F]", rel):
            print(f"  BAD NAME   {rel} (space or non-ASCII character)"); ok = False
        if p.suffix.lower() == ".csv" and size < 50 * 1024**2:
            with open(p, encoding="utf-8-sig", errors="replace", newline="") as f:
                blank = sum(1 for row in csv.reader(f) if not any(c.strip() for c in row))
            if blank:
                print(f"  BLANK ROWS {rel}: {blank} empty rows (drop them when reading; file not edited)")
    for p in RAW.rglob("*"):
        if re.search(r"\s", p.name):
            print(f"  BAD NAME   {p.relative_to(RAW).as_posix()} (space in name)"); ok = False
    print("  all good" if ok else "  -> see messages above")
    return data_files


def step4_checksums(files: list[Path], dry: bool) -> None:
    print("\n[4] Write codebook/checksums_sha256.csv")
    if dry:
        return
    CODEBOOK.mkdir(exist_ok=True)
    with open(CODEBOOK / "checksums_sha256.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["file", "bytes", "sha256"])
        for p in files:
            w.writerow([p.relative_to(RAW).as_posix(), p.stat().st_size, sha256(p)])
    print(f"  {len(files)} files listed")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="show actions, change nothing")
    dry = ap.parse_args().dry_run
    print(f"0_RawData = {RAW}{'   (DRY RUN)' if dry else ''}")
    step1_place_data(dry)
    step2_place_codebook(dry)
    files = step3_checks()
    step4_checksums(files, dry)
    print("\nDone. Next: python 0_RawData/codebook/make_codebook.py")


if __name__ == "__main__":
    main()
