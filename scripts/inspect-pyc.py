#!/usr/bin/env python3
"""Decode matched CPython bytecode as data. Never import/exec the target code."""
import argparse
import dis
import hashlib
import importlib.util
import io
import json
import marshal
from pathlib import Path
import sys
import types


def constant(value):
    if isinstance(value, types.CodeType): return {'kind':'code','name':value.co_name,'qualname':value.co_qualname}
    if value is None or isinstance(value,(str,bool,int,float)):return {'kind':type(value).__name__,'value':value}
    if isinstance(value,bytes):return {'kind':'bytes','hex':value.hex()}
    if isinstance(value,(tuple,frozenset)):
        values=[constant(item) for item in value]
        if isinstance(value,frozenset):values.sort(key=lambda item:json.dumps(item,sort_keys=True))
        return {'kind':type(value).__name__,'items':values}
    if value is Ellipsis:return {'kind':'ellipsis'}
    if isinstance(value,complex):return {'kind':'complex','real':value.real,'imag':value.imag}
    raise ValueError(f'Unsupported constant type: {type(value).__name__}')


def operand(value):
    if isinstance(value,type):
        return {'kind':'interpreter-symbol','module':value.__module__,'name':value.__qualname__}
    return constant(value)


def inspect(path):
    raw=path.read_bytes()
    if raw[:4]!=importlib.util.MAGIC_NUMBER:raise ValueError(f'CPython magic mismatch for {path}; use its matching interpreter')
    if len(raw)<16:raise ValueError('Truncated pyc header')
    stream=io.BytesIO(raw[16:]);root=marshal.load(stream)
    if stream.tell()!=len(raw)-16:raise ValueError('Trailing marshal data')
    if not isinstance(root,types.CodeType):raise ValueError('Expected module code object')
    records=[]
    def walk(code):
        instructions=[]
        for ins in dis.get_instructions(code,show_caches=False,adaptive=False):
            display=(f'code {ins.argval.co_qualname} ({ins.argval.co_filename}:{ins.argval.co_firstlineno})'
                     if isinstance(ins.argval,types.CodeType) else ins.argrepr)
            instructions.append({'offset':ins.offset,'opname':ins.opname,'arg':ins.arg,'argrepr':display,
                                 'argval':operand(ins.argval),'line':ins.starts_line,'jump_target':ins.is_jump_target})
        records.append({'index':len(records),'name':code.co_name,'qualname':code.co_qualname,'filename':code.co_filename,
                        'firstlineno':code.co_firstlineno,'argcount':code.co_argcount,'names':list(code.co_names),
                        'varnames':list(code.co_varnames),'consts':[constant(v) for v in code.co_consts],
                        'bytecode_sha256':hashlib.sha256(code.co_code).hexdigest(),'instructions':instructions,
                        'exception_entries':[dict(entry._asdict()) for entry in dis.Bytecode(code).exception_entries]})
        for value in code.co_consts:
            if isinstance(value,types.CodeType):walk(value)
    walk(root)
    return {'source_path':str(path),'sha256':hashlib.sha256(raw).hexdigest(),'magic_hex':raw[:4].hex(),
            'python_version':sys.version,'inspection':'marshal decode and CPython disassembly; target code not imported or executed',
            'code_objects':records,'limitations':['Disassembly is not recovered source.','Control-flow interpretation requires review of jumps and exception tables.']}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);args=p.parse_args()
    result=inspect(args.input);args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(f"Decoded {len(result['code_objects'])} code objects from {args.input.name}")
