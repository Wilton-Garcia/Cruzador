#!/usr/bin/env python3
"""Verify disassembly identity and cross-check code digests with independent REA facts."""
import hashlib
import json
from pathlib import Path

root=Path(__file__).resolve().parent.parent
catalog=json.loads((root/'evidence/python-disassembly-catalog.json').read_text())
assert hashlib.sha256((root/'scripts/inspect-pyc.py').read_bytes()).hexdigest()==catalog['script_sha256']
assert hashlib.sha256((root/'tools/python-inspection-host.c').read_bytes()).hexdigest()==catalog['host_source_sha256']
modules={}
for item in catalog['modules']:
    path=root/item['output'];assert hashlib.sha256(path.read_bytes()).hexdigest()==item['output_sha256'],path
    data=json.loads(path.read_text());assert data['sha256']==item['source_sha256'];assert len(data['code_objects'])==item['code_objects']
    assert item['module'] not in modules;modules[item['module']]=data
    for code in data['code_objects']:
        offsets=[i['offset'] for i in code['instructions']]
        assert offsets==sorted(set(offsets)),code['qualname']
        assert all(i['opname']!='CACHE' for i in code['instructions'])
records=json.loads((root/'evidence/crossover-binary-study.evidence.json').read_text())['records']
checked=0
for evidence in records:
    if evidence['operation']!='inspect_python_pyc':continue
    facts=evidence['normalized_result'];module=Path(facts['artifact']['path']).stem
    if module not in modules:continue
    decoded=modules[module];assert decoded['sha256']==facts['artifact']['sha256'],module
    expected={(c['qualname'],c['firstlineno']):c for c in facts['code_objects']}
    observed={(c['qualname'],c['firstlineno']):c for c in decoded['code_objects']}
    assert expected.keys()==observed.keys(),module
    for key,code in expected.items():
        assert code['bytecode']['sha256']==observed[key]['bytecode_sha256'],(module,key)
        checked+=1
print(f"Verified {len(modules)} modules / {sum(len(m['code_objects']) for m in modules.values())} code objects; {checked} code digests match independent REA metadata")
