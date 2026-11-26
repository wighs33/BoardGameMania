extends Node
## 전역 싱글톤 (Autoload: Global)
## - 게임 목록(허브에 표시될 보드게임들)
## - 설정/기록 저장
## - 화면 전환 페이드

const SAVE_PATH := "user://boardgamemania.cfg"
const HOME_SCENE := "res://scenes/main_menu.tscn"

## 새 게임을 추가하려면 여기에 항목을 하나 더 넣고 available 을 true 로!
var games: Array[Dictionary] = [
	{
		"id": "herochess",
		"title": "히어로 체스",
		"desc": "능력이 다른 영웅 10명으로\n상대 성을 무너뜨려요!",
		"tags": ["1~2인", "전략"],
		"scene": "res://games/herochess/hero_game.tscn",
		"color": Color("#3FA9F5"),
		"icon": "hero",
		"available": true,
	},
	{
		"id": "wall",
		"title": "벽 땅따먹기",
		"desc": "말을 옮기고 벽을 세워\n가장 넓은 땅을 차지하세요!",
		"tags": ["1~3인", "전략"],
		"scene": "res://games/wall/wall_game.tscn",
		"color": Color("#FF8A65"),
		"icon": "wall",
		"available": true,
	},
	{
		"id": "wall2",
		"title": "벽 땅따먹기 2",
		"desc": "네모 말과 동그라미 말,\n움직임이 다른 두 말로 승부!",
		"tags": ["1~3인", "전략"],
		"scene": "res://games/wall/wall2_game.tscn",
		"color": Color("#FF7EB6"),
		"icon": "wall2",
		"available": true,
	},
	{
		"id": "omok",
		"title": "오목",
		"desc": "다섯 알을 먼저\n나란히 놓으면 승리!",
		"tags": ["1~2인", "클래식"],
		"scene": "res://games/omok/omok_game.tscn",
		"color": Color("#9C88FF"),
		"icon": "omok",
		"available": true,
	},
	{
		"id": "reversi",
		"title": "리버시",
		"desc": "상대 돌을 사이에 끼워\n내 색으로 뒤집어요",
		"tags": ["1~2인", "클래식"],
		"scene": "res://games/reversi/reversi_game.tscn",
		"color": Color("#44C47A"),
		"icon": "reversi",
		"available": true,
	},
	{
		"id": "liar",
		"title": "라이어 찾기",
		"desc": "제시어를 모르는 라이어를\n다 같이 찾아내요!",
		"tags": ["3~8인", "파티"],
		"scene": "res://games/liar/liar_game.tscn",
		"color": Color("#26B8C9"),
		"icon": "liar",
		"available": true,
	},
	{
		"id": "davinci",
		"title": "비밀 숫자",
		"desc": "상대의 숨은 숫자 타일을\n추리해서 맞혀요",
		"tags": ["1~4인", "추리"],
		"scene": "res://games/davinci/davinci_game.tscn",
		"color": Color("#5C6BC0"),
		"icon": "davinci",
		"available": true,
	},
	{
		"id": "rummy",
		"title": "타일 러미",
		"desc": "숫자 타일로 묶음을 만들어\n먼저 다 내면 승리!",
		"tags": ["1~4인", "숫자"],
		"scene": "res://games/rummy/rummy_game.tscn",
		"color": Color("#F5A623"),
		"icon": "rummy",
		"available": true,
	},
	{
		"id": "fruitbell",
		"title": "과일 종치기",
		"desc": "같은 과일이 딱 5개면\n누구보다 빨리 종을 쳐요!",
		"tags": ["1~4인", "순발력"],
		"scene": "res://games/fruitbell/fruit_game.tscn",
		"color": Color("#FF6F91"),
		"icon": "fruit",
		"available": true,
	},
	{
		"id": "drawquiz",
		"title": "그림 퀴즈",
		"desc": "그림을 그리고 맞혀요!\n혼자서는 AI 그림 맞히기",
		"tags": ["1~8인", "파티"],
		"scene": "res://games/drawquiz/draw_game.tscn",
		"color": Color("#00B8A9"),
		"icon": "draw",
		"available": true,
	},
]

var _cfg := ConfigFile.new()
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	_cfg.load(SAVE_PATH)
	get_tree().root.theme = UIKit.make_theme()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = UIKit.BG_TOP
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


# ── 화면 전환 ──────────────────────────────────────────
func goto_scene(path: String) -> void:
	if _busy or path.is_empty():
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await t.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, 0.25)
	await t2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func go_home() -> void:
	goto_scene(HOME_SCENE)


# ── 설정 / 기록 ────────────────────────────────────────
func get_setting(game_id: String, key: String, default: Variant) -> Variant:
	return _cfg.get_value("settings_" + game_id, key, default)


func set_setting(game_id: String, key: String, value: Variant) -> void:
	_cfg.set_value("settings_" + game_id, key, value)
	_cfg.save(SAVE_PATH)


func get_stat(game_id: String, key: String) -> int:
	return int(_cfg.get_value("stats_" + game_id, key, 0))


func add_stat(game_id: String, key: String, amount: int = 1) -> void:
	_cfg.set_value("stats_" + game_id, key, get_stat(game_id, key) + amount)
	_cfg.save(SAVE_PATH)


# ── 노치/홈바 안전 영역 (모바일) ───────────────────────
func safe_top() -> int:
	if not OS.has_feature("mobile"):
		return 0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0
	var vp := get_tree().root.get_visible_rect().size
	return maxi(0, int(safe.position.y * vp.y / float(win.y)))


func safe_bottom() -> int:
	if not OS.has_feature("mobile"):
		return 0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0
	var vp := get_tree().root.get_visible_rect().size
	return maxi(0, int((win.y - safe.end.y) * vp.y / float(win.y)))
