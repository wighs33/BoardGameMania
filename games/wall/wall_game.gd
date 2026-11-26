extends GameScreen
## 벽 땅따먹기 – 게임 화면 (룰 1 · 룰 2 공용)
## 경기 방식: 서바이벌(3인전 → 남은 둘이 1:1) / 3인전 / 1:1
## 공통 UI(상단 바, 카드, 팝업)는 GameScreen 에 있음
##
## 플레이어 번호가 두 가지라는 점에 주의:
##  - 로직 번호(lp): 이번 라운드의 순서 (0 = 선 플레이어)
##  - 정체성(id): 0 = 빨강(AI 대전에서는 나), 1 = 파랑, 2 = 노랑  → 색과 이름에 사용
##  seats[lp] = id

const MATCH_IDS := ["survival", "trio", "duel"]
const MATCH_LABELS := ["서바이벌", "3인전", "1:1"]
const TURN_LIMIT := 90.0

## 1 = 기본 룰, 2 = 사각·원형 말 룰 (씬에서 지정)
@export var rule: int = 1

var logic: WallLogic
var ai: WallAI = null
var match_type: String = "survival"
var timer_on: bool = false
var round_no: int = 1
var seats: Array = []

var board: WallBoard
var break_btn: Button
var cancel_btn: Button
var kind_row: HBoxContainer
var _kind_btns: Array = []
var _place_kind: int = -1
var _break_mode: bool = false
var _time_left: float = 0.0
var _timer_active: bool = false

var _busy: bool = false
var _thread: Thread = null
var _thread_token: int = -1
var _ai_started_ms: int = 0
var _last_area: Array = []


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "벽 땅따먹기" if rule == 1 else "벽 땅따먹기 2"


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	var place := "정해진 순서(1-2-3-3-2-1)대로 빈칸에 말을 하나씩 놓아요."
	var move := "내 말 하나를 상하좌우로 [b]1칸 또는 2칸[/b] 움직여요. 꺾어도 되고, 갔다가 되돌아와도 돼요."
	if rule == 2:
		place = "정해진 순서대로 [b]네모 말 · 동그라미 말[/b] 중 하나를 골라 빈칸에 놓아요."
		move = "[b]네모 말[/b]은 한 방향으로 곧게 1~2칸, [b]동그라미 말[/b]은 1칸 간 뒤 원하면 왼쪽/오른쪽으로 꺾어 1칸 더 가요."
	return (
		"[color=#%s]1. 말 놓기[/color]  %s\n" % [c1, place]
		+ "[color=#%s]2. 이동[/color]  %s 다른 말과 벽은 지나갈 수 없어요. 움직이지 않고 [b]제자리[/b]에서 벽만 세워도 돼요.\n" % [c2, move]
		+ "[color=#%s]3. 벽 세우기[/color]  움직인 말이 선 칸의 네 변 중 한 곳에 [b]꼭[/b] 벽을 세워요.\n" % c3
		+ "[color=#%s]4. 벽 부수기[/color] (3인전)  한 판에 딱 한 번, 가는 길의 벽 하나를 부수고 지나갈 수 있어요.\n" % c4
		+ "[color=#%s]5. 끝[/color]  모든 사람의 말이 벽으로 갈라지면 끝! 내 말이 있는 구역의 칸 수가 가장 많으면 1등. (같으면 가장 큰 구역 비교)\n" % c1
		+ "[color=#%s]6. 서바이벌[/color]  3인전 1등은 생존 확정! 나머지 둘이 1:1로 겨뤄 진 사람이 탈락해요. 1:1은 말 4개(2개는 정해진 자리)로 시작하고 벽 부수기는 없어요." % c2
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "경기 방식", MATCH_LABELS, maxi(0, MATCH_IDS.find(match_type)), UIKit.player_color(1),
		func(i: int) -> void: match_type = MATCH_IDS[i])
	box.add_child(UIKit.make_label("서바이벌: 3인전 1등은 생존, 나머지 둘이 1:1 결승", 21, UIKit.INK_SOFT))
	add_choice_row(box, "한 턴 제한 시간", ["없음", "90초"], 1 if timer_on else 0, UIKit.GREEN,
		func(i: int) -> void: timer_on = i == 1)


