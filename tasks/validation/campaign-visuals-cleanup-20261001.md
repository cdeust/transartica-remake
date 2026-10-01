# Campaign capture shutdown

The native campaign visuals fixture now exits after its stopped finale WAV and
playback resources are released. Runtime code and exported artifacts are unchanged.

Three diagnostic native runs reproduced an ObjectDB warning naming
`AudioStreamWAV` and `AudioStreamPlaybackWAV`. Those runs overlapped; their logs
identify the leaked objects, but their shared scratch captures are not acceptance
evidence. Godot 4.5 `stop_playback_stream` marks playback for asynchronous deletion
and `_mix_step` removes it during mixing. See the
[official audio server source](https://github.com/godotengine/godot/blob/4.5-stable/servers/audio_server.cpp#L1184).

`test_campaign_visuals.gd` observes both objects through WeakRefs before stopping
the movie, clears the player's stream, frees the screen and yields frames until
both resources disappear. Completion follows resource lifetime without a fixed
delay. All existing scene and finale captures remain exercised.

Three subsequent native runs executed sequentially, each with:

```sh
.toolchain/Godot.app/Contents/MacOS/Godot --path game --verbose \
  --script tests/test_campaign_visuals.gd
```

Each exited 0 and printed PASS. Their complete verbose logs contain no ERROR,
WARNING or leaked-object entries:

- `campaign-visuals-clean-after-1-20261001.log`
- `campaign-visuals-clean-after-2-20261001.log`
- `campaign-visuals-clean-after-3-20261001.log`

The final sequential run regenerated the scratch scene captures. Both source and
craftsmanship checks reported zero errors and zero warnings for the changed fixture.
