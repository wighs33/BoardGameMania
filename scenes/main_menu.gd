extends Control
## 보드게임마니아 – 메인 메뉴 (게임 모음 허브)


func _ready() -> void:
	add_child(UIKit.make_background())
	add_child(BgDecor.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36 + Global.safe_top())
	margin.add_theme_constant_override("margin_bottom", 20 + Global.safe_bottom())
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# ── 헤더 ──
	var mascots := MascotRow.new()
	mascots.custom_minimum_size = Vector2(0, 100)
	vb.add_child(mascots)

	var title := WavyTitle.new()
	title.text = "보드게임마니아"
	title.font_size = 82
	title.custom_minimum_size = Vector2(0, 116)
	vb.add_child(title)

	vb.add_child(UIKit.make_label("모여라! 우리들의 보드게임 모음집", 28, UIKit.INK_SOFT))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vb.add_child(spacer)

	# ── 섹션 제목 ──
	var sec := HBoxContainer.new()
	var sec_label := UIKit.make_label("게임 목록", 34, UIKit.INK, 800, HORIZONTAL_ALIGNMENT_LEFT)
	sec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec.add_child(sec_label)
	var available := 0
	for g in Global.games:
		if g["available"]:
			available += 1
	var chip := UIKit.make_chip("%d / %d 플레이 가능" % [available, Global.games.size()], UIKit.GREEN, 22)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sec.add_child(chip)
	vb.add_child(sec)

	# ── 게임 카드 목록 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vb.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(pad)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 22)
	pad.add_child(list)

	var i := 0
	for g in Global.games:
		var card := _make_card(g)
		list.add_child(card)
		UIKit.pop_in(card, 0.08 + i * 0.07, 0.9)
		i += 1

	vb.add_child(UIKit.make_label("v0.1 · 새로운 게임이 곧 찾아와요!", 22, UIKit.INK_SOFT))


func _make_card(g: Dictionary) -> Control:
	var is_available: bool = g["available"]
	var color: Color = g["color"]

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color.WHITE, 36, 22))
	# 카드 위에서 시작한 손가락 밀기도 목록이 받게 (PanelContainer는 기본으로 터치를 붙잡음)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	panel.add_child(hb)

	var icon := GameIcon.new()
	icon.kind = g["icon"]
	icon.accent = color if is_available else UIKit.GREY
	icon.custom_minimum_size = Vector2(136, 136)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	hb.add_child(info)

	info.add_child(UIKit.make_label(g["title"], 36, UIKit.INK, 800, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UIKit.make_label(g["desc"], 22, UIKit.INK_SOFT, 700, HORIZONTAL_ALIGNMENT_LEFT))

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	for t in g["tags"]:
		tags.add_child(UIKit.make_chip(t, color.lightened(0.15) if is_available else UIKit.GREY, 19))
	if not is_available:
		tags.add_child(UIKit.make_chip("준비 중", UIKit.INK_SOFT, 19))
	else:
		var wins := Global.get_stat(g["id"], "wins")
		if wins > 0:
			tags.add_child(UIKit.make_chip("승리 %d" % wins, UIKit.GOLD.darkened(0.1), 19))
		var best := Global.get_stat(g["id"], "best")
		if best > 0:
			tags.add_child(UIKit.make_chip("최고 %d" % best, UIKit.GOLD.darkened(0.1), 19))
	info.add_child(tags)

	if is_available:
		var play := UIKit.make_round_button("play", color, 96)
		play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var scene_path: String = g["scene"]
		play.pressed.connect(func() -> void: Global.goto_scene(scene_path))
		hb.add_child(play)
	else:
		panel.self_modulate = Color(1, 1, 1, 0.8)
	return panel


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