func _on_setup_opened() -> void:
	_busy = false
	_timer_active = false
	_break_mode = false
	if board != null:
		board.input_enabled = false
		_update_buttons()


func _is_game_over() -> bool:
	return logic != null and logic.phase == WallLogic.Phase.OVER


## id(정체성) 기준 이름
func player_name(p: int) -> String:
	if ai_level >= 0:
		if p == 0:
			return "나"
		if match_type == "duel":
			return "AI · " + LEVEL_NAMES[ai_level]
		return "AI %d" % p
	return _side_name(p)


func subject(p: int) -> String:
	if ai_level >= 0:
		if p == 0:
			return "내가"
		if match_type == "duel":
			return "AI가"
	return josa(player_name(p), "이", "가")


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "wall" if rule == 1 else "wall2"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	match_type = str(Global.get_setting(game_id, "match", "survival"))
	timer_on = bool(Global.get_setting(game_id, "timer", false))
	build_frame()

	board = WallBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 400)
	board.cell_pressed.connect(_on_cell_pressed)
	board.edge_pressed.connect(_on_edge_pressed)
	content.add_child(board)
	attach_toast(board)

	# 룰 2 말 놓기: 어떤 말을 놓을지 고르기
	kind_row = HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 14)
	kind_row.visible = false
	content.add_child(kind_row)
	var kgroup := ButtonGroup.new()
	for k in [WallLogic.Kind.SQUARE, WallLogic.Kind.ROUND]:
		var b := UIKit.make_toggle("네모 말 놓기" if k == WallLogic.Kind.SQUARE else "동그라미 말 놓기", UIKit.PURPLE, kgroup, 26)
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: int = k
		b.pressed.connect(func() -> void: _pick_kind(kind))
		kind_row.add_child(b)
		_kind_btns.append(b)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	content.add_child(bottom)
	break_btn = UIKit.make_button("벽 부수기", UIKit.ORANGE, Vector2(0, 96), 26)
	break_btn.toggle_mode = true
	break_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_btn.toggled.connect(_on_break_toggled)
	bottom.add_child(break_btn)
	cancel_btn = UIKit.make_button("이동 취소", UIKit.PURPLE, Vector2(0, 96), 26)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.disabled = true
	cancel_btn.pressed.connect(_on_cancel)
	bottom.add_child(cancel_btn)
	var new_btn := UIKit.make_button("새 게임", UIKit.GREEN, Vector2(0, 96), 26)
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(show_setup)
	bottom.add_child(new_btn)

	# 설정 화면 뒤에 보일 빈 판
	seats = [0, 1, 2]
	logic = WallLogic.new()
	logic.setup_trio(rule)
	board.setup(logic, _colors())
	setup_cards(seats)
	_last_area = [0, 0, 0]
	_refresh_ui()
	_update_buttons()
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _exit_tree() -> void:
	_token += 1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _process(delta: float) -> void:
	super(delta)
	if _thread != null and not _thread.is_alive():
		var result: Variant = _thread.wait_to_finish()
		_thread = null
		if _thread_token == _token:
			_apply_ai_result(result)
	if _timer_active and _overlay_kind == "" and not _busy:
		_time_left -= delta
		status_label.text = "%s  · %d초" % [_status_base, ceili(maxf(_time_left, 0.0))]
		if _time_left <= 0.0:
			_timer_active = false
			_on_timeout()


# ── 번호 변환 ──────────────────────────────────────────
func _id(lp: int) -> int:
	return int(seats[lp])


func _colors() -> Array:
	var out: Array = []
	for id in seats:
		out.append(UIKit.player_color(int(id)))
	return out


func _is_ai_turn() -> bool:
	return is_ai(_id(logic.current))


# ══════════════════════════════════════════════════════
#  게임 / 라운드 시작
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	_busy = false
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "match", match_type)
	Global.set_setting(game_id, "timer", timer_on)
	apply_mode()
	ai = WallAI.new(ai_level) if ai_level >= 0 else null
	human_player = 0
	round_no = 1
	var ids: Array = [0, 1] if match_type == "duel" else [0, 1, 2]
	ids.shuffle()   # 추첨으로 순서 결정
	_start_round(ids)


