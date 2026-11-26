extends SceneTree
## 타일 러미 로직/AI 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_rummy_logic.gd

var _fail := 0
var _rng := RandomNumberGenerator.new()
const J := RummyLogic.JOKER_A


func _init() -> void:
	_rng.seed = 2024
	_test_analyze()
	_test_commit_rules()
	_test_ai_meld()
	_test_ai_layoff()
	for n in [2, 3, 4]:
		_selfplay(n, 3)
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


## 색(0 빨강 1 파랑 2 노랑 3 검정), 숫자, 벌(0/1) → 타일 번호
func t(c: int, num: int, copy: int = 0) -> int:
	return copy * 52 + RummyLogic.kind_of(c, num)


func _test_analyze() -> void:
	var a := RummyLogic.analyze([t(0, 5), t(1, 5), t(3, 5)])
	_check(a["ok"] and a["kind"] == "group" and int(a["value"]) == 15, "group of three 5s")
	_check(not RummyLogic.analyze([t(0, 5), t(0, 5, 1), t(3, 5)])["ok"], "same color twice in group")
	_check(not RummyLogic.analyze([t(0, 5), t(1, 5)])["ok"], "two tiles not a set")
	_check(not RummyLogic.analyze([t(0, 5), t(1, 5), t(2, 5), t(3, 5), J])["ok"], "group max 4")
	a = RummyLogic.analyze([t(1, 7), t(1, 5), t(1, 6)])
	_check(a["ok"] and a["kind"] == "run" and int(a["value"]) == 18, "run 5-6-7")
	_check(a["order"] == [t(1, 5), t(1, 6), t(1, 7)], "run ordered")
	_check(not RummyLogic.analyze([t(1, 5), t(1, 6), t(0, 7)])["ok"], "mixed colors run")
	_check(not RummyLogic.analyze([t(1, 12), t(1, 13), t(1, 1)])["ok"], "no wrap 12-13-1")
	a = RummyLogic.analyze([t(2, 4), J, t(2, 6)])
	_check(a["ok"] and a["kind"] == "run" and int(a["value"]) == 15 and (a["order"] as Array)[1] == J, "joker fills gap")
	a = RummyLogic.analyze([t(2, 12), t(2, 13), J])
	_check(a["ok"] and int(a["value"]) == 36, "joker extends down at the top: 11-12-13")
	a = RummyLogic.analyze([t(0, 9), t(3, 9), J])
	_check(a["ok"] and a["kind"] == "group" and int(a["value"]) == 27, "joker in group")
	a = RummyLogic.analyze([t(0, 5), J, J + 1])
	_check(a["ok"] and a["kind"] == "run" and int(a["value"]) == 18, "two jokers: best value run 5-6-7")
	var long: Array = []
	for v in range(1, 14):
		long.append(t(3, v))
	_check(RummyLogic.analyze(long)["ok"], "full run 1-13")


func _logic_with(rack: Array, table: Array, melded: bool) -> RummyLogic:
	var L := RummyLogic.new()
	L.setup(2, _rng, 0)
	L.racks[0] = rack.duplicate()
	L.table = table.duplicate(true)
	L.melded[0] = melded
	L.current = 0
	return L


func _test_commit_rules() -> void:
	var L := _logic_with([t(0, 10), t(1, 10), t(2, 10), t(0, 1), t(0, 2)], [[t(3, 1), t(3, 2), t(3, 3)]], false)
	var tbl: Array = L.table.duplicate(true)
	tbl.append([t(0, 1), t(0, 2)])
	_check(L.commit(tbl) != "", "invalid set rejected")
	tbl = L.table.duplicate(true)
	_check(L.commit(tbl) != "", "must play at least one tile")
	tbl = L.table.duplicate(true)
	tbl.append([t(0, 1), t(0, 2), t(0, 3, 1)])
	_check(L.commit(tbl) != "", "tile not in rack rejected")
	# 처음 등록 30점 미만
	var M := _logic_with([t(0, 5), t(1, 5), t(2, 5), t(0, 9)], [], false)
	_check(M.commit([[t(0, 5), t(1, 5), t(2, 5)]]).contains("30"), "initial meld under 30 rejected")
	# 처음 등록 때 판 타일 사용 금지
	var N := _logic_with([t(0, 10), t(1, 10), t(2, 10), t(3, 4)], [[t(3, 1), t(3, 2), t(3, 3)]], false)
	_check(N.commit([[t(0, 10), t(1, 10), t(2, 10)], [t(3, 1), t(3, 2), t(3, 3), t(3, 4)]]) != "", "cannot extend table on initial meld")
	_check(N.commit([[t(3, 1), t(3, 2), t(3, 3)], [t(0, 10), t(1, 10), t(2, 10)]]) == "", "valid 30-point meld")
	_check(N.melded[0] and N.current == 1 and (N.racks[0] as Array).size() == 1, "meld applied")
	# 등록 뒤에는 판을 자유롭게
	N.current = 0
	_check(N.commit([[t(3, 1), t(3, 2), t(3, 3), t(3, 4)], [t(0, 10), t(1, 10), t(2, 10)]]) == "" and N.over and N.winner == 0, "extend and win")
	# 판 타일을 손으로 가져오기 금지
	var P := _logic_with([t(1, 4), t(1, 9)], [[t(0, 4), t(2, 4), t(3, 4), t(1, 4, 1)]], true)
	_check(P.commit([[t(0, 4), t(2, 4), t(3, 4), t(1, 4)]]) != "", "table tile cannot go back to rack")
	# 더미가 떨어지면 다 같이 넘긴 뒤 점수로 끝
	var Q := _logic_with([t(0, 13), J], [], true)
	Q.racks[1] = [t(1, 2)]
	Q.pool = []
	Q.draw_and_pass()
	_check(not Q.over and Q.current == 1, "first pass")
	Q.draw_and_pass()
	_check(Q.over and Q.by_points and Q.winner == 1, "ends by points, lowest wins")
	var sc := Q.final_scores()
	_check(int(sc[0]) == -43 and int(sc[1]) == 41, "scores %s" % [sc])


