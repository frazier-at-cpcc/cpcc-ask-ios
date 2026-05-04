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