func _start_round(ids: Array) -> void:
	_token += 1
	_busy = false
	seats = ids
	logic = WallLogic.new()
	if ids.size() == 3:
		logic.setup_trio(rule)
	else:
		logic.setup_duel(rule)
	board.setup(logic, _colors())
	setup_cards(seats)
	_last_area = []
	for i in seats.size():
		_last_area.append(0)
	close_overlay()
	var names := PackedStringArray()
	for id in seats:
		names.append(player_name(int(id)))
	var head := "%d라운드! " % round_no if match_type == "survival" else ""
	toast(head + "순서: " + " → ".join(names))
	_next_turn()


func _start_round2(ids: Array) -> void:
	round_no = 2
	_start_round(ids)


# ══════════════════════════════════════════════════════
#  턴 진행
# ══════════════════════════════════════════════════════
func _next_turn() -> void:
	board.clear_hints()
	board.input_enabled = false
	_break_mode = false
	_timer_active = false
	kind_row.visible = false
	cancel_btn.disabled = true
	cancel_btn.text = "이동 취소"
	board.refresh()
	_refresh_ui()
	_update_buttons()
	if logic.phase == WallLogic.Phase.OVER:
		var sc := logic.scores()
		var parts := PackedStringArray()
		for lp in seats.size():
			parts.append("%s %d" % [player_name(_id(lp)), int(sc[lp]["area"])])
		set_status("게임 끝! " + " : ".join(parts))
		cancel_btn.text = "결과 보기"
		cancel_btn.disabled = false
		var tok := _token
		await wait(1.2)
		if tok != _token:
			return
		_finish_round()
		return
	if _is_ai_turn():
		_start_ai()
	else:
		_begin_human()


func _begin_human() -> void:
	board.input_enabled = true
	_time_left = TURN_LIMIT
	_timer_active = timer_on
	var who := who_prefix(_id(logic.current))
	if logic.phase == WallLogic.Phase.PLACE:
		board.place_mode = true
		var kinds := logic.remaining_kinds(logic.current)
		if rule == 2 and kinds.has(WallLogic.Kind.SQUARE) and kinds.has(WallLogic.Kind.ROUND):
			kind_row.visible = true
			(_kind_btns[0] as Button).button_pressed = true
			_pick_kind(WallLogic.Kind.SQUARE)
		else:
			_place_kind = int(kinds[0])
			var what := "말" if rule == 1 else _kind_name(_place_kind)
			set_status("%s%s을 놓을 칸을 고르세요" % [who, what])
	else:
		board.selectable = _movable(logic.current, false)
		if board.selectable.is_empty():
			_break_mode = true
			board.selectable = _movable(logic.current, true)
			toast("벽을 부숴야만 움직일 수 있어요!")
		set_status("%s움직일 말을 고르세요" % who)
	_update_buttons()


func _kind_name(kind: int) -> String:
	return "네모 말" if kind == WallLogic.Kind.SQUARE else "동그라미 말"


func _pick_kind(kind: int) -> void:
	_place_kind = kind
	set_status("%s%s을 놓을 칸을 고르세요" % [who_prefix(_id(logic.current)), _kind_name(kind)])


func _movable(lp: int, with_break: bool) -> Array[int]:
	var out: Array[int] = []
	for i in logic.pieces_of(lp):
		if not logic.destinations(i, with_break).is_empty():
			out.append(i)
	return out


## 벽 부수기 버튼 상태 갱신
func _update_buttons() -> void:
	var trio := seats.size() == 3
	break_btn.visible = trio
	if not trio:
		return
	# AI 대전에서는 내 남은 횟수, 2인 이상 사람끼리면 현재 차례인 사람의 횟수
	var owner_lp := logic.current if ai_level < 0 else seats.find(0)
	var left := logic.breaks_left[owner_lp] if owner_lp >= 0 else 0
	var can_use := logic.phase == WallLogic.Phase.MOVE and not _is_ai_turn() and not _busy and _thread == null and left > 0
	break_btn.disabled = not can_use and not _break_mode
	break_btn.set_pressed_no_signal(_break_mode)
	if _break_mode:
		break_btn.text = "부수기 켜짐!"
	elif left > 0:
		break_btn.text = "벽 부수기 1회"
	else:
		break_btn.text = "부수기 다 씀"


