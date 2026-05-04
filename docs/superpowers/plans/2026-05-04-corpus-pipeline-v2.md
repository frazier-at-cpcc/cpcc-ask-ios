# Corpus Pipeline v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the BFS-based corpus crawlers with a sitemap-driven pipeline using crawl4ai for clean markdown extraction and an explicit YAML-driven PDF allowlist, eliminating archive-PDF leakage at the source.

**Architecture:** `sources.yaml` declares two HTML sitemaps (`www.cpcc.edu`, `catalog.cpcc.edu`) and a flat PDF allowlist. Three new crawler modules (`sitemap.py`, `html_crawler.py`, `pdf_fetcher.py`) feed a single JSONL with a `markdown` field. Chunker, embedder, writer, and upload step keep their roles; only the chunker is modified (reads markdown, splits on headings).

**Tech Stack:** Python 3.11, crawl4ai (Playwright/Chromium), httpx, PyYAML, pdfplumber (existing), sentence-transformers (existing), pytest.

**Working directory:** `/Users/frazier/Developer/cpcc-ask-ios`. Branch: `feat/corpus-pipeline-v2`.

**Spec:** `docs/superpowers/specs/2026-05-04-corpus-pipeline-v2-design.md`

---

## Task 1: Branch + dependency scaffold

**Files:**
- Create: `feat/corpus-pipeline-v2` branch
- Modify: `pipeline/requirements.txt`
- Create: `pipeline/sources.yaml` (skeleton)

- [ ] **Step 1: Create feature branch**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
git checkout main
git pull --ff-only
git checkout -b feat/corpus-pipeline-v2
```

- [ ] **Step 2: Update `pipeline/requirements.txt`**

Replace contents with:

```
crawl4ai>=0.4
httpx>=0.27
PyYAML>=6.0
pdfplumber>=0.11
sentence-transformers>=2.7
torch>=2.2
tqdm>=4.66
pytest>=8.0
```

(Dropped `beautifulsoup4` and `requests` — old crawlers will be deleted in Task 8.)

- [ ] **Step 3: Install dependencies + Playwright browsers**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios/pipeline
python -m pip install -e .
crawl4ai-setup
```

Expected: `crawl4ai-setup` reports "Setup complete" and Chromium is installed under `~/Library/Caches/ms-playwright/`.

- [ ] **Step 4: Create `pipeline/sources.yaml` skeleton**

Write `pipeline/sources.yaml`:

```yaml
# Declarative source configuration for the corpus pipeline.
# See docs/superpowers/specs/2026-05-04-corpus-pipeline-v2-design.md.

main:
  sitemap: "https://www.cpcc.edu/sitemap.xml"
  exclude_patterns:
    - "/news/"
    - "/events/"
    - "/calendar/"
    - "/sites/.*\\.pdf$"
  max_pages: 2000

catalog:
  sitemap: "https://catalog.cpcc.edu/sitemap.xml"
  exclude_patterns:
    - "/archives?/"
    - "(19|20)\\d{2}([-_]\\d{2,4})?\\.pdf$"
  max_pages: 1500

pdfs:
  # Populated in Task 2 after manual research.
  allowlist: []
```

- [ ] **Step 5: Commit**

```bash
git add pipeline/requirements.txt pipeline/sources.yaml
git commit -m "feat(pipeline): scaffold v2 deps and sources.yaml"
```

---

## Task 2: Research and populate PDF allowlist

**This is a manual research task, not TDD.** No code is written.

**Files:**
- Modify: `pipeline/sources.yaml`

- [ ] **Step 1: Verify both sitemaps actually exist**

```bash
curl -sSI https://www.cpcc.edu/sitemap.xml | head -1
curl -sSI https://catalog.cpcc.edu/sitemap.xml | head -1
```

Expected: both return `HTTP/2 200`. If either returns 404, **stop and notify the user** — design needs to fall back to a hand-curated seed-URL list for that source. Update `sources.yaml` accordingly before proceeding.

- [ ] **Step 2: Audit `www.cpcc.edu` for current published PDFs**

Manually visit and identify the canonical, current versions of:

- Student Handbook
- Academic Calendar (current academic year)
- FERPA Notice
- Title IX / Sexual Misconduct Policy
- Code of Student Conduct
- Board of Trustees Policy Manual (or equivalent)
- Tuition & Fees schedule
- Drug-free schools notification

For each, copy the canonical URL and the official document title. Verify the PDF actually loads (some links 404).

- [ ] **Step 3: Update `pipeline/sources.yaml` `pdfs.allowlist`**

Replace `allowlist: []` with the populated list. Each entry must have `url` and `title`. Example structure:

```yaml
pdfs:
  allowlist:
    - url: "https://www.cpcc.edu/sites/default/files/<actual-path>/student-handbook-2026-2027.pdf"
      title: "Student Handbook 2026–2027"
    - url: "https://www.cpcc.edu/sites/default/files/<actual-path>/academic-calendar-2026-2027.pdf"
      title: "Academic Calendar 2026–2027"
    # … 6–12 entries total
```

- [ ] **Step 4: Commit**

```bash
git add pipeline/sources.yaml
git commit -m "feat(pipeline): seed PDF allowlist for v2 corpus"
```

---

## Task 3: `sitemap.py` — sitemap parsing and URL loading

**Files:**
- Create: `pipeline/crawlers/sitemap.py`
- Create: `pipeline/tests/fixtures/sitemap_simple.xml`
- Create: `pipeline/tests/fixtures/sitemap_index.xml`
- Create: `pipeline/tests/fixtures/sitemap_child.xml`
- Create: `pipeline/tests/test_sitemap.py`

- [ ] **Step 1: Create simple sitemap fixture**

Write `pipeline/tests/fixtures/sitemap_simple.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.test/programs</loc></url>
  <url><loc>https://example.test/admissions</loc></url>
  <url><loc>https://example.test/news/2024/closure</loc></url>
  <url><loc>https://example.test/archives/2010-11.pdf</loc></url>
  <url><loc>https://example.test/calendar</loc></url>
</urlset>
```

- [ ] **Step 2: Create sitemap-index fixtures**

Write `pipeline/tests/fixtures/sitemap_index.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>https://example.test/sitemap-child.xml</loc></sitemap>
</sitemapindex>
```

