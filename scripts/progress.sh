#!/bin/bash
# Periquito — English Learning Progress
# Usage: /progress in Claude Code

HISTORY_FILE="$HOME/.english-learning/history.jsonl"

if [ ! -f "$HISTORY_FILE" ]; then
  echo "No learning data yet. Keep writing in English!"
  exit 0
fi

/usr/bin/python3 -c "
import json, sys
from datetime import datetime, timedelta
from collections import Counter

history = []
with open('$HISTORY_FILE', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            history.append(json.loads(line))
        except:
            pass

if not history:
    print('No learning data yet.')
    sys.exit(0)

total = len(history)
good = sum(1 for e in history if e.get('type') == 'good')
corrections = sum(1 for e in history if e.get('type') == 'correction')
skipped = sum(1 for e in history if e.get('type') == 'skip')
evaluated = good + corrections
accuracy = (good * 100 // evaluated) if evaluated > 0 else 0

# Accuracy bar
bar_len = 20
filled = accuracy * bar_len // 100
bar = '█' * filled + '░' * (bar_len - filled)

print()
print('  PERIQUITO — English Progress')
print('  ════════════════════════════════')
print()
print(f'  Accuracy   [{bar}] {accuracy}%')
print(f'  Analyzed   {evaluated} prompts ({good} good, {corrections} corrections)')
if skipped:
    print(f'  Skipped    {skipped} (not English)')
print()

# Weekly breakdown
print('  Last 7 days')
print('  ────────────────────────────────')
today = datetime.now().date()
for i in range(6, -1, -1):
    day = today - timedelta(days=i)
    day_str = day.isoformat()
    day_entries = [e for e in history if e.get('date', '').startswith(day_str)]
    day_good = sum(1 for e in day_entries if e.get('type') == 'good')
    day_corr = sum(1 for e in day_entries if e.get('type') == 'correction')
    day_total = day_good + day_corr
    label = 'today' if i == 0 else day.strftime('%a %d')
    if day_total > 0:
        day_acc = day_good * 100 // day_total
        mini_bar = '█' * (day_acc * 10 // 100) + '░' * (10 - day_acc * 10 // 100)
        print(f'  {label:>8}  {mini_bar} {day_acc}%  ({day_good}✓ {day_corr}✗)')
    else:
        print(f'  {label:>8}  ·········· --')

# Common mistakes
categories = Counter()
for e in history:
    if e.get('type') == 'correction':
        categories[e.get('category', 'other')] += 1

if categories:
    print()
    print('  Top mistake areas')
    print('  ────────────────────────────────')
    labels = {
        'grammar': 'Grammar',
        'spelling': 'Spelling',
        'word_choice': 'Word choice',
        'phrasing': 'Phrasing',
        'punctuation': 'Punctuation',
        'other': 'Other'
    }
    for cat, count in categories.most_common(5):
        name = labels.get(cat, cat.title())
        pct = count * 100 // corrections if corrections > 0 else 0
        print(f'  {name:<14} {count:>3}x  ({pct}%)')

# Recent corrections
recent_corrections = [e for e in history if e.get('type') == 'correction'][-5:]
if recent_corrections:
    print()
    print('  Recent corrections')
    print('  ────────────────────────────────')
    for e in recent_corrections:
        tip = e.get('tip', '')
        # Truncate long tips
        if len(tip) > 80:
            tip = tip[:77] + '...'
        print(f'  {tip}')

print()
print('  Keep practicing! The parrot is watching.')
print()
" 2>/dev/null
