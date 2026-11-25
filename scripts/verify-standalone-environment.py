#!/usr/bin/env python3
"""Record bounded application-directory evidence; never infer whole-machine absence."""
import argparse
import json
import os
from pathlib import Path
import platform
import plistlib
import sys
from xml.parsers.expat import ExpatError


def inspect(roots):
    findings, errors, examined = [], [], 0
    for root in roots:
        if not root.exists():
            if root.is_symlink(): errors.append({'path': str(root), 'error': 'Unresolved applications directory link'})
            continue
        if not root.is_dir():
            errors.append({'path': str(root), 'error': 'Applications root is not a directory'}); continue
        def failed(error): errors.append({'path': error.filename, 'error': str(error)})
        for folder, directories, _ in os.walk(root, onerror=failed, followlinks=False):
            for name in list(directories):
                candidate = Path(folder)/name
                if not name.lower().endswith('.app'): continue
                directories.remove(name); examined += 1
                try:
                    info = plistlib.loads((candidate/'Contents/Info.plist').read_bytes())
                    if not isinstance(info, dict): raise ValueError('Bundle plist is not a dictionary')
                    identifier = info.get('CFBundleIdentifier')
                    if name.lower() == 'crossover.app' or identifier == 'com.codeweavers.CrossOver':
                        findings.append({'path': str(candidate), 'bundle_identifier': identifier})
                except (OSError, ValueError, plistlib.InvalidFileException, ExpatError) as error:
                    errors.append({'path': str(candidate), 'error': str(error)})
    status = 'present' if findings else ('unknown' if errors else 'absent-in-inspected-roots')
    return {'formatVersion': 1, 'status': status, 'roots': [str(root) for root in roots], 'application_bundles_examined': examined,
            'findings': findings, 'errors': errors, 'host_architecture': platform.machine(), 'operating_system': platform.platform(),
            'limitations': ['Only named application directories were inspected; this is not a whole-disk or running-process census.',
                            'Application bundles are inspected through their names and Info.plist identities; arbitrary renamed binaries outside bundles are not detected.',
                            'No target executable was run or changed by this inspection.']}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--applications-root', action='append', type=Path); parser.add_argument('--output', required=True, type=Path); args = parser.parse_args()
    roots = args.applications_root or [Path('/Applications'), Path('/System/Applications'), Path.home()/'Applications']
    report = inspect(roots)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists(): raise ValueError('Retain the existing observation; select a new output path')
    args.output.write_text(json.dumps(report, indent=2)+'\n'); print(json.dumps(report))
    sys.exit(0 if report['status'] == 'absent-in-inspected-roots' else 1)