Write `pipeline/tests/fixtures/sitemap_child.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.test/from-child-1</loc></url>
  <url><loc>https://example.test/from-child-2</loc></url>
</urlset>
```

- [ ] **Step 3: Write the failing tests**

Write `pipeline/tests/test_sitemap.py`:

```python
from pathlib import Path

import pytest

from pipeline.crawlers.sitemap import parse_sitemap_xml, load_urls


FIXTURE_DIR = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURE_DIR / name).read_text(encoding="utf-8")


def test_parse_simple_urlset_returns_locs():
    urls = parse_sitemap_xml(_read("sitemap_simple.xml"))
    assert urls == [
        "https://example.test/programs",
        "https://example.test/admissions",
        "https://example.test/news/2024/closure",
        "https://example.test/archives/2010-11.pdf",
        "https://example.test/calendar",
    ]


def test_parse_sitemap_index_returns_child_sitemap_urls():
    """A sitemap-index returns child sitemap URLs (caller recurses)."""
    urls = parse_sitemap_xml(_read("sitemap_index.xml"))
    assert urls == ["https://example.test/sitemap-child.xml"]


def test_load_urls_applies_exclude_patterns(tmp_path, monkeypatch):
    """Patterns drop matching URLs after recursion."""
    fetched: dict[str, str] = {
        "https://example.test/sitemap.xml": _read("sitemap_simple.xml"),
    }

    def fake_fetch(url: str) -> str:
        return fetched[url]

    monkeypatch.setattr("pipeline.crawlers.sitemap._fetch_text", fake_fetch)

    urls = load_urls(
        "https://example.test/sitemap.xml",
        exclude_patterns=[r"/news/", r"/archives/", r"/calendar"],
        max_pages=100,
    )
    assert urls == [
        "https://example.test/programs",
        "https://example.test/admissions",
    ]


def test_load_urls_recurses_sitemap_index(monkeypatch):
    fetched = {
        "https://example.test/sitemap.xml": (FIXTURE_DIR / "sitemap_index.xml").read_text(),
        "https://example.test/sitemap-child.xml": (FIXTURE_DIR / "sitemap_child.xml").read_text(),
    }

    monkeypatch.setattr(
        "pipeline.crawlers.sitemap._fetch_text",
        lambda url: fetched[url],
    )

    urls = load_urls(
        "https://example.test/sitemap.xml",
        exclude_patterns=[],
        max_pages=100,
    )
    assert urls == [
        "https://example.test/from-child-1",
        "https://example.test/from-child-2",
    ]


def test_load_urls_respects_max_pages(monkeypatch):
    monkeypatch.setattr(
        "pipeline.crawlers.sitemap._fetch_text",
        lambda url: (FIXTURE_DIR / "sitemap_simple.xml").read_text(),
    )
    urls = load_urls(
        "https://example.test/sitemap.xml",
        exclude_patterns=[],
        max_pages=2,
    )
    assert urls == [
        "https://example.test/programs",
        "https://example.test/admissions",
    ]
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
python -m pytest pipeline/tests/test_sitemap.py -v
```

Expected: collection error or `ModuleNotFoundError: No module named 'pipeline.crawlers.sitemap'`.

- [ ] **Step 5: Implement `pipeline/crawlers/sitemap.py`**

Write `pipeline/crawlers/sitemap.py`:

```python
"""Sitemap loader: fetches sitemap.xml(.gz), parses, recurses indexes,
applies exclude patterns, caps results at max_pages."""
from __future__ import annotations

import gzip
import re
from xml.etree import ElementTree as ET

import httpx

NS = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}


def _fetch_text(url: str) -> str:
    """Fetch a sitemap. Handles .xml.gz transparently."""
    resp = httpx.get(url, timeout=30, follow_redirects=True)
    resp.raise_for_status()
    if url.endswith(".gz") or resp.headers.get("Content-Type", "").startswith("application/gzip"):
        return gzip.decompress(resp.content).decode("utf-8")
    return resp.text


def parse_sitemap_xml(xml: str) -> list[str]:
    """Parse a sitemap or sitemap-index XML string into a list of URLs.

    For a <urlset>, returns each <url><loc>.
    For a <sitemapindex>, returns each <sitemap><loc> (caller is responsible
    for recursing).
    """
    root = ET.fromstring(xml)
    locs = root.findall(".//sm:loc", NS)
    return [loc.text.strip() for loc in locs if loc.text]


def _is_sitemap_index(xml: str) -> bool:
    return "<sitemapindex" in xml[:512]


def load_urls(sitemap_url: str, exclude_patterns: list[str],
              max_pages: int) -> list[str]:
    """Recursively load page URLs from a sitemap, dropping pattern matches.

    Returns at most max_pages URLs in document order.
    """
    compiled = [re.compile(p) for p in exclude_patterns]
    urls: list[str] = []
    queue: list[str] = [sitemap_url]
    visited: set[str] = set()

    while queue and len(urls) < max_pages:
        current = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)

        try:
            xml = _fetch_text(current)
        except Exception:
            continue

        if _is_sitemap_index(xml):
            queue.extend(parse_sitemap_xml(xml))
            continue

        for u in parse_sitemap_xml(xml):
            if any(rx.search(u) for rx in compiled):
                continue
            urls.append(u)
            if len(urls) >= max_pages:
                break

    return urls
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
python -m pytest pipeline/tests/test_sitemap.py -v
```

Expected: 5 passed.

- [ ] **Step 7: Commit**

```bash
git add pipeline/crawlers/sitemap.py pipeline/tests/test_sitemap.py pipeline/tests/fixtures/sitemap_simple.xml pipeline/tests/fixtures/sitemap_index.xml pipeline/tests/fixtures/sitemap_child.xml
git commit -m "feat(pipeline): sitemap loader with index recursion + exclude patterns"
```

---

## Task 4: `html_crawler.py` — markdown extraction from HTML

**Files:**
- Create: `pipeline/crawlers/html_crawler.py`
- Create: `pipeline/tests/fixtures/sample_page.html`
- Create: `pipeline/tests/test_html_crawler.py`

- [ ] **Step 1: Create sample HTML fixture**

Write `pipeline/tests/fixtures/sample_page.html`:

