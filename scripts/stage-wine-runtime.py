#!/usr/bin/env python3
"""Stage a verified runtime in an app, retaining an older package on replacement."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import uuid

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('prepare_wine_runtime',ROOT/'scripts/prepare-wine-runtime.py')
packaging=importlib.util.module_from_spec(spec);spec.loader.exec_module(packaging)

def stage(source,app):
    manifest=packaging.verify(source)
    resources=app/'Contents/Resources';resources.mkdir(parents=True,exist_ok=True)
    destination=resources/'Runtime'
    if destination.exists():
        try:current=packaging.verify(destination)
        except (ValueError,OSError,KeyError):current=None
        if current==manifest:return {'runtime':str(destination),'changed':False,'backup':None}
    with tempfile.TemporaryDirectory(prefix='runtime-copy-',dir=app.parent) as temporary:
        staged=Path(temporary)/'Runtime';shutil.copytree(source,staged,symlinks=True)
        packaging.verify(staged)
        backup=None
        if destination.exists():
            backup=app.parent/('Runtime-backup-'+str(uuid.uuid4()));destination.rename(backup)
        try:staged.rename(destination)
        except BaseException:
            if backup is not None:backup.rename(destination)
            raise
    return {'runtime':str(destination),'changed':True,'backup':str(backup) if backup is not None else None}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('app',type=Path);args=p.parse_args()
    print(json.dumps(stage(args.source.resolve(),args.app.resolve()),indent=2))
