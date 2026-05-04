# pipeline/

Python project that builds the Ask CPCC corpus.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
pytest
```

See `../docs/BUILD_PIPELINE.md` for the full flow, including the CoreML conversion notes.
