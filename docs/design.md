# Ask CPCC iOS — "Every Answer About CPCC, Cited"

**Date:** 2026-05-03
**Author:** Frazier Smith
**Audience:** Prospective students, current CPCC students, CPCC staff
**Status:** Phase 1 design draft pending implementation plan
**Sibling specs:**
- iOS app patterns reused: `compvis/docs/superpowers/specs/2026-05-02-pill-counter-ios-design.md`
- Existing course-schedule plugin (TS source for endpoint shapes): `Documents/Administrative/CPCC/MyCollege/docs/superpowers/specs/2026-04-01-cpcc-course-schedule-plugin-design.md`

**Phase boundary.** This spec is Phase 1 only — public-website RAG + guest course-schedule queries. Phase 2 (authenticated mycollege features: grades, holds, registration, financial aid, transcripts) is a separate future spec.

---

## 1. Goal & Message

A native universal iOS/iPadOS chat app that answers questions about Central Piedmont Community College using two on-device data sources: a freshly-built RAG index of the public CPCC website plus academic catalog plus handbook PDFs, and a thin client to the public course-section search endpoint at `mycollegess.cpcc.edu`. The app is for prospective students, current students, and staff alike — anyone who has a question that ends in *"…at CPCC?"* and doesn't want to navigate three menus and a PDF to find the answer.

**Core value proposition:**

> Every answer about CPCC, sourced and cited, with current course schedules. Bring your own OpenRouter key.

The user pastes an OpenRouter API key once; from then on the app's behavior is: type a question, see a streamed answer with cited links, with a small badge if the live course schedule was consulted. No accounts, no analytics, no backend. The LLM call goes directly from device to OpenRouter; no question text or user data leaves the device except to OpenRouter.

**What it's not (Phase 1):** anything that requires the user's own mycollege login. No grades, no holds, no financial aid balances, no class roster, no attendance. Those are Phase 2, behind a separate auth flow.

## 2. User Experience

### First launch (one screen)

Friendly explanation of what the app does and what it needs. A single primary button: **"Connect OpenRouter."** Tapping it opens an in-app `SFSafariViewController` to `openrouter.ai/keys` with a brief inline note: *"Create a key, copy it, come back."* Returning to the app reveals a paste field; the user pastes, taps Save, key goes to Keychain. A "Skip for now" link drops them into a read-only demo mode showing one canned Q&A so they understand the app without paying.

### Main chat screen

Pure chat: previous turns above, an input field at the bottom, a send button. Input placeholder rotates through suggestions (*"Ask about a program…"*, *"Search for sections of ENG 111…"*, *"What's the registration deadline?"*).

Each assistant turn renders as:

- **Streamed answer text** (Markdown, tappable inline links).
- **Source row** — small chips below the answer: *"📄 cpcc.edu/financial-aid"*, *"📚 catalog.cpcc.edu/courses/eng-111"*. Tap a chip → opens in `SFSafariViewController`.
- **Optional course-schedule badge** — *"🗓️ 4 live sections"* when the intent classifier triggered a course-schedule lookup. Tap → expandable card with each section's days, times, location, instructor, seats remaining.

User can swipe left on any past assistant turn to copy the answer or share.

### Conversation memory

Last 8 turns (4 user + 4 assistant) included as conversation history in each new request. A "New chat" button in the toolbar resets context. Conversations are not persisted across app relaunches in v1 — fresh start every cold launch.

### Settings (gear icon, top-right)

- **OpenRouter API key** — replace, view (masked), or remove
- **Model** — picker (default: `anthropic/claude-haiku-4-5`; alternates: `openai/gpt-4o-mini`, `google/gemini-2.5-flash`, `anthropic/claude-sonnet-4-6`). Each lists OpenRouter's per-million-token cost.
- **Corpus version** — read-only text showing date of the loaded corpus + a "Check for update" button.
- **Search live course schedule** — toggle (default On). When off, the app skips the mycollege call even on schedule-flavored questions.
- **Reset chat memory** — clears any in-memory conversation.
- **About** — credits, version, link to repo / spec.

### Empty / error states

- No API key: chat input is disabled and the welcome screen is pinned with a *"Connect OpenRouter"* CTA.
- Network failure: inline error inside the failed turn, with a *"Retry"* button. Conversation is preserved.
- Corpus download failure on first launch: app falls back to "ask without sources" mode (no RAG context) and shows a small banner *"Sources unavailable — using OpenRouter only"* until the next successful download.
- Course-schedule call fails: the answer still renders from RAG, with a small note *"Couldn't reach the live schedule — answer based on catalog only."*

### Accessibility

VoiceOver reads message turns, source chips are individually focusable, Dynamic Type supported up to xxLarge, Reduce Motion replaces streaming text with a single insertion.

## 3. Layout & Visual Design

### Universal SwiftUI

Single SwiftUI hierarchy. iPhone gets a one-column chat. iPad gets a `NavigationSplitView` with a sidebar (Settings link + a "scratch pad" of one ongoing thread) and the chat in the detail pane. macOS via Catalyst is **not** in scope.

