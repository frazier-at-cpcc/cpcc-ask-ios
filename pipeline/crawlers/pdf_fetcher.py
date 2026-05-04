"""Fetch + extract text from an explicit PDF allowlist.

Each PDF becomes one Record whose markdown is `# {title}\n\n{text}`. Same
output type as html_crawler.Record so downstream code is uniform.
"""
from __future__ import annotations

import hashlib
import io
import sys
from dataclasses import dataclass
from typing import Callable, Iterable

import httpx
import pdfplumber


@dataclass
class Record:
    url: str
    title: str
    markdown: str
    sha256: str


def _default_fetcher(url: str) -> bytes:
    resp = httpx.get(url, timeout=60, follow_redirects=True,
                     headers={"User-Agent": "AskCPCC-Pipeline/0.2"})
    resp.raise_for_status()
    return resp.content


def extract_pdf_text(pdf_bytes: bytes) -> str:
    """Extract text from PDF bytes. Returns '' on parse failure."""
    try:
        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            pages = [page.extract_text() or "" for page in pdf.pages]
        return "\n\n".join(pages).strip()
    except Exception:
        # pdfplumber can raise a wide variety of low-level exceptions on
        # malformed input — we treat all of them as "this PDF is unusable,
        # skip it" rather than enumerating them.
        return ""


def fetch_all(allowlist: Iterable[dict],
              fetcher: Callable[[str], bytes] = _default_fetcher) -> list[Record]:
    """Fetch each allowlisted PDF, extract text, return Records.

    allowlist entries must have 'url' and 'title' keys. Failed fetches and
    PDFs with no extractable text are skipped silently (logged to stderr).
    """
    records: list[Record] = []
    for entry in allowlist:
        url = entry["url"]
        title = entry["title"]
        try:
            data = fetcher(url)
        except (httpx.HTTPError, OSError, RuntimeError) as exc:
            # Network/IO failures and the test's RuntimeError are expected;
            # anything else (programming errors, KeyboardInterrupt) propagates.
            print(f"pdf_fetcher.fetch_all: skip {url}: {exc}", file=sys.stderr)
            continue
        text = extract_pdf_text(data)
        if not text:
            print(f"pdf_fetcher.fetch_all: skip {url}: no extractable text",
                  file=sys.stderr)
            continue
        markdown = f"# {title}\n\n{text}"
        sha = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
        records.append(Record(url=url, title=title, markdown=markdown, sha256=sha))
    return records
