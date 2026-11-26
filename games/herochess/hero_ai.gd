class_name HeroAI
extends RefCounted
## 히어로 체스 AI (3판 '이동 후 능력' 규칙) – 한 차례(영웅 두 명의 이동 + 능력, 또는 성 소환)를 통째로 계획해요
##  쉬움  : 첫 행동 후보 2개만 더 따져 보고, 평가에 큰 잡음
##  보통  : 좋은 첫 행동 3개마다 두 번째 행동까지 모두 따져 봄
##  어려움: 첫 행동 6개 × 두 번째 행동 + 가장 좋은 계획 3개는 상대의 한 차례(두 행동)까지 상대 입장에서 골라 보고
##          가장 나쁜 결과가 가장 나은 계획을 고름 (AI끼리 실험: 보통 상대 12승 4패, 예전 방식은 7승 9패)

enum Level { EASY, NORMAL, HARD }

const K := HeroLogic.Kind
## 영웅 가치 (기사, 병사, 천사, 마법사, 성직자, 로봇, 전사, 닌자, 사신, 건축가)
const VALUE := [5.0, 3.0, 3.5, 5.0, 3.5, 2.5, 5.0, 4.0, 6.0, 3.0]
const WIN := 100000.0
const LIFE := 450.0
const STOP := HeroLogic.STOP
const FIRST_TOP := [2, 3, 6]
const HARD_CHECK := 3      # 어려움: 상대 응수까지 따져 볼 내 계획 수
const REPLY_TOP := 2       # 어려움: 따져 볼 상대의 첫 행동 수 (상대 입장에서 좋은 순)
## 생각 시간 상한 (ms, 쉬움 · 보통 · 어려움). 좋은 후보부터 따지다가 넘으면 남은 후보는 건너뜀 (느린 폰 대비)
## 어려움은 상대 한 차례까지 따지느라 PC에서 평균 1초쯤. 1.5초로 끊으면 보통 상대 9승 7패, 3초면 12승 4패라 3초
const BUDGET_MS := [800, 1200, 3000]
const TURRET := 260.0      # 포탑 하나의 가치
const BARRIER := 20.0      # 배리어 하나의 가치
const OWN_WALL := 8.0      # 자기 벽을 허물 때의 손해 (이득이 있을 때만 허물게)
const HORSE := 60.0        # 말 하나의 가치 (공격을 한 번 대신 맞음)
const DARK := 40.0         # 흑기사 (다음 차례에 주위 8칸 공격)
## 유령의 가치 (그 영웅 가치에 곱함): 내 천사가 다음 행동으로 부활시킬 수 있음 / 천사가 살아 있음 / 천사가 없음
const GHOST_NEAR := 0.42
const GHOST_FAR := 0.2
const GHOST_LOST := 0.04

var level: int
var _foe_turrets: Array[Vector2i] = []   # 위협을 계산하는 동안 상대 포탑 칸들
var _foe_mine := 0                       # 위협을 계산하는 동안 상대 지뢰 값 (1 · 2)
var rng := RandomNumberGenerator.new()


func _init(p_level: int = Level.NORMAL) -> void:
	level = p_level
	rng.randomize()


