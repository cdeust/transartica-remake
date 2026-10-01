"""Source-grounded operand boundaries and actual unpacked-script anchors."""

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('alis_disasm', ROOT / 'tools/alis_disasm.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def load_tests(loader, standard_tests, pattern):
    """Include function tests in the project's stdlib discovery command."""
    functions = sorted(
        (name, value) for name, value in globals().items()
        if name.startswith('test_') and callable(value)
    )
    return unittest.TestSuite(unittest.FunctionTestCase(test) for _, test in functions)


def test_source_dispatch_and_real_prefixes():
    tables = module.source_tables()
    assert tables['opcode'][0x29] == 'cdim'
    assert tables['opcode'][0x2f] == 'cswitch2'
    assert tables['oper'][0x38] == 'oeval'
    usine = (ROOT / 'reference-private/unpacked/usine.alis').read_bytes()
    result = module.disassemble(usine, 0x18, 20, reachable=True)
    by_offset = {entry['offset']: entry for entry in result['instructions']}
    assert by_offset[0x18]['targets'] == [0x54]
    assert by_offset[0x60]['end'] == 0x65
    assert by_offset[0x6e]['name'] == 'ctopalet'
    ville = (ROOT / 'reference-private/unpacked/ville.alis').read_bytes()
    result = module.disassemble(ville, 0x18, 30, reachable=True)
    by_offset = {entry['offset']: entry for entry in result['instructions']}
    assert by_offset[0x18]['end'] == 0x1f
    assert by_offset[0x29]['targets'] == [0x3c, 0x4a, 0x62, 0x58]
    assert by_offset[0x74]['name'] == 'csleep'


def test_cdim_22_and_fail_closed():
    tables = module.source_tables()
    # opcodes.c cdim reads s16 offset, u8 count, u8 value, then count s16 words.
    data = bytes.fromhex('29 00 76 01 01 00 49 42')
    result = module.disassemble(data, 0, 2)
    assert result['instructions'][0]['args'] == [118, 1, 1, 73]
    assert result['instructions'][0]['end'] == 7
    assert result['instructions'][1]['name'] == 'cstop'
    result = module.disassemble(bytes.fromhex('29 00 76 01 01 00'), 0, 1)
    assert result['instructions'] == []
    assert 'truncated' in result['errors'][0]['error']
    result = module.disassemble(bytes.fromhex('ff'), 0, 1)
    assert result['errors']
    main = (ROOT / 'reference-private/unpacked/main.alis').read_bytes()
    first = module.disassemble(main, 0x18, 1)['instructions'][0]
    assert first['name'] == 'cdim' and first['end'] == 0x1f


def test_relative_jump_and_nested_expression():
    tables = module.source_tables()
    jump = module.disassemble(bytes.fromhex('0a ff ff fc 42'), 0, 2)
    assert jump['instructions'][0]['targets'] == [0]
    assert jump['instructions'][0]['end'] == 4
    expr = module.disassemble(bytes.fromhex('1f 38 00 05 4c 00 05 3a 42'), 0, 2)
    assert expr['instructions'][0]['end'] == 8
    assert expr['instructions'][0]['args'][0]['args'][-1]['name'] == 'ofin'


def test_clive_transitive_store_operand():
    # opcodes.c clive -> clivin reads s16 ID then cstore_continue.
    time = (ROOT / 'reference-private/unpacked/time.alis').read_bytes()
    result = module.disassemble(time, 0x470, 3)
    first = result['instructions'][0]
    assert first['name'] == 'clive' and first['end'] == 0x475
    assert first['args'][0] == 32
    assert first['args'][1]['name'] == 'sdirw'
    assert result['instructions'][1]['offset'] == 0x475


def test_time_entry_reachable_boundaries():
    time = (ROOT / 'reference-private/unpacked/time.alis').read_bytes()
    result = module.disassemble(time, 0x18, 5000, reachable=True)
    by_offset = {entry['offset']: entry for entry in result['instructions']}
    assert len(by_offset) == 1218
    assert result['errors'] == []
    assert by_offset[0x180]['name'] == 'csend'
    assert by_offset[0x470]['end'] == 0x475
    short = module.disassemble(time, 0x18, 1, reachable=True)
    assert short['truncated'] and short['pending_offsets'] == [0x25]


def test_text2k_entry_reachable_boundaries():
    text2k = (ROOT / 'reference-private/unpacked/texte2k.alis').read_bytes()
    result = module.disassemble(text2k, 0x18, 5000, reachable=True)
    by_offset = {entry['offset']: entry for entry in result['instructions']}
    assert len(by_offset) == 608
    assert result['errors'] == [] and not result['truncated']
    assert by_offset[0x22]['name'] == 'cfindcla'
    assert by_offset[0x2676]['name'] == 'cerasen'


def test_yoda_and_textek_reachable_boundaries():
    for name, expected in (('yoda', 1510), ('textek', 1929)):
        data = (ROOT / f'reference-private/unpacked/{name}.alis').read_bytes()
        result = module.disassemble(data, 0x18, 5000, reachable=True)
        assert len(result['instructions']) == expected
        assert result['errors'] == [] and not result['truncated']


def test_carte_map_layout_and_reachability():
    carte = (ROOT / 'reference-private/unpacked/carte.alis').read_bytes()
    result = module.disassemble(carte, 0x18, 5000, reachable=True)
    by_offset = {entry['offset']: entry for entry in result['instructions']}
    assert len(by_offset) == 1486
    assert result['errors'] == [] and not result['truncated']
    assert by_offset[0x128]['name'] == 'cdefmap'
    assert by_offset[0x13d]['name'] == 'csetmap'
    assert by_offset[0x13d]['end'] == 0x151
    assert by_offset[0x86a]['name'] == 'cputmap'
    assert by_offset[0x12f0]['name'] == 'cputnat'


def test_header_entries_and_resource_boundary():
    # alis.c: interrupt handler at header+10+s32, post-tick at header+6+s32;
    # adresdes: resources at header+0x0e+s32. ville code ends at 0x76.
    ville = (ROOT / 'reference-private/unpacked/ville.alis').read_bytes()
    header = module.header_entries(ville)
    assert header == {'entries': [0x18], 'resources': 0x76}
    result = module.disassemble(ville, 0x18, 1000, reachable=True)
    assert max(i['end'] for i in result['instructions']) == 0x76
    usine = (ROOT / 'reference-private/unpacked/usine.alis').read_bytes()
    assert module.header_entries(usine)['entries'] == [0x18, 0x1c]


def test_file_opcodes_from_main():
    # opcodes.c cfopen: C string + u16 mode; cfreadb (< v30): s16 addr + u16 length.
    main = (ROOT / 'reference-private/unpacked/main.alis').read_bytes()
    result = module.disassemble(main, 0x78d, 3)
    names = [i['name'] for i in result['instructions']]
    assert names == ['cfopen', 'cfreadb', 'cfclose']
    assert result['instructions'][0]['args'] == ['ville.fic', 2]
    assert result['instructions'][1]['args'] == [0x5fe4, 0x8a]


def test_campaign_sound_and_effect_paths_are_reachable():
    # opcodes.c3340 sound consumes five expressions; ccancall4430 consumes none.
    data = bytes.fromhex('9d 00 00 00 64 00 7f 00 02 00 08 dc 42')
    result = module.disassemble(data, 0, 3)
    assert result['errors'] == []
    assert [i['end'] for i in result['instructions']] == [11, 12, 13]
    scene = (ROOT / 'reference-private/unpacked/scene3.alis').read_bytes()
    result = module.disassemble(scene, 0x18, 1000, reachable=True)
    by_offset = {i['offset']: i for i in result['instructions']}
    assert result['errors'] == []
    assert by_offset[0x102]['args'][1]['args'] == [0x64f5]
    assert by_offset[0x10d]['args'][0]['args'] == [86]
    assert by_offset[0x131]['args'][0]['args'] == [87]
    ending = (ROOT / 'reference-private/unpacked/ifebo.alis').read_bytes()
    result = module.disassemble(ending, 0x18, 1000, reachable=True)
    assert result['errors'] == []
    assert any(i['offset'] == 0x127 and i['name'] == 'cerasen' for i in result['instructions'])


def test_bopres_music_operands_and_termination():
    # opcodes.c music type4 (<v30 ECS) reads index and five envelope fields.
    data = (ROOT / 'reference-private/unpacked/bopres.alis').read_bytes()
    result = module.disassemble(data, 0x18, 1000, reachable=True)
    assert result['errors'] == []
    by_offset = {item['offset']: item for item in result['instructions']}
    assert [item['args'][0] for item in by_offset[0xc8]['args']] == [0, 127, 32, 20, 10000, 100]
    assert by_offset[0xc8]['end'] == 0xd6
    assert by_offset[0xd6]['name'] == 'csleep'


def test_audio_scene_linking_and_machine_information():
    # Primary source opcodes.c2879 clinking reads exactly one expression;
    # opernames.c854 omip reads no operand and returns host MIPS information.
    instruction = module.disassemble(bytes.fromhex('83 00 01 42'), 0, 2)
    assert instruction['errors'] == []
    assert instruction['instructions'][0]['name'] == 'clinking'
    assert instruction['instructions'][0]['end'] == 3
    assert instruction['instructions'][1]['name'] == 'cstop'
    value = module.disassemble(bytes.fromhex('1f a4 42'), 0, 2)
    assert value['errors'] == []
    assert value['instructions'][0]['args'][0]['name'] == 'omip'
    assert value['instructions'][0]['end'] == 2
    for script in ('train', 'wdecor'):
        data = (ROOT / f'reference-private/unpacked/{script}.alis').read_bytes()
        reader = module.Reader(data, module.source_tables())
        for entry in module.header_entries(data)['entries']:
            decoded = module.walk(reader, entry, 20000, True)
            assert decoded['errors'] == [] and not decoded['truncated']
