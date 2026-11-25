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
from runtime_smoke_report import validate_runtime_report, validate_msync_report, validate_legacy_report

def cleanup_prefixes(runtime, root):
    cleanup = []
    control_path = root / 'runtime-control.json'
    try:
        control = json.loads(control_path.read_text())
        if not isinstance(control, dict) or control.get('formatVersion') != 1: raise ValueError('Unsupported runtime control metadata')
        selected = Path(control['runtime'])
        server = Path(control['server'])
        if not selected.is_absolute() or selected.resolve() != runtime or not server.is_absolute() or not server.resolve().is_relative_to(selected.resolve()):
            raise ValueError('Runtime control identity could not be confirmed')
        server = server.resolve()
        if not server.is_file() or not os.access(server, os.X_OK): raise ValueError('Selected runtime server is unavailable')
    except (OSError, ValueError, TypeError, KeyError) as error:
        return [{'control_metadata': str(control_path), 'error': str(error)}]
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
    return cleanup

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, help='Select a prepared Wine package instead of the original CrossOver')
parser.add_argument('--installer-msi', type=Path, help='Optional pinned 7-Zip MSI for positive installation validation')
parser.add_argument('--recipes', type=Path, help='Optional own recipe catalog for end-to-end 7-Zip recipe validation')
parser.add_argument('--timeout', type=float, default=120, help='Overall test deadline in seconds (default: 120); timeout retains logs and cleans the isolated Wine server')
parser.add_argument('--msync', action='store_true', help='Test the optional MSync runtime and switching back to server synchronization')
parser.add_argument('--output-root', type=Path, help='Retain reports and fresh test roots here (default: project .local)')
args = parser.parse_args()
if args.msync and not args.runtime: parser.error('--msync requires --runtime')
if not math.isfinite(args.timeout) or args.timeout <= 0: parser.error('--timeout must be positive')
project = Path(__file__).resolve().parent.parent
runtime_path = args.runtime.resolve() if args.runtime else None
output_root = args.output_root.resolve() if args.output_root else project / '.local'
root = output_root / ('smoke-' + str(uuid.uuid4()))
root.parent.mkdir(parents=True, exist_ok=True)
summary = output_root / 'packaged-runtime-smoke.json'
previous_summary = None
if args.runtime and not args.msync and summary.exists():
    if not summary.is_file(): raise ValueError(f'Existing summary is not a regular file: {summary}')
    previous_summary = summary.with_name('packaged-runtime-smoke.previous-' + root.name + '.json')
    summary.rename(previous_summary)
if args.runtime:
    environment = dict(os.environ, CRUZADOR_PACKAGED_RUNTIME=str(runtime_path), CRUZADOR_PACKAGED_SMOKE_ROOT=str(root))
    selection = 'PackagedNativeSmokeTests'
    if args.msync:
        environment.update(CRUZADOR_MSYNC_RUNTIME=str(runtime_path), CRUZADOR_MSYNC_ROOT=str(root))
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
timed_out = False
with log.open('w') as output:
    child = subprocess.Popen(['swift', 'test', '--skip-build', '--filter', selection], cwd=project, env=environment, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        result = child.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()
        result = 124
test_exit = child.returncode
if result != 0 and args.runtime: cleanup = cleanup_prefixes(runtime_path, root)
report_error = None
phases = root / 'phases.jsonl'
if phases.exists(): print(phases.read_text())
print(log.read_text()[-12000:])
print('Retained test root:', root)
print('Test output:', log)
if timed_out:
    print('Timeout: inspect retained logs and the isolated prefix before retrying.')

if args.runtime and not args.msync and result == 0:
    try:
        report_path = root / 'runtime-smoke.json'
        report = json.loads(report_path.read_text())
        validate_runtime_report(report, require_imported_7zip=bool(args.recipes), expected_runtime=runtime_path, expected_root=root)
        output = summary
        output.write_text(json.dumps(report, indent=2) + '\n')
        print('Packaged runtime report:', output)
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
        report_error = str(error); result = 1
        cleanup = cleanup_prefixes(runtime_path, root)
        print('Runtime report validation failed:', report_error)

if args.msync and result == 0:
    try:
        report = json.loads((root / 'msync-observations.json').read_text())
        validate_msync_report(report, expected_runtime=runtime_path, expected_root=root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        report_error = str(error); result = 1
        cleanup = cleanup_prefixes(runtime_path, root)
        print('MSync report validation failed:', report_error)

if not args.runtime and result == 0:
    try:
        report = json.loads((root / 'original-runtime-smoke.json').read_text())
        validate_legacy_report(report, expected_root=root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        report_error = str(error); result = 1
        print('Original-runtime report validation failed:', report_error)

failure = result != 0
cleanup_status = 'not-requested'
if failure:
    if not args.runtime: cleanup_status = 'unavailable-for-legacy'
    elif not cleanup: cleanup_status = 'no-prefix-observed'
    else: cleanup_status = 'commands-confirmed' if all(entry.get('exit_code') == 0 and 'error' not in entry for entry in cleanup) else 'incomplete'

supervision = {'format_version': 2, 'timed_out': timed_out, 'timeout_seconds': args.timeout, 'elapsed_seconds': time.monotonic() - started,
               'result': result, 'test_exit': test_exit, 'cleanup_status': cleanup_status, 'cleanup': cleanup, 'report_error': report_error,
               'previous_summary': str(previous_summary) if previous_summary else None,
               'requested_output_root': str(args.output_root) if args.output_root else None,
               'output_root': str(output_root),
               'requested_runtime': str(args.runtime) if args.runtime else None,
               'runtime': str(runtime_path) if args.runtime else None,
               'requested_installer_msi': str(args.installer_msi) if args.installer_msi else None,
               'requested_recipes': str(args.recipes) if args.recipes else None,
               'limitations': ['CPU time and peak process-family memory were not measured.', 'Cleanup control commands concern only the selected retained prefixes; arbitrary detached helpers were not enumerated.']}
(root.parent / (root.name + '.supervision.json')).write_text(json.dumps(supervision, indent=2) + '\n')
print(json.dumps(supervision))

sys.exit(result)