## 이번 차례 계획: {"summon": 영웅, "cell": 칸} 또는 {"taps": [영웅, 칸, 칸…]} 를 두 개까지 (빈 배열 = 할 게 없음)
func plan(L: HeroLogic) -> Array:
	var t_start := Time.get_ticks_msec()
	var me := L.current
	var noise := 260.0 if level == Level.EASY else 4.0
	var cands: Array = []   # [점수, 계획, 끝난 뒤 상태]
	# 하나의 행동 [계획 한 단계, 끝난 뒤 상태, 허문 자기 벽 수, 영웅(성 소환은 -1)]
	var firsts := _units(L)
	var scored: Array = []
	for f in firsts:
		var S: HeroLogic = f[1]
		var v: float
		if S.over or S.current != me:
			v = _end_value(S, me)
			cands.append([v + rng.randf_range(0.0, noise) - OWN_WALL * f[2], [f[0]], S])
		else:
			v = _mid_value(S, me)
		scored.append([v + rng.randf_range(0.0, noise) - OWN_WALL * f[2], f])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if level == Level.EASY and scored.size() > 1 and rng.randf() < 0.3:
		var odd: Array = scored[rng.randi() % scored.size()]
		if odd[1][3] >= 0:   # 하트를 쓰는 성 소환은 아무렇게나 고르지 않음
			scored.push_front(odd)

	var tried := 0
	var seen := {}
	for s in scored:
		if tried >= FIRST_TOP[level]:
			break
		if tried > 0 and Time.get_ticks_msec() - t_start > BUDGET_MS[level]:
			break
		var f: Array = s[1]
		var S: HeroLogic = f[1]
		if S.over or S.current != me:
			continue
		# 같은 영웅의 비슷한 행동만 여러 번 따지지 않게 (영웅마다 2개까지)
		var hero: int = f[3]
		seen[hero] = int(seen.get(hero, 0)) + 1
		if seen[hero] > 2:
			continue
		tried += 1
		var E := S.clone()
		E.end_turn()
		cands.append([_end_value(E, me) + rng.randf_range(0.0, noise) - OWN_WALL * f[2], [f[0]], E])
		for g in _units(S):
			cands.append([_end_value(g[1], me) + rng.randf_range(0.0, noise) - OWN_WALL * (f[2] + g[2]), [f[0], g[0]], g[1]])
	if cands.is_empty():
		return []
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if level != Level.HARD:
		return cands[0][1]

	# 어려움: 좋은 계획마다 상대의 한 차례(두 행동)를 상대 입장에서 골라 보고, 가장 나쁜 결과가 가장 나은 계획
	var best_v := -INF
	var best: Array = cands[0][1]
	for i in mini(HARD_CHECK, cands.size()):
		if i > 0 and Time.get_ticks_msec() - t_start > BUDGET_MS[level]:
			break
		var S: HeroLogic = cands[i][2]
		var worst: float
		if S.over or S.current == me:
			worst = float(cands[i][0])
		else:
			worst = _reply_worst(S, me, best_v)
		worst += float(cands[i][0]) * 0.001
		if worst > best_v:
			best_v = worst
			best = cands[i][1]
	return best


## 상대 차례 S 에서 상대가 두는 한 차례를 따져 본 뒤 내 점수의 최솟값
## 상대의 첫 행동은 상대 입장에서 좋은 것 REPLY_TOP 개, 두 번째 행동은 상대 입장에서 가장 좋은 것
func _reply_worst(S: HeroLogic, me: int, cutoff: float) -> float:
	var opp := 1 - me
	var firsts := all_actions(S)
	if firsts.is_empty():
		return _end_value(S, me)
	var scored: Array = []
	for r in firsts:
		var R: HeroLogic = r[1]
		var v := _end_value(R, opp) if R.over or R.current != opp else _mid_value(R, opp)
		scored.append([v, R])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var worst := INF
	for j in mini(REPLY_TOP, scored.size()):
		var R: HeroLogic = scored[j][1]
		var mine: float
		if R.over or R.current != opp:
			mine = _end_value(R, me)
		else:
			# 두 번째 행동: 한 명만 쓰고 끝내기 포함, 상대에게 가장 좋은 것
			var pick := R.clone()
			pick.end_turn()
			var best_o := _end_value(pick, opp)
			for r2 in all_actions(R):
				var v2 := _end_value(r2[1], opp)
				if v2 > best_o:
					best_o = v2
					pick = r2[1]
			mine = _end_value(pick, me)
		worst = minf(worst, mine)
		if worst <= cutoff:
			break
	return worst


## 지금 차례인 사람이 할 수 있는 모든 행동 하나(영웅 행동과 성 소환): [계획 한 단계, 끝난 뒤 상태, 허문 자기 벽 수, 영웅(성 소환은 -1)]
func _units(L: HeroLogic) -> Array:
	var out: Array = []
	for f in all_actions(L):
		out.append([{"taps": f[0]}, f[1], f[2], f[0][0]])
	var cells := L.summon_cells()
	for g in L.summon_ids():
		for c in cells:
			var S := L.clone()
			S.do_summon(g, c)
			out.append([{"summon": g, "cell": c}, S, 0, -1])
	return out


