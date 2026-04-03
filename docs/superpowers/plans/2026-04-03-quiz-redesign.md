# Quiz System Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix broken spaced repetition quiz (validation, IDs, data corruption) and add history-based dynamic distractors.

**Architecture:** Create `DistractorEngine` as the single place for history parsing and option generation. Fix `SpacedRepetitionManager` to store clean data, use UUID IDs, and detect corrupted state on startup. Update `QuizBubbleView` to consume dynamic options and show selection highlight.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 15+. No test target — verification is build + manual run.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `periquito-app/periquito/Services/DistractorEngine.swift` | **Create** | `HistoryCorrection` type, history parsing, distractor selection |
| `periquito-app/periquito/Services/SpacedRepetitionManager.swift` | Modify | Remove private `CorrectionEntry`, use `HistoryCorrection`, UUID IDs, corruption reset, `currentOptions` |
| `periquito-app/periquito/Views/QuizBubbleView.swift` | Modify | Accept `options: [String]` + `correctAnswer: String`, selection highlight |
| `periquito-app/periquito/Views/ExpandedPanelView.swift` | Modify | Pass `quizManager.currentOptions` + `correctAnswer` to `QuizBubbleView` |

---

### Task 1: Create DistractorEngine with HistoryCorrection type

**Files:**
- Create: `periquito-app/periquito/Services/DistractorEngine.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// Shared type representing a parsed correction from history.jsonl
struct HistoryCorrection {
    let id: String
    let wrong: String
    let right: String
    let why: String
    let category: String
}

/// Builds shuffled quiz option arrays from correction history.
struct DistractorEngine {

    /// Returns shuffled quiz options for a quiz item.
    /// - Pulls up to 2 extra distractors from the same category in `corrections`.
    /// - Falls back to [correctSentence, incorrectSentence] if not enough history.
    static func options(for item: QuizItem, from corrections: [HistoryCorrection]) -> [String] {
        let sameCategory = corrections.filter {
            $0.category == item.category && $0.wrong != item.incorrectSentence
        }

        let distractors = Array(sameCategory.shuffled().prefix(2).map(\.wrong))
        let pool = [item.correctSentence, item.incorrectSentence] + distractors
        return pool.shuffled()
    }

    /// Loads and parses all corrections from history.jsonl.
    static func loadFromHistory() async -> [HistoryCorrection] {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".english-learning")
            .appendingPathComponent("history.jsonl")

        return await Task.detached {
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                return []
            }

            var corrections: [HistoryCorrection] = []
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let data = trimmed.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = obj["type"] as? String,
                      type == "correction",
                      let tip = obj["tip"] as? String else { continue }

                let category = obj["category"] as? String ?? "grammar"
                let parsed = parseTip(tip)
                guard !parsed.wrong.isEmpty, !parsed.right.isEmpty else { continue }

                let id = UUID().uuidString
                corrections.append(HistoryCorrection(
                    id: id,
                    wrong: parsed.wrong,
                    right: parsed.right,
                    why: parsed.why,
                    category: category
                ))
            }
            return corrections
        }.value
    }

    // MARK: - Tip parsing

    static func parseTip(_ tip: String) -> (wrong: String, right: String, why: String) {
        let segment = tip.components(separatedBy: "; ").first ?? tip

        guard let arrowRange = segment.range(of: " → ") else {
            return ("", "", segment)
        }

        let wrongPart = String(segment[segment.startIndex..<arrowRange.lowerBound])
            .replacingOccurrences(of: "❌ ", with: "")
            .replacingOccurrences(of: "❌", with: "")
            .trimmingCharacters(in: .whitespaces)

        let afterArrow = String(segment[arrowRange.upperBound...])

        if let dashRange = afterArrow.range(of: " — ") {
            // Strip alternatives: take only the first option before " / "
            let fullRight = String(afterArrow[afterArrow.startIndex..<dashRange.lowerBound])
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            let rightMain = fullRight.components(separatedBy: " / ").first?
                .trimmingCharacters(in: .whitespaces) ?? fullRight
            let why = String(afterArrow[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (wrongPart, rightMain, why)
        } else {
            let fullRight = afterArrow
                .replacingOccurrences(of: "✅ ", with: "")
                .replacingOccurrences(of: "✅", with: "")
                .trimmingCharacters(in: .whitespaces)
            let rightMain = fullRight.components(separatedBy: " / ").first?
                .trimmingCharacters(in: .whitespaces) ?? fullRight
            return (wrongPart, rightMain, "")
        }
    }
}
```

