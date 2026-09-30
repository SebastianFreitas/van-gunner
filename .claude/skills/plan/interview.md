# Plan interview (Stage `planning` or `ready`)

One of the plan skill's two stage files (`SKILL.md` is the index). A
session continuing an interview reads this file and the plan, not
`run.md`. One plan per checkout; other active plans belong to other
checkouts: never edit their plan files, state files, research or code
areas.

Do **not** use Claude Code's built-in plan mode (Shift+Tab) for this: it
blocks every file write, and planning here writes research digests and
the plan itself into the repo. `/plan` is the plan mode.

## `/plan` or `go` while Stage is `planning`

Read `Interview` (which part is open) and `Open items`, and continue the
interview from exactly there.

## The interview: how planning feels

The goal, in the owner's words (2026-09-28): *"the concept for the plan
is that during execution the LLM should never make decisions on its
own. So the planning phase is there to ask all the specifics, if there's
100 questions so be it, if there's 5 then so be it. But the goal is to
specify everything."* **The finished plan leaves zero choices to the
LLM.** Questions are the tool, not the target: there is no minimum
count, no word count. A plan is done when a review finds nothing left
to choose. So planning is a loop:

> ask what is open → write it into the plan → review the plan → every
> uncertainty the review finds becomes a new question → repeat until a
> review finds none.