## 지금 차례인 사람이 고를 수 있는 모든 영웅 행동 하나: [[영웅, 칸, 칸…], 끝난 뒤 상태, 허문 자기 벽 수]
func all_actions(L: HeroLogic) -> Array:
	var out: Array = []
	for id in L.selectable():
		var S := L.clone()
		S.begin_action(id)
		_dfs(S, [id], out)
	return out


func _dfs(S: HeroLogic, taps: Array, out: Array, own: int = 0) -> void:
	if S.act_hero < 0 or S.over:
		out.append([taps, S, own])
		return
	if S.act_optional:
		var U := S.clone()
		U.stop_action()
		_dfs(U, taps + [STOP], out, own) 
	var opts := S.step_options()
	var laid := false
	for c in opts:
		var mine := 0
		if str(opts[c]) == "return" and opts.size() > 1:
			continue   # 내려앉아 그냥 돌아가는 것은 제자리와 같음
		if str(opts[c]).begins_with("mine"):
			if laid:
				continue   # 지뢰는 어느 칸을 눌러도 상하좌우 모두에 놓음
			laid = true
		if str(opts[c]) == "break" and S.wall_owner(S.pos[S.act_hero], HeroLogic.real_cell(c)) == HeroLogic.owner_of(S.act_hero):
			mine = 1
		var U := S.clone()
		U.choose(c)
		if str(opts[c]) == "land" and U.act_step == HeroLogic.Step.LAND and U.step_options().size() == 1:
			continue   # 공격할 적이 없는 내려앉기
		_dfs(U, taps + [c], out, own + mine)


# ══════════════════════════════════════════════════════
#  평가
# ══════════════════════════════════════════════════════
func _terminal(S: HeroLogic, me: int) -> float:
	if S.winner == me:
		return WIN - S.turn
	if S.winner == 1 - me:
		return -WIN + S.turn
	return 0.0


## 내 차례가 끝난 뒤 (보통 상대가 둘 차례)
func _end_value(S: HeroLogic, me: int) -> float:
	if S.over:
		return _terminal(S, me)
	var v := _static(S, me)
	if S.current == me:
		v += _threat(S, me, 2) * 0.7 - _threat(S, 1 - me, 1) * 0.3
		v += _ghost_risk(S, 1 - me, 2) * 0.6
	else:
		v += _threat(S, me, 1) * 0.3 - _threat(S, 1 - me, 2) * 0.85
		v -= _ghost_risk(S, me, 2) * 0.8   # 상대(성직자 · 천사)가 다음 차례에 내 유령을 없앨 수 있음
	return v


## 첫 행동 뒤 (내가 한 번 더 움직일 수 있음)
func _mid_value(S: HeroLogic, me: int) -> float:
	if S.over:
		return _terminal(S, me)
	var v := _static(S, me) + _threat(S, me, 1) * 0.85 - _threat(S, 1 - me, 2) * 0.6
	return v + _ghost_risk(S, 1 - me, 1) * 0.6 - _ghost_risk(S, me, 2) * 0.6


func _static(S: HeroLogic, me: int) -> float:
	var v := float(S.lives[me] - S.lives[1 - me]) * LIFE
	for id in HeroLogic.KINDS * 2:
		var p: Vector2i = S.pos[id]
		if p == HeroLogic.NONE:
			if S.has_ghost(id):
				v += (1.0 if HeroLogic.owner_of(id) == me else -1.0) * _ghost_value(S, id)
			elif HeroLogic.kind_of(id) == K.ANGEL and S.cross[HeroLogic.owner_of(id)] >= 0 and S.alive(id - K.ANGEL + K.PRIEST):
				v += (1.0 if HeroLogic.owner_of(id) == me else -1.0) * 30.0   # 성직자가 희생해 부활시킬 수 있음
			continue
		var o := HeroLogic.owner_of(id)
		var k := HeroLogic.kind_of(id)
		var sgn := 1.0 if o == me else -1.0
		var val: float = VALUE[k] * 100.0
		if S.disabled_by[id] >= 0:
			val *= 0.6
		if S.horse[id] != 0:
			val += HORSE
		if S.dark[id] != 0:
			val += DARK
		if S.barrier[id] != 0 and k != K.ROBOT:
			val += BARRIER   # 깨질 때까지 목숨 하나 (지금 막아 줄 위협은 위협 계산에서 봄)
		if S.cursed_by[id] >= 0:
			val *= 0.8   # 사신이 언제든 잡으러 올 수 있음
		var target: Vector2i = HeroLogic.CASTLE[1 - o]
		var d := absi(p.x - target.x) + absi(p.y - target.y)
		match k:
			K.ANGEL:
				val += (20 - d) * 2.0
				# 유령을 부활시킬 수 있는 가치는 _ghost_value 에서
			K.MAGICIAN:
				val += (20 - d) * 3.0
			K.ROBOT, K.ARCHITECT, K.PRIEST:
				val += (20 - d) * 1.5
			K.REAPER:
				val += (20 - d) * 3.0
			_:
				val += (20 - d) * 5.0
		v += sgn * val
	return v + _house_value(S, me)