- [ ] **Step 2: Build and verify it compiles**

Open Xcode or run:
```bash
cd /Users/lucianfialho/Code/loro/periquito-app
xcodebuild -scheme periquito -destination 'platform=macOS' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add periquito-app/periquito/Services/DistractorEngine.swift
git commit -m "feat: add DistractorEngine with HistoryCorrection type and history parsing"
```

---

### Task 2: Refactor SpacedRepetitionManager to use DistractorEngine

**Files:**
- Modify: `periquito-app/periquito/Services/SpacedRepetitionManager.swift`

- [ ] **Step 1: Remove `CorrectionEntry` and `parseTip` from SpacedRepetitionManager**

Delete these blocks entirely (they are replaced by `DistractorEngine`):

```swift
// DELETE this entire block (lines ~154-160):
private struct CorrectionEntry {
    let id: String
    let wrong: String
    let right: String
    let why: String
    let category: String
}

// DELETE this entire method (lines ~162-198):
private func loadCorrections() async -> [CorrectionEntry] { ... }

// DELETE this entire method (lines ~200-230):
nonisolated private static func parseTip(_ tip: String) -> ... { ... }

// DELETE this entire method (lines ~234-257):
private func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double { ... }
```

- [ ] **Step 2: Add `currentOptions` property**

Add after `private(set) var currentQuiz: QuizItem?`:

```swift
private(set) var currentOptions: [String] = []
```

- [ ] **Step 3: Rewrite `syncFromHistory` to use DistractorEngine and UUID IDs**

Replace the entire `syncFromHistory()` method:

```swift
func syncFromHistory() async {
    let corrections = await DistractorEngine.loadFromHistory()
    var existingIds = Set(items.map(\.id))

    for correction in corrections {
        // Use wrong sentence as dedup key to avoid re-adding same mistake
        let dedupKey = correction.wrong.lowercased().trimmingCharacters(in: .whitespaces)
        let alreadyExists = items.contains {
            $0.incorrectSentence.lowercased().trimmingCharacters(in: .whitespaces) == dedupKey
        }
        guard !alreadyExists else { continue }

        let id = UUID().uuidString
        existingIds.insert(id)

        let item = QuizItem(
            id: id,
            incorrectSentence: correction.wrong,
            correctSentence: correction.right,
            explanation: correction.why,
            category: correction.category,
            box: 1,
            nextReviewDate: Date(),
            totalReviews: 0,
            correctCount: 0
        )
        items.append(item)
    }

    saveReviews()
    logger.info("Synced \(self.items.count) review items")
}
```

Note: deduplication is now by `incorrectSentence` content match (instead of hash ID collision), so same mistake isn't added twice even with UUID IDs.

- [ ] **Step 4: Add corruption detection to `loadReviews`**

Replace `loadReviews()`:

```swift
private func loadReviews() {
    guard FileManager.default.fileExists(atPath: Self.reviewsFile.path),
          let data = try? Data(contentsOf: Self.reviewsFile),
          let loaded = try? JSONDecoder().decode([QuizItem].self, from: data) else {
        return
    }

    // Detect corrupted state: all items stuck in box 1 with 0 correct answers
    let allCorrupted = !loaded.isEmpty && loaded.allSatisfy { $0.box == 1 && $0.correctCount == 0 }
    if allCorrupted {
        logger.warning("Detected corrupted reviews data (\(loaded.count) items, all box 1). Resetting.")
        try? FileManager.default.removeItem(at: Self.reviewsFile)
        items = []
        return
    }

    items = loaded
    logger.info("Loaded \(self.items.count) review items")
}
```

