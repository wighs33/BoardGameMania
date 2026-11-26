extends GameScreen
## 타일 러미 – 게임 화면 (2~4명 · AI 대전 / 친구끼리 폰 돌리기)
## 내 차례에는 판과 손패의 '작업용 복사본'을 마음대로 바꾸고, [완료]를 누르면 규칙 검사 후 확정

var logic: RummyLogic
var ai: RummyAI = null
var players: int = 2
var sort_by_color: bool = true

var view: RummyView
var sort_btn: Button
var undo_btn: Button
var main_btn: Button

var work_table: Array = []
var work_rack: Array = []
var start_rack: Array = []
var selected: Dictionary = {}
var _fresh_ai: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _busy: bool = false
var _viewer: int = -1
var _thread: Thread = null
var _thread_token: int = -1
var _ai_started_ms: int = 0


# ══════════════════════════════════════════════════════
#  GameScreen 설정
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "타일 러미"


func _mode_label(id: String) -> String:
	if id == "local":
		return "친구끼리"
	return super(id)


func _rules_text() -> String:
	var c1 := UIKit.player_dark(0).to_html(false)
	var c2 := UIKit.GREEN.darkened(0.15).to_html(false)
	var c3 := UIKit.player_dark(1).to_html(false)
	var c4 := UIKit.ORANGE.darkened(0.1).to_html(false)
	return (
		"[color=#%s]1. 타일[/color]  1~13 숫자 타일 4색 × 2벌 + 조커 2장. 처음에 14장씩 받아요.\n" % c1
		+ "[color=#%s]2. 묶음[/color]  [b]그룹[/b]: 같은 숫자 · 다른 색 3~4장 / [b]런[/b]: 같은 색 · 이어지는 숫자 3장 이상. 조커는 아무 타일이나 대신해요.\n" % c2
		+ "[color=#%s]3. 처음 등록[/color]  처음 낼 때는 [b]내 타일만으로 합 30점 이상[/b]을 내야 해요.\n" % c3
		+ "[color=#%s]4. 내 차례[/color]  타일을 내거나, 낼 게 없으면 1장 뽑고 넘겨요. 등록 뒤에는 판의 묶음을 마음대로 나누고 합쳐도 돼요. 단, 끝낼 때 모든 묶음이 올바라야 해요!\n" % c1
		+ "[color=#%s]5. 승리[/color]  손의 타일을 모두 내면 승리! 더미가 떨어지면 남은 점수가 가장 적은 사람이 이겨요.\n" % c2
		+ "[color=#%s]조작[/color]  타일을 눌러 고르고 → 묶음이나 '새 묶음'을 눌러 옮겨요. 타일을 끌어다 놓아도 돼요. 빨간 묶음은 아직 틀린 묶음!" % c4
	)


func _add_setup_options(box: VBoxContainer) -> void:
	add_choice_row(box, "인원 (나 포함)", ["2명", "3명", "4명"], players - 2, UIKit.player_color(1),
		func(i: int) -> void: players = i + 2)
	box.add_child(UIKit.make_label("친구끼리: 폰 하나를 돌려 가며 해요 (차례마다 화면 가리개)", 21, UIKit.INK_SOFT))


func _on_setup_opened() -> void:
	_busy = false
	if view != null:
		view.interactive = false
		_update_buttons()


func _is_game_over() -> bool:
	return logic == null or logic.over


func player_name(p: int) -> String:
	if ai_level >= 0:
		if p == human_player:
			return "나"
		if players == 2:
			return "AI · " + LEVEL_NAMES[ai_level]
		return "AI %d" % p
	return _side_name(p)


func subject(p: int) -> String:
	if ai_level >= 0:
		if p == human_player:
			return "내가"
		if players == 2:
			return "AI가"
	return josa(player_name(p), "이", "가")


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "rummy"
	mode = str(Global.get_setting(game_id, "mode", "ai_normal"))
	players = clampi(int(Global.get_setting(game_id, "players", 2)), 2, 4)
	sort_by_color = bool(Global.get_setting(game_id, "sort_color", true))
	_rng.randomize()
	build_frame()

	view = RummyView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 600)
	view.tapped.connect(_on_tapped)
	view.dropped.connect(_on_dropped)
	view.drag_filter = _can_drag
	content.add_child(view)
	attach_toast(view)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	content.add_child(bottom)
	sort_btn = _small_button("숫자순", UIKit.PURPLE)
	sort_btn.pressed.connect(_on_sort)
	bottom.add_child(sort_btn)
	undo_btn = _small_button("되돌리기", UIKit.ORANGE)
	undo_btn.pressed.connect(_on_undo)
	bottom.add_child(undo_btn)
	var new_btn := _small_button("새 게임", Color("#3FA9F5"))
	new_btn.pressed.connect(show_setup)
	bottom.add_child(new_btn)
	main_btn = _small_button("뽑고 넘기기", UIKit.GREEN)
	main_btn.size_flags_stretch_ratio = 1.5
	main_btn.pressed.connect(_on_main)
	bottom.add_child(main_btn)

	apply_mode()
	logic = RummyLogic.new()
	logic.setup(players, _rng, 0)
	setup_cards(range(players))
	_viewer = 0
	_refresh_ui()
	_update_view()
	set_status("어떻게 플레이할지 골라 주세요")
	show_setup()