## 포탑과 짓는 중인 한 칸짜리 집 (한 편의 벽만 2~3개인 빈 칸은 건축가가 살아 있으면 그 편 몫으로 봄)
func _house_value(S: HeroLogic, me: int) -> float:
	var v := 0.0
	var a0: Vector2i = S.pos[K.ARCHITECT]
	var a1: Vector2i = S.pos[HeroLogic.KINDS + K.ARCHITECT]
	var builders: bool = a0 != HeroLogic.NONE or a1 != HeroLogic.NONE
	var W := HeroLogic.W
	for i in W * HeroLogic.H:
		var t: int = S.turret[i]
		if t != 0:
			var tp := t - 1
			v += TURRET if tp == me else -TURRET
			continue
		if not builders:
			continue
		var x := i % W
		var y := i / W
		if x == 0 or y == 0 or x == W - 1 or y == HeroLogic.H - 1 or S.grid[i] >= 0:
			continue
		var w: int = int(S.wall_v[i] != 0) + int(S.wall_v[i - 1] != 0) + int(S.wall_h[i] != 0) + int(S.wall_h[i - W] != 0)
		if w < 2:
			continue
		# 벽 값 1 = 플레이어 0, 2 = 플레이어 1. 두 편 벽이 섞인 칸은 포탑이 될 수 없음
		var sum: int = S.wall_v[i] + S.wall_v[i - 1] + S.wall_h[i] + S.wall_h[i - W]
		var owner := 0 if sum == w else (1 if sum == w * 2 else -1)
		if owner < 0 or (a0 if owner == 0 else a1) == HeroLogic.NONE or S.is_castle(Vector2i(x, y)):
			continue
		var val := 12.0 if w == 2 else 45.0
		v += val if owner == me else -val
	return v


## q 의 유령 중 상대가 다음 행동 한 번으로 없앨 수 있는 것의 가치 (큰 것 n개 합)
## 성직자(이동 1칸 + 상하좌우 십자가)와 천사(내려앉기)만 유령을 없앰
func _ghost_risk(S: HeroLogic, q: int, n: int) -> float:
	var foe := 1 - q
	var pr: int = foe * HeroLogic.KINDS + K.PRIEST
	var an: int = foe * HeroLogic.KINDS + K.ANGEL
	var pr_ok: bool = S.alive(pr) and S.disabled_by[pr] < 0 and S.sealed[pr] == 0 and S.stunned[pr] == 0
	var an_ok: bool = S.alive(an) and S.disabled_by[an] < 0 and S.sealed[an] == 0 and S.stunned[an] == 0
	var rp: int = foe * HeroLogic.KINDS + K.REAPER
	var rp_ok: bool = S.alive(rp) and S.disabled_by[rp] < 0 and S.sealed[rp] == 0 and S.stunned[rp] == 0
	if not pr_ok and not an_ok and not rp_ok:
		return 0.0
	var risk: Array[float] = []
	var stands: Dictionary = S.move_paths(pr, -1, false) if pr_ok else {}
	for k in HeroLogic.KINDS:
		var g := q * HeroLogic.KINDS + k
		if not S.has_ghost(g):
			continue
		var c: Vector2i = S.ghost_pos[g]
		var hit := false
		if pr_ok and absi(S.pos[pr].x - c.x) + absi(S.pos[pr].y - c.y) <= 2:
			for m: Vector2i in stands:
				if absi(m.x - c.x) + absi(m.y - c.y) == 1 and not S._hit_stopped(m, c, foe):
					hit = true
					break
		if not hit and an_ok:
			hit = _angel_at(S, an, c)
		if not hit and rp_ok:
			hit = S.cursed_by[g] >= 0   # 사신이 거리와 상관없이 없애러 옴
		if hit:
			risk.append(maxf(0.0, _ghost_value(S, g)))
	risk.sort()
	var total := 0.0
	for i in mini(n, risk.size()):
		total += risk[risk.size() - 1 - i]
	return total


