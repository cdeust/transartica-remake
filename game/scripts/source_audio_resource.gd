extends RefCounted

# MIT. Preserve raw source WAVs in development; exported PCKs use imported audio.
# Evidence: tasks/validation/exported-audio-20261004.md, release resource probe.
static func wave(path: String) -> AudioStreamWAV:
	if FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as AudioStreamWAV
	return null
