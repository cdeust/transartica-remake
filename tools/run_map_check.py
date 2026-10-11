#!/usr/bin/env python3
"""MIT. Serialize bounded local checks; an aborted check is never a pass.

Owner policy: tasks/evidence/resource-resume-20261011.md.
POSIX sessions/killpg/flock: docs.python.org/3.14/library/{subprocess,os,fcntl}.html.
RSS is sampled for the owned process group, not a kernel or machine-wide limit.
Commands must remain in their launch group (no daemonization/setsid).
"""
import argparse
from contextlib import contextmanager
import fcntl
import io
import json
import math
import os
from pathlib import Path
import selectors
import signal
import subprocess
import time
from collections.abc import Iterator
from types import FrameType
from typing import TextIO

# Retain the previous runner's diagnostic size, polling and termination grace.
LOG_BYTES = 4096
POLL_SECONDS = 0.2
GRACE_SECONDS = 2
# Owner 10 Oct initial budget; 1 GiB is the previously authorized upper bound.
DEFAULT_MEMORY_MIB = 768
MAX_MEMORY_MIB = 1024
# The documented native-check protocol already uses this deadline.
DEFAULT_SECONDS = 15


class GuardError(RuntimeError):
    """The check cannot continue within its resource contract."""


class DiagnosticLog:
    """Bound retained output; scan every chunk, including split error markers."""
    def __init__(self) -> None:
        self.preview = bytearray()
        self.tail = b''
        self.total = 0
        self.failed = False

    def add(self, chunk: bytes) -> None:
        self.failed |= errors(self.tail + chunk)
        self.tail = (self.tail + chunk)[-len(b'SCRIPT ERROR:'):]
        self.total += len(chunk)
        self.preview.extend(chunk[:max(0, LOG_BYTES - len(self.preview))])

    def render(self) -> str:
        text = self.preview.decode('utf-8', errors='replace')
        if self.total > len(self.preview):
            text += '\n[output truncated; all received bytes scanned for errors]\n'
        return text


def errors(transcript: bytes) -> bool:
    return b'SCRIPT ERROR:' in transcript or b'\nERROR:' in transcript or transcript.startswith(b'ERROR:')


def group_stats(pgid: int) -> tuple[int, int]:
    """One bounded process-table read; zombies consume no active workload."""
    result = subprocess.run(['ps', '-A', '-o', 'pgid=,rss=,stat='],
                            text=True, capture_output=True, timeout=GRACE_SECONDS)
    if result.returncode or not result.stdout.strip():
        raise GuardError('resource monitor unavailable')
    rss, count = 0, 0
    try:
        for line in result.stdout.splitlines():
            group, memory, state = line.split()
            group, memory = int(group), int(memory)
            if memory < 0:
                raise ValueError('negative RSS')
            if group == pgid and not state.startswith('Z'):
                rss += memory
                count += 1
    except ValueError as error:
        raise GuardError('malformed resource monitor output') from error
    return rss, count


def signal_group(pgid: int, signum: int) -> None:
    try:
        os.killpg(pgid, signum)
    except ProcessLookupError:
        pass


def group_stopped(process: subprocess.Popen, deadline: float) -> bool:
    while time.monotonic() < deadline:
        process.poll()  # Reap our direct child, including after SIGKILL.
        try:
            if group_stats(process.pid)[1] == 0:
                return True
        except (GuardError, OSError, subprocess.TimeoutExpired):
            return False
        time.sleep(POLL_SECONDS)
    return False


def stop(process: subprocess.Popen) -> None:
    """The group remains ours even when its original parent has exited."""
    signal_group(process.pid, signal.SIGTERM)
    if not group_stopped(process, time.monotonic() + GRACE_SECONDS):
        signal_group(process.pid, signal.SIGKILL)
        if not group_stopped(process, time.monotonic() + GRACE_SECONDS):
            raise GuardError('owned process group cleanup could not be verified')
    process.wait(timeout=GRACE_SECONDS)


def shared_lock_path() -> Path:
    root = Path(__file__).resolve().parents[1]
    common = subprocess.run(
        ['git', '-C', str(root), 'rev-parse', '--path-format=absolute', '--git-common-dir'],
        capture_output=True, text=True, check=True, timeout=GRACE_SECONDS)
    # All worktrees resolve to the same main checkout; never write inside .git.
    return Path(common.stdout.strip()).parent / 'tasks/evidence/map-check.lock'


@contextmanager
def exclusive_check(path: Path) -> Iterator[TextIO]:
    # Keep this inode: unlinking a flock file can allow two concurrent holders.
    with path.open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise GuardError('another local check is already running') from error
        yield lock


