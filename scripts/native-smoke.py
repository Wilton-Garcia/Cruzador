#!/usr/bin/env python3
"""Execute the opt-in native test with a bounded, owned process group."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import uuid

project = Path(__file__).resolve().parent.parent
root = project / '.local' / ('smoke-' + str(uuid.uuid4()))
root.parent.mkdir(exist_ok=True)
environment = dict(os.environ, CRUZADOR_NATIVE_SMOKE_ROOT=str(root))
log = root.parent / (root.name + '.test.log')
with log.open('w') as output:
    child = subprocess.Popen(['swift', 'test', '--skip-build', '--filter', 'NativeSmokeTests'], cwd=project, env=environment, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        result = child.wait(timeout=120)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        result = 124
print(log.read_text()[-12000:])
print('Retained test root:', root)
print('Test output:', log)
if result == 124:
    print('Timeout: inspect retained logs and the isolated prefix before retrying.')
sys.exit(result)
