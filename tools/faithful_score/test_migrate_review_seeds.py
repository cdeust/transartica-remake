"""MIT. A seed migration cannot conceal unrelated changed sample bytes."""
import unittest

from migrate_review_seeds import compare_payloads


class MigrationTests(unittest.TestCase):
    def test_only_documented_zero_substitution_and_suffix_are_allowed(self):
        result = compare_payloads(bytes([1, 2, 3, 1]), bytes([0, 2, 3, 1, 4, 5]))
        self.assertEqual(result['host_zero_to_one_bytes'], 1)
        self.assertEqual(result['original_suffix_bytes'], 2)
        self.assertNotEqual(result['old_pcm_sha256'], result['new_pcm_sha256'])

    def test_unrelated_changed_byte_is_refused(self):
        with self.assertRaisesRegex(ValueError, 'unexplained PCM difference'):
            compare_payloads(bytes([1, 2, 3]), bytes([0, 4, 3]))

    def test_truncating_original_is_refused(self):
        with self.assertRaisesRegex(ValueError, 'shorter'):
            compare_payloads(bytes([1, 2, 3]), bytes([0, 2]))

    def test_uncompared_host_tail_is_explicit_not_claimed_equal(self):
        result = compare_payloads(bytes([1, 2, 99]), bytes([0, 2, 77, 4]), 2)
        self.assertEqual(result['common_prefix_bytes'], 2)
        self.assertEqual(result['host_uncompared_suffix_bytes'], 1)
        self.assertEqual(result['original_uncompared_suffix_bytes'], 2)


if __name__ == '__main__':
    unittest.main()
