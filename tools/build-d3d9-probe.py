#!/usr/bin/env python3
"""Build a deterministic, standalone Windows x64 PE graphics probe.

No Windows SDK or binary is copied. The small program calls documented Win32
and D3D9 COM interfaces, clears/presents one frame, writes a success marker and
exits. Exit 10/11/12/13/14 identifies window/D3D/device/clear/present failure.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def align(value, boundary):
    return (value + boundary - 1) // boundary * boundary


def build():
    data = bytearray()
    symbols = {}

    def allocate(name, payload, alignment=1):
        data.extend(b'\0' * (align(len(data), alignment) - len(data)))
        symbols[name] = 0x2000 + len(data)
        data.extend(payload)
        return symbols[name]

    allocate('class', b'STATIC\0')
    allocate('title', b'Cruzador D3D9 probe\0')
    marker = b'CRUZADOR_D3D9_FRAME_OK\r\n'
    allocate('marker', marker)
    allocate('written', b'\0' * 8, 8)
    allocate('device', b'\0' * 8, 8)
    # D3DPRESENT_PARAMETERS: seven DWORDs, padding, HWND and six DWORDs.
    allocate('present', struct.pack('<7I4xQ6I', 320, 240, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0), 8)
    imports = {
        'KERNEL32.dll': ['ExitProcess', 'GetStdHandle', 'WriteFile'],
        'USER32.dll': ['CreateWindowExA', 'ShowWindow', 'UpdateWindow', 'DestroyWindow'],
        'D3D9.dll': ['Direct3DCreate9'],
    }
    descriptors = allocate('imports', b'\0' * (20 * (len(imports) + 1)), 8) - 0x2000
    for number, (dll, functions) in enumerate(imports.items()):
        dll_name = allocate('dll:' + dll, dll.encode('ascii') + b'\0')
        names = [allocate('name:' + name, b'\0\0' + name.encode('ascii') + b'\0', 2) for name in functions]
        lookup = allocate('lookup:' + dll, b''.join(struct.pack('<Q', value) for value in names) + b'\0' * 8, 8)
        iat = allocate('iat:' + dll, b''.join(struct.pack('<Q', value) for value in names) + b'\0' * 8, 8)
        for index, name in enumerate(functions):
            symbols['call:' + name] = iat + index * 8
        struct.pack_into('<5I', data, descriptors + number * 20, lookup, 0, 0, dll_name, iat)

    code = bytearray()
    labels, patches = {}, []

    def emit(hexadecimal):
        code.extend(bytes.fromhex(hexadecimal))

    def relative(opcode, symbol, extra=0):
        emit(opcode)
        patches.append((len(code), symbol, extra))
        code.extend(b'\0' * 4)

    def stack(offset, value):
        emit('48 c7 44 24')
        code.append(offset)
        code.extend(struct.pack('<I', value & 0xffffffff))

    def call(name):
        relative('ff 15', 'call:' + name)

    def fail_if(opcode, label):
        relative(opcode, label)

    emit('48 81 ec 88 00 00 00')  # Win64 alignment, shadow space and stack arguments.
    emit('31 c9')
    relative('48 8d 15', 'class')
    relative('4c 8d 05', 'title')
    emit('41 b9 00 00 cf 00')
    for offset, value in [(32, 0), (40, 0), (48, 320), (56, 240), (64, 0), (72, 0), (80, 0), (88, 0)]:
        stack(offset, value)
    call('CreateWindowExA')
    emit('48 85 c0'); fail_if('0f 84', 'fail10')
    emit('49 89 c4')  # r12 = HWND, nonvolatile across Win32 calls.
    emit('4c 89 e1 ba 01 00 00 00'); call('ShowWindow')
    emit('4c 89 e1'); call('UpdateWindow')
    emit('b9 20 00 00 00'); call('Direct3DCreate9')
    emit('48 85 c0'); fail_if('0f 84', 'fail11')
    emit('48 89 c3 4c 89 e0')
    relative('48 89 05', 'present', 32)
    emit('48 89 d9 31 d2 41 b8 01 00 00 00 4d 89 e1')
    stack(32, 0x20)  # D3DCREATE_SOFTWARE_VERTEXPROCESSING.
    relative('48 8d 05', 'present'); emit('48 89 44 24 28')
    relative('48 8d 05', 'device'); emit('48 89 44 24 30')
    emit('48 8b 03 ff 90 80 00 00 00')  # IDirect3D9::CreateDevice, slot 16.
    emit('85 c0'); fail_if('0f 88', 'fail12')
    relative('4c 8b 2d', 'device')
    emit('4c 89 e9 31 d2 45 31 c0 41 b9 01 00 00 00')
    stack(32, 0xff00aa88); stack(40, 0x3f800000); stack(48, 0)
    emit('49 8b 45 00 ff 90 58 01 00 00')  # Device::Clear, slot 43.
    emit('85 c0'); fail_if('0f 88', 'fail13')
    emit('4c 89 e9 31 d2 45 31 c0 45 31 c9'); stack(32, 0)
    emit('49 8b 45 00 ff 90 88 00 00 00')  # Device::Present, slot 17.
    emit('85 c0'); fail_if('0f 88', 'fail14')
    emit('4c 89 e9 49 8b 45 00 ff 50 10')  # Release device.
    emit('48 89 d9 48 8b 03 ff 50 10')  # Release D3D9.
    emit('4c 89 e1'); call('DestroyWindow')
    emit('b9 f5 ff ff ff'); call('GetStdHandle')
    emit('48 89 c1'); relative('48 8d 15', 'marker')
    emit('41 b8'); code.extend(struct.pack('<I', len(marker)))
    relative('4c 8d 0d', 'written'); stack(32, 0); call('WriteFile')
    emit('31 c9'); call('ExitProcess')
    for status in range(10, 15):
        labels['fail' + str(status)] = 0x1000 + len(code)
        emit('b9'); code.extend(struct.pack('<I', status)); call('ExitProcess')
    for offset, symbol, extra in patches:
        target = (symbols | labels)[symbol] + extra
        struct.pack_into('<i', code, offset, target - (0x1000 + offset + 4))

    if len(code) > 4096: raise ValueError('Probe code exceeds the fixed PE text section address range')
    text_size, data_size = align(len(code), 512), align(len(data), 512)
    header = bytearray(512); header[:2] = b'MZ'; struct.pack_into('<I', header, 0x3c, 0x80)
    header[0x80:0x84] = b'PE\0\0'
    struct.pack_into('<HHIIIHH', header, 0x84, 0x8664, 2, 0, 0, 0, 240, 0x22)
    optional = 0x98
    struct.pack_into('<HBBIIIIIQII', header, optional, 0x20b, 0, 0, text_size, data_size, 0, 0x1000, 0x1000, 0x140000000, 4096, 512)
    struct.pack_into('<6H', header, optional + 40, 6, 1, 1, 0, 6, 1)
    struct.pack_into('<IIIIHH', header, optional + 52, 0, align(0x2000 + len(data), 4096), 512, 0, 3, 0x100)
    struct.pack_into('<QQQQII', header, optional + 72, 0x100000, 0x1000, 0x100000, 0x1000, 0, 16)
    struct.pack_into('<II', header, optional + 112 + 8, symbols['imports'], 20 * (len(imports) + 1))
    sections = optional + 240
    struct.pack_into('<8sIIIIIIHHI', header, sections, b'.text', len(code), 0x1000, text_size, 512, 0, 0, 0, 0, 0x60000020)
    struct.pack_into('<8sIIIIIIHHI', header, sections + 40, b'.data', len(data), 0x2000, data_size, 512 + text_size, 0, 0, 0, 0, 0xc0000040)
    return bytes(header + code + b'\0' * (text_size - len(code)) + data + b'\0' * (data_size - len(data)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--output', type=Path, default=Path('.local/probes/d3d9-probe.exe')); args = parser.parse_args()
    payload = build(); args.output.parent.mkdir(parents=True, exist_ok=True); args.output.write_bytes(payload)
    print(json.dumps({'path': str(args.output.resolve()), 'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest()}))
