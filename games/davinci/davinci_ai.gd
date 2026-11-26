class_name DavinciAI
extends RefCounted
## 비밀 숫자 AI
## 내가 볼 수 있는 정보(내 타일, 공개된 타일, 타일 색, 줄 순서, 틀렸던 추측)만으로
## 상대 줄마다 "가능한 숫자 배치"를 모두 세어서 각 숨은 타일이 어떤 숫자일 확률을 계산
##  - 쉬움: 아무 타일이나 골라 대충 맞히기, 가끔 욕심내서 계속
##  - 보통: 가장 확률 높은 숫자로 맞히기, 꽤 확실할 때만 계속
##  - 어려움: 모든 정보 사용, 상황에 맞춰 계속할지 판단, 공개할 타일도 신중히 고름

enum Level { EASY, NORMAL, HARD }

var level: int = Level.NORMAL
var rng := RandomNumberGenerator.new()


func _init(lv: int = Level.NORMAL) -> void:
	level = lv
	rng.randomize()


## 뽑을 색: 남은 수가 많은 쪽 (쉬움은 아무거나)
func choose_draw(L: DavinciLogic, _me: int) -> int:
	var b := L.pool_count(0)
	var w := L.pool_count(1)
	if b == 0:
		return 1
	if w == 0:
		return 0
	if level != Level.HARD or b == w:
		return rng.randi() % 2
	return 0 if b > w else 1


## [상대, 위치, 숫자, 확률]
func choose_guess(L: DavinciLogic, me: int) -> Array:
	var probs := _all_probs(L, me, true)
	var best: Array = []
	var best_p := -1.0
	if probs.is_empty():
		return best
	if level == Level.EASY:
		# 숨은 타일 하나를 고르고, 가능한 숫자 중 무작위 (가끔은 가장 그럴듯한 것)
		var keys := probs.keys()
		var pick: Array = keys[rng.randi() % keys.size()]
		var dist: Dictionary = probs[pick]
		var nums := dist.keys()
		var num: int = nums[rng.randi() % nums.size()]
		if rng.randf() < 0.35:
			for k in nums:
				if float(dist[k]) > float(dist[num]):
					num = k
		return [pick[0], pick[1], num, float(dist[num])]
	for t in probs:
		var dist: Dictionary = probs[t]
		var hidden_left := L.hidden_count(int(t[0]))
		for num in dist:
			var p: float = dist[num]
			# 같은 확률이면 탈락 직전인 상대를 노림 + 약간의 무작위
			var score := p + (0.02 if hidden_left == 1 else 0.0) + rng.randf() * 0.001
			if score > best_p:
				best_p = score
				best = [t[0], t[1], num, p]
	return best


## 맞힌 뒤 한 번 더 맞힐지
func should_continue(L: DavinciLogic, me: int) -> bool:
	if L.alive_count() <= 1:
		return false
	var g := choose_guess(L, me)
	if g.is_empty():
		return false
	var p: float = g[3]
	if p >= 0.999:
		return true
	match level:
		Level.EASY:
			return rng.randf() < 0.2
		Level.NORMAL:
			return p >= 0.5
	# 어려움: 틀리면 뽑은 타일(또는 내 타일)이 공개되니, 내 숨은 타일이 적을수록 조심
	var my_hidden := L.hidden_count(me) + (1 if L.drawn >= 0 else 0)
	var need := 0.42
	if my_hidden <= 1:
		need = 0.7
	elif my_hidden <= 2:
		need = 0.55
	# 상대 하나만 남았고 그 상대가 숨은 타일이 1개면 과감하게
	if L.alive_count() == 2 and L.hidden_count(int(g[0])) == 1:
		need -= 0.1
	return p >= need


