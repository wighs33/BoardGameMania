class_name OmokAI
extends RefCounted
## 오목 AI
##  - 후보: 기존 돌 주변 2칸 이내 빈칸
##  - 점수: 내가 두었을 때의 공격 점수 + 상대가 두었을 때의 방어 점수
##    (오목 > 열린4 > 4-3 > 막힌4 > 열린3 ... 순)
##  - 쉬움: 방어가 약하고 랜덤 / 보통: 공격·방어 균형 / 어려움: 상대 응수까지 2수 앞
##  - 스레드에서 돌릴 수 있도록 넘겨받은 OmokLogic 복사본만 건드림

enum Level { EASY, NORMAL, HARD }

const S_FIVE := 1000000.0
const DEF_WEIGHT := [0.55, 0.85, 1.0]

var level: int = Level.NORMAL
var rng := RandomNumberGenerator.new()
## 어려움: 상대가 다음에 만들 수 있는 공격을 얼마나 경계할지 (클수록 수비적)
var caution: float = 0.5
var def_weight_hard: float = 1.0


func _init(p_level: int = Level.NORMAL) -> void:
	level = p_level
	rng.randomize()


static func cell_score(L: OmokLogic, c: Vector2i, p: int) -> float:
	var a := L.analyze(c, p)
	if a["five"]:
		return S_FIVE
	var of: int = a["open_fours"]
	var f: int = a["fours"]
	var ot: int = a["open_threes"]
	var t: int = a["threes"]
	var s := of * 100000.0 + f * 12000.0 + ot * 4000.0 + t * 500.0 + float(a["window"])
	# 이기는 조합: 열린 4 와 같은 급 이상으로 취급
	if of + f >= 2:
		s += 150000.0         # 쌍사
	elif of + f >= 1 and ot >= 1:
		s += 150000.0         # 사삼
	elif ot >= 2 and not L.ban_double_three:
		s += 60000.0          # 쌍삼 (허용될 때만)
	return s


## [점수, 자리, 공격, 방어] 목록 (점수 내림차순)
func _rank(L: OmokLogic, me: int, w_def: float) -> Array:
	var opp := 1 - me
	var out: Array = []
	for c in L.candidates(2):
		if L.is_forbidden(c, me):
			continue
		var atk := cell_score(L, c, me)
		var dfn := 0.0 if L.is_forbidden(c, opp) else cell_score(L, c, opp)
		out.append([atk + dfn * w_def, c, atk, dfn])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return out