```html
<!DOCTYPE html>
<html>
<head><title>Programs of Study | Example College</title></head>
<body>
  <nav><a href="/">Home</a> <a href="/admissions">Admissions</a></nav>
  <header><h1>Site Header — should be stripped</h1></header>
  <main>
    <h1>Programs of Study</h1>
    <p>Example College offers more than 280 programs across business, health, technology, and the arts.</p>
    <h2>Information Technology</h2>
    <p>The IT division includes Cybersecurity, Software Development, and Network Engineering.</p>
    <h2>Health Sciences</h2>
    <p>Programs include Nursing, Medical Assisting, and Surgical Technology.</p>
  </main>
  <footer><p>Copyright Example College 2026</p></footer>
</body>
</html>
```

- [ ] **Step 2: Write the failing tests**

Write `pipeline/tests/test_html_crawler.py`:

```python
from pathlib import Path

from pipeline.crawlers.html_crawler import (
    Record,
    record_from_markdown,
    html_to_markdown,
)

FIXTURE_DIR = Path(__file__).parent / "fixtures"


def test_record_from_markdown_computes_sha256():
    rec = record_from_markdown(
        url="https://example.test/programs",
        title="Programs of Study",
        markdown="# Programs\n\nText here.",
    )
    assert isinstance(rec, Record)
    assert rec.url == "https://example.test/programs"
    assert rec.title == "Programs of Study"
    assert rec.markdown == "# Programs\n\nText here."
    assert len(rec.sha256) == 64  # SHA-256 hex


def test_record_from_markdown_is_deterministic():
    a = record_from_markdown("u", "t", "body")
    b = record_from_markdown("u", "t", "body")
    assert a.sha256 == b.sha256


def test_html_to_markdown_emits_headings_and_paragraphs():
    html = (FIXTURE_DIR / "sample_page.html").read_text(encoding="utf-8")
    md = html_to_markdown(html, base_url="https://example.test/programs")
    assert "Programs of Study" in md
    assert "Information Technology" in md
    assert "Cybersecurity" in md


def test_html_to_markdown_strips_navigation():
    """Boilerplate (nav links, footer copyright) should be filtered out."""
    html = (FIXTURE_DIR / "sample_page.html").read_text(encoding="utf-8")
    md = html_to_markdown(html, base_url="https://example.test/programs")
    assert "Copyright Example College 2026" not in md
    # Site header outside <main> should be filtered
    assert "Site Header — should be stripped" not in md


def test_html_to_markdown_returns_empty_for_empty_html():
    assert html_to_markdown("", base_url="https://example.test/") == ""
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
python -m pytest pipeline/tests/test_html_crawler.py -v
```

Expected: `ModuleNotFoundError: No module named 'pipeline.crawlers.html_crawler'`.

- [ ] **Step 4: Implement `pipeline/crawlers/html_crawler.py`**

Write `pipeline/crawlers/html_crawler.py`:

```python
"""crawl4ai-based HTML → markdown extractor.

Two layers:
  1. record_from_markdown / html_to_markdown — pure helpers, unit-testable.
  2. crawl(urls) — async function using AsyncWebCrawler (Playwright). Used in
     production; covered by smoke test only (requires Chromium + network).
"""
from __future__ import annotations

import asyncio
import hashlib
from dataclasses import dataclass

from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
from crawl4ai.markdown_generation_strategy import DefaultMarkdownGenerator
from crawl4ai.content_filter_strategy import PruningContentFilter


@dataclass
class Record:
    url: str
    title: str
    markdown: str
    sha256: str


def record_from_markdown(url: str, title: str, markdown: str) -> Record:
    sha = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
    return Record(url=url, title=title, markdown=markdown, sha256=sha)


def _markdown_generator() -> DefaultMarkdownGenerator:
    return DefaultMarkdownGenerator(
        content_filter=PruningContentFilter(threshold=0.48, threshold_type="fixed"),
    )


def html_to_markdown(html: str, base_url: str) -> str:
    """Run crawl4ai's markdown generator over a raw HTML string.

    Pure synchronous function — no browser, no network. Used by both the
    live crawler and unit tests so behaviour matches.
    """
    if not html.strip():
        return ""
    gen = _markdown_generator()
    res = gen.generate_markdown(input_html=html, base_url=base_url)
    # fit_markdown is the content-filter-pruned version; fall back to raw.
    fit = getattr(res, "fit_markdown", None)
    return (fit or res.raw_markdown or "").strip()


async def _crawl_async(urls: list[str]) -> list[Record]:
    config = CrawlerRunConfig(markdown_generator=_markdown_generator())
    records: list[Record] = []
    async with AsyncWebCrawler() as crawler:
        for url in urls:
            try:
                result = await crawler.arun(url=url, config=config)
            except Exception as exc:
                print(f"  skip {url}: {exc}")
                continue
            if not getattr(result, "success", False):
                continue
            md_obj = result.markdown
            md = (
                getattr(md_obj, "fit_markdown", None)
                or getattr(md_obj, "raw_markdown", None)
                or str(md_obj)
                or ""
            ).strip()
            if not md:
                continue
            title = ""
            if result.metadata:
                title = result.metadata.get("title", "") or ""
            records.append(record_from_markdown(url=url, title=title, markdown=md))
    return records


def crawl(urls: list[str]) -> list[Record]:
    """Sync wrapper over the async crawler. Returns Records for successful URLs."""
    return asyncio.run(_crawl_async(urls))
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
python -m pytest pipeline/tests/test_html_crawler.py -v
```

Expected: 5 passed.

If `test_html_to_markdown_strips_navigation` fails because the content filter doesn't strip the nav block, **adjust the filter threshold** (try `threshold=0.3`) and re-run. Document the chosen value in a code comment.

- [ ] **Step 6: Commit**

```bash
git add pipeline/crawlers/html_crawler.py pipeline/tests/test_html_crawler.py pipeline/tests/fixtures/sample_page.html
git commit -m "feat(pipeline): html crawler with crawl4ai markdown extraction"
```

---

## Task 5: `pdf_fetcher.py` — fetch + extract allowlisted PDFs

