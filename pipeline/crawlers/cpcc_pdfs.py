"""Downloads CPCC PDFs from an explicit allowlist + URLs discovered in HTML crawls."""
from __future__ import annotations

import json
import hashlib
from pathlib import Path
from urllib.parse import urlparse, urldefrag

import pdfplumber
import requests

USER_AGENT = "AskCPCC-Pipeline/0.1 (+https://github.com/Frazier-at-CPCC/cpcc-ask-ios)"

# Pin an explicit allowlist after the first crawl reveals discovered PDFs.
# Each entry is a URL to a published CPCC PDF (handbook, board policy, etc.).
ALLOWLIST: list[str] = [
    # Add explicit URLs after first audit; placeholder example:
    # "https://www.cpcc.edu/sites/default/files/2024-08/student-handbook.pdf",
]


def discover_pdfs_from_jsonl(jsonl_path: Path) -> set[str]:
    """Scan an HTML JSONL file for PDF links."""
    found: set[str] = set()
    if not jsonl_path.exists():
        return found
    with jsonl_path.open(encoding="utf-8") as fp:
        for line in fp:
            rec = json.loads(line)
            html = rec.get("html", "")
            for piece in html.split('href="'):
                if not piece:
                    continue
                end = piece.find('"')
                if end < 0:
                    continue
                href = piece[:end]
                if href.lower().endswith(".pdf"):
                    if href.startswith("/"):
                        href = "https://www.cpcc.edu" + href
                    href, _ = urldefrag(href)
                    if urlparse(href).netloc.endswith("cpcc.edu"):
                        found.add(href)
    return found


def crawl(raw_dir: Path) -> Path:
    raw_dir.mkdir(parents=True, exist_ok=True)
    out_path = raw_dir / "cpcc_pdfs.jsonl"
    discovered = discover_pdfs_from_jsonl(raw_dir / "cpcc_main.jsonl")
    discovered |= discover_pdfs_from_jsonl(raw_dir / "cpcc_catalog.jsonl")
    targets = set(ALLOWLIST) | discovered

    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT
    seen_sha: set[str] = set()

    with out_path.open("w", encoding="utf-8") as fp:
        for url in sorted(targets):
            try:
                resp = session.get(url, timeout=30)
            except requests.RequestException:
                continue
            if resp.status_code != 200:
                continue
            data = resp.content
            sha = hashlib.sha256(data).hexdigest()
            if sha in seen_sha:
                continue
            seen_sha.add(sha)

            tmp = raw_dir / f"{sha}.pdf"
            tmp.write_bytes(data)
            try:
                with pdfplumber.open(tmp) as pdf:
                    text = "\n\n".join(page.extract_text() or "" for page in pdf.pages)
            except Exception:
                tmp.unlink(missing_ok=True)
                continue
            tmp.unlink(missing_ok=True)
            if not text.strip():
                continue
            fp.write(json.dumps({
                "url": url, "title": Path(urlparse(url).path).name,
                "text": text, "sha256": sha,
            }) + "\n")

    return out_path


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, default=Path("pipeline/raw"))
    args = parser.parse_args()
    out = crawl(args.raw)
    print(f"Wrote {out}")