## 천사 an 이 이번에 유령이 있는 칸 c 에 갈 수 있는지
func _angel_at(S: HeroLogic, an: int, c: Vector2i) -> bool:
	return _angel_line(S, S.pos[an], c)


## 유령의 가치: 내 천사가 다음에 부활시킬 수 있으면 크고, 아니면 천사와 가까울수록
func _ghost_value(S: HeroLogic, id: int) -> float:
	var o := HeroLogic.owner_of(id)
	var base: float = VALUE[HeroLogic.kind_of(id)] * 100.0
	var an: int = o * HeroLogic.KINDS + K.ANGEL
	if not S.alive(an):
		return base * GHOST_LOST
	var gp: Vector2i = S.ghost_pos[id]
	var keep := 0.7 if S.cursed_by[id] >= 0 else 1.0   # 저주에 걸린 유령은 사신이 언제든 없앨 수 있음
	if S.sealed[an] == 0 and S._home_room(an) > 0 and _angel_at(S, an, gp):
		return base * GHOST_NEAR * keep
	var p: Vector2i = S.pos[an]
	return keep * maxf(base * GHOST_LOST, base * GHOST_FAR - (absi(gp.x - p.x) + absi(gp.y - p.y)) * 4.0)


## 칸 c 의 네 변 중 셋이 q 의 벽이고 하나가 비었으면 그 변 너머의 칸 (아니면 NONE, 판 가장자리는 벽이 아님)
func _cage_gap(S: HeroLogic, c: Vector2i, q: int) -> Vector2i:
	if c.x == 0 or c.y == 0 or c.x == HeroLogic.W - 1 or c.y == HeroLogic.H - 1 or S.ghost_at(c) >= 0:
		return HeroLogic.NONE
	var gap := HeroLogic.NONE
	for d in HeroLogic.DIRS4:
		var o := S.wall_owner(c, c + d)
		if o == 1 - q:
			return HeroLogic.NONE
		if o < 0:
			if gap != HeroLogic.NONE:
				return HeroLogic.NONE
			gap = c + d
	return gap


