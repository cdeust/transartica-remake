# SPDX-License-Identifier: MIT
"""Read the pinned original executable without modifying or publishing it.

Evidence: AMIGA_PLAYER.md, disk1.adf OFS header1148 and four T.X load hunks.
"""
import hashlib
import struct

TX_SHA256 = '741f28adae86c8954cfeb90de6f9ba8f64f98abadb4eafab1d018381b4505071'
# Harness allocation only; offsets inside each hunk remain original.
HUNK_BASES = (0x10000, 0x20000, 0x30000, 0x40000)


def read_executable(disk):
    data = disk.read_bytes()
    if data[:4] != b'DOS\0':
        raise ValueError('Expected original OFS disk')
    header = data[1148 * 512:1149 * 512]
    if header[432:436] != b'\x03T.X':
        raise ValueError('Original executable directory entry changed')
    length = int.from_bytes(header[324:328], 'big')
    block = int.from_bytes(header[16:20], 'big')
    result = bytearray()
    visited = set()
    while block:
        if block in visited:
            raise ValueError('Cyclic OFS data chain')
        visited.add(block)
        record = data[block * 512:(block + 1) * 512]
        if len(record) != 512:
            raise ValueError('OFS block outside disk')
        kind, owner, sequence, count, block, _ = struct.unpack('>6I', record[:24])
        if kind != 8 or owner != 1148 or sequence != len(visited) or count > 488:
            raise ValueError('Invalid original OFS data block')
        result.extend(record[24:24 + count])
    if len(result) != length or hashlib.sha256(result).hexdigest() != TX_SHA256:
        raise ValueError('Original executable SHA mismatch')
    return bytes(result)


def load_hunks(data, memory):
    if hashlib.sha256(data).hexdigest() != TX_SHA256:
        raise ValueError('Refuse unreviewed executable')
    at, hunk = 36, 0  # Verified four-hunk T.X header.
    while at < len(data):
        kind = int.from_bytes(data[at:at + 4], 'big') & 0x3fffffff
        at += 4
        if kind in (1001, 1002):  # HUNK_CODE, HUNK_DATA
            size = int.from_bytes(data[at:at + 4], 'big') * 4
            at += 4
            memory.w_block(HUNK_BASES[hunk], data[at:at + size])
            at += size
        elif kind == 1004:  # HUNK_RELOC32
            at = _relocations(data, memory, at, hunk)
        elif kind == 1010:  # HUNK_END
            hunk += 1
        else:
            raise ValueError(f'Unexpected pinned hunk record: {kind}')
    if hunk != 4:
        raise ValueError('Expected four original hunks')


def _relocations(data, memory, at, hunk):
    while True:
        count = int.from_bytes(data[at:at + 4], 'big')
        at += 4
        if not count:
            return at
        target = int.from_bytes(data[at:at + 4], 'big')
        at += 4
        for _ in range(count):
            offset = int.from_bytes(data[at:at + 4], 'big')
            at += 4
            address = HUNK_BASES[hunk] + offset
            memory.w32(address, memory.r32(address) + HUNK_BASES[target])
