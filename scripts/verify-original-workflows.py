#!/usr/bin/env python3
"""Validate retained scenario outcomes without launching CrossOver."""
import json
from pathlib import Path

root=Path(__file__).resolve().parent.parent
report=json.loads((root/'evidence/runtime/original-workflows.json').read_text())
assert report['completed'] is True and report['server_wait']=='completed'
expected={'create':0,'duplicate-create-rejected':1,'status-after-create-conflict':0,'windows-command':0,'windows-nonzero-exit':7,'missing-program':1,'command-after-errors':0,'wait-owned-server':0}
assert {r['id'] for r in report['runs']}==set(expected)
for run in report['runs']:
    assert run['exit_code']==expected[run['id']],run['id']
    assert not run['timed_out'],run['id']
    assert run['selected_environment']['WINEPREFIX']==report['prefix']
    assert run['selected_environment']['CX_BOTTLE_PATH']==str(Path(report['prefix']).parent)
    assert set(run['selected_environment'])=={'CX_BOTTLE_PATH','CX_BOTTLE','WINEPREFIX'}
    assert len(run['log_sha256'])==64 and len(run['executable_sha256'])==64
assert 'CRUZADOR_ORIGINAL_OK' in next(r for r in report['runs'] if r['id']=='windows-command')['output']
assert 'CRUZADOR_RECOVERED_OK' in next(r for r in report['runs'] if r['id']=='command-after-errors')['output']
error=json.loads((root/'evidence/runtime/rea-pty-capture-failure.json').read_text())
assert error['details']['partial_observation']['observations']['target_pid']['state']=='unavailable'
assert error['details']['cleanup_report']['owned_process_group']['state']=='not_required'
print('Verified 8 original runtime outcomes and explicit pre-launch PTY failure')
