---
name: plan
description: Start, continue or run a many-phase plan in .claude/plans/. Planning asks every question up front through AskUserQuestion; running never asks. Owner-invoked only.
disable-model-invocation: true
argument-hint: "new <name>: <brief>  |  (nothing: continue the active plan)"
---

# Plan: one procedure, two states

A plan is a file `.claude/plans/<name>.md` built from
`.claude/plans/TEMPLATE.md`. `.claude/plans/ACTIVE` holds the name of the
plan in progress (one line; absent = no plan). The plan's `Stage:` line is
the state: `planning` → `ready` → `running` → `done`.

The SessionStart hook prints `PLAN: <name> · <stage>` when ACTIVE exists.
No `PLAN:` line means no plan is active: a bare "go" is then an ordinary
prompt, not a phase.

Do **not** use Claude Code's built-in plan mode (Shift+Tab) for this: it
blocks every file write, and planning here writes research digests and
the plan itself into the repo. `/plan` is the plan mode.

## `/plan new <name>: <brief>` → Stage planning

1. Create `.claude/plans/<name>.md` from TEMPLATE, write `<name>` to
   ACTIVE, paste the owner's brief **verbatim** under Brief (condense
   later, never now: their words are the source every question quotes).
2. Run the planning loop below until the ready gate passes.

## `/plan` or `go` while Stage is `planning`

Continue the planning loop from `Open items`.

## The planning loop

The owner's flow, in their words:

    owner: hey, idea for a plan
    claude: n questions → writes the answers into the plan → n questions →
            writes them in → … (this defines WHAT we will explore, not
            the specifics; specifics belong to each phase's own research)
    claude: starts the phases; each phase is one commit + a handoff

So the loop is rounds. Each round is one turn: ask, write every answer
into the plan file, commit the plan, ask again. It ends when a round
produces no new question. Planning questions are **never** skipped,
never timed out into a default, never carried into the running stage:
if the owner does not answer, the turn ends with the question standing,
the handoff names it, and the next "go" asks it again.

Planning decides direction and scope: which areas exist, what each is
for, what stays untouched, what the result should feel like. It does not
decide a phase's numbers, names or exact shapes; those come from that
phase's research while running (and may raise a phase question, below).

1. **Intake.** Explore the current state through `Explore` (grep
   `docs/PROJECT_MAP.md` first; `file:line` anchors, no code bodies). Write
   it under Current state.
2. **Research wide.** Load `WebSearch`/`WebFetch`. Research every area
   the brief touches and then go past it (other games, films, painters,
   history, techniques). Digest into `.claude/plans/research/<name>-00-intake.md`:
   sources, what we take from each, in our own words. Never copy art or
   long text.
3. **Option map.** For every area the brief touches, list the directions
   the research found: 3–6 per area, each one line, each with one real
   precedent (a game, a film, a painter, a technique), and what it would
   look like in *our* result. Areas the owner did not mention but the
   work will force (numbering, captions, performance, what stays as is)
   go here too. This map is where the questions come from.
4. **Question round.** Turn every open item into `AskUserQuestion`:
   - 4 questions per call, consecutive calls in the **same turn** until
     every open item of this round is asked. Never carry a known
     question into a later turn or a later phase.
   - 2–4 options each, the recommended one first with "(Recommended)".
     Options are concrete and different from each other, written as
     what the owner will see or get, never "Yes / No" unless the choice
     is truly binary. `multiSelect: true` when several can be true;
     `preview` when a caption, palette, layout or table decides it.
   - The owner always has "Other" for free text. A free-text answer is
     recorded verbatim as the decision, and its consequences may open a
     new round.
   - One question per decision. A question that needs the option map
     explained first puts the explanation in its own text: the owner has
     not read the research.
5. **Record.** Every answer becomes `D<n>` under Decisions, in the
   owner's words when they wrote them. Cross out the option-map lines it
   settles. Anything an answer opens (a new area, a contradiction with an
   earlier D) goes to Open items → back to step 2 or 3 for that area
   only → another round.
6. **Write the phases** once Open items is empty. Each phase: kind
   (research/doc/code/review), research topics, deliverables,
   verification, and the D-numbers it rests on. **No phase may be of kind
   "owner talk".** A question discovered while writing a phase is an open
   item: stop writing, run a round, then finish the phases.
7. **Ready gate.** All true, or keep looping:
   - Open items: none.
   - Every phase cites at least one D or the Brief line it implements.
   - Constraints and Out of scope are filled.
   - The Progress table lists every phase as `todo`.
   Then set `Stage: ready`, commit the plan and research by path, and ask
   one last `AskUserQuestion`: "Start running the plan? (Recommended) /
   Change something first / Hold". Start → `Stage: running` and run the
   first phase in the same turn. Change → record the change as a D and
   run the gate again.

Context: planning is long. At `CONTEXT WATCH` commit the plan file as it
stands, write `.claude/handoff.md` with the loop step and the open items,
keep working. The plan file *is* the handoff for everything settled.

## `go` while Stage is `running`

1. Read Progress; take the first `todo` row. Read only that phase, Brief,
   Decisions, Constraints, Carry forward.
2. Research that phase's topics (digest to `research/<name>-<NN>.md`),
   design, specs, implementer, verify, review, commit, report, as
   `CLAUDE.md` says.
3. Set the row `done <sha>`; add what later phases need to Carry forward.
4. **Phase questions: ask first, decide alone only when the owner is
   away.** A phase's research or design will sometimes force a decision
   the plan does not cover (something planning did not check). That is a
   phase question. Handle it in this order:
   - Look for it on purpose: before the first spec of a phase, list every
     decision the phase forces that no `D` or Brief line settles. Ask them
     all in one `AskUserQuestion` round (same rules as planning: 4 per
     call, concrete options, Recommended first, `preview` when useful),
     at the **start** of the phase, never after the implementer has run.
   - Wait for the answer. The tool's `askUserQuestionTimeout` setting
     (settings.json: 60s, 5m or 10m; set 5m) decides how long.
   - If the question times out **and** the previous phase question in this
     run also went unanswered, the owner is away: from then on take the
     option you would have marked "(Recommended)", record it as
     `D<n> (auto)` with one line of reason, and keep going without asking
     again in this run. One unanswered question alone does not switch
     this on: it just becomes an `(auto)` and the next question is asked.
   - A **blocker** always waits, no matter how many timeouts: the code
     contradicts the plan; two decisions conflict; a step would be
     irreversible and is not in the plan (deleting files, rewriting a
     rules file beyond what a D says). Finish what can be finished, write
     the handoff with the blocker named, end the turn.
   The owner reviews every `(auto)` at the end; each one also names a
   question planning should have asked.
5. **Every phase ends with a commit and a handoff.** Write
   `.claude/handoff.md` (the `handoff` skill's format: Done, Next, the
   open phase questions) after every phase, not only at `CONTEXT WATCH`.
   Compaction: Claude cannot run `/compact` itself; auto-compaction fires
   at the configured line and the hook prints the handoff back in. An
   owner who is present can run `/compact` between phases; never stop to
   ask for it.
6. Run phase after phase until Progress has no `todo`.

## Last phase done → Stage done

Set `Stage: done`, delete ACTIVE, list every `D<n> (auto)` in the report
under **Look at**, commit. The plan file stays as the record.

## `/plan` with no active plan

List `.claude/plans/*.md` with their Stage lines and stop.
