extends SceneTree
## 오목 로직/AI 헤드리스 테스트
## 실행: Godot_console.exe --headless --path . -s res://tests/test_omok_logic.gd

var _fail := 0


func _init() -> void:
	_test_five_and_turns()
	_test_double_three()
	_test_undo()
	_test_ai_tactics()
	for pair in [[0, 1], [1, 2], [2, 1], [2, 2]]:
		_selfplay(pair[0], pair[1], true)
	_selfplay(2, 2, false)
	print("RESULT: ", "ALL PASSED" if _fail == 0 else "%d FAILED" % _fail)
	quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail += 1
		print("  FAIL: ", msg)


## moves 를 번갈아 둠 (흑, 백, 흑, ...)
func _play(L: OmokLogic, moves: Array) -> void:
	for m in moves:
		_check(L.place(m), "place %s" % m)


func _test_five_and_turns() -> void:
	var L := OmokLogic.new()
	L.setup(15, false)
	_check(L.current == 0, "black first")
	_play(L, [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 3), Vector2i(6, 4)])
	_check(not L.over, "not over at four")
	_check(not L.place(Vector2i(3, 3)), "occupied rejected")
	_play(L, [Vector2i(7, 3)])
	_check(L.over and L.winner == 0, "black five wins")
	_check(L.win_line.size() == 5, "win line 5 stones")
	_check(not L.place(Vector2i(10, 10)), "no moves after game over")

	# 대각선 + 장목
	L.setup(15, false)
	_play(L, [Vector2i(0, 0), Vector2i(0, 5), Vector2i(1, 1), Vector2i(0, 6), Vector2i(2, 2), Vector2i(0, 7),
		Vector2i(4, 4), Vector2i(0, 9), Vector2i(5, 5), Vector2i(0, 10)])
	_check(not L.over, "gap not five")
	_play(L, [Vector2i(3, 3)])
	_check(L.over and L.winner == 0 and L.win_line.size() == 6, "overline (6) counts as win")


func _test_double_three() -> void:
	var L := OmokLogic.new()
	L.setup(15, true)
	# 흑: (7,6),(7,5) 세로 / (6,7),(5,7) 가로 → (7,7)은 쌍삼
	_play(L, [Vector2i(7, 6), Vector2i(0, 0), Vector2i(7, 5), Vector2i(0, 14), Vector2i(6, 7), Vector2i(14, 0), Vector2i(5, 7), Vector2i(14, 14)])
	_check(L.current == 0, "black to move")
	_check(L.is_forbidden(Vector2i(7, 7), 0), "double-three is forbidden")
	_check(L.forbidden_cells(0).has(Vector2i(7, 7)), "forbidden list contains it")
	_check(not L.place(Vector2i(7, 7)), "placing forbidden rejected")
	_check(not L.is_forbidden(Vector2i(7, 4), 0), "single three allowed")
	# 한쪽이 막힌 3 은 열린 3 이 아님 → 금지 아님
	var M := OmokLogic.new()
	M.setup(15, true)
	_play(M, [Vector2i(7, 6), Vector2i(7, 4), Vector2i(7, 5), Vector2i(0, 14), Vector2i(6, 7), Vector2i(14, 0), Vector2i(5, 7), Vector2i(14, 14)])
	_check(not M.is_forbidden(Vector2i(7, 7), 0), "blocked three + open three is allowed")
	# 자유룰이면 허용
	var F := OmokLogic.new()
	F.setup(15, false)
	_play(F, [Vector2i(7, 6), Vector2i(0, 0), Vector2i(7, 5), Vector2i(0, 14), Vector2i(6, 7), Vector2i(14, 0), Vector2i(5, 7), Vector2i(14, 14)])
	_check(F.place(Vector2i(7, 7)), "free rule allows double-three")


func _test_undo() -> void:
	var L := OmokLogic.new()
	L.setup(15, false)
	_play(L, [Vector2i(7, 7), Vector2i(8, 8)])
	_check(L.undo() and L.current == 1 and L.is_empty(Vector2i(8, 8)), "undo restores white's turn")
	_check(L.undo() and L.current == 0 and L.history.is_empty(), "undo to empty board")
	_check(not L.undo(), "nothing to undo")


func _test_ai_tactics() -> void:
	for lv in [1, 2]:
		var ai := OmokAI.new(lv)
		# AI(백) 는 흑의 4 를 막아야 함
		var L := OmokLogic.new()
		L.setup(15, false)
		_play(L, [Vector2i(5, 7), Vector2i(0, 0), Vector2i(6, 7), Vector2i(0, 2), Vector2i(7, 7), Vector2i(14, 14), Vector2i(8, 7)])
		var c := ai.choose(L.clone(), 1)
		_check(c == Vector2i(4, 7) or c == Vector2i(9, 7), "lv%d blocks four, got %s" % [lv, c])
		# AI(흑) 는 자기 4 를 완성해야 함
		var W := OmokLogic.new()
		W.setup(15, false)
		_play(W, [Vector2i(5, 5), Vector2i(7, 7), Vector2i(5, 6), Vector2i(8, 7), Vector2i(5, 7), Vector2i(9, 7), Vector2i(5, 8), Vector2i(10, 7)])
		var w := ai.choose(W.clone(), 0)
		_check(w == Vector2i(5, 4) or w == Vector2i(5, 9), "lv%d takes the win, got %s" % [lv, w])


func _selfplay(lv_a: int, lv_b: int, ban: bool) -> void:
	var L := OmokLogic.new()
	L.setup(15, ban)
	var ais := [OmokAI.new(lv_a), OmokAI.new(lv_b)]
	var max_ms := 0
	var total_ms := 0
	while not L.over and L.history.size() < 225:
		var t0 := Time.get_ticks_msec()
		var c: Vector2i = (ais[L.current] as OmokAI).choose(L.clone(), L.current)
		var dt := Time.get_ticks_msec() - t0
		total_ms += dt
		max_ms = maxi(max_ms, dt)
		var ok := L.place(c)
		_check(ok, "AI move legal %s (forbidden=%s)" % [c, L.is_forbidden(c, L.current)])
		if not ok:
			break
	_check(L.over, "game finished")
	print("AI %d(흑) vs %d(백), ban33=%s: %d moves, winner %d, think avg %dms max %dms" % [
		lv_a, lv_b, ban, L.history.size(), L.winner, total_ms / maxi(1, L.history.size()), max_ms])
