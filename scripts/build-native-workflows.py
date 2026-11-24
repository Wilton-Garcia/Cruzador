#!/usr/bin/env python3
"""Link provider-observed direct call targets without inventing dynamic receivers."""
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
OUTPUT=ROOT/'evidence/native-workflows.json'
FLOWS={'new-bottle':'0x10001ba64','run-command':'0x100017e4c','graphics':'0x1000232f8','python-bridge':'0x100039c10','task-launch':'0x100039ad8'}

def build():
    bundle=json.loads((ROOT/'evidence/crossover-binary-study.evidence.json').read_text())
    inventory=next(r for r in bundle['records'] if r['operation']=='list_procedures')
    names={r['address']:r['value'] for r in inventory['normalized_result']}
    flows=[]
    for name,address in FLOWS.items():
        source=next(r for r in bundle['records'] if r['operation']=='procedure_callees' and r['parameters']['procedure']==address)
        edges=[]
        for destination in source['normalized_result']:
            label=names.get(destination)
            kind='selector-only' if label and label.startswith('_objc_msgSend$') else 'import-stub' if label and label.startswith('imp___stubs__') else 'native-entry' if label else 'unresolved-name'
            edges.append({'destination':destination,'provider_name':label,'resolution':kind})
        flows.append({'id':name,'entry':address,'provider_name':names.get(address),'evidence_id':source['evidence_id'],'direct_targets':edges,'dynamic_receiver_resolution':'unknown'})
    dispatch=next(r for r in bundle['records'] if r['operation']=='inspect_native_dispatch_metadata')
    catalog=json.loads((ROOT/'evidence/native-export-catalog.json').read_text())
    return {'version':1,'target_sha256':catalog['target_sha256'],'architecture':'arm64','exported_records':catalog['total_records'],'exported_groups':len(catalog['groups']),
            'inventory_evidence_id':inventory['evidence_id'],'flows':flows,
            'dispatch_metadata':{'evidence_id':dispatch['evidence_id'],'coverage':dispatch['normalized_result']['result']['coverage']},
            'interrupted_observation':{'operation':'inspect_native_dispatch_metadata','parameters':{'max_records':20000},'result':'MCP transport closed before a result was delivered','completion':'unknown','replayed':False},
            'limitations':['Direct target rows cover the provider observation, not every dynamic call.','An Objective-C selector does not identify a unique runtime receiver.','Selected application workflows were exported; decorative views and unrelated controllers were not exhaustively reviewed.','The main executable analysis does not establish Wine or graphics implementation internals.']}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    result=build();text=json.dumps(result,ensure_ascii=False,indent=2)+'\n'
    if args.check:assert OUTPUT.read_text()==text,'Native workflow report is stale'
    else:OUTPUT.write_text(text)
    print(f"{result['exported_records']} exports / {result['exported_groups']} groups / {len(result['flows'])} direct-call observations")
