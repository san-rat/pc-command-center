"""Linux PTY integration checks; development-only standard-library Python."""
import csv
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parent.parent


def exercise(record, scheduled=False):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 110, 0, 0))
    original = termios.tcgetattr(slave)
    args = ['bash', str(ROOT / 'pc-command-center.sh'), '--wide', '--no-color',
            '--interval', '1' if scheduled else '999999', '--record', str(record)]
    proc = subprocess.Popen(args, stdin=slave, stdout=slave, stderr=slave,
                            env={**os.environ, 'TERM': 'xterm', 'XDG_CONFIG_HOME': str(record.parent / 'config')},
                            start_new_session=True,
                            preexec_fn=lambda: fcntl.ioctl(0, termios.TIOCSCTTY, 0))
    transcript = bytearray()

    def receive(seconds):
        data = bytearray()
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if select.select([master], [], [], min(.05, max(0, end-time.monotonic())))[0]:
                try:
                    data.extend(os.read(master, 65536))
                except OSError:
                    break
        transcript.extend(data)
        return bytes(data)

    def frame(marker=b''):
        data = bytearray()
        deadline = time.monotonic() + 10
        while b'\x1b[J' not in data and time.monotonic() < deadline:
            data.extend(receive(.05))
        assert b'\x1b[J' in data, ('frame timeout', bytes(data[-1000:]))
        assert marker in data, (marker, bytes(data[-2000:]))
        assert b'syntax error' not in data and b'integer expression' not in data, data
        return bytes(data)

    def rows():
        with record.open(newline='') as stream:
            return list(csv.DictReader(stream))

    try:
        frame(b'PC COMMAND CENTER')
        assert len(rows()) == 1
        if scheduled:
            frame(b'History:')
            assert len(rows()) >= 2
            proc.send_signal(signal.SIGTERM)
        else:
            # Repainting, sorting, selection, and filter input do not record samples.
            for key, marker in [(b'2', b'PCC PROCESSES'), (b'm', b'sort mem'),
                                (b'j', b'Processes:'), (b'\r', b'Threads'),
                                (b'a', b'Args:'), (b'\x1b', b'Processes:')]:
                os.write(master, key)
                frame(marker)
            os.write(master, b'/'); frame(b'Filter>')
            os.write(master, b'q'); frame(b'Filter> q')
            assert proc.poll() is None
            os.write(master, b'\x1b'); frame(b'Filter: all')
            for key, marker in [(b'3', b'PCC STORAGE'), (b'4', b'PCC NETWORK'),
                                (b'5', b'PCC PRESSURE'), (b'e', b'Events:'),
                                (b'e', b'PCC PRESSURE'), (b'1', b'PC COMMAND CENTER')]:
                os.write(master, key); frame(marker)
            assert len(rows()) == 1
            os.write(master, b'p'); frame(b'PAUSED')
            os.write(master, b'?'); frame(b'HELP')
            os.write(master, b'x'); frame(b'PAUSED')
            assert len(rows()) == 1
            os.write(master, b'r'); frame(b'History:')
            assert len(rows()) == 2
            os.write(master, b'p'); frame(b'History:')
            assert len(rows()) == 3
            # Automatic responsive overview, then all focused views in tiny terminals.
            for width, height in [(80, 24), (50, 14), (40, 9), (30, 5), (1, 1), (110, 30)]:
                fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', height, width, 0, 0))
                frame()
            assert len(rows()) == 3
            os.write(master, b'q')
        proc.wait(timeout=10)
        ending = receive(.1)
        assert proc.returncode == 0, proc.returncode
        assert termios.tcgetattr(slave) == original, 'terminal attributes not restored'
        assert b'\x1b[?1049l' in ending and b'\x1b[?25h' in ending, ending
        values = rows()
        assert [int(r['sample_sequence']) for r in values] == list(range(1, len(values)+1))
        assert all(r['schema_version'] == '1' for r in values)
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        (record.parent / (record.stem + '.terminal')).write_bytes(transcript)
        os.close(master)
        os.close(slave)


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='pcc-pty-') as directory:
        exercise(Path(directory) / 'interaction.csv')
        exercise(Path(directory) / 'scheduled.csv', scheduled=True)
    print('PASS: PTY navigation, filtering, resize, sampling/recording, pause/help, q/SIGTERM cleanup')
