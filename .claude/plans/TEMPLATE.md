# <Plan name>

Stage: planning
Started: <YYYY-MM-DD>
Procedure: `.claude/skills/plan/interview.md` (the interview), then `run.md` (state in `.claude/plans/<name>.state.md` while running).
Path: full   <- or light: one area, no new user-facing design (interview.md "Light path")
Size: at most 20 KB (10 KB on the light path), each phase at most 2.5 KB (interview.md "Plan size")
Interview: A open · 0 asked   <- A/B/C open or done, running total; missed: lines while running
Questions: ask   <- or auto: phase questions never defer, the recommended option is taken (run.md "Phase questions")

## Brief (owner's words, verbatim)

<paste; do not condense during planning>

## Scope

- In: <what this plan may change, by file or area>
- Out (stays exactly as is): <files, systems, beats, rules>

## Current state (explored <date>; anchors drift, grep the names)

- <only facts a phase needs and does not state itself; file/function: what it does today, one line each>

## Option map (full path, planning only; deleted at the ready gate)

### <Area 1>
- <direction> · precedent: <real game / film / painter / technique> · in ours: <what it looks like> → D?
- <direction> · precedent: … · in ours: …

## Open items

- <one line per question not yet asked, or answer not yet applied; `review leftover:` lines may stay at ready>
- none

## Decisions (while asking; folded into the phases in Part C; `(auto)` = taken while running)

- **D1 · <topic>.** <the answer, owner's words when written by them>. Goes to: <phase n / Constraints>.

## Initial idea (full path, Part B; prose, beginning to end, as the owner experiences it)

<a page at most; every sentence rests on a D or the Brief; guesses carry [?] until asked>

### Piece 1 · <name>
<3 to 8 lines: what is on screen, what moves, what is read or heard, what the user does, in order>

## Walk-through (one line: the pieces were shown together)

- Pieces 1-<n> · <That is it / changed: ...> · D<n>

## Constraints (every phase)

- <rules that hold for the whole plan, including decisions several phases use (D<n>): invariants, art rules, perf, screenshots and baselines unchanged outside the phase's scope>

## Progress

| # | Phase | Kind | Needs | Rests on | Status |
|---|---|---|---|---|---|
| 1 | <name> | code | - | Brief | todo |
| 2 | <name> | code | 1 | D5 | todo |

Needs: earlier phases whose output it builds on. Rests on: decisions still in the list, or Brief. Status: todo, done <sha>, deferred Q<k>.

## Phases

### 1 · <name>
Research: <full path only, optional: topics and where things are, then "go past the list">.
Deliverable: <what it delivers, with the decisions it uses written in plain words (D<n>); measurable ones as "→ phase decides: measure X, then apply rule Y">. Files: <exact files / functions; at most two it reads to design>.
Verification: <exact commands from CLAUDE.md § Verify, and the screenshots that must change / stay the same>.
Reviewed: <the owner's answer to the phases question>
Notes: <filled when done: what changed, sha>

### 2 · <name>
…

## Carry forward

- <facts later phases need: names, numbers measured, screenshot set names>
