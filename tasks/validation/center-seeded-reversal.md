# Center-seeded reversal regression

Actual TABLE-start campaign shopping reaches Gdansk, then the Berlin leg resumes after works. A manual reversal at a trailing switch can leave two possible incoming ports. TrainPath.incoming_for correctly returns zero rather than inventing an entry path, and TrainJourney already treats that as a center entry in _entry_position and _logical_fractional_position. _advance_render incorrectly indexed DELTAS[0] and emitted repeated native script errors.

The narrow fix assigns no length to the unknown incoming half and measures the existing outgoing half. Movement phases, logical heading and stored rail history stay intact.

Native test_reverser_center uses source switch18 and the original start through reverse_direction; its two incoming choices produce zero without assigning an incoming heading. Before the fix it exits1 with two Dictionary index0 errors and fails the cursor-distance assertion. After the fix it exits0 with no errors, advances by the known outgoing half, and replays identically after snapshot restore. Existing test_reverser also passes its source phases, convoy continuity, repeated reversal and persistence checks.
