# Spec: Streak System with Visual Feedback

**Issue:** #6
**Phase:** 2 — Tamagotchi Lifecycle
**Date:** 2026-03-14

---

## 1. Problem Statement

**What are we solving?**

Users have no sense of daily consistency. The leveling system tracks cumulative progress (XP), but doesn't reward showing up every day. A streak counter creates a daily habit loop — the fear of breaking a streak is one of the strongest motivators in gamification (Duolingo, GitHub contributions).

**Why now?**

LevelManager already tracks `lastActiveDate`, and `history.jsonl` contains dated entries. The streak can be computed from existing data with no schema changes. The stats tab and notch badge infrastructure are in place from issues #1 and #5.

---

## 2. User Stories

### US-1: Current streak count
**As a** developer using Periquito,
**I want to** see how many consecutive days I've practiced English
**so that** I'm motivated to maintain my daily habit.

**Acceptance Criteria:**
- [ ] Streak = number of consecutive calendar days with ≥3 evaluated prompts (good + correction)
- [ ] Today counts toward the streak if ≥3 prompts have been analyzed today
- [ ] Today does NOT count if fewer than 3 prompts so far (streak shows yesterday's end value, not broken yet)
- [ ] Streak breaks when a full calendar day passes with <3 evaluated prompts
- [ ] Streak is computed from `history.jsonl` dates — no separate persistence file

### US-2: Best streak record
**As a** user who broke a streak,
**I want to** see my all-time best streak
**so that** I have a record to beat and motivation to rebuild.

**Acceptance Criteria:**
- [ ] Best streak = longest consecutive run ever recorded in history
- [ ] Computed from `history.jsonl` alongside current streak
- [ ] Shown in stats tab alongside current streak
- [ ] If current streak equals or exceeds best streak, highlight it (e.g. "New best!")

### US-3: Streak badge in collapsed notch
**As a** user,
**I want to** see my streak at a glance in the notch
**so that** I'm reminded of my progress without opening the panel.

**Acceptance Criteria:**
- [ ] Small "🔥 N" badge visible near the parrot in the collapsed notch
- [ ] Only shown when streak ≥ 1 (no badge for 0-day streak)
- [ ] Badge positioned to not conflict with the existing level emoji badge
- [ ] Uses a compact font size that fits the notch area

### US-4: Streak display in stats tab
**As a** user,
**I want to** see my streak details in the stats panel
**so that** I can track my consistency over time.

**Acceptance Criteria:**
- [ ] Stats tab shows current streak and best streak
- [ ] Current streak displayed prominently with fire emoji
- [ ] Best streak shown smaller/dimmed below or beside it
- [ ] "New best!" indicator when current ≥ best
- [ ] Shows "0 days" cleanly when no streak (not hidden)

### US-5: Streak updates in real-time
**As a** user,
**I want** the streak to update as I write prompts
**so that** I see immediate feedback toward my daily goal.

**Acceptance Criteria:**
- [ ] Streak recomputes when `tips.count` changes (same trigger as stats reload)
- [ ] If today's prompt count goes from 2→3, streak increments immediately
- [ ] No manual refresh needed

---

## 3. Non-Goals (Scope Defense)

- **No streak freeze / skip days** — no paid or earned "freeze" mechanic
- **No configurable daily minimum** — hardcoded at 3 prompts
- **No streak-based XP bonuses** — streaks are purely motivational, no XP multiplier
- **No notifications for streak at risk** — that's issue #15 (notification center)
- **No weekly/monthly streak history view** — that's issue #2 (weekly chart)
- **No separate persistence file** — computed from existing `history.jsonl`

---

## 4. Technical Context

### Streak computation algorithm
1. Parse all entries from `history.jsonl`
2. Group by calendar date (extract date from ISO8601 `date` field)
3. Count evaluated prompts (good + correction) per day
4. A "qualifying day" has ≥3 evaluated prompts
5. Walk backwards from today:
   - If today has ≥3 → include today, then check yesterday, etc.
   - If today has <3 → streak = run ending yesterday (streak not broken until day ends)
6. Current streak = length of the qualifying run that touches today or yesterday
7. Best streak = longest qualifying run in the entire history

### Integration with HistoryStatsLoader
Extend `HistoryStats` to include `currentStreak: Int` and `bestStreak: Int`. Compute alongside existing stats in the `load()` function — single pass through the file.

### Display locations
- **Stats tab** (`StatsView.swift`) — streak section between level row and accuracy hero
- **Notch badge** (`GrassIslandView.swift`) — "🔥 N" positioned opposite the level badge (bottom-left vs bottom-right)

### Files to modify
- **Modify:** `Services/HistoryStatsLoader.swift` — add streak computation
- **Modify:** `Views/StatsView.swift` — add streak display
- **Modify:** `Views/GrassIslandView.swift` — add streak badge on sprites

---

## 5. Open Questions

1. Should the daily minimum (3 prompts) be visible to the user? **Proposed: yes** — show "2/3 today" progress in the stats tab so users know how close they are to qualifying the day.
2. Timezone handling: should we use the system timezone for "calendar day"? **Proposed: yes** — use `Calendar.current` which respects the user's locale.
