from pipeline.chunker import chunk_text


def test_short_text_yields_single_chunk():
    text = "Hello CPCC."
    chunks = chunk_text(text, max_chars=600, overlap=100)
    assert len(chunks) == 1
    assert chunks[0] == "Hello CPCC."


def test_long_text_splits_with_overlap():
    text = "A" * 1500
    chunks = chunk_text(text, max_chars=600, overlap=100)
    assert len(chunks) == 3
    assert all(len(c) <= 600 for c in chunks)
    # Adjacent chunks share 100 chars
    assert chunks[0][-100:] == chunks[1][:100]


def test_paragraph_boundary_preserved_when_possible():
    para1 = "Paragraph one. " * 20  # ~300 chars
    para2 = "Paragraph two. " * 20
    text = para1 + "\n\n" + para2
    chunks = chunk_text(text, max_chars=600, overlap=100)
    # First chunk should end at the paragraph boundary, not mid-sentence
    assert chunks[0].rstrip().endswith(".")


def test_empty_text_returns_empty_list():
    assert chunk_text("", max_chars=600, overlap=100) == []


def test_whitespace_only_returns_empty_list():
    assert chunk_text("   \n\t\n  ", max_chars=600, overlap=100) == []
