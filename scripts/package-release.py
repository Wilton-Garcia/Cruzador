#!/usr/bin/env python3
"""Build a local, verified drag-install image without publishing or changing installed apps."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parent.parent
IDENTIFIER = 'io.github.wilton-garcia.cruzador'

def run(arguments, **kwargs):
    return subprocess.run([str(value) for value in arguments], check=True, timeout=300, **kwargs)

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024*1024), b''): digest.update(block)
    return digest.hexdigest()

def package(app, output):
    app = app.resolve(); output = output.resolve()
    if output == app or output.is_relative_to(app): raise ValueError('Package outside the selected app bundle')
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != IDENTIFIER: raise ValueError('Selected bundle is not Cruzador')
    if output.exists(): raise ValueError('Retain the existing release output and select a new directory')
    run(['/usr/bin/codesign', '--verify', '--strict', app])
    run(['python3', ROOT/'scripts/prepare-wine-runtime.py', '--destination', app/'Contents/Resources/Runtime', '--verify'])
    output.mkdir(parents=True)
    stage = output/('stage-'+str(uuid.uuid4())); stage.mkdir()
    run(['/usr/bin/ditto', app, stage/'Cruzador.app'])
    (stage/'Applications').symlink_to('/Applications', target_is_directory=True)
    shutil.copy2(ROOT/'docs/Installation.html', stage/'Installation.html')
    image = output/'Cruzador.dmg'
    run(['/usr/bin/hdiutil', 'create', '-srcfolder', stage, '-volname', 'Cruzador', '-format', 'UDZO', image])
    run(['/usr/bin/hdiutil', 'verify', image])
    mount = output/'mounted'; mount.mkdir()
    attached = False
    try:
        run(['/usr/bin/hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, image]); attached = True
        embedded = mount/'Cruzador.app'
        run(['/usr/bin/codesign', '--verify', '--strict', embedded])
        if sha(embedded/'Contents/MacOS/Cruzador') != sha(app/'Contents/MacOS/Cruzador'): raise ValueError('Packaged executable changed')
        if not (mount/'Applications').is_symlink() or (mount/'Applications').readlink() != Path('/Applications'): raise ValueError('Install destination link differs')
    finally:
        if attached: run(['/usr/bin/hdiutil', 'detach', mount])
    signature = run(['/usr/bin/codesign', '-dvv', app], capture_output=True, text=True).stderr
    record = {'formatVersion': 1, 'bundleIdentifier': IDENTIFIER, 'version': info.get('CFBundleShortVersionString'), 'build': info.get('CFBundleVersion'),
              'source_app': str(app), 'image': str(image), 'sha256': sha(image), 'bytes': image.stat().st_size,
              'executable_sha256': sha(app/'Contents/MacOS/Cruzador'), 'signature_observation': signature,
              'image_verified': True, 'mounted_bundle_verified': True, 'published': False,
              'limitations': ['Installation and update use Finder drag-and-replace with the app closed; no automatic updater is implemented.',
                             'A valid local signature does not establish Developer ID, notarization or Gatekeeper acceptance.',
                             'Third-party source and license correspondence must be reviewed before public redistribution.',
                             'No installed app or user library was changed by packaging.']}
    (output/'release.json').write_text(json.dumps(record, indent=2)+'\n')
    shutil.rmtree(stage); mount.rmdir()
    return record

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--app', type=Path, default=ROOT/'build/Cruzador.app'); parser.add_argument('--output', type=Path, required=True); args = parser.parse_args()
    print(json.dumps(package(args.app, args.output), indent=2))
