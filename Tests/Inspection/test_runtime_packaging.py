import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

path=Path(__file__).resolve().parents[2]/'scripts/prepare-wine-runtime.py'
spec=importlib.util.spec_from_file_location('runtime_packaging',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class RuntimePackagingTests(unittest.TestCase):
    def test_archive_links_are_checked_with_internal_working_control(self):
        good=tarfile.TarInfo('Wine.app/runtime/lib/link');good.type=tarfile.SYMTYPE;good.linkname='../bin/wine'
        module.validate_members([good])
        outside=tarfile.TarInfo('Wine.app/runtime/lib/link');outside.type=tarfile.SYMTYPE;outside.linkname='../../../../outside'
        with self.assertRaisesRegex(ValueError,'External'):module.validate_members([outside])
        absolute=tarfile.TarInfo('/tmp/outside')
        with self.assertRaisesRegex(ValueError,'Unsafe'):module.validate_members([absolute])

    def test_preparation_is_repeatable_and_detects_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);archive=root/'wine.tar.xz'
            with tarfile.open(archive,'w:xz') as package:
                for name in ['wine','wineserver']:
                    data=b'#!/bin/sh\nexit 0\n';entry=tarfile.TarInfo('Wine.app/runtime/bin/'+name);entry.size=len(data);entry.mode=0o755;package.addfile(entry,io.BytesIO(data))
            license=root/'LICENSE';license.write_text('fixture')
            lock={'archive':{'sha256':module.sha(archive),'runtimePath':'Wine.app/runtime'},'identifier':'org.winehq.wine','version':'fixture','sourceURL':'https://example.invalid/source','sourceRevision':'fixture','providerRelease':'https://example.invalid/release','architectures':['test']}
            destination=root/'Runtime';licenses={'licenses/LICENSE':license}
            first=module.prepare(lock,archive,licenses,destination)
            self.assertEqual(module.prepare(lock,archive,licenses,destination),first)
            stage_spec=importlib.util.spec_from_file_location('stage_runtime',path.parent/'stage-wine-runtime.py')
            staging=importlib.util.module_from_spec(stage_spec);stage_spec.loader.exec_module(staging)
            app=root/'Cruzador.app'
            self.assertTrue(staging.stage(destination,app)['changed'])
            self.assertFalse(staging.stage(destination,app)['changed'])
            installed=app/'Contents/Resources/Runtime/bin/wine';installed.write_text('old changed data')
            replacement=staging.stage(destination,app)
            self.assertTrue(replacement['changed'])
            self.assertEqual((Path(replacement['backup'])/'bin/wine').read_text(),'old changed data')
            self.assertEqual(installed.read_text(),'#!/bin/sh\nexit 0\n')
            (destination/'bin/wine').write_text('changed')
            with self.assertRaisesRegex(ValueError,'differ'):module.verify(destination)

if __name__=='__main__':unittest.main()
