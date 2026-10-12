"""Reply cap (SubagentStop): sends a subagent back once when its final reply
is over 250 words, so it answers in the caller's format (at most about 150
words plus its report path; playbook "Delegation", every agent file).

Since 2026-10-01, 28% of Explore replies and 29% of reviewer replies were
over 250 words (Explore's 90th percentile is 1,141 words), and the main
window pays for that text on every later turn.

Allowed without a word: `stop_hook_active` (block only once per stop), the
Plan agent (it returns a plan and has no Write tool), and a subagent whose
own transcript cannot be found.

The reply is the event's `last_assistant_message` when set (the transcript
file may lag); the subagent's transcript is read only when it is missing or empty.

Never fails the hook: any error allows the stop (exit 0).
"""
import json
import os
import sys

MAX_WORDS = 250


def session_dir(transcript_path):
    p = os.path.normpath(transcript_path)
    if os.path.basename(os.path.dirname(p)) == "subagents":
        return os.path.dirname(os.path.dirname(p))
    return os.path.splitext(p)[0]


def own_transcript(d):
    atp = d.get("agent_transcript_path")
    if atp and os.path.exists(atp):
        return atp
    path, agent_id = d.get("transcript_path"), d.get("agent_id")
    if not (path and agent_id):
        return None
    cand = os.path.join(session_dir(path), "subagents", f"agent-{agent_id}.jsonl")
    return cand if os.path.exists(cand) else None


def final_reply(path):
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        f.seek(max(0, size - 600_000))
        tail = f.read().decode("utf-8", "ignore")
    for line in reversed(tail.splitlines()):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if not isinstance(o, dict) or o.get("type") != "assistant":
            continue
        content = (o.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        texts = [b.get("text") or "" for b in content
                 if isinstance(b, dict) and b.get("type") == "text"]
        text = " ".join(t for t in texts if t.strip())
        if text:
            return text
    return ""


def main():
    d = json.load(sys.stdin)
    if d.get("stop_hook_active") or d.get("agent_type") == "Plan":
        return
    reply = d.get("last_assistant_message")
    if not (isinstance(reply, str) and reply.strip()):
        path = own_transcript(d)
        if not path:
            return
        reply = final_reply(path)
    n = len(reply.split())
    if n <= MAX_WORDS:
        return
    print(json.dumps({"decision": "block", "reason": (
        f"Reply cap: your reply is {n} words; the caller reads at most "
        "about 150 (playbook Delegation). Reply again with only: a status "
        "or verdict line, the files changed, at most five one-line findings "
        "with file:line anchors, and your report's path. Explore: the "
        "anchors with one line each, no code bodies. Anything longer "
        "belongs in your report file.")}))


try:
    main()
except Exception:
    pass
