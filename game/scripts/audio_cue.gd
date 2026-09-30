extends RefCounted

# MIT. Source operand subset present in every decoded ECS csound call.
# ALIS opernames.c: ornd uses current accumulator; opushacc/opile are a stack.
static func value(operand: Dictionary, locals: Dictionary) -> int:
	match operand.name:
		"oimmb", "oimmw":
			return int(operand.args[0])
		"odirb":
			return int(locals.get(str(operand.args[0]), 0))
		"oeval":
			var accumulator := 0
			var stack: Array[int] = []
			for item in operand.args:
				match item.name:
					"opushacc": stack.append(accumulator)
					"opile": accumulator = stack.pop_back()
					"ornd": accumulator = randi_range(0, maxi(0, accumulator - 1))
					"oadd":
						accumulator += stack.pop_back() if item.args[0].name == "opile" else value(item.args[0], locals)
					"ofin": pass
					_: accumulator = value(item, locals)
			return accumulator
	push_error("Unsupported original audio operand: " + operand.name)
	return 0
