"""Zips the corpus and publishes a GitHub Release; updates latest.json."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import zipfile
from pathlib import Path


GH_REPO = "Frazier-at-CPCC/cpcc-ask-ios"


def make_zip(out_dir: Path, version: str) -> Path:
    zip_path = out_dir / f"corpus-{version}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for name in ("corpus.sqlite", "embeddings.bin", "manifest.json"):
            zf.write(out_dir / name, arcname=name)
    return zip_path


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def publish(zip_path: Path, version: str) -> str:
    tag = f"corpus-{version}"
    subprocess.run(
        ["gh", "release", "create", tag, str(zip_path),
         "--title", f"Corpus {version}",
         "--notes", f"Automated corpus build for {version}",
         "--repo", GH_REPO],
        check=True,
    )
    return f"https://github.com/{GH_REPO}/releases/download/{tag}/{zip_path.name}"


def update_latest(repo_root: Path, version: str, url: str, size: int, sha: str) -> None:
    payload = {"version": version, "url": url, "size": size, "sha256": sha}
    (repo_root / "latest.json").write_text(json.dumps(payload, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("pipeline/out"))
    parser.add_argument("--version", type=str, required=True)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    args = parser.parse_args()

    zip_path = make_zip(args.out, args.version)
    sha = sha256_of(zip_path)
    size = os.path.getsize(zip_path)
    url = publish(zip_path, args.version)
    update_latest(args.repo_root, args.version, url, size, sha)
    print(f"Released {url}")
    print(f"latest.json updated. Open a PR to merge it.")