## q 가 다음 차례에 바로 얻을 수 있는 이득: 영웅마다 가장 큰 이득 중 큰 것 n개의 합 (대략)
## 이동한 뒤 능력으로 닿는지만 자리로 바로 따짐 (길 전체를 만들지 않아 빠름)
## 두 명이 같은 적을 노리면 둘 다 셈 (겹치지 않게 세는 것보다 AI끼리 19승 5패로 나았음)
func _threat(S: HeroLogic, q: int, n: int) -> float:
	var vc: Array[Vector2i] = []
	var vv: Array[float] = []
	var doom := 0.0
	var doom_i := -1
	for e in S.heroes_of(1 - q):
		if S._immune(e):
			continue
		vc.append(S.pos[e])
		vv.append(_hit_value(S, e))
		if S.cursed_by[e] >= 0 and VALUE[HeroLogic.kind_of(e)] * 100.0 > doom:
			doom = VALUE[HeroLogic.kind_of(e)] * 100.0
			doom_i = vc.size() - 1
	# 세 변이 벽인 적 영웅: 마지막 변 너머의 칸(건축가가 설 곳)과 이득
	var cages: Array[Vector2i] = []
	var cage_v: Array[float] = []
	for e in S.heroes_of(1 - q):
		var gap := _cage_gap(S, S.pos[e], q)
		if gap != HeroLogic.NONE:
			cages.append(gap)
			cage_v.append(VALUE[HeroLogic.kind_of(e)] * 100.0 + TURRET)
	_foe_mine = 2 - q
	_foe_turrets.clear()
	for i in S.turret.size():
		if S.turret[i] == 2 - q:
			_foe_turrets.append(Vector2i(i % HeroLogic.W, i / HeroLogic.W))
	var auras := S._aura_cells(1 - q)
	var foe: Vector2i = HeroLogic.CASTLE[1 - q]
	var mine := S.heroes_of(q)
	var robot: int = q * HeroLogic.KINDS + K.ROBOT
	var pairs: Array = []   # [이득, 영웅, 목표 번호(-1 = 성)]
	var hitters := 0
	for id in mine:
		var k := HeroLogic.kind_of(id)
		if k == K.ROBOT or S.sealed[id] != 0 or S.stunned[id] != 0:   # 봉인 · 스턴된 영웅은 다음 차례에 능력을 못 씀
			continue
		var f := 1.0
		if S.disabled_by[id] >= 0:
			# 무력해도 로봇이 적 전사를 밀어 풀어 준 뒤 쓸 수 있음
			if n < 2 or S.pos[robot] == HeroLogic.NONE:
				continue
			f = 0.45
		var p: Vector2i = S.pos[id]
		# 지금 자리에서 쓸 수 있는 모습들 (닌자는 앞 · 뒤 줄 영웅의 모습)
		var forms: Array = [k]
		if k == K.NINJA:
			for src in S.ninja_sources(id):
				var sk := S.form_of(src)
				if sk != K.ROBOT and not forms.has(sk):
					forms.append(sk)
		var castle := false
		for fk in forms:
			if not castle and HeroLogic._can_siege(id) and _castle_reach(S, fk, p, foe, q, auras, id):
				castle = true
			if fk == K.ARCHITECT:
				# 벽 3개로 둘러싸인 적의 마지막 변을 막으면 쓰러뜨리고 포탑이 됨
				for i in cages.size():
					if _reach(S, K.ARCHITECT, p, cages[i], auras):
						pairs.append([cage_v[i] * f, id, -2 - i])
			if fk == K.NINJA or fk == K.ARCHITECT:
				continue
			for i in vc.size():
				var h := _can_hit(S, fk, p, vc[i], q, id, auras, mine, n)
				if h > 0.0:
					pairs.append([vv[i] * h * f, id, i])
			if fk == K.REAPER and doom_i >= 0:
				pairs.append([doom * f, id, doom_i])
		if castle:
			if f == 1.0:
				hitters += 1
			pairs.append([LIFE * f, id, -1])
	var left := S.lives[1 - q]
	if hitters > 0 and mini(hitters, n) >= left:
		return WIN * 0.4
	if pairs.is_empty():
		return 0.0
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total := 0.0
	var used_h := 0
	var got := 0
	for pr in pairs:
		var hb: int = 1 << int(pr[1])
		if used_h & hb:
			continue
		used_h |= hb
		total += pr[0]
		got += 1
		if got >= n:
			break
	return total


## 칸 p 의 k 모습이 이번에 움직여 칸 n 에 설 수 있는지 (n 은 빈칸이거나 제자리. 상대 전사 주위 8칸이면 능력을 못 쓰므로 X)
func _reach(S: HeroLogic, k: int, p: Vector2i, n: Vector2i, auras: Array[Vector2i]) -> bool:
	if n == p:
		return true
	if S.in_bounds(n) and S.mines[n.y * HeroLogic.W + n.x] == _foe_mine:   # 상대 지뢰에 멈추면 맞음
		return false
	for tc in _foe_turrets:   # 상대 포탑 주위 8칸에 멈추면 바로 맞음
		if HeroLogic.cheb(tc, n) == 1:
			return false
	var d := n - p
	var m := absi(d.x) + absi(d.y)
	match k:
		K.REAPER:
			return m == 1 and S.is_free(n)   # 벽을 통과함
		K.WARRIOR:
			return m == 1 and S.is_free(n) and not S.has_wall(p, n)
		K.PRIEST:
			return m == 1 and S.is_free(n) and not S.has_wall(p, n) and not HeroLogic._in_aura(n, auras)
		K.ANGEL:
			return _angel_line(S, p, n) and S.is_free(n)
		K.KNIGHT, K.SOLDIER:
			if m > 2 or not S.is_free(n) or HeroLogic._in_aura(n, auras):
				return false
			if k == K.KNIGHT and m == 2:
				var who := S.at(p)
				if who >= 0 and S.form_of(who) == K.KNIGHT and S.horse[who] == 0:
					return false   # 말이 없으면 1칸
			if m == 1:
				return not S.has_wall(p, n)
			if d.x == 0 or d.y == 0:
				return _mid_ok(S, p, p + d / 2, n)
			return k == K.SOLDIER and (_mid_ok(S, p, Vector2i(n.x, p.y), n) or _mid_ok(S, p, Vector2i(p.x, n.y), n))
		K.ARCHITECT, K.NINJA:
			# 닌자는 가로 · 세로, 건축가는 8방향으로 막힐 때까지
			if d.x != 0 and d.y != 0 and (k == K.NINJA or absi(d.x) != absi(d.y)):
				return false
			if HeroLogic._in_aura(n, auras):
				return false
			var st := Vector2i(signi(d.x), signi(d.y))
			var c := p
			while c != n:
				var nx: Vector2i = c + st
				if not S.is_open(nx) or S._step_walled(c, nx):
					return false
				c = nx
			return S.is_free(n)
	return false


