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
interview from exactly there. While Stage is `ready`, a bare `go` runs
no phase in this session: it starts the supervised run (`run.md`,
"Supervising the run"), which belongs in a fresh session (Ready gate).

## Who does what: the app session manages, writers write

Owner, 2026-10-01: *"never make much logic yourself, you are a
manager; use instances to make the plan, when they bump the limit they
stop and you start a new one to finish the job."*

- **The app session is the manager.** It never explores code,
  researches, reads screenshots, works out numbers or drafts plan text.
  It starts `plan-writer` subagents (foreground, one at a time), asks
  the owner the questions they return through `AskUserQuestion`, writes
  each answer into the plan as a `D<n>` (its words, one line), commits
  the plan by path, and starts the next writer. It reads the plan file
  only to write D's and check the Interview line.
- **A `plan-writer` does one job per call** (its jobs: intake, idea,
  phases, apply, continue) and commits what it wrote. Its prompt names
  the plan path, the job, and "answers since your last job: D<a>-D<b>".
  It returns what it wrote and questions ready to paste.
- **Cut off:** a writer past its line (120k) is refused tools, so it
  reports `context line: continue from <where>`. The manager starts a
  fresh writer with job `continue`, never the same job from scratch.
- **Which step is whose:** Part A 1-4 (or light path 1) = writer
  `intake`; A5 = manager asks. B1 = writer `idea`; B2 = manager asks the
  pieces question; B3 = writer `apply`, then the manager asks what it
  returns. C1 = writer `phases`; C2 = manager asks the phases question;
  C3 = writer `apply`. Ready gate: the manager starts the
  `plan-reviewer`s; their report paths go to a writer `apply`. The review
  passes below are the writer's.
- **Changes the owner asks for** mid-interview go to a writer `apply`
  as a D; the manager asks again only the pieces or phases it returns
  as changed.

## The interview: how planning feels

The goal, in the owner's words (2026-09-28): *"the concept for the plan
is that during execution the LLM should never make decisions on its
own. So the planning phase is there to ask all the specifics, if there's
100 questions so be it, if there's 5 then so be it. But the goal is to
specify everything."*

Narrowed by the owner, 2026-09-30: **everything the owner sees, hears or
gets** is settled in planning, so a running phase never makes a choice
the owner would have made. Two kinds of choice are **not** asked:

- **Numbers the code can give.** A clearance, an offset, a count that
  fits, a timing: the writer works it out from the code, with the
  working in the plan ("Numbers and math", below). Not asked.
- **Clear from the code.** When the code, a D or a rule makes one option
  clearly right, it is written as a D marked `(from code)`, not asked.

**Ask only about gaps** (owner, 2026-09-30): a question is asked only
when it is a real choice the owner said nothing about and should have,
or something they missed. The owner takes the Recommended option on
almost every design question, so a question whose Recommended option is
obvious is not asked: write it as a D and move on. Questions are the
tool, not the target: there is no minimum count, no word count. So
planning is:

> ask what is open → write it into the plan → review the plan once →
> what the review finds becomes a question or a fix → a second review
> only when the first found something that cannot be built or would
> build the wrong thing (owner, 2026-09-30: vangapfix's 14 review rounds
> cost 3h45; rounds 7 to 14 found only wording).

