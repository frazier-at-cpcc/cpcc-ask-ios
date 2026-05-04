"""End-to-end: crawl → extract → chunk → embed → write."""
from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path

from bs4 import BeautifulSoup

from pipeline.chunker import chunk_text
from pipeline.crawlers import cpcc_main, cpcc_catalog, cpcc_pdfs
from pipeline.embedder import load_model, embed
from pipeline.writer import write_corpus


def extract_text_from_html(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header", "aside"]):
        tag.decompose()
    return soup.get_text(separator="\n", strip=True)


def load_jsonl(path: Path):
    if not path.exists():
        return
    with path.open(encoding="utf-8") as fp:
        for line in fp:
            yield json.loads(line)


def build(raw_dir: Path, out_dir: Path, version: str | None = None) -> None:
    print("Stage 1: crawl")
    cpcc_main.crawl(raw_dir)
    cpcc_catalog.crawl(raw_dir)
    cpcc_pdfs.crawl(raw_dir)

    print("Stage 2 + 3: extract + chunk")
    chunks: list[dict] = []
    counts = {"cpcc.edu": 0, "catalog.cpcc.edu": 0, "pdfs": 0}

    for rec in load_jsonl(raw_dir / "cpcc_main.jsonl"):
        text = extract_text_from_html(rec["html"])
        for piece in chunk_text(text):
            chunks.append({"source_url": rec["url"], "title": rec.get("title", ""), "text": piece,
                           "char_offset": 0, "page_section": ""})
        counts["cpcc.edu"] += 1

    for rec in load_jsonl(raw_dir / "cpcc_catalog.jsonl"):
        text = extract_text_from_html(rec["html"])
        for piece in chunk_text(text):
            chunks.append({"source_url": rec["url"], "title": rec.get("title", ""), "text": piece,
                           "char_offset": 0, "page_section": ""})
        counts["catalog.cpcc.edu"] += 1

    for rec in load_jsonl(raw_dir / "cpcc_pdfs.jsonl"):
        for piece in chunk_text(rec["text"]):
            chunks.append({"source_url": rec["url"], "title": rec.get("title", ""), "text": piece,
                           "char_offset": 0, "page_section": ""})
        counts["pdfs"] += 1

    print(f"  total chunks: {len(chunks)}")

    print("Stage 4: embed")
    model = load_model()
    vecs = embed(model, [c["text"] for c in chunks])

    print("Stage 5: write")
    v = version or date.today().isoformat()
    write_corpus(out_dir, chunks, vecs, counts, version=v)
    print(f"Wrote corpus version {v} to {out_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", type=Path, default=Path("pipeline/raw"))
    parser.add_argument("--out", type=Path, default=Path("pipeline/out"))
    parser.add_argument("--version", type=str, default=None)
    args = parser.parse_args()
    build(args.raw, args.out, args.version)
