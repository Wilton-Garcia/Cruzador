#!/usr/bin/env python3
"""Download pinned Windows test inputs; never execute or install them."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parent.parent

def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): value.update(block)
    return value.hexdigest()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--asset', action='append'); args = parser.parse_args()
    lock = json.loads((ROOT/'config/windows-validation-assets.json').read_text()); assert lock['formatVersion'] == 1
    selected = set(args.asset or [a['id'] for a in lock['assets']])
    assert selected <= {a['id'] for a in lock['assets']}, 'Unknown asset'
    destination = ROOT/'.local/downloads'; destination.mkdir(parents=True, exist_ok=True)
    for asset in lock['assets']:
        if asset['id'] not in selected: continue
        path = destination/asset['filename']; assert path.parent == destination
        if path.exists():
            assert path.stat().st_size == asset['size'] and digest(path) == asset['sha256'], 'Existing asset differs; preserve it before downloading again'
        else:
            assert asset['url'].startswith('https://')
            staging = destination/('.download-' + str(uuid.uuid4()))
            request = urllib.request.Request(asset['url'], headers={'User-Agent': 'Cruzador-runtime-validation'})
            with urllib.request.urlopen(request, timeout=60) as response, staging.open('xb') as output:
                for block in iter(lambda: response.read(1024 * 1024), b''): output.write(block)
            assert staging.stat().st_size == asset['size'] and digest(staging) == asset['sha256'], 'Downloaded asset failed verification; staging retained'
            staging.rename(path)
        print(json.dumps({'asset': asset['id'], 'path': str(path), 'sha256': asset['sha256']}))
