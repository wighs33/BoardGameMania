extends GameScreen
## 영웅키우기: 흰 영웅 하나가 바닥에서 끝없이 솟아오르는 검은 적들과 싸우는 3D 미니게임.
## 적은 화살 한 방에 쓰러지고, 영웅만 체력이 있어 머리 위에 체력바가 뜹니다.
## 이동: 화면을 누른 채 끌기 (누른 자리에 조이스틱이 생김), 또는 WASD
## 활: 오른쪽 아래 화살 방향 패드를 누르고 있는 동안 끄는 쪽으로 계속 쏩니다 (또는 방향키).
## 쏘는 동안 몸은 쏘는 쪽을 보고 다리는 걷는 쪽으로 걷습니다 (옆걸음·뒷걸음). 시위를 당기다 맞으면 끊깁니다.
## 영웅은 주먹을 쓰지 않습니다. 적은 주먹 전에 팔을 뒤로 당기므로, 그 사이에 피할 수 있습니다.
## 팝업(시작·게임 방법·나가기 확인·결과)이 떠 있는 동안은 3D 세상이 통째로 멈춥니다.

const FLOOR_SHADER := preload("res://games/herogrow/grow_floor.gdshader")

const ARENA := 9.0            # 격투장 반지름
const PITCH := 58.0           # 카메라가 내려다보는 각도 (도)
const VIEW_WIDTH := 5.5       # 화면 가로에 보이는 바닥 폭
const CAM_DISTANCE := 20.0
const BODY := 0.42            # 사람끼리 이보다 가까이 겹치지 않음
const REACH := 0.78           # 주먹이 닿는 거리 (몸 중심 사이)
const PLAYER_SPEED := 2.6
const ENEMY_SPEED := 1.25
const PLAYER_HP := 100.0
const ENEMY_DAMAGE := 7.0
const ENEMY_WINDUP := 0.28    # 적이 팔을 뒤로 당기는 시간 = 피할 틈
const STUN := 0.22            # 맞으면 이 시간 동안 아무것도 못 함
const RISE_TIME := 0.45       # 새 적이 바닥에서 솟아오르는 시간
const BOW_DRAW := 0.36        # 활을 꺼내 시위를 다 당기기까지
const BOW_COOLDOWN := 0.55    # 쏜 뒤 다음 화살까지
const ARROW_SPEED := 14.0
const ARROW_RANGE := 9.0
const ARROW_HIT := 0.2        # 화살과 적 몸 중심이 이만큼 가까우면 맞음
const STICK_R := 90.0
const AIM_R := 90.0           # 화살 방향 패드 반지름
const AIM_DEAD := 0.25        # 패드 가운데를 이만큼 안 벗어나면 방향 없음 (바라보는 쪽으로 쏨)
const PLAYER_BAR := Color(0.32, 0.8, 0.42)
const OVER_DELAY := 0.9       # 쓰러진 뒤 결과 창이 뜨기까지


class Fighter:
	var body: GrowPerson
	var player := false
	var hp := 1.0                 # 적은 1 = 한 방이면 쓰러짐
	var max_hp := 1.0
	var bar_hp := 1.0             # 체력바의 흰 부분 (깎인 만큼 천천히 따라 내려감)
	var vel := Vector2.ZERO
	var knock := Vector2.ZERO     # 맞아서 밀려나는 빠르기
	var cooldown := 0.0
	var punch_t := -1.0           # 주먹 낸 뒤 흐른 시간. -1 = 안 냄
	var windup := 0.0
	var landed := false           # 이번 주먹의 맞는 순간이 지났는지
	var stun := 0.0
	var rise := 0.0               # 바닥에서 솟아오르는 중이면 남은 시간
	var pace := 1.0
	var aim_t := -1.0             # 활 시위를 당기기 시작한 뒤 흐른 시간. -1 = 안 당김
	var bow_cd := 0.0

	func pos() -> Vector2:
		return Vector2(body.position.x, body.position.z)

	func facing() -> Vector2:
		return Vector2(-sin(body.rotation.y), -cos(body.rotation.y))