- [ ] **Step 5: Fix `startQuiz` to build options via DistractorEngine**

Replace `startQuiz()`:

```swift
func startQuiz() -> Bool {
    guard let item = nextDueItem() else {
        logger.info("No items due for review")
        return false
    }
    currentQuiz = item
    // Build options synchronously from already-loaded items
    // Use other items' incorrectSentences as the corrections pool
    let pool = items.map {
        HistoryCorrection(id: $0.id, wrong: $0.incorrectSentence, right: $0.correctSentence,
                          why: $0.explanation, category: $0.category)
    }
    currentOptions = DistractorEngine.options(for: item, from: pool)
    quizState = .asking(item)
    logger.info("Starting quiz for: \(item.incorrectSentence) with \(currentOptions.count) options")
    return true
}
```

- [ ] **Step 6: Fix `submitAnswer` to compare directly**

Replace lines 87-89 in `submitAnswer`:

```swift
// Before:
let correct = quiz.correctSentence.components(separatedBy: " / ").first ?? quiz.correctSentence
let isCorrect = answer == correct

// After:
let isCorrect = answer == quiz.correctSentence
```

- [ ] **Step 7: Clear `currentOptions` on dismiss**

Update `dismissQuiz()`:

```swift
func dismissQuiz() {
    quizState = .idle
    currentQuiz = nil
    currentOptions = []
}
```

- [ ] **Step 8: Build and verify**