### iPhone layout (portrait, primary form factor)

```
┌──────────────────────────────────────┐
│ [CPCC mark]  Ask CPCC          ⚙     │  ← 56pt nav bar (Gray #54565A)
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Hi! Ask about CPCC programs,   │  │  ← system intro turn
│  │ courses, deadlines, anything.  │  │
│  └────────────────────────────────┘  │
│                                      │
│              ┌────────────────────┐  │
│              │ When does ENG 111  │  │  ← user turn (right-aligned,
│              │ meet next term?    │  │     Blue #005D83 bubble)
│              └────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ For Fall 2026, ENG 111 has 6   │  │  ← assistant turn (left-aligned,
│  │ open sections. Most meet MWF…  │  │     white card, gray text)
│  │                                │  │
│  │ 📄 catalog.cpcc.edu/eng-111    │  │  ← source chips
│  │ 🗓️  6 live sections           │  │  ← course-schedule badge
│  └────────────────────────────────┘  │
│                                      │
├──────────────────────────────────────┤
│  ┌─────────────────────────────┐ ▶   │  ← input field + send button
│  │ Ask about a program…        │ ⚪  │
│  └─────────────────────────────┘     │
└──────────────────────────────────────┘
```

### iPad layout (landscape primary)

```
┌────────────┬─────────────────────────────────────────────┐
│ [CPCC mark]│ Ask CPCC                              ⚙     │
│            ├─────────────────────────────────────────────┤
│ + New chat │                                             │
│            │   (chat thread, same as iPhone)             │
│ Today      │                                             │
│  Programs  │                                             │
│            │                                             │
│ Settings   │                                             │
│            ├─────────────────────────────────────────────┤
│            │ [ input field… ]                       ▶    │
└────────────┴─────────────────────────────────────────────┘
```

### CPCC color application

| Element | Color | Notes |
|---|---|---|
| Top nav bar | `#54565A` (Gray) | White text + mark |
| User message bubble | `#005D83` (Blue) | White text |
| Assistant card | `#FFFFFF` background, `#54565A` text | Subtle gold `#B4A269` 1pt border |
| Source chips | White card, `#005D83` text + icon | Tap → SFSafariViewController |
| Course-schedule badge | `#B4A269` (Gold) tint | Tap → expandable section detail |
| Send button (active) | `#005D83` (Blue) | Disabled state: gray `#54565A` 50% |
| Streaming dots indicator | Gold `#B4A269` | Three pulsing dots while LLM streams |

### Typography

System SF Pro / SF Pro Rounded. Franklin Gothic isn't App Store-licensable; the brand guide allows the digital fallback path, and SF Pro is the Apple-native equivalent.

- **Title:** SF Pro Rounded 22pt semibold
- **Message body:** SF Pro 17pt regular, line height 22pt
- **Source chip text:** SF Pro 13pt medium
- **Suggestion placeholder:** SF Pro 15pt italic, gray 50%
- **Dynamic Type:** scales up to `xxxLarge`; bubble widths flex; chips wrap to two lines

### Apple HIG specifics

- **Safe areas:** chat scroll respects keyboard and home indicator; input field rises with the keyboard.
- **Touch targets:** ≥44×44pt for send, settings, source chips.
- **Symbols:** SF Symbols (`paperplane.fill`, `gearshape.fill`, `arrow.clockwise`, `link`, `calendar`).
- **Haptics:** `.selection()` on send, light `.impact()` on streaming completion.
- **Streaming animation:** new tokens fade-in over 80 ms; Reduce Motion replaces with instant insert.
- **VoiceOver:** message bubbles read with sender prefix ("You said…", "Ask CPCC said…"); source chips read as buttons with URL announcement.
- **No notifications, no badges, no background tasks** other than the daily corpus version check.

### Logo and app icon

CPCC primary mark (gold favicon-only — sub-165pt rule) at 28pt height in the top nav. App icon: gold mark on Central Piedmont Gray `#54565A`, identical pattern to Pill Counter for visual consistency across CPCC apps on a faculty member's home screen.

## 4. Architecture & Repo

### Repo

New standalone repo at `/Users/frazier/Documents/Projects/cpcc-ask-ios/`. GitHub remote: `github.com/Frazier-at-CPCC/cpcc-ask-ios` (public). Bundle ID `edu.cpcc.AskCPCC` (or `com.frazier.AskCPCC` if signing under a personal team). xcodegen-driven, identical pattern to Pill Counter.

The corpus build pipeline lives in the **same repo** under `pipeline/` so build script and iOS app evolve together. Pipeline runs on your Mac or via GitHub Actions weekly cron.

