#!/usr/bin/env python3
"""Bounded ALIS 2.2 disassembly, grounded in the pinned ALIS source tables.

Addresses are offsets in the supplied unpacked script, never VM trace addresses.
Unsupported layouts terminate a path explicitly; this tool does not execute ALIS.
"""

import argparse
import json
import re
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / 'reference-private/alis-source/src'
TABLE_FILES = {'opcode': 'opcodes.c', 'oper': 'opernames.c',
               'store': 'storenames.c', 'add': 'addnames.c'}
TABLE_NAMES = {'opcode': 'opcodes', 'oper': 'opernames',
               'store': 'storenames', 'add': 'addnames'}


class DecodeError(ValueError):
    """An unsupported opcode or truncated operand at a known address."""


def source_tables(source=SOURCE):
    """Read dispatch IDs directly from the authoritative DECL_OPCODE arrays."""
    tables = {}
    for kind, filename in TABLE_FILES.items():
        body = (source / filename).read_text()
        anchor = re.search(r'sAlisOpcode\s+' + TABLE_NAMES[kind] + r'\[\]\s*=\s*\{', body)
        if anchor is None:
            raise DecodeError(f'missing {kind} source table in {filename}')
        body = body[anchor.end():body.index('};', anchor.end())]
        pairs = re.findall(r'DECL_OPCODE\(0x([0-9a-fA-F]+),\s*(\w+)', body)
        tables[kind] = {int(code, 16): name for code, name in pairs}
    return tables


