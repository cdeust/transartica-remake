# Earned save endpoint restoration

The normal book rejected actual Turin11591 at12094 with "Journey save is invalid". Its saved render cursor exceeded the recomputed sum by about4e-14cells. The validator accepts only Godot4.5 approximate equality at that endpoint, then clamps the restored cursor to the recomputed path length. Non-numeric, non-finite and excessive values still fail. This changes numerical restoration; travel rules are unchanged.

The comparison follows [Godot4.5 is_equal_approx documentation](https://docs.godotengine.org/en/4.5/classes/class_@globalscope.html#class-globalscope-method-is-equal-approx). The earned snapshot remains private at reference-private/validation/turin11591-earned.json. No snapshot fields were repaired or reconstructed.

Independent review5October approves the production change. test_restore_earned_turin and test_train_journey both exit0. The regression restores the actual city through Main, verifies its cursor lies on the restored path, and confirms that adding another complete rail segment is rejected without changing the current journey. Source/craft report0errors0warnings.

Actual rebuilt package book12100 restored that same earned save;12101/12102 show the Turin city menu and goods list. Native captures and the earlier causal observation are retained under tasks/validation/continuous-play-20261003. Full campaign completion remains open.
