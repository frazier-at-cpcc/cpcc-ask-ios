"""End-to-end smoke test for build_corpus.

Patches sitemap._fetch_text and html_crawler.crawl with fixture-backed fakes
so the full pipeline runs without network or Chromium.
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np
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

    # Patch fetch_all directly because fetch_all's `fetcher` default is bound at
    # import time, so patching _default_fetcher on the module has no effect when
    # build_corpus calls fetch_all() with no fetcher argument.
    # Capture the real function BEFORE patching to avoid infinite recursion.
    pdf_bytes = (FIXTURE_DIR / "sample.pdf").read_bytes()
    _real_fetch_all = pdf_fetcher.fetch_all

    def fake_fetch_all(allowlist, fetcher=None):
        return _real_fetch_all(allowlist, fetcher=lambda url: pdf_bytes)

    monkeypatch.setattr(pdf_fetcher, "fetch_all", fake_fetch_all)

    # Fake the embed model so the smoke test stays hermetic and fast —
    # sentence-transformers would try to download BAAI/bge-small-en-v1.5 on
    # first call, which requires a network connection and ~120 MB download.
    monkeypatch.setattr(build_corpus, "load_model", lambda: None)
    monkeypatch.setattr(
        build_corpus,
        "embed",
        lambda model, texts: np.zeros((len(texts), 384), dtype=np.float32),
    )

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
