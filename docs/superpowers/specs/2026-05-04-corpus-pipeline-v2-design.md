# Corpus Pipeline v2 — Design Spec

**Date:** 2026-05-04
**Status:** Approved by user, ready for implementation planning
**Owner:** Frazier Smith

## Background

The current corpus pipeline (`pipeline/crawlers/cpcc_main.py`, `cpcc_catalog.py`, `cpcc_pdfs.py`) does an unbounded BFS of `www.cpcc.edu` and `catalog.cpcc.edu`, then auto-discovers and downloads every `.pdf` link found in the crawled HTML. This pulled in dozens of archived catalog PDFs going back to 2002–03, which now contaminate retrieval — the running app cites `catalog.cpcc.edu/archives/2002-03.pdf` for current-year program questions. The existing chunker emits ~80k chunks / 134 MB, much of which is boilerplate (nav, footer, sidebars).

## Goals

1. Stop indexing archival catalog PDFs and other stale long-tail content at *crawl time*, so on-device filtering becomes belt-and-suspenders.
2. Improve chunk quality by switching from raw-HTML extraction to markdown extraction (boilerplate stripped at the source).
3. Make the source set declarative (config-as-data) so non-engineers can add/remove a PDF without touching Python.
4. Keep the same final corpus artifact (`corpus.sqlite`) and the same on-device app behavior — no changes to the iOS app for this work.

## Non-goals

- No changes to the iOS app, the embedder, the writer, or the upload step.
- No live-schedule fetcher changes.
- No automated end-to-end LLM-driven quality gates in CI (captured under Future Work).
- No support for additional CPCC sub-domains beyond `www.cpcc.edu` and `catalog.cpcc.edu`.

## Key decisions (from brainstorming session)

| # | Decision | Rationale |
|---|---|---|
| 1 | PDFs become an explicit allowlist; no auto-discovery from HTML. | Auto-discovery is the root cause of the archive-PDF bug. |
| 2 | Switch JSONL contract to a `markdown` field; chunker reads markdown directly. | Cleaner chunks, smaller corpus; the JSONL is a build-time artifact, not shipped. |
| 3 | Rip-and-replace the three existing crawlers on a feature branch (no parallel v1/v2). | Avoids carrying both code paths; weekly cron picks up the new pipeline once merged. |
| 4 | Use `crawl4ai` with the headless-browser (Playwright/Chromium) strategy. | User preference; future-proof for any source that gains JS rendering. |
| 5 | PDF allowlist lives in `pipeline/sources.yaml` with hand-written titles. | YAML diffs cleanly in PRs; hand-written titles avoid garbage PDF-metadata titles. |
| 6 | Sitemap-first crawling; BFS replaced entirely. | Sitemaps surface canonical/current URLs only; archives are absent by definition. |

## Architecture

```
            ┌─────────────────────────┐
            │ pipeline/sources.yaml   │  ← single source of truth
            │  • main:    sitemap URL │
            │  • catalog: sitemap URL │
            │  • pdfs:    [allowlist] │
            └──────────┬──────────────┘
                       │
   ┌───────────────────┼───────────────────┐
   ▼                   ▼                   ▼
sitemap.py        html_crawler.py      pdf_fetcher.py
(parses XML →     (crawl4ai +          (httpx GET each
URL list, drops   Playwright →         allowlisted PDF;
exclude_pattern   markdown via         pdfplumber → text)
matches)          DefaultMarkdown
                  Generator with
                  content filter)
   └───────────────────┼───────────────────┘
                       ▼
            JSONL  {url, title, markdown, sha256}
                       │
                       ▼
              chunker.py (markdown-aware,
              splits on headings → size cap → dedup)
                       ▼
              embedder.py → corpus.sqlite
                       ▼
                upload_release.py
```

The chunker, embedder, writer, and upload step keep their roles. The chunker is the only downstream module that changes — it reads the new `markdown` field instead of `html`.

## Module layout