func _mid_ok(S: HeroLogic, a: Vector2i, mid: Vector2i, b: Vector2i) -> bool:
	return S.is_open(mid) and not S.has_wall(a, mid) and not S.has_wall(mid, b)


## k 모습이 움직인 뒤 상대 성을 칠 수 있는지 (로봇 · 건축가 · 닌자가 아니면 맞닿은 성은 누구나, 마법사는 3칸 파이어볼)
func _castle_reach(S: HeroLogic, k: int, p: Vector2i, foe: Vector2i, q: int, auras: Array[Vector2i], id: int) -> bool:
	var far := absi(p.x - foe.x) + absi(p.y - foe.y)
	if k == K.MAGICIAN:
		return far <= HeroLogic.FIRE_RANGE and _ball_hits(S, p, foe, q, HeroLogic.FIRE_RANGE)
	if far > 4:
		return false
	for d in HeroLogic.DIRS4:
		var c: Vector2i = foe + d
		if not S.in_bounds(c) or (k == K.REAPER and HeroLogic._in_aura(c, auras)) or S._hit_stopped(c, foe, q):
			continue
		if _reach(S, k, p, c, auras):
			return true
		if k == K.ANGEL and _land_ok(S, p, c, id):
			return true
	return false


## 천사가 p 에서 c 로 갈 수 있는 줄인지 (상하좌우 한 방향 2칸 이하, 성과 벽은 못 넘음)
func _angel_line(S: HeroLogic, p: Vector2i, c: Vector2i) -> bool:
	var d := c - p
	var m := maxi(absi(d.x), absi(d.y))
	if m > HeroLogic.ANGEL_STEPS or (d.x != 0 and d.y != 0):
		return false
	var st := Vector2i(signi(d.x), signi(d.y))
	for i in m:
		var a := p + st * i
		if (i > 0 and S.is_castle(a)) or S.has_wall(a, a + st):
			return false
	return true


func _land_ok(S: HeroLogic, p: Vector2i, c: Vector2i, id: int) -> bool:
	if not _angel_line(S, p, c):
		return false
	var o := S.at(c)
	return o >= 0 and o != id and S.can_land_on(o, id)


## 칸 p 에서 쏜 파이어볼이 reach 칸 안의 칸 v 에 닿는지 (사이의 영웅 · 성과 상대의 벽 · 포탑에 막힘)
func _ball_hits(S: HeroLogic, p: Vector2i, v: Vector2i, q: int, reach: int) -> bool:
	var d := v - p
	if d.x != 0 and d.y != 0:
		return false
	var m := absi(d.x) + absi(d.y)
	if m == 0 or m > reach:
		return false
	var st := Vector2i(signi(d.x), signi(d.y))
	var c := p
	for i in m:
		var nx: Vector2i = c + st
		if not S.in_bounds(nx) or (nx != v and (S.is_castle(nx) or S.at(nx) >= 0)) or S._shot_stopped(c, nx, q):
			return false
		c = nx
	return true