**Files:**
- Create: `pipeline/crawlers/pdf_fetcher.py`
- Create: `pipeline/tests/fixtures/sample.pdf` (small sample PDF)
- Create: `pipeline/tests/test_pdf_fetcher.py`

- [ ] **Step 1: Create a sample PDF fixture**

Use `reportlab` (install once: `pip install reportlab`):

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
python -c "
from reportlab.pdfgen import canvas
c = canvas.Canvas('pipeline/tests/fixtures/sample.pdf')
c.drawString(100, 750, 'Sample PDF Title')
c.drawString(100, 730, 'This is a test paragraph for the corpus pipeline.')
c.drawString(100, 710, 'Multiple lines of text are extracted page-by-page.')
c.save()
print('wrote pipeline/tests/fixtures/sample.pdf')
"
```

Alternatively, drop any small existing PDF (≤50 KB, with extractable text) at `pipeline/tests/fixtures/sample.pdf` and adjust the test assertions in step 2 to match its content.

- [ ] **Step 2: Write the failing tests**

Write `pipeline/tests/test_pdf_fetcher.py`:

```python
from pathlib import Path

import pytest

from pipeline.crawlers.pdf_fetcher import (
    Record,
    extract_pdf_text,
    fetch_all,
)

FIXTURE = Path(__file__).parent / "fixtures" / "sample.pdf"


def test_extract_pdf_text_reads_text():
    text = extract_pdf_text(FIXTURE.read_bytes())
    assert "Sample PDF Title" in text
    assert "test paragraph" in text


def test_extract_pdf_text_returns_empty_for_corrupt_bytes():
    assert extract_pdf_text(b"not a pdf") == ""


def test_fetch_all_uses_provided_fetcher_and_returns_records():
    """fetch_all is dependency-injected with a fetcher to keep tests offline."""
    pdf_bytes = FIXTURE.read_bytes()

    def fake_fetch(url: str) -> bytes:
        assert url == "https://example.test/handbook.pdf"
        return pdf_bytes

    records = fetch_all(
        allowlist=[
            {"url": "https://example.test/handbook.pdf", "title": "Handbook"},
        ],
        fetcher=fake_fetch,
    )
    assert len(records) == 1
    rec = records[0]
    assert isinstance(rec, Record)
    assert rec.url == "https://example.test/handbook.pdf"
    assert rec.title == "Handbook"
    assert rec.markdown.startswith("# Handbook")
    assert "test paragraph" in rec.markdown
    assert len(rec.sha256) == 64


def test_fetch_all_skips_failed_fetches():
    def fail_fetch(url: str) -> bytes:
        raise RuntimeError("boom")

    records = fetch_all(
        allowlist=[{"url": "https://example.test/x.pdf", "title": "X"}],
        fetcher=fail_fetch,
    )
    assert records == []
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
python -m pytest pipeline/tests/test_pdf_fetcher.py -v
```

Expected: `ModuleNotFoundError`.

- [ ] **Step 4: Implement `pipeline/crawlers/pdf_fetcher.py`**

Write `pipeline/crawlers/pdf_fetcher.py`:

```python
"""Fetch + extract text from an explicit PDF allowlist.

Each PDF becomes one Record whose markdown is `# {title}\n\n{text}`. Same
output type as html_crawler.Record so downstream code is uniform.
"""
from __future__ import annotations

import hashlib
import io
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
        return ""


def fetch_all(allowlist: Iterable[dict],
              fetcher: Callable[[str], bytes] = _default_fetcher) -> list[Record]:
    """Fetch each allowlisted PDF, extract text, return Records.

    allowlist entries must have 'url' and 'title' keys. Failed fetches and
    PDFs with no extractable text are skipped silently.
    """
    records: list[Record] = []
    for entry in allowlist:
        url = entry["url"]
        title = entry["title"]
        try:
            data = fetcher(url)
        except Exception as exc:
            print(f"  skip {url}: {exc}")
            continue
        text = extract_pdf_text(data)
        if not text:
            continue
        markdown = f"# {title}\n\n{text}"
        sha = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
        records.append(Record(url=url, title=title, markdown=markdown, sha256=sha))
    return records
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
python -m pytest pipeline/tests/test_pdf_fetcher.py -v
```

Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
git add pipeline/crawlers/pdf_fetcher.py pipeline/tests/test_pdf_fetcher.py pipeline/tests/fixtures/sample.pdf
git commit -m "feat(pipeline): pdf fetcher with explicit allowlist"
```

---

## Task 6: Update `chunker.py` for markdown-aware splitting

The existing `chunk_text` works on arbitrary text. We're adding a markdown-aware wrapper that prefers heading boundaries (`#`, `##`, `###`) before falling back to size-based splits.

**Files:**
- Modify: `pipeline/chunker.py`
- Modify: `pipeline/tests/test_chunker.py`

- [ ] **Step 1: Write the failing tests**

Append to `pipeline/tests/test_chunker.py`:

```python
from pipeline.chunker import chunk_markdown


def test_chunk_markdown_splits_on_h2():
    md = "# Title\n\nIntro paragraph.\n\n## Section A\n\n" + ("A. " * 200) + "\n\n## Section B\n\n" + ("B. " * 200)
    chunks = chunk_markdown(md, max_chars=600, overlap=100)
    # Section A and B should not be glued together
    a_chunks = [c for c in chunks if "A. " in c and "B. " not in c]
    b_chunks = [c for c in chunks if "B. " in c and "A. " not in c]
    assert a_chunks, "expected section A chunks"
    assert b_chunks, "expected section B chunks"


def test_chunk_markdown_preserves_short_section_in_one_chunk():
    md = "# Title\n\nShort.\n\n## Heading\n\nAnother short paragraph."
    chunks = chunk_markdown(md, max_chars=600, overlap=100)
    assert len(chunks) == 1
    assert "Short." in chunks[0]
    assert "Another short paragraph." in chunks[0]


def test_chunk_markdown_falls_back_to_size_split_within_long_section():
    """A single section longer than max_chars uses chunk_text size splits."""
    long_section = "# Title\n\n" + ("Repeated. " * 200)
    chunks = chunk_markdown(long_section, max_chars=600, overlap=100)
    assert len(chunks) >= 2
    assert all(len(c) <= 600 for c in chunks)


def test_chunk_markdown_empty_input_returns_empty_list():
    assert chunk_markdown("", max_chars=600, overlap=100) == []
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python -m pytest pipeline/tests/test_chunker.py -v
```

