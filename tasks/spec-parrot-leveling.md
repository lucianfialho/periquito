# Spec: Parrot Leveling System

**Issue:** #5
**Phase:** 2 — Tamagotchi Lifecycle
**Date:** 2026-03-14
**Related:** #20 (distinct sprites per level — deferred, placeholder badges for now)

---

## 1. Problem Statement

**What are we solving?**

The parrot reacts to individual prompts (happy/sad) but has no sense of long-term progression. Users can't see how they've grown over time. A leveling system gives the Tamagotchi a lifecycle — the parrot evolves as the user improves, creating a persistent sense of accomplishment and motivation.

**Why now?**

The stats tab (#1) just shipped, giving users visibility into their accuracy. Leveling builds on the same data (`history.jsonl`) and gives that data a narrative: you're not just "78% accurate" — you're a Level 3 Parrot about to become a Macaw.

---

## 2. User Stories

### US-1: XP accumulation
**As a** developer using Periquito,
**I want to** earn XP for every English prompt I write
**so that** I feel rewarded for practicing consistently.

**Acceptance Criteria:**
- [ ] Each "good" analysis result earns +10 XP
- [ ] Each "correction" result earns +5 XP (learning still counts)
- [ ] "skip" results earn 0 XP
- [ ] XP is persisted in `~/.english-learning/level.json`
- [ ] XP accumulates across sessions and app restarts

### US-2: Five evolution stages
**As a** user,
**I want to** see my parrot evolve through 5 stages
**so that** I have a long-term goal to work toward.

**Acceptance Criteria:**
- [ ] 5 levels defined: Egg (1), Chick (2), Parrot (3), Macaw (4), Phoenix (5)
- [ ] Each level has an XP threshold AND a minimum accuracy requirement:
  - Egg: 0 XP, 0% accuracy (starting state)
  - Chick: 100 XP, 30% accuracy
  - Parrot: 500 XP, 50% accuracy
  - Macaw: 2000 XP, 70% accuracy
  - Phoenix: 5000 XP, 85% accuracy
- [ ] Accuracy is computed over the last 50 evaluated prompts (rolling window), not all-time
- [ ] Level up only triggers when BOTH XP and accuracy thresholds are met
- [ ] Levels are permanent — you cannot de-rank once achieved

### US-3: XP decay on broken streak
**As a** user who stops practicing,
**I want to** see consequences for inactivity
**so that** I'm motivated to keep a daily habit.

**Acceptance Criteria:**
- [ ] If no English prompt is analyzed for a full calendar day, the user "breaks streak"
- [ ] On each missed day, XP decays by 5% (compounding)
- [ ] XP cannot decay below the current level's threshold (you never lose a level)
- [ ] Decay is calculated on app launch by checking `lastActiveDate` in level.json
- [ ] When decay happens, parrot shows sad/sob emotion state on launch

### US-4: Level badge in notch (collapsed view)
**As a** user,
**I want to** see my current level at a glance
**so that** I feel my progress even when the panel is collapsed.

**Acceptance Criteria:**
- [ ] A small level indicator is visible near the parrot in the collapsed notch
- [ ] Shows level number or stage name abbreviation (e.g. "Lv3" or egg/chick/parrot emoji)
- [ ] Updates immediately on level-up
- [ ] Does not obstruct the parrot sprite

### US-5: Level + XP in stats tab
**As a** user,
**I want to** see my level, XP, and progress to next level in the stats panel
**so that** I know how close I am to evolving.

**Acceptance Criteria:**
- [ ] Stats tab shows: current level name, level number, XP count
- [ ] XP progress bar showing progress from current level threshold to next level threshold
- [ ] Progress bar is color-coded (matches parrot evolution theme)
- [ ] If accuracy is below next level's requirement, show a hint: "Need X% accuracy (currently Y%)"
- [ ] At max level (Phoenix), show "Max Level" instead of progress bar

### US-6: Soft penalty for inactivity (visual)
**As a** user who hasn't practiced recently,
**I want** the parrot to look sad
**so that** I feel motivated to come back and practice.

**Acceptance Criteria:**
- [ ] If `lastActiveDate` is >1 day ago, parrot emotion defaults to sad on launch
- [ ] If `lastActiveDate` is >3 days ago, parrot emotion defaults to sob
- [ ] Emotion resets to normal after the first prompt is analyzed in the new session
- [ ] No permanent damage — just a visual nudge

---

## 3. Non-Goals (Scope Defense)

- **No distinct sprites per level** — using the same parrot sprite with a level badge. Art is tracked in issue #20
- **No celebrations/confetti on level-up** — that's issue #8
- **No streak counter display** — that's issue #6
- **No sound effects for level-up** — keep it silent for now
- **No leaderboard or social sharing** — that's Phase 4
- **No level-specific idle animations** — same animations at all levels

---

## 4. Technical Context

### Persistence file: `~/.english-learning/level.json`
```json
{
  "xp": 1250,
  "level": 3,
  "lastActiveDate": "2026-03-14"
}
```
- Created on first analysis if missing
- Read on app launch to compute decay and set initial emotion
- Updated after each analysis result

### XP thresholds
| Level | Name    | XP Threshold | Min Accuracy (last 50) |
|-------|---------|-------------|----------------------|
| 1     | Egg     | 0           | 0%                   |
| 2     | Chick   | 100         | 30%                  |
| 3     | Parrot  | 500         | 50%                  |
| 4     | Macaw   | 2000        | 70%                  |
| 5     | Phoenix | 5000        | 85%                  |

### Rolling accuracy
Computed from the last 50 entries in `history.jsonl` where type is "good" or "correction" (not "skip"). This avoids penalizing users for early mistakes when they were just starting.

### Integration points
- **EmotionAnalyzer** or **PeriquitoStateMachine** — after each analysis, call into level service to award XP
- **HistoryStatsLoader** — extend to compute rolling accuracy (last 50)
- **ExpandedPanelView / StatsView** — show level info
- **NotchContentView or GrassIslandView** — show level badge in collapsed state
- **App launch** — compute decay, set initial emotion

### Files to create/modify
- **New:** `Services/LevelManager.swift` — XP, level logic, persistence
- **New:** `Models/ParrotLevel.swift` — level definitions enum
- **Modify:** `Services/HistoryStatsLoader.swift` — add rolling accuracy
- **Modify:** `Views/StatsView.swift` — add level + XP progress bar
- **Modify:** `Views/GrassIslandView.swift` or `NotchContentView.swift` — level badge overlay
- **Modify:** `Services/PeriquitoStateMachine.swift` — award XP after analysis

---

## 5. Open Questions

1. Should XP decay cap be the current level's threshold, or slightly above it (e.g. threshold + 10%)? **Proposed: exact threshold** — simplest, and you keep the level.
2. Should the "rolling 50" window for accuracy be configurable? **Proposed: no** — hardcoded for simplicity, can revisit later.
3. What happens if `history.jsonl` has fewer than 50 entries? **Proposed: use all available entries** for accuracy calculation.
