"""Sliding-window text chunker."""
from __future__ import annotations

import re


def chunk_text(text: str, max_chars: int = 600, overlap: int = 100,
               min_chunk_chars: int = 200) -> list[str]:
    """Split text into overlapping chunks of at most max_chars characters.

    Prefers paragraph boundaries (\\n\\n) but only accepts a boundary
    when the resulting chunk would be at least min_chunk_chars long.
    Otherwise hard-cuts at max_chars.

    Skips chunks shorter than min_chunk_chars in the output to avoid
    flooding the index with low-value microchunks. Returns [] for empty
    or whitespace-only input.
    """
    text = text.strip()
    if not text:
        return []

    if len(text) <= max_chars:
        return [text]

    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        if end < len(text):
            # Look for a paragraph break anywhere in the current window,
            # but only accept it if the resulting chunk would be >= min_chunk_chars.
            # This keeps semantically-related paragraphs together while preventing
            # the chunker from creating microchunks on every \n\n.
            min_acceptable_end = start + min_chunk_chars
            segment = text[start:end]
            para_idx = segment.rfind("\n\n")
            if para_idx > 0:
                candidate_end = start + para_idx
                if candidate_end >= min_acceptable_end:
                    end = candidate_end
        chunk = text[start:end].strip()
        if chunk and len(chunk) >= min_chunk_chars:
            chunks.append(chunk)
        if end == len(text):
            break
        start = max(end - overlap, start + 1)
    return chunks


# Splits at the start of any line beginning with #, ##, or ### (ATX headings).
_HEADING_SPLIT = re.compile(r"(?m)^(?=#{1,3}\s)")


def chunk_markdown(markdown: str, max_chars: int = 600, overlap: int = 100,
                   min_chunk_chars: int = 200) -> list[str]:
    """Markdown-aware chunker.

    Splits on heading boundaries (#, ##, ###) into sections, then runs each
    section through chunk_text. Short adjacent sections are merged together
    rather than emitted as microchunks.
    """
    markdown = markdown.strip()
    if not markdown:
        return []

    sections = [s.strip() for s in _HEADING_SPLIT.split(markdown) if s.strip()]
    if not sections:
        return chunk_text(markdown, max_chars=max_chars, overlap=overlap,
                          min_chunk_chars=min_chunk_chars)

    chunks: list[str] = []
    buffer = ""
    for section in sections:
        if len(buffer) + len(section) + 2 <= max_chars:
            buffer = (buffer + "\n\n" + section).strip()
            continue
        if buffer:
            chunks.extend(chunk_text(buffer, max_chars=max_chars, overlap=overlap,
                                     min_chunk_chars=min_chunk_chars))
            buffer = ""
        if len(section) <= max_chars:
            buffer = section
        else:
            chunks.extend(chunk_text(section, max_chars=max_chars, overlap=overlap,
                                     min_chunk_chars=min_chunk_chars))
    if buffer:
        chunks.extend(chunk_text(buffer, max_chars=max_chars, overlap=overlap,
                                 min_chunk_chars=min_chunk_chars))
    return chunks
