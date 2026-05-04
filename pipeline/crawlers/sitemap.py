"""Sitemap loader: fetches sitemap.xml(.gz), parses, recurses indexes,
applies exclude patterns, caps results at max_pages."""
from __future__ import annotations

import gzip
import re
import sys
from xml.etree import ElementTree as ET

import httpx

NS = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}

# Gzip magic bytes
_GZIP_MAGIC = b"\x1f\x8b"


def _fetch_text(url: str) -> str:
    """Fetch a sitemap. Handles .xml.gz transparently.

    Gzip detection priority:
    1. Magic bytes b"\\x1f\\x8b" at start of content (content-type-agnostic)
    2. URL suffix .gz
    3. Content-Type header (application/gzip or application/x-gzip)
    """
    resp = httpx.get(url, timeout=30, follow_redirects=True)
    resp.raise_for_status()
    content_type = resp.headers.get("Content-Type", "")
    is_gzip = (
        resp.content[:2] == _GZIP_MAGIC
        or url.endswith(".gz")
        or content_type.startswith("application/gzip")
        or content_type.startswith("application/x-gzip")
    )
    if is_gzip:
        return gzip.decompress(resp.content).decode("utf-8")
    return resp.text


def parse_sitemap_xml(xml: str) -> list[str]:
    """Parse a sitemap or sitemap-index XML string into a list of URLs.

    For a <urlset>, returns each <url><loc>.
    For a <sitemapindex>, returns each <sitemap><loc> (caller is responsible
    for recursing).
    """
    root = ET.fromstring(xml)
    locs = root.findall(".//sm:loc", NS)
    return [loc.text.strip() for loc in locs if loc.text]


def _is_sitemap_index(xml: str) -> bool:
    return "<sitemapindex" in xml[:512]


def load_urls(sitemap_url: str, exclude_patterns: list[str],
              max_pages: int) -> list[str]:
    """Recursively load page URLs from a sitemap, dropping pattern matches.

    Returns at most max_pages URLs in document order.
    """
    compiled = [re.compile(p) for p in exclude_patterns]
    urls: list[str] = []
    queue: list[str] = [sitemap_url]
    visited: set[str] = set()

    while queue and len(urls) < max_pages:
        current = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)

        try:
            xml = _fetch_text(current)
        except (httpx.HTTPError, gzip.BadGzipFile, ET.ParseError) as exc:
            print(f"sitemap.load_urls: failed to fetch {current}: {exc}", file=sys.stderr)
            continue

        if _is_sitemap_index(xml):
            queue.extend(parse_sitemap_xml(xml))
            continue

        for u in parse_sitemap_xml(xml):
            if any(rx.search(u) for rx in compiled):
                continue
            urls.append(u)
            if len(urls) >= max_pages:
                break

    return urls
