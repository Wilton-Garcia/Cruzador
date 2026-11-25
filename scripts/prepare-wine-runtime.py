#!/usr/bin/env python3
"""Prepare the pinned open Wine runtime locally; never install system software."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import shutil
import tarfile
import tempfile
import urllib.request

ROOT=Path(__file__).resolve().parent.parent

def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1024*1024),b''):h.update(block)
    return h.hexdigest()

def fetch(item,cache):
    path=cache/item['name'];cache.mkdir(parents=True,exist_ok=True)
    if not path.exists():
        temporary=path.with_suffix(path.suffix+'.partial')
        with urllib.request.urlopen(item['url'],timeout=60) as response,temporary.open('wb') as out:shutil.copyfileobj(response,out)
        if sha(temporary)!=item['sha256']:raise ValueError(f'Download digest mismatch: {temporary}')
        temporary.replace(path)
    if sha(path)!=item['sha256']:raise ValueError(f'Cached digest mismatch: {path}')
    return path

def validate_members(members):
    for member in members:
        path=PurePosixPath(member.name)
        if path.is_absolute() or '..' in path.parts:raise ValueError(f'Unsafe archive path: {member.name}')
        if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):raise ValueError(f'Unsupported special archive entry: {member.name}')
        if member.issym() or member.islnk():
            target=member.linkname
            joined=posixpath.normpath(posixpath.join(str(path.parent),target) if member.issym() else target)
            if target.startswith('/') or joined=='..' or joined.startswith('../'):raise ValueError(f'External archive link: {member.name}')

def inventory(root):
    records=[]
    for folder,dirs,files in os.walk(root,followlinks=False):
        for name in sorted(dirs+files):
            path=Path(folder)/name;relative=path.relative_to(root).as_posix()
            if relative in ['runtime.json','runtime-files.json']:continue
            if path.is_symlink():
                resolved=path.resolve(strict=False)
                if not resolved.is_relative_to(root.resolve()):raise ValueError(f'Runtime link escapes package: {relative}')
                records.append({'path':relative,'kind':'symlink','target':os.readlink(path)})
            elif path.is_file():records.append({'path':relative,'kind':'file','bytes':path.stat().st_size,'sha256':sha(path)})
    return sorted(records,key=lambda r:r['path'])

def verify(root):
    manifest=json.loads((root/'runtime.json').read_text());records=json.loads((root/'runtime-files.json').read_text())
    if sha(root/'runtime-files.json')!=manifest['inventorySHA256']:raise ValueError('Runtime inventory digest mismatch')
    if inventory(root)!=records:raise ValueError('Runtime files differ from the inventory')
    return manifest

def prepare(lock,archive,licenses,destination):
    if sha(archive)!=lock['archive']['sha256']:raise ValueError('Archive digest mismatch')
    if destination.exists():
        manifest=verify(destination)
        if manifest['archiveSHA256']!=lock['archive']['sha256']:raise ValueError('Existing runtime belongs to another archive; preserve it before replacement')
        for key in ['identifier','version','sourceURL','sourceRevision','architectures']:
            if manifest[key]!=lock[key]:raise ValueError(f'Existing runtime metadata differs: {key}')
        for key in ['formatVersion','minimumMacOSVersion','features','builderRevision']:
            if manifest.get(key,1 if key=='formatVersion' else None)!=lock.get(key,1 if key=='formatVersion' else None):raise ValueError(f'Existing runtime metadata differs: {key}')
        if manifest['licenseFiles']!=list(licenses):raise ValueError('Existing license selection differs')
        for relative,source in licenses.items():
            if sha(destination/relative)!=sha(source):raise ValueError(f'Existing license differs: {relative}')
        return manifest
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='runtime-stage-',dir=destination.parent) as temporary:
        stage=Path(temporary)
        with tarfile.open(archive,'r:*') as package:
            members=package.getmembers();validate_members(members);package.extractall(stage,members=members)
        runtime=stage/lock['archive']['runtimePath']
        if not runtime.is_dir():raise ValueError('Selected runtime directory is absent from archive')
        for relative,source in licenses.items():
            selected=PurePosixPath(relative)
            if selected.is_absolute() or '..' in selected.parts:raise ValueError('License path must stay inside runtime')
            target=runtime/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
        for relative in ['bin/wine','bin/wineserver']:
            if not (runtime/relative).is_file() or not os.access(runtime/relative,os.X_OK):raise ValueError(f'Missing executable: {relative}')
        (runtime/'runtime-files.json').write_text(json.dumps(inventory(runtime),ensure_ascii=False,indent=2)+'\n')
        manifest={'formatVersion':lock.get('formatVersion',1),'identifier':lock['identifier'],'version':lock['version'],'sourceURL':lock['sourceURL'],'sourceRevision':lock['sourceRevision'],
                  'providerRelease':lock['providerRelease'],'archiveSHA256':lock['archive']['sha256'],'architectures':lock['architectures'],
                  'wineExecutable':'bin/wine','serverExecutable':'bin/wineserver','licenseFiles':list(licenses),'inventorySHA256':sha(runtime/'runtime-files.json'),
                  'distributionStatus':'development-package; complete third-party attribution review remains unverified'}
        for key in ['minimumMacOSVersion','features','builderRevision']:
            if key in lock:manifest[key]=lock[key]
        (runtime/'runtime.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        verify(runtime)
        runtime.rename(destination)
    return manifest

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--destination',type=Path,default=ROOT/'.local/Runtime-11.21');parser.add_argument('--verify',action='store_true');parser.add_argument('--lock',type=Path,default=ROOT/'config/wine-runtime-lock.json');args=parser.parse_args()
    if args.verify:
        manifest=verify(args.destination.resolve())
    else:
        lock=json.loads(args.lock.read_text());cache=ROOT/'.local/downloads'
        archive=fetch(lock['archive'],cache);licenses={}
        for item in lock['licenses']:
            cached=fetch(dict(item,name=lock['version']+'-'+Path(item['path']).name),cache);licenses[item['path']]=cached
        manifest=prepare(lock,archive,licenses,args.destination.resolve())
    print(json.dumps({'runtime':str(args.destination.resolve()),'version':manifest['version'],'archiveSHA256':manifest['archiveSHA256']},indent=2))
