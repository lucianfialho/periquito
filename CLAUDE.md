# Loro — Language Learning Tamagotchi for Claude Code

## What is this project?
Loro is a macOS notch app (forked from [Loro](https://github.com/sk-ruban/loro)) that helps developers learn English (and other languages) while they code. It's a Tamagotchi-style parrot that lives in your MacBook notch and reacts to your English usage in Claude Code.

## Origin
- Forked from `sk-ruban/loro` (MIT License)
- Original project: a coding companion that shows animated sprites in the macOS notch reacting to Claude Code activity
- Our goal: transform it into a language learning companion

## Architecture (inherited from Loro)
```
Claude Code Hooks → Unix Socket → Event Parser → State Machine → SwiftUI Sprites (notch)
```

- **Hooks**: Shell scripts registered with Claude Code (`UserPromptSubmit`)
- **Communication**: JSON payloads via Unix socket
- **Frontend**: SwiftUI native macOS app
- **Rendering**: Animated sprites in the MacBook notch area

## What Loro should become
- A **parrot Tamagotchi** that lives in the notch
- **Parrot states**: happy (good English), confused (grammar error + shows correction), sad (long time without English), growing (accuracy improving)
- **Knowledge base**: tracks all corrections in `~/.english-learning/history.jsonl`
- **Stats panel**: streak, accuracy rate, common mistakes, weekly evolution
- **Notifications**: corrections and praise with different sounds/icons

## Existing hook system (from ~/Code/learnEnglish)
We already built the backend hook system that:
1. Intercepts every Claude Code prompt via `UserPromptSubmit` hook
2. Runs `claude -p` with `--settings '{}'` to avoid recursive hooks
3. Analyzes English with AI, returns JSON: `{type, tip, category}`
4. Logs to `~/.english-learning/history.jsonl`
5. Sends macOS notifications via `terminal-notifier`

The scripts are in `~/Code/learnEnglish/` — they should be migrated/integrated into this repo.

## Key files to migrate from learnEnglish
- `english-tip.sh` — main hook (UserPromptSubmit)
- `analyze-worker.sh` — detached worker that calls claude -p and sends notifications
- `log_tip.py` — parses AI response and logs to history
- `progress.sh` — CLI dashboard showing learning evolution
- `assets/` — 3D icons from thiings.co (parrot-mascot.png, book-icon.png, check-icon.png)

## Tech stack
- **App**: Swift + SwiftUI (macOS 15.0+, MacBook with notch)
- **Hooks**: Bash shell scripts
- **Analysis**: Claude Code headless (`claude -p`)
- **Notifications**: terminal-notifier (brew dependency)
- **Icons**: 3D icons from thiings.co

## TODO
1. Rename all loro references to loro
2. Replace sprites with parrot character (states: idle, happy, confused, sad, learning)
3. Integrate language analysis hooks (replace coding activity hooks)
4. Add knowledge base panel (stats, accuracy, streak)
5. Migrate scripts from ~/Code/learnEnglish into this repo's scripts/ folder
6. Update install flow

## Brand
- **Name**: Loro ("parrot" in Spanish/Italian)
- **Mascot**: 3D parrot from thiings.co
- **Sounds**: Glass (correct), Pop (correction)