```
pipeline/
├── sources.yaml                  ← NEW: declarative source config
├── build_corpus.py               ← MODIFIED: orchestrate v2 crawlers + write JSONL
├── chunker.py                    ← MODIFIED: read markdown field, split on headings
├── embedder.py                   ← unchanged
├── writer.py                     ← unchanged
├── upload_release.py             ← unchanged
├── crawlers/
│   ├── __init__.py
│   ├── sitemap.py                ← NEW: parse sitemap.xml(.gz) → list[URL]
│   ├── html_crawler.py           ← NEW: crawl4ai (Playwright) → markdown
│   └── pdf_fetcher.py            ← NEW: httpx + pdfplumber for allowlisted PDFs
├── tests/
│   ├── fixtures/                 ← NEW: sitemap XML, sample HTML pages, sample PDF
│   ├── test_sitemap.py           ← NEW
│   ├── test_html_crawler.py      ← NEW (mocks crawl4ai with fixture HTML)
│   ├── test_pdf_fetcher.py       ← NEW (uses fixture PDF)
│   ├── test_chunker.py           ← MODIFIED for markdown input
│   └── test_build_corpus_smoke.py ← NEW: end-to-end against fixture sources
└── scripts/
    └── verify_corpus.py          ← NEW: developer tool, runs known-bad queries
```

Files **deleted**: `crawlers/cpcc_main.py`, `crawlers/cpcc_catalog.py`, `crawlers/cpcc_pdfs.py`. (No existing tests target them — `pipeline/tests/` currently only has `test_chunker.py` and `test_writer.py`.)

### Module responsibilities

- **`sitemap.py`** — `load_urls(sitemap_url: str, exclude_patterns: list[str], max_pages: int) -> list[str]`. Fetches `sitemap.xml` (or `.xml.gz`), recurses sitemap-indexes, defragments URLs, drops anything matching any `exclude_patterns` regex, caps at `max_pages`. No parsing of page bodies, no PDF/HTML side trips — output is a URL list.
- **`html_crawler.py`** — `async crawl(urls: list[str]) -> Iterable[Record]`. Runs `crawl4ai.AsyncWebCrawler` with `CrawlerRunConfig` tuned to emit clean markdown via `DefaultMarkdownGenerator` + a content filter that strips nav, footer, and sidebar elements. Yields `Record(url, title, markdown, sha256)`. No knowledge of sources or sitemaps.
- **`pdf_fetcher.py`** — `fetch_all(allowlist: list[PDFSpec]) -> Iterable[Record]`. For each `(url, title)` in the allowlist, fetches with `httpx`, extracts text with `pdfplumber`, wraps as a single markdown block under `# {title}`, returns `Record(url, title, markdown, sha256)`. Same output type as `html_crawler.crawl()`.
- **`build_corpus.py`** — Reads `sources.yaml`, calls `sitemap.load_urls()` for each HTML source, hands the URL lists to `html_crawler.crawl()`, calls `pdf_fetcher.fetch_all()` for the PDF allowlist, merges the streams into one JSONL, then runs the existing chunker → embedder → writer chain.
- **`chunker.py`** — Modified to read the `markdown` field. Splitting strategy: prefer heading boundaries (`#`, `##`, `###`), fall back to size-based splits if a section exceeds the size cap. Existing dedup logic (per commit `d866619`) is preserved unchanged.

Each module is testable in isolation with fixture inputs.

## Configuration: `sources.yaml`

```yaml
# pipeline/sources.yaml

main:
  sitemap: "https://www.cpcc.edu/sitemap.xml"
  exclude_patterns:
    - "/news/"
    - "/events/"
    - "/calendar/"
    - "/sites/.*\\.pdf$"   # PDFs handled in pdfs:, not via HTML crawl
  max_pages: 2000

catalog:
  sitemap: "https://catalog.cpcc.edu/sitemap.xml"
  exclude_patterns:
    - "/archives?/"
    - "(19|20)\\d{2}([-_]\\d{2,4})?\\.pdf$"
  max_pages: 1500

pdfs:
  # Auto-discovery is gone. Populate manually; refresh annually.
  allowlist:
    # Initial seed list to be researched and proposed during implementation;
    # candidates: student handbook, academic calendar, FERPA notice,
    # board policy, code of conduct.
    # Each entry: { url: <https URL>, title: <human-readable> }
    []
```

`title:` is **required** on each PDF entry — derived titles from PDF metadata are unreliable.

## Migration steps

Rip-and-replace on a feature branch (`feat/corpus-pipeline-v2`):

