# Ask CPCC (iOS)

Universal iOS/iPadOS chat app that answers questions about Central Piedmont Community College using on-device RAG over the public CPCC website + academic catalog + handbook PDFs, plus live guest course-section search via mycollegess.cpcc.edu. LLM via OpenRouter with user-supplied API key.

## Build

```bash
brew install xcodegen swiftlint gh
xcodegen generate
open AskCPCC.xcodeproj
```

Run on iPad Pro/Air 11" or any iPhone running iPadOS 17+.

## Tests

```bash
xcodebuild -project AskCPCC.xcodeproj -scheme AskCPCC \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' test
```

## Pipeline (Python)

See [docs/BUILD_PIPELINE.md](docs/BUILD_PIPELINE.md) for crawling, chunking, embedding, and publishing the corpus to GitHub Releases.

## Design

- Spec: [docs/design.md](docs/design.md)
- Endpoint reference: [docs/ENDPOINTS.md](docs/ENDPOINTS.md)
- Brand notes: [docs/BRAND_NOTES.md](docs/BRAND_NOTES.md)
