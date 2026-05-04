"""BGE-small-en-v1.5 embeddings via sentence-transformers."""
from __future__ import annotations

from pathlib import Path
import numpy as np
from sentence_transformers import SentenceTransformer

MODEL_NAME = "BAAI/bge-small-en-v1.5"
EMBEDDING_DIM = 384


def load_model() -> SentenceTransformer:
    return SentenceTransformer(MODEL_NAME)


def embed(model: SentenceTransformer, texts: list[str], batch_size: int = 64) -> np.ndarray:
    """Return an (N, 384) float32 array of L2-normalized embeddings."""
    if not texts:
        return np.zeros((0, EMBEDDING_DIM), dtype=np.float32)
    vecs = model.encode(
        texts,
        batch_size=batch_size,
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=True,
    )
    return vecs.astype(np.float32)


def write_embeddings_bin(vecs: np.ndarray, path: Path) -> None:
    assert vecs.dtype == np.float32, vecs.dtype
    assert vecs.ndim == 2 and vecs.shape[1] == EMBEDDING_DIM
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as fp:
        fp.write(vecs.tobytes())