## 내 숨은 타일 중 하나를 공개해야 할 때: 남들이 어차피 쉽게 맞힐 타일부터
func choose_reveal(L: DavinciLogic, me: int) -> int:
	var hidden: Array = []
	for i in L.hands[me].size():
		if not L.revealed[me][i]:
			hidden.append(i)
	if hidden.is_empty():
		return -1
	if level != Level.HARD:
		return hidden[rng.randi() % hidden.size()]
	# 공개 정보만 아는 다른 사람 눈으로 내 줄을 계산해서 가장 확실한(정보 가치가 적은) 타일
	var others := -1
	for q in L.n:
		if q != me and not L.out[q]:
			others = q
			break
	var dist := _row_probs(L, others, me, true)
	var best := int(hidden[0])
	var best_p := -1.0
	for i in hidden:
		var d: Dictionary = dist[i]
		var mx := 0.0
		for k in d:
			mx = maxf(mx, float(d[k]))
		if mx > best_p:
			best_p = mx
			best = i
	return best


# ── 확률 계산 ──────────────────────────────────────────
## { [상대, 위치]: {숫자: 확률} }  (숨은 타일만)
func _all_probs(L: DavinciLogic, me: int, use_wrong: bool) -> Dictionary:
	var outd := {}
	for o in L.n:
		if o == me or L.out[o]:
			continue
		var rows := _row_probs(L, me, o, use_wrong)
		for i in rows.size():
			if L.revealed[o][i]:
				continue
			var d: Dictionary = rows[i]
			if d.is_empty():
				continue
			outd[[o, i]] = d
	return outd


## viewer 가 보기에 상대 o 의 줄 각 자리가 어떤 숫자일 확률. 결과[i] = {숫자: 확률}
func _row_probs(L: DavinciLogic, viewer: int, o: int, use_wrong: bool) -> Array:
	# viewer 가 모르는 키들
	var known := {}
	for q in L.n:
		for j in L.hands[q].size():
			if q == viewer or L.revealed[q][j]:
				known[L.hands[q][j]] = true
	if L.current == viewer and L.drawn >= 0:
		known[L.drawn] = true
	var h: Array = L.hands[o]
	var m := h.size()
	var cands: Array = []
	for i in m:
		var k: int = h[i]
		if L.revealed[o][i]:
			cands.append([k])
			continue
		var col := DavinciLogic.color_of(k)
		var ex: Array = L.wrong.get(k, []) if use_wrong else []
		var lst: Array = []
		for num in DavinciLogic.MAX_NUM + 1:
			var kk := DavinciLogic.key_of(num, col)
			if not known.has(kk) and not ex.has(num):
				lst.append(kk)
		cands.append(lst)
	# 앞에서부터 / 뒤에서부터 경우의 수 (줄은 항상 키가 커지는 순서)
	var fwd: Array = []
	for i in m:
		var d := {}
		for kv in cands[i]:
			var k: int = kv
			var ways := 0.0
			if i == 0:
				ways = 1.0
			else:
				var prev: Dictionary = fwd[i - 1]
				for pk in prev:
					if int(pk) < k:
						ways += float(prev[pk])
			if ways > 0.0:
				d[k] = ways
		fwd.append(d)
	var bwd: Array = []
	bwd.resize(m)
	for i in range(m - 1, -1, -1):
		var d := {}
		for kv in cands[i]:
			var k: int = kv
			var ways := 0.0
			if i == m - 1:
				ways = 1.0
			else:
				var nxt: Dictionary = bwd[i + 1]
				for nk in nxt:
					if int(nk) > k:
						ways += float(nxt[nk])
			if ways > 0.0:
				d[k] = ways
		bwd[i] = d
	var total := 0.0
	if m > 0:
		var last_d: Dictionary = fwd[m - 1]
		for k in last_d:
			total += float(last_d[k])
	var res: Array = []
	for i in m:
		var d := {}
		if total > 0.0:
			var f: Dictionary = fwd[i]
			var b: Dictionary = bwd[i]
			for k in f:
				if b.has(k):
					var pr := float(f[k]) * float(b[k]) / total
					if pr > 0.0:
						var num := DavinciLogic.num_of(int(k))
						d[num] = float(d.get(num, 0.0)) + pr
		res.append(d)
	return res
