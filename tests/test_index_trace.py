import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "index_trace", Path(__file__).resolve().parents[1] / "tools" / "index_trace.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TraceIndexTests(unittest.TestCase):
    def test_variants_retain_branch_outcomes_and_counts(self):
        # Format matches the observed ALIS trace; values are a parser fixture.
        taken = "main.co [000010]00000e: 14: cbz24 ### jump\n"
        untaken = "main.co [000010]00000e: 14: cbz24 ### no jump\n"
        result = MODULE.summarize([taken, untaken, taken])
        self.assertEqual(result["instruction_count"], 3)
        self.assertEqual(result["script_counts"], {"main.co": 3})
        self.assertEqual([v["count"] for v in result["variants"]], [2, 1])
        self.assertEqual(result["variants"][0]["last_line"], 3)

    def test_scheduler_separates_blocks_and_eof_flushes(self):
        lines = [
            "main.co [000010]00000e: 1e: cstore ###\n",
            "      --> [000011]00000f: 00: oimmb ### 0x01\n",
            " RUNNING carte.co [00, 01]\n",
            "      --> [000050]00004e: 00: orphan ###\n",
            "carte.co [000060]00005e: 42: cstop ###\n",
        ]
        blocks = list(MODULE.instruction_blocks(lines))
        self.assertEqual(len(blocks), 2)
        self.assertEqual(len(blocks[0]["details"]), 2)
        self.assertEqual(blocks[1]["line"], 5)
        self.assertEqual(blocks[1]["debug_file_address"], "000060")
        self.assertEqual(blocks[1]["pc_after_fetch"], "00005e")
        self.assertEqual(blocks[1]["opcode_address"], "00005d")


if __name__ == "__main__":
    unittest.main()
