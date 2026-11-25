"""Own validation of the real-runtime report expected by the smoke supervisor."""
from uuid import UUID
from pathlib import Path

def _check_path(report, field, expected):
    actual = report.get(field)
    if not isinstance(actual, str) or not Path(actual).is_absolute(): raise ValueError(f'Missing absolute runtime report path: {field}')
    if expected is not None and Path(actual).resolve() != expected: raise ValueError(f'Runtime report belongs to another {field}')


def validate_runtime_report(report, *, require_imported_7zip=False, require_additional_apps=False, require_reboot=False, require_retina=False, expected_runtime=None, expected_root=None):
    def require(condition, field):
        if not condition:
            raise ValueError(f'Incomplete runtime workflow report: {field}. Rebuild the tests before running --skip-build.')
    require(isinstance(report, dict), 'report object')
    require(report.get('formatVersion') == 2, 'formatVersion=2')
    _check_path(report, 'root', expected_root); _check_path(report, 'runtime', expected_runtime)
    commands = report.get('windows_commands')
    require(isinstance(commands, list) and len(commands) == 2 and all(isinstance(item, dict) for item in commands), 'windows_commands')
    require(all(isinstance(item.get('pe_machine'), str) for item in commands), 'PE machine types')
    require({item.get('pe_machine') for item in commands} == {'0x8664', '0x14c'}, 'Windows PE architectures')
    for item in commands:
        require(type(item.get('exit_code')) is int and item['exit_code'] == 0, 'Windows command exit')
        require(item.get('marker_observed') is True and item.get('explicit_environment_observed') is True, 'Windows command observations')
    for field in ['initialization_exit', 'repair_exit', 'after_cancellation_exit', 'server_wait_exit']:
        require(type(report.get(field)) is int and report[field] == 0, field)
    require(type(report.get('nonzero_exit')) is int and report['nonzero_exit'] == 7, 'nonzero_exit')
    require(report.get('cancelled') is True, 'cancelled')
    codes = report.get('cancellation_cleanup_codes')
    require(isinstance(codes, list) and len(codes) == 2 and all(type(code) is int and code == 0 for code in codes), 'cancellation_cleanup_codes')
    require(report.get('invalid_msi_status') == 'unconfirmed', 'invalid_msi_status')
    require(type(report.get('invalid_msi_macOS_exit')) is int and report['invalid_msi_macOS_exit'] != 0, 'invalid_msi_macOS_exit')
    workflows = report.get('library_workflows')
    require(isinstance(workflows, dict), 'library_workflows')
    for name in ['original_probe', 'copied_probe', 'imported_probe']:
        probe = workflows.get(name)
        require(isinstance(probe, dict), name)
        require(type(probe.get('exit')) is int and probe['exit'] == 0, name + '.exit')
        for field in ['global_and_local_options_observed', 'working_directory_observed']:
            require(probe.get(field) is True, name + '.' + field)
    for field in ['import_preparation_exit', 'final_server_wait_exit']:
        require(type(workflows.get(field)) is int and workflows[field] == 0, field)
    for field in ['removed_reference_rejected', 'original_reference_resolved_after_transfers', 'diagnostics_source_preserved', 'diagnostics_log_hashes_verified']:
        require(workflows.get(field) is True, field)
    try:
        ids = [UUID(workflows[field]) for field in ['original_id', 'duplicate_id', 'imported_id']]
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        raise ValueError('Runtime workflow identities are missing or invalid') from error
    require(len(set(ids)) == 3, 'distinct bottle identities')
    if require_retina:
        require(report.get('retina_modes_observed') == ['enabled', 'disabled', 'automatic'], 'Retina registry modes')
    if require_reboot:
        require(type(report.get('reboot_exit')) is int and report['reboot_exit'] == 0 and report.get('reboot_run_once_observed') is True, 'reboot RunOnce observation')
    if require_additional_apps:
        apps = report.get('additional_apps')
        require(isinstance(apps, list) and len(apps) == 4 and all(isinstance(item, dict) for item in apps), 'additional_apps')
        require({(item.get('id'), item.get('case')) for item in apps} == {('plink-w32', 'version'), ('plink-w64', 'version'), ('sqlite-tools-x64', 'write'), ('sqlite-tools-x64', 'read')}, 'additional application cases')
        for item in apps:
            require(type(item.get('exit')) is int and item['exit'] == 0 and item.get('cancelled') is False and item.get('marker_observed') is True, 'additional application outcome')
            require(item.get('pe_machine') == ('0x14c' if item['id'] == 'plink-w32' else '0x8664'), 'additional application architecture')
            if item['case'] == 'read': require(item.get('integrity_ok') is True, 'SQLite integrity')
    if require_imported_7zip:
        require(type(workflows.get('imported_7zip_exit')) is int and workflows['imported_7zip_exit'] == 0, 'imported_7zip_exit')

