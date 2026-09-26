import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("decode_cities", ROOT / "tools" / "decode_cities.py")
decode_cities = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = decode_cities
SPEC.loader.exec_module(decode_cities)


def _is_checked_non_tibesti(record):
    return bool(record["guide_check"]) and record["game_name"] != "TIBESTI"


class DecodeCitiesTests(unittest.TestCase):
    def test_triplet_decoder_preserves_raw_values_and_sign_extends_field0(self):
        rows = decode_cities.decode_records(bytes([0xDE, 53, 5, 9, 70, 2, 1, 2, 0xFE]))
        self.assertEqual(rows[0], {"index": 0, "field0_raw": 0xDE, "field0_signed": -34,
                                   "field1": 53, "field2_raw": 5, "field2_abs": 5})
        self.assertEqual(rows[1]["field0_signed"], 9)
        self.assertEqual(rows[1]["field2_abs"], 2)
        self.assertEqual((rows[2]["field2_raw"], rows[2]["field2_abs"]), (0xFE, 2))
        with self.assertRaisesRegex(ValueError, "not divisible"):
            decode_cities.decode_records(b"short")

    def test_real_alis_switches_extract_names_categories_and_footprint_offsets(self):
        textek = ROOT / "reference-private" / "unpacked" / "textek.alis"
        time_script = ROOT / "reference-private" / "unpacked" / "time.alis"
        if not textek.exists() or not time_script.exists():
            self.skipTest("private unpacked ALIS observations are unavailable")
        names, categories, evidence = decode_cities.extract_text_tables(textek)
        self.assertEqual(len(names), 46)
        self.assertEqual(names[0], "CASABLANCA")
        self.assertEqual(names[43], "TIBESTI")
        self.assertEqual(names[45], "TRIBE OF NOMADS")
        self.assertEqual(categories, ["TOWN", "COMMERCIAL CROSSROADS", "INDUSTRIAL TOWN",
                                      "GARRISON TOWN", "MAMMOTH FAIR", "SLAVE MARKET"])
        self.assertEqual(evidence["city_name_switch_offset"], "0x3bc0")
        self.assertEqual(evidence["category_switch_offset"], "0x3b09")
        self.assertEqual(decode_cities._footprint_offsets(time_script),
                         {71: (2, 1), 72: (1, 1), 73: (0, 1),
                          74: (2, 0), 75: (1, 0), 76: (0, 0)})

    def test_independent_guide_matches_43_records_and_keeps_tibesti_unresolved(self):
        ville = ROOT / "reference-private" / "VILLE.FIC"
        carte = ROOT / "reference-private" / "CARTE.FIC"
        textek = ROOT / "reference-private" / "unpacked" / "textek.alis"
        time_script = ROOT / "reference-private" / "unpacked" / "time.alis"
        cities = ROOT / "data" / "villes.csv"
        if not all(p.exists() for p in (ville, carte, textek, time_script, cities)):
            self.skipTest("private FIC/ALIS observations or independent guide are unavailable")
        paths = decode_cities.SourcePaths(ville, carte, textek, time_script, cities)
        result = decode_cities.decode(paths)
        self.assertEqual((result["record_count"], result["guide_count"],
                          result["guide_anchor_match_count"]), (46, 44, 43))
        self.assertEqual(result["unmatched_guide_records"][0]["game_name"], "TIBESTI")
        tibesti = result["records"][43]
        self.assertEqual((tibesti["anchor_x"], tibesti["anchor_y"]), (49, 70))
        self.assertEqual(tibesti["guide_check"]["map_code_at_guide"], 0)
        self.assertEqual(tibesti["guide_check"]["record_anchor_map_code"], 76)
        self.assertEqual([r["game_name"] for r in result["records"] if r["oracle_name"] is None],
                         ["ALEXANDRIA", "TRIBE OF NOMADS"])
        non_tibesti_checked = [r for r in result["records"] if _is_checked_non_tibesti(r)]
        self.assertEqual(len(non_tibesti_checked), 43)
        self.assertEqual({r["guide_check"]["status"] for r in non_tibesti_checked}, {"anchor_match"})


if __name__ == "__main__":
    unittest.main()
