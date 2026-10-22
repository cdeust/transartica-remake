# SPDX-License-Identifier: MIT
"""Load samples through original T.X Fibonacci decoder, without host invdigit.

Original routine hunk0:0xdee..0xef2 only processes types1/2; music type4 is
unchanged. Slot mapping follows each original script's cinstru instructions.
"""
import hashlib
from amiga_binary import HUNK_BASES
from extract_score import resource_offset

SCRIPT_RAM, TEMP_POINTERS, TEMP_PLANES = 0x500000, 0x700000, 0x710000


def source_slot(cue, slot):
    # Exact original cinstru loops at byte24 onward, plus BOLOST byte37.
    script = cue.split('-')[0]
    if script == 'bojeu':
        return script, slot if slot <= 12 else 0
    if script == 'bojeu2':
        return script, slot if slot <= 13 else 1
    if script in ('bolieu', 'bolost'):
        if script == 'bolost' and slot == 10:
            return 'bolost', 1
        return 'bolieu', slot if slot <= 9 else 0
    if script == 'bopres':
        return script, slot if 2 <= slot <= 12 else 1
    raise ValueError('Unknown original instrument script')


def decode_bank(player, source, script):
    raw = (source / 'unpacked' / (script + '.alis')).read_bytes()
    packed = (source / 'game-data' / (script + '.co')).read_bytes()
    memory = player.mem
    memory.w_block(SCRIPT_RAM, raw)
    # Addresses are decoded relocated operands in original instructions.
    flag_address = memory.r32(HUNK_BASES[0] + 0xdf2)
    temporary_variable = memory.r32(HUNK_BASES[0] + 0xe46)
    memory.w8(flag_address, int.from_bytes(packed[4:6], 'big') & 1)
    memory.w32(temporary_variable, TEMP_POINTERS)
    for plane in range(16):  # Harness capacity; original decoder decides usage.
        memory.w32(TEMP_POINTERS + plane * 4, TEMP_PLANES + plane * 65536)
    player.cpu.w_reg(player.register.A1, SCRIPT_RAM)
    player.call(HUNK_BASES[0] + 0xdee, cycles=100_000_000)
    table = int.from_bytes(raw[14:18], 'big')
    count = int.from_bytes(raw[table + 16:table + 18], 'big')
    result = {}
    for index in range(count):
        offset = resource_offset(raw, index)
        if raw[offset] != 2:
            continue
        length = memory.r32(SCRIPT_RAM + offset + 2)
        result[index] = bytes(memory.r_block(SCRIPT_RAM + offset, length))
    return result


def reconstruct(player, source, capture, cue):
    banks, instruments, blobs = {}, {}, {}
    for slot, host in player.instruments.items():
        name, index = source_slot(cue, slot)
        if name not in banks:
            banks[name] = decode_bank(player, source, name)
        blob = banks[name][index]
        previous = (capture / 'samples' / host['resource_file']).read_bytes()
        if hashlib.sha256(previous).hexdigest() != host['sha256']:
            raise ValueError('Captured instrument SHA mismatch')
        if hashlib.sha256(previous[16:]).hexdigest() != host['payload_sha256']:
            raise ValueError('Captured instrument payload SHA mismatch')
        # Independently verify cinstru mapping against the known host payload,
        # accounting only for its documented zero->1 conversion. Tail mutations
        # from host invdigit are excluded; no original byte is changed here.
        loop_end = int.from_bytes(blob[12:16], 'big')
        prefix = min(1024, (loop_end or len(blob) - 16) - 32)
        normalized = bytes(value or 1 for value in blob[16:16 + prefix])
        if prefix <= 0 or normalized != previous[16:16 + prefix]:
            raise ValueError(f'Original cinstru mapping differs: {cue} slot {slot}')
        item = dict(host, resource_bytes=len(blob), pcm_bytes=len(blob) - 16,
                    header_hex=blob[:16].hex(), sha256=hashlib.sha256(blob).hexdigest(),
                    payload_sha256=hashlib.sha256(blob[16:]).hexdigest(),
                    host_reader_sha256=host['sha256'], host_payload_sha256=host['payload_sha256'],
                    original_script=name, original_resource=index,
                    source_loop_start_field=int.from_bytes(blob[8:12], 'big'),
                    source_loop_end_field=loop_end,
                    decoder='original T.X hunk0:0xdee..0xef2',
                    mapping_compared_prefix_bytes=prefix)
        instruments[slot] = item
        blobs[slot] = blob
    return instruments, blobs