Execution that stops or defers a phase for a question is a planning
miss, not the plan working (owner, 2026-09-29: "stopping midway is not
the goal, it should be a rare occurrence"). Ask here what a phase would
otherwise have to ask.

- **Every question goes through `AskUserQuestion`** (the UI), never as
  prose that ends the turn. Calls are consecutive in the **same turn**:
  ask, record, ask again. The turn ends only when the owner does not
  answer (the question stands, the handoff names it, the next "go" asks
  it again) or when the ready gate passes. A "you decide" answer is
  recorded as a D in Claude's words, marked `(owner: you decide)`.
- **What counts as an open choice.** Any spot where the implementer
  would have to pick: a name, number, colour, count, order, timing,
  caption or HUD text, a tuning value, what the user sees, hears or
  feels in the first and last second, what happens when it fails, what
  stays exactly as is next to it. If two reasonable implementers could
  build it two different ways, it is open.
- **What is not asked.** A choice already fixed by the Brief, a D, the
  existing code, an invariant in `CLAUDE.md`, a domain rule
  (`.claude/rules/*.md`) or a memory is written into the plan as a D
  marked `(from <source>)`, not asked. Never ask to fill a count, never
  ask twice what a D settles, never ask a question whose every answer
  builds the same thing.
- **Detail by detail.** Planning decides specifics now. A phase's
  research while running only fills what planning explicitly left it,
  marked `→ phase decides`, and only when the owner agreed to leave it.
- **Never stop early.** Never end a planning turn to "let the owner
  think"; never write "ready when you are"; never skip an open choice
  because the answer seems obvious or the owner seems tired of questions.
  If the owner types "just build it" or "stop asking", record that
  verbatim as a D, ask one question ("Take Recommended for every open
  choice left?" with "No, keep going (Recommended)" first) and follow the
  answer.

### Question rules (every call)

- Up to 4 questions per call; consecutive calls until the open list is
  empty. Never carry a known open choice into a later turn or a later
  phase.
- 2 to 4 options each, the recommended one first with "(Recommended)".
  Options are concrete and different from each other, written as what
  the owner will see or get, never "Yes / No" unless the choice is truly
  binary. `multiSelect: true` when several can be true; `preview` when a
  caption, palette, layout or table decides it.
- The owner always has "Other" for free text. A free-text answer is
  recorded verbatim; if it opens new choices, they join the open list.
- One question per decision. A question that needs research explained
  first puts the explanation in its own text: the owner has not read the
  research digest.
- Every question quotes or points at the Brief line, the D, or the piece
  of the Initial idea it is about, so the owner knows where they are.
- After each call: write every answer into the plan as `D<n>`, bump the
  count under `Interview`, commit the plan by path. Then the next call.

### The review pass (used after every part)

Read the plan section (or the whole plan) **as the implementer who must
build it from that text alone**, and list every open choice (above) you
would have to make, plus every place two lines could be read two ways or
contradict a D. Each item is either fixed from a source (write the D,
`(from <source>)`) or becomes a question. Ask them all, apply the
answers, then review again. The part is done when a review returns an
empty list.

### Part A · Brief and direction

1. **Intake.** Explore the current state through `Explore` (grep
   `.claude/MAP.md` first; `file:line` anchors, no code bodies). Write
   it under Current state.
2. **Research** the areas the brief touches, as wide as the choices
   need (other games, films, painters, techniques, engine or library
   docs). Load `WebSearch`/`WebFetch`. Digest into
   `.claude/plans/research/<name>-00-intake.md`: sources, what we take
   from each, in our own words. Never copy art or long text.
3. **Option map.** For each area where the research found real
   alternatives, list them: one line each, with one precedent and what
   it would look like in *our* result. Include areas the brief did not
   mention but the work forces (captions or HUD text, performance,
   phones, reduced motion, the project's baselines and art rules, what
   stays as is) only where they are actually open.
4. **Open list.** Read the Brief clause by clause and list the choices it
   leaves open that shape the whole result (direction, scope, what it
   is), plus the option-map areas. Details that only matter inside one
   piece wait for Part B, where they have context.
5. **Ask the list** by the question rules. Contradictions with an earlier
   D are asked as their own question, never resolved silently. Write
   `Interview: A done · <count> asked` and go to Part B in the same turn.

### Part B · Initial idea, reviewed piece by piece

1. **Write the Initial idea** under its section: the whole result in
   prose, beginning to end, as the owner will experience it (what is on
   screen, what moves, what is read or heard, what the user does, in
   order). Every sentence rests on a D, the Brief or a `(from <source>)`
   fact; anything else is a guess and is marked `[?]`. Split it into
   numbered **pieces** (a beat, a screen, a system, a rule), as many as
   the work has, each a heading with its lines under it. Commit.
2. **Show every piece to the owner.** One question per piece, up to 4
   pieces per call: *"Piece <n>, <name>: <the piece's lines, in full>.
   Right?"* with "That is it (Recommended) / Close, but change something
   (say what in Other) / Different direction / Explain the choices
   first". A change or new direction rewrites the piece and it is shown
   again; "Explain" is answered in the next call's question text, then
   the piece is shown again. Record each under `Walk-through` (piece,
   answer, D numbers).
3. **Review pass** over the pieces: every `[?]` and every open choice the
   review finds becomes a question. Rewrite the prose with the answers
   and review again until the list is empty and no `[?]` remains. Write
   `Interview: B done · <count> asked`.

A plan with no user-facing result (tooling, workflow) may record
"Initial idea skipped" as a D the owner chose; its phases then carry
every piece.

### Part C · Phases and their review

1. **Write the phases** from the Initial idea. Each phase: kind
   (research/doc/code/review), the pieces it implements, research
   topics, deliverables, verification, the D numbers it rests on. **No
   phase may be of kind "owner talk"**: every question is asked here,
   now. **Size:** a code phase is at most two implementer specs and at
   most two files it reads to design (name them); more than that is two
   phases. A phase's section is self-contained (it names its D numbers
   and pieces), because an unattended session sees only that section.
   Verification names the check that actually sees the change (see
   "Verify in a phase" in `run.md`; read only that section). Fill
   Scope, Constraints, the Progress table,
   including each phase's **Needs**: the earlier phases whose output it
   builds on (`-` for none), so a deferred phase holds back only what
   depends on it. Commit.
2. **Show every phase to the owner.** One question per phase, up to 4
   per call: *"Phase <n>, <name>, delivers <deliverables>, must not touch
   <Out list>, verified by <commands / screenshots>. Right?"* with "Right
   (Recommended) / Missing something (say what in Other) / Too big,
   split it / Merge with the previous phase". Splits and merges rewrite
   the Progress table and the changed phases are shown again. Record
   under each phase: `Reviewed: <answer, D numbers>`.
3. **Review pass** over each phase as the session that will run it,
   seeing only that section: draft its specs in your head (files,
   functions, names, numbers, text, what the screenshot shows) and every
   blank you would have to fill becomes a question. Repeat until empty.
   Write `Interview: C done · <count> asked`.

### Ready gate (all true, or keep going)

- **Fresh-eyes review.** A `Plan` subagent that has not seen the
  interview reads the plan file (give it the path; it does not load
  CLAUDE.md) and lists, per phase, every choice it would have to make
  to build it and every line it could read two ways, with the line
  quoted. Each item is fixed from a source or asked; then a new fresh
  review runs. The gate needs one review that returns nothing.
- `Interview` shows A, B and C done. Open items: none. No `[?]` anywhere.
  No `→ phase decides` the owner did not agree to.
- Every piece has a Walk-through line; every phase has a `Reviewed:`
  line, cites at least one D or Brief line, has its Needs filled, and is
  `todo` in the Progress table. Constraints and Scope are filled.

Then set `Stage: ready`, commit the plan and research by path, and ask
one last `AskUserQuestion` call with two questions: "Start running the
plan? (Recommended) / Change something first / Hold", and "A question
the plan missed, with no clear answer: park that phase for you to answer
later (Recommended) / take the recommended option and keep going", which
sets `Questions: ask` or `Questions: auto` in the header. Start →
`Stage: running`, read `.claude/skills/plan/run.md` and run the first
phase in the same turn, ending with its Handoff protocol and hard stop
(one phase, never two). Change → record the change as a D, show the
pieces and phases it touches again, and run the gate again.

Context: auto-compact is off (owner's rule, 2026-09-29). At `CONTEXT
WATCH`, ask no new question. Record the answer you already have as a D,
make sure `Interview` names the open part and `Open items` lists every
choice still to ask, and commit the plan by path. No
`.claude/handoff.md`: the plan file *is* the handoff. Then hard-stop.
The last line of the turn is this exact message, with nothing after it:

> Interview paused (context full). Please run `/clear`, then prompt me
> with `go` to continue the interview from the same part.

`go` then resumes through "`/plan` or `go` while Stage is `planning`"
in a fresh context.
