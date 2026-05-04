# Corpus build pipeline

The corpus is a single zip (`corpus-YYYY-MM-DD.zip`) containing `corpus.sqlite`, `embeddings.bin`, and `manifest.json`. Published as a GitHub Release asset; the iOS app discovers new versions by polling `latest.json`.

## Local rebuild

```bash
cd pipeline
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
python -m playwright install chromium   # one-time; or run: crawl4ai-setup

cd ..
python -m pipeline.build_corpus \
    --sources pipeline/sources.yaml \
    --raw pipeline/raw \
    --out pipeline/out \
    --version $(date +%Y-%m-%d)
python -m pipeline.scripts.verify_corpus --out pipeline/out
python -m pipeline.upload_release --out pipeline/out --version $(date +%Y-%m-%d) --repo-root .
```

## Stages

1. **Discover** — `crawlers/sitemap.py` reads `sources.yaml`, fetches `sitemap.xml` for each site, and returns a filtered URL list.
2. **Crawl** — `crawlers/html_crawler.py` renders each page with crawl4ai (Playwright) and extracts clean markdown JSONL. `crawlers/pdf_fetcher.py` downloads allowlisted PDFs via httpx and converts them to markdown JSONL with pdfplumber.
3. **Chunk** — `chunker.py` splits markdown into heading-aware chunks and deduplicates across all sources.
4. **Embed** — `embedder.py` runs `sentence-transformers/all-MiniLM-L6-v2` (384-dim, L2-normalized).
5. **Write** — `writer.py` produces `corpus.sqlite` (chunks + FTS5) and `embeddings.bin`.
6. **Upload** — `upload_release.py` zips, publishes via `gh release create`, updates `latest.json`.

## CoreML conversion (one-time)

To regenerate `AskCPCC/Resources/BGEEmbedder.mlpackage` from the HuggingFace model:

```bash
cd pipeline
source .venv/bin/activate
# coremltools 9.0 is sensitive to transformers/torch versions — pin compatible ones:
pip install 'transformers<5' 'torch==2.7.0' coremltools
python -m pipeline.scripts.convert_bge_to_coreml --out ../AskCPCC/Resources/BGEEmbedder.mlpackage
```

The converter contains an in-script monkey-patch for a coremltools 9.0 `_cast` issue with length-1 ndarrays — leave it in place.

## Weekly cron

`.github/workflows/refresh-corpus.yml` runs every Monday at 06:00 ET. Opens a PR with the new `latest.json`. Merge to publish.