func _small_button(text: String, color: Color) -> Button:
	var b := UIKit.make_button(text, color, Vector2(0, 90), 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := b.get_theme_stylebox(st) as StyleBoxFlat
		if sb != null:
			sb.content_margin_left = 10
			sb.content_margin_right = 10
	return b


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


# ══════════════════════════════════════════════════════
#  게임 진행
# ══════════════════════════════════════════════════════
func _start_game() -> void:
	_token += 1
	_busy = false
	Global.set_setting(game_id, "mode", mode)
	Global.set_setting(game_id, "players", players)
	apply_mode()
	ai = RummyAI.new(ai_level) if ai_level >= 0 else null
	human_player = 0
	logic = RummyLogic.new()
	logic.setup(players, _rng, _rng.randi() % players)
	_viewer = human_player if ai_level >= 0 else -1
	setup_cards(range(players))
	work_table = []
	selected.clear()
	_fresh_ai.clear()
	main_btn.text = "뽑고 넘기기"
	close_overlay()
	_refresh_ui()
	_update_view()
	toast("%s 먼저 시작해요!" % subject(logic.current))
	_next_turn()


func _is_human_turn() -> bool:
	return logic != null and not logic.over and not is_ai(logic.current)


func _human_ok() -> bool:
	return _is_human_turn() and not _busy and _thread == null and not has_curtain() and _overlay_kind == ""


func _next_turn() -> void:
	view.interactive = false
	selected.clear()
	_refresh_ui()
	if logic.over:
		_game_over()
		return
	var cur := logic.current
	if is_ai(cur):
		_update_view()
		_update_buttons()
		_start_ai()
		return
	if ai_level < 0 and _viewer != cur:
		_update_buttons()
		show_curtain("%s 차례!" % _side_name(cur), "%s에게 폰을 넘겨 주세요" % _side_name(cur), _side_color(cur), _begin_human)
		return
	_begin_human()


func _begin_human() -> void:
	var cur := logic.current
	_viewer = cur
	start_rack = (logic.racks[cur] as Array).duplicate()
	work_rack = start_rack.duplicate()
	RummyLogic.sort_tiles(work_rack, sort_by_color)
	work_table = logic.table.duplicate(true)
	selected.clear()
	view.interactive = true
	_refresh_ui()
	_update_view()
	_update_buttons()
	_update_status()


func _dirty() -> bool:
	if work_rack.size() != start_rack.size():
		return true
	if work_table.size() != logic.table.size():
		return true
	for i in work_table.size():
		if RummyLogic._sig(work_table[i]) != RummyLogic._sig(logic.table[i]):
			return true
	return false


func _played_count() -> int:
	return start_rack.size() - work_rack.size()


func _update_status() -> void:
	if not _is_human_turn():
		return
	var who := who_prefix(logic.current)
	if not logic.melded[logic.current]:
		var pts := logic.meld_points(work_table, logic.current)
		if _played_count() == 0:
			set_status("%s처음 등록: 내 타일로 30점 이상 내기" % who)
		elif pts < 0:
			set_status("%s처음 등록 때는 판의 타일을 옮길 수 없어요" % who)
		else:
			set_status("%s새 묶음 %d점 / 30점%s" % [who, pts, " · 완료 가능!" if pts >= 30 and RummyLogic.table_valid(work_table) else ""])
		return
	if _played_count() == 0 and not _dirty():
		set_status("%s타일을 골라 판에 내 보세요" % who)
	elif not RummyLogic.table_valid(work_table):
		set_status("%s빨간 묶음을 고쳐야 끝낼 수 있어요" % who)
	else:
		set_status("%s%d장 냈어요! 다 됐으면 [완료]" % [who, _played_count()])


func _update_buttons() -> void:
	var human := _human_ok()
	sort_btn.text = "숫자순" if sort_by_color else "색깔순"
	if logic.over:
		main_btn.text = "결과 보기"
		main_btn.disabled = false
		undo_btn.disabled = true
		return
	undo_btn.disabled = not (human and _dirty())
	if human and _dirty():
		main_btn.text = "완료!"
	else:
		main_btn.text = "뽑고 넘기기" if not logic.pool.is_empty() else "넘기기"
	main_btn.disabled = not human


func _update_view() -> void:
	if _is_human_turn() and view.interactive:
		view.table = work_table
		view.rack = work_rack
		var fr := {}
		for s in work_table:
			for t in s:
				if start_rack.has(t):
					fr[t] = true
		view.fresh = fr
	else:
		view.table = logic.table
		var p := _viewer if _viewer >= 0 else 0
		var r: Array = (logic.racks[p] as Array).duplicate()
		RummyLogic.sort_tiles(r, sort_by_color)
		view.rack = r
		view.fresh = _fresh_ai
	view.selected = selected
	view.pool_left = logic.pool.size()
	view.rack_label = "내 타일" if ai_level >= 0 else "%s의 타일" % _side_name(maxi(_viewer, 0))


# ── 내 차례 조작 ──────────────────────────────────────
func _can_pick_table(tile: int) -> bool:
	return logic.melded[logic.current] or start_rack.has(tile)


func _can_drag(tile: int) -> bool:
	if not _human_ok():
		return false
	if work_rack.has(tile):
		return true
	if not _can_pick_table(tile):
		toast("처음 등록 전에는 판의 타일을 옮길 수 없어요")
		return false
	return true


func _on_tapped(hit: Dictionary) -> void:
	if not _human_ok():
		return
	var kind: String = hit.get("kind", "none")
	match kind:
		"tile":
			var tile: int = hit["tile"]
			if hit["area"] == "rack":
				_toggle(tile)
			elif selected.has(tile):
				selected.erase(tile)
			elif selected.is_empty():
				if _can_pick_table(tile):
					selected[tile] = true
				else:
					toast("처음 등록 전에는 판의 타일을 옮길 수 없어요")
			else:
				_move(selected.keys(), {"kind": "set", "set": hit["set"]})
				return
		"set", "new", "rack":
			if not selected.is_empty():
				_move(selected.keys(), hit)
				return
			if kind == "new":
				toast("먼저 옮길 타일을 골라요")
		_:
			selected.clear()
	_update_view()


func _toggle(tile: int) -> void:
	if selected.has(tile):
		selected.erase(tile)
	else:
		selected[tile] = true


func _on_dropped(tiles: Array, target: Dictionary) -> void:
	if not _human_ok():
		return
	_move(tiles, target)


func _move(tiles: Array, target: Dictionary) -> void:
	var kind: String = target.get("kind", "none")
	if kind == "none":
		_update_view()
		return
	var moving: Array = tiles.duplicate()
	if kind == "rack":
		var back: Array = moving.filter(func(t: int) -> bool: return start_rack.has(t))
		if back.size() < moving.size():
			toast("판에 있던 타일은 가져올 수 없어요")
		moving = back
	else:
		var ok: Array = moving.filter(func(t: int) -> bool: return work_rack.has(t) or _can_pick_table(t))
		if ok.size() < moving.size():
			toast("처음 등록 전에는 판의 타일을 옮길 수 없어요")
		moving = ok
	if moving.is_empty():
		selected.clear()
		_update_view()
		return
	var target_set: Array = []
	if kind == "set":
		var si: int = target["set"]
		if si < 0 or si >= work_table.size():
			_update_view()
			return
		target_set = work_table[si]
	for t in moving:
		if work_rack.has(t):
			work_rack.erase(t)
			continue
		for s in work_table:
			if (s as Array).has(t):
				(s as Array).erase(t)
				break
	match kind:
		"set":
			target_set.append_array(moving)
		"new":
			work_table.append(moving)
		"rack":
			work_rack.append_array(moving)
			RummyLogic.sort_tiles(work_rack, sort_by_color)
	var cleaned: Array = []
	for s in work_table:
		if not (s as Array).is_empty():
			var info := RummyLogic.analyze(s)
			if info["ok"]:
				cleaned.append(info["order"])
			else:
				var c: Array = (s as Array).duplicate()
				RummyLogic.sort_tiles(c, false)
				cleaned.append(c)
	work_table = cleaned
	selected.clear()
	if kind == "new":
		view.scroll_to_end()
	_update_view()
	_update_buttons()
	_update_status()


func _on_sort() -> void:
	sort_by_color = not sort_by_color
	Global.set_setting(game_id, "sort_color", sort_by_color)
	RummyLogic.sort_tiles(work_rack, sort_by_color)
	_update_view()
	_update_buttons()


func _on_undo() -> void:
	if not _human_ok():
		return
	work_rack = start_rack.duplicate()
	RummyLogic.sort_tiles(work_rack, sort_by_color)
	work_table = logic.table.duplicate(true)
	selected.clear()
	toast("이번 차례를 처음으로 되돌렸어요")
	_update_view()
	_update_buttons()
	_update_status()


func _on_main() -> void:
	if logic.over:
		reopen_result()
		return
	if not _human_ok():
		return
	var me := logic.current
	if _dirty():
		var err := logic.commit(work_table)
		if err != "":
			toast(err)
			return
		var cnt := (logic.last.get("tiles", []) as Array).size()
		_fresh_ai = {}
		for t in logic.last.get("tiles", []):
			_fresh_ai[t] = true
		toast("%d장 냈어요!" % cnt if not logic.over else "타일을 모두 냈어요!")
		set_status("%s %d장 냈어요!" % [subject(me), cnt])
	else:
		var t := logic.draw_and_pass()
		_fresh_ai = {}
		if t >= 0:
			toast("%s 뽑았어요" % _tile_name(t))
			set_status("%s 1장 뽑고 넘겼어요" % subject(me))
		else:
			toast("뽑을 타일이 없어서 넘겨요")
			set_status("%s 넘겼어요" % subject(me))
	view.interactive = false
	selected.clear()
	_after_human_turn(me)


func _after_human_turn(me: int) -> void:
	_busy = true
	_update_view()
	_update_buttons()
	_refresh_ui()
	var last_draw := int(logic.last.get("tile", -1)) if logic.last.get("type", "") == "draw" else -1
	if last_draw >= 0 and (ai_level >= 0 or _viewer == me):
		view.pop(last_draw)
	var tok := _token
	await wait(0.9)
	if tok != _token:
		return
	_busy = false
	_next_turn()


func _tile_name(t: int) -> String:
	if RummyLogic.is_joker(t):
		return "조커를"
	return "%s %s" % [RummyLogic.COLOR_NAMES[RummyLogic.color_of(t)], josa(str(RummyLogic.num_of(t)), "을", "를")]


# ── AI 차례 (생각은 별도 스레드에서) ───────────────────
func _start_ai() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_busy = true
	start_thinking("%s 생각 중" % player_name(logic.current))
	_ai_started_ms = Time.get_ticks_msec()
	_thread = Thread.new()
	_thread_token = _token
	_thread.start(ai.choose.bind(logic.clone(), logic.current))


func _apply_ai_result(result: Variant) -> void:
	var tok := _token
	var me := logic.current
	var elapsed := (Time.get_ticks_msec() - _ai_started_ms) / 1000.0
	if elapsed < 0.8:
		await wait(0.8 - elapsed)
		if tok != _token:
			return
	var tbl: Array = result if result is Array else []
	_fresh_ai = {}
	if not tbl.is_empty() and logic.commit(tbl) == "":
		for t in logic.last.get("tiles", []):
			_fresh_ai[t] = true
		var cnt := _fresh_ai.size()
		set_status("%s %d장 냈어요!" % [subject(me), cnt])
		toast("%s 타일을 모두 냈어요!" % subject(me) if logic.over else "%s %d장 냈어요" % [subject(me), cnt])
	else:
		var t := logic.draw_and_pass()
		set_status("%s 1장 뽑고 넘겼어요" % subject(me) if t >= 0 else "%s 넘겼어요" % subject(me))
	_update_view()
	_refresh_ui()
	await wait(1.1 if not _fresh_ai.is_empty() else 0.6)
	if tok != _token:
		return
	_busy = false
	_next_turn()


# ══════════════════════════════════════════════════════
#  화면 갱신 / 결과
# ══════════════════════════════════════════════════════
func _refresh_ui() -> void:
	for p in logic.n:
		var cnt := (logic.racks[p] as Array).size()
		if _is_human_turn() and p == logic.current and view != null and view.interactive:
			cnt = work_rack.size()
		set_card(p, player_name(p), "%d장" % cnt, not logic.over and logic.current == p)
	set_status_side(logic.current)


func _game_over() -> void:
	view.interactive = false
	_update_view()
	_update_buttons()
	record_result(logic.winner)
	if logic.by_points:
		set_status("더미가 떨어졌어요! 남은 점수로 승부")
	else:
		set_status("%s 타일을 모두 냈어요!" % subject(logic.winner))
	var tok := _token
	await wait(1.4)
	if tok != _token:
		return
	var sc := logic.final_scores()
	var order: Array = range(logic.n)
	order.sort_custom(func(a: int, b: int) -> bool: return int(sc[a]) > int(sc[b]))
	var rows: Array = []
	for p in order:
		var s: int = sc[p]
		rows.append({"p": p, "big": ("+%d" % s) if s > 0 else str(s), "small": "남은 타일 %d장" % (logic.racks[p] as Array).size()})
	var note := "더미가 떨어져서 남은 점수가 가장 적은 사람이 이겼어요" if logic.by_points else "남은 타일의 숫자 합만큼 점수가 깎여요 (조커 30)"
	show_standard_result(logic.winner, rows, note)
