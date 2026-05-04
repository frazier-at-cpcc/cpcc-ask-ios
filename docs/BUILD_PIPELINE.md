# Corpus build pipeline

The corpus is a single zip (`corpus-YYYY-MM-DD.zip`) containing `corpus.sqlite`, `embeddings.bin`, and `manifest.json`. Published as a GitHub Release asset; the iOS app discovers new versions by polling `latest.json`.

## Local rebuild

```bash
cd pipeline
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]

python -m pipeline.build_corpus --out out --version $(date +%Y-%m-%d)
python -m pipeline.upload_release --out out --version $(date +%Y-%m-%d) --repo-root ..
```

## Stages

1. **Crawl** — `cpcc_main.py`, `cpcc_catalog.py`, `cpcc_pdfs.py` produce JSONL records.
2. **Chunk** — `chunker.py` slides 600-char windows with 100-char overlap, paragraph-aware.
3. **Embed** — `embedder.py` runs BAAI/bge-small-en-v1.5 (384-dim, L2-normalized).
4. **Write** — `writer.py` produces `corpus.sqlite` (chunks + FTS5) and `embeddings.bin`.
5. **Upload** — `upload_release.py` zips, publishes via `gh release create`, updates `latest.json`.

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