var player: Fighter
var enemies: Array[Fighter] = []
var kills := 0
var cam: Camera3D

var _world: Node3D                # 3D 세상 전부 (팝업이 뜨면 통째로 멈춤)
var _fallen: Array = []           # 쓰러진 적 {f, knock, t, size}: 잠시 누워 있다가 작아지며 사라짐
var _bursts: Array = []           # 맞은 자리 번쩍임 {at, t}
var _arrows: Array = []           # 날아가거나 바닥에 떨어진 화살 {node, dir, dist, fly, t}
var _spawn_timer := 1.0
var _game_over := false
var _over_t := 0.0
var _result_shown := false
var _paused := false
var _stick_id := -1
var _stick_from := Vector2.ZERO
var _stick := Vector2.ZERO
var _aim_id := -1                 # 화살 방향 패드를 누른 손가락
var _aim := Vector2.ZERO          # 패드 가운데에서 손가락까지 (패드 반지름 = 1)
var _aim_dir := Vector2.ZERO      # 지금 쏘는 방향. 손을 떼도 당기던 화살은 이 방향으로 나감
var _aim_tap := 0.0               # 패드를 누른 걸 잠깐 기억 (톡 누르고 바로 떼도 한 발 나가게)
var _shake := 0.0
var _cam_at := Vector2.ZERO
var _hud: Control
var _top: Control                 # 상단 바 (뒤로 · 제목 · 게임 방법). 여기서 시작한 터치는 조이스틱이 아님
var _kills_label: Label
var _old_touch_emulation := false


# ══════════════════════════════════════════════════════
#  GameScreen 덮어쓰기
# ══════════════════════════════════════════════════════
func _game_title() -> String:
	return "영웅키우기"


func _rules_text() -> String:
	return ("[b]목표[/b]  바닥에서 끝없이 솟아오르는 검은 적을 쓰러뜨리며 최대한 오래 버텨요.\n"
		+ "[b]이동[/b]  화면 아무 곳이나 누른 채 끌면 그 자리에 조이스틱이 생겨요.\n"
		+ "[b]활[/b]  오른쪽 아래 동그란 패드를 누르고 있는 동안, 끄는 쪽으로 화살이 계속 나가요. 쏘는 동안 영웅은 그쪽을 보고, 발은 걷는 쪽으로 걸어요. 시위를 당기다 맞으면 끊겨요.\n"
		+ "[b]적[/b]  화살 한 방에 쓰러져요. 주먹을 내기 전에 팔을 뒤로 당기니, 그 틈에 피하세요.\n"
		+ "[b]체력[/b]  맞을 때마다 줄어들고, 다 떨어지면 끝나요. 많이 쓰러뜨릴수록 적이 한꺼번에 더 많이 나와요.\n"
		+ "[b]키보드[/b]  이동 WASD, 활 방향키 (누르고 있는 동안 그쪽으로 쏴요)")


func _setup_title() -> String:
	return "몇 명이나 쓰러뜨릴까요?"


func _mode_ids() -> Array:
	return []


func _add_setup_options(box: VBoxContainer) -> void:
	var best := Global.get_stat(game_id, "best")
	var text := "최고 기록  %d명" % best if best > 0 else "흰 영웅 혼자서 검은 적을 막아 내요!"
	box.add_child(UIKit.make_label(text, 28, UIKit.INK_SOFT, 800))


func _start_game() -> void:
	close_overlay()
	restart()


func _is_game_over() -> bool:
	return _game_over


# ══════════════════════════════════════════════════════
#  화면 구성
# ══════════════════════════════════════════════════════
func _ready() -> void:
	game_id = "herogrow"
	# PC에서도 마우스로 조이스틱·버튼을 누를 수 있게 (이 화면에서만)
	_old_touch_emulation = Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	GrowPerson.set_colors(Color(0.98, 0.98, 0.98), Color(0.05, 0.05, 0.05), 2.0, "player")
	GrowPerson.set_colors(Color(0.06, 0.06, 0.06), Color.WHITE, 2.0, "enemy")
	_world = Node3D.new()
	add_child(_world)
	_build_world()
	_build_ui()
	restart()
	show_setup()