func _test_ai_meld() -> void:
	var ai := RummyAI.new(RummyAI.Level.NORMAL)
	var rack := [t(0, 10), t(1, 10), t(2, 10), t(3, 1), t(3, 2), t(3, 3), t(0, 2), t(1, 7)]
	var sets := ai.best_rack_sets(rack, true)
	var n_tiles := 0
	var value := 0
	for s in sets:
		_check(RummyLogic.analyze(s)["ok"], "AI set valid")
		n_tiles += (s as Array).size()
		value += int(RummyLogic.analyze(s)["value"])
	_check(n_tiles == 6 and value >= 30, "AI melds 6 tiles (%d, %d)" % [n_tiles, value])
	_check(ai.best_rack_sets([t(0, 2), t(1, 2), t(2, 2), t(3, 9)], true).is_empty(), "no meld under 30")
	# 두 벌 모두 써서 같은 런 두 번
	var r2 := [t(1, 4), t(1, 5), t(1, 6), t(1, 4, 1), t(1, 5, 1), t(1, 6, 1)]
	var s2 := ai.best_rack_sets(r2, false)
	_check(s2.size() == 2, "two identical runs from two copies")
	# 조커 활용
	var s3 := ai.best_rack_sets([t(2, 11), t(2, 13), J, t(0, 1)], true)
	_check(s3.size() == 1 and (s3[0] as Array).size() == 3, "joker fills 11-J-13 meld")


func _test_ai_layoff() -> void:
	var L := _logic_with([t(0, 8), t(2, 5), t(1, 1)], [[t(0, 5), t(0, 6), t(0, 7)], [t(1, 5), t(3, 5), t(0, 5, 1)]], true)
	var ai := RummyAI.new(RummyAI.Level.NORMAL)
	var tbl := ai.choose(L, 0)
	_check(not tbl.is_empty() and RummyLogic.table_valid(tbl), "layoff table valid")
	_check(L.commit(tbl) == "", "layoff commit ok")
	_check((L.racks[0] as Array) == [t(1, 1)], "red 8 and yellow 5 laid off, left %s" % [L.racks[0]])
	# 어려움: 런 나누기
	var M := _logic_with([t(3, 6), t(1, 13)], [[t(3, 3), t(3, 4), t(3, 5), t(3, 6), t(3, 7), t(3, 8)]], true)
	var hard := RummyAI.new(RummyAI.Level.HARD)
	var tb2 := hard.choose(M, 0)
	_check(M.commit(tb2) == "" and (M.racks[0] as Array).size() == 1, "hard splits run to place black 6")
	# 어려움: 빌려 오기 (손 빨강 9 · 파랑 9 + 판 검정 9 그룹 4개 중 하나)
	var N := _logic_with([t(0, 9, 1), t(1, 9, 1), t(2, 2)], [[t(0, 9), t(1, 9), t(2, 9), t(3, 9)]], true)
	var tb3 := hard.choose(N, 0)
	_check(N.commit(tb3) == "" and (N.racks[0] as Array) == [t(2, 2)], "hard borrows from 4-group")


func _selfplay(n: int, games: int) -> void:
	var wins := []
	wins.resize(n)
	wins.fill(0)
	var turns_total := 0
	for gi in games:
		var L := RummyLogic.new()
		L.setup(n, _rng, gi % n)
		var ais: Array = []
		for p in n:
			ais.append(RummyAI.new((gi + p) % 3))
		var guard := 0
		while not L.over and guard < 2000:
			guard += 1
			var me := L.current
			var tbl: Array = (ais[me] as RummyAI).choose(L.clone(), me)
			if tbl.is_empty():
				L.draw_and_pass()
			else:
				var err := L.commit(tbl)
				_check(err == "", "AI commit ok: %s" % err)
				if err != "":
					L.draw_and_pass()
			_check(RummyLogic.table_valid(L.table), "table valid")
			var count := L.pool.size()
			for p in n:
				count += (L.racks[p] as Array).size()
			for s in L.table:
				count += (s as Array).size()
			_check(count == RummyLogic.TILE_COUNT, "tiles conserved")
		_check(L.over, "rummy n=%d finished" % n)
		turns_total += L.turn_no
		if L.winner >= 0:
			wins[L.winner] += 1
	print("  rummy selfplay n=%d wins %s avg turns %.1f" % [n, wins, turns_total / float(games)])
