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


def test_fetch_all_skips_pdfs_with_no_extractable_text():
    """Image-only or otherwise text-less PDFs should be skipped, not added
    as empty Records to the corpus."""
    def fake_fetch(url): return b"not a pdf"
    records = fetch_all(
        allowlist=[{"url": "https://example.test/blank.pdf", "title": "Blank"}],
        fetcher=fake_fetch,
    )
    assert records == []
