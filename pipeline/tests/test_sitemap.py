from pathlib import Path

import pytest

from pipeline.crawlers.sitemap import parse_sitemap_xml, load_urls


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
