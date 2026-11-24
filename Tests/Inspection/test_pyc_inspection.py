"""Boundary checks run with the matching CPython host; no target execution."""
import importlib.util
import marshal
from pathlib import Path
import runpy
import tempfile

inspect=runpy.run_path(str(Path(__file__).resolve().parents[2]/'scripts/inspect-pyc.py'))['inspect']

def fixture(path,source):
    code=compile(source,'original/日本語/source.py','exec')
    path.write_bytes(importlib.util.MAGIC_NUMBER+b'\0'*12+marshal.dumps(code))

def test_decodes_branches_and_exceptions_without_executing_module():
    with tempfile.TemporaryDirectory() as directory:
        path=Path(directory)/'sample.pyc';marker=Path(directory)/'executed'
        fixture(path,f"from pathlib import Path\nPath({str(marker)!r}).write_text('executed')\ndef choose(value):\n    try:\n        if value:\n            return '日本語'\n        return 'other'\n    except ValueError:\n        return None\nraise RuntimeError('must not execute')\n")
        data=inspect(path)
        assert not marker.exists(),'Target module was executed'
        function=next(c for c in data['code_objects'] if c['name']=='choose')
        assert any('JUMP' in i['opname'] for i in function['instructions'])
        assert function['exception_entries']
        assert function['filename']=='original/日本語/source.py'
        assert any(c.get('value')=='日本語' for c in function['consts'])

def test_rejects_wrong_magic_and_trailing_data():
    with tempfile.TemporaryDirectory() as directory:
        path=Path(directory)/'sample.pyc';fixture(path,'pass')
        raw=path.read_bytes();path.write_bytes(b'bad!'+raw[4:])
        try:inspect(path)
        except ValueError as error:assert 'magic mismatch' in str(error)
        else:raise AssertionError('Wrong magic was accepted')
        path.write_bytes(raw+b'extra')
        try:inspect(path)
        except ValueError as error:assert 'Trailing' in str(error)
        else:raise AssertionError('Trailing marshal data was accepted')

if __name__=='__main__':
    test_decodes_branches_and_exceptions_without_executing_module()
    test_rejects_wrong_magic_and_trailing_data()
    print('Passed 2 pyc inspection boundary checks')
