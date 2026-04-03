# Quiz System Redesign

**Date:** 2026-04-03  
**Status:** Approved  

---

## Problem

The spaced repetition quiz system has 4 interconnected bugs that make it non-functional:

1. **Corrupted data** — All 3,834 existing `QuizItem`s are stuck in box 1 with `correctCount: 0` because answers were never validated correctly.
2. **Broken answer validation** — `correctSentence` stored in `QuizItem` sometimes contains alternatives separated by ` / ` (AI-generated). Both the UI and `submitAnswer` call `.components(separatedBy: " / ").first`, but subtle divergences cause comparisons to fail.
3. **ID collisions** — IDs generated via `hashValue & 0xFFFFFFFF` cause different corrections to share the same ID; duplicates are silently dropped.
4. **No visual feedback** — Quiz options are visually identical; no indication of which was selected before the result screen appears.

Additionally, the quiz only ever shows 2 options (correct vs original wrong sentence), making it too easy and not representative of the user's real error patterns.

---

## Goal

A working spaced repetition quiz that:
- Correctly advances items through Leitner boxes 1–5
- Shows 2–4 options, with distractors drawn from the user's own correction history in the same grammar category
- Gives immediate visual feedback when an option is selected

---

## Design

### Section 1 — Bug Fixes

**1a. Clean `correctSentence` at storage time**

In `SpacedRepetitionManager.parseTip()`, strip alternatives before storing:

```swift
let rightMain = rightPart.components(separatedBy: " / ").first ?? rightPart
return (wrongPart, rightMain.trimmingCharacters(in: .whitespaces), why)
```

`submitAnswer` then compares directly: `answer == quiz.correctSentence` — no re-parsing.

**1b. UUID-based IDs**

Replace hash-based ID generation in `syncFromHistory()`:

```swift
let id = UUID().uuidString
```

**1c. Reset corrupted data on startup**

In `SpacedRepetitionManager.loadReviews()`, after loading, detect corruption and reset:

```swift
let allCorrupted = !items.isEmpty && items.allSatisfy { $0.box == 1 && $0.correctCount == 0 }
if allCorrupted {
    items = []
    try? FileManager.default.removeItem(at: Self.reviewsFile)
}
```

After reset, `syncFromHistory()` recreates items from `history.jsonl` with clean IDs.

---

### Section 2 — DistractorEngine

New file: `Services/DistractorEngine.swift`

**Responsibility:** Given a `QuizItem`, return a shuffled `[String]` of quiz options (correct answer + wrong options).

**Algorithm:**
1. Load all corrections from `history.jsonl` (same parsing as `SpacedRepetitionManager`)
2. Group by `category` (grammar, preposition, spelling, etc.)
3. For the current item's category, collect `incorrectSentence` values from other items (excluding current)
4. Pick up to 2 distractors randomly from that pool
5. Return `[item.correctSentence, item.incorrectSentence] + distractors`, shuffled
6. Fallback: if fewer than 1 distractor available, return `[item.correctSentence, item.incorrectSentence]` (original behavior)

**Interface:**
```swift
struct DistractorEngine {
    static func options(for item: QuizItem, from history: [HistoryCorrection]) -> [String]
}
```

`SpacedRepetitionManager` loads history once and passes it to `DistractorEngine.options(for:from:)` when starting a quiz.

---

### Section 3 — QuizBubbleView UI

**3a. Dynamic options**

Remove `shuffledOptions()`. `QuizBubbleView` receives `options: [String]` as a parameter (passed from `SpacedRepetitionManager` via the `QuizState.asking` case or as a separate property).

`ForEach(options, id: \.self)` already handles any count.

**3b. Selection feedback**

Add `@State private var selectedAnswer: String?` (already exists but unused for styling).

When a button is tapped, set `selectedAnswer` before calling `onSubmit`. Each button reads its highlight state:

```swift
.background(buttonBackground(for: option))

private func buttonBackground(for option: String) -> Color {
    guard let selected = selectedAnswer else {
        return Color.white.opacity(0.08)  // default
    }
    if option == selected {
        return selected == correctAnswer
            ? TerminalColors.green.opacity(0.2)
            : TerminalColors.amber.opacity(0.2)
    }
    return Color.white.opacity(0.04)  // dimmed unselected
}
```

`correctAnswer` is the first option in `options` that matches `quiz.correctSentence` — passed alongside `options`.

---

## Data Flow After Fix

```
history.jsonl
    ↓ syncFromHistory() — UUID IDs, cleaned correctSentence
reviews.json (QuizItems, boxes 1-5)
    ↓ nextDueItem() — picks lowest box that is due
DistractorEngine.options(for:from:) — 2-4 shuffled options
    ↓
QuizBubbleView — ForEach options, selection highlight
    ↓ onSubmit(answer)
submitAnswer() — answer == quiz.correctSentence (direct compare)
    ↓ recordAnswer(correct:) — advances/demotes box
reviews.json updated
```

---

## Files Changed

| File | Change |
|------|--------|
| `Services/SpacedRepetitionManager.swift` | Fix parseTip, UUID IDs, corruption reset, pass options to quiz |
| `Services/DistractorEngine.swift` | **New** — distractor selection logic |
| `Models/QuizItem.swift` | No change |
| `Views/QuizBubbleView.swift` | Accept `options: [String]` + `correctAnswer: String`, add selection highlight |

---

## Out of Scope

- Changing the idle trigger that launches quizzes
- Redesigning the quiz bubble layout or result screen
- Adding new quiz types (fill-in-the-blank, etc.)