Execution that stops or defers a phase for a question is a planning
miss, not the plan working (owner, 2026-09-29: "stopping midway is not
the goal, it should be a rare occurrence"). Ask here what a phase would
otherwise have to ask.

- **Every question goes through `AskUserQuestion`** (the UI), never as
  prose that ends the turn. Writers return them ready; the manager asks
  them as soon as it has them. Calls are consecutive in the **same turn**:
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
  marked `→ phase decides`: what cannot be known before building, with
  what to measure and the rule ("Numbers and math"), or one the owner
  agreed to leave.
- **Never stop early.** Never end a planning turn to "let the owner
  think"; never write "ready when you are"; never skip a real gap (above)
  because the owner seems tired of questions.
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
- Every question quotes the Brief line, or says in plain words the
  decision or piece it is about, so the owner knows where they are.
  **Never a bare number:** not "per D4" but "the 5 cm overlap rule (D4)".
  The owner has not memorised the D list. The same holds for the report
  at the end of a planning turn.
- After each call: write every answer into the plan as `D<n>`, bump the
  count under `Interview`, commit the plan by path. Then the next call.

### The review pass (used after every part)

Read the plan section (or the whole plan) **as the implementer who must
build it from that text alone**, and ask one question: *what would make
a phase impossible to build, or make it build the wrong thing?* That
covers an open choice (above) two implementers would settle differently
in a way the owner would notice, a line that contradicts a D, and a
number or name the code does not have. Wording that could be read two
ways but builds the same thing either way is no finding. Each item is
either fixed from a source (write the D, `(from <source>)`) or becomes a
question. Ask them all and apply the answers.

**The cap: one round, a second only when needed, never a third.** A
second review runs only when the first found something that cannot be
built or would build the wrong thing, and it reads only what those
fixes changed. After the second round (or after the first, when it
found nothing of that kind), anything left goes under Open items as
`review leftover: <item>` and the part is done.

### Numbers and math (owner, 2026-10-01)

A plan is a design document with the math in it, complete enough to be
the perfect prompt for each phase (owner, 2026-10-01: "turn an idea
into a proper design document with math"). So the writer works out
every size, offset, count, angle and timing the result needs, from the
code, and writes it into the phase with its working on one line:

> strip depth = gap 4.2 cm (`van_body.gd:212`) − lip 3.9 cm
> (`van_doors.gd:88`) = 0.3 cm, so 0.5 cm with the 0.2 cm overlap rule
> (D4). Check: `gap_check g31` = 0 px; else widen by the measured gap
> + 0.2 cm.

Every input names where it came from (`file:line`, a D, a rule); every
number carries its **check** (what the phase measures once) and its
**fallback** (what to do when the measurement disagrees). The phase
builds with the number, measures once, and applies the fallback only
when the check fails, recording it as `D<n> (auto)`.
`→ phase decides: measure X, then apply rule Y` is left only for what
cannot be known before building (the frame cost of a new effect, how a
physics joint settles); it still names X and the rule. A number no code,
rule or D gives (a feel, a look, a tuning value the owner will notice)
is a question, never a guess.

### Plan size (owner, 2026-09-30)

A phase session starts at about 40k and must fit its work under its
line, so the plan file is a budget, not a record. vangapfix reached
130 KB with 68 decisions and left each session room for one small step.

- **Budget:** the plan file at most **20 KB** for up to 6 phases (plus
  3 KB per phase past 6); each phase section at most **2.5 KB**. Check
  with `wc -c` (and the phase's lines) after Part C and at the ready
  gate.
- **Decisions fold into the phase that uses them.** While asking, every
  answer goes into Decisions as `D<n>` (so each commit keeps it). When
  Part C writes the phases, a D used by one phase is written into that
  phase in plain words (keep `(D<n>)` after it) and taken out of the
  list; a D used by several phases becomes one line under Constraints
  and is taken out too. A decision that replaces or narrows another is
  written over it: the old one is deleted, never kept as "narrowed by".
  At the ready gate the Decisions list is empty or holds only what no
  phase carries yet; while running it collects the `(auto)` ones.
- **Cut, do not keep.** Current state holds only facts a phase needs
  and does not state itself. The Option map is deleted at the ready gate
  (its answers live in the phases). Research lives in
  `.claude/plans/research/`, never pasted into the plan. Review records
  are one line each (round, what it changed), never the prompts.
- **Still over:** the plan is two plans. Ask the owner which half runs
  first (a real choice), move the other half's Brief lines into a new
  plan file with `Stage: planning`, and finish this one.

### Light path (small briefs)

A brief that touches **one area** and adds **no new user-facing design**
(a fix, a seal, a tuning pass, tooling) takes the light path; decide it
from the Brief at intake and record it as a D `(from Brief)`. Anything
that adds a new thing the player or visitor sees or does takes the full
path. The light path:

1. **One writer `intake` (light)** over the area: Current state,
   `file:line` anchors, what is broken and where, the numbers the fix
   needs. No research digest, no option map.
2. **One batch of questions** (one `AskUserQuestion` round, up to 4),
   only the real gaps. `Interview: A done`.
3. **No Initial idea** (record `Initial idea skipped (light path)`).
   A writer `phases` writes them straight from the Brief and the
   answers, with their math; the manager shows them
   in one question (Part C step 2). `Interview: C done`.
4. **One `plan-reviewer` build round**, the same cap as the ready gate;
   no design-fit or art-style check unless looks change.

Then the ready gate as usual. A light-path plan aims at 10 KB.

### Part A · Brief and direction

1. **Intake.** Explore the current state (grep `.claude/MAP.md` first,
   then read around the hits; `file:line` anchors, no code bodies). Write
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
   - **Pass test.** When the Brief says how the result is judged (what a
     viewer must be able to say, "if X it is not done", a number to
     hit), copy those words verbatim into the plan's `## Pass test`.
     When the plan changes looks and the Brief gives none, the writer
     drafts one from the Brief (two or three things a viewer must be
     able to say) and it is asked. The Pass test is what "done" means:
     every phase serves it, and the run stops when it fails (`run.md`).
   - **Rules that narrow the Brief are asked.** When a project rule,
     cap or budget (art rules, palette limits, perf, baselines) would
     limit what the Pass test needs, ask which wins, saying what each
     answer looks like. Never fold such a rule in silently (owner,
     2026-10-07: van-interior-salvage's paint caps from the art rules
     kept every donor van the same dark wall, so its Pass test could
     not pass, and that was found only in phase 11 of 12).
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
2. **Show the pieces to the owner, once, together.** One question with
   every piece in plain words (a line or two each, no bare D numbers):
   *"This is what you will get: <pieces>. Right?"* with "That is it
   (Recommended) / Change a piece (say which and what in Other) /
   Different direction". Only a changed piece is shown again, on its
   own. Record under `Walk-through` (pieces, answer, D numbers).
3. **Review pass** over the pieces (the cap above): every `[?]` and
   every finding becomes a question. Rewrite the prose with the answers;
   no `[?]` may remain. Write `Interview: B done · <count> asked`.

A plan with no user-facing result (tooling, workflow) may record
"Initial idea skipped" as a D the owner chose; its phases then carry
every piece.

### Part C · Phases and their review

1. **Write the phases** from the Initial idea. Each phase: kind
   (research/doc/code/review), the pieces it implements, research
   topics, deliverables with their numbers worked out ("Numbers and
   math"), verification, the D numbers it rests on. **No
   phase may be of kind "owner talk"**: every question is asked here,
   now. **Size:** a code phase is at most two implementer specs and at
   most two files it reads to design (name them); more than that is two
   phases. A phase's section is self-contained: the decisions it uses
   are folded into it in plain words (Plan size, above), because an
   unattended session sees only that section, Constraints and Carry
   forward. At most 2.5 KB.
   Verification names the check that actually sees the change (see
   "Verify in a phase" in `run.md`; read only that section) and **who
   runs each check**: the implementer (commands, numbers), the
   `reviewer`, or the `look-judge` (pictures judged against words). The
   phase session never reads a picture, so a check only it could do is
   no check (van-interior-salvage: "judge the cabin views by the Brief"
   in every phase, judged by nobody until phase 11).
   - **Look proof phase** (owner, 2026-10-07, required): a full-path
     plan whose Pass test is about looks has, as phase 1 or 2 (after
     only what it needs to render), a cheap phase that builds the
     crudest version of the look: its paints, light, scale and a few
     stand-in pieces, temporary code allowed. Its Verification is the
     Pass test judged by the `look-judge` on the views and seeds the
     Pass test names; every later phase Needs it. It exists to find out
     in an hour, not after ten phases, that the plan's numbers cannot
     pass.
   - **Look checks** (phases that change what the Pass test judges, at
     least the look proof, one mid-way and the last before any swap or
     deletion): Verification ends with the `look-judge` on the named
     shots, and the pictures go to the owner too. A FAIL after the
     phase's tuning fallback stops the run (`run.md`).
   - **A phase that deletes or replaces the old version** (a swap, a
     removal) Needs the last look check, and runs only after it passed.
   Fill
   Scope, Constraints, the Progress table,
   including each phase's **Needs**: the earlier phases whose output it
   builds on (`-` for none), so a deferred phase holds back only what
   depends on it. Commit.
2. **Show the phases to the owner, once, together.** One question with
   every phase in one plain line (what it delivers, what it must not
   touch, how it is checked): *"The work runs in these phases: <list>.
   Right?"* with "Right (Recommended) / Missing something (say what in
   Other) / Split or merge a phase (say which in Other)". Splits and
   merges rewrite the Progress table; only the changed phases are shown
   again. Record under each phase: `Reviewed: <answer, D numbers>`.
3. **Review pass** over each phase as the session that will run it,
   seeing only that section: draft its specs in your head (files,
   functions, names, numbers, text, what the screenshot shows); every
   blank that would make it build the wrong thing becomes a question.
   Same cap as above. Write `Interview: C done · <count> asked`.

### Ready gate (all true, or keep going)

- **Fresh-eyes review, capped.** One `plan-reviewer` subagent (Opus,
  read-only; never the built-in `Plan` agent, which has no pinned model)
  reads the whole plan file: give it the path and "check: build". It
  answers per phase *what would make this phase impossible to build, or
  make it build the wrong thing?*, with the line quoted, and knows that
  wording which builds the same thing either way is no finding. Each
  item is fixed from a source or asked. A second
  fresh review runs only when the first found such an item, and reads
  only the lines those fixes changed. There is never a third: what is
  left goes under Open items as `review leftover: <item>`, and the gate
  passes with it.
- **Two one-shot checks, only when the plan needs them** (one
  `plan-reviewer` each, "check: design fit" or "check: art style", in
  parallel with the build review; one round each, never repeated; findings are asked or become `review
  leftover` lines). *Design fit*, when the plan changes what a user sees,
  hears or does: does the result as planned make the game or portfolio
  better for the people it is for, judged against the Brief and the
  project's purpose in `CLAUDE.md`? *Art style*, when the plan changes
  looks: does it match the project's art rules (`CLAUDE.md`,
  `.claude/rules/`, `.claude/project/`) and the look of what stands next
  to it? Skip both for tooling, workflow and invisible fixes.
- `Interview` shows A, B and C done. Open items: none except `review
  leftover` lines. No `[?]` anywhere. Every number a phase builds with
  has its working, check and fallback ("Numbers and math"); every `→
  phase decides` names what to measure and the rule, or is one the owner
  agreed to leave.
- **Pass test:** filled when the Brief judges the result or the plan
  changes looks; a look plan has its look proof phase, its look checks
  name the `look-judge`, and a swap or deletion phase Needs the last
  look check. Every Verification check names who runs it.
- Every piece has a Walk-through line; every phase has a `Reviewed:`
  line, rests on at least one decision or Brief line, has its Needs
  filled, and is `todo` in the Progress table. Constraints and Scope are
  filled.
- **Within budget** (Plan size): decisions folded, superseded ones
  deleted, the Option map gone, the file at most 20 KB and each phase at
  most 2.5 KB.

Then ask one last `AskUserQuestion` with one question: "A question the
plan missed, with no clear answer: park that phase for you to answer
later (Recommended) / take the recommended option and keep going", which
sets `Questions: ask` or `Questions: auto` in the header. Set `Stage:
ready`, commit the plan and research by path. **Do not start the run
here**: the planning session is heavy, and the run is supervised from a
fresh one that stays small (owner, 2026-10-01: "once the plan is made
and ready to execute, tell me to clear the window and write the prompt
to start the execution"). There is no "Start running the plan?"
question. **Never run a phase in the planning session**: each phase runs
in its own fresh session under the runner (owner, 2026-09-28,
workflow-port D25). A change the owner asks for later reopens the
interview: record it as a D, show the pieces and phases it touches
again, and run the gate again.

End the turn with the plan in a few plain lines (what it builds, the
phases), then the go prompt (`workflow.md` "The go prompt": checkout and
branch from git, now) as the last thing, nothing after it:

    Plan ready. Please run `/clear`, then paste this:

    ```
    go: run plan <name> one phase at a time. Checkout <path> on branch <branch>, <mode> mode. Read the "Supervising the run" part of .claude/skills/plan/run.md first, and .claude/plans/<name>.state.md if it exists; never the plan.
    ```

If `tools/autoplan.py` does not exist in this checkout, the first clause
is instead "Read .claude/plans/<name>.state.md and execute the next
phase" (no `go:`; the phase then runs in the app, `run.md`).

Context: auto-compact is off (owner's rule, 2026-09-29). The manager
stays small because writers do the work, but in planning it may run
past its line to finish what is in flight (owner, 2026-10-01: "on the
interview phase and before it's ok if you go beyond the limit and ask
me to clear and continue"): a question round already asked, or a writer
already running. At `CONTEXT WATCH` start no new writer and ask no new
question. Record the answers you already have as D's,
make sure `Interview` names the open part and `Open items` lists every
choice still to ask, and commit the plan by path. No
`.claude/handoff.md`: the plan file *is* the handoff. Then hard-stop.
The turn ends with the go prompt (`workflow.md` "The go prompt"),
nothing after it:

    Interview paused (context full). Please run `/clear`, then paste this:

    ```
    go: continue the interview for plan <name> from Part <letter>. Checkout <path> on branch <branch>, <mode> mode. Read the Interview line of .claude/plans/<name>.md first.
    ```

That prompt then resumes through "`/plan` or `go` while Stage is
`planning`" in a fresh context.
