#!/usr/bin/env python3
"""Download pinned Windows test inputs; never execute or install them."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent

def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''): value.update(block)
    return value.hexdigest()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--asset', action='append'); parser.add_argument('--additional-apps', action='store_true'); args = parser.parse_args()
    lock = json.loads((ROOT/('config/additional-validation-apps.json' if args.additional_apps else 'config/recipes.json')).read_text()); assert lock['formatVersion'] == 1
    entries = lock.get('artifacts', lock.get('assets'))
    selected = set(args.asset or [a['id'] for a in entries])
    assert selected <= {a['id'] for a in entries}, 'Unknown asset'
    destination = ROOT/('.local/additional-apps' if args.additional_apps else '.local/downloads'); destination.mkdir(parents=True, exist_ok=True)
    for asset in entries:
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
        if asset.get('member'):
            member = asset['member']; assert Path(member).name == member
            with zipfile.ZipFile(path) as archive: data = archive.read(member)
            assert hashlib.sha256(data).hexdigest() == asset['member_sha256']
            target = destination/member
            if target.exists(): assert target.read_bytes() == data, 'Existing extracted member differs; retain it'
            else: target.write_bytes(data)
        print(json.dumps({'asset': asset['id'], 'path': str(path), 'sha256': asset['sha256']}))