Expected: 4 new tests fail with `ImportError: cannot import name 'chunk_markdown'`.

- [ ] **Step 3: Implement `chunk_markdown` in `pipeline/chunker.py`**

Append to `pipeline/chunker.py`:

```python
import re

# Splits at the start of any line beginning with #, ##, or ### (ATX headings).
_HEADING_SPLIT = re.compile(r"(?m)^(?=#{1,3}\s)")


def chunk_markdown(markdown: str, max_chars: int = 600, overlap: int = 100,
                   min_chunk_chars: int = 200) -> list[str]:
    """Markdown-aware chunker.

    Splits on heading boundaries (#, ##, ###) into sections, then runs each
    section through chunk_text. Short adjacent sections are merged together
    rather than emitted as microchunks.
    """
    markdown = markdown.strip()
    if not markdown:
        return []

    sections = [s.strip() for s in _HEADING_SPLIT.split(markdown) if s.strip()]
    if not sections:
        return chunk_text(markdown, max_chars=max_chars, overlap=overlap,
                          min_chunk_chars=min_chunk_chars)

    chunks: list[str] = []
    buffer = ""
    for section in sections:
        if len(buffer) + len(section) + 2 <= max_chars:
            buffer = (buffer + "\n\n" + section).strip()
            continue
        if buffer:
            chunks.extend(chunk_text(buffer, max_chars=max_chars, overlap=overlap,
                                     min_chunk_chars=min_chunk_chars))
            buffer = ""
        if len(section) <= max_chars:
            buffer = section
        else:
            chunks.extend(chunk_text(section, max_chars=max_chars, overlap=overlap,
                                     min_chunk_chars=min_chunk_chars))
    if buffer:
        chunks.extend(chunk_text(buffer, max_chars=max_chars, overlap=overlap,
                                 min_chunk_chars=min_chunk_chars))
    return chunks
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
python -m pytest pipeline/tests/test_chunker.py -v
```

Expected: all chunker tests pass (existing + 4 new).

- [ ] **Step 5: Commit**

```bash
git add pipeline/chunker.py pipeline/tests/test_chunker.py
git commit -m "feat(pipeline): chunk_markdown with heading-aware splits"
```

---

## Task 7: Rewrite `build_corpus.py` for v2 sources

**Files:**
- Modify: `pipeline/build_corpus.py` (rewrite — keep only embed/write stages)

- [ ] **Step 1: Replace `pipeline/build_corpus.py`**

Overwrite with:

```python
"""End-to-end v2: sources.yaml → sitemap+crawl → PDFs → markdown JSONL → chunk → embed → write."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date
from pathlib import Path

import yaml

from pipeline.chunker import chunk_markdown
from pipeline.crawlers import sitemap, html_crawler, pdf_fetcher
from pipeline.embedder import load_model, embed
from pipeline.writer import write_corpus


def load_sources(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def write_jsonl(path: Path, records) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fp:
        for r in records:
            fp.write(json.dumps({
                "url": r.url,
                "title": r.title,
                "markdown": r.markdown,
                "sha256": r.sha256,
            }) + "\n")


def build(sources_path: Path, raw_dir: Path, out_dir: Path,
          version: str | None = None) -> None:
    sources = load_sources(sources_path)

    print("Stage 1: discover URLs from sitemaps")
    main_cfg = sources["main"]
    main_urls = sitemap.load_urls(
        main_cfg["sitemap"], main_cfg.get("exclude_patterns", []),
        max_pages=main_cfg.get("max_pages", 2000),
    )
    print(f"  www.cpcc.edu: {len(main_urls)} URLs")

    catalog_cfg = sources["catalog"]
    catalog_urls = sitemap.load_urls(
        catalog_cfg["sitemap"], catalog_cfg.get("exclude_patterns", []),
        max_pages=catalog_cfg.get("max_pages", 1500),
    )
    print(f"  catalog.cpcc.edu: {len(catalog_urls)} URLs")

    print("Stage 2: crawl HTML pages")
    main_records = html_crawler.crawl(main_urls)
    catalog_records = html_crawler.crawl(catalog_urls)

    print("Stage 3: fetch allowlisted PDFs")
    pdf_records = pdf_fetcher.fetch_all(sources.get("pdfs", {}).get("allowlist", []))
    print(f"  pdfs: {len(pdf_records)}")

    raw_dir.mkdir(parents=True, exist_ok=True)
    write_jsonl(raw_dir / "main.jsonl", main_records)
    write_jsonl(raw_dir / "catalog.jsonl", catalog_records)
    write_jsonl(raw_dir / "pdfs.jsonl", pdf_records)

    print("Stage 4: chunk + dedup")
    chunks: list[dict] = []
    seen_texts: set[str] = set()
    counts = {"www.cpcc.edu": 0, "catalog.cpcc.edu": 0, "pdfs": 0}

    def add_chunks(records, label: str) -> None:
        for r in records:
            for piece in chunk_markdown(r.markdown):
                if piece in seen_texts:
                    continue
                seen_texts.add(piece)
                chunks.append({
                    "source_url": r.url, "title": r.title, "text": piece,
                    "char_offset": 0, "page_section": "",
                })
            counts[label] += 1

    add_chunks(main_records, "www.cpcc.edu")
    add_chunks(catalog_records, "catalog.cpcc.edu")
    add_chunks(pdf_records, "pdfs")

    print(f"  total chunks: {len(chunks)} (deduped)")

    print("Stage 5: embed")
    model = load_model()
    vecs = embed(model, [c["text"] for c in chunks])

    print("Stage 6: write")
    v = version or date.today().isoformat()
    write_corpus(out_dir, chunks, vecs, counts, version=v)
    print(f"Wrote corpus version {v} to {out_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=Path, default=Path("pipeline/sources.yaml"))
    parser.add_argument("--raw", type=Path, default=Path("pipeline/raw"))
    parser.add_argument("--out", type=Path, default=Path("pipeline/out"))
    parser.add_argument("--version", type=str, default=None)
    args = parser.parse_args()
    build(args.sources, args.raw, args.out, args.version)
```

