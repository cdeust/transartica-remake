# Sabotage confirmation clarification

Native continuous-play capture10033 shows NO/OK over the crew illustration and
an empty bottom text area. CampaignCrew emitted sabotage_confirm with an empty
message-ID array, and CampaignSession only rendered text from those IDs.

Verified primary listing: reference-private/observations/listings-20260927/carte.json.
CARTE0x27ae rejects travelling/already-used spies.0x27f9 draws resource238;
0x2805 chooses form2;0x2809 waits for MAIN28;0x2814 compares action33;
0x2821 adds100 to spy field13 before tile-specific sabotage dispatch.
This branch does not issue a TEXTEK question or contain a textual prompt.
The private decoded atlas carte_198_247_pal196.png likewise supplies artwork,
not a sabotage sentence. Action33 is the form choice, not TEXTEK message33.

The authored clarification “ORDER THIS SPY TO USE DYNAMITE HERE?” describes
the existing dynamite action. It is an adaptation, not a quotation from ECS.
Only CampaignSession presentation changes. Existing actors, NO/OK input,
spy selection, sabotage effects, event message IDs and save schema remain.

test_sabotage_question.gd checks nonempty presentation, existing question mode,
crew scene and exact unchanged campaign snapshot. This is a prepared regression;
Native visual and actual input acceptance is recorded below.

Opened legacy saves also stored the empty lines directly. After existing
validation succeeds, CampaignSession.restore rebuilds that sabotage question
through _show_page, then applies all other saved presentation fields unchanged.
Only empty sabotage lines are upgraded; nonempty saved wording remains intact.
The regression verifies the legacy snapshot stays valid and differs after
restore solely in its repaired lines, including an untouched nonempty case.
This additional save-upgrade path awaits root-owned native verification.

Native verification in the rebuilt macOS release, SHA256
`f03d905b2f4bd24bfd4d37804daf09886e54527105d1423a27e6dacadefde4f2`:
OPTIONS loaded the byte-identical earned10027 save at10049. Fuel rates were
turned off through L/A controls at10050, and the stopped train waited through
normal simulation until the spy arrived, then paused at10133.
10134 displays the complete question; the root inspected its viewport PNG.
NO at10135 leaves central_destroyed=false and spy field13=0. Reopening10136
and OK10137 sets central_destroyed=true and field13=100. Both branches were
recorded through real inputs and F5, preserving620 lignite. Native process77370
executed the bundled app, not a source-path run. The initial sandboxed launch
aborted before boot; the successful native launch used the macOS host.

Legacy native fixture: the retained0989213d macOS release actually loaded the
earned posted-spy save10133 through OPTIONS. Choosing DYNAMITE with the mouse
at10389 and the central location10390 produced the old empty confirmation;
F5 at10391 persisted scene=sabotage_confirm, lines=[], messages=[] and spy0.
EMPTYASK.SAV is a byte-identical private copy of that actual save. This was
not achieved by the earlier10369/10380 attempts, which contained no modal.
The old app lived in registered disposable directory
.cache/act1-artifact/disk-hygiene-f5b7o1x9; its owned processes were stopped.
Native upgrade replay remains pending until the next rebuilt release.
