#!/usr/bin/env python3
"""Execute the opt-in native test with a bounded, owned process group."""
import argparse
import os
import json
import time
import math
from pathlib import Path
import signal
import subprocess
import sys
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, help='Select a prepared Wine package instead of the original CrossOver')
parser.add_argument('--installer-msi', type=Path, help='Optional pinned 7-Zip MSI for positive installation validation')
parser.add_argument('--recipes', type=Path, help='Optional own recipe catalog for end-to-end 7-Zip recipe validation')
parser.add_argument('--timeout', type=float, default=120, help='Overall test deadline in seconds (default: 120); timeout retains logs and cleans the isolated Wine server')
parser.add_argument('--msync', action='store_true', help='Test the optional MSync runtime and switching back to server synchronization')
args = parser.parse_args()
if args.msync and not args.runtime: parser.error('--msync requires --runtime')
if not math.isfinite(args.timeout) or args.timeout <= 0: parser.error('--timeout must be positive')
project = Path(__file__).resolve().parent.parent
root = project / '.local' / ('smoke-' + str(uuid.uuid4()))
root.parent.mkdir(exist_ok=True)
if args.runtime:
    environment = dict(os.environ, CRUZADOR_PACKAGED_RUNTIME=str(args.runtime.resolve()), CRUZADOR_PACKAGED_SMOKE_ROOT=str(root))
    selection = 'PackagedNativeSmokeTests'
    if args.msync:
        environment.update(CRUZADOR_MSYNC_RUNTIME=str(args.runtime.resolve()), CRUZADOR_MSYNC_ROOT=str(root))
        selection = 'SynchronizationTests.testRealMSyncRuntimeAndServerMode'
else:
    environment = dict(os.environ, CRUZADOR_NATIVE_SMOKE_ROOT=str(root))
    selection = 'NativeSmokeTests.testInstalledCrossOverCreatesBottleAndRunsWindowsCommand'
if args.installer_msi:
    environment['CRUZADOR_TEST_MSI'] = str(args.installer_msi.resolve())
if args.recipes:
    environment['CRUZADOR_TEST_RECIPES'] = str(args.recipes.resolve())
log = root.parent / (root.name + '.test.log')
started = time.monotonic()
cleanup = []
with log.open('w') as output:
    child = subprocess.Popen(['swift', 'test', '--skip-build', '--filter', selection], cwd=project, env=environment, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        result = child.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        result = 124
        if args.runtime:
            server = args.runtime.resolve() / 'bin/wineserver'
            for prefix in (root / 'Bottles').glob('*'):
                try: uuid.UUID(prefix.name)
                except ValueError: continue
                if prefix.is_symlink() or not prefix.is_dir(): continue
                selected_environment = {key: value for key, value in os.environ.items() if not key.startswith(('WINE', 'CX_'))}
                selected_environment.update(WINEPREFIX=str(prefix), WINESERVER=str(server))
                for arguments in [['-k'], ['-w']]:
                    try:
                        stopped = subprocess.run([str(server)] + arguments, env=selected_environment, capture_output=True, text=True, timeout=10)
                        cleanup.append({'prefix': str(prefix), 'arguments': arguments, 'exit_code': stopped.returncode, 'stderr': stopped.stderr})
                    except (OSError, subprocess.TimeoutExpired) as error:
                        cleanup.append({'prefix': str(prefix), 'arguments': arguments, 'error': str(error)})
supervision = {'timeout_seconds': args.timeout, 'elapsed_seconds': time.monotonic() - started, 'result': result, 'timeout_cleanup': cleanup, 'limitations': ['CPU time and peak process-family memory were not measured.']}
(root.parent / (root.name + '.supervision.json')).write_text(json.dumps(supervision, indent=2) + '\n')
print(json.dumps(supervision))
phases = root / 'phases.jsonl'
if phases.exists(): print(phases.read_text())
print(log.read_text()[-12000:])
print('Retained test root:', root)
print('Test output:', log)
if result == 124:
    print('Timeout: inspect retained logs and the isolated prefix before retrying.')

if args.runtime and not args.msync and result == 0:
    import struct
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
