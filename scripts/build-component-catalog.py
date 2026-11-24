#!/usr/bin/env python3
"""Project component roles from REA-owned directory facts; never execute targets."""
import argparse
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'evidence/component-inventory.evidence.json'
OUTPUT = ROOT / 'evidence/component-catalog.json'
BASE = 'Contents/SharedSupport/CrossOver/'

def role(path):
    if path.startswith('Contents/MacOS/'): return 'native-application'
    if path.startswith('Contents/Frameworks/Python.framework/'): return 'python-runtime'
    if path.startswith('Contents/Frameworks/Sparkle.framework/'): return 'updater-framework'
    if path.startswith(BASE + 'lib/python/'): return 'application-python'
    if path.startswith(BASE + 'lib/perl/'): return 'application-perl'
    if path.startswith(BASE + 'CrossOver-Hosted Application/'): return 'command-tools'
    if path == BASE + 'bin': return 'command-tools-alias'
    if any(path.startswith(BASE + prefix) for prefix in ['lib/dxmt/', 'lib/dxvk/', 'lib64/apple_gptk/']): return 'graphics-backends'
    if path.startswith(BASE + 'share/wine/mono/'): return 'mono-runtime'
    if path.startswith(BASE + 'lib/wine/'): return 'wine-runtime'
    if path.startswith(BASE + 'lib64/'): return 'native-support-libraries'
    if path.startswith(BASE + 'share/crossover/bottle_templates/'): return 'bottle-templates'
    if path.startswith(BASE + 'share/crossover/'): return 'compatibility-data'
    if path.startswith(BASE + 'etc/'): return 'configuration'
    if path.startswith('Contents/Resources/'):
        return 'interface-and-resources'
    if path.startswith(BASE + 'share/locale/'): return 'localization'
    if path.endswith(('license.txt', 'ThirdPartyLicenses.txt', 'README', 'changelog.html')): return 'documentation-and-notices'
    return 'other-or-unclassified'

def build():
    bundle = json.loads(SOURCE.read_text())
    sources = [r for r in bundle['records'] if r['operation'] == 'inspect_desktop_application']
    assert len(sources) == 1, 'Select one inventory observation explicitly'
    source = sources[0]; observed = source['normalized_result']
    entries = []
    for fact in observed['files']:
        entries.append({'file_id': fact['file_id'], 'path': fact['path'], 'kind': fact['kind'], 'bytes': fact['bytes'],
                        'role': role(fact['path']), 'classification': 'path-derived', 'format_facts': fact['facts'],
                        'read_status': fact['read_status'], 'issues': fact['issues']})
    entries.sort(key=lambda e: (e['path'], e['file_id']))
    assert len({e['file_id'] for e in entries}) == len(entries)
    counts = Counter(e['role'] for e in entries)
    return {'version': 1, 'source_evidence_id': source['evidence_id'], 'source_bundle': str(SOURCE.relative_to(ROOT)),
            'root': observed['root'], 'coverage': observed['coverage'], 'omissions': observed['omissions'],
            'counts_by_role': dict(sorted(counts.items())), 'entry_count': len(entries), 'entries': entries,
            'limitations': ['Roles are path-derived categories, not runtime loading observations.',
                            'All retained entries are categorized, including explicit other-or-unclassified entries.',
                            'Symlinks were not followed; directory aliases are not independent copies.',
                            'REA snapshot identity covers metadata and read ranges, not every byte of every file.',
                            'A sequential directory inventory is not an atomic filesystem snapshot.']}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--check', action='store_true'); args = parser.parse_args()
    result = build(); text = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        assert OUTPUT.read_text() == text, 'Component catalog is stale'
    else: OUTPUT.write_text(text)
    print(f"{'Verified' if args.check else 'Wrote'} {result['entry_count']} entries in {len(result['counts_by_role'])} component roles")
