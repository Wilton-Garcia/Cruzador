#!/usr/bin/env python3
"""Use an isolated matching CPython host; inspect every top-level business pyc."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parent.parent

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--app',type=Path,default=Path('/Applications/CrossOver.app'));args=p.parse_args()
    home=args.app/'Contents/Frameworks/Python.framework/Versions/3.13';library=home/'Python'
    inputs=args.app/'Contents/SharedSupport/CrossOver/lib/python'
    host=ROOT/'.local/python-inspection-host';host.parent.mkdir(exist_ok=True)
    subprocess.run(['clang','-std=c11','-Wall','-Wextra','-Werror',str(ROOT/'tools/python-inspection-host.c'),'-o',str(host)],check=True,timeout=60)
    runtime_digest=digest(library)
    subprocess.run([str(host),str(library),str(home),str(ROOT/'Tests/Inspection/test_pyc_inspection.py')],check=True,timeout=30)
    output=ROOT/'evidence/python-disassembly';output.mkdir(exist_ok=True)
    records=[]
    paths=sorted(inputs.glob('*.pyc'))
    if not paths:raise RuntimeError('No top-level pyc files at the selected application path')
    for path in paths:
        result=output/(path.stem+'.json')
        subprocess.run([str(host),str(library),str(home),str(ROOT/'scripts/inspect-pyc.py'),str(path),str(result)],check=True,timeout=30)
        decoded=json.loads(result.read_text())
        assert decoded['sha256']==digest(path),'Input changed during inspection'
        records.append({'module':path.stem,'source_path':str(path),'source_sha256':decoded['sha256'],'code_objects':len(decoded['code_objects']),
                        'output':str(result.relative_to(ROOT)),'output_sha256':digest(result)})
    assert runtime_digest==digest(library),'Interpreter library changed during inspection'
    catalog={'version':1,'interpreter_library':str(library),'interpreter_sha256':runtime_digest,'script_sha256':digest(ROOT/'scripts/inspect-pyc.py'),
             'host_source_sha256':digest(ROOT/'tools/python-inspection-host.c'),'modules':records,
             'inspection':'Business modules decoded with marshal and dis; never imported or executed',
             'limitations':['The interpreter and its standard library execute as analysis tooling.','Only top-level lib/python/*.pyc files selected; nested modules and other language runtimes are outside this selection.','Disassembly is not original source and does not establish runtime behavior.']}
    (ROOT/'evidence/python-disassembly-catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    print(f"Inspected {len(records)} modules and {sum(r['code_objects'] for r in records)} code objects")
