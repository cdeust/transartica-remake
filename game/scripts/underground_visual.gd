extends RefCounted

# MIT. Presentation classification only; does not alter source traversal/risk.
# Source: TIME0x0496 switch codes; private CARTE tile atlas53/54/58 mouths.
static func is_underground(code: int) -> bool:
	code = absi(code)
	return (code >= 38 and code <= 52) or (code >= 55 and code <= 57)


static func mouth_direction(code: int) -> Vector2:
	# Opening faces surface rails:53 south,54 west,58 east. The opposite side
	# enters the ice-covered approach52/50/56 respectively in CARTE.FIC.
	match code:
		53: return Vector2.DOWN
		54: return Vector2.LEFT
		58: return Vector2.RIGHT
	return Vector2.ZERO


static func train_tint(code: int, candidate_alpha: float) -> Color:
	# Owner4Oct requests slight transparency; candidate strength is visual design,
	# not an original simulation constant. Mouth/surface wagons remain opaque.
	return Color(1,1,1,candidate_alpha if is_underground(code) else 1.0)
