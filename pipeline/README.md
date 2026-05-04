# pipeline/

This package builds the Ask CPCC corpus — the offline knowledge base that powers RAG retrieval in the iOS app. It crawls `www.cpcc.edu` and `catalog.cpcc.edu` via sitemap, converts pages to clean markdown, fetches an explicit allowlist of CPCC PDFs, chunks and deduplicates the text, embeds it with a sentence-transformers MiniLM model, and writes a `corpus.sqlite` + `embeddings.bin` pair that ships inside the app bundle.

---

## Architecture

```
pipeline/sources.yaml
        |
        v
crawlers/sitemap.py          -- parse sitemap.xml, filter URLs
        |
        v
crawlers/html_crawler.py     -- crawl4ai (Playwright) -> markdown
crawlers/pdf_fetcher.py      -- httpx + pdfplumber -> markdown
        |
        v  (markdown JSONL written to pipeline/raw/)
chunker.py                   -- heading-aware markdown splitting
        |
        v
embedder.py                  -- sentence-transformers MiniLM (384-dim)
        |
        v
writer.py                    -- corpus.sqlite (FTS5) + embeddings.bin
        |
        v
pipeline/out/corpus.sqlite
pipeline/out/embeddings.bin
pipeline/out/manifest.json
```

---

## Modules

| Module | Description |
|---|---|
| `crawlers/sitemap.py` | Fetches and parses `sitemap.xml`, applies regex exclude-patterns, and returns a filtered list of page URLs up to `max_pages`. |
| `crawlers/html_crawler.py` | Uses crawl4ai (Playwright/Chromium) to render each URL and extract clean markdown. Returns `CrawlRecord(url, title, markdown, sha256)` objects. |
| `crawlers/pdf_fetcher.py` | Downloads each URL in the `pdfs.allowlist` via `httpx`, extracts text with `pdfplumber`, and returns `CrawlRecord` objects with the hand-written title from `sources.yaml`. |
| `chunker.py` | Splits markdown into semantically coherent chunks guided by heading boundaries. Avoids splitting mid-sentence; respects a max-char ceiling. |
| `embedder.py` | Loads `sentence-transformers/all-MiniLM-L6-v2` and embeds a batch of text strings into L2-normalized 384-dim float32 vectors. |
| `writer.py` | Writes `corpus.sqlite` (chunks table + FTS5 virtual table) and `embeddings.bin` (flat float32 array, row-major). Also writes `manifest.json` with version, date, and per-source counts. |
| `build_corpus.py` | Orchestrator. Reads `sources.yaml`, runs all six stages in order, and writes to `pipeline/out/`. |
| `scripts/verify_corpus.py` | Manual quality gate. Checks chunk counts, spot-queries FTS5, and validates that embeddings dimensions match the chunk count. Run after a local build before pushing. |

---

## Local run

### 1. Set up the environment

```bash
cd pipeline
python -m pip install -e .
python -m playwright install chromium   # one-time; or run: crawl4ai-setup
```

### 2. Build the corpus

```bash
cd ..   # back to repo root
python -m pipeline.build_corpus \
    --sources pipeline/sources.yaml \
    --raw pipeline/raw \
    --out pipeline/out
```

This runs all six stages and writes output to `pipeline/out/`.

### 3. Verify quality

```bash
python -m pipeline.scripts.verify_corpus --out pipeline/out
```

---

## Adding a PDF to the allowlist

1. Open `pipeline/sources.yaml`.
2. Add an entry under `pdfs.allowlist`:
   ```yaml
   pdfs:
     allowlist:
       - url: "https://catalog.cpcc.edu/path/to/document.pdf"
         title: "Human-Readable Title Here"
   ```
   Always supply a hand-written `title` — PDF metadata is often unreliable.
3. Commit and push. The weekly cron job picks it up automatically on its next run.

---

## CI

The weekly corpus refresh runs every Monday at 06:00 ET via `.github/workflows/refresh-corpus.yml`. It builds a fresh corpus, publishes it as a GitHub Release asset, and opens a PR updating `latest.json`. Merge the PR to push the new corpus to users.

---

## Tests

```bash
python -m pytest pipeline/tests/ -v
```

---

See `../docs/BUILD_PIPELINE.md` for the full data-flow and CoreML conversion notes.