### High-level architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AskCPCC iOS App                          │
│                                                             │
│   SwiftUI Views ──┐                                         │
│                   │                                         │
│            ┌──────▼──────────┐                              │
│            │  ChatViewModel  │  @Observable, @MainActor     │
│            │  (turns, send)  │                              │
│            └──────┬──────────┘                              │
│                   │                                         │
│        ┌──────────┴──────────┐                              │
│        │                     │                              │
│   ┌────▼────────────┐  ┌─────▼─────────────┐                │
│   │ QueryOrchestr.  │  │ KeychainStore     │                │
│   │ (intent classify│  │ (OpenRouter key)  │                │
│   │  + retrieve     │  └───────────────────┘                │
│   │  + LLM call)    │                                       │
│   └─┬───────┬───────┘                                       │
│     │       │                                               │
│  ┌──▼──┐ ┌──▼─────────┐ ┌──────────────────┐                │
│  │ RAG │ │CourseSched-│ │ OpenRouterClient │                │
│  │Index│ │uleClient   │ │ (streaming)      │                │
│  └──┬──┘ └──┬─────────┘ └─────────┬────────┘                │
│     │      │                      │                         │
│  ┌──▼──────▼──┐                   │                         │
│  │EmbeddingModel│                 │                         │
│  │(CoreML BGE) │                  │                         │
│  └──────────┬──┘                  │                         │
│             │                     │                         │
│         ┌───▼─────────┐           │                         │
│         │ CorpusStore │           │                         │
│         │ (SQLite +   │           │                         │
│         │  vectors)   │           │                         │
│         └───┬─────────┘           │                         │
└─────────────┼───────────────────┬─┴─────────────────────────┘
              │                   │
              ▼                   ▼                ▼
       GitHub Releases    mycollegess.cpcc.edu   openrouter.ai
       (corpus.zip)       (PostSearchCriteria)   (chat completions)
```

### File tree

```
cpcc-ask-ios/
├── AskCPCC.xcodeproj                    # generated by xcodegen
├── project.yml
├── .swiftlint.yml
├── .gitignore
├── README.md
├── latest.json                          # corpus version pointer (committed to main)
│
├── AskCPCC/                              # iOS app target
│   ├── AskCPCCApp.swift                  # @main
│   ├── Info.plist
│   ├── Assets.xcassets/                  # CPCC colors, mark, app icon
│   ├── Resources/
│   │   ├── intro.json                    # canned demo Q&A for "Skip for now"
│   │   └── bge-small-en-v1.5.mlpackage   # CoreML embedding model (33 MB)
│   │
│   ├── App/
│   │   ├── ChatViewModel.swift           # @Observable chat state
│   │   ├── ChatTurn.swift                # struct: id, role, text, sources, scheduleHits
│   │   ├── Settings.swift                # @Observable user settings (model, etc.)
│   │   └── KeychainStore.swift           # OpenRouter key storage
│   │
│   ├── Branding/
│   │   ├── CPCCColors.swift
│   │   └── CPCCFonts.swift
│   │
│   ├── Orchestration/
│   │   ├── QueryOrchestrator.swift       # main entry per question
│   │   ├── IntentClassifier.swift        # regex/keyword router
│   │   └── PromptBuilder.swift           # turns RAG context + schedule into a prompt
│   │
│   ├── RAG/
│   │   ├── RAGIndex.swift                # top-level retrieval API
│   │   ├── CorpusStore.swift             # SQLite reader (chunks + URLs)
│   │   ├── VectorStore.swift             # in-memory float arrays + cosine search
│   │   ├── EmbeddingModel.swift          # CoreML wrapper (bge-small-en-v1.5)
│   │   └── CorpusUpdater.swift           # daily GitHub Releases version check
│   │
│   ├── CourseSchedule/
│   │   ├── CourseScheduleClient.swift    # POST /Student/Courses/PostSearchCriteria
│   │   ├── CourseScheduleAuth.swift      # CSRF token + cookie management
│   │   ├── SectionResult.swift           # struct: courseCode, title, sections[]
│   │   └── Section.swift                 # struct: id, days, time, location, instructor, seats
│   │
│   ├── LLM/
│   │   ├── OpenRouterClient.swift        # streaming chat completions
│   │   ├── OpenRouterModel.swift         # enum of available models + costs
│   │   └── ChatMessage.swift             # role + content for the API
│   │
│   └── Views/
│       ├── RootView.swift                # NavigationSplitView wrapper
│       ├── Chat/
│       │   ├── ChatView.swift            # message list + input
│       │   ├── MessageBubble.swift       # one chat turn
│       │   ├── SourceChip.swift          # tappable URL chip
│       │   ├── ScheduleBadge.swift       # "🗓️ N live sections" expandable
│       │   ├── ScheduleSectionRow.swift  # one section in expanded view
│       │   ├── StreamingDots.swift       # three pulsing dots
│       │   └── InputBar.swift            # TextField + send button
│       ├── Onboarding/
│       │   ├── OnboardingView.swift      # welcome + connect OpenRouter
│       │   └── ApiKeyPasteView.swift     # paste, validate, save
│       ├── Settings/
│       │   ├── SettingsView.swift
│       │   ├── ModelPickerView.swift
│       │   └── AboutView.swift
│       └── ErrorBanner.swift             # corpus / network failure banners
│
├── AskCPCCTests/                         # XCTest
│   ├── IntentClassifierTests.swift
│   ├── PromptBuilderTests.swift
│   ├── VectorStoreTests.swift
│   ├── CorpusStoreTests.swift
│   ├── KeychainStoreTests.swift
│   └── ChatViewModelTests.swift
│
├── pipeline/                             # corpus build (Python)
│   ├── README.md
│   ├── pyproject.toml
│   ├── requirements.txt
│   ├── build_corpus.py                   # main entry: crawl → chunk → embed → write
│   ├── crawlers/
│   │   ├── cpcc_main.py                  # cpcc.edu
│   │   ├── cpcc_catalog.py               # catalog.cpcc.edu
│   │   └── cpcc_pdfs.py                  # handbook + policy PDFs
│   ├── chunker.py                        # splits + cleans HTML/PDF text
│   ├── embedder.py                       # bge-small-en-v1.5 via sentence-transformers
│   ├── writer.py                         # writes corpus.sqlite + manifest.json
│   ├── upload_release.py                 # publishes to GitHub Releases
│   └── tests/
│       └── test_chunker.py               # smoke test on a small fixture
│
├── .github/workflows/
│   └── refresh-corpus.yml                # weekly cron: build_corpus + open PR
│
└── docs/
    ├── design.md                         # copy of this spec
    ├── BUILD_PIPELINE.md                 # how to run the pipeline manually
    ├── BRAND_NOTES.md                    # CPCC color/logo notes
    └── ENDPOINTS.md                      # mycollegess.cpcc.edu endpoints we use