func _exit_tree() -> void:
	Input.emulate_touch_from_mouse = _old_touch_emulation


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.7, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-66, 215, 0)
	# 이 렌더러에서는 해가 생각보다 밝게 들어와서 약하게 둠: 빛 받는 바닥 ≈ 바닥색 그대로, 그림자 ≈ 0.55배
	sun.light_energy = 0.16
	sun.light_specular = 0.0
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 32.0
	_world.add_child(sun)

	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("radius", ARENA)
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	plane.material = mat
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(ground)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = VIEW_WIDTH
	cam.near = 1.0
	cam.far = 32.0   # 길게 두면 그림자가 계단처럼 깨짐
	cam.rotation = Vector3(-deg_to_rad(PITCH), 0, 0)
	_world.add_child(cam)


## 화면 위 그림(체력바·조이스틱·버튼) → 상단 바 → 팝업 순서로 쌓음 (팝업이 맨 위)
func _build_ui() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	add_child(_hud)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22 + Global.safe_top())
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# 상단 바: 다른 게임과 같은 모양 (뒤로 / 제목 / 게임 방법)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_top = top
	var back := UIKit.make_round_button("back", UIKit.PURPLE)
	back.pressed.connect(_on_back)
	top.add_child(back)
	var title := UIKit.make_label(_game_title(), 42, UIKit.INK, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var help := UIKit.make_round_button("help", UIKit.ORANGE)
	help.pressed.connect(show_rules.bind(false))
	top.add_child(help)

	_kills_label = UIKit.make_label("", 34, Color(0.08, 0.08, 0.08), 800)
	col.add_child(_kills_label)

	# 팝업 레이어 (GameScreen 의 시작·게임 방법·나가기 확인·결과 창이 여기에 뜸)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)


## 처음부터 다시: 적·쓰러진 사람·화살을 치우고 영웅을 가운데에 새로 세웁니다.
func restart() -> void:
	for e: Fighter in enemies:
		e.body.queue_free()
	enemies.clear()
	for d in _fallen:
		d.f.body.queue_free()
	_fallen.clear()
	for a in _arrows:
		a.node.queue_free()
	_arrows.clear()
	_bursts.clear()
	if player != null:
		player.body.queue_free()
	player = _make_fighter(true, Vector2.ZERO)
	player.body.give_bow()
	kills = 0
	_spawn_timer = 1.0
	_game_over = false
	_over_t = 0.0
	_result_shown = false
	_cam_at = Vector2.ZERO
	_place_camera()   # 시작 창 뒤로도 영웅이 보이게 (멈춘 동안은 _process 가 카메라를 옮기지 않음)
	_reset_touches()


func _make_fighter(is_player: bool, at: Vector2) -> Fighter:
	var f := Fighter.new()
	f.player = is_player
	var body := GrowPerson.new()
	body.look = "player" if is_player else "enemy"
	body.position = Vector3(at.x, 0, at.y)
	if not is_player:
		body.scale = Vector3.ONE * randf_range(0.95, 1.05)
	_world.add_child(body)
	f.body = body
	if is_player:
		f.max_hp = PLAYER_HP
		f.hp = PLAYER_HP
		f.bar_hp = PLAYER_HP
	else:
		f.pace = randf_range(0.85, 1.15)
		f.cooldown = randf_range(0.3, 0.8)
	return f


# ══════════════════════════════════════════════════════
#  입력
# ══════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if _paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _top.get_global_rect().grow(8.0).has_point(event.position):
				return   # 뒤로 · 게임 방법 버튼 자리
			if _game_over:
				if _result_shown:
					reopen_result()   # '판 보기'로 결과 창을 닫은 뒤 화면을 누르면 다시 열림
				return
			if _aim_id < 0 and event.position.distance_to(_pad_center()) < AIM_R + 16.0:
				_aim_id = event.index
				_aim = ((event.position - _pad_center()) / AIM_R).limit_length(1.0)
				_aim_tap = 0.15
				if _aim.length() > AIM_DEAD:
					_aim_dir = _aim.normalized()
			elif _stick_id < 0:
				_stick_id = event.index
				_stick_from = event.position
				_stick = Vector2.ZERO
		else:
			if event.index == _stick_id:
				_stick_id = -1
				_stick = Vector2.ZERO
			if event.index == _aim_id:
				_aim_id = -1
				_aim = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			var d: Vector2 = event.position - _stick_from
			if d.length() > STICK_R:   # 손가락이 멀리 가면 조이스틱 밑판이 따라감
				_stick_from = event.position - d.normalized() * STICK_R
				d = d.normalized() * STICK_R
			_stick = d / STICK_R
		elif event.index == _aim_id:   # 패드는 제자리. 손가락이 밖으로 나가도 방향만 따라감
			_aim = ((event.position - _pad_center()) / AIM_R).limit_length(1.0)


## 팝업이 뜨는 동안 놓친 손가락 떼기를 대신 처리 (조이스틱·패드가 눌린 채로 남지 않게)
func _reset_touches() -> void:
	_stick_id = -1
	_stick = Vector2.ZERO
	_aim_id = -1
	_aim = Vector2.ZERO
	_aim_tap = 0.0


func _move_input() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if v != Vector2.ZERO:
		return v.normalized()
	return _stick.limit_length(1.0)   # 카메라가 돌아가 있지 않아 화면 오른쪽 = +x, 아래 = +z


## 화살 방향키 (PC): 누르고 있는 쪽
func _key_aim() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).normalized()


