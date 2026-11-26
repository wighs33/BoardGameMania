extends SceneTree
## 리버시 로직/AI 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_reversi_logic.gd

var _fail := 0


func _init() -> void:
	_test_start_and_flips()
	_test_pass_and_end()
	_test_undo()
	_test_ai_corner()
	_test_ai_endgame()
	for pair in [[0, 1], [1, 0], [1, 2], [2, 1]]:
		_match(pair[0], pair[1], 4)
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


## 문자열 판 불러오기: X = 흑, O = 백, . = 빈칸
func _load(L: ReversiLogic, rows: Array, turn: int) -> void:
	L.setup()
	for y in 8:
		for x in 8:
			var ch: String = rows[y][x]
			L.cells[y * 8 + x] = 1 if ch == "X" else (2 if ch == "O" else 0)
	L.current = turn


func _test_start_and_flips() -> void:
	var L := ReversiLogic.new()
	L.setup()
	_check(L.count(0) == 2 and L.count(1) == 2, "start 2:2")
	_check(L.current == 0, "black first")
	var moves := L.legal_moves(0)
	moves.sort()
	_check(moves == [Vector2i(3, 2), Vector2i(2, 3), Vector2i(5, 4), Vector2i(4, 5)] or moves.size() == 4, "4 opening moves, got %s" % [moves])
	for m in [Vector2i(3, 2), Vector2i(2, 3), Vector2i(5, 4), Vector2i(4, 5)]:
		_check(moves.has(m), "opening move %s legal" % m)
	_check(not L.place(Vector2i(0, 0)), "illegal corner rejected")
	_check(L.place(Vector2i(3, 2)), "black d3")
	_check(L.count(0) == 4 and L.count(1) == 1, "after d3: 4:1")
	_check(L.stone(Vector2i(3, 3)) == 1, "d4 flipped to black")
	_check(L.current == 1, "white's turn")
	# 여러 방향 동시에 뒤집기
	var M := ReversiLogic.new()
	_load(M, [
		"........",
		".X.X.X..",
		"..OOO...",
		".XO.OX..",
		"..OOO...",
		".X.X.X..",
		"........",
		"........",
	], 0)
	var f := M.flips_for(Vector2i(3, 3), 0)
	_check(f.size() == 8, "8-direction flips, got %d" % f.size())


func _test_pass_and_end() -> void:
	# 백은 둘 곳이 없고 흑만 둘 수 있는 상황 → 흑이 두고 나면 백은 패스
	var L := ReversiLogic.new()
	_load(L, [
		"XXXXXXXX",
		"XXXXXXXX",
		"XXXXXXXX",
		"XXXXXXXX",
		"XXXXXXXX",
		"XXXXXXXX",
		"XXXXXXO.",
		"XXXXXX..",
	], 0)
	_check(L.is_legal(Vector2i(7, 6), 0), "black can take h7")
	_check(L.place(Vector2i(7, 6)), "black h7")
	_check(L.over, "no moves for anyone -> over")
	_check(L.winner == 0 and L.count(1) == 0, "black wins with white wiped out")

	# 백이 두고 나도 흑은 둘 곳이 없고 백은 남아 있음 → 흑 패스, 백이 한 번 더
	var P := ReversiLogic.new()
	_load(P, [
		"OX......",
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"......XO",
	], 1)
	_check(not P.can_move(0), "black has no move in setup")
	_check(P.place(Vector2i(2, 0)), "white c1 flips b1")
	_check(not P.over and P.current == 1 and P.passed_player == 0, "black passes, white again")
	_check(P.place(Vector2i(5, 7)), "white f8 flips g8")
	_check(P.over and P.winner == 1, "no black stones left -> white wins")


func _test_undo() -> void:
	var L := ReversiLogic.new()
	L.setup()
	var before := L.cells.duplicate()
	L.place(Vector2i(3, 2))
	L.place(L.legal_moves(1)[0])
	_check(L.undo() and L.current == 1, "undo white")
	_check(L.undo() and L.current == 0, "undo black")
	_check(L.cells == before, "board restored exactly")


func _test_ai_corner() -> void:
	# 귀를 잡을 수 있으면 보통/어려움은 귀를 잡아야 함
	for lv in [1, 2]:
		var L := ReversiLogic.new()
		_load(L, [
			"........",
			".O......",
			"..O.....",
			"...OX...",
			"...XX...",
			"........",
			"........",
			"........",
		], 0)
		_check(L.is_legal(Vector2i(0, 0), 0), "corner is legal in setup")
		var c := ReversiAI.new(lv).choose(L.clone(), 0)
		_check(c == Vector2i(0, 0), "lv%d takes corner, got %s" % [lv, c])


func _test_ai_endgame() -> void:
	var L := ReversiLogic.new()
	L.setup()
	var ai := ReversiAI.new(2)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	# 무작위로 빈칸 12개 남을 때까지 진행 후, 끝내기 계산 시간 측정
	while not L.over and L.cells.count(0) > 12:
		var ms := L.legal_moves(L.current)
		L.place(ms[rnd.randi() % ms.size()])
	if L.over:
		return
	var t0 := Time.get_ticks_msec()
	var c := ai.choose(L.clone(), L.current)
	var dt := Time.get_ticks_msec() - t0
	_check(L.is_legal(c, L.current), "endgame move legal")
	print("endgame (12 empties) think: %dms" % dt)


func _match(lv_black: int, lv_white: int, games: int) -> void:
	var res := [0, 0, 0]
	var max_ms := 0
	for g in games:
		var L := ReversiLogic.new()
		L.setup()
		var ais := [ReversiAI.new(lv_black), ReversiAI.new(lv_white)]
		while not L.over:
			var t0 := Time.get_ticks_msec()
			var c: Vector2i = (ais[L.current] as ReversiAI).choose(L.clone(), L.current)
			max_ms = maxi(max_ms, Time.get_ticks_msec() - t0)
			if not L.place(c):
				_check(false, "AI move legal %s" % c)
				break
		res[L.winner + 1] += 1
	print("흑 lv%d vs 백 lv%d (%d판): 흑승 %d, 백승 %d, 무 %d, 최대 생각 %dms" % [lv_black, lv_white, games, res[1], res[2], res[0], max_ms])