func _on_break_toggled(on: bool) -> void:
	if logic.phase != WallLogic.Phase.MOVE or _is_ai_turn() or _busy or logic.breaks_left[logic.current] <= 0:
		_update_buttons()
		return
	_break_mode = on
	board.selectable = _movable(logic.current, _break_mode)
	if board.selected != -1:
		board.targets = logic.destinations(board.selected, _break_mode)
	if on:
		set_status("주황색 칸은 벽을 부수고 갈 수 있어요")
	else:
		set_status("%s움직일 말을 고르세요" % who_prefix(_id(logic.current)))
	_update_buttons()


func _on_cell_pressed(c: Vector2i) -> void:
	if _busy or _thread != null or _is_ai_turn():
		return
	if logic.phase == WallLogic.Phase.PLACE:
		if logic.place_piece(c, _place_kind):
			board.sync_pieces()
			_after_placement()
	elif logic.phase == WallLogic.Phase.MOVE:
		var pi := logic.piece_at(c)
		if board.selected != -1 and board.targets.has(c) and (pi == -1 or pi == board.selected):
			_human_move(board.selected, c)
		elif pi != -1 and board.selectable.has(pi):
			_select_piece(pi)
		elif board.selected != -1:
			board.selected = -1
			board.targets = {}
			set_status("%s움직일 말을 고르세요" % who_prefix(_id(logic.current)))


func _after_placement() -> void:
	if logic.phase == WallLogic.Phase.MOVE:
		toast("%s 먼저 움직여요!" % subject(_id(logic.current)))
	_next_turn()


func _select_piece(pi: int) -> void:
	board.selected = pi
	board.targets = logic.destinations(pi, _break_mode)
	if rule == 1:
		set_status("어디로 갈까요? (말을 다시 누르면 제자리)")
	elif logic.piece_kind[pi] == WallLogic.Kind.SQUARE:
		set_status("네모 말: 곧게 1~2칸 (다시 누르면 제자리)")
	else:
		set_status("동그라미 말: 1칸+꺾어 1칸 (다시 누르면 제자리)")


func _human_move(pi: int, c: Vector2i) -> void:
	var e: Dictionary = board.targets[c]
	var broken: Vector2i = e["broken"]
	var brk := broken.x >= 0
	var bval := logic.get_slot(broken) if brk else 0
	if not logic.move_piece(pi, c, brk):
		return
	_busy = true
	board.targets = {}
	board.selectable = []
	if brk:
		board.mark_broken(broken, bval)
		toast("벽을 부쉈어요!")
	_update_buttons()
	var tok := _token
	await board.animate_move(pi, e["path"])
	if tok != _token:
		return
	_busy = false
	_enter_wall_phase()


func _enter_wall_phase() -> void:
	var cell := logic.piece_pos[logic.moved_piece]
	board.selected = -1
	board.wall_cell = cell
	board.wall_dirs = logic.open_dirs(cell)
	cancel_btn.disabled = false
	set_status("반짝이는 곳을 눌러 벽을 세우세요")
	_update_buttons()


func _on_edge_pressed(d: int) -> void:
	if _busy or _thread != null or _is_ai_turn():
		return
	if logic.phase != WallLogic.Phase.WALL:
		return
	_place_wall(d)


func _place_wall(d: int) -> void:
	var cell := logic.piece_pos[logic.moved_piece]
	var before := logic.scores()
	if not logic.place_wall(d):
		return
	board.mark_wall(cell, d)
	var after := logic.scores()
	for lp in after.size():
		var gained := int(after[lp]["area"]) - int(before[lp]["area"])
		if gained > 0:
			toast("%s 땅 %d칸 확보!" % [subject(_id(lp)), gained])
	for lp in logic.skipped:
		toast("%s 움직일 수 없어 차례를 넘겨요" % subject(_id(lp)))
	_next_turn()