## 칸 p 의 k 모습이 움직인 뒤 칸 v 의 적을 칠 수 있는지 (1 = 됨, 0.7 = 아군이 먼저 옆에 가 주면 됨(천사), 0 = 안 됨)
func _can_hit(S: HeroLogic, k: int, p: Vector2i, v: Vector2i, q: int, id: int, auras: Array[Vector2i], mine: Array[int], n: int) -> float:
	var m := absi(p.x - v.x) + absi(p.y - v.y)
	match k:
		K.MAGICIAN:
			return 1.0 if m <= HeroLogic.FIRE_RANGE and _ball_hits(S, p, v, q, HeroLogic.FIRE_RANGE) else 0.0
		K.KNIGHT:
			var kn := S.at(p)
			if kn >= 0 and S.dark[kn] != 0:
				# 흑기사: 움직인 뒤 주위 8칸
				for d in HeroLogic.DIRS8:
					var st0: Vector2i = v - d
					if S.in_bounds(st0) and not S._hit_stopped(st0, v, q) and _reach(S, k, p, st0, auras):
						return 1.0
				return 0.0
			var tv := S.at(v)
			if kn >= 0 and S.horse[kn] != 0 and S.barrier[kn] == 0 and tv >= 0 and S.form_of(tv) == K.REAPER:
				# 사신의 대각선에 서면 흑기사가 되어 사신을 칠 수 있음
				for d in HeroLogic.DIAG:
					var st1: Vector2i = v - d
					if S.in_bounds(st1) and _reach(S, k, p, st1, auras):
						return 1.0
			# 움직인 방향의 다음 칸
			if m > 3 or (p.x != v.x and p.y != v.y):
				return 0.0
			var d := Vector2i(signi(v.x - p.x), signi(v.y - p.y))
			var stand: Vector2i = v - d
			return 1.0 if m >= 2 and not S._hit_stopped(stand, v, q) and _reach(S, k, p, stand, auras) else 0.0
		K.WARRIOR, K.SOLDIER, K.PRIEST:
			# 움직인 뒤(전사 · 성직자 1칸, 병사 2칸) 상하좌우
			if m > (3 if k == K.SOLDIER else 2):
				return 0.0
			for d in HeroLogic.DIRS4:
				var st2: Vector2i = v - d
				if S.in_bounds(st2) and not S._hit_stopped(st2, v, q) and _reach(S, k, p, st2, auras):
					return 1.0
		K.REAPER:
			var ve := S.at(v)
			if m > 3 or (ve >= 0 and (_shielded(S, ve) or S.horse[ve] != 0)):   # 배리어가 있거나 말을 탄 적에게는 자동 공격이 안 통함
				return 0.0
			for d in HeroLogic.DIAG:
				var st3: Vector2i = v - d
				if S.in_bounds(st3) and _reach(S, k, p, st3, auras):
					return 1.0
		K.ANGEL:
			if m > HeroLogic.ANGEL_STEPS + 1:
				return 0.0
			var best := 0.0
			for d in HeroLogic.DIRS4:
				var c: Vector2i = v - d
				if not S.in_bounds(c) or S.is_castle(c) or S._hit_stopped(c, v, q):
					continue
				if _land_ok(S, p, c, id):
					return 1.0
				if n >= 2 and best == 0.0 and _angel_line(S, p, c) and S.is_free(c):
					# 아군이 먼저 그 칸에 서 주면 내려앉아 칠 수 있음
					for h in mine:
						var hk := HeroLogic.kind_of(h)
						if h != id and hk != K.ROBOT and hk != K.MAGICIAN and S.disabled_by[h] < 0 and _reach(S, hk, S.pos[h], c, auras):
							best = 0.7
							break
			return best
	return 0.0


## 적 영웅 하나를 공격하는 이득 (배리어가 있으면 배리어만, 말이 있으면 말만)
func _hit_value(S: HeroLogic, e: int) -> float:
	if _shielded(S, e):
		return 60.0
	if S.horse[e] != 0:
		return HORSE
	return VALUE[HeroLogic.kind_of(e)] * 100.0


## e 에게 배리어가 있는지 (깨질 때까지 유지)
func _shielded(S: HeroLogic, e: int) -> bool:
	return S.barrier[e] != 0


## 배치 단계: 정해진 배치 중 하나를 골라요
func choose_formation(L: HeroLogic, me: int) -> void:
	L.random_formation(me, rng)