- [ ] **Step 2: Verify imports resolve (no runtime call yet)**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
python -c "from pipeline.build_corpus import build, load_sources, write_jsonl; print('imports ok')"
```

Expected: `imports ok`. If you get a `ModuleNotFoundError`, fix the path/name and re-run.

- [ ] **Step 3: Commit**

```bash
git add pipeline/build_corpus.py
git commit -m "feat(pipeline): rewrite build_corpus for sources.yaml + markdown JSONL"
```

---

## Task 8: Delete the old crawlers

**Files:**
- Delete: `pipeline/crawlers/cpcc_main.py`
- Delete: `pipeline/crawlers/cpcc_catalog.py`
- Delete: `pipeline/crawlers/cpcc_pdfs.py`
- Modify: `pipeline/crawlers/__init__.py` (drop old imports if any)

- [ ] **Step 1: Inspect `pipeline/crawlers/__init__.py`**

```bash
cat /Users/frazier/Developer/cpcc-ask-ios/pipeline/crawlers/__init__.py
```

If it imports `cpcc_main`, `cpcc_catalog`, or `cpcc_pdfs`, remove those lines. Replace with imports of the new modules if the file currently re-exports symbols, otherwise leave empty:

```python
"""Crawler modules for the corpus pipeline v2."""
from . import sitemap, html_crawler, pdf_fetcher  # noqa: F401
```

- [ ] **Step 2: Delete old crawler files**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
rm pipeline/crawlers/cpcc_main.py
rm pipeline/crawlers/cpcc_catalog.py
rm pipeline/crawlers/cpcc_pdfs.py
```

- [ ] **Step 3: Verify no stale imports**

```bash
grep -rn "cpcc_main\|cpcc_catalog\|cpcc_pdfs" pipeline/ tests/ 2>/dev/null
```

Expected: no output. If any import remains, fix it before continuing.

- [ ] **Step 4: Run the full test suite**

```bash
python -m pytest pipeline/tests/ -v
```

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add pipeline/crawlers/__init__.py
git rm pipeline/crawlers/cpcc_main.py pipeline/crawlers/cpcc_catalog.py pipeline/crawlers/cpcc_pdfs.py
git commit -m "refactor(pipeline): remove v1 BFS crawlers"
```

---

## Task 9: End-to-end smoke test

**Files:**
- Create: `pipeline/tests/test_build_corpus_smoke.py`

This validates that the v2 modules wire together correctly end-to-end on hermetic fixtures, and asserts no archive URLs slip through.

- [ ] **Step 1: Write the failing smoke test**

Write `pipeline/tests/test_build_corpus_smoke.py`:

```python
"""End-to-end smoke test for build_corpus.

Patches sitemap._fetch_text and html_crawler.crawl with fixture-backed fakes
so the full pipeline runs without network or Chromium.
"""
from __future__ import annotations

import re
from pathlib import Path

import yaml

from pipeline import build_corpus
from pipeline.crawlers import html_crawler, pdf_fetcher, sitemap


FIXTURE_DIR = Path(__file__).parent / "fixtures"


def test_smoke_no_archive_urls_in_corpus(tmp_path, monkeypatch):
    sources_path = tmp_path / "sources.yaml"
    sources_path.write_text(yaml.safe_dump({
        "main": {
            "sitemap": "https://example.test/main.xml",
            "exclude_patterns": ["/archives/"],
            "max_pages": 100,
        },
        "catalog": {
            "sitemap": "https://example.test/catalog.xml",
            "exclude_patterns": ["/archives/"],
            "max_pages": 100,
        },
        "pdfs": {
            "allowlist": [
                {"url": "https://example.test/handbook.pdf", "title": "Handbook"},
            ],
        },
    }), encoding="utf-8")

    sitemap_xml = """<?xml version='1.0' encoding='UTF-8'?>
<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>
  <url><loc>https://example.test/programs</loc></url>
  <url><loc>https://example.test/archives/2010-11.pdf</loc></url>
</urlset>"""
    monkeypatch.setattr(sitemap, "_fetch_text", lambda url: sitemap_xml)

    def fake_crawl(urls):
        return [
            html_crawler.record_from_markdown(
                url=u, title="Programs", markdown="# Programs\n\nIT, Health, Business.",
            )
            for u in urls
        ]

    monkeypatch.setattr(html_crawler, "crawl", fake_crawl)

    pdf_bytes = (FIXTURE_DIR / "sample.pdf").read_bytes()
    monkeypatch.setattr(pdf_fetcher, "_default_fetcher", lambda url: pdf_bytes)

    raw_dir = tmp_path / "raw"
    out_dir = tmp_path / "out"
    build_corpus.build(sources_path, raw_dir, out_dir, version="test-1")

    # Sanity: corpus.sqlite written
    assert (out_dir / "corpus.sqlite").exists() or any(
        p.name.startswith("corpus") for p in out_dir.iterdir()
    ), f"no corpus artifact in {out_dir}: {list(out_dir.iterdir())}"

    # The strict invariant: no chunk should reference an archive URL.
    main_jsonl = (raw_dir / "main.jsonl").read_text(encoding="utf-8")
    catalog_jsonl = (raw_dir / "catalog.jsonl").read_text(encoding="utf-8")
    pdfs_jsonl = (raw_dir / "pdfs.jsonl").read_text(encoding="utf-8")
    archive_pattern = re.compile(r"/archives?/|(19|20)\d{2}([-_]\d{2,4})?\.pdf")
    assert not archive_pattern.search(main_jsonl)
    assert not archive_pattern.search(catalog_jsonl)
    # pdfs_jsonl is allowed to be empty if extraction failed; if non-empty, no archives.
    assert not archive_pattern.search(pdfs_jsonl) or "handbook.pdf" in pdfs_jsonl
