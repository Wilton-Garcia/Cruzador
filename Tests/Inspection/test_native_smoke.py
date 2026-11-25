import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('runtime_smoke_report', ROOT/'scripts/runtime_smoke_report.py')
reports = importlib.util.module_from_spec(spec); spec.loader.exec_module(reports)

def complete_report():
    probe = {'exit': 0, 'global_and_local_options_observed': True, 'working_directory_observed': True}
    workflows = {name: dict(probe) for name in ['original_probe', 'copied_probe', 'imported_probe']}
    workflows.update({name: str(uuid4()) for name in ['original_id', 'duplicate_id', 'imported_id']})
    workflows.update(import_preparation_exit=0, final_server_wait_exit=0, removed_reference_rejected=True,
                     original_reference_resolved_after_transfers=True, diagnostics_source_preserved=True,
                     diagnostics_log_hashes_verified=True, imported_7zip_exit=0)
    return {'formatVersion': 2, 'root': '/fixture/smoke', 'runtime': '/fixture/runtime', 'library_workflows': workflows,
            'windows_commands': [{'pe_machine': machine, 'exit_code': 0, 'marker_observed': True, 'explicit_environment_observed': True} for machine in ['0x8664', '0x14c']],
            'initialization_exit': 0, 'repair_exit': 0, 'nonzero_exit': 7, 'after_cancellation_exit': 0, 'server_wait_exit': 0,
            'cancelled': True, 'cancellation_cleanup_codes': [0, 0], 'invalid_msi_status': 'unconfirmed', 'invalid_msi_macOS_exit': 83}

class RuntimeReportTests(unittest.TestCase):
    def test_complete_report_control_and_incomplete_or_false_facts(self):
        valid = complete_report(); reports.validate_runtime_report(valid, require_imported_7zip=True)
        with self.assertRaises(ValueError): reports.validate_runtime_report(valid, expected_runtime=Path('/other/runtime'))
        for candidate in [None, {}, {'formatVersion': 1}, {key: value for key, value in valid.items() if key != 'library_workflows'}]:
            with self.assertRaises(ValueError): reports.validate_runtime_report(candidate)
        mutations = [('original_probe', 'exit', False), ('copied_probe', 'working_directory_observed', False), ('imported_probe', 'global_and_local_options_observed', None)]
        for probe, field, value in mutations:
            invalid = copy.deepcopy(valid); invalid['library_workflows'][probe][field] = value
            with self.assertRaises(ValueError): reports.validate_runtime_report(invalid)
        invalid = copy.deepcopy(valid); invalid['library_workflows']['imported_id'] = invalid['library_workflows']['original_id'].lower()
        with self.assertRaises(ValueError): reports.validate_runtime_report(invalid)
        invalid = copy.deepcopy(valid); invalid['library_workflows'].pop('imported_7zip_exit')
        reports.validate_runtime_report(invalid)
        with self.assertRaises(ValueError): reports.validate_runtime_report(invalid, require_imported_7zip=True)

    def test_requested_retina_requires_all_saved_registry_modes(self):
        report = complete_report()
        with self.assertRaises(ValueError): reports.validate_runtime_report(report, require_retina=True)
        report['retina_modes_observed'] = ['enabled', 'disabled', 'automatic']
        reports.validate_runtime_report(report, require_retina=True)
        report['retina_modes_observed'] = ['enabled', 'automatic']
        with self.assertRaises(ValueError): reports.validate_runtime_report(report, require_retina=True)

    def test_requested_reboot_requires_run_once_observation(self):
        report = complete_report()
        with self.assertRaises(ValueError): reports.validate_runtime_report(report, require_reboot=True)
        report.update(reboot_exit=0, reboot_run_once_observed=True)
        reports.validate_runtime_report(report, require_reboot=True)
        report['reboot_run_once_observed'] = False
        with self.assertRaises(ValueError): reports.validate_runtime_report(report, require_reboot=True)

    def test_additional_apps_require_real_cases_and_sqlite_integrity(self):
        report = complete_report()
        with self.assertRaises(ValueError): reports.validate_runtime_report(report, require_additional_apps=True)
        report['additional_apps'] = [{'id': app, 'case': case, 'exit': 0, 'cancelled': False, 'marker_observed': True, 'pe_machine': '0x14c' if app == 'plink-w32' else '0x8664', 'integrity_ok': case == 'read'} for app, case in [('plink-w32', 'version'), ('plink-w64', 'version'), ('sqlite-tools-x64', 'write'), ('sqlite-tools-x64', 'read')]]
        reports.validate_runtime_report(report, require_additional_apps=True)
        for mutate in [lambda data: data['additional_apps'].pop(), lambda data: data['additional_apps'][-1].update(integrity_ok=False), lambda data: data['additional_apps'][0].update(pe_machine='0x8664'), lambda data: data['additional_apps'][1].update(exit=False)]:
            invalid = copy.deepcopy(report); mutate(invalid)
            with self.assertRaises(ValueError): reports.validate_runtime_report(invalid, require_additional_apps=True)

    def test_msync_requires_startup_cancellation_and_recovery(self):
        valid = {'formatVersion': 2, 'root': '/fixture/smoke', 'runtime': '/fixture/runtime', 'initialization_exit': 0, 'server_wait_exit': 0,
                 'observations': [{'mode': mode, 'exit': 0, 'cancelled': False, 'marker': marker, 'log': ('msync: up and running.\n' if mode == 'msync' else '') + marker} for mode, marker in [('msync', 'CRUZADOR_SYNC_1_GLOBAL_OK'), ('server', 'CRUZADOR_SYNC_0_GLOBAL_OK')]],
                 'cancellation': {'cancelled': True, 'cleanup_codes': [0, 0], 'after_cancel_exit': 0, 'after_cancel_marker': True}}
        reports.validate_msync_report(valid)
        for mutate in [lambda data: data['observations'][0].update(log='missing startup'), lambda data: data['cancellation'].update(cleanup_codes=[9, 0]), lambda data: data['cancellation'].update(after_cancel_marker=False)]:
            invalid = copy.deepcopy(valid); mutate(invalid)
            with self.assertRaises(ValueError): reports.validate_msync_report(invalid)

