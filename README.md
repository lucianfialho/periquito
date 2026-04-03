# Periquito

A macOS notch companion that helps you learn English while you code with Claude Code.

A Tamagotchi-style parrot that lives in your MacBook notch, analyzes your English in real-time, and teaches you through spaced repetition — without breaking your flow.

https://github.com/lucianfialho/periquito/releases/download/v1.1.0/export-kk.mp4

## What it does

- **Analyzes your English** in every Claude Code prompt via AI
- **Corrections in real-time** — shows what was wrong and why, right in the notch panel
- **Spaced repetition quiz** — periodically asks you to review your own past mistakes
- **Progress tracking** — accuracy %, streak, level system (Egg → Chick → Macaw → Phoenix)
- **Parrot reacts emotionally** — happy when you write well, sad when you keep making the same mistakes
- **Compact mode** — collapse to a stats bar showing accuracy + thumbs up/down counts

## Requirements

- macOS 15.0+ (Sequoia)
- MacBook with notch
- [Claude Code](https://claude.ai/code) installed

## Install

1. Clone the repo and open `periquito-app/periquito.xcodeproj` in Xcode
2. Build and run (`⌘R`)
3. On first launch, open Settings and click **Install Hooks** to register the Claude Code hook
4. Start using Claude Code in English — Periquito will analyze each prompt automatically

## How it works

```
Claude Code prompt → UserPromptSubmit hook → Unix socket → EmotionAnalyzer (claude -p)
       ↓
  JSON: { type, tip, category }
       ↓
  history.jsonl + SpacedRepetitionManager + SwiftUI notch panel
```

When you type a prompt in Claude Code, a shell hook intercepts it and sends it to a background worker. The worker calls `claude -p` to analyze the English, logs the result to `~/.english-learning/history.jsonl`, and the app displays a correction (or praise) in the notch panel.

The spaced repetition system (Leitner boxes 1–5) tracks your mistakes and resurfaces them for review when you're idle — pulling distractors from your own correction history so quizzes are relevant to your real errors.

## Project structure

```
periquito-app/          Swift/SwiftUI macOS app
  periquito/
    Services/
      EmotionAnalyzer.swift       Claude -p analysis
      SpacedRepetitionManager.swift  Leitner box quiz engine
      DistractorEngine.swift      History-based quiz option generator
      LevelManager.swift          XP + level progression
    Views/
      GrassIslandView.swift       Parrot sprite + walking animation
      ExpandedPanelView.swift     Tips, quiz, stats panel
      QuizBubbleView.swift        Multiple-choice quiz UI
      StatsView.swift             Accuracy ring, level, review stats
    Models/
      PeriquitoState.swift        State machine (idle/working/sleeping/etc.)
      QuizItem.swift              Leitner box item

scripts/                Shell scripts for hooks and CLI tools
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

- Forked from [sk-ruban/periquito](https://github.com/sk-ruban/periquito) (MIT) — original notch companion
- Sprite art generated with [AutoSprite](https://autosprite.co)

## License

[MIT](LICENSE)
