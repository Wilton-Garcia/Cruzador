#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
report=json.loads((root/'evidence/recovered-contracts.json').read_text())
ids=set();count=0
runs={r['id'] for r in json.loads((root/report['runtime_results']).read_text())['runs']}
for contract in report['contracts']:
    assert contract['id'] not in ids;ids.add(contract['id'])
    for source in contract['sources']:
        data=json.loads((root/source['path']).read_text());assert data['sha256']==source['module_sha256']
        code=next(c for c in data['code_objects'] if c['qualname']==source['qualname'] and c['firstlineno']==source['firstlineno'])
        assert code['bytecode_sha256']==source['bytecode_sha256'];count+=1
    assert set(contract['runtime_scenarios'])<=runs
for contract in report['native_contracts']:
    for path in contract['sources']:assert (root/path).is_file()
print(f"Verified {len(ids)} recovered Python contracts with {count} code references and {len(report['native_contracts'])} native contracts")