```

### Module boundaries

- **`RAG/`** — pure retrieval. Inputs: a query string. Outputs: `[Chunk]` with text, URL, similarity score. No SwiftUI, no LLM.
- **`CourseSchedule/`** — pure HTTP client over Ellucian's JSON endpoint. Inputs: search criteria. Outputs: `SectionResult`. No SwiftUI, no LLM.
- **`LLM/`** — pure OpenRouter wrapper, stream of tokens. No business logic.
- **`Orchestration/`** — the only module that knows how all three fit together. Stateless.
- **`App/ChatViewModel`** — single source of truth for chat state, calls the orchestrator.
- **`Views/`** — pure SwiftUI; reads `ChatViewModel`, never touches RAG/CourseSchedule/LLM directly.
- **`Branding/`** — leaf module.

### Concurrency

- `ChatViewModel` runs on `@MainActor`.
- `QueryOrchestrator` is `actor`; orchestration is async, with token streaming via `AsyncStream<String>` back to the view model.
- `RAGIndex` is `actor` (single shared in-memory vector store; loaded once on launch).
- `CourseScheduleClient` is a final class with a `URLSession`; cookie store is the iOS default container.
- `OpenRouterClient` uses `URLSession.bytes(for:)` for SSE streaming.
- `CorpusUpdater` runs as a background `Task` from `App.task`, with a soft "skip if checked in last 24 h" guard.

### Storage

- **Keychain:** OpenRouter API key only. Service `edu.cpcc.AskCPCC.openrouter`. Nothing else.
- **App support directory:** `corpus.sqlite` + `embeddings.bin` + `corpus_manifest.json` — atomically replaced when a new corpus arrives.
- **`UserDefaults`:** model selection, last corpus check timestamp, "search live schedule" toggle, demo-mode flag.
- **No persisted chat history** in v1. Conversation lives in memory only.

## 5. Corpus Build Pipeline

### Inputs (the three sources)

1. **`cpcc.edu`** — main institutional site. Programs, admissions, financial aid, student services, policies, academic calendar, campus info, "About" pages.
2. **`catalog.cpcc.edu`** — academic catalog. Course descriptions, program requirements, degree maps, transfer information.
3. **PDF handbooks/policies** — student handbook, faculty handbook, board policies (linked from `cpcc.edu`). The pipeline downloads, parses, and indexes these alongside HTML pages.

### Pipeline stages (Python, runs on Mac or GitHub Actions)

```
┌──────────────────────────────────────────────────────────┐
│                   build_corpus.py                        │
│                                                          │
│  Stage 1: Crawl                                          │
│   ├─ cpcc_main.py        → list of HTML pages + URLs     │
│   ├─ cpcc_catalog.py     → list of catalog HTML pages    │
│   └─ cpcc_pdfs.py        → list of PDF binaries          │
│                            ↓                             │
│  Stage 2: Extract                                        │
│   └─ For each page: title, body text, source URL         │
│       (BeautifulSoup for HTML, pdfplumber for PDF)       │
│                            ↓                             │
│  Stage 3: Chunk                                          │
│   └─ chunker.py — sliding window 600 chars, 100 overlap  │
│                            ↓                             │
│  Stage 4: Embed                                          │
│   └─ embedder.py — BAAI/bge-small-en-v1.5 (384-dim)      │
│                            ↓                             │
│  Stage 5: Write                                          │
│   └─ corpus.sqlite (chunks table + FTS5 index)           │
│      embeddings.bin (raw float32 array, N×384)           │
│      manifest.json (version, date, source counts)        │
│                            ↓                             │
│  Stage 6: Package + Upload                               │
│   └─ zip → GitHub Release asset corpus-YYYY-MM-DD.zip    │
└──────────────────────────────────────────────────────────┘
```

### Stage details

**Stage 1 — Crawl.** Three focused crawlers, each in `pipeline/crawlers/`:

- `cpcc_main.py` — starts at `https://www.cpcc.edu/`, follows internal links up to depth 4, respects `robots.txt`, throttles to 1 req/sec, skips assets, image directories, and event-calendar querystring noise. Allowlist seed: `/programs`, `/admissions`, `/financial-aid`, `/student-services`, `/about`, `/academic-calendar`, `/policies`. Hard cap 3000 pages.
- `cpcc_catalog.py` — starts at `https://catalog.cpcc.edu/`, walks the program/course tree, captures full course descriptions including prereqs and credits.
- `cpcc_pdfs.py` — gathers PDF URLs discovered during crawl 1 + an explicit allowlist (`student-handbook.pdf`, `faculty-handbook.pdf`, board-policy URLs). Downloads once, deduplicates by SHA-256.

