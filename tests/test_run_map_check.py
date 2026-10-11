"""MIT. Small process probes for the shared-workstation runner."""
import contextlib
import io
import json
import tempfile
from types import SimpleNamespace
from unittest import mock
import importlib.util
import os
import signal
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get('RUN_MAP_CHECK_SOURCE', ROOT / 'tools/run_map_check.py'))
SPEC = importlib.util.spec_from_file_location('runner', SOURCE)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class ProcessCleanupTests(unittest.TestCase):
    def test_parent_exit_does_not_leave_its_child_running(self):
        child_code = 'import signal; print("ready", flush=True); signal.pause()'
        parent_code = (
            'import subprocess, sys; '
            f'p = subprocess.Popen([sys.executable, "-c", {child_code!r}], '
            'stdout=subprocess.PIPE, text=True); '
            'assert p.stdout.readline().strip() == "ready"; '
            'print(p.pid, flush=True)'
        )
        parent = subprocess.Popen([sys.executable, '-c', parent_code],
                                  start_new_session=True, stdout=subprocess.PIPE,
                                  text=True)
        try:
            child_pid = int(parent.stdout.readline())
            parent.wait(timeout=2)
            runner.stop(parent)
            result = subprocess.run(['ps', '-o', 'stat=', '-p', str(child_pid)],
                                    text=True, capture_output=True, check=False)
            self.assertTrue(not result.stdout.strip() or result.stdout.strip().startswith('Z'),
                             'owned child still running after parent exit')
        finally:
            try:
                os.killpg(parent.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            parent.wait(timeout=2)
            parent.stdout.close()



class GuardBehaviorTests(unittest.TestCase):
    def test_group_rss_includes_children_and_excludes_other_jobs(self):
        table = '10 100 S\n10 240 S\n11 900 S\n10 50 Z\n'
        with mock.patch.object(runner.subprocess, 'run', return_value=SimpleNamespace(
                returncode=0, stdout=table)):
            self.assertEqual(runner.group_stats(10), (340, 2))

    def test_broken_monitor_is_rejected(self):
        for table in ('', '10 nope S\n', '10 -1 S\n', '10 22\n'):
            with (
                self.subTest(table=table),
                mock.patch.object(runner.subprocess, 'run',
                                  return_value=SimpleNamespace(returncode=0, stdout=table)),
                self.assertRaises(runner.GuardError),
            ):
                runner.group_stats(10)

    def test_output_is_bounded_but_errors_beyond_preview_are_seen(self):
        log = runner.DiagnosticLog()
        log.add(b'x' * (runner.LOG_BYTES + 1))
        log.add(b'\nSCRIPT ER')
        log.add(b'ROR: broken')
        self.assertEqual(len(log.preview), runner.LOG_BYTES)
        self.assertTrue(log.failed)
        self.assertIn('truncated', log.render())

    def test_invalid_budgets_and_missing_command_are_rejected(self):
        cases = [['--seconds', 'nan', 'true'], ['--seconds', '0', 'true'],
                 ['--memory-mib', '1025', 'true'], ['--memory-mib', '0', 'true'], []]
        for args in cases:
            with (
                self.subTest(args=args),
                contextlib.redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit),
            ):
                runner.parse_args(args)

    def test_lock_prevents_a_second_cli_from_launching(self):
        with tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests') as tmp:
            marker = Path(tmp) / 'must-not-exist'
            with runner.exclusive_check(runner.shared_lock_path()):
                result = subprocess.run(
                    [sys.executable, '-B', str(ROOT / 'tools/run_map_check.py'), '--',
                     sys.executable, '-c', f'open({str(marker)!r}, "w").close()'],
                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertIn('another local check', result.stdout)
            self.assertFalse(marker.exists())
            # Release is descriptor-based, with the same persistent inode.
            with runner.exclusive_check(runner.shared_lock_path()):
                pass

    def test_memory_abort_without_large_allocation(self):
        with tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests') as tmp:
            output = io.StringIO()
            with (
                runner.exclusive_check(Path(tmp) / 'lock') as lock,
                mock.patch.object(runner, 'group_stats', side_effect=[(2048, 2), (0, 0)]),
                contextlib.redirect_stdout(output),
            ):
                code = runner.run_check(
                    [sys.executable, '-c', 'import signal; signal.pause()'],
                    SimpleNamespace(memory_mib=1, seconds=15), lock)
            self.assertEqual(code, 2)
            receipt = json.loads(output.getvalue().splitlines()[-1])
            self.assertEqual(receipt['peak_rss_kib'], 2048)
            self.assertEqual(receipt['aborted'], 'memory budget exceeded')

    def test_monitor_failure_stops_owned_group(self):
        with tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests') as tmp:
            output = io.StringIO()
            with (
                runner.exclusive_check(Path(tmp) / 'lock') as lock,
                mock.patch.object(runner, 'group_stats',
                                  side_effect=[runner.GuardError('monitor failed'), (0, 0)]),
                contextlib.redirect_stdout(output),
            ):
                code = runner.run_check(
                    [sys.executable, '-c', 'import signal; signal.pause()'],
                    SimpleNamespace(memory_mib=768, seconds=15), lock)
            self.assertEqual(code, 2)
            self.assertIn('monitor failed', output.getvalue())

    def test_short_success_and_error_after_normal_exit(self):
        for command, expected in [('print("PASS probe")', 0), ('print("ERROR: bad")', 2)]:
            with self.subTest(command=command):
                result = subprocess.run(
                    [sys.executable, '-B', str(ROOT / 'tools/run_map_check.py'), '--',
                     sys.executable, '-c', command], capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected, result.stdout)

    def test_sigterm_cleans_up_and_releases_the_lock(self):
        child_code = 'import signal; print("READY", flush=True); signal.pause()'
        # File acknowledgement avoids depending on the runner's buffered preview.
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests'))
        fifo = Path(tmp) / 'ready'
        os.mkfifo(fifo)
        child_code = f'open({str(fifo)!r}, "w").write("READY\\n"); import signal; signal.pause()'
        monitor = subprocess.Popen(
            [sys.executable, '-B', str(ROOT / 'tools/run_map_check.py'), '--',
             sys.executable, '-c', child_code], stdout=subprocess.PIPE, text=True)
        try:
            with fifo.open() as ready:
                self.assertEqual(ready.readline(), 'READY\n')
            monitor.send_signal(signal.SIGTERM)
            output, _ = monitor.communicate(timeout=5)
            self.assertEqual(monitor.returncode, 2, output)
            self.assertIn('interrupted by signal', output)
            with runner.exclusive_check(runner.shared_lock_path()):
                pass
        finally:
            if monitor.poll() is None:
                monitor.terminate()
                monitor.communicate(timeout=5)
            monitor.stdout.close()

    def test_stubborn_child_is_killed_but_unrelated_process_survives(self):
        def cleanup(process):
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=2)
            process.stdout.close()

        child_code = ('import signal; signal.signal(signal.SIGTERM, signal.SIG_IGN); '
                      'print("READY", flush=True); signal.pause()')
        child = subprocess.Popen([sys.executable, '-c', child_code],
                                 start_new_session=True, stdout=subprocess.PIPE, text=True)
        sentinel = subprocess.Popen([sys.executable, '-c', child_code],
                                    start_new_session=True, stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(child.stdout.readline(), 'READY\n')
            self.assertEqual(sentinel.stdout.readline(), 'READY\n')
            runner.stop(child)
            self.assertEqual(child.returncode, -signal.SIGKILL)
            self.assertIsNone(sentinel.poll())
        finally:
            for process in (child, sentinel):
                cleanup(process)



    def test_exited_parent_uses_a_fresh_process_snapshot(self):
        process = mock.Mock()
        process.pid = 77
        process.poll.return_value = 0
        selector = mock.MagicMock()
        selector.__enter__.return_value.select.return_value = []
        with mock.patch.object(runner.selectors, 'DefaultSelector', return_value=selector):
            with mock.patch.object(runner, 'group_stats', side_effect=[(100, 1), (0, 0)]):
                peak, aborted = runner.watch(
                    process, SimpleNamespace(memory_mib=768, seconds=15), runner.DiagnosticLog())
        self.assertEqual(peak, 100)
        self.assertIsNone(aborted)

    def test_setup_failure_still_stops_the_launched_process(self):
        launched = []
        real_popen = subprocess.Popen

        def launch(*args, **kwargs):
            process = real_popen(*args, **kwargs)
            launched.append(process)
            return process

        with tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests') as tmp:
            with (
                runner.exclusive_check(Path(tmp) / 'lock') as lock,
                mock.patch.object(runner.subprocess, 'Popen', side_effect=launch),
                mock.patch.object(runner.os, 'set_blocking', side_effect=OSError('setup failed')),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                code = runner.run_check(
                    [sys.executable, '-c', 'import signal; signal.pause()'],
                    SimpleNamespace(memory_mib=768, seconds=15), lock)
        self.assertEqual(code, 2)
        self.assertTrue(launched)
        self.assertIsNotNone(launched[0].poll())

    def test_launch_signal_is_deferred_until_the_handle_is_owned(self):
        launched = []
        real_popen = subprocess.Popen

        def launch(*args, **kwargs):
            process = real_popen(*args, **kwargs)
            launched.append(process)
            os.kill(os.getpid(), signal.SIGTERM)
            return process

        with tempfile.TemporaryDirectory(prefix='.guard-test-', dir=ROOT / 'tests') as tmp:
            output = io.StringIO()
            with (
                runner.exclusive_check(Path(tmp) / 'lock') as lock,
                mock.patch.object(runner.subprocess, 'Popen', side_effect=launch),
                contextlib.redirect_stdout(output),
            ):
                code = runner.run_check(
                    [sys.executable, '-c', 'import signal; signal.pause()'],
                    SimpleNamespace(memory_mib=768, seconds=15), lock)
        self.assertEqual(code, 2)
        self.assertIn('during launch', output.getvalue())
        self.assertIsNotNone(launched[0].poll())

    def test_second_signal_does_not_interrupt_cleanup(self):
        child_code = ('import signal; signal.signal(signal.SIGTERM, signal.SIG_IGN); '
                      'print("READY", flush=True); signal.pause()')
        process = subprocess.Popen([sys.executable, '-c', child_code],
                                   start_new_session=True, stdout=subprocess.PIPE)
        real_signal_group = runner.signal_group

        def send_with_interrupt(pgid, signum):
            real_signal_group(pgid, signum)
            if signum == signal.SIGTERM:
                os.kill(os.getpid(), signal.SIGTERM)

        try:
            self.assertEqual(process.stdout.readline(), b'READY\n')
            os.set_blocking(process.stdout.fileno(), False)
            with (
                runner.interruption_cleanup(),
                mock.patch.object(runner, 'signal_group', side_effect=send_with_interrupt),
            ):
                runner.finish_process(process, runner.DiagnosticLog(), True)
            self.assertEqual(process.returncode, -signal.SIGKILL)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=2)
            process.stdout.close()


if __name__ == '__main__':
    unittest.main()
