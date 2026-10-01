"""Hook dispatcher: one Python process per hook event, instead of one per
hook script. `.claude/settings.json` calls `run.sh hooks.py` once for
each event; this file reads the event JSON once and runs each shared
hook script that applies, in this process (`runpy`, with stdin, stdout
and stderr captured), then merges their answers into the one reply
Claude Code expects. Every tool call used to spawn three Python
processes (git-guard or file-guard, context-watch twice) at about 270 ms
each on the owner's machine; now it spawns one.

TABLE below is the only place the shared hooks are listed. A project's
own hooks keep their own entries in `.claude/project/settings.json`
(their matchers already limit them to the tools they care about).

Merging, per event:
- PreToolUse / PostToolUse: a script that exits 2 (stderr = reason) or
  answers `permissionDecision: deny|ask` ends the chain and its answer is
  the reply. Every `additionalContext` (and any plain text) is joined
  into one `additionalContext`; `systemMessage`s are joined too.
- Stop / SubagentStop: every `decision: block` reason is joined into one
  block; `systemMessage`s are joined; exit 2 is passed through.
- SessionStart / UserPromptSubmit: plain text (and any
  `additionalContext`) is concatenated; exit 2 is passed through.

The scripts are unchanged: each still reads the event from stdin and
prints its reply, so `bash run.sh <script>.py < event.json` keeps
working for a test. Never fails the hook: any error of its own exits 0.
"""
import contextlib
import io
import json
import os
import re
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# event -> [(tool matcher or None, script)]; guards before context-watch,
# so a refused call is never measured as if it ran.
TABLE = {
    "SessionStart": [(None, "session-start.py")],
    "UserPromptSubmit": [(None, "context-watch.py")],
    "PreToolUse": [
        ("Bash|PowerShell", "git-guard.py"),
        ("Bash|PowerShell", "review-guard.py"),
        ("Read|Write|Edit|MultiEdit|NotebookEdit", "file-guard.py"),
        ("Agent|Task", "agent-guard.py"),
        (None, "context-watch.py"),
    ],
    "PostToolUse": [],
    "SubagentStop": [(None, "context-watch.py")],
    "Stop": [(None, "stop-guard.py")],
}


def matches(matcher, tool_name):
    if not matcher:
        return True
    if tool_name in matcher.split("|"):
        return True
    try:
        return re.fullmatch(matcher, tool_name or "") is not None
    except re.error:
        return False


def run_script(script, d):
    """Run one hook script in this process. Returns (exit code, stdout, stderr)."""
    path = os.path.join(HERE, script)
    if not os.path.isfile(path):
        return 0, "", ""
    out, err = io.StringIO(), io.StringIO()
    old_stdin, old_cwd, old_argv = sys.stdin, os.getcwd(), sys.argv
    sys.stdin = io.StringIO(json.dumps(d))
    sys.argv = [path]
    code = 0
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                runpy.run_path(path, run_name="__main__")
            except SystemExit as e:
                code = e.code if isinstance(e.code, int) else (0 if e.code is None else 1)
            except Exception:
                code = 0
    finally:
        sys.stdin, sys.argv = old_stdin, old_argv
        try:
            os.chdir(old_cwd)
        except OSError:
            pass
    return code, out.getvalue(), err.getvalue()


def parse_json(text):
    s = text.strip()
    if not s.startswith("{"):
        return None
    try:
        o = json.loads(s)
    except ValueError:
        return None
    return o if isinstance(o, dict) else None


def passthrough(code, out, err):
    """A script's answer, printed as it was (used when the chain ends)."""
    if out:
        sys.stdout.write(out)
    if err:
        sys.stderr.write(err)
    sys.exit(code)


def dispatch_tool(ev, d, scripts):
    contexts, system = [], []
    for script in scripts:
        code, out, err = run_script(script, d)
        if code == 2:
            passthrough(code, out, err)
        if err:
            sys.stderr.write(err)
        j = parse_json(out)
        if j is None:
            if out.strip():
                contexts.append(out.strip())
            continue
        hso = j.get("hookSpecificOutput") or {}
        if hso.get("permissionDecision") in ("deny", "ask") or j.get("decision") == "block":
            passthrough(0, json.dumps(j), "")
        if hso.get("additionalContext"):
            contexts.append(str(hso["additionalContext"]))
        if j.get("systemMessage"):
            system.append(str(j["systemMessage"]))
    if not contexts and not system:
        return
    reply = {}
    if contexts:
        reply["hookSpecificOutput"] = {"hookEventName": ev,
                                       "additionalContext": "\n".join(contexts)}
    if system:
        reply["systemMessage"] = "\n".join(system)
    print(json.dumps(reply))


def dispatch_stop(ev, d, scripts):
    reasons, system = [], []
    for script in scripts:
        code, out, err = run_script(script, d)
        if code == 2:
            passthrough(code, out, err)
        if err:
            sys.stderr.write(err)
        j = parse_json(out)
        if j is None:
            if out.strip():
                system.append(out.strip())
            continue
        if j.get("decision") == "block" and j.get("reason"):
            reasons.append(str(j["reason"]))
        if j.get("systemMessage"):
            system.append(str(j["systemMessage"]))
    if not reasons and not system:
        return
    reply = {}
    if reasons:
        reply["decision"] = "block"
        reply["reason"] = "\n".join(reasons)
    if system:
        reply["systemMessage"] = "\n".join(system)
    print(json.dumps(reply))


def dispatch_text(ev, d, scripts):
    parts = []
    for script in scripts:
        code, out, err = run_script(script, d)
        if code == 2:
            passthrough(code, out, err)
        if err:
            sys.stderr.write(err)
        j = parse_json(out)
        if j is None:
            if out.strip():
                parts.append(out.rstrip())
            continue
        hso = j.get("hookSpecificOutput") or {}
        if hso.get("additionalContext"):
            parts.append(str(hso["additionalContext"]))
        if j.get("systemMessage"):
            parts.append(str(j["systemMessage"]))
    if parts:
        print("\n".join(parts))


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    d = json.load(sys.stdin)
    ev = d.get("hook_event_name") or (sys.argv[1] if len(sys.argv) > 1 else "")
    d.setdefault("hook_event_name", ev)
    tool = d.get("tool_name") or ""
    scripts = [s for m, s in TABLE.get(ev, []) if matches(m, tool)]
    if not scripts:
        return
    if ev in ("PreToolUse", "PostToolUse"):
        dispatch_tool(ev, d, scripts)
    elif ev in ("Stop", "SubagentStop"):
        dispatch_stop(ev, d, scripts)
    else:
        dispatch_text(ev, d, scripts)


try:
    main()
except SystemExit:
    raise
except Exception:
    pass
