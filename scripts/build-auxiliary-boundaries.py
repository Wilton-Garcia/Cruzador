#!/usr/bin/env python3
"""Project exact helper identities and observed boundaries from retained REA facts."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
OUTPUT=ROOT/'evidence/auxiliary-boundaries.json'

def load(path,operation):
    value=json.loads((ROOT/path).read_text())
    records=value.get('records',[value])
    return next(r for r in records if r['operation']==operation)

def build():
    images=[]
    for name in ['wineloader','wineserver','ntdll']:
        path=f'evidence/{name}-macho.evidence.json';r=load(path,'inspect_macho');n=r['normalized_result']
        images.append({'id':name,'source':path,'evidence_id':r['evidence_id'],'identity':r['subject'],
                       'dependencies':n['dependencies'],'entrypoints':n['entrypoints'],
                       'exports_exhaustive':n['exports']['exhaustive']})
    pe=load('evidence/auxiliary/winewrapper-imports.json','inspect_pe_imports')
    index=json.loads((ROOT/'evidence/auxiliary/wineloader/decompile-index.json').read_text())
    for r in index['functions']:
        if r['status']=='written':assert hashlib.sha256((ROOT/'evidence/auxiliary/wineloader'/r['relative_path']).read_bytes()).hexdigest()==r['sha256']
    entries=[]
    for filename in ['wineserver-entry','ntdll-wine-main']:
        r=load(f'evidence/auxiliary/{filename}.json','procedure_pseudo_code')
        assert isinstance(r['normalized_result'],str) and r['normalized_result'].strip()
        entries.append({'source':f'evidence/auxiliary/{filename}.json','evidence_id':r['evidence_id'],'subject':r['subject'],'parameters':r['parameters']})
    return {'version':1,'native_images':images,'wrapper':{'source':'evidence/auxiliary/winewrapper-imports.json','evidence_id':pe['evidence_id'],'artifact':pe['normalized_result']['artifact'],'coverage':pe['normalized_result']['coverage']},
            'loader_export':{'index':'evidence/auxiliary/wineloader/decompile-index.json','records':len(index['functions']),'sha256':index['target_sha256']},'entry_decompilations':entries,
            'findings':[{'kind':'static-decompilation','source':'evidence/auxiliary/wineloader/functions/0x100000670.c','fact':'Loader locates ntdll.so, uses dlopen and resolves __wine_main with dlsym; WINEDLLPATH participates in fallback lookup.'},
                        {'kind':'static-decompilation','source':'evidence/auxiliary/ntdll-wine-main.json','fact':'__wine_main reads WINELOADERNOEXEC, handles help/version and initializes native runtime paths and a CoreFoundation run loop.'},
                        {'kind':'static-decompilation','source':'evidence/auxiliary/wineserver-entry.json','fact':'Server entry parses options, registers signal handlers and configures descriptor resource limits before unnamed internal initialization calls.'}],
            'limitations':['Selected images are x86_64; runtime execution under translation was not observed in this static step.','Exports of stripped images are not exhaustive inventories of internal functions.','Server protocol, Win32 semantics and graphics internals were not recovered in full.','Pseudocode is not original source; complete native body ranges remain unavailable.']}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    result=build();text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.check:assert OUTPUT.read_text()==text,'Auxiliary report is stale'
    else:OUTPUT.write_text(text)
    print('Verified helper identities, loader exports, PE imports and two native entry decompilations')