## 쏘는 중인지 (패드나 방향키를 누르고 있음, 또는 방금 톡 누름)
func _aim_held() -> bool:
	return _aim_id >= 0 or _aim_tap > 0.0 or _key_aim() != Vector2.ZERO


## 쏠 방향. 패드 가운데 근처만 누르고 있으면 ZERO
func _aim_input() -> Vector2:
	var k := _key_aim()
	if k != Vector2.ZERO:
		return k
	if _aim_id >= 0 and _aim.length() > AIM_DEAD:
		return _aim.normalized()
	return Vector2.ZERO


func _pad_center() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	return Vector2(vs.x - 130.0, vs.y - 170.0 - Global.safe_bottom())


# ══════════════════════════════════════════════════════
#  매 프레임
# ══════════════════════════════════════════════════════
func _process(delta: float) -> void:
	var paused := not _overlay_kind.is_empty()
	if paused != _paused:
		_paused = paused
		_world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
		_reset_touches()
		_hud.queue_redraw()
	if _paused:
		return
	delta = minf(delta, 0.05)

	_update_player(delta)
	_update_enemies(delta)
	_update_arrows(delta)
	_separate()
	_update_fallen(delta)
	_spawn(delta)

	player.bar_hp = move_toward(player.bar_hp, player.hp, player.max_hp * 0.8 * delta)
	for b in _bursts.duplicate():
		b.t += delta
		if b.t > 0.18:
			_bursts.erase(b)

	_cam_at = _cam_at.lerp(player.pos(), 1.0 - exp(-5.0 * delta))
	_place_camera()
	if _shake > 0.0:
		_shake -= delta
		cam.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.07 * _shake / 0.18

	if _game_over:
		_over_t += delta
		if _over_t > OVER_DELAY and not _result_shown:
			_result_shown = true
			_show_over()
	_kills_label.text = "쓰러뜨린 적  %d" % kills
	_hud.queue_redraw()


