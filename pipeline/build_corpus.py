"""End-to-end v2: sources.yaml → sitemap+crawl → PDFs → markdown JSONL → chunk → embed → write."""
from __future__ import annotations

import argparse
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
    for required in ("main", "catalog"):
        if required not in sources:
            raise SystemExit(
                f"sources.yaml missing required key: {required!r} "
                f"(expected at top level of {sources_path})"
            )

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
