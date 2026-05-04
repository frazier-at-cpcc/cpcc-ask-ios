"""Writes corpus.sqlite (chunks + FTS5), embeddings.bin, manifest.json."""
from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

EMBEDDING_DIM = 384


def write_corpus(
    out_dir: Path,
    chunks: list[dict],
    embeddings: np.ndarray,
    sources_count: dict[str, int],
    version: str,
    embedding_model: str = "BAAI/bge-small-en-v1.5",
    min_app_version: str = "1.0.0",
) -> None:
    """Write all three corpus artifacts into out_dir."""
    out_dir.mkdir(parents=True, exist_ok=True)
    assert embeddings.dtype == np.float32
    assert embeddings.shape == (len(chunks), EMBEDDING_DIM)

    db_path = out_dir / "corpus.sqlite"
    if db_path.exists():
        db_path.unlink()
    db = sqlite3.connect(db_path)
    db.execute("""
        CREATE TABLE chunks (
            id INTEGER PRIMARY KEY,
            source_url TEXT NOT NULL,
            title TEXT,
            text TEXT NOT NULL,
            char_offset INTEGER,
            page_section TEXT
        )
    """)
    db.execute("""
        CREATE VIRTUAL TABLE chunks_fts USING fts5(text, content='chunks', content_rowid='id')
    """)
    for c in chunks:
        cur = db.execute(
            "INSERT INTO chunks (source_url, title, text, char_offset, page_section) VALUES (?, ?, ?, ?, ?)",
            (c["source_url"], c.get("title", ""), c["text"], c.get("char_offset", 0), c.get("page_section", "")),
        )
        db.execute("INSERT INTO chunks_fts (rowid, text) VALUES (?, ?)", (cur.lastrowid, c["text"]))
    db.commit()
    db.close()

    (out_dir / "embeddings.bin").write_bytes(embeddings.tobytes())

    manifest = {
        "version": version,
        "buildTimestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sources": sources_count,
        "totalChunks": len(chunks),
        "embeddingModel": embedding_model,
        "embeddingDim": EMBEDDING_DIM,
        "minAppVersion": min_app_version,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))
