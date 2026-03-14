# Spec: Stats Tab in Expanded Panel

**Issue:** #1
**Phase:** 1 — Learning Dashboard
**Date:** 2026-03-14

---

## 1. Problem Statement

**What are we solving?**

Periquito logs every English analysis result to `~/.english-learning/history.jsonl`, but users can only see this data via the CLI (`/progress` command). There's no way to check your learning progress without leaving the app. Users need a quick, glanceable summary of how they're doing — right in the notch panel.

**Why now?**

The data pipeline is complete (analysis + logging works). The expanded panel currently only has tips and settings. Adding a stats view is the highest-impact feature that uses existing data with no backend changes.

---

## 2. User Stories

### US-1: View learning summary
**As a** developer using Periquito,
**I want to** see my English accuracy and prompt counts in the app
**so that** I can track my progress without switching to a terminal.

**Acceptance Criteria:**
- [ ] A "Stats" tab is visible in the expanded panel alongside the existing tips view
- [ ] Tab bar shows two tabs: "Tips" (default) and "Stats"
- [ ] Switching tabs preserves scroll position of the other tab
- [ ] Stats tab shows: accuracy %, total prompts evaluated, good count, correction count

### US-2: Accuracy metric
**As a** user,
**I want to** see my overall accuracy as a percentage
**so that** I know how my English is at a glance.

**Acceptance Criteria:**
- [ ] Accuracy = `good / (good + corrections) * 100`, rounded to nearest integer
- [ ] Displayed prominently (large number + "%" label)
- [ ] Color-coded: green ≥80%, amber 50-79%, red <50%
- [ ] Shows "—" if no data (0 evaluated prompts)

### US-3: Prompt counts
**As a** user,
**I want to** see how many prompts were analyzed and the good/correction breakdown
**so that** I understand the volume of my practice.

**Acceptance Criteria:**
- [ ] Shows total evaluated prompts (good + corrections, excludes skips)
- [ ] Shows good count with green indicator
- [ ] Shows correction count with amber indicator
- [ ] Layout fits within the panel width (402pt max)

### US-4: Real-time updates
**As a** user,
**I want** stats to update as I write new prompts
**so that** I see immediate feedback without navigating away and back.

**Acceptance Criteria:**
- [ ] When a new tip is recorded (good or correction), stats recompute
- [ ] No manual refresh needed
- [ ] File is re-read when a new analysis completes (triggered by tip count change)

### US-5: Empty state
**As a** new user with no history,
**I want to** see an encouraging message
**so that** I understand what this tab will show once I start writing.

**Acceptance Criteria:**
- [ ] If `history.jsonl` doesn't exist or has 0 evaluated entries, show: "Start writing in English to see your progress!"
- [ ] Uses same styling as existing empty state (TerminalColors.secondaryText + dimmedText)
- [ ] No broken UI or zero-division errors

---

## 3. Non-Goals (Scope Defense)

- **No weekly chart** — that's issue #2
- **No category ranking** — that's issue #3
- **No history browser / scrollable corrections list** — that's issue #4
- **No streak tracking** — that's issue #6 (Phase 2)
- **No persistent stats model or database** — read directly from JSONL file
- **No changes to the JSONL format or logging pipeline**

---

## 4. Technical Context

### Data source
- File: `~/.english-learning/history.jsonl`
- Format: one JSON object per line
- Fields: `type` ("good" | "correction" | "skip"), `date` (ISO8601), `prompt` (string, max 200 chars), `tip` (optional string), `category` (optional string)
- Read-only from the stats view; EmotionAnalyzer owns writes

### Navigation
- Tab bar at the top of the expanded panel content area (below the divider, above the scroll view)
- Two tabs: "Tips" (existing content) and "Stats" (new)
- Default to "Tips" on panel open
- Tab state is local to the expanded panel (not persisted)

### Refresh strategy
- Parse JSONL on first appear
- Re-parse when `tips.count` changes (piggyback on existing observation)
- Parsing runs on a background thread; results delivered to @MainActor

### Files to create/modify
- **New:** `Views/StatsView.swift` — stats display
- **Modify:** `Views/ExpandedPanelView.swift` — add tab bar and tab switching

---

## 5. Open Questions

1. Should skipped prompts (non-English) count toward "total prompts" or be hidden? **Proposed: hidden** (match progress.sh behavior)
2. If the JSONL file is very large (>10k lines), should we cap parsing? **Proposed: no cap for now**, revisit if performance is an issue — file I/O is fast for JSONL at this scale.
