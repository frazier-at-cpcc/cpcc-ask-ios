import json
import sqlite3
from pathlib import Path

import numpy as np

from pipeline.writer import write_corpus


def test_writes_chunks_and_embeddings_and_manifest(tmp_path: Path):
    chunks = [
        {"source_url": "https://cpcc.edu/a", "title": "A", "text": "Alpha", "char_offset": 0, "page_section": ""},
        {"source_url": "https://cpcc.edu/b", "title": "B", "text": "Beta",  "char_offset": 0, "page_section": ""},
    ]
    vecs = np.zeros((2, 384), dtype=np.float32)
    vecs[0, 0] = 1.0
    vecs[1, 1] = 1.0

    sources_count = {"cpcc.edu": 2, "catalog.cpcc.edu": 0, "pdfs": 0}
    write_corpus(tmp_path, chunks, vecs, sources_count, version="2026-05-03")

    db = sqlite3.connect(tmp_path / "corpus.sqlite")
    rows = db.execute("SELECT id, source_url, text FROM chunks ORDER BY id").fetchall()
    assert rows == [(1, "https://cpcc.edu/a", "Alpha"), (2, "https://cpcc.edu/b", "Beta")]

    raw = (tmp_path / "embeddings.bin").read_bytes()
    assert len(raw) == 2 * 384 * 4
    arr = np.frombuffer(raw, dtype=np.float32).reshape(2, 384)
    assert arr[0, 0] == 1.0
    assert arr[1, 1] == 1.0

    manifest = json.loads((tmp_path / "manifest.json").read_text())
    assert manifest["version"] == "2026-05-03"
    assert manifest["totalChunks"] == 2
    assert manifest["embeddingDim"] == 384


def test_fts_index_searchable(tmp_path: Path):
    chunks = [{"source_url": "u", "title": "t", "text": "registration deadline", "char_offset": 0, "page_section": ""}]
    vecs = np.zeros((1, 384), dtype=np.float32)
    write_corpus(tmp_path, chunks, vecs, {"cpcc.edu": 1, "catalog.cpcc.edu": 0, "pdfs": 0}, version="2026-05-03")
    db = sqlite3.connect(tmp_path / "corpus.sqlite")
    hits = db.execute("SELECT rowid FROM chunks_fts WHERE chunks_fts MATCH 'deadline'").fetchall()
    assert hits == [(1,)]
