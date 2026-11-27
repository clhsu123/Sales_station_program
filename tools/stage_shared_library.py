#!/usr/bin/env python3
"""Extract a review copy of the shared library from both local regions."""
import argparse
import json
from pathlib import Path
import re


REGIONS = ("andes-data-korea", "andes-data-japan")
ASSET_REF = re.compile(r"(?:a|u):([\w.-]+)")
CASE_DIRECTORIES = ("decks", "kb", "stories")
ASSET_DIRECTORIES = ("decks/_images", "stories/assets")


def image_references(value):
    if isinstance(value, str):
        match = ASSET_REF.fullmatch(value)
        return {match[1]} if match else set()
    if isinstance(value, dict):
        value = value.values()
    elif not isinstance(value, list):
        return set()
    return {ref for child in value for ref in image_references(child)}


def prepare_region(root, bundled_ids, include_customer_decks):
    records = {}
    refs = set()
    for directory in CASE_DIRECTORIES:
        for path in sorted((root / directory).glob("*.json")):
            if path.name.startswith(("_", ".")) and path.name != "_labels.json":
                continue
            document = json.loads(path.read_text(encoding="utf-8-sig"))
            if directory == "decks":
                kind = document.get("kind")
                if kind != "master" and not (include_customer_decks and kind == "customer"):
                    continue
            records[path.relative_to(root)] = document
            refs.update(image_references(document))

    missing = []
    for ref in sorted(refs):
        for directory in ASSET_DIRECTORIES:
            relative = Path(directory) / (ref + ".json")
            path = root / relative
            if path.is_file():
                image = json.loads(path.read_text(encoding="utf-8-sig"))
                if not isinstance(image.get("data"), str) or not image["data"].startswith("data:image/"):
                    raise ValueError(f"Invalid image record in {root.name}/{relative}")
                records[relative] = image
                break
        else:
            if ref not in bundled_ids:
                missing.append(ref)
    return records, missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("private_root", type=Path)
    parser.add_argument("review_folder", type=Path, help="New folder outside the source and program checkout")
    parser.add_argument("--include-customer-decks", action="store_true")
    args = parser.parse_args()
    source = args.private_root.resolve(strict=True)
    target = args.review_folder.resolve()
    checkout = Path(__file__).resolve().parents[1]
    if target.exists() or target.is_relative_to(source) or target.is_relative_to(checkout):
        parser.error("Choose a new review folder outside the private source and the program checkout.")
    if any((folder / ".git").exists() for folder in target.parents):
        parser.error("Choose a review folder outside any Git checkout.")
    for region in REGIONS:
        if not (source / region / "settings.json").is_file():
            parser.error(f"Can't find {region}/settings.json in the private root.")
    html = (checkout / "index.html").read_text(encoding="utf-8")
    match = re.search(r"window\.ANDES_ASSETS\s*=\s*(\{.*?\});", html, flags=re.S)
    bundled_ids = set(json.loads(match[1])) if match else set()
    prepared = {
        region: prepare_region(source / region, bundled_ids, args.include_customer_decks)
        for region in REGIONS
    }
    target.mkdir(parents=True)
    report = {}
    for region, (records, missing) in prepared.items():
        for relative, document in records.items():
            output = target / region / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(json.dumps(document, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        report[region] = {"files": len(records), "missing_image_ids": missing}
    (target / "review-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Review copy created. No source file was modified or uploaded.")


if __name__ == "__main__":
    main()
