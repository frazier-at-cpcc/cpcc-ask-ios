"""Crawler for catalog.cpcc.edu."""
from __future__ import annotations

import json
import time
import hashlib
from pathlib import Path
from urllib.parse import urljoin, urlparse, urldefrag

import requests
from bs4 import BeautifulSoup

USER_AGENT = "AskCPCC-Pipeline/0.1 (+https://github.com/Frazier-at-CPCC/cpcc-ask-ios)"
BASE = "https://catalog.cpcc.edu"
ALLOWED_HOST = "catalog.cpcc.edu"
SKIP_EXTENSIONS = (".jpg", ".jpeg", ".png", ".gif", ".zip", ".docx", ".xlsx")
MAX_PAGES = 1500
THROTTLE_SECONDS = 1.0


def crawl(out_dir: Path, max_pages: int = MAX_PAGES) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "cpcc_catalog.jsonl"

    visited: set[str] = set()
    queue: list[str] = [BASE + "/"]
    session = requests.Session()
    session.headers["User-Agent"] = USER_AGENT

    with out_path.open("w", encoding="utf-8") as fp:
        while queue and len(visited) < max_pages:
            url = queue.pop(0)
            url, _ = urldefrag(url)
            if url in visited:
                continue
            visited.add(url)

            parsed = urlparse(url)
            if parsed.netloc != ALLOWED_HOST:
                continue
            if any(parsed.path.lower().endswith(e) for e in SKIP_EXTENSIONS):
                continue

            try:
                resp = session.get(url, timeout=20)
            except requests.RequestException:
                continue
            time.sleep(THROTTLE_SECONDS)
            if resp.status_code != 200 or "text/html" not in resp.headers.get("Content-Type", ""):
                continue

            html = resp.text
            soup = BeautifulSoup(html, "html.parser")
            title_tag = soup.find("title")
            title = title_tag.get_text(strip=True) if title_tag else ""
            sha = hashlib.sha256(html.encode("utf-8")).hexdigest()
            fp.write(json.dumps({"url": url, "title": title, "html": html, "sha256": sha}) + "\n")

            for a in soup.find_all("a", href=True):
                href = urljoin(url, a["href"])
                href, _ = urldefrag(href)
                if href not in visited:
                    queue.append(href)

    return out_path


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("pipeline/raw"))
    parser.add_argument("--max-pages", type=int, default=MAX_PAGES)
    args = parser.parse_args()
    out = crawl(args.out, max_pages=args.max_pages)
    print(f"Wrote {out}")
