"""Check the static reader against independently executed ALIS instructions."""
import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("alis_disasm", ROOT / "tools/alis_disasm.py")
DECODER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DECODER)


class RuntimeOracleTests(unittest.TestCase):
    def test_time_reader_matches_every_observed_instruction(self):
        private = ROOT / "reference-private"
        trace = private / "trace-index.json"
        binary = private / "unpacked/time.alis"
        if not trace.exists() or not binary.exists():
            self.skipTest("local original-data observation corpus is unavailable")
        # source: runtime.trace load record at lines 1227151-1227152;
        # independently matches TIME's bytes in the F11 RAM observation.
        time_base = 0x33B98
        data = binary.read_bytes()
        result = DECODER.disassemble(data, 0x18, len(data), reachable=True)
        self.assertEqual(result["errors"], [])
        self.assertFalse(result.get("truncated", False))
        by_offset = {item["offset"]: item for item in result["instructions"]}
        all_variants = json.loads(trace.read_text())["variants"]
        variants = [item for item in all_variants if item["script"] == "time.co"]
        self.assertTrue(variants, "an empty trace must not pass as verification")
        for item in variants:
            offset = int(item["opcode_address"], 16) - time_base
            with self.subTest(offset=hex(offset)):
                self.assertIn(offset, by_offset)
                self.assertEqual(by_offset[offset]["code"], int(item["opcode"], 16))
                self.assertEqual(by_offset[offset]["name"], item["name"])


if __name__ == "__main__":
    unittest.main()
