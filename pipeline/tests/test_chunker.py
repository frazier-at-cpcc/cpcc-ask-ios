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


def test_html_extract_with_frequent_paragraphs_does_not_overfragment():
    """Regression test for the over-fragmentation bug from corpus-2026-05-04.

    HTML extracts have many short \\n\\n-separated lines (links, list items,
    headings). The chunker must not turn this into a flood of tiny chunks.
    """
    paragraphs = ["Short item " + str(i) for i in range(120)]
    text = "\n\n".join(paragraphs)  # ~1500 chars total, 120 \n\n separators

    chunks = chunk_text(text, max_chars=600, overlap=100)
    assert len(chunks) <= 5, f"expected ≤5 chunks, got {len(chunks)}"
    # Every chunk should be substantive — no microchunks.
    assert all(len(c) >= 100 for c in chunks), \
        f"found short chunks: {[len(c) for c in chunks if len(c) < 100]}"


def test_min_chunk_size_enforced():
    """Even when paragraph boundaries are close to start, chunks should
    cluster up to at least min size before splitting."""
    text = "A. " * 200 + "\n\n" + "B. " * 200  # ~1200 chars total
    chunks = chunk_text(text, max_chars=600, overlap=100)
    # Should not produce a tiny chunk just because \n\n appears at offset ~600
    for c in chunks:
        assert len(c) >= 100, f"too-small chunk: {len(c)} chars"


from pipeline.chunker import chunk_markdown


def test_chunk_markdown_splits_on_h2():
    md = "# Title\n\nIntro paragraph.\n\n## Section A\n\n" + ("A. " * 200) + "\n\n## Section B\n\n" + ("B. " * 200)
    chunks = chunk_markdown(md, max_chars=600, overlap=100)
    # Section A and B should not be glued together
    a_chunks = [c for c in chunks if "A. " in c and "B. " not in c]
    b_chunks = [c for c in chunks if "B. " in c and "A. " not in c]
    assert a_chunks, "expected section A chunks"
    assert b_chunks, "expected section B chunks"


def test_chunk_markdown_preserves_short_section_in_one_chunk():
    md = "# Title\n\nShort.\n\n## Heading\n\nAnother short paragraph."
    chunks = chunk_markdown(md, max_chars=600, overlap=100)
    assert len(chunks) == 1
    assert "Short." in chunks[0]
    assert "Another short paragraph." in chunks[0]


def test_chunk_markdown_falls_back_to_size_split_within_long_section():
    """A single section longer than max_chars uses chunk_text size splits."""
    long_section = "# Title\n\n" + ("Repeated. " * 200)
    chunks = chunk_markdown(long_section, max_chars=600, overlap=100)
    assert len(chunks) >= 2
    assert all(len(c) <= 600 for c in chunks)


def test_chunk_markdown_empty_input_returns_empty_list():
    assert chunk_markdown("", max_chars=600, overlap=100) == []
