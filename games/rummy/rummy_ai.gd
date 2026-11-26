class_name RummyAI
extends RefCounted
## 타일 러미 AI
##  1) 손패만으로 만들 수 있는 묶음 조합 중 가장 많이 내는 조합 찾기 (처음 등록은 30점 이상)
##  2) 판의 묶음에 한 장씩 붙이기 (어려움: 런 가운데 끼워 둘로 나누기도)
##  3) 어려움: 판의 묶음에서 남는 타일을 빌려 와 새 묶음 만들기
## 쉬움은 일부만, 보통은 1)+2), 어려움은 모두 사용

enum Level { EASY, NORMAL, HARD }

const NODE_LIMIT := 25000

var level: int = Level.NORMAL
var rng := RandomNumberGenerator.new()
var _nodes: int = 0


func _init(lv: int = Level.NORMAL) -> void:
	level = lv
	rng.randomize()


## 이번 차례에 만들 새 판. 빈 배열이면 뽑고 넘김
func choose(L: RummyLogic, me: int) -> Array:
	var rack: Array = (L.racks[me] as Array).duplicate()
	var table: Array = L.table.duplicate(true)
	var before := rack.size()
	if not L.melded[me]:
		var sets := best_rack_sets(rack, true)
		if sets.is_empty():
			return []
		if level == Level.EASY and rng.randf() < 0.25:
			return []   # 쉬움: 가끔 등록할 수 있어도 놓침
		for s in sets:
			table.append(s)
		return table

	var sets2 := best_rack_sets(rack, false)
	if level == Level.EASY and sets2.size() > 1:
		sets2 = [sets2[0]]
	for s in sets2:
		table.append(s)
		for t in s:
			rack.erase(t)
	if level != Level.EASY or rng.randf() < 0.5:
		_layoff(table, rack, level == Level.HARD)
	if level == Level.HARD:
		if _borrow(table, rack) > 0:
			_layoff(table, rack, true)
	if rack.size() == before:
		return []
	if not RummyLogic.table_valid(table):
		return []
	return table


# ══════════════════════════════════════════════════════
#  손패만으로 묶음 만들기
# ══════════════════════════════════════════════════════
## need_meld 이면 합이 30 이상인 조합만. 고른 묶음들(타일 번호)을 돌려줌
func best_rack_sets(rack: Array, need_meld: bool) -> Array:
	var counts: Array = []
	counts.resize(52)
	counts.fill(0)
	var by_kind := {}
	var jokers: Array = []
	for t in rack:
		if RummyLogic.is_joker(t):
			jokers.append(t)
			continue
		var k := RummyLogic.kind_of(RummyLogic.color_of(t), RummyLogic.num_of(t))
		counts[k] += 1
		if not by_kind.has(k):
			by_kind[k] = []
		(by_kind[k] as Array).append(t)
	var cands := _candidates(counts, jokers.size())
	if cands.is_empty():
		return []
	# 큰 묶음부터 탐색
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["size"]) > int(b["size"]))
	var state := {"best": [], "best_tiles": 0, "best_value": 0, "best_jokers": 99}
	_nodes = 0
	_dfs(cands, 0, counts, jokers.size(), [], 0, 0, 0, need_meld, state, rack.size())
	var chosen: Array = state["best"]
	if chosen.is_empty():
		return []
	# 종류 → 실제 타일 번호
	var used := {}
	var ji := 0
	var out: Array = []
	for c in chosen:
		var s: Array = []
		for k in c["kinds"]:
			for t in by_kind[k]:
				if not used.has(t):
					used[t] = true
					s.append(t)
					break
		for j in int(c["jokers"]):
			s.append(jokers[ji])
			ji += 1
		out.append(s)
	return out


func _candidates(counts: Array, jokers: int) -> Array:
	var out: Array = []
	# 그룹
	for num in range(1, 14):
		var cols: Array = []
		for c in 4:
			if int(counts[RummyLogic.kind_of(c, num)]) > 0:
				cols.append(c)
		var m := cols.size()
		for mask in range(1, 1 << m):
			var kinds: Array = []
			for i in m:
				if mask & (1 << i):
					kinds.append(RummyLogic.kind_of(cols[i], num))
			for j in range(0, mini(jokers, 2) + 1):
				var sz := kinds.size() + j
				if sz >= 3 and sz <= 4:
					out.append({"kinds": kinds, "jokers": j, "size": sz, "value": num * sz})
	# 런
	for c in 4:
		for start in range(1, 12):
			for end in range(start + 2, 14):
				var kinds: Array = []
				var missing := 0
				var value := 0
				for v in range(start, end + 1):
					value += v
					var k := RummyLogic.kind_of(c, v)
					if int(counts[k]) > 0:
						kinds.append(k)
					else:
						missing += 1
				if missing > jokers:
					if missing > 2:
						break
					continue
				if kinds.is_empty():
					continue
				out.append({"kinds": kinds, "jokers": missing, "size": end - start + 1, "value": value})
	return out


