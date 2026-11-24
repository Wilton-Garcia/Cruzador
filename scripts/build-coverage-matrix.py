#!/usr/bin/env python3
"""Project reviewed capabilities without treating UI declarations as implementations."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parent.parent
OUTPUT=ROOT/'evidence/coverage-matrix.json'
DOC=ROOT/'docs/coverage.md'

def build():
    catalog=json.loads((ROOT/'evidence/feature-catalog.json').read_text())
    assessment=json.loads((ROOT/'evidence/capability-assessments.json').read_text())
    features={f['id']:f for f in catalog['features']}
    capabilities=assessment['capabilities'];mapping={key:[] for key in features};source_digests={}
    assert len({c['id'] for c in capabilities})==len(capabilities)
    for cap in capabilities:
        assert cap['prototype_status'] in ['missing','partial','implemented']
        assert cap['feature_ids'],cap['id']
        for fid in cap['feature_ids']:
            assert fid in features,fid
            mapping[fid].append(cap['id'])
        for path in cap['source_files']:
            data=(ROOT/path).read_bytes();source_digests[path]=hashlib.sha256(data).hexdigest()
        for test in cap['tests']:
            data=(ROOT/test['file']).read_text()
            assert re.search(r'func\s+'+re.escape(test['name'])+r'\s*\(',data),test
            source_digests[test['file']]=hashlib.sha256(data.encode()).hexdigest()
    rows=[{'feature_id':fid,'capability_ids':mapping[fid],'assessment':'mapped' if mapping[fid] else 'not-assessed'} for fid in features]
    return {'version':1,'capabilities':capabilities,'feature_coverage':rows,'source_sha256':dict(sorted(source_digests.items())),
            'counts':{'capabilities':len(capabilities),'catalog_items':len(rows),'mapped_items':sum(bool(r['capability_ids']) for r in rows),'unassessed_items':sum(not r['capability_ids'] for r in rows),'prototype_status':dict(Counter(c['prototype_status'] for c in capabilities))},
            'limitations':assessment['limitations']+['References and hashes establish provenance, not semantic correctness.','No behavioral-equivalence percentage is computed from control counts.']}

def markdown(matrix):
    counts=matrix['counts']; lines=['# Cobertura de reconstrução','','Matriz de evidência, implementação e validação do protótipo atual. `partial` significa implementação parcial no código, normalmente dependente de motor externo. `missing` indica ausência de implementação mapeada. Nenhum grupo tem equivalência independente estabelecida.','',
        f"Há {counts['capabilities']} grupos revisados e {counts['catalog_items']} itens de catálogo. {counts['mapped_items']} itens têm vínculo com um grupo; os outros {counts['unassessed_items']} permanecem explicitamente não avaliados. Controles repetidos e ações de framework não são funcionalidades independentes.",'',
        '| Capacidade | Conhecimento do original | Protótipo | Validação referenciada | Diferença restante |','| --- | --- | --- | --- | --- |']
    for c in matrix['capabilities']:
        validation='; '.join(t['scope'] for t in c['tests']) or 'Sem teste específico referenciado'
        lines.append('| '+' | '.join([c['title'],c['reverse_knowledge'],c['prototype_status'],validation,c['remaining_gap']]).replace('\n',' ')+' |')
    lines += ['', 'Os testes referenciados são os já existentes. A execução nativa registrada cobriu criação e `cmd.exe` via CrossOver instalado, não independência, instalação arbitrária ou todos os controles do Wine. A captura de interface do original comprova presença e estados observados, não sucesso de todas as operações.','',
              '[Avaliações revisadas](../evidence/capability-assessments.json) · [Matriz estruturada](../evidence/coverage-matrix.json).','',
              'Verifique a projeção com `python3 scripts/build-coverage-matrix.py --check`. Alterações nos arquivos referenciados mudam os hashes; a avaliação semântica deve ser revista quando o comportamento mudar.']
    return '\n'.join(lines)+'\n'

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    matrix=build();text=json.dumps(matrix,ensure_ascii=False,indent=2)+'\n';doc=markdown(matrix)
    if args.check:
        assert OUTPUT.read_text()==text,'Coverage matrix is stale'
        assert DOC.read_text()==doc,'Coverage documentation is stale'
    else:OUTPUT.write_text(text);DOC.write_text(doc)
    print(json.dumps(matrix['counts']))