```bash
cd /Users/lucianfialho/Code/loro/periquito-app
xcodebuild -scheme periquito -destination 'platform=macOS' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 9: Commit**

```bash
git add periquito-app/periquito/Services/SpacedRepetitionManager.swift
git commit -m "fix: rewrite SpacedRepetitionManager with UUID IDs, corruption reset, DistractorEngine"
```

---

### Task 3: Update QuizBubbleView for dynamic options + selection highlight

**Files:**
- Modify: `periquito-app/periquito/Views/QuizBubbleView.swift`

- [ ] **Step 1: Add `options` and `correctAnswer` parameters**

Change the struct declaration and add properties:

```swift
struct QuizBubbleView: View {
    let quizState: QuizState
    let options: [String]          // ADD
    let correctAnswer: String      // ADD
    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    @State private var selectedAnswer: String?
    private var fontSize: AppSettings.FontSize { AppSettings.fontSize }
    // ... rest unchanged
```

- [ ] **Step 2: Replace `shuffledOptions` call in `questionBubble` with the `options` parameter**

In `questionBubble(item:)`, replace:

```swift
// BEFORE:
let options = Self.shuffledOptions(item: item)
VStack(spacing: 6) {
    ForEach(options, id: \.self) { option in
        Button(action: {
            selectedAnswer = option
            onSubmit(option)
        }) {
            Text(option)
                .font(.system(size: fontSize.tipFont, weight: .medium))
                .foregroundColor(TerminalColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// AFTER:
VStack(spacing: 6) {
    ForEach(options, id: \.self) { option in
        Button(action: {
            guard selectedAnswer == nil else { return }  // prevent double-tap
            selectedAnswer = option
            onSubmit(option)
        }) {
            Text(option)
                .font(.system(size: fontSize.tipFont, weight: .medium))
                .foregroundColor(optionTextColor(for: option))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(optionBackground(for: option))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(selectedAnswer != nil)
    }
}
```

- [ ] **Step 3: Add helper methods for option styling**

Add after the `questionBubble` method:

```swift
private func optionBackground(for option: String) -> Color {
    guard let selected = selectedAnswer else {
        return Color.white.opacity(0.08)
    }
    if option == selected {
        return selected == correctAnswer
            ? TerminalColors.green.opacity(0.2)
            : TerminalColors.amber.opacity(0.2)
    }
    // Dim unselected options after a selection is made
    return Color.white.opacity(0.04)
}

private func optionTextColor(for option: String) -> Color {
    guard let selected = selectedAnswer else {
        return TerminalColors.primaryText
    }
    if option == selected {
        return selected == correctAnswer ? TerminalColors.green : TerminalColors.amber
    }
    return TerminalColors.dimmedText
}
```

- [ ] **Step 4: Remove the now-unused `shuffledOptions` static method**

Delete:

```swift
private static func shuffledOptions(item: QuizItem) -> [String] {
    let correct = item.correctSentence.components(separatedBy: " / ").first ?? item.correctSentence
    let wrong = item.incorrectSentence
    return [correct, wrong].shuffled()
}
```

- [ ] **Step 5: Reset `selectedAnswer` when quiz state changes**

Add `.onChange` in the `body`:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 8) {
        switch quizState {
        case .asking(let item):
            questionBubble(item: item)
        case .evaluating:
            questionLoading
        case .result(let correct, let explanation):
            resultBubble(correct: correct, explanation: explanation)
        case .idle:
            EmptyView()
        }
    }
    .onChange(of: quizState) { _, _ in
        selectedAnswer = nil
    }
}
```

- [ ] **Step 6: Build**

```bash
xcodebuild -scheme periquito -destination 'platform=macOS' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded` (will fail until Task 4 updates the call site)

- [ ] **Step 7: Commit (will be finalized after Task 4)**

---

### Task 4: Update call site in ExpandedPanelView

**Files:**
- Modify: `periquito-app/periquito/Views/ExpandedPanelView.swift` (~line 221)

- [ ] **Step 1: Pass `options` and `correctAnswer` to QuizBubbleView**

Replace the `QuizBubbleView(...)` call:

```swift
// BEFORE:
QuizBubbleView(
    quizState: quizManager.quizState,
    onSubmit: { answer in
        quizManager.submitAnswer(answer)
    },
    onDismiss: {
        quizManager.dismissQuiz()
    }
)

// AFTER:
QuizBubbleView(
    quizState: quizManager.quizState,
    options: quizManager.currentOptions,
    correctAnswer: quizManager.currentQuiz?.correctSentence ?? "",
    onSubmit: { answer in
        quizManager.submitAnswer(answer)
    },
    onDismiss: {
        quizManager.dismissQuiz()
    }
)
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme periquito -destination 'platform=macOS' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add periquito-app/periquito/Views/QuizBubbleView.swift \
        periquito-app/periquito/Views/ExpandedPanelView.swift
git commit -m "feat: dynamic quiz options with selection highlight"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run the app**

Build and run in Xcode or:
```bash
xcodebuild -scheme periquito -destination 'platform=macOS' -derivedDataPath /tmp/periquito-build build 2>&1 | tail -5
open /tmp/periquito-build/Build/Products/Debug/periquito.app
```

- [ ] **Step 2: Verify corruption reset**

Check logs for the reset message:
```bash
log stream --predicate 'subsystem == "com.lucianfialho.periquito"' --level debug | grep -i "corrupt\|reset\|synced"
```
Expected output on first run: `Detected corrupted reviews data (...). Resetting.` followed by `Synced N review items`

- [ ] **Step 3: Verify quiz shows 2-4 options**

Wait for idle quiz trigger (or lower the idle threshold temporarily in `IdleDetector`). Confirm the quiz bubble shows more than 2 options if correction history is sufficient.

- [ ] **Step 4: Verify selection highlight**

Click the wrong option → button turns amber. Click the correct option in a new quiz → button turns green.

- [ ] **Step 5: Verify box advancement**

Answer 1 quiz correctly. Check `~/.english-learning/reviews.json`:
```bash
cat ~/.english-learning/reviews.json | python3 -c "
import json, sys
items = json.load(sys.stdin)
advanced = [i for i in items if i['box'] > 1]
print(f'Items in box > 1: {len(advanced)}')
if advanced: print('Example:', advanced[0]['incorrectSentence'], '→ box', advanced[0]['box'])
"
```
Expected: at least 1 item with `box: 2`

- [ ] **Step 6: Final commit if any fixes needed, then push**

```bash
git push
```