## 카메라: _cam_at 을 PITCH 각도로 CAM_DISTANCE 만큼 떨어져 내려다봄
func _place_camera() -> void:
	var pitch := deg_to_rad(PITCH)
	cam.position = Vector3(_cam_at.x, 0, _cam_at.y) + Vector3(0, sin(pitch), cos(pitch)) * CAM_DISTANCE


## 쓰러진 뒤 결과 창. 최고 기록(쓰러뜨린 적 수)을 넘으면 새 기록으로 저장하고 축하합니다.
func _show_over() -> void:
	var best := Global.get_stat(game_id, "best")
	var record := kills > best
	Global.add_stat(game_id, "played")
	if record:
		Global.set_stat(game_id, "best", kills)
	var note := "쓰러뜨린 적  %d명\n최고 기록  %d명" % [kills, maxi(kills, best)]
	show_result("새 기록!" if record else "쓰러졌어요", UIKit.ORANGE if record else UIKit.PURPLE, record, -1, [], note, "다시 하기")


func _update_player(delta: float) -> void:
	var f := player
	f.bow_cd -= delta
	f.stun -= delta
	_aim_tap -= delta
	if _game_over:
		f.vel = Vector2.ZERO
		_move(f, delta)
		return
	var input := _move_input()
	var want := input * PLAYER_SPEED
	if f.stun > 0.0:
		want = Vector2.ZERO   # 맞으면 잠깐 멈춰 섬
	f.vel = f.vel.lerp(want, 1.0 - exp(-14.0 * delta))

	# 활: 패드를 누르고 있는 동안 그 방향으로 계속 쏨 (시위를 당기는 동안에도 그대로 걸음)
	var shooting := _aim_held()
	var aim := _aim_input()
	if aim != Vector2.ZERO:
		_aim_dir = aim
	elif not shooting and f.aim_t < 0.0:
		_aim_dir = Vector2.ZERO   # 손을 떼고 당기던 화살도 다 쏘면 방향을 잊음
	if f.aim_t >= 0.0:
		f.aim_t += delta
		if f.aim_t >= BOW_DRAW:
			_fire(f)
	elif shooting and f.stun <= 0.0 and f.bow_cd <= 0.0:
		if _aim_dir == Vector2.ZERO:
			_aim_dir = f.facing()   # 패드 가운데만 눌렀으면 바라보던 쪽으로
		f.aim_t = 0.0
		f.body.shoot(BOW_DRAW)
		_aim_tap = 0.0

	# 몸: 쏘는 동안은 쏘는 쪽을, 아니면 걷는 쪽을 봄 (다리는 _move 에서 걷는 쪽으로)
	if f.stun <= 0.0:
		if (shooting or f.aim_t >= 0.0) and _aim_dir != Vector2.ZERO:
			_face(f, _aim_dir, 1.0 - exp(-18.0 * delta))
		elif input.length() > 0.1:
			_face(f, input, 1.0 - exp(-14.0 * delta))
	_move(f, delta)


## 시위를 놓아 화살을 날립니다. 화살은 패드로 정한 방향으로 곧게 날아갑니다.
func _fire(f: Fighter) -> void:
	var nocked: Transform3D = f.body.release()
	f.aim_t = -1.0
	f.bow_cd = BOW_COOLDOWN
	if _aim_dir != Vector2.ZERO:
		_face(f, _aim_dir, 1.0)   # 몸이 아직 덜 돌았어도 정한 방향 그대로
	var dir := f.facing()
	var arrow := GrowPerson.make_arrow("player")
	_world.add_child(arrow)
	arrow.transform = Transform3D(Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP), nocked.origin)
	_arrows.append({"node": arrow, "dir": dir, "dist": 0.0, "fly": true, "t": 0.0})


