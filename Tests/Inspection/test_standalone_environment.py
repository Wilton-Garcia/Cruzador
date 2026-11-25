import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('standalone', Path(__file__).resolve().parents[2]/'scripts/verify-standalone-environment.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)

class StandaloneEnvironmentTests(unittest.TestCase):
    def test_original_identified_even_with_another_bundle_name(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(module.inspect([root])['status'], 'absent-in-inspected-roots')
            app = root/'Renamed.app'/'Contents'; app.mkdir(parents=True)
            (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.codeweavers.CrossOver'}))
            report = module.inspect([root])
            self.assertEqual(report['status'], 'present'); self.assertEqual(len(report['findings']), 1)

    def test_malformed_bundle_is_unknown_and_regular_other_app_is_control(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); app = root/'Other.app'/'Contents'; app.mkdir(parents=True)
            info = app/'Info.plist'; info.write_bytes(b'<?xml version="1.0"?><plist><dict>&broken;</dict></plist>')
            self.assertEqual(module.inspect([root])['status'], 'unknown')
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'org.example.other'}))
            self.assertEqual(module.inspect([root])['status'], 'absent-in-inspected-roots')

if __name__ == '__main__': unittest.main()