func _on_cancel() -> void:
	if logic.phase == WallLogic.Phase.OVER:
		reopen_result()  # 게임이 끝난 뒤에는 '결과 보기' 버튼
		return
	if _busy or logic.phase != WallLogic.Phase.WALL or _is_ai_turn():
		return
	var pi := logic.moved_piece
	logic.cancel_move()
	board.wall_cell = Vector2i(-1, -1)
	board.wall_dirs = []
	board.snap_piece(pi)
	board.refresh()
	cancel_btn.disabled = true
	_break_mode = false
	board.selectable = _movable(logic.current, false)
	if board.selectable.is_empty():
		_break_mode = true
		board.selectable = _movable(logic.current, true)
	_select_piece(pi)
	_update_buttons()


## 제한 시간 초과: 남은 단계를 무작위로 처리
func _on_timeout() -> void:
	if _busy or _is_ai_turn():
		return
	toast("시간 초과! 무작위로 진행돼요")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if logic.phase == WallLogic.Phase.PLACE:
		var empties: Array = []
		for y in logic.size:
			for x in logic.size:
				if logic.piece_at(Vector2i(x, y)) == -1:
					empties.append(Vector2i(x, y))
		if logic.place_piece(empties[rng.randi() % empties.size()], _place_kind):
			board.sync_pieces()
			_after_placement()
		return
	if logic.phase == WallLogic.Phase.MOVE:
		var opts: Array = []
		for pi in _movable(logic.current, true):
			var dests := logic.destinations(pi, false)
			for cell in dests:
				opts.append([pi, cell])
		if opts.is_empty():
			_next_turn()
			return
		var pick: Array = opts[rng.randi() % opts.size()]
		logic.move_piece(pick[0], pick[1], false)
		board.snap_piece(pick[0])
	if logic.phase == WallLogic.Phase.WALL:
		var dirs := logic.open_dirs(logic.piece_pos[logic.moved_piece])
		_place_wall(dirs[rng.randi() % dirs.size()])


# ── AI 차례 (생각은 별도 스레드에서) ───────────────────
func _start_ai() -> void:
	if _thread != null:
		_thread.wait_to_finish()  # 이전 라운드에서 남은 계산 정리
		_thread = null
	board.input_enabled = false
	_update_buttons()
	start_thinking("%s 생각 중" % player_name(_id(logic.current)))
	_ai_started_ms = Time.get_ticks_msec()
	var clone := logic.clone()
	_thread = Thread.new()
	_thread_token = _token
	if logic.phase == WallLogic.Phase.PLACE:
		_thread.start(ai.choose_placement.bind(clone, logic.current))
	else:
		_thread.start(ai.choose_move.bind(clone, logic.current))


func _apply_ai_result(result: Variant) -> void:
	var tok := _token
	var elapsed := (Time.get_ticks_msec() - _ai_started_ms) / 1000.0
	if elapsed < 0.6:
		await wait(0.6 - elapsed)
		if tok != _token:
			return
	var id := _id(logic.current)
	if logic.phase == WallLogic.Phase.PLACE:
		var pl: Array = result
		logic.place_piece(pl[0], pl[1])
		board.sync_pieces()
		_after_placement()
		return
	var mv: Array = result
	if mv.is_empty():
		_next_turn()
		return
	var pi: int = mv[0]
	var dest: Vector2i = mv[1]
	var d: int = mv[2]
	var broken: Vector2i = mv[3]
	var brk := broken.x >= 0
	set_status("%s 움직여요!" % subject(id))
	board.selected = pi
	await wait(0.35)
	if tok != _token:
		return
	var e: Dictionary = logic.destinations(pi, brk).get(dest, {})
	var path: Array = e.get("path", [])
	var bval := logic.get_slot(broken) if brk else 0
	if not logic.move_piece(pi, dest, brk):
		_next_turn()
		return
	if brk:
		board.mark_broken(broken, bval)
		toast("%s 벽을 부쉈어요!" % subject(id))
	board.selected = -1
	await board.animate_move(pi, path)
	if tok != _token:
		return
	board.wall_cell = dest
	var dirs: Array[int] = [d]
	board.wall_dirs = dirs
	await wait(0.35)
	if tok != _token:
		return
	_place_wall(d)


