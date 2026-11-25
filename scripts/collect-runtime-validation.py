#!/usr/bin/env python3
"""Retain selected smoke metadata and logs with their paths, never runtime binaries."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import shutil

METADATA = ['runtime-smoke.json', 'msync-observations.json', 'original-runtime-smoke.json', 'runtime-control.json', 'phases.jsonl', 'report.json']

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): digest.update(block)
    return digest.hexdigest()

def collect(source, output, source_commit=None):
    requested_source, requested_output = str(source), str(output)
    source = source.resolve(); output = output.resolve()
    if not source.is_dir(): raise ValueError(f'Smoke evidence source unavailable: {source}')
    if output == source or output.is_relative_to(source): raise ValueError('Collect outside the smoke source to avoid recursive copies')
    paths = set()
    for root in list(source.glob('smoke-*')) + list(source.glob('workflow-diagnostics-*')):
        if root.is_symlink(): continue
        if root.is_file():
            if root.name.endswith(('.test.log', '.supervision.json')): paths.add(root)
            continue
        if not root.is_dir(): continue
        paths.update(root/name for name in METADATA if (root/name).is_file() and not (root/name).is_symlink())
        logs = root/'Logs'
        if logs.is_dir() and not logs.is_symlink():
            for folder, directories, files in os.walk(logs, followlinks=False):
                directories[:] = [name for name in directories if not (Path(folder)/name).is_symlink()]
                paths.update(Path(folder)/name for name in files if (Path(folder)/name).is_file() and not (Path(folder)/name).is_symlink())
    summary = source/'packaged-runtime-smoke.json'
    if summary.is_file() and not summary.is_symlink(): paths.add(summary)
    records = []
    for path in sorted(paths):
        relative = Path('evidence')/path.relative_to(source)
        target = output/relative
        if target.exists():
            if not target.is_file() or sha(target) != sha(path): raise ValueError(f'Existing captured evidence differs; choose another output: {target}')
        else:
            target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(path, target)
        records.append({'source': str(path), 'exported_path': str(relative), 'bytes': target.stat().st_size, 'sha256': sha(target)})
    # Keep the one historical top-level artifact name for existing report consumers.
    if summary in paths:
        target = output/summary.name
        if target.exists() and sha(target) != sha(summary): raise ValueError(f'Existing summary differs: {target}')
        if not target.exists(): shutil.copy2(summary, target)
    output.mkdir(parents=True, exist_ok=True)
    index = {'formatVersion': 1, 'requested_source': requested_source, 'requested_output': requested_output, 'source': str(source), 'source_commit': source_commit, 'files': records,
             'limitations': ['Only selected smoke metadata and regular log files are collected.', 'Runtime binaries, prefixes and raw source-library.json are not collected.', 'Copies are separate observations, not an atomic filesystem snapshot.']}
    data = json.dumps(index, ensure_ascii=False, indent=2) + '\n'
    destination = output/'evidence-index.json'
    if destination.exists() and destination.read_text() != data: raise ValueError(f'Existing evidence index differs; choose another output: {destination}')
    if not destination.exists(): destination.write_text(data)
    return index

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--source', type=Path, default=Path('.local')); parser.add_argument('--output', type=Path, default=Path('validation')); parser.add_argument('--source-commit'); args = parser.parse_args()
    index = collect(args.source, args.output, args.source_commit)
    print(json.dumps({'files': len(index['files']), 'output': str(args.output.resolve())}))
