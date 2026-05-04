"""crawl4ai-based HTML → markdown extractor.

Two layers:
  1. record_from_markdown / html_to_markdown — pure helpers, unit-testable.
  2. crawl(urls) — async function using AsyncWebCrawler (Playwright). Used in
     production; covered by smoke test only (requires Chromium + network).
"""
from __future__ import annotations

import asyncio
import hashlib
import sys
from dataclasses import dataclass

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig
from crawl4ai.markdown_generation_strategy import DefaultMarkdownGenerator
from crawl4ai.content_filter_strategy import PruningContentFilter

# Pin browser settings explicitly so corpus builds are reproducible across
# crawl4ai version upgrades (defaults can shift between releases).
_BROWSER_CONFIG = BrowserConfig(
    headless=True,
    user_agent="AskCPCC-Pipeline/0.2 (+https://github.com/Frazier-at-CPCC/cpcc-ask-ios)",
    viewport_width=1280,
    viewport_height=800,
)


# Same shape as pdf_fetcher.Record — kept separate intentionally to decouple
# the two crawlers. Downstream code accepts either via duck typing.
@dataclass
class Record:
    url: str
    title: str
    markdown: str
    sha256: str


def record_from_markdown(url: str, title: str, markdown: str) -> Record:
    sha = hashlib.sha256(markdown.encode("utf-8")).hexdigest()
    return Record(url=url, title=title, markdown=markdown, sha256=sha)


def _markdown_generator() -> DefaultMarkdownGenerator:
    return DefaultMarkdownGenerator(
        content_filter=PruningContentFilter(threshold=0.48, threshold_type="fixed"),
    )


def html_to_markdown(html: str, base_url: str) -> str:
    """Run crawl4ai's markdown generator over a raw HTML string.

    Pure synchronous function — no browser, no network. Used by both the
    live crawler and unit tests so behaviour matches.
    """
    if not html.strip():
        return ""
    gen = _markdown_generator()
    res = gen.generate_markdown(input_html=html, base_url=base_url)
    # fit_markdown is the content-filter-pruned version; fall back to raw.
    fit = getattr(res, "fit_markdown", None)
    return (fit or res.raw_markdown or "").strip()


async def _crawl_async(urls: list[str]) -> list[Record]:
    config = CrawlerRunConfig(markdown_generator=_markdown_generator())
    records: list[Record] = []
    async with AsyncWebCrawler(config=_BROWSER_CONFIG) as crawler:
        for url in urls:
            try:
                result = await crawler.arun(url=url, config=config)
            except (asyncio.TimeoutError, ConnectionError, OSError) as exc:
                # Only swallow expected network-layer failures; anything else
                # (programming errors, KeyboardInterrupt, etc.) should propagate.
                print(f"html_crawler.crawl: skip {url}: {exc}", file=sys.stderr)
                continue
            if not getattr(result, "success", False):
                continue
            md_obj = result.markdown
            md = (
                getattr(md_obj, "fit_markdown", None)
                or getattr(md_obj, "raw_markdown", None)
                or str(md_obj)
                or ""
            ).strip()
            if not md:
                continue
            title = ""
            if result.metadata:
                title = result.metadata.get("title", "") or ""
            records.append(record_from_markdown(url=url, title=title, markdown=md))
    return records


def crawl(urls: list[str]) -> list[Record]:
    """Sync wrapper over the async crawler. Returns Records for successful URLs."""
    return asyncio.run(_crawl_async(urls))
