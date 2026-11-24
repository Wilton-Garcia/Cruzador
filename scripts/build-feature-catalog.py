#!/usr/bin/env python3
"""Build a stable catalog of observed surfaces and declared UI actions."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'evidence/feature-catalog.json'

def build():
    runtime = json.loads((ROOT / 'evidence/ui-observations.json').read_text())
    declarations = json.loads((ROOT / 'evidence/interface-declarations.json').read_text())
    features=[]
    for surface in runtime['observations']:
        for order,label in enumerate(surface['items']):
            features.append({'id':f"ui:{surface['id']}:{order}", 'label':label,'surface':surface['surface'],
                             'evidence_kind':'runtime-accessibility','source':'evidence/ui-observations.json',
                             'observation_id':surface['id'],'operation_success_established':False})
    for action in declarations['action_declarations']:
        identity = hashlib.sha256(action['id'].encode()).hexdigest()[:20]
        features.append({'id':f'ib:{identity}','label':action['selector'],'evidence_kind':'archive-declaration',
                         'source':'evidence/interface-declarations.json','node_id':action['id'],
                         'evidence_id':declarations['source_evidence_id'], 'operation_success_established':False})
    assert len({f['id'] for f in features}) == len(features)
    return {'version':1,'target':runtime['target'],'features':features,'surface_count':len(runtime['observations']),
            'runtime_items':sum(len(o['items']) for o in runtime['observations']),
            'declared_actions':len(declarations['action_declarations']),
            'limitations':runtime['limitations']+declarations['limitations']}

if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    result=build();text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.check:assert OUTPUT.read_text()==text,'Feature catalog is stale'
    else:OUTPUT.write_text(text)
    print(f"Catalog: {result['surface_count']} observed surfaces, {result['runtime_items']} UI items, {result['declared_actions']} archive action declarations")
