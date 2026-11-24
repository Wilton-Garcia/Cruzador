#!/usr/bin/env python3
"""Verify published decompilation packages against retained export digests."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / 'evidence/native-export-catalog.json').read_text())
bundle = json.loads((root / 'evidence/crossover-binary-study.evidence.json').read_text())
ids = {record['evidence_id'] for record in bundle['records']}
feature_map = json.loads((root / 'evidence/binary-feature-map.json').read_text())
total = 0
seen = set()
for group in catalog['groups']:
    path = root / group['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == group['sha256'], path
    package = json.loads(path.read_text())
    assert package['manifest']['target_sha256'] == catalog['target_sha256'], path
    assert len(package['records']) == group['records'], path
    manifest_records = {r['address']: r for r in package['manifest']['functions'] if r['status'] == 'written'}
    for item in package['records']:
        record = item['record']
        assert record == manifest_records[record['address']], path
        assert record['address'] not in seen, record['address']
        assert hashlib.sha256(item['exported_text'].encode('utf-8')).hexdigest() == record['sha256'], record['address']
        assert '// pseudocode: provider-specific; not original source' in item['exported_text'], path
        seen.add(record['address'])
        total += 1
assert total == catalog['total_records'], total
for finding in feature_map['findings']:
    assert finding['evidence_id'] in ids, finding['id']
    assert any(r['evidence_id'] == finding['evidence_id'] and r['subject']['identity'].get('sha256') == catalog['target_sha256'] for r in bundle['records']), finding['id']
for module in feature_map['python_modules']:
    assert module['evidence_id'] in ids, module['path']
assert feature_map['interface_actions']['evidence_id'] in ids
print(f"Verified {total} native exports in {len(catalog['groups'])} packages; {len(feature_map['findings'])} findings link to matching target Evidence.")