def validate_msync_report(report, *, expected_runtime=None, expected_root=None):
    def require(condition, field):
        if not condition: raise ValueError(f'Incomplete MSync report: {field}. Rebuild the tests before running --skip-build.')
    require(isinstance(report, dict) and report.get('formatVersion') == 2, 'formatVersion=2')
    _check_path(report, 'root', expected_root); _check_path(report, 'runtime', expected_runtime)
    require(type(report.get('initialization_exit')) is int and report['initialization_exit'] == 0, 'initialization_exit')
    require(type(report.get('server_wait_exit')) is int and report['server_wait_exit'] == 0, 'server_wait_exit')
    observed = report.get('observations')
    require(isinstance(observed, list) and len(observed) == 2 and all(isinstance(item, dict) for item in observed), 'observations')
    require(all(isinstance(item.get('mode'), str) for item in observed), 'mode types')
    require({item.get('mode') for item in observed} == {'msync', 'server'}, 'modes')
    for item in observed:
        require(type(item.get('exit')) is int and item['exit'] == 0 and item.get('cancelled') is False, 'mode execution')
        expected = 'CRUZADOR_SYNC_' + ('1' if item['mode'] == 'msync' else '0') + '_GLOBAL_OK'
        require(item.get('marker') == expected and isinstance(item.get('log'), str) and expected in item['log'], 'mode marker')
        if item['mode'] == 'msync': require('msync: up and running.' in item['log'], 'MSync startup')
    cancelled = report.get('cancellation')
    require(isinstance(cancelled, dict) and cancelled.get('cancelled') is True, 'cancellation')
    codes = cancelled.get('cleanup_codes')
    require(isinstance(codes, list) and len(codes) == 2 and all(type(code) is int and code == 0 for code in codes), 'cleanup_codes')
    require(type(cancelled.get('after_cancel_exit')) is int and cancelled['after_cancel_exit'] == 0 and cancelled.get('after_cancel_marker') is True, 'recovery after cancellation')

def validate_legacy_report(report, *, expected_root=None):
    def require(condition, field):
        if not condition: raise ValueError(f'Incomplete original-runtime report: {field}. Rebuild the tests before running --skip-build.')
    require(isinstance(report, dict) and report.get('formatVersion') == 1 and report.get('engine_kind') == 'crossOver', 'identity and format')
    _check_path(report, 'root', expected_root)
    for field in ['initialization_exit', 'command_exit', 'server_wait_exit']:
        require(type(report.get(field)) is int and report[field] == 0, field)
    for field in ['initialization_cancelled', 'command_cancelled', 'server_wait_cancelled']:
        require(report.get(field) is False, field)
    require(report.get('marker_observed') is True and report.get('prefix_initialized') is True, 'observations')
    try: UUID(report['bottle_id'])
    except (ValueError, TypeError, KeyError, AttributeError) as error: raise ValueError('Missing original-runtime bottle identity') from error
