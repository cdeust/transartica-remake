# Locomotive visibility at earned raw10361

Scope: source/render diagnostics. Root owns native launch and player inputs.
No earned campaign completion is claimed by prepared probes.

- [x] Inspect native10493 metadata and PNG. One complete pose exists, hero
  AtlasTexture and underlying793x1983texture are available, lag0 and tint opaque.
- [x] Native10508 confirms Renderer.draw traverses that pose and supplies the
  expected matrix/rectangle near788,250 to849,190.
- [x] Prepared Main restores unchanged raw10361 and intercepts a real hero
  texture command. CPU image center alpha0.9882. Headless exit0.
- [x] Root-run prepared Atlas probe exits0 and draws all three equivalent hero
  paths correctly on GL compatibility Apple M4. No asset/backend workaround.
- [x] Root-run prepared Main layer probe exits0; stage1 inspection shows part
  of the hero under the caption and direction arrow. Full absence is not proved.
- [x] Root-run stage6 train-only and stage7 heading-only captures. Measured
 1232 train pixels,663 heading overlap,665 changed in combined,567 unchanged.
 The hero draws correctly; the original cue covered part of it.
- [x] MapEntities translates the arrow and caption outside actual
 renderer.screen_bounds at the same lag, while keeping each inside the viewport.
 Existing authored dimensions/gap remain unchanged.
- [x] Remove transient renderer draw instrumentation and its capture field.
 Useful frame diagnostics remain. Headless heading regression exit0: exact
 native old-caption intersection,8 directions forward/reverse and3 fitted
 viewport sizes using actual21 wagon frames. Native after-proof remains open.

Native observations remain in tasks/validation/continuous-play-20261003.
Prepared probes/logs are in .cache/reverse-hidden-contact-fix-20261004.
The renderer last_draw_observation was temporary, excluded from saves and is
 now removed.
The stages modify drawing only in a prepared Main copy whose only changed
production declaration is the WorldViewScript preload. No game-state injection.
The pixel comparator reads captures and never changes them.

Source: MapEntities.draw_player_heading draws after the train and places the
caption above diagonal travel; its existing comment requires the caption not
hide a reversing locomotive. The arrow sits32pixels ahead of the displayed
head while the reverse locomotive body also extends in that direction.
Source visibility contract plus measured overlap justify overlay placement.
 When no box fits outside the convoy in the viewport, the map cue is omitted;
 the separate direction instrument still displays the actual heading.

Lesson: pose counts and valid draw commands do not prove that an overlay leaves
 a vehicle visible. Compare train-only and overlay-only native captures before
 declaring a vehicle absent. Place cues using the same drawn vehicle bounds and
 lag, and test viewport fitting without changing train geometry.

Independent reviewer /root/reverse_physical_stop returned APPROVE for the
final overlay geometry and test. Both overlays are cleared against the same
convoy AABB at the same draw lag. Their mutual placement still requires the
owner-run prepared native after-capture. No native after-verdict is claimed.

Root native after-proof10582 restores the same earned raw10361 through normal
OPTIONS in the rebuilt macOS application. The hero is visible on the rails,
with the caption above its full body and the direction arrow below it; neither
covers the hero or the other cue. Position43,31,cycles9201,reverse=true and
pause match the before state. The viewport capture was visually inspected.
Full native underground traversal and campaign completion remain separate.
