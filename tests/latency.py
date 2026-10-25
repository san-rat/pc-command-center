"""Opt-in Linux latency measurement; no thresholds and no runtime dependency.

Usage: python3 tests/latency.py [--script /path/to/baseline.sh] [--samples 7]
Collection uses live host data. Cached rendering/handlers reuse the same sample.
PTY timing measures key write to the completed frame. Host load affects results.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import statistics
import struct
import subprocess
import tempfile
import termios
import time

DRIVER = r'''
source "$1"
LIVE_MODE=1 TERM_COLS=80 TERM_LINES=24 RESIZE_PENDING=0
init_cpu_sample
sleep .25
collect_sample
printf 'READY\n'
while IFS= read -r action; do
    case "$action" in
        collect) collect_metrics >/dev/null ;;
        render) render_dashboard >/dev/null ;;
        handler) handle_key 2 >/dev/null ;;
        quit) break ;;
    esac
    printf 'DONE\n'
done
'''


def summarize(values):
    return {'median_ms': round(statistics.median(values), 2),
            'max_ms': round(max(values), 2), 'samples': len(values)}


def measure_functions(script, count):
    proc = subprocess.Popen(['bash', '-c', DRIVER, '_', str(script)],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            text=True, env={**os.environ, 'TERM': ''})
    result = {}
    try:
        assert proc.stdout.readline().strip() == 'READY'
        for action in ['collect', 'render', 'handler']:
            values = []
            for _ in range(count):
                start = time.perf_counter()
                proc.stdin.write(action + '\n'); proc.stdin.flush()
                assert proc.stdout.readline().strip() == 'DONE'
                values.append((time.perf_counter() - start) * 1000)
            result[action] = summarize(values)
        proc.stdin.write('quit\n'); proc.stdin.flush()
        assert proc.wait(timeout=10) == 0
    finally:
        if proc.poll() is None:
            proc.kill(); proc.wait()
        proc.stdin.close(); proc.stdout.close()
    return result


def measure_terminal(script, count):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    with tempfile.TemporaryDirectory(prefix='pcc-latency-') as directory:
        proc = subprocess.Popen(['bash', str(script), '--interval', '999999', '--no-color'],
                                stdin=slave, stdout=slave, stderr=slave,
                                env={**os.environ, 'TERM': 'xterm', 'XDG_CONFIG_HOME': directory},
                                start_new_session=True,
                                preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0))
        def frame():
            data = b''
            deadline = time.monotonic() + 15
            while b'\x1b[J' not in data:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError('completed terminal frame not received')
                if select.select([master], [], [], min(.1, remaining))[0]:
                    data += os.read(master, 65536)
            return data
        values = []
        try:
            frame()
            for index in range(count):
                start = time.perf_counter()
                os.write(master, [b'2', b'4', b'1', b'3', b'5'][index % 5])
                frame()
                values.append((time.perf_counter() - start) * 1000)
            os.write(master, b'q')
            assert proc.wait(timeout=10) == 0
        finally:
            if proc.poll() is None:
                proc.kill(); proc.wait()
            os.close(master); os.close(slave)
    return summarize(values)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--script', type=Path, default=Path(__file__).resolve().parent.parent / 'pc-command-center.sh')
    parser.add_argument('--samples', type=int, choices=range(1, 101), default=7)
    args = parser.parse_args()
    script = args.script.resolve(strict=True)
    measurements = measure_functions(script, args.samples)
    measurements['terminal_key_to_frame'] = measure_terminal(script, args.samples)
    print(json.dumps(measurements, indent=2))