def receive(process: subprocess.Popen, log: DiagnosticLog) -> bool:
    """Nonblocking single chunk: output cannot starve RSS/deadline checks."""
    try:
        chunk = os.read(process.stdout.fileno(), io.DEFAULT_BUFFER_SIZE)
    except BlockingIOError:
        return False
    log.add(chunk)
    return bool(chunk)


def watch(process: subprocess.Popen, budget: argparse.Namespace, log: DiagnosticLog) -> tuple[int, str | None]:
    started, peak = time.monotonic(), 0
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while True:
            if selector.select(timeout=0):
                receive(process, log)
            if log.failed:
                return peak, 'Godot script/render error'
            rss, count = group_stats(process.pid)
            peak = max(peak, rss)
            if rss > budget.memory_mib * 1024:
                return peak, 'memory budget exceeded'
            if process.poll() is not None:
                # The snapshot may predate the exit; confirm surviving children.
                _, remaining = group_stats(process.pid)
                return peak, 'parent exited with active children' if remaining else None
            if not count:
                raise GuardError('running process absent from resource monitor')
            if time.monotonic() - started > budget.seconds:
                return peak, 'time budget exceeded'
            time.sleep(POLL_SECONDS)


def interrupted(signum: int, _frame: FrameType | None) -> None:
    raise GuardError(f'interrupted by signal {signum}')


@contextmanager
def interruption_cleanup() -> Iterator[None]:
    previous = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)



@contextmanager
def deferred_interruptions() -> Iterator[list[int]]:
    """Record launch-time interruption until the process handle is available."""
    pending = []

    def record(signum: int, _frame: FrameType | None) -> None:
        if not pending:
            pending.append(signum)

    previous = {sig: signal.signal(sig, record) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        yield pending
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def finish_process(process: subprocess.Popen, log: DiagnosticLog, nonblocking: bool) -> None:
    # Ignore repeated interrupts only during bounded teardown, then restore.
    previous = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGINT, signal.SIGTERM)}
    try:
        stop(process)
    finally:
        try:
            # No final blocking read: an escaped pipe holder cannot hang shutdown.
            drain_until = time.monotonic() + GRACE_SECONDS
            while nonblocking and time.monotonic() < drain_until and receive(process, log):
                pass
        finally:
            process.stdout.close()
            for sig, handler in previous.items():
                signal.signal(sig, handler)


def run_check(command: list[str], budget: argparse.Namespace, lock: TextIO) -> int:
    started, peak, aborted = time.monotonic(), 0, None
    log, process, nonblocking = DiagnosticLog(), None, False
    try:
        # Defer handled signals across Popen and assignment to preserve ownership.
        with deferred_interruptions() as pending:
            # nice applies before exec; children inherit the reduced priority.
            # Inherited lock survives supervisor death while the child retains it.
            process = subprocess.Popen(['nice', '-n', '10', *command],
                                       start_new_session=True, pass_fds=(lock.fileno(),),
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if pending:
            raise GuardError(f'interrupted by signal {pending[0]} during launch')
        os.set_blocking(process.stdout.fileno(), False)
        nonblocking = True
        peak, aborted = watch(process, budget, log)
    except (GuardError, OSError, subprocess.TimeoutExpired) as error:
        aborted = str(error)
    finally:
        if process is not None:
            try:
                finish_process(process, log, nonblocking)
            except (GuardError, OSError, subprocess.TimeoutExpired) as error:
                aborted = str(error)
    if log.failed:
        aborted = 'Godot script/render error'
    print(log.render(), end='')
    print(json.dumps({'exit': process.returncode if process is not None else None,
                      'aborted': aborted, 'peak_rss_kib': peak,
                      'rss_scope': 'owned_process_group',
                      'elapsed_s': round(time.monotonic() - started, 3)}))
    return 2 if aborted else process.returncode

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=DEFAULT_SECONDS)
    parser.add_argument('--memory-mib', type=int, default=DEFAULT_MEMORY_MIB)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if not math.isfinite(args.seconds) or args.seconds <= 0:
        parser.error('--seconds must be finite and positive')
    if not 0 < args.memory_mib <= MAX_MEMORY_MIB:
        parser.error(f'--memory-mib must be between 1 and {MAX_MEMORY_MIB}')
    if args.command[:1] == ['--']:
        args.command = args.command[1:]
    if not args.command:
        parser.error('a command is required')
    return args


def main() -> int:
    args = parse_args()
    try:
        with interruption_cleanup(), exclusive_check(shared_lock_path()) as lock:
            # Verify ps works before creating any workload.
            group_stats(os.getpgrp())
            return run_check(args.command, args, lock)
    except (GuardError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'exit': None, 'aborted': str(error), 'peak_rss_kib': 0}))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
