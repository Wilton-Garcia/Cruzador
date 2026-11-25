#!/usr/bin/env python3
"""Observe a new private original bottle and compare with retained independent observations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import uuid
from runtime_smoke_report import validate_runtime_report

ROOT = Path(__file__).resolve().parent.parent
BASELINE = '1d245f2f9f52bd56a120616fede8b1eb9cca9fa228319de04a2cbeabd8de7174'

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): digest.update(block)
    return digest.hexdigest()

def observe(app, independent_path, msi):
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    name = info['CFBundleExecutable']
    if not isinstance(name, str) or Path(name).name != name: raise ValueError('Invalid original executable name')
    executable = app/'Contents/MacOS'/name
    digest = sha(executable)
    if digest != BASELINE: raise ValueError('Original target changed; inspect its identity before comparing against the recovered baseline')
    independent = json.loads(independent_path.read_text()); validate_runtime_report(independent, require_imported_7zip=True)
    msi_sha = sha(msi)
    if msi_sha != '6dc822569e777d9a3ecd5ffcbc22b55600af87e6c5d9810a64e8566cf5a4af9f': raise ValueError('Select the pinned 7-Zip 26.06 x64 MSI')
    workspace = ROOT/'.local'/('original-comparison-'+str(uuid.uuid4()))
    bottles = workspace/'Bottles'; bottles.mkdir(parents=True); logs = workspace/'Logs'; logs.mkdir()
    bottle_id = str(uuid.uuid4()); prefix = bottles/bottle_id
    selected = {'CX_BOTTLE_PATH': str(bottles), 'CX_BOTTLE': bottle_id, 'WINEPREFIX': str(prefix), 'CRUZADOR_LAUNCH_VALUE': 'OWN_ENV_OK'}
    environment = {key: value for key, value in os.environ.items() if not key.startswith(('CX_', 'WINE'))}; environment.update(selected)
    base = app/'Contents/SharedSupport/CrossOver/bin'
    common = ['--bottle', bottle_id, '--scope', 'private']
    wine = common + ['--no-gui', '--wait', '--']
    runs = []
    report = {'formatVersion': 1, 'workspace': str(workspace), 'prefix': str(prefix), 'original_version': info.get('CFBundleShortVersionString'),
              'original_executable': str(executable), 'original_sha256': digest, 'independent_report_path': str(independent_path),
              'independent_report_sha256': sha(independent_path), 'msi_path': str(msi), 'msi_sha256': msi_sha, 'runs': runs,
              'completed': False, 'limitations': ['Independent results are retained observations from a separate execution, not simultaneous live state.',
              'Comparison covers selected engine-level behavior, not full UI, game compatibility, performance or product equivalence.',
              'Only explicit environment overrides are retained; ambient environment is not recorded.',
              'Text tails are UTF-8 projections with replacement; raw logs and byte digests are retained.',
              'No process-family census was performed; waiting for the selected server does not prove every detached helper exited.']}
    def run(case, tool, args, cwd=None):
        log = logs/(case+'.log'); target = base/tool
        with log.open('wb') as output:
            child = subprocess.Popen([str(target)]+args, cwd=cwd or workspace, env=environment, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            try: code = child.wait(timeout=90); timed_out = False
            except subprocess.TimeoutExpired:
                timed_out = True; os.killpg(child.pid, signal.SIGTERM)
                try: code = child.wait(timeout=5)
                except subprocess.TimeoutExpired: os.killpg(child.pid, signal.SIGKILL); code = child.wait()
        text = log.read_text(errors='replace')
        item = {'id': case, 'executable': str(target), 'executable_sha256': sha(target), 'arguments': args, 'selected_environment': selected,
                'working_directory': str(cwd or workspace), 'exit_code': code, 'timed_out': timed_out, 'log_path': str(log),
                'log_sha256': sha(log), 'output_tail': text[-6000:]}
        runs.append(item); print(case, code, flush=True)
        if timed_out: raise TimeoutError(f'{case} timed out; inspect {workspace}')
        return item, text
    try:
        created, _ = run('initialize', 'cxbottle', common+['--create','--template','win10_64'])
        if created['exit_code'] != 0 or not (prefix/'system.reg').is_file(): raise RuntimeError('Original preparation was not confirmed')
        for folder, marker in [('system32','CRUZADOR_WIN64_OK'), ('syswow64','CRUZADOR_WIN32_OK')]:
            command = prefix/'drive_c/windows'/folder/'cmd.exe'
            item, text = run(folder, 'wine', wine+[str(command), '/c', 'echo', marker, '%CRUZADOR_LAUNCH_VALUE%'], prefix/'drive_c')
            item['marker_observed'] = marker in text; item['explicit_environment_observed'] = 'OWN_ENV_OK' in text
        run('windows-version', 'wine', wine+['cmd.exe','/c','ver'])
        run('nonzero-exit', 'wine', wine+['cmd.exe','/c','exit','7'])
        missing, _ = run('missing-program', 'wine', wine+['C:\\cruzador-no-such-program.exe']); missing['failure_observed'] = missing['exit_code'] != 0
        installed, _ = run('positive-msi', 'wine', wine+['msiexec','/i',str(msi),'/norestart','/L*V',str(logs/'7zip.msi.log'),'/qn'], msi.parent)
        if installed['exit_code'] == 0:
            launched, text = run('installed-7zip', 'wine', wine+[str(prefix/'drive_c/Program Files/7-Zip/7z.exe')])
            launched['7zip_marker_observed'] = '7-Zip' in text
        invalid = workspace/'invalid-package.msi'; invalid.write_bytes(bytes.fromhex('d0cf11e0a1b11ae1'))
        bad, _ = run('invalid-msi', 'wine', wine+['msiexec','/i',str(invalid),'/norestart','/L*V',str(logs/'invalid.msi.log'),'/qn'])
        bad['failure_observed'] = bad['exit_code'] != 0
        recovery, text = run('after-errors', 'wine', wine+['cmd.exe','/c','echo','CRUZADOR_RECOVERED_OK']); recovery['marker_observed'] = 'CRUZADOR_RECOVERED_OK' in text
        report['completed'] = True
    finally:
        try:
            stopped, _ = run('server-wait', 'wine', common+['--no-gui','--wait-all'])
            report['server_wait_confirmed'] = stopped['exit_code'] == 0
        except Exception as error:
            report['server_wait_confirmed'] = False; report['cleanup_error'] = str(error)
        report['completed'] = report['completed'] and report['server_wait_confirmed']
        (workspace/'original-observations.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
        print('Retained comparison:', workspace, flush=True)
    if not report['completed'] or not report['server_wait_confirmed']: raise RuntimeError('Comparison incomplete; retained data requires diagnosis')
    return report, independent

def assess(row):
    if type(row.get('independent_exit')) is not int or type(row.get('original_exit')) is not int:
        return 'observation unavailable'
    if row['scenario'] == 'invalid-msi':
        return 'same observed failure class' if row['original_exit'] != 0 and row['independent_exit'] != 0 else 'different observed outcome'
    if row['original_exit'] != row['independent_exit']: return 'different observed status'
    markers = ['original_marker_and_environment', 'independent_marker_and_environment']
    if any(key in row for key in markers) and not all(row.get(key) is True for key in markers):
        return 'marker or environment observation differs or is incomplete'
    return 'matching selected observations'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--original', type=Path, default=Path('/Applications/CrossOver.app'))
    parser.add_argument('--independent-report', type=Path, default=ROOT/'.local/packaged-runtime-smoke.json')
    parser.add_argument('--msi', type=Path, default=ROOT/'.local/downloads/7z2606-x64.msi'); args = parser.parse_args()
    original, independent = observe(args.original.resolve(), args.independent_report.resolve(), args.msi.resolve())
    lookup = {item['id']: item for item in original['runs']}
    rows = []
    commands_by_machine = {command['pe_machine']: command for command in independent['windows_commands']}
    for folder, machine in [('system32', '0x8664'), ('syswow64', '0x14c')]:
        command = commands_by_machine[machine]
        other = lookup[folder]
        rows.append({'scenario': folder, 'original_exit': other['exit_code'], 'independent_exit': command['exit_code'],
                     'original_marker_and_environment': other['marker_observed'] and other['explicit_environment_observed'],
                     'independent_marker_and_environment': command['marker_observed'] and command['explicit_environment_observed']})
    rows += [{'scenario':'nonzero-exit','original_exit':lookup['nonzero-exit']['exit_code'],'independent_exit':independent['nonzero_exit']},
             {'scenario':'positive-msi','original_exit':lookup['positive-msi']['exit_code'],'independent_exit':independent.get('positive_7zip_msi_exit')},
             {'scenario':'invalid-msi','original_exit':lookup['invalid-msi']['exit_code'],'independent_exit':independent['invalid_msi_macOS_exit'], 'comparison':'Both are nonzero; Unix status does not identify the complete Windows MSI code.'},
             {'scenario':'server-wait','original_exit':lookup['server-wait']['exit_code'],'independent_exit':independent['server_wait_exit']}]
    original['comparison'] = rows
    for row in rows:
        row['assessment'] = assess(row)
    original['original_command_images'] = []
    for folder in ['system32', 'syswow64']:
        path = Path(original['prefix'])/'drive_c/windows'/folder/'cmd.exe'
        original['original_command_images'].append({'folder': folder, 'path': str(path), 'sha256': sha(path), 'file_description': subprocess.check_output(['/usr/bin/file', '-b', str(path)], text=True).strip()})
    original['deliberate_differences'] = ['Own UUID-backed library and launcher/transfer formats; original metadata formats are not claimed compatible.',
       'Own launch requests validate a selected local file before execution; an absent Windows program is not silently represented as a valid local executable.',
       'Changing synchronization requires a successful non-cancelled server wait; the recovered original callback alone is not considered shutdown success.']
    output = Path(original['workspace'])/'comparison.json'; output.write_text(json.dumps(original, ensure_ascii=False, indent=2)+'\n')
    print('Comparison report:', output)