1. **Branch** from `main`.
2. **Add deps** to `requirements.txt`: `crawl4ai`, `httpx`, `PyYAML`. Drop `requests` and `beautifulsoup4` if no test still uses them. Keep `pdfplumber`. Run `crawl4ai-setup` once locally to install Playwright/Chromium.
3. **Research step:** audit `www.cpcc.edu` for current PDFs worth pinning (handbook, academic calendar, FERPA, board policy, code of conduct, etc.). Populate `sources.yaml` `pdfs.allowlist`.
4. **Write `sitemap.py` + tests.** Save real `sitemap.xml` for `catalog` and `main` as fixtures; tests are offline.
5. **Write `html_crawler.py` + tests.** Save 2–3 real `.html` pages as fixtures; mock crawl4ai's fetch so tests don't spin Playwright. Tune the content filter on sample pages.
6. **Write `pdf_fetcher.py` + tests.** One small allowlisted PDF as a fixture.
7. **Modify `chunker.py`** to read `markdown` field, split on heading boundaries, preserve existing dedup. Update existing chunker tests.
8. **Modify `build_corpus.py`** to wire it together.
9. **Delete the three old crawlers** (`cpcc_main.py`, `cpcc_catalog.py`, `cpcc_pdfs.py`).
10. **Local end-to-end run.** Build the v2 corpus on the branch (~10–30 min). Inspect:
    - chunk count (expect a drop from ~80k toward ~30–50k).
    - 20 random chunks for boilerplate / extraction quality.
    - run `pipeline/scripts/verify_corpus.py` against known-bad queries from the May 4 screenshots ("nursing programs", "IT degree options", "CTI-120 sections"). No archive URLs in top-3 sources.
11. **Update README and `docs/BUILD_PIPELINE.md`** to reflect new modules and `sources.yaml`.
12. **Update `.github/workflows/`** weekly-cron job: install Chromium step, cache Playwright browsers between runs.
13. **Open PR, merge.** Weekly cron picks up the new pipeline; first scheduled run ships the new corpus.

Steps 4–9 can be parallelized; step 10 is a quality gate before merge.

## Testing strategy

**Unit tests** (`pipeline/tests/`)
- `test_sitemap.py` — fixture: `tests/fixtures/sitemap_catalog.xml`. Verifies URL extraction, exclude-pattern application, sitemap-index recursion. No network.
- `test_html_crawler.py` — fixtures: 2–3 `tests/fixtures/*.html` saved offline. Mocks crawl4ai's fetcher. Asserts markdown drops nav/footer, preserves headings, captures title.
- `test_pdf_fetcher.py` — fixture: one small PDF. Asserts record shape and text extraction.
- `test_chunker.py` — extended for markdown input + heading splits + preserved dedup.

**Smoke test** (`pipeline/tests/test_build_corpus_smoke.py`)
- Runs `build_corpus.py` against a synthetic mini `sources.yaml` pointing at fixture sitemaps + fixture PDFs. Asserts: non-empty `corpus.sqlite`, chunk count in expected range, **no chunk URL matches `/archives/` or a year-stamped PDF pattern**.

**Manual verification gate** (`pipeline/scripts/verify_corpus.py`)
- Loads the freshly-built corpus and runs ~10 known-bad-citation queries. Prints top-3 source URLs per query. Eyeball before merge.
- Not in CI; developer-only tool. No LLM call needed (uses RAG retrieval directly).

## Risks

| Risk | Mitigation |
|---|---|
| Sitemap.xml may be incomplete or missing for `www.cpcc.edu` | Verify both sitemaps exist before starting work; if `www.cpcc.edu` lacks one, fall back to a hand-curated seed-URL list in `sources.yaml` (a path the design supports without restructuring). |
| crawl4ai's content filter may strip too aggressively or miss boilerplate | Tune on 5–10 sample pages during step 5; the smoke test asserts non-empty markdown per page. |
| Playwright + Chromium add ~15–20 min and ~500 MB to the weekly CI cron | Cache the Playwright browsers between runs (step 12). Acceptable cost for the quality win. |
| The PDF allowlist will rot as CPCC publishes new versions of handbook/calendar | Annual refresh task; not solved by this design. Document in README. |
| Chunk count drops too far (e.g. <10k) suggesting over-aggressive exclusion | Step-10 quality gate catches this before merge; iterate on `exclude_patterns` if needed. |

## Future work

Out of scope for this spec, captured for reference:

- **OpenRouter-driven automated Xcode integration tests.** End-to-end test harness that runs golden questions through the full RAG → schedule → OpenRouter pipeline and asserts source quality + answer correctness. Requires `OPENROUTER_API_KEY` as a GitHub Actions secret. Cost guards needed. Separate spec cycle.
- **Live-schedule reliability.** Anti-forgery token regex in `CourseScheduleAuth.swift` is brittle (assumes `name=` precedes `value=` in HTML); request body shape in `CourseScheduleClient.swift` is suspect. Diagnostic surfacing landed in this branch already; root-cause fix is separate.
- **Annual PDF allowlist refresh process.** Probably a small script + a calendar reminder.