class NativeSupervisorTests(unittest.TestCase):
    def run_supervisor(self, report, *, exit_code=0, delay=False, legacy=False, custom_server=False):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        root = Path(temporary.name); fake_bin = root/'bin'; fake_bin.mkdir()
        output = root/'output with spaces'; output.mkdir()
        previous = b'{"previous":"retained evidence"}\n'
        (output/'packaged-runtime-smoke.json').write_bytes(previous)
        runtime = root/'Runtime'; (runtime/'bin').mkdir(parents=True)
        prefix_id = str(uuid4())
        swift = fake_bin/'swift'
        report_name = 'original-runtime-smoke.json' if legacy else 'runtime-smoke.json'
        root_key = 'CRUZADOR_NATIVE_SMOKE_ROOT' if legacy else 'CRUZADOR_PACKAGED_SMOKE_ROOT'
        runtime_line = '' if legacy else ('payload["runtime"] = os.environ["CRUZADOR_PACKAGED_RUNTIME"]\n'
                     '(root/"runtime-control.json").write_text(json.dumps({"formatVersion":1,"runtime":payload["runtime"],"server":str(Path(os.environ["CRUZADOR_TEST_SERVER_EXECUTABLE"]).resolve())}))\n')
        program = ('#!/usr/bin/env python3\nimport os,json,sys,time\nfrom pathlib import Path\n'
                   'root = Path(os.environ['+repr(root_key)+'])\n'
                   '(root/"Bottles"/'+repr(prefix_id)+').mkdir(parents=True)\n'
                   'payload = json.loads('+repr(json.dumps(report))+')\n'
                   'payload["root"] = str(root)\n'+runtime_line+
                   '(root/'+repr(report_name)+').write_text(json.dumps(payload))\n'+
                   ('time.sleep(30)\n' if delay else '')+'sys.exit('+str(exit_code)+')\n')
        swift.write_text(program)
        swift.chmod(0o755)
        server = runtime/('helpers/custom-server' if custom_server else 'bin/wineserver')
        server.parent.mkdir(parents=True, exist_ok=True)
        server.write_text('#!/bin/sh\nprintf \'%s|%s\\n\' "$WINEPREFIX" "$1" >> "$CRUZADOR_TEST_SERVER_LOG"\n')
        server.chmod(0o755)
        server_log = root/'server.log'
        env = dict(os.environ, PATH=str(fake_bin)+os.pathsep+os.environ['PATH'], CRUZADOR_TEST_SERVER_LOG=str(server_log), CRUZADOR_TEST_SERVER_EXECUTABLE=str(server))
        command = [sys.executable, str(ROOT/'scripts/native-smoke.py'), '--output-root', str(output), '--timeout', '1' if delay else '5']
        if not legacy: command += ['--runtime', str(runtime)]
        result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=10)
        supervision = json.loads(next(output.glob('smoke-*.supervision.json')).read_text())
        backups = list(output.glob('packaged-runtime-smoke.previous-*.json'))
        if legacy:
            self.assertEqual(backups, []); self.assertEqual((output/'packaged-runtime-smoke.json').read_bytes(), previous)
        else:
            self.assertEqual(len(backups), 1); self.assertEqual(backups[0].read_bytes(), previous)
        return root, output, server_log, result, supervision, prefix_id

    def test_stale_or_incomplete_report_does_not_publish_success_and_cleans_only_own_prefix(self):
        for custom in [False, True]:
            root, output, server_log, result, supervision, prefix_id = self.run_supervisor({'old': 'report'}, custom_server=custom)
            self.assertEqual(result.returncode, 1); self.assertEqual(supervision['test_exit'], 0)
            self.assertEqual(supervision['result'], 1); self.assertIsNotNone(supervision['report_error'])
            self.assertFalse((output/'packaged-runtime-smoke.json').exists())
            lines = server_log.read_text().splitlines()
            self.assertEqual(len(lines), 2)
            for line, argument in zip(lines, ['-k', '-w']):
                prefix, actual_argument = line.split('|')
                self.assertTrue(Path(prefix).resolve().is_relative_to(output.resolve()))
                self.assertEqual(Path(prefix).name, prefix_id); self.assertEqual(actual_argument, argument)

    def test_complete_report_control_publishes_current_summary(self):
        root, output, server_log, result, supervision, prefix_id = self.run_supervisor(dict(complete_report(), reboot_exit=0, reboot_run_once_observed=True, retina_modes_observed=["enabled", "disabled", "automatic"]))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(supervision['result'], 0); self.assertFalse(supervision['timed_out'])
        self.assertIsNone(supervision['report_error']); self.assertFalse(server_log.exists())
        reports.validate_runtime_report(json.loads((output/'packaged-runtime-smoke.json').read_text()))

    def test_original_runtime_also_requires_an_observed_report(self):
        root, output, server_log, result, supervision, prefix_id = self.run_supervisor({}, legacy=True)
        self.assertEqual(result.returncode, 1); self.assertEqual(supervision['test_exit'], 0)
        self.assertEqual(supervision['cleanup_status'], 'unavailable-for-legacy')
        self.assertIsNotNone(supervision['report_error']); self.assertFalse(server_log.exists())
        valid = {'formatVersion': 1, 'root': '/fixture/smoke', 'engine_kind': 'crossOver', 'bottle_id': str(uuid4()),
                 'initialization_exit': 0, 'command_exit': 0, 'server_wait_exit': 0,
                 'initialization_cancelled': False, 'command_cancelled': False, 'server_wait_cancelled': False,
                 'marker_observed': True, 'prefix_initialized': True}
        root, output, server_log, result, supervision, prefix_id = self.run_supervisor(valid, legacy=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_timeout_and_nonzero_exit_keep_distinct_outcomes_and_attempt_cleanup(self):
        for delay, exit_code in [(False, 1), (True, 0)]:
            root, output, server_log, result, supervision, prefix_id = self.run_supervisor(complete_report(), exit_code=exit_code, delay=delay)
            self.assertEqual(result.returncode, 124 if delay else 1)
            self.assertEqual(supervision['timed_out'], delay)
            self.assertEqual(supervision['test_exit'], -15 if delay else 1)
            self.assertFalse((output/'packaged-runtime-smoke.json').exists())
            self.assertEqual(len(supervision['cleanup']), 2)
            self.assertEqual([entry['exit_code'] for entry in supervision['cleanup']], [0, 0])

if __name__ == '__main__': unittest.main()
