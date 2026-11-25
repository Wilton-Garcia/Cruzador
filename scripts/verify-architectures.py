#!/usr/bin/env python3
"""Validate declared native images with lipo and retain the tool observations."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess

ROOT=Path(__file__).resolve().parent.parent
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--app',type=Path,default=ROOT/'build/Cruzador.app');p.add_argument('--output',type=Path,default=ROOT/'.local/architecture-build.json');args=p.parse_args()
    images=[(args.app/'Contents/MacOS/Cruzador',{'arm64','x86_64'}),
            (args.app/'Contents/Resources/Runtime/bin/wine',{'x86_64'}),
            (args.app/'Contents/Resources/Runtime/bin/wineserver',{'x86_64'})]
    records=[]
    for path,expected in images:
        raw=subprocess.check_output(['/usr/bin/lipo','-archs',str(path)],text=True).strip()
        observed=set(raw.split())
        assert observed==expected,(str(path),raw,expected)
        records.append({'path':str(path.resolve()),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'lipo_output':raw,'architectures':sorted(observed)})
    build=subprocess.check_output(['/usr/bin/vtool','-show-build',str(images[0][0])],text=True)
    result={'host_process_architecture':platform.machine(),'operating_system':platform.mac_ver()[0],'images':records,'build_version_report':build,
            'limitations':['A universal binary is not proof of execution on both native host architectures.','Windows PE bitness is checked separately after actual execution.']}
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('Verified universal Cruzador plus x86_64 Wine and wineserver')
