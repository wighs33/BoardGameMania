class_name RummyLogic
extends RefCounted
## 타일 러미 – 규칙 엔진 (루미큐브와 같은 규칙)
## 타일 번호: 0~103 = 숫자 타일 (2벌 × 4색 × 1~13), 104 · 105 = 조커
## 묶음: 그룹(같은 숫자 · 서로 다른 색 3~4개) 또는 런(같은 색 · 이어지는 숫자 3개 이상)

const JOKER_A := 104
const TILE_COUNT := 106
const START_HAND := 14
const MELD_MIN := 30
const JOKER_PENALTY := 30
const COLOR_NAMES := ["빨강", "파랑", "노랑", "검정"]

var n: int = 2
var racks: Array = []        # p -> Array (타일 번호)
var table: Array = []        # 묶음들 (각 묶음 = 타일 번호 Array)
var pool: Array = []
var current: int = 0
var melded: Array = []       # p -> 처음 등록(30점) 했는지
var passes: int = 0          # 더미가 빈 뒤 연속으로 그냥 넘긴 횟수
var over: bool = false
var winner: int = -1
var by_points: bool = false  # 더미가 떨어져 점수로 끝났는지
var turn_no: int = 0
var last: Dictionary = {}


static func is_joker(t: int) -> bool:
	return t >= JOKER_A


static func color_of(t: int) -> int:
	return -1 if t >= JOKER_A else (t % 52) / 13


static func num_of(t: int) -> int:
	return 0 if t >= JOKER_A else t % 13 + 1


static func kind_of(color: int, num: int) -> int:
	return color * 13 + num - 1


## 남은 타일 벌점 (조커 30)
static func penalty_of(t: int) -> int:
	return JOKER_PENALTY if t >= JOKER_A else num_of(t)


## 손패 정렬 키. by_color = 색깔별, 아니면 숫자별 (조커는 맨 뒤)
static func sort_key(t: int, by_color: bool) -> int:
	if t >= JOKER_A:
		return 100000 + t
	if by_color:
		return color_of(t) * 1000 + num_of(t) * 10 + (t / 52)
	return num_of(t) * 1000 + color_of(t) * 10 + (t / 52)


static func sort_tiles(tiles: Array, by_color: bool) -> void:
	tiles.sort_custom(func(a: int, b: int) -> bool: return sort_key(a, by_color) < sort_key(b, by_color))


func setup(players: int, rng: RandomNumberGenerator, first: int = 0) -> void:
	n = players
	pool = []
	for t in TILE_COUNT:
		pool.append(t)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	racks = []
	melded = []
	for p in n:
		var r: Array = []
		for i in START_HAND:
			r.append(pool.pop_back())
		racks.append(r)
		melded.append(false)
	table = []
	current = first % n
	passes = 0
	over = false
	winner = -1
	by_points = false
	turn_no = 0
	last = {}


func clone() -> RummyLogic:
	var c := RummyLogic.new()
	c.n = n
	c.racks = racks.duplicate(true)
	c.table = table.duplicate(true)
	c.pool = pool.duplicate()
	c.current = current
	c.melded = melded.duplicate()
	c.passes = passes
	c.over = over
	c.winner = winner
	c.by_points = by_points
	c.turn_no = turn_no
	return c


# ══════════════════════════════════════════════════════
#  묶음 판정
# ══════════════════════════════════════════════════════
## {ok, kind("group"/"run"), value(숫자 합, 조커는 대신하는 숫자), order(보여 줄 순서)}
static func analyze(tiles: Array) -> Dictionary:
	var best := {"ok": false, "kind": "", "value": 0, "order": tiles.duplicate()}
	var cnt := tiles.size()
	if cnt < 3 or cnt > 13:
		return best
	var jokers: Array = []
	var normals: Array = []
	for t in tiles:
		if is_joker(t):
			jokers.append(t)
		else:
			normals.append(t)
	if normals.is_empty():
		return best

	# 그룹: 같은 숫자, 색은 모두 다르게, 3~4개
	if cnt <= 4:
		var ok := true
		var num := num_of(normals[0])
		var cols := {}
		for t in normals:
			if num_of(t) != num or cols.has(color_of(t)):
				ok = false
				break
			cols[color_of(t)] = true
		if ok:
			var order: Array = normals.duplicate()
			order.sort_custom(func(a: int, b: int) -> bool: return color_of(a) < color_of(b))
			order.append_array(jokers)
			best = {"ok": true, "kind": "group", "value": num * cnt, "order": order}

	# 런: 같은 색, 숫자는 겹치지 않고 이어지게 (빈 곳은 조커)
	var col := color_of(normals[0])
	var by_num := {}
	var ok2 := true
	for t in normals:
		if color_of(t) != col or by_num.has(num_of(t)):
			ok2 = false
			break
		by_num[num_of(t)] = t
	if ok2:
		var lo := 99
		var hi := 0
		for v in by_num:
			lo = mini(lo, v)
			hi = maxi(hi, v)
		var gaps := (hi - lo + 1) - normals.size()
		if gaps <= jokers.size():
			var extra := jokers.size() - gaps
			var top := hi + extra
			var start := lo
			if top > 13:
				start = lo - (top - 13)
				top = 13
			if start >= 1:
				var order: Array = []
				var value := 0
				var ji := 0
				for v in range(start, top + 1):
					value += v
					if by_num.has(v):
						order.append(by_num[v])
					else:
						order.append(jokers[ji])
						ji += 1
				if not best["ok"] or value > int(best["value"]):
					best = {"ok": true, "kind": "run", "value": value, "order": order, "start": start}
	return best


