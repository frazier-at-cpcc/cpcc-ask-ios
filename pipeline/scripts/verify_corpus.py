"""Developer tool: runs known-bad-citation queries against a freshly-built corpus
and prints top-3 sources per query.

Not run in CI. Use after `build_corpus.py` finishes locally to eyeball quality
before opening a PR.

Usage:
    python -m pipeline.scripts.verify_corpus --out pipeline/out

Schema deviation note
---------------------
The prescribed starter code assumed `SELECT source_url, embedding FROM chunks`,
i.e. embeddings stored as BLOBs inside the chunks table.

Actual writer.py schema (see pipeline/writer.py):
  - TABLE chunks (id, source_url, title, text, char_offset, page_section)
    → NO embedding column; embeddings are NOT stored in SQLite.
  - embeddings.bin  — flat binary file: (N, 384) float32, row-ordered by
    chunks.id ascending (same insertion order as chunks list passed to
    write_corpus()).
  - manifest.json   — contains "totalChunks" and "embeddingDim" for validation.

topk() therefore:
  1. Reads source_url values from chunks ordered by id (preserving row index).
  2. Memory-maps embeddings.bin as a numpy array aligned to the same ordering.
  3. Computes dot-product similarity (embeddings are already L2-normalised by
     the embedder, so dot == cosine).
"""
from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

import numpy as np

from pipeline.embedder import load_model, embed

EMBEDDING_DIM = 384

KNOWN_BAD_QUERIES = [
    "what nursing programs does CPCC offer",
    "what IT degree options are there",
    "which sections of CTI-120 have seats available this fall",
    "where is the campus located",
    "tuition cost",
    "academic calendar fall 2026",
    "FERPA student records",
    "code of conduct",
    "computer science associate degree",
    "financial aid deadlines",
]


def topk(corpus_path: Path, query_vec: list[float], k: int = 3) -> list[tuple[str, float]]:
    """Brute-force cosine-similarity top-k against the corpus.

    Schema-adapted: embeddings live in embeddings.bin (same directory as
    corpus.sqlite), NOT in a column of the chunks table.
    """
    out_dir = corpus_path.parent

    # --- load manifest for dimension/count validation ---
    manifest_path = out_dir / "manifest.json"
    if manifest_path.exists():
        meta = json.loads(manifest_path.read_text())
        total_chunks = meta.get("totalChunks", None)
        emb_dim = meta.get("embeddingDim", EMBEDDING_DIM)
    else:
        total_chunks = None
        emb_dim = EMBEDDING_DIM

    # --- load source URLs in id order (matches embeddings.bin row order) ---
    # Actual SQL used: SELECT source_url FROM chunks ORDER BY id
    conn = sqlite3.connect(corpus_path)
    rows = conn.execute("SELECT source_url FROM chunks ORDER BY id").fetchall()
    conn.close()
    urls: list[str] = [r[0] for r in rows]
    n = len(urls)

    # --- memory-map embeddings.bin ---
    emb_path = out_dir / "embeddings.bin"
    if not emb_path.exists():
        raise FileNotFoundError(f"embeddings.bin not found in {out_dir}")
    embeddings = np.frombuffer(emb_path.read_bytes(), dtype=np.float32).reshape(n, emb_dim)

    # --- cosine similarity (dot product; embeddings are pre-normalised) ---
    qv = np.asarray(query_vec, dtype=np.float32)
    qn = qv / (np.linalg.norm(qv) + 1e-12)
    scores: np.ndarray = embeddings @ qn  # shape (n,)

    top_indices = np.argpartition(scores, -min(k, n))[-min(k, n):]
    top_indices = top_indices[np.argsort(scores[top_indices])[::-1]]
    return [(urls[i], float(scores[i])) for i in top_indices]


def main(out_dir: Path) -> None:
    corpus_path = out_dir / "corpus.sqlite"
    if not corpus_path.exists():
        # Fallback: pick the first corpus*.sqlite in out_dir
        candidates = sorted(out_dir.glob("corpus*.sqlite"))
        if not candidates:
            raise SystemExit(f"No corpus.sqlite in {out_dir}")
        corpus_path = candidates[0]

    model = load_model()
    for q in KNOWN_BAD_QUERIES:
        qv = embed(model, [q])[0]
        hits = topk(corpus_path, list(qv), k=3)
        print(f"\nQ: {q}")
        for url, score in hits:
            flag = "  ARCHIVE" if "/archives/" in url or "/archive/" in url else ""
            print(f"  [{score:.3f}] {url}{flag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("pipeline/out"))
    args = parser.parse_args()
    main(args.out)