Output: `pipeline/raw/` directory containing one JSON-Lines file per crawler with `{url, title, html, sha256}` records.

**Stage 2 — Extract.** Plain-text extraction. HTML via BeautifulSoup, stripping nav, footer, share-bar boilerplate. PDFs via `pdfplumber`. Output: per-page `{url, title, text}` records.

**Stage 3 — Chunk.** `chunker.py` splits each page into sliding windows of ~600 characters with 100-character overlap, preserving paragraph boundaries when possible. A page typically yields 3–15 chunks. Total estimated corpus size: ~10,000–25,000 chunks across ~3000 pages and ~50 PDFs.

**Stage 4 — Embed.** `embedder.py` loads `BAAI/bge-small-en-v1.5` via `sentence-transformers` (Python). Encodes all chunks in batches of 64 on whatever CPU/GPU the host has (M-series Macs use MPS automatically). 384-dim float32 vectors. Embedding 25k chunks takes ~3–5 minutes on an M-series Mac.

**Stage 5 — Write.**

```sql
CREATE TABLE chunks (
    id INTEGER PRIMARY KEY,
    source_url TEXT NOT NULL,
    title TEXT,
    text TEXT NOT NULL,
    char_offset INTEGER,
    page_section TEXT
);

CREATE VIRTUAL TABLE chunks_fts USING fts5(text, content='chunks', content_rowid='id');
```

Embeddings written separately to `embeddings.bin` as a packed float32 array (N × 384). Order matches `chunks.id` so a chunk's vector is at byte offset `id * 384 * 4`. iOS app `mmap`s it.

`manifest.json`:

```json
{
  "version": "2026-05-03",
  "buildTimestamp": "2026-05-03T14:22:11Z",
  "sources": {
    "cpcc.edu": 2847,
    "catalog.cpcc.edu": 412,
    "pdfs": 47
  },
  "totalChunks": 18342,
  "embeddingModel": "BAAI/bge-small-en-v1.5",
  "embeddingDim": 384,
  "minAppVersion": "1.0.0"
}
```

`minAppVersion` lets you publish a corpus that only newer app versions should accept (in case you ever change the chunk schema).

**Stage 6 — Package + Upload.** `pipeline/upload_release.py`:

1. Zips `corpus.sqlite` + `embeddings.bin` + `manifest.json` into `corpus-YYYY-MM-DD.zip` (~30–80 MB compressed).
2. Uses GitHub CLI (`gh release create`) to publish a release tagged `corpus-YYYY-MM-DD`. Asset is the zip.
3. Also updates `latest.json` on the repo's `main` branch: `{ "version": "...", "url": "https://github.com/Frazier-at-CPCC/cpcc-ask-ios/releases/download/...", "size": ..., "sha256": "..." }`. iOS app polls only this small file.

### iOS app: discovery + download flow

On launch, in a background `Task`:

1. Skip if `lastChecked < 24h ago` (per `UserDefaults`).
2. Fetch `https://raw.githubusercontent.com/Frazier-at-CPCC/cpcc-ask-ios/main/latest.json`.
3. Compare `version` to the locally-loaded `manifest.json`.
4. If newer: download the zip, verify SHA-256, atomically swap the corpus directory, hot-reload `RAGIndex`. UI shows a small "Updated to corpus 2026-05-03" toast.
5. If equal: nothing.
6. If failure (network, signature mismatch): keep current corpus, log, retry tomorrow.

### Refresh cadence

`refresh-corpus.yml` GitHub Actions workflow runs every Monday at 06:00 ET. The order matters: the release asset must exist *before* `latest.json` is merged, otherwise iOS apps would briefly try to download a not-yet-published asset.

1. Run `build_corpus.py` to produce `corpus.sqlite` + `embeddings.bin` + `manifest.json`.
2. Run `upload_release.py` to zip them and `gh release create corpus-YYYY-MM-DD` (asset published immediately).
3. Open a PR titled "chore: refresh corpus YYYY-MM-DD" containing only the new `latest.json` pointing at the just-published release URL + SHA-256.
4. You review the PR, sanity-check `manifest.json`, merge.
5. Within 24 h, every running app sees the bumped `latest.json` and downloads the new corpus.