func choose(L: OmokLogic, me: int) -> Vector2i:
	var mid := L.size / 2
	if L.history.is_empty():
		if level == Level.EASY:
			return Vector2i(mid + rng.randi_range(-1, 1), mid + rng.randi_range(-1, 1))
		return Vector2i(mid, mid)

	var ranked := _rank(L, me, def_weight_hard if level == Level.HARD else DEF_WEIGHT[level])
	if ranked.is_empty():
		return _any_empty(L, me)

	# 1) 이길 수 있으면 바로 이김
	for r in ranked:
		if float(r[2]) >= S_FIVE:
			return r[1]

	if level == Level.EASY:
		# 상대 오목은 가끔만 막음
		for r in ranked:
			if float(r[3]) >= S_FIVE and rng.randf() < 0.7:
				return r[1]
		var top := mini(6, ranked.size())
		if rng.randf() < 0.35:
			return ranked[rng.randi() % top][1]
		var best: Array = ranked[0]
		var best_v := -INF
		for i in top:
			var v: float = float(ranked[i][0]) * rng.randf_range(0.6, 1.4)
			if v > best_v:
				best_v = v
				best = ranked[i]
		return best[1]

	# 2) 상대 오목 자리는 반드시 막음
	for r in ranked:
		if float(r[3]) >= S_FIVE:
			return r[1]

	# 3) 연속 4로 몰아붙여 이기는 수순(VCF)이 있으면 실행
	var vcf := find_vcf(L, me, 8 if level == Level.HARD else 3, 500 if level == Level.HARD else 120)
	if vcf.x >= 0:
		return vcf

	if level == Level.NORMAL:
		# 비슷한 점수끼리는 약간의 변화
		var top_v: float = ranked[0][0]
		var pool: Array = []
		for r in ranked:
			if float(r[0]) >= top_v * 0.97:
				pool.append(r)
		return pool[rng.randi() % pool.size()][1]

	# 3) 어려움: 열린 4 · 사삼 · 쌍사처럼 이기는 수가 있으면 바로 둠 (가장 센 것부터)
	var winning: Array = []
	for r in ranked:
		if float(r[2]) >= 100000.0:
			winning.append(r)
	if not winning.is_empty():
		winning.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
		return winning[0][1]

	# 상대에게 VCF 가 있으면, 그것을 끊는 수 중 가장 좋은 수
	var opp := 1 - me
	var opp_vcf := find_vcf(L, opp, 6, 250)
	if opp_vcf.x >= 0:
		var tries: Array = []
		for r in ranked:
			if r[1] == opp_vcf:
				tries.append(r)
		for k in mini(10, ranked.size()):
			if not tries.has(ranked[k]):
				tries.append(ranked[k])
		for r in tries:
			var c: Vector2i = r[1]
			var idx := c.y * L.size + c.x
			L.cells[idx] = me + 1
			var still := find_vcf(L, opp, 6, 150)
			L.cells[idx] = 0
			if still.x < 0:
				return c

	# 상위 후보마다 '그 뒤 상대가 만들 수 있는 가장 센 공격'을 빼서 비교
	var best_c: Vector2i = ranked[0][1]
	var best_val := -INF
	for k in mini(8, ranked.size()):
		var c: Vector2i = ranked[k][1]
		var idx := c.y * L.size + c.x
		L.cells[idx] = me + 1
		var reply_atk := 0.0
		for c2 in L.candidates(2):
			if L.is_forbidden(c2, opp):
				continue
			reply_atk = maxf(reply_atk, cell_score(L, c2, opp))
		L.cells[idx] = 0
		var my_atk: float = ranked[k][2]
		var penalty := 0.0 if my_atk >= 12000.0 else caution * reply_atk  # 내가 4를 만들면 상대는 막아야 함
		if reply_atk >= S_FIVE:
			penalty = S_FIVE * 2.0  # 상대가 바로 이기는 수는 절대 금지
		var v := float(ranked[k][0]) - penalty
		if v > best_val:
			best_val = v
			best_c = c
	return best_c


# ── VCF: 4를 연달아 두어 상대가 막을 수밖에 없게 몰아 이기는 수순 ──
var _budget: int = 0


## 이기는 연속 4 수순의 첫 수. 없으면 (-1, -1)
func find_vcf(L: OmokLogic, me: int, depth: int, budget: int) -> Vector2i:
	_budget = budget
	return _vcf(L, me, depth)


func _vcf(L: OmokLogic, me: int, depth: int) -> Vector2i:
	var none := Vector2i(-1, -1)
	if depth <= 0:
		return none
	var opp := 1 - me
	for c in L.candidates(2):
		if not L.may_make_four(c, me) or L.is_forbidden(c, me):
			continue
		_budget -= 1
		if _budget <= 0:
			return none
		var a := L.analyze(c, me)
		if a["five"] or int(a["open_fours"]) > 0 or int(a["fours"]) >= 2:
			return c
		if int(a["fours"]) != 1:
			continue
		var ci := c.y * L.size + c.x
		L.cells[ci] = me + 1
		var blocks := L.five_points_at(c, me)
		var wins := false
		if blocks.size() >= 2:
			wins = true
		elif blocks.size() == 1:
			var b: Vector2i = blocks[0]
			if L.is_forbidden(b, opp):
				wins = true  # 상대가 막을 자리가 금지 자리
			else:
				var bi := b.y * L.size + b.x
				L.cells[bi] = opp + 1
				# 상대가 막으면서 4를 만들면 이 수순은 실패
				if L.five_points_at(b, opp).is_empty():
					wins = _vcf(L, me, depth - 1).x >= 0
				L.cells[bi] = 0
		L.cells[ci] = 0
		if wins:
			return c
	return none


func _any_empty(L: OmokLogic, me: int) -> Vector2i:
	for i in L.size * L.size:
		var c := Vector2i(i % L.size, i / L.size)
		if L.is_empty(c) and not L.is_forbidden(c, me):
			return c
	return Vector2i(-1, -1)
