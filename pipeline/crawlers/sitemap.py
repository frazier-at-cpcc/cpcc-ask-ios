"""Sitemap loader: fetches sitemap.xml(.gz), parses, recurses indexes,
applies exclude patterns, caps results at max_pages."""
from __future__ import annotations

import gzip
import re
from xml.etree import ElementTree as ET

import httpx

NS = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}


def _fetch_text(url: str) -> str:
    """Fetch a sitemap. Handles .xml.gz transparently."""
    resp = httpx.get(url, timeout=30, follow_redirects=True)
    resp.raise_for_status()
    if url.endswith(".gz") or resp.headers.get("Content-Type", "").startswith("application/gzip"):
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
        except Exception:
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