### Build pipeline costs

- Crawl: free (we ARE the polite scraper, throttled).
- Embedding: free (open-weight model, runs on local CPU/GPU).
- GitHub Releases: free for public repos.
- GitHub Actions: free for public repos under 2000 minutes/month; this job ~10 min weekly = 40 min/month.

**Net infra cost: $0/month.**

### What we deliberately don't do

- **No live re-crawl per query.** Corpus is rebuilt weekly; same-day events fall back to "I'm not sure about this week's events — check cpcc.edu/calendar."
- **No cross-encoder re-ranking** in v1. Bi-encoder retrieval is enough.
- **No multilingual embeddings.** English only. (Phase 2 add: `bge-m3` or similar.)
- **No semantic dedup.** Near-duplicate chunks across pages are accepted.
- **No image OCR** in PDFs. Scanned-image PDFs are skipped with a warning.

## 6. Runtime: Query Flow

### End-to-end per question

```
User types: "When does ENG 111 meet next term?"
                    │
                    ▼
        ┌───────────────────────┐
        │ ChatViewModel.send()  │ — appends user turn, creates pending assistant turn
        └───────────┬───────────┘
                    ▼
        ┌──────────────────────────┐
        │ QueryOrchestrator        │
        │  .answer(question, ctx)  │
        └───────────┬──────────────┘
                    ▼
        ┌──────────────────────────┐
        │ IntentClassifier         │ — returns .needsSchedule(courseCode: "ENG 111")
        └───────────┬──────────────┘
                    ▼
       ┌────────────┴───────────────┐
       │                            │
       ▼                            ▼
┌──────────────────┐      ┌────────────────────┐
│ RAGIndex.search  │      │ CourseScheduleClient│
│ (top 6 chunks)   │      │ .searchSections    │
└────────┬─────────┘      │ ("ENG 111", term)  │
         │                └─────────┬──────────┘
         └─────────┬────────────────┘
                   ▼
        ┌──────────────────────────┐
        │ PromptBuilder            │
        │  .build(question, chunks,│
        │         sections, hist.) │
        └───────────┬──────────────┘
                    ▼
        ┌──────────────────────────┐
        │ OpenRouterClient         │
        │  .stream(messages, model)│
        └───────────┬──────────────┘
                    ▼
        AsyncStream<String> tokens → ChatViewModel.appendTokens(...)
                    │
                    ▼
        After last token: attach sources + scheduleHits to the turn
                    │
                    ▼
        UI renders the streamed answer, source chips, schedule badge
```

### IntentClassifier (deterministic, ~30 lines)

Pure Swift, fully unit-testable. Returns one of:

```swift
enum Intent {
    case ragOnly
    case needsSchedule(courseCode: String?, subject: String?)
}
```

Logic:
1. **Course-code regex** `\b([A-Z]{2,4})[\s-]?(\d{2,3})\b` — matches `ENG 111`, `MAT-271`, `CSC214`. If found → `.needsSchedule(courseCode: ..., subject: nil)`.
2. **Schedule keyword scan** (case-insensitive): `section`, `sections`, `meets`, `meeting time`, `schedule`, `seats`, `open seats`, `register for`, `available`, `who teaches`, `instructor for`. If matched without a course code → `.needsSchedule(courseCode: nil, subject: parsedSubject)`.
3. **Subject keyword** scan against the list of CPCC subject codes (loaded once from corpus): if a question mentions "english" near "section", parse subject = `ENG`.
4. Default → `.ragOnly`.

If "search live course schedule" toggle in Settings is **off**, force `.ragOnly` regardless.

### RAG retrieval

Always runs. `RAGIndex.search(query, k: 6)`:

1. Encode the query with the on-device CoreML BGE model → 384-dim vector.
2. Brute-force cosine similarity against the mmapped `embeddings.bin` (Accelerate `vDSP_dotpr` per row; 18k rows × 384 floats ≈ 5–8 ms on M-series).
3. Take top-6 indices. Look up text + URL from `chunks` table by id.
4. Return `[Chunk]` sorted by score descending.
5. Hybrid retrieval (BM25 from `chunks_fts` merged with cosine top-6) is gated behind `enableHybridSearch = false` for v1; Phase 2 polish.

### Course-schedule lookup (when intent triggers it)

`CourseScheduleClient.searchSections` POSTs to `https://mycollegess.cpcc.edu/Student/Student/Courses/PostSearchCriteria`:

```swift
struct SearchCriteria: Encodable {
    let keyword: String?           // "ENG 111" or subject name
    let subjectCode: String?       // "ENG"
    let courseNumber: String?      // "111"
    let termId: String             // "FALL2026"  (auto-detected: "next open term")
    let openSectionsOnly: Bool = false
    let pageSize: Int = 25
}
```

Response is parsed into `[Section]` with the fields users see (days, time, location, instructor, seats remaining, section number, term).