static func table_valid(tbl: Array) -> bool:
	for s in tbl:
		if not analyze(s)["ok"]:
			return false
	return true


static func _sig(s: Array) -> String:
	var c: Array = s.duplicate()
	c.sort()
	return ",".join(PackedStringArray(c.map(func(x: int) -> String: return str(x))))


# ══════════════════════════════════════════════════════
#  진행
# ══════════════════════════════════════════════════════
## 처음 등록 전, 이번에 새로 만든(내 타일로만 된) 묶음들의 점수. 판 타일을 건드렸으면 -1
func meld_points(new_table: Array, p: int) -> int:
	var old_sigs := {}
	for s in table:
		var sg := _sig(s)
		old_sigs[sg] = int(old_sigs.get(sg, 0)) + 1
	var rack: Array = racks[p]
	var sum := 0
	for s in new_table:
		if (s as Array).is_empty():
			continue
		var sg := _sig(s)
		if int(old_sigs.get(sg, 0)) > 0:
			old_sigs[sg] = int(old_sigs[sg]) - 1
			continue
		for t in s:
			if not rack.has(t):
				return -1
		var info := analyze(s)
		if info["ok"]:
			sum += int(info["value"])
	for k in old_sigs:
		if int(old_sigs[k]) > 0:
			return -1
	return sum


## 이번 차례 결과 확정. 성공하면 "" , 아니면 안 되는 이유
func commit(new_table: Array) -> String:
	if over:
		return "게임이 끝났어요"
	var rack: Array = racks[current]
	var old_left := {}
	for s in table:
		for t in s:
			old_left[t] = true
	var played: Array = []
	var cleaned: Array = []
	for s in new_table:
		if (s as Array).is_empty():
			continue
		cleaned.append((s as Array).duplicate())
		for t in s:
			if old_left.has(t):
				old_left.erase(t)
			elif rack.has(t) and not played.has(t):
				played.append(t)
			else:
				return "잘못된 타일이 있어요"
	if not old_left.is_empty():
		return "판에 있던 타일은 손으로 가져올 수 없어요"
	if played.is_empty():
		return "내 타일을 한 장 이상 내야 해요"
	for s in cleaned:
		if not analyze(s)["ok"]:
			return "올바르지 않은 묶음이 있어요"
	if not melded[current]:
		var pts := meld_points(cleaned, current)
		if pts < 0:
			return "처음 등록할 때는 판의 타일을 옮길 수 없어요"
		if pts < MELD_MIN:
			return "처음 등록은 내 타일로만 30점 이상! (지금 %d점)" % pts
	for i in cleaned.size():
		cleaned[i] = analyze(cleaned[i])["order"]
	table = cleaned
	for t in played:
		rack.erase(t)
	melded[current] = true
	passes = 0
	last = {"type": "play", "by": current, "tiles": played}
	if rack.is_empty():
		over = true
		winner = current
		return ""
	_next()
	return ""


## 타일을 내지 않고 넘기기: 더미에서 1장 뽑음. 더미가 없으면 그냥 넘김. 뽑은 타일 번호(-1 = 없음)
func draw_and_pass() -> int:
	if over:
		return -1
	if pool.is_empty():
		passes += 1
		last = {"type": "pass", "by": current}
		if passes >= n:
			_finish_by_points()
		else:
			_next()
		return -1
	var t: int = pool.pop_back()
	(racks[current] as Array).append(t)
	passes = 0
	last = {"type": "draw", "by": current, "tile": t}
	_next()
	return t


func _next() -> void:
	current = (current + 1) % n
	turn_no += 1


func rack_value(p: int) -> int:
	var s := 0
	for t in racks[p]:
		s += penalty_of(t)
	return s


func _finish_by_points() -> void:
	over = true
	by_points = true
	var best := -1
	for p in n:
		if best < 0 or rack_value(p) < rack_value(best) \
				or (rack_value(p) == rack_value(best) and (racks[p] as Array).size() < (racks[best] as Array).size()):
			best = p
	winner = best


## 점수: 이긴 사람 = 다른 사람들 남은 점수 합, 나머지 = -(내 남은 점수)
func final_scores() -> Array:
	var out: Array = []
	var total := 0
	for p in n:
		if p != winner:
			total += rack_value(p)
	for p in n:
		if p == winner:
			out.append(total - (rack_value(p) if by_points else 0))
		else:
			out.append(-rack_value(p))
	return out
