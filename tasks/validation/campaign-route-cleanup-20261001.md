# Campaign route fixture shutdown, 1 October 2026

The isolated driver/story UI attach/free fixture exits cleanly. Completed route
playback under Godot Dummy leaked one AudioStreamWAV and its AudioStreamPlaybackWAV.
Verbose evidence: `campaign-route-cleanup-route-after-20261001.log`.
The Sun movie owns this playback even though the route host has no GameAudio.
The actual native macOS renderer releases it cleanly. The route test therefore
requires the native renderer, with this measured reason beside its declaration.

The route checkpoint fixture also omitted the production launcher required by
current session save extensions. Godot reported five script errors while the
old test still printed PASS. `campaign-route-cleanup-route-before-20261001.log`
retains those failures. The route presentation host now extends Control and
owns the actual LauncherSession. It supplies original world data for the
launcher's presentation. The disk checkpoint uses that same Boudoir host.
No runtime game module or campaign rule changed.

Final native verbose execution in `campaign-route-cleanup-native-after-20261001.log`
contains no SCRIPT ERROR, ERROR, WARNING, leaked instance or ObjectDB leak.
Both continuous and actual Mausoleum disk-resumed routes finish after 10,657
advance callbacks and 1,713 entered cells, on day23 with lignite1067.
The original finale returns to OPTIONS. The checkpoint state and final outcome
remain identical. Source and craftsmanship gate logs are alongside this file.

Reproduce from the project root:

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --verbose --path game \
  --script res://tests/test_campaign_route.gd
```

Acceptance requires PASS and absence of script errors or leak warnings.
