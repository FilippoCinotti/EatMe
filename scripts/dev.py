"""Start the local API and processing worker with explicit development settings."""
import os
import signal
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
environment = {**os.environ, 'PYTHONPATH': str(root / 'services/api'), 'EATME_ENV': 'development', 'AUTH_MODE': 'development'}
environment.setdefault('DATABASE_URL', str(root / 'var/eatme-dev.sqlite3'))
(root / 'var').mkdir(exist_ok=True)
processes = [subprocess.Popen([sys.executable, '-m', 'eatme.local_server'], cwd=root, env=environment), subprocess.Popen([sys.executable, str(root / 'services/worker/main.py')], cwd=root, env=environment)]
try:
    for process in processes:
        process.wait()
except KeyboardInterrupt:
    for process in processes:
        process.send_signal(signal.SIGTERM)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
