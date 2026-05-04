"""Sliding-window text chunker."""
from __future__ import annotations


def chunk_text(text: str, max_chars: int = 600, overlap: int = 100) -> list[str]:
    """Split text into overlapping chunks of at most max_chars characters.

    Prefers paragraph boundaries (\\n\\n) when within a max_chars window.
    Returns [] for empty or whitespace-only input.
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
            # Prefer ending on a paragraph boundary anywhere within the
            # current window (after start). This keeps semantically-related
            # paragraphs intact when possible.
            segment = text[start:end]
            para_idx = segment.rfind("\n\n")
            if para_idx > 0:
                end = start + para_idx
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end == len(text):
            break
        start = max(end - overlap, start + 1)
    return chunks