func _update_arrows(delta: float) -> void:
	for a in _arrows.duplicate():
		var node: Node3D = a.node
		var dir: Vector2 = a.dir
		if a.fly:
			var step := ARROW_SPEED * delta
			var nock := Vector2(node.position.x, node.position.z)
			var from := nock + dir * 0.25
			var to := nock + dir * (GrowPerson.ARROW_LENGTH + step)
			var hit: Fighter = null
			var best := INF
			for e: Fighter in enemies:
				if e.rise > 0.0:
					continue
				var c := e.pos()
				var q := Geometry2D.get_closest_point_to_segment(c, from, to)
				if q.distance_to(c) < ARROW_HIT and q.distance_to(from) < best:
					best = q.distance_to(from)
					hit = e
			if hit != null:
				_arrow_hit(a, hit)
				continue
			node.position += Vector3(dir.x, 0, dir.y) * step
			a.dist += step
			if a.dist > ARROW_RANGE:
				a.fly = false
		else:
			# 끝까지 날아간 화살은 촉부터 바닥에 떨어져 꽂혔다가 사라짐
			a.t += delta
			if a.t < 0.15:
				node.position += Vector3(dir.x, 0, dir.y) * ARROW_SPEED * 0.3 * delta
				node.position.y = maxf(node.position.y - 4.5 * delta, 0.12)
				node.rotate_object_local(Vector3.RIGHT, -0.5 * delta / 0.15)
			if a.t > 1.0:
				node.queue_free()
				_arrows.erase(a)


## 화살이 적에게 맞음: 촉이 몸에 조금 박힌 채로 붙어서 함께 쓰러집니다.
func _arrow_hit(a: Dictionary, e: Fighter) -> void:
	var node: Node3D = a.node
	var dir: Vector2 = a.dir
	var nock := e.pos() - dir * (GrowPerson.ARROW_LENGTH + 0.04)
	node.position = Vector3(nock.x, node.position.y, nock.y)
	_arrows.erase(a)
	_hit(player, e, dir)
	e.body.attach(node)


func _update_enemies(delta: float) -> void:
	for e: Fighter in enemies.duplicate():
		e.cooldown -= delta
		e.stun -= delta
		if e.rise > 0.0:
			e.rise -= delta
			var k := clampf(e.rise / RISE_TIME, 0.0, 1.0)
			e.body.position.y = -1.15 * k * k
			continue
		var to := player.pos() - e.pos()
		var d := to.length()
		var want := Vector2.ZERO
		if _game_over:
			pass
		elif e.stun <= 0.0 and e.punch_t < 0.0:
			if d > REACH - 0.08:
				want = to / d * ENEMY_SPEED * e.pace
			elif e.cooldown <= 0.0:
				_start_punch(e, ENEMY_WINDUP)
				e.cooldown = randf_range(0.9, 1.6)
			_face(e, to, 1.0 - exp(-10.0 * delta))
		elif e.punch_t >= 0.0 and e.punch_t < e.windup:
			_face(e, to, 1.0 - exp(-5.0 * delta))   # 팔을 당기는 동안은 천천히 따라 돎 → 옆으로 피할 수 있음
		e.vel = e.vel.lerp(want, 1.0 - exp(-8.0 * delta))
		_move(e, delta)
		if not _game_over:
			_tick_punch(e, delta, [player])


func _start_punch(f: Fighter, windup: float) -> void:
	f.punch_t = 0.0
	f.windup = windup
	f.landed = false
	f.body.punch(windup)


## 주먹이 다 뻗는 순간 앞쪽 REACH 안에 있는 상대를 때립니다.
## 지금은 적만 주먹을 쓰고, 적은 영웅 하나만 때립니다.
func _tick_punch(f: Fighter, delta: float, targets: Array) -> void:
	if f.punch_t < 0.0:
		return
	f.punch_t += delta
	if not f.landed and f.punch_t >= f.windup + GrowPerson.PUNCH_PEAK:
		f.landed = true
		for t in targets.duplicate():
			if t.hp <= 0.0 or t.rise > 0.0:
				continue
			var d: Vector2 = t.pos() - f.pos()
			var dist := d.length()
			var dir := d / dist if dist > 0.001 else f.facing()
			if dist < REACH + 0.12 and dir.dot(f.facing()) > 0.5:
				_hit(f, t, dir)
	if f.punch_t >= f.windup + GrowPerson.PUNCH_TIME:
		f.punch_t = -1.0


