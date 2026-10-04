# Choice readability correction, 4 October 2026

Owner screenshots showed SEND SPY/DYNAMITE/EXIT and sabotage NO/OK as bare
text against the map table. OPTIONS status labels likewise floated over blue
plaques. The owner requested readable controls in the existing pixel-art theme.

BrassChoice reuses OriginalScreen.GOLD and WorldEventScreen's dark navy.
Authored cards have opaque dark backing, brass outline, lighter hover backing,
and thicker pressed/focus outline. Typography uses OriginalScreen's existing
seven-logical-pixel text. Frame widths and label insets are presentation choices,
not original game rules. Focus indication follows existing keyboard defaults:
first crew choice and confirmation OK. Mouse exit redraw clears hover.

All input code remains intact: crew choices still select full-width bands
starting y44 at25-pixel intervals; confirmation still partitions the entire
canvas at x160; OPTIONS still uses the five original PLAQUES rectangles;
KEYS retains Rect2(130,128,59,17). The art and campaign logic are unchanged.
Visual cards are intentionally contained inside those existing input regions.

test_brass_choices passed clicks outside the new cards but inside original
hitboxes, NO/OK partition boundaries and original level/combat/music actions.
Prepared native captures at output/brass-choices-review-20261004 show the spy
menu, sabotage confirmation and OPTIONS. All three were visually inspected:
labels are readable and original icon artwork remains visible. The observer
keeps room texture alive as the actual GeneralQuarters does. These captures
are presentation evidence; root owns native player-flow acceptance.

Root rebuilt the private macOS package and inspected its actual native captures:
10468 OPTIONS,10469 KEYS click and10470 return;10472 earned legacy empty
confirmation restored with its question and framed NO/OK,10473 NO;10485 operator
spy menu with all three framed choices,10486 keyboard EXIT. These are real
viewport inputs and earned save loads in the exported application. The full
campaign remains open.