class Reader:
    def __init__(self, data, tables):
        self.data, self.tables, self.pc = data, tables, 0

    def number(self, size, signed=False):
        start = self.pc
        self.pc += size
        if self.pc > len(self.data):
            raise DecodeError(f'truncated {size}-byte operand at {start:#x}')
        return int.from_bytes(self.data[start:self.pc], 'big', signed=signed)

    def cstring(self):
        end = self.data.find(b'\0', self.pc)
        if end < 0:
            raise DecodeError(f'unterminated string at {self.pc:#x}')
        value = self.data[self.pc:end].decode('latin-1')
        self.pc = end + 1
        return value

    def eval_sequence(self, args, depth):
        while True:
            child = self.nested('oper', depth + 1)
            args.append(child)
            if child['code'] == 0x3a:
                return

    def nested(self, kind, depth=0):
        if depth > 24:
            raise DecodeError(f'nested {kind} depth exceeded at {self.pc:#x}')
        offset = self.pc
        code = self.number(1)
        name = self.tables[kind].get(code)
        if not name or name == 'pnul':
            raise DecodeError(f'unsupported {kind} {code:#04x} at {offset:#x}')
        args = []
        if kind == 'oper' and code == 0x04:
            args.append(self.cstring())
        elif kind == 'oper' and code in (0x00, 0x02):
            args.append(self.number(1 if code == 0 else 2, signed=True))
        elif 0x06 <= code <= 0x28 and code % 2 == 0:
            args.append(self.number(1 if 0x12 <= code <= 0x1c else 2, signed=not 0x12 <= code <= 0x1c))
        elif 0x2a <= code <= 0x2e and code % 2 == 0:
            args.extend((self.number(2, signed=True), self.number(2, signed=True)))
        elif code in (0x36, 0x3a, 0x40, 0x60, 0x62, 0x64, 0x66, 0x68,
                      0x6a, 0x72, 0x74, 0x76, 0x78, 0x7a, 0x82, 0x84, 0x86, 0x96, 0x98,
                      0x9c, 0x9e, 0xa0, 0xa2, 0xa4, 0xa8):
            pass
        elif kind == 'oper' and code == 0x88:
            args.append(self.nested('oper', depth + 1))
        elif kind == 'oper' and code == 0x8a:
            args.append(self.nested('oper', depth + 1))
        elif kind == 'oper' and code == 0x8c:
            args.extend((self.nested('oper', depth + 1),
                         self.nested('oper', depth + 1)))
        elif kind == 'oper' and code == 0x38:
            self.eval_sequence(args, depth)
        elif kind == 'oper' and code in range(0x42, 0x60, 2):
            args.append(self.nested('oper', depth + 1))
        elif kind in ('store', 'add') and code == 0x38:
            self.eval_sequence(args, depth)
            args.append(self.nested(kind, depth + 1))
        else:
            raise DecodeError(f'unsupported {kind} {name} at {offset:#x}')
        return {'offset': offset, 'code': code, 'name': name, 'args': args}

    def relative(self, code, args, targets):
        if code == 0x11:
            return 'return'
        size = (code - 0x05) % 3 + 1 if code <= 0x0a else (code - 0x12) % 3 + 1
        delta = self.number(size, signed=True)
        args.append(delta)
        targets.append(self.pc + delta)
        return 'call' if code <= 0x07 else 'jump' if code <= 0x0a else 'branch'

    def start(self, code, args, targets):
        delta = self.number(code - 0x30 + 1, signed=True)
        args.append(delta)
        targets.append(self.pc + delta)
        return 'branch'  # cstart differs by fseq; preserve both paths.

    def loop(self, code, args, targets):
        delta = self.number(code - 0x2b + 1, signed=True)
        branch_base = self.pc  # opcodes.c cloop saves PC before addname.
        args.extend((delta, self.nested('add')))
        targets.append(branch_base + delta)
        return 'branch'

    def switch2(self, args, targets):
        args.append(self.nested('oper'))
        maximum = self.number(1)
        if self.pc & 1:
            self.number(1)  # opcodes.c cswitch2 aligns the table to even PC.
        base = self.number(2, signed=True)
        args.extend((maximum, base))
        for _ in range(maximum + 1):
            delta = self.number(2, signed=True)
            targets.append(self.pc + delta)

    def switch1(self, args, targets):
        args.append(self.nested('oper'))
        maximum = self.number(1)
        if self.pc & 1:
            self.number(1)
        args.append(maximum)
        for _ in range(maximum + 1):
            test = self.number(2, signed=True)
            delta = self.number(2, signed=True)
            args.append(test)
            targets.append(self.pc + delta)

    def variable(self, code, args, targets):
        if code == 0x29:
            args.extend((self.number(2, signed=True), self.number(1), self.number(1)))
            args.extend(self.number(2, signed=True) for _ in range(args[1]))
        elif code == 0x25:
            args.append(self.cstring())
        elif code == 0x45:
            script_id = self.number(2)
            args.append(script_id)
            args.append(self.cstring() if script_id else self.nested('oper'))
        elif code == 0x61:
            length = self.number(1)
            args.append(length)
            # csend's first read, inner reads and fallback loop total length+2.
            args.extend(self.nested('oper') for _ in range(length + 2))
        elif code == 0x2f:
            self.switch2(args, targets)
        elif code == 0x2e:
            self.switch1(args, targets)
        elif code in (0x95, 0x97):
            # opcodes.c music(): resource index plus volume/tempo/attack/duration/fall.
            args.extend(self.nested('oper') for _ in range(6))

    def map_args(self, code, args):
        offset = self.number(2, signed=True)
        args.append(offset)
        if offset == 0:
            args.append(self.number(2, signed=True))
        count = {0xe3: 7, 0xe4: 6, 0xe5: 4}[code]
        args.extend(self.nested('oper') for _ in range(count))

    def indirect(self, code, args):
        if code == 0x40:
            args.append(self.number(2, signed=True))  # clive -> clivin
            args.append(self.nested('store'))  # clivin -> cstore_continue
        elif code == 0x46:
            args.extend((self.number(2, signed=True), self.number(1)))
            args.append(self.number(32).to_bytes(32, 'big').hex())  # ALIS 2.2
        elif code in (0x47, 0x4e, 0x4f):
            args.append(self.number(2))
        elif code == 0x3d:
            args.append(self.number(2, signed=True))
        elif code in (0x57, 0x60):
            args.append(self.nested('store'))
        elif code == 0x9c:
            args.append(self.nested('store'))  # clistent -> crstent
        elif code == 0x86:
            args.extend(self.nested('store') for _ in range(3))
        elif code == 0xca:
            args.extend((self.nested('oper'), self.nested('store')))
        elif code == 0x94:
            args.extend((self.number(2, signed=True), self.nested('store')))

    def file_io(self, code, args):
        # opcodes.c cfopen: 0xff marker -> two oper expressions, else C string + u16 mode.
        if code == 0x70:
            if self.data[self.pc:self.pc + 1] == b'\xff':
                self.number(1)
                args.extend((self.nested('oper'), self.nested('oper')))
            else:
                args.extend((self.cstring(), self.number(2)))
        elif code in (0x77, 0x78):
            # cfreadb/cfwriteb: s16 address (0 -> s16 main offset), then
            # s16 length for ALIS versions < 30 (script_read16 branch).
            address = self.number(2, signed=True)
            args.append(address)
            if address == 0:
                args.append(self.number(2, signed=True))
            args.append(self.number(2))
        elif code == 0x74:
            args.append(self.nested('store'))  # cfreadv -> cstore_continue
        elif code in (0x75, 0xcf):
            args.append(self.nested('oper'))  # cfwritev, cordspr

    def instruction(self, offset):
        self.pc = offset
        code = self.number(1)
        name = self.tables['opcode'].get(code)
        if not name or name == 'cnul':
            raise DecodeError(f'unsupported opcode {code:#04x} at {offset:#x}')
        args, targets, flow = [], [], 'next'
        if 0x05 <= code <= 0x1d and code not in range(0x0b, 0x11):
            flow = self.relative(code, args, targets)
        elif code in (0x25, 0x29, 0x2e, 0x2f, 0x45, 0x61, 0x95, 0x97):
            self.variable(code, args, targets)
            flow = 'switch' if code in (0x2e, 0x2f) else 'next'
        elif code in (0x1e, 0x20, 0x21):
            args.append(self.nested('oper'))
            args.append(self.nested('store' if code == 0x1e else 'add'))
        elif code in (0x27, 0xbe, 0xd8, 0xc0):
            args.extend((self.nested('oper'), self.nested('oper')))
        elif code in (0x4c, 0x4d, 0xcd):
            args.extend(self.nested('oper') for _ in range(3))
        elif code == 0xbf:
            args.extend(self.nested('oper') for _ in range(4))
        elif code in (0x49, 0xa7, 0xba, 0x9d, 0x9e):
            args.extend(self.nested('oper') for _ in range(5))
        elif code in (0x1f, 0x24, 0x26, 0x28, 0x2a, 0x34, 0x35, 0x36,
                      0x3e, 0x41, 0x48, 0x4b, 0x51, 0x6a, 0x7d,
                      0x68, 0x83, 0x96, 0xb8, 0xb9, 0xbc, 0xd7, 0xdd, 0xde):
            args.append(self.nested('oper'))
        elif code in (0x30, 0x31, 0x32):
            flow = self.start(code, args, targets)
        elif code in (0xe3, 0xe4, 0xe5):
            self.map_args(code, args)
        elif code in (0x2b, 0x2c, 0x2d):
            flow = self.loop(code, args, targets)
        elif code in (0x3d, 0x40, 0x46, 0x47, 0x4e, 0x4f, 0x57, 0x60,
                      0x86, 0x94, 0x9c, 0xca):
            self.indirect(code, args)
        elif code in (0x70, 0x71, 0x74, 0x75, 0x77, 0x78, 0xcf):
            self.file_io(code, args)
        elif code == 0x44:
            flow = 'return'
        elif code in (0x3f, 0x42):
            flow = 'suspend'  # cstop stops this VM tick; next PC remains reachable.
        elif code in (0x3b, 0x50, 0x52, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
                      0x84, 0x85, 0xa1, 0xdc):
            pass
        else:
            raise DecodeError(f'unsupported opcode {name} at {offset:#x}')
        return {'offset': offset, 'end': self.pc, 'code': code, 'name': name,
                'args': args, 'targets': targets, 'flow': flow}


