#!/usr/bin/env python3
"""Execute the opt-in native test with a bounded, owned process group."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import sys
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, help='Select a prepared Wine package instead of the original CrossOver')
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
root = project / '.local' / ('smoke-' + str(uuid.uuid4()))
root.parent.mkdir(exist_ok=True)
if args.runtime:
    environment = dict(os.environ, CRUZADOR_PACKAGED_RUNTIME=str(args.runtime.resolve()), CRUZADOR_PACKAGED_SMOKE_ROOT=str(root))
    selection = 'PackagedNativeSmokeTests'
else:
    environment = dict(os.environ, CRUZADOR_NATIVE_SMOKE_ROOT=str(root))
    selection = 'NativeSmokeTests.testInstalledCrossOverCreatesBottleAndRunsWindowsCommand'
log = root.parent / (root.name + '.test.log')
with log.open('w') as output:
    child = subprocess.Popen(['swift', 'test', '--skip-build', '--filter', selection], cwd=project, env=environment, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
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

if args.runtime and result == 0:
    import json, struct
    report_path = root / 'runtime-smoke.json'
    report = json.loads(report_path.read_text())
    for command in report['windows_commands']:
        data = Path(command['executable']).read_bytes()
        assert data[:2] == b'MZ'
        offset = struct.unpack_from('<I', data, 0x3c)[0]
        assert data[offset:offset+4] == b'PE\0\0'
        command['pe_machine'] = hex(struct.unpack_from('<H', data, offset+4)[0])
    assert [c['pe_machine'] for c in report['windows_commands']] == ['0x8664', '0x14c']
    output = project / '.local/packaged-runtime-smoke.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print('Packaged runtime report:', output)

sys.exit(result)
