extends RefCounted

# Stoup / radio message queue: main[0x6152], count main+0x614f. Shared by the boudoir
# (room.alis 0xd4 -> 0x267) and General Quarters (train.alis 0xe4e -> 0x10ad); both
# handlers run byte-identical code against the same main-process array.
#
# Push (yoda.alis 0x1d30-0x1db7, disassembled 2026-09-27): when the array is full the
# routine shifts every slot down by one (dropping the oldest entry, main[0x6152][0]),
# then always writes the new id at main[0x6152][count] and increments count.
# Pop (room.alis 0x267 / train.alis 0x10ad): count -= 1; read main[0x6152][count].
#
# Correction to tasks/evidence/captain-crew.md §2 ("pop one from main[0x6152]"): the
# evidence did not state an order. The listing proves push appends at the end (oldest
# dropped first when full) and pop reads the just-decremented top index, i.e. the STOUP
# always shows the MOST RECENTLY arrived message first, not the oldest -- a capacity-10
# LIFO stack with drop-oldest overflow, not a FIFO queue.

const CAPACITY := 10
const STOUP_DISPLAY := 98 # textek 98: the card the stoup shows (room.alis 0x272, train.alis 0x10b8).
const STORY_THRESHOLD := 51 # ids < 51 are not read (captain-crew.md §2; not decoded further).
const SPY_REPORT_BASE := 101 # ids 101+k are reports from spy k.

var _entries: Array[int] = []


func count() -> int:
	return _entries.size()


func has_pending() -> bool:
	return not _entries.is_empty()


# precondition: message_id identifies a stoup message.
# postcondition: message_id is the new top of the stack (returned first by pop()).
# invariant: _entries.size() <= CAPACITY; when the stack was already full, the oldest
# entry (index 0) is discarded before the new one is appended.
func push(message_id: int) -> void:
	if _entries.size() >= CAPACITY:
		_entries.pop_front()
	_entries.append(message_id)


# precondition: has_pending() is true.
# postcondition: the top entry is removed; returns {"display": STOUP_DISPLAY,
# "message_id": <popped id>}. Returns {} when the stack is empty (caller's "if messages
# waiting" guard, main+0x614f != 0, kept explicit rather than assumed by the caller).
func pop() -> Dictionary:
	if _entries.is_empty():
		return {}
	var message_id: int = _entries.pop_back()
	return {"display": STOUP_DISPLAY, "message_id": message_id}


func snapshot() -> Array:
	return _entries.duplicate()


func restore(value: Variant) -> bool:
	if not value is Array or value.size() > CAPACITY:
		return false
	var parsed: Array[int] = []
	for entry in value:
		if not (typeof(entry) == TYPE_INT or typeof(entry) == TYPE_FLOAT) or float(entry) != floor(float(entry)):
			return false
		parsed.append(int(entry))
	_entries = parsed
	return true
