# Stray map command icon above the city painting

Earned Kiev screenshots 32034 and 32038 contain the same beige fragment at pixels x205..220, y163..175. The city painting starts at y175.5 at this viewport size. This is an interface artifact, not part of the painting.

Separate native layer renders establish the producer: `city-only.png` has no fragment, while `city-and-panel.png` restores it. Rendering the common panel primitives separately produces the fragment only in `panel-commands.png`. Plate, clock and composition captures do not produce it. Captures are in `tasks/validation/city-ui-artifact-20261005/`; the isolated diagnostic script is `.cache/city-ui-artifact-20261005/layers.gd`. No active game-console input or campaign save was used.

Root cause: `OriginalPanel._draw` resets its drawing transform before `_draw_map_commands`. `_draw_command_icon` then supplied a logical destination rectangle directly to `draw_texture_rect_region`. The atlas icon was drawn at unscaled logical coordinates above the HUD. The correction uses the existing `screen_rect(destination)` conversion, preserving atlas selection and the intended slot.

Native pixel regression `test_panel_command_registration.gd` compares the renderer output against a hidden-panel baseline. Every changed pixel must lie in the real map-command slot, and that slot must contain changed pixels. It covers map and overview-return icons at 1440×900 and 1280×800.

Before: exit 1; zero pixels inside the slot, 213 outside for the map icon and 82 outside for the return icon at both resolutions. After: exit 0; outside count zero in all four cases; inside counts 4185/1608 at 1440×900 and 3306/1258 at 1280×800. Logs: `registration-before.log` and `registration-after.log` in the validation directory. OpenGL 4.1 Metal compatibility renderer was used.

`after-full.png` shows the city without the stray fragment and the restored icon in the HUD. The focused native regression was rerun after its final formatting edit. Existing `test_original_panel.gd` and `test_clock_quality.gd` exit 0. Source and craftsmanship checks report zero errors and zero warnings; whitespace checks pass. All diagnostic processes exited normally. No city artwork or gameplay behavior was changed.
