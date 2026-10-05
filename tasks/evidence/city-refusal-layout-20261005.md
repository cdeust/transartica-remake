# City transaction refusal overlap, 5 October 2026

Native campaign capture `tasks/validation/continuous-play-20261003/33126.png`
shows the genuine Paris tender-capacity refusal crossing the three-line sale
detail. The detail occupied logical y116..145 and the notice y125..147.
Their rectangles overlapped by20 logical pixels.

`game/tests/test_city_refusal_layout.gd` reproduces the actual refusal through
production `increment()`: Paris caviar33, lignite4185, anthracite785, one tender.
Only the detached fixture's cargo capacity differs from the full campaign
consist: Room27 versus Room227. The same40-lignite sale exceeds remaining
tender capacity30. No campaign save or running console is changed.

The native baseline exits1 with capacity/workshop overlap failures at both
resolutions. Raw measurements in `.cache/city-refusal-before-20261005.log`:

```text
1440x900 detail y522..652.5; notice y562.5..661.5; overlap90
1280x800 detail y464..580; notice y500..588; overlap80
```

The minimal `city_screen.gd` change reduces list height72 to62, moves detail
relative y77 to67, and reserves logical y139..147 for notices. Detail retains
its existing29-pixel height and font. All current refusal strings fit one line.
The list retains its existing five columns and scrolling.

Final native exit0 in `.cache/city-refusal-after-20261005.log`:

```text
1440x900 detail y477..607.5; notice y625.5..661.5; overlap0
1280x800 detail y424..540; notice y556..588; overlap0
PASS: native refusal, full three-line detail and workshop/menu notice separation at both resolutions
```

The regression also checks actual workshop money refusal and menu no-room
refusal, full detail text width/height, every current notice width, and notice
containment above the shared HUD. Screenshots are retained under
`tasks/validation/city-refusal-layout-20261005/{before,after}-{capacity,workshop,menu}-{1440,1280}.png`.
Both final capacity captures were visually inspected.

Final source and craftsmanship gates on the two changed code files report
0errors and0warnings. `test_city_trade.gd` and `test_city_list_text.gd` both exit0;
the latter retains whole source names and quantities at four viewport sizes.
Headless checks emit the existing macOS certificate warning. The causal layout
test executes with native OpenGL/Metal rendering. `git diff --check` is clean.
All isolated test processes exited. No commit or push was performed.
