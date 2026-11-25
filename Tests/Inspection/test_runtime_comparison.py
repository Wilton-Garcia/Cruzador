import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
spec = importlib.util.spec_from_file_location('comparison', ROOT/'scripts/compare-original-runtime.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)

class ComparisonTests(unittest.TestCase):
    def test_equal_status_is_not_enough_without_requested_markers(self):
        row = {'scenario': 'system32', 'original_exit': 0, 'independent_exit': 0, 'original_marker_and_environment': True, 'independent_marker_and_environment': False}
        self.assertNotEqual(module.assess(row), 'matching selected observations')
        row['independent_marker_and_environment'] = True
        self.assertEqual(module.assess(row), 'matching selected observations')
        row['independent_exit'] = None
        self.assertEqual(module.assess(row), 'observation unavailable')

    def test_failure_class_requires_two_failed_observations(self):
        row = {'scenario': 'invalid-msi', 'original_exit': 91, 'independent_exit': 91}
        self.assertEqual(module.assess(row), 'same observed failure class')
        row['independent_exit'] = 0
        self.assertEqual(module.assess(row), 'different observed outcome')
        row['independent_exit'] = False
        self.assertEqual(module.assess(row), 'observation unavailable')

if __name__ == '__main__': unittest.main()
