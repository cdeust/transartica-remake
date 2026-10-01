extends RefCounted

# MIT. TEXTEK77/78→81→79/80; byte-for-byte loss order from0x1875..1e31.
static func defenders(wagons, phrases: Dictionary) -> Dictionary:
	var mammals := 0
	var guns := 0
	var infantry := 0
	for wagon in wagons.wagons:
		if wagon[0] == 7:
			mammals += wagon[3]
		elif wagon[0] == 12 and wagon[1] < 3:
			guns += 1
		elif wagon[0] in [23, 24]:
			infantry += wagon[3]
	return {"divisor": maxi(2, 10 - int((infantry + mammals * 30 + guns * 60) / 40)),
		"lines": [_p(phrases, 0x449b, 0) + str(infantry) + _p(phrases, 0x449b, 1),
			_p(phrases, 0x44c3, 0) + str(mammals) + _p(phrases, 0x44c3, 1),
			_p(phrases, 0x44ec, 0) + str(guns) + _p(phrases, 0x44ec, 1)]}


static func human(wagons, divisor: int, phrases: Dictionary) -> Array[String]:
	var mammals := 0
	var slaves := 0
	var infantry := 0
	for wagon in wagons.wagons:
		if wagon[0] == 7:
			wagon[3] -= int(wagon[3] / divisor)
			# Source1cf4 reads the already reduced load. Preserve original underreport.
			mammals += int(wagon[3] / divisor)
		elif wagon[0] in [5, 6, 23, 24]:
			var loss := int(wagon[3] / divisor)
			if wagon[0] in [5, 6]:
				slaves += loss
			else:
				infantry += loss
			wagon[3] -= loss
	var lines: Array[String] = [_p(phrases, 0x1c9f)]
	if slaves > 0:
		lines.append(_p(phrases, 0x1dc3) + str(slaves))
	lines.append(_p(phrases, 0x1de4) + str(infantry))
	if mammals > 0:
		lines.append(_p(phrases, 0x1e13) + str(mammals))
	return lines


static func materials(wolf: bool, wagons, engine, divisor: int, phrases: Dictionary, rng: RandomNumberGenerator, data: Dictionary) -> Array[String]:
	if wolf:
		return _wolf_materials(wagons, phrases, rng)
	var first: int = engine.anthracite / divisor #1ac2 stock2fc8.
	var second: int = engine.lignite / divisor #1ad9 stock2fb6.
	engine.anthracite -= first
	engine.lignite -= second
	var reported: int = (first + second) / 10 #1af0..1afa preserved report arithmetic.
	var destroyed := 0
	if wagons.count() > 4:
		for wagon in wagons.wagons:
			if wagon[0] > 3 and wagon[0] != 21:
				destroyed = wagon[0]
				wagon[1] = 3
				wagon[2] = 0
				wagon[3] = 0
				break
	var lines: Array[String] = [_p(phrases, 0x1a99)]
	if destroyed > 0:
		lines.append(_p(phrases, 0x1bee) + str(data.get("wagon_names", {}).get(str(destroyed), "")) + _p(phrases, 0x1bee, 1))
	if first > 0:
		lines.append(str(second) + _p(phrases, 0x1c2c))
	if reported > 0:
		lines.append(str(first) + _p(phrases, 0x1c59))
	if destroyed == 0 and second == 0 and reported == 0:
		lines.append(_p(phrases, 0x1ba8))
	rng.randi_range(0, 4) #1c8e source display interval; consumes original RNG draw.
	return lines


static func _wolf_materials(wagons, phrases: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var losses := {11: 0, 12: 0, 13: 0}
	for wagon in wagons.wagons:
		if wagon[0] in [17, 18] and losses.has(wagon[2]):
			var loss: int = wagon[3] / 2
			losses[wagon[2]] += loss
			wagon[3] -= loss
	var lines: Array[String] = [_p(phrases, 0x18b7)]
	for goods in [11, 12, 13]:
		if losses[goods] > 0:
			lines.append(str(losses[goods]) + _p(phrases, {11: 0x1a0a, 12: 0x1a34, 13: 0x1a5e}[goods]))
	if lines.size() == 1:
		lines.append(_p(phrases, 0x19f2))
	rng.randi_range(0, 3) #1a88 source display interval.
	return lines


static func _p(phrases: Dictionary, offset: int, index := 0) -> String:
	var values: Array = phrases.get(str(offset), [])
	return str(values[index]) if values.size() > index else ""
