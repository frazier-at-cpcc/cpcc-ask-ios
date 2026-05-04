import gzip
from pathlib import Path

import httpx
import pytest

from pipeline.crawlers.sitemap import _fetch_text, parse_sitemap_xml, load_urls


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


# ---------------------------------------------------------------------------
# Issue 1: fetch failure is logged to stderr; crawl continues for other URLs
# ---------------------------------------------------------------------------

_GOOD_XML = """\
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.test/good-page</loc></url>
</urlset>
"""


def test_load_urls_logs_fetch_failure_and_continues(monkeypatch, capsys):
    """A fetch failure for one URL is logged to stderr; other URLs still appear."""
    bad_url = "https://example.test/bad-sitemap.xml"
    good_url = "https://example.test/good-sitemap.xml"

    # Use a sitemap-index as the entry point so both children are queued
    index_xml = f"""\
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap><loc>{bad_url}</loc></sitemap>
  <sitemap><loc>{good_url}</loc></sitemap>
</sitemapindex>
"""

    def fake_fetch(url: str) -> str:
        if url == bad_url:
            raise httpx.HTTPError("simulated")
        if url == good_url:
            return _GOOD_XML
        return index_xml

    monkeypatch.setattr("pipeline.crawlers.sitemap._fetch_text", fake_fetch)

    urls = load_urls(
        "https://example.test/sitemap-index.xml",
        exclude_patterns=[],
        max_pages=100,
    )

    # The good URL should still be harvested
    assert "https://example.test/good-page" in urls

    # Something diagnostic should have been written to stderr
    captured = capsys.readouterr()
    assert bad_url in captured.err
    assert "sitemap.load_urls" in captured.err


# ---------------------------------------------------------------------------
# Issue 2: gzip handling — Content-Type: application/gzip and URL suffix
# ---------------------------------------------------------------------------

_SIMPLE_XML_BYTES = _GOOD_XML.encode("utf-8")


def test_fetch_text_decompresses_gzip_by_content_type(monkeypatch):
    """_fetch_text decompresses when Content-Type is application/gzip."""
    compressed = gzip.compress(_SIMPLE_XML_BYTES)
    fake_response = httpx.Response(
        200,
        content=compressed,
        headers={"Content-Type": "application/gzip"},
        request=httpx.Request("GET", "https://example.test/sm.xml.gz"),
    )
    monkeypatch.setattr("httpx.get", lambda *a, **kw: fake_response)

    result = _fetch_text("https://example.test/sm.xml.gz")
    assert result == _GOOD_XML


def test_fetch_text_decompresses_gzip_by_url_suffix(monkeypatch):
    """_fetch_text decompresses when URL ends with .gz (Content-Type absent/wrong)."""
    compressed = gzip.compress(_SIMPLE_XML_BYTES)
    fake_response = httpx.Response(
        200,
        content=compressed,
        headers={"Content-Type": "application/octet-stream"},
        request=httpx.Request("GET", "https://example.test/sm.xml.gz"),
    )
    monkeypatch.setattr("httpx.get", lambda *a, **kw: fake_response)

    result = _fetch_text("https://example.test/sm.xml.gz")
    assert result == _GOOD_XML


# ---------------------------------------------------------------------------
# Issue 3: application/x-gzip and magic-bytes detection
# ---------------------------------------------------------------------------

def test_fetch_text_decompresses_gzip_x_gzip_content_type(monkeypatch):
    """_fetch_text decompresses when Content-Type is application/x-gzip."""
    compressed = gzip.compress(_SIMPLE_XML_BYTES)
    fake_response = httpx.Response(
        200,
        content=compressed,
        headers={"Content-Type": "application/x-gzip"},
        request=httpx.Request("GET", "https://example.test/sm.xml"),
    )
    monkeypatch.setattr("httpx.get", lambda *a, **kw: fake_response)

    result = _fetch_text("https://example.test/sm.xml")
    assert result == _GOOD_XML


def test_fetch_text_decompresses_gzip_by_magic_bytes(monkeypatch):
    """_fetch_text decompresses when content starts with gzip magic bytes,
    regardless of Content-Type or URL suffix."""
    compressed = gzip.compress(_SIMPLE_XML_BYTES)
    # Verify it really starts with gzip magic bytes
    assert compressed[:2] == b"\x1f\x8b"

    fake_response = httpx.Response(
        200,
        content=compressed,
        headers={"Content-Type": "text/xml"},  # wrong content-type, no .gz suffix
        request=httpx.Request("GET", "https://example.test/sitemap.xml"),
    )
    monkeypatch.setattr("httpx.get", lambda *a, **kw: fake_response)

    result = _fetch_text("https://example.test/sitemap.xml")
    assert result == _GOOD_XML