func _dfs(cands: Array, i: int, counts: Array, jokers: int, picked: Array, tiles: int, value: int, jused: int,
		need_meld: bool, st: Dictionary, rack_size: int) -> void:
	_nodes += 1
	if _nodes > NODE_LIMIT:
		return
	# 지금까지 고른 것 평가
	if not picked.is_empty() and (not need_meld or value >= RummyLogic.MELD_MIN):
		var better := tiles > int(st["best_tiles"])
		if tiles == int(st["best_tiles"]):
			better = jused < int(st["best_jokers"]) or (jused == int(st["best_jokers"]) and value > int(st["best_value"]))
		if better:
			st["best"] = picked.duplicate()
			st["best_tiles"] = tiles
			st["best_value"] = value
			st["best_jokers"] = jused
	if int(st["best_tiles"]) >= rack_size:
		return
	for ci in range(i, cands.size()):
		var c: Dictionary = cands[ci]
		var j: int = c["jokers"]
		if j > jokers:
			continue
		var ok := true
		for k in c["kinds"]:
			if int(counts[k]) <= 0:
				ok = false
				break
		if not ok:
			continue
		for k in c["kinds"]:
			counts[k] -= 1
		picked.append(c)
		# 같은 묶음을 한 번 더 고를 수 있게 (2벌) ci 부터 다시
		_dfs(cands, ci, counts, jokers - j, picked, tiles + int(c["size"]), value + int(c["value"]), jused + j, need_meld, st, rack_size)
		picked.pop_back()
		for k in c["kinds"]:
			counts[k] += 1
		if _nodes > NODE_LIMIT:
			return


# ══════════════════════════════════════════════════════
#  판에 붙이기 / 빌려 오기
# ══════════════════════════════════════════════════════
func _layoff(table: Array, rack: Array, allow_split: bool) -> int:
	var placed := 0
	var changed := true
	var guard := 0
	while changed and guard < 60:
		guard += 1
		changed = false
		var order := rack.duplicate()
		# 조커는 마지막에 (아껴 쓰기)
		order.sort_custom(func(a: int, b: int) -> bool: return int(RummyLogic.is_joker(a)) < int(RummyLogic.is_joker(b)))
		for t in order:
			if RummyLogic.is_joker(t) and level == Level.HARD and rack.size() > 3:
				continue
			for si in table.size():
				var s: Array = table[si]
				var cand := s.duplicate()
				cand.append(t)
				if RummyLogic.analyze(cand)["ok"]:
					table[si] = cand
					rack.erase(t)
					placed += 1
					changed = true
					break
				if allow_split and _try_split(table, si, t):
					rack.erase(t)
					placed += 1
					changed = true
					break
			if changed:
				break
	return placed


## 런 가운데에 같은 숫자가 들어오면 둘로 나누기 (예: 빨강 3~8 + 빨강 5 → 3~5, 5~8)
func _try_split(table: Array, si: int, t: int) -> bool:
	if RummyLogic.is_joker(t):
		return false
	var info := RummyLogic.analyze(table[si])
	if not info["ok"] or info["kind"] != "run":
		return false
	var order: Array = info["order"]
	var start: int = info["start"]
	var v := RummyLogic.num_of(t)
	var c := -1
	for x in order:
		if not RummyLogic.is_joker(x):
			c = RummyLogic.color_of(x)
			break
	if RummyLogic.color_of(t) != c:
		return false
	var idx := v - start
	if idx < 2 or idx > order.size() - 3:
		return false
	var left := order.slice(0, idx + 1)
	var right: Array = [t]
	right.append_array(order.slice(idx + 1))
	if RummyLogic.analyze(left)["ok"] and RummyLogic.analyze(right)["ok"]:
		table[si] = left
		table.append(right)
		return true
	return false


## 판에서 빼도 괜찮은 타일 [묶음 번호, 타일]
func _removable(table: Array) -> Array:
	var out: Array = []
	for si in table.size():
		var s: Array = table[si]
		if s.size() < 4:
			continue
		for t in s:
			var rest := s.duplicate()
			rest.erase(t)
			if RummyLogic.analyze(rest)["ok"]:
				out.append([si, t])
	return out


## 손패 1~2장 + 판에서 빌린 타일로 새 묶음 만들기
func _borrow(table: Array, rack: Array) -> int:
	var made := 0
	for round_i in 8:
		var rem := _removable(table)
		if rem.is_empty():
			break
		var done := false
		# 손패 2장 + 판 1장
		for a in rack.size():
			for b in range(a + 1, rack.size()):
				for r in rem:
					var trio: Array = [rack[a], rack[b], r[1]]
					if RummyLogic.analyze(trio)["ok"]:
						var ta: int = rack[a]
						var tb: int = rack[b]
						(table[r[0]] as Array).erase(r[1])
						table.append(trio)
						rack.erase(ta)
						rack.erase(tb)
						made += 2
						done = true
						break
				if done:
					break
			if done:
				break
		if not done:
			# 손패 1장 + 판 2장 (서로 다른 묶음, 또는 둘 다 빼도 되는 같은 묶음)
			for a in rack.size():
				for x in rem.size():
					for y in range(x + 1, rem.size()):
						var rx: Array = rem[x]
						var ry: Array = rem[y]
						var trio: Array = [rack[a], rx[1], ry[1]]
						if not RummyLogic.analyze(trio)["ok"]:
							continue
						if int(rx[0]) == int(ry[0]):
							var rest: Array = (table[rx[0]] as Array).duplicate()
							rest.erase(rx[1])
							rest.erase(ry[1])
							if not RummyLogic.analyze(rest)["ok"]:
								continue
						var ta: int = rack[a]
						(table[rx[0]] as Array).erase(rx[1])
						(table[ry[0]] as Array).erase(ry[1])
						table.append(trio)
						rack.erase(ta)
						made += 1
						done = true
						break
					if done:
						break
				if done:
					break
		if not done:
			break
	return made