# ══════════════════════════════════════════════════════
#  화면 갱신 / 결과
# ══════════════════════════════════════════════════════
func _refresh_ui() -> void:
	var sc: Array = logic.scores() if logic.phase != WallLogic.Phase.PLACE else []
	for lp in seats.size():
		var area: int = 0 if sc.is_empty() else int(sc[lp]["area"])
		var active := logic.phase != WallLogic.Phase.OVER and logic.current == lp
		set_card(lp, player_name(_id(lp)), "%d칸" % area, active, area > int(_last_area[lp]))
		_last_area[lp] = area
	set_status_side(_id(logic.current))


func _rows(order: Array, smalls: Array) -> Array:
	var sc := logic.scores()
	var rows: Array = []
	for k in order.size():
		var lp: int = order[k]
		rows.append({"p": _id(lp), "big": "%d칸" % int(sc[lp]["area"]), "small": smalls[k]})
	return rows


func _finish_round() -> void:
	var order := logic.ranking()
	var sc := logic.scores()
	var note := "넓이가 같아서 가장 큰 구역으로 순위를 정했어요" if logic.decided_by_largest() else ""

	# 서바이벌 1라운드: 1등은 생존, 나머지 둘은 2라운드로
	if match_type == "survival" and round_no == 1:
		var winner_id := _id(order[0])
		var next_ids := [_id(order[1]), _id(order[2])]   # 더 넓게 확보한 쪽이 선
		var rows := _rows(order, ["생존 확정!", "2라운드로", "2라운드로"])
		if ai_level >= 0 and winner_id == 0:
			Global.add_stat(game_id, "played")
			Global.add_stat(game_id, "wins")
			show_result("1등! 생존 확정!", UIKit.ORANGE, true, winner_id, rows, note)
		else:
			var title := "1라운드 끝!" if ai_level >= 0 else "%s 생존 확정!" % _side_name(winner_id)
			var msg := "남은 두 사람이 1:1로 마지막 승부!"
			show_result(title, UIKit.INK, ai_level < 0, winner_id, rows, msg if note.is_empty() else note + "\n" + msg,
				"2라운드 시작!", _start_round2.bind(next_ids))
		return

	# 서바이벌 2라운드: 진 사람 탈락
	if match_type == "survival":
		var w_id := _id(order[0])
		var l_id := _id(order[1])
		var rows := _rows(order, ["생존!", "탈락"])
		Global.add_stat(game_id, "played")
		if ai_level >= 0:
			if w_id == 0:
				Global.add_stat(game_id, "wins")
				show_result("생존 성공!", UIKit.ORANGE, true, w_id, rows, note)
			else:
				show_result("탈락...", UIKit.PURPLE, false, w_id, rows, note)
		else:
			show_result("%s 탈락..." % _side_name(l_id), UIKit.INK, true, w_id, rows, note)
		return

	# 3인전: 순위
	if seats.size() == 3:
		var rows := _rows(order, ["1등", "2등", "3등"])
		Global.add_stat(game_id, "played")
		var w_id := _id(order[0])
		if ai_level >= 0:
			var my_rank := 1
			for k in order.size():
				if _id(order[k]) == 0:
					my_rank = k + 1
			if my_rank == 1:
				Global.add_stat(game_id, "wins")
				show_result("1등!", UIKit.ORANGE, true, w_id, rows, note)
			else:
				show_result("%d등" % my_rank, UIKit.PURPLE, false, w_id, rows, note)
		else:
			show_result("%s 1등!" % _side_name(w_id), UIKit.player_dark(w_id), true, w_id, rows, note)
		return

	# 1:1
	var w := logic.winner()
	var wid := _id(w) if w >= 0 else -1
	record_result(wid)
	var rows: Array = []
	for lp in 2:
		rows.append({"p": _id(lp), "big": "%d칸" % int(sc[lp]["area"]), "small": "최대 구역 %d칸" % int(sc[lp]["largest"])})
	show_standard_result(wid, rows, note)
