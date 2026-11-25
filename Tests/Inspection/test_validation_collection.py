import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

path = Path(__file__).resolve().parents[2]/'scripts/collect-runtime-validation.py'
spec = importlib.util.spec_from_file_location('collection', path); collection = importlib.util.module_from_spec(spec); spec.loader.exec_module(collection)

class ValidationCollectionTests(unittest.TestCase):
    def test_paths_and_digests_survive_duplicate_names_without_copying_prefixes_or_links(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); source = root/'local'; source.mkdir(); output = root/'validation'
            for name, text in [('smoke-one', 'first'), ('workflow-diagnostics-two', 'second')]:
                folder = source/name; (folder/'Logs').mkdir(parents=True)
                (folder/'Logs/run.log').write_text(text)
                (folder/'source-library.json').write_text('not selected')
                (folder/'Prefix').mkdir(); (folder/'Prefix/program.exe').write_bytes(b'not selected')
                (folder/'runtime-control.json').write_text('{}')
            outside = root/'external'; outside.write_text('not selected')
            (source/'smoke-one/Logs/link.log').symlink_to(outside)
            (source/'packaged-runtime-smoke.json').write_text('{"retained":true}')
            index = collection.collect(source, output, 'fixture-commit')
            self.assertEqual(collection.collect(source, output, 'fixture-commit'), index)
            self.assertEqual((output/'evidence/smoke-one/Logs/run.log').read_text(), 'first')
            self.assertEqual((output/'evidence/workflow-diagnostics-two/Logs/run.log').read_text(), 'second')
            self.assertFalse(list(output.rglob('program.exe'))); self.assertFalse(list(output.rglob('source-library.json'))); self.assertFalse(list(output.rglob('link.log')))
            for record in index['files']: self.assertEqual(collection.sha(output/record['exported_path']), record['sha256'])
            self.assertEqual(json.loads((output/'evidence-index.json').read_text())['source_commit'], 'fixture-commit')
            with self.assertRaises(ValueError): collection.collect(source, source/'recursive')
            (source/'smoke-one/Logs/run.log').write_text('changed source')
            with self.assertRaises(ValueError): collection.collect(source, output)
            self.assertEqual((output/'evidence/smoke-one/Logs/run.log').read_text(), 'first')

if __name__ == '__main__': unittest.main()