## 맞음. 적은 무조건 한 방에 쓰러지고, 영웅은 체력이 깎이다가 0이 되면 쓰러집니다.
func _hit(attacker: Fighter, target: Fighter, dir: Vector2) -> void:
	target.knock = dir * (3.2 if attacker.player else 2.4)
	target.punch_t = -1.0   # 맞으면 내던 주먹이나 당기던 활이 끊김
	target.aim_t = -1.0
	target.stun = STUN
	_bursts.append({"at": target.body.position + Vector3(-dir.x * 0.18, 0.75, -dir.y * 0.18), "t": 0.0})
	if target.player:
		_shake = 0.18
		target.hp = maxf(target.hp - ENEMY_DAMAGE, 0.0)
		if target.hp > 0.0:
			target.body.hurt()
			return
	target.hp = 0.0
	target.body.knock_out()
	if target.player:
		_game_over = true
		_over_t = 0.0
	else:
		enemies.erase(target)
		kills += 1
		_fallen.append({"f": target, "knock": target.knock * 1.3, "t": 0.0, "size": target.body.scale.x})


func _move(f: Fighter, delta: float) -> void:
	var p := (f.pos() + (f.vel + f.knock) * delta).limit_length(ARENA - 0.3)
	f.knock = f.knock.move_toward(Vector2.ZERO, 12.0 * delta)
	f.body.position.x = p.x
	f.body.position.z = p.y
	f.body.speed = f.vel.length()
	if f.vel.length() > 0.05:   # 다리는 걷는 쪽으로 (몸이 다른 쪽을 보며 쏠 때 옆걸음·뒷걸음)
		f.body.walk_angle = -f.facing().angle_to(f.vel)


func _face(f: Fighter, dir: Vector2, weight: float) -> void:
	if dir.length() < 0.001:
		return
	f.body.rotation.y = lerp_angle(f.body.rotation.y, atan2(-dir.x, -dir.y), weight)


## 사람끼리 겹치면 서로 밀어냅니다. 영웅은 덜 밀려서 적에게 둘러싸여도 헤쳐 나갈 수 있음.
func _separate() -> void:
	var all: Array = enemies.duplicate()
	if not _game_over:
		all.append(player)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Fighter = all[i]
			var b: Fighter = all[j]
			if a.rise > 0.0 or b.rise > 0.0:
				continue
			var d := b.pos() - a.pos()
			var dist := d.length()
			if dist >= BODY:
				continue
			var n := d / dist if dist > 0.001 else Vector2.RIGHT
			var share := 0.3 if a.player else (0.7 if b.player else 0.5)
			var gap := Vector3(n.x, 0, n.y) * (BODY - dist)
			a.body.position -= gap * share
			b.body.position += gap * (1.0 - share)


func _update_fallen(delta: float) -> void:
	for d in _fallen.duplicate():
		d.t += delta
		var body: GrowPerson = d.f.body
		var k: Vector2 = d.knock
		body.position += Vector3(k.x, 0, k.y) * delta
		d.knock = k.move_toward(Vector2.ZERO, 10.0 * delta)
		if d.t > 1.4:   # 잠시 누워 있다가 작아지며 사라짐 (꽂힌 화살도 같이)
			body.scale = Vector3.ONE * maxf(1.0 - (d.t - 1.4) / 0.3, 0.01) * d.size
		if d.t > 1.7:
			body.queue_free()
			_fallen.erase(d)