def walk(reader, start, count, reachable=False):
    listing, errors = [], []
    pending, seen = [start], set()
    while pending and len(listing) < count:
        offset = pending.pop() if reachable else pending.pop(0)
        if offset in seen:
            continue
        seen.add(offset)
        try:
            insn = reader.instruction(offset)
        except (DecodeError, IndexError) as exc:
            errors.append({'offset': offset, 'error': str(exc)})
            if not reachable:
                break
            continue
        listing.append(insn)
        if reachable:
            if insn['flow'] in ('next', 'branch', 'call', 'suspend', 'switch'):
                pending.append(insn['end'])
            pending.extend(insn['targets'])
        elif insn['flow'] != 'return':
            pending.append(insn['end'])
    pending_offsets = sorted(set(pending) - seen)
    return {'instructions': listing, 'errors': errors,
            'truncated': bool(pending_offsets), 'pending_offsets': pending_offsets}


def header_entries(data):
    """Entry points from the script header (alis.c scheduler, alis.c adresdes).

    +0x06: s32 offset of the post-tick handler, run at header+6+offset.
    +0x0a: s32 offset of the interrupt/scan handler, run at header+10+offset.
    +0x0e: s32 offset of the resource table; code never extends past it.
    """
    word = lambda at: int.from_bytes(data[at:at + 4], 'big', signed=True)
    entries = [0x18]
    for field in (0x06, 0x0a):
        if word(field):
            entries.append(field + word(field))
    return {'entries': entries, 'resources': word(0x0e)}


def disassemble(data, start, count, reachable=False):
    return walk(Reader(data, source_tables()), start, count, reachable)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--start', type=lambda s: int(s, 0), default=0x18)
    parser.add_argument('--count', type=int, default=100)  # bounded CLI output
    parser.add_argument('--reachable', action='store_true')
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--all-entries', action='store_true',
                        help='walk every header entry point (implies --reachable)')
    parser.add_argument('--source', type=Path, default=SOURCE)
    args = parser.parse_args()
    data = args.file.read_bytes()
    reader = Reader(data, source_tables(args.source))
    if args.all_entries:
        header = header_entries(data)
        result = {'instructions': [], 'errors': [], 'pending_offsets': [],
                  'header': header}
        seen = set()
        for entry in header['entries']:
            part = walk(reader, entry, args.count, True)
            fresh = [i for i in part['instructions'] if i['offset'] not in seen]
            seen.update(i['offset'] for i in fresh)
            result['instructions'] += fresh
            result['errors'] += part['errors']
            result['pending_offsets'] += part['pending_offsets']
        result['truncated'] = bool(result['pending_offsets'])
    else:
        result = walk(reader, args.start, args.count, args.reachable)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        for item in result['instructions']:
            print(f"{item['offset']:06x}: {item['name']} {item['args']} -> {item['targets']}")
        for item in result['errors']:
            print(f"STOP {item['offset']:06x}: {item['error']}")
        if result['truncated']:
            print(f"TRUNCATED: {len(result['pending_offsets'])} pending offsets")


if __name__ == '__main__':
    main()