**CSRF + cookie handling.** First call ever in app session: `GET https://mycollegess.cpcc.edu/Student/Student/Courses` (catalog landing page). Parse HTML for `__RequestVerificationToken` input value. Cache token + cookies for the session. On subsequent POSTs, include `__RequestVerificationToken: <token>` header. If response is 401/302 (token expired), re-fetch landing page and retry once.

`CourseScheduleAuth` encapsulates this. Public surface: `func ensureFresh() async throws -> AuthState` returning a struct with the current token. `CourseScheduleClient.searchSections` calls `ensureFresh()` before each request.

**Term auto-detection.** First session: `GET /Student/Courses` returns a page with embedded JSON listing available terms. Cache the list. Classifier defaults to "next open term" (current registration window).

### PromptBuilder

Constructs the messages array passed to OpenRouter:

```
SYSTEM:
You are Ask CPCC, an assistant that answers questions about Central
Piedmont Community College using only the provided context. Cite
sources at the end of each claim using [n] markers matching the
context entries below. If the answer isn't in the context, say so —
don't fabricate. Keep answers concise (under 200 words unless the
question demands detail). Today's date is {YYYY-MM-DD}.

CONTEXT:
[1] {chunk[0].text}
    Source: {chunk[0].source_url}
[2] {chunk[1].text}
    Source: {chunk[1].source_url}
... up to [6]

LIVE COURSE SCHEDULE (only if intent triggered it):
[s1] ENG 111 — College Composition (3 credits)
     Section 12345: MWF 9:00–9:50, Central Campus, Smith J., 4 seats open
     Section 12346: TR 10:00–11:15, Levine Campus, Doe A., FULL
     ...

CONVERSATION HISTORY (last 4 turns):
USER: ...
ASSISTANT: ...

USER: When does ENG 111 meet next term?
```

The LLM is instructed to use `[n]` source markers; the iOS app post-processes the response to turn them into tappable inline links. Schedule sections are rendered separately as the expandable schedule badge.

### OpenRouter call

`OpenRouterClient.stream(messages, model)` POSTs to `https://openrouter.ai/api/v1/chat/completions` with `stream: true`. SSE response parsed line-by-line into an `AsyncStream<String>`. Headers:

- `Authorization: Bearer <key from Keychain>`
- `HTTP-Referer: https://github.com/Frazier-at-CPCC/cpcc-ask-ios`
- `X-Title: Ask CPCC`

Error handling:
- 401 invalid key → `OpenRouterError.invalidKey` → UI shows "Your API key seems wrong. Update in Settings." with a deep link to Settings.
- 429 rate limit → backoff + retry once with `Retry-After`. Persistent → "Try again in a moment."
- 5xx → retry once after 1 s. Persistent → "OpenRouter is having trouble. Try again."
- Network → "No connection — check Wi-Fi."

### Streaming UI behavior

`ChatViewModel` appends each incoming token to the pending assistant turn's `text`. `MessageBubble` re-renders. After stream closes:

1. Post-process `text` to replace `[n]` markers with markdown links.
2. Attach `sources: [chunks[0..k].url]` to the turn.
3. If schedule lookup ran, attach `scheduleHits: [Section]`.
4. Trigger streaming-dots-stop animation, light haptic on completion.

### Latency budget (M2 iPad / iPhone 15)

| Stage | Time | Notes |
|---|---|---|
| Intent classify | < 1 ms | regex match |
| Query embed (CoreML BGE) | 30–60 ms | one-time per question |
| Vector search (cosine vs mmap) | 5–10 ms | 18k × 384 floats |
| Course schedule fetch | 200–600 ms | only when intent triggers |
| OpenRouter time-to-first-token | 400–1500 ms | model-dependent |
| Total time-to-first-token | < 1 s typical | 2 s worst case |

Streaming dots cover the wait; users see motion within 100 ms.

### Conversation memory rules

- Last 4 user/assistant pairs included verbatim.
- Older history is dropped — no summarization in v1 (cheap, simple, "New chat" button is the escape hatch).
- Same RAG retrieval runs for every new question; previous turns are never used to rewrite the query in v1. (Phase 2 polish: query rewriting.)

## 7. Privacy, Security & Open Items

### Privacy posture

The app is designed to expose as little as possible:

- **No backend.** Nothing about the user's questions reaches a server controlled by you or CPCC. The only outbound destinations are `mycollegess.cpcc.edu` (public catalog), `openrouter.ai` (LLM), and `github.com` (corpus + `latest.json`).
- **No analytics, no telemetry, no crash reporters.** Crash reports go through the user's normal "Share with App Developers" iOS toggle; no SDK.
- **No user account.** No sign-in, no email collection, nothing stored on the device that ties to identity.
- **API key is the user's, not yours.** Stored only in iOS Keychain. Removable from Settings. The `HTTP-Referer` header sent to OpenRouter identifies the app, not the user.
- **Conversation history lives in RAM only.** Cold launch = clean slate.
- **Course-schedule queries are public data.** No login, no personal info.

### Security model