## 적은 영웅 근처(3.2 이상 떨어진 곳) 바닥에서 솟아오릅니다. 많이 쓰러뜨릴수록 한꺼번에 더 많이 나옴.
func _spawn(delta: float) -> void:
	if _game_over:
		return
	_spawn_timer -= delta
	var cap := mini(2 + kills / 3, 8)
	if _spawn_timer > 0.0 or enemies.size() >= cap:
		return
	_spawn_timer = randf_range(0.8, 1.6)
	var at := Vector2.ZERO
	for tries in 12:
		at = Vector2.from_angle(randf() * TAU) * randf_range(2.0, ARENA - 0.8)
		if at.distance_to(player.pos()) > 3.2 and at.distance_to(player.pos()) < 6.0:
			break
	var e := _make_fighter(false, at)
	e.rise = RISE_TIME
	e.body.position.y = -1.15
	var to := player.pos() - at
	e.body.rotation.y = atan2(-to.x, -to.y)
	enemies.append(e)


# ══════════════════════════════════════════════════════
#  화면 위 그림 (체력바, 번쩍임, 조이스틱, 화살 방향 패드)
# ══════════════════════════════════════════════════════
func _draw_hud() -> void:
	_draw_bar(player, 1.0 if not _game_over else clampf(1.0 - _over_t / 0.4, 0.0, 1.0))

	for b in _bursts:
		var c := cam.unproject_position(b.at)
		var k: float = b.t / 0.18
		for i in 8:
			var dir := Vector2.from_angle(i * TAU / 8.0 + 0.3)
			var p0 := c + dir * (12.0 + 24.0 * k)
			var p1 := c + dir * (24.0 + 34.0 * k)
			_hud.draw_line(p0, p1, Color(0, 0, 0, 1.0 - k), 7.0)
			_hud.draw_line(p0, p1, Color(1, 1, 1, 1.0 - k), 3.0)

	if _stick_id >= 0:
		_hud.draw_circle(_stick_from, STICK_R, Color(0, 0, 0, 0.1))
		_hud.draw_arc(_stick_from, STICK_R, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 3.0, true)
		_hud.draw_circle(_stick_from + _stick * STICK_R, 36.0, Color(0, 0, 0, 0.45))

	if _game_over:
		return
	# 화살 방향 패드: 밑판은 제자리, 손잡이가 손가락 쪽으로 움직임 (그쪽으로 화살이 나감)
	var pc := _pad_center()
	var held := _aim_held()
	_hud.draw_circle(pc, AIM_R, Color(0.08, 0.08, 0.08, 0.32 if held else 0.18))
	_hud.draw_arc(pc, AIM_R, 0.0, TAU, 64, Color(0.08, 0.08, 0.08, 0.85), 4.0, true)
	var off := _aim if _aim_id >= 0 else _key_aim()
	var kc := pc + off * (AIM_R - 30.0)
	var kr := 44.0
	_hud.draw_circle(kc, kr, Color(0.08, 0.08, 0.08, 1.0 if held else 0.88))
	_hud.draw_arc(kc, kr, 0.0, TAU, 48, Color.WHITE, 4.0, true)
	_hud.draw_string(UIKit.font(800), kc + Vector2(-kr, 11.0), "활", HORIZONTAL_ALIGNMENT_CENTER, kr * 2.0, 32, Color.WHITE)


## 머리 위 체력바 (영웅만): 검은 테두리, 회색 빈 칸, 흰색 = 방금 깎인 만큼, 초록 = 남은 체력
func _draw_bar(f: Fighter, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var top: Vector3 = f.body.position + Vector3(0, 1.3 * f.body.scale.y, 0)
	var at := cam.unproject_position(top)
	var w := 88.0
	var h := 12.0
	var r := Rect2(at.x - w * 0.5, at.y - h, w, h)
	_hud.draw_rect(r.grow(2.5), Color(0.03, 0.03, 0.03, alpha))
	_hud.draw_rect(r, Color(0.35, 0.35, 0.35, alpha))
	_hud.draw_rect(Rect2(r.position, Vector2(w * f.bar_hp / f.max_hp, h)), Color(1, 1, 1, alpha))
	_hud.draw_rect(Rect2(r.position, Vector2(w * f.hp / f.max_hp, h)), Color(PLAYER_BAR, alpha))
