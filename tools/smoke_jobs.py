"""Parallel job runner for tools/smoke.py: Popen jobs with a log file each, longest first."""
import dataclasses
import pathlib
import shutil
import subprocess
import threading
import time
from typing import Callable


@dataclasses.dataclass
class Job:
    name: str
    args: list[str]
    est: float  # estimated seconds alone; only used to order the start
    # Blocking launcher (the hidden-desktop helper): runs in a thread, returns (code, output).
    blocking: Callable[[], tuple[int, str]] | None = None
    start: float = 0.0
    secs: float = 0.0
    returncode: int = -1
    output: str = ""
    timed_out: bool = False
    error: str = ""
    log: pathlib.Path | None = None
    proc: subprocess.Popen | None = None
    thread: threading.Thread | None = None


def _run_blocking(job: Job, timeout: int) -> None:
    try:
        assert job.blocking is not None
        job.returncode, job.output = job.blocking()
    except subprocess.TimeoutExpired:
        job.timed_out = True
    except OSError as err:
        job.error = str(err)


def _launch(job: Job, root: pathlib.Path, jobs_dir: pathlib.Path, timeout: int) -> None:
    job.start = time.time()
    if job.blocking is not None:
        job.thread = threading.Thread(target=_run_blocking, args=(job, timeout), daemon=True)
        job.thread.start()
        return
    job.log = jobs_dir / (job.name.replace("/", "_").replace(" ", "_") + ".log")
    with open(job.log, "wb") as handle:
        job.proc = subprocess.Popen(
            job.args,
            cwd=root,
            stdout=handle,
            stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )


def _poll(job: Job, timeout: int) -> bool:
    """True once the job has finished (or been killed on its timeout)."""
    if job.thread is not None:
        return not job.thread.is_alive()
    assert job.proc is not None and job.log is not None
    code = job.proc.poll()
    if code is None:
        if time.time() - job.start <= timeout:
            return False
        job.proc.kill()
        job.proc.wait()
        job.timed_out = True
        code = job.proc.returncode
    job.returncode = code
    job.output = job.log.read_text(encoding="utf-8", errors="replace")
    return True


def run_jobs(
    jobs: list[Job], max_running: int, root: pathlib.Path, timeout: int,
) -> None:
    """Runs every job, at most `max_running` at once. The first job starts first; the
    rest start longest-estimate first. Prints one line per finished job."""
    jobs_dir = root / ".godot" / "smoke_jobs"
    shutil.rmtree(jobs_dir, ignore_errors=True)
    jobs_dir.mkdir(parents=True, exist_ok=True)
    pending = jobs[:1] + sorted(jobs[1:], key=lambda job: -job.est)
    running: list[Job] = []
    try:
        while pending or running:
            while pending and len(running) < max(max_running, 1):
                job = pending.pop(0)
                try:
                    _launch(job, root, jobs_dir, timeout)
                except OSError as err:
                    job.error = str(err)
                    print(f"== {job.name}: FAILED (could not start: {err})", flush=True)
                    continue
                running.append(job)
            time.sleep(0.5)
            for job in list(running):
                if _poll(job, timeout):
                    running.remove(job)
                    job.secs = time.time() - job.start
                    failed = job.timed_out or job.error or job.returncode != 0
                    state = "FAILED" if failed else "ok"
                    print(f"== {job.name}: {state} ({job.secs:.0f} s)", flush=True)
    finally:
        for job in jobs:
            if job.proc is not None and job.proc.poll() is None:
                job.proc.kill()
                job.proc.wait()