```

- [ ] **Step 2: Run the test**

```bash
python -m pytest pipeline/tests/test_build_corpus_smoke.py -v
```

If the test reveals issues with `embed()` requiring downloaded model weights or `write_corpus()` requiring a specific layout, **fix them in the smoke test** by using minimal fakes (e.g., `monkeypatch.setattr(build_corpus, "load_model", lambda: None)` and a fake `embed` returning `[[0.0]] * len(texts)` if needed). The goal is "components wire together," not "embedding model loads."

Expected: PASS once any fakes are in place.

- [ ] **Step 3: Commit**

```bash
git add pipeline/tests/test_build_corpus_smoke.py
git commit -m "test(pipeline): end-to-end smoke test asserts no archive URLs"
```

---

## Task 10: `verify_corpus.py` developer tool

**Files:**
- Create: `pipeline/scripts/__init__.py`
- Create: `pipeline/scripts/verify_corpus.py`

This is a manual gate, not a CI test. It runs known-bad-citation queries from the May 4 screenshots and prints top-3 sources for eyeballing.

- [ ] **Step 1: Create the script**

Write `pipeline/scripts/__init__.py`:

```python
```

Write `pipeline/scripts/verify_corpus.py`:

```python
"""Developer tool: runs known-bad-citation queries against a freshly-built corpus
and prints top-3 sources per query.

Not run in CI. Use after `build_corpus.py` finishes locally to eyeball quality
before opening a PR.

Usage:
    python -m pipeline.scripts.verify_corpus --out pipeline/out
"""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

from pipeline.embedder import load_model, embed

KNOWN_BAD_QUERIES = [
    "what nursing programs does CPCC offer",
    "what IT degree options are there",
    "which sections of CTI-120 have seats available this fall",
    "where is the campus located",
    "tuition cost",
    "academic calendar fall 2026",
    "FERPA student records",
    "code of conduct",
    "computer science associate degree",
    "financial aid deadlines",
]


def topk(corpus_path: Path, query_vec: list[float], k: int = 3) -> list[tuple[str, float]]:
    """Brute-force cosine-similarity top-k. Slow but adequate for verification."""
    import numpy as np
    conn = sqlite3.connect(corpus_path)
    cur = conn.execute("SELECT source_url, embedding FROM chunks")
    rows = cur.fetchall()
    qv = np.asarray(query_vec, dtype=np.float32)
    qn = qv / (np.linalg.norm(qv) + 1e-12)
    scored: list[tuple[str, float]] = []
    for url, blob in rows:
        v = np.frombuffer(blob, dtype=np.float32)
        score = float(np.dot(qn, v / (np.linalg.norm(v) + 1e-12)))
        scored.append((url, score))
    scored.sort(key=lambda t: t[1], reverse=True)
    return scored[:k]


def main(out_dir: Path) -> None:
    corpus_path = out_dir / "corpus.sqlite"
    if not corpus_path.exists():
        # Fallback: pick the first corpus*.sqlite in out_dir
        candidates = sorted(out_dir.glob("corpus*.sqlite"))
        if not candidates:
            raise SystemExit(f"No corpus.sqlite in {out_dir}")
        corpus_path = candidates[0]

    model = load_model()
    for q in KNOWN_BAD_QUERIES:
        qv = embed(model, [q])[0]
        hits = topk(corpus_path, list(qv), k=3)
        print(f"\nQ: {q}")
        for url, score in hits:
            flag = "  ARCHIVE" if "/archives/" in url or "/archive/" in url else ""
            print(f"  [{score:.3f}] {url}{flag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("pipeline/out"))
    args = parser.parse_args()
    main(args.out)
```

If the actual schema in `corpus.sqlite` differs (column names, embedding storage format), adjust the SQL/numpy code in `topk()`. Confirm the schema by reading `pipeline/writer.py` first.

- [ ] **Step 2: Confirm `pipeline/writer.py` schema matches the SQL**

```bash
grep -n "CREATE TABLE\|INSERT INTO\|embedding" /Users/frazier/Developer/cpcc-ask-ios/pipeline/writer.py
```

Adjust `verify_corpus.py` if column names differ. Common variations: `embedding` vs `vector` vs `vec`; `BLOB` vs `numpy bytes`. Match what `writer.py` actually writes.

- [ ] **Step 3: Commit**

```bash
git add pipeline/scripts/__init__.py pipeline/scripts/verify_corpus.py
git commit -m "feat(pipeline): verify_corpus developer tool for manual quality gate"
```

---

## Task 11: Update CI workflow

**Files:**
- Modify: `.github/workflows/refresh-corpus.yml`

- [ ] **Step 1: Edit the workflow**

Replace `.github/workflows/refresh-corpus.yml` with:

```yaml
name: Refresh corpus

on:
  schedule:
    - cron: "0 10 * * 1"  # Mondays 10:00 UTC = 06:00 ET
  workflow_dispatch: {}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Cache Playwright browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ runner.os }}-chromium-v1

      - name: Install pipeline
        working-directory: pipeline
        run: |
          python -m pip install --upgrade pip
          pip install -e .

      - name: Install Playwright browsers (Chromium only)
        run: |
          python -m playwright install --with-deps chromium

      - name: Run pipeline tests
        run: |
          python -m pytest pipeline/tests/ -v

      - name: Build corpus
        run: |
          python -m pipeline.build_corpus \
            --sources pipeline/sources.yaml \
            --raw pipeline/raw \
            --out pipeline/out \
            --version "$(date +%Y-%m-%d)"

      - name: Publish release + update latest.json
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          python -m pipeline.upload_release --out pipeline/out --version "$(date +%Y-%m-%d)" --repo-root .

      - name: Open PR for latest.json
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          BR="chore/refresh-corpus-$(date +%Y-%m-%d)"
          git config user.name "askcpcc-bot"
          git config user.email "askcpcc-bot@users.noreply.github.com"
          git checkout -b "$BR"
          git add latest.json
          git commit -m "chore: refresh corpus $(date +%Y-%m-%d)"
          git push -u origin "$BR"
          gh pr create --title "chore: refresh corpus $(date +%Y-%m-%d)" \
                       --body "Automated weekly corpus refresh." \
                       --base main --head "$BR"
```

- [ ] **Step 2: Validate the YAML locally**

```bash
python -c "import yaml; yaml.safe_load(open('.github/workflows/refresh-corpus.yml'))"
```

Expected: no output (parse OK).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/refresh-corpus.yml
git commit -m "ci: install Playwright browsers + run pipeline tests in refresh-corpus"
```

---

## Task 12: Update documentation

**Files:**
- Modify: `pipeline/README.md`
- Modify: `docs/BUILD_PIPELINE.md`

