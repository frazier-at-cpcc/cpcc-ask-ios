# Endpoints used by Ask CPCC

## OpenRouter

- `POST https://openrouter.ai/api/v1/chat/completions` (streaming)
  - Headers: `Authorization: Bearer <key>`, `HTTP-Referer: https://github.com/Frazier-at-CPCC/cpcc-ask-ios`, `X-Title: Ask CPCC`
  - Body: `{ model, messages, stream: true }`

## mycollegess.cpcc.edu (Ellucian Colleague Self-Service, guest course catalog)

- `GET https://mycollegess.cpcc.edu/Student/Student/Courses` — landing page; CSRF token via `__RequestVerificationToken` input
- `POST https://mycollegess.cpcc.edu/Student/Student/Courses/PostSearchCriteria` — section search
  - Headers: `Content-Type: application/json`, `__RequestVerificationToken: <token>`
  - Body: `{ keyword, subjectCode, courseNumber, termId, openSectionsOnly, pageSize }`

## GitHub

- `GET https://raw.githubusercontent.com/Frazier-at-CPCC/cpcc-ask-ios/main/latest.json` — corpus version pointer
- `GET https://github.com/Frazier-at-CPCC/cpcc-ask-ios/releases/download/corpus-YYYY-MM-DD/corpus-YYYY-MM-DD.zip` — corpus payload