| Threat | Mitigation |
|---|---|
| Stolen device → API key extraction | Keychain `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. |
| Compromised corpus.zip on GitHub | SHA-256 in `latest.json` is verified before swap. `latest.json` itself is on a public repo's `main` branch — protected by GitHub branch-protection + your account 2FA. Phase 2 polish: detached signature using a Sigstore key. |
| Rogue server impersonating mycollegess.cpcc.edu | App sets `URLSessionConfiguration.tls...minimumProtocolVersion = .TLSv13` and uses ATS defaults. Cert pinning is **out of scope** for v1. |
| Prompt injection via crawled CPCC content | System prompt instructs the LLM to treat context as data, not instructions; we don't plumb LLM output back into a tool call (Approach 1 is deterministic). |
| Key extraction via reverse-engineering the .ipa | N/A — we don't bundle a key. |
| OpenRouter outage | Graceful degradation: clear error message, retry button, conversation preserved. |
| Corpus refresh fails repeatedly | Stale corpus is used; banner notifies user. App still answers from older sources. |

### Open items

1. **Apple Developer signing** — same as Pill Counter (personal team for development; no TestFlight in v1).
2. **Default model** — spec lists `anthropic/claude-haiku-4-5`. Confirm taste; alternates listed in Settings.
3. **Term auto-detection logic** — confirm by testing once a working CSRF flow is in place; Ellucian sometimes returns terms in non-obvious order.
4. **Catalog crawler etiquette** — `catalog.cpcc.edu` may be Modern Campus Acalog (a common CMS) with preferred export endpoints. Adjust crawler if discovered during Stage-1 implementation.
5. **PDF allowlist** — first crawl will discover PDFs; audit and pin an explicit allowlist in `pipeline/cpcc_pdfs.py` to prevent future crawls from sweeping in irrelevant PDFs.

### Out of scope (v1)

- **Authenticated mycollege features** — grades, holds, registration, financial aid balance, transcripts. **Phase 2 spec.**
- **Function-calling / tool-use orchestration** — the LLM cannot drive course-schedule queries directly. Phase 2 polish.
- **Hybrid retrieval (BM25 + cosine merge)** — bi-encoder only in v1. Phase 2 polish.
- **Cross-encoder re-ranking** — same.
- **Query rewriting from conversation history** — Phase 2 polish.
- **Persisted chat history.** Conversations gone on relaunch.
- **Push notifications** — none.
- **Multilingual support.** English only.
- **Image input or output.** Text only.
- **Voice input or TTS output.** None.
- **macOS Catalyst.** iOS + iPadOS only.
- **TestFlight / App Store distribution.** Personal Xcode build only.
- **MDM / Configurator kiosk.** Not relevant.
- **CPCC-paid LLM key, server gateway, abuse monitoring.** All ruled out by user-supplied-key choice.
- **Custom Franklin Gothic typography.** SF Pro only.

## 8. Build Plan

| Week | Focus | Deliverables |
|---|---|---|
| **1** | Pipeline foundations | `pipeline/` Python project. Crawlers for `cpcc.edu` + `catalog.cpcc.edu`. Chunker. BGE embedder. SQLite + embeddings.bin writer. First successful local corpus build (~10k chunks). PDFs deferred to Week 4. |
| **2** | iOS shell + RAG | xcodegen project, CPCC brand assets, SwiftLint. CoreML BGE model wrapper. RAGIndex with cosine search. CorpusUpdater + GitHub Releases download flow. ChatViewModel skeleton. KeychainStore for OpenRouter key. |
| **3** | LLM + chat UI | OpenRouterClient with streaming. PromptBuilder. ChatView with bubbles, source chips, streaming dots. OnboardingView. SettingsView with model picker. Working end-to-end "ask, get answer with citations" loop. |
| **4** | Course schedule + polish | CourseScheduleClient + CSRF/cookie auth. IntentClassifier with unit tests. ScheduleBadge UI + expansion. PDF crawler. GitHub Actions weekly cron. README + endpoints docs. First field test on real iPhone + iPad. |

**Roles assumed:**

- **You:** all of it. Single developer.
- **CPCC IT:** zero involvement (Phase 1 is all public data + user-supplied keys).

## 9. References

- Existing OpenTabs plugin (TS source for the Ellucian `PostSearchCriteria` shape): `/Users/frazier/cpcc-course-schedule/`
- Existing OpenTabs plugin (TS source for CSRF/cookie pattern, faculty endpoints reserved for Phase 2): `/Users/frazier/cpcc-selfservice/`
- BAAI/bge-small-en-v1.5: https://huggingface.co/BAAI/bge-small-en-v1.5
- OpenRouter API: https://openrouter.ai/docs
- Apple HIG (iOS): https://developer.apple.com/design/human-interface-guidelines/designing-for-ios
- CPCC brand: per `cpcc-branding` skill in `~/.claude/skills/`
- Sibling iOS spec (Pill Counter, for app-pattern reuse): `compvis/docs/superpowers/specs/2026-05-02-pill-counter-ios-design.md`
- Original course-schedule plugin spec: `Documents/Administrative/CPCC/MyCollege/docs/superpowers/specs/2026-04-01-cpcc-course-schedule-plugin-design.md`