- [ ] **Step 1: Update `pipeline/README.md`**

Read the current file:

```bash
cat /Users/frazier/Developer/cpcc-ask-ios/pipeline/README.md
```

Rewrite or amend it to document:
- The new `sources.yaml` configuration model.
- The three modules under `pipeline/crawlers/` and what each does.
- How to run locally: `crawl4ai-setup` + `python -m pipeline.build_corpus`.
- How to add a PDF to the allowlist (edit YAML, commit, weekly cron picks it up).
- Pointer to `pipeline/scripts/verify_corpus.py` for quality verification.

- [ ] **Step 2: Update `docs/BUILD_PIPELINE.md`**

Read and update:

```bash
cat /Users/frazier/Developer/cpcc-ask-ios/docs/BUILD_PIPELINE.md
```

Replace any reference to `cpcc_main.py` / `cpcc_catalog.py` / `cpcc_pdfs.py` with the new module names, and update the data-flow diagram to reflect markdown JSONL instead of HTML JSONL.

- [ ] **Step 3: Commit**

```bash
git add pipeline/README.md docs/BUILD_PIPELINE.md
git commit -m "docs: update pipeline README + BUILD_PIPELINE for v2"
```

---

## Task 13: Local end-to-end run + manual verification gate

**This is the quality gate before merge.** No code is written; this is a verification step.

- [ ] **Step 1: Clean any prior raw output**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
rm -rf pipeline/raw pipeline/out
```

- [ ] **Step 2: Run the full v2 pipeline**

```bash
python -m pipeline.build_corpus \
  --sources pipeline/sources.yaml \
  --raw pipeline/raw \
  --out pipeline/out \
  --version "v2-local-$(date +%Y%m%d)"
```

Expected output ends with:
```
Stage 6: write
Wrote corpus version v2-local-... to pipeline/out
```

Wall-clock: 10–30 min (Chromium + ~3500 page fetches).

- [ ] **Step 3: Inspect chunk count**

```bash
sqlite3 pipeline/out/corpus.sqlite "SELECT COUNT(*) FROM chunks;"
```

Expected: somewhere in **20,000–60,000**. If <10,000, exclude patterns are too aggressive — investigate before merging. If >100,000, deduplication or extraction failed — investigate.

- [ ] **Step 4: Eyeball 20 random chunks for boilerplate / extraction quality**

```bash
sqlite3 pipeline/out/corpus.sqlite "SELECT source_url, substr(text, 1, 200) FROM chunks ORDER BY RANDOM() LIMIT 20;"
```

Reading the output: chunks should be substantive prose. Flag and investigate if you see:
- Lots of `*` / `|` / pipe-separated nav menus.
- Repeated copyright/footer text.
- Empty or single-line chunks.

- [ ] **Step 5: Run the manual verification gate**

```bash
python -m pipeline.scripts.verify_corpus --out pipeline/out
```

Expected: for every query, top-3 sources are **current** `cpcc.edu` / `catalog.cpcc.edu` pages. Zero `ARCHIVE` flags. If any archive URL appears, **stop and fix `sources.yaml` exclude_patterns** before merging.

- [ ] **Step 6: Confirm no archive URLs in any chunk**

```bash
sqlite3 pipeline/out/corpus.sqlite "SELECT COUNT(*) FROM chunks WHERE source_url LIKE '%/archives/%' OR source_url LIKE '%/archive/%';"
```

Expected: `0`. If non-zero, this is a regression — investigate before merging.

- [ ] **Step 7: Decide go/no-go**

If all checks pass, proceed to Task 14. If anything fails, iterate on `sources.yaml` exclude patterns, the content filter threshold in `html_crawler.py`, or the chunker — re-run Steps 1–6.

---

## Task 14: Open PR

- [ ] **Step 1: Push branch**

```bash
cd /Users/frazier/Developer/cpcc-ask-ios
git push -u origin feat/corpus-pipeline-v2
```

- [ ] **Step 2: Open PR**

```bash
gh pr create --title "feat(pipeline): corpus v2 — sitemap-driven crawl4ai + PDF allowlist" --body "$(cat <<'EOF'
## Summary
- Replaces BFS-based crawlers with sitemap-driven URL discovery (`sitemap.py`).
- Switches HTML extraction to `crawl4ai` (Playwright) → markdown.
- Replaces auto-discovered PDFs with an explicit YAML allowlist (`sources.yaml`).
- Chunker now markdown-aware (heading-boundary splits before size-based fallback).
- Eliminates the archive-PDF leakage that motivated this work (May 4 2026 incident).

## Test plan
- [x] `pytest pipeline/tests/` green (unit + smoke).
- [x] Local build produces 20–60k chunks.
- [x] `pipeline/scripts/verify_corpus.py` shows zero ARCHIVE flags on 10 known-bad queries.
- [x] `sqlite3 ... WHERE source_url LIKE '%/archives/%'` returns 0.

## Spec
`docs/superpowers/specs/2026-05-04-corpus-pipeline-v2-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Confirm CI is green on the PR**

```bash
gh pr checks --watch
```

Expected: refresh-corpus workflow's pytest step passes (the actual corpus-build step only runs on schedule/dispatch, not on PR — that's fine).

- [ ] **Step 4: Merge after review**

User-controlled. Once merged, the next Monday cron run will produce the first v2-built corpus and ship it via `upload_release.py`.

---

## Self-review notes

- **Spec coverage:** every section of the spec maps to at least one task: architecture (Tasks 3–7), sources.yaml schema (Task 1 + 2), migration steps (Tasks 1–14), testing strategy (Tasks 3, 4, 5, 6, 9, 10, 13), risks (mitigations referenced in Task 13 quality-gate steps).
- **Type consistency:** `Record` is defined identically in `html_crawler.py` and `pdf_fetcher.py` (intentionally — same shape, different home). `chunk_markdown` signature matches existing `chunk_text` style. JSONL field names (`url`, `title`, `markdown`, `sha256`) are consistent across writer and tests.
- **Known assumptions to verify in Task 10 Step 2:** `verify_corpus.py` SQL assumes columns `source_url` and `embedding` in `chunks`. If `pipeline/writer.py` uses different names (e.g., separate `embeddings` table), update the SQL.
