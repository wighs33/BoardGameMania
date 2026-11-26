class_name GrowPerson
extends Node3D
## 얼굴 없는 단색 사람 하나.
## 머리·몸통·팔·다리를 기본 도형(공, 캡슐)으로 짜 맞추고, speed에 맞춰 걷는 동작을 합니다.
## 주먹(punch), 맞기(hurt), 쓰러지기(knock_out), 활 쏘기(give_bow → shoot → release) 동작도 있습니다.
## 색은 이름 붙은 색 묶음(look)으로 나눠 쓰며, set_colors() 로 그 묶음을 쓰는 사람 모두의 색을 바꿉니다.
## 키는 약 1.07 (발끝 y = 0), 앞쪽은 -Z 입니다.

const OUTLINE_SHADER := preload("res://games/herogrow/grow_outline.gdshader")
const STEP_LENGTH := 0.42   # 한 걸음 길이. 움직이는 빠르기와 발놀림을 맞추는 데 씀
const PUNCH_TIME := 0.3     # 주먹을 뻗었다가 거둬들이는 시간 (준비 동작은 빼고)
const PUNCH_PEAK := 0.09    # 주먹을 다 뻗는 순간 (준비 동작이 끝난 뒤부터 잼)
const FLASH_LOOK := "flash" # 맞는 순간 잠깐 바뀌는 색 묶음
const ARM_LENGTH := 0.31    # 어깨에서 주먹 끝까지

# 활: 손잡이가 원점, 활대는 앞(-Y)으로 휘고 양 끝은 ±X, 시위는 두 끝 사이 (+Y 쪽)
const BOW_RADIUS := 0.48
const BOW_ANGLE := 0.72
const BOW_TIP := Vector3(0.3165, 0.1191, 0.0)      # = (R sin A, R (1 - cos A), 0)
const ARROW_LENGTH := 0.62                          # 화살 오늬(0)에서 촉 끝(-Z)까지
const DRAW_BACK := 0.40                             # 다 당겼을 때 손잡이에서 시위까지
const RECOVER := 0.35                               # 쏜 뒤 활을 등으로 돌리는 시간
const BOW_ON_BACK := Transform3D(Basis(Vector3.BACK, 0.87), Vector3(0, 0.6, 0.17))   # 등에 비스듬히 멤

## 지금 움직이는 빠르기 (초당 거리). 0이면 제자리에 서 있습니다.
var speed := 0.0
## 걷는 방향: 바라보는 쪽 기준으로 돈 각 (Y축 회전, 라디안). 0 = 앞으로 걸음.
## 몸은 다른 쪽을 보며 옆·뒤로 걸을 때 다리가 그쪽으로 걷습니다 (옆보다 뒤쪽이면 뒷걸음질).
var walk_angle := 0.0
## 이 사람이 쓰는 색 묶음 이름. "default" = 검은 몸에 흰 선.
var look := "default":
	set(value):
		look = value
		_apply_material(_look_mat(look))

static var _looks := {}     # 색 묶음 이름 → 몸 재질 (윤곽선은 그 재질의 next_pass)
static var _meshes := {}
static var _string_mat: StandardMaterial3D

var _parts: Array[MeshInstance3D] = []
var _hips: Node3D          # 다리까지 포함한 몸 전체. 걸을 때 들썩이고 살짝 숙임
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _phase := randf() * TAU
var _walk := 0.0           # 0 = 서 있음, 1 = 보통 걸음
var _stride := 1.0         # 1 = 앞으로 걸음, -1 = 뒷걸음
var _leg_yaw := 0.0        # 다리가 걷는 쪽으로 돈 각 (몸 기준)
var _breath := randf() * TAU
var _punch_t := -1.0       # 주먹 동작이 시작된 뒤 흐른 시간. -1 = 주먹 안 냄
var _windup := 0.0         # 주먹 전에 팔을 뒤로 당기는 시간
var _punch_arm := 0        # 0 = 왼팔, 1 = 오른팔 (번갈아 냄)
var _hurt_t := -1.0
var _flash := 0.0
var _down_t := -1.0        # 쓰러지기 시작한 뒤 흐른 시간. -1 = 서 있음

var _bow: Node3D           # 활 (없으면 null). 평소엔 등에, 쏠 때는 왼손에
var _strings: Array[MeshInstance3D] = []   # 시위 두 가닥 (활 끝 → 당기는 손 → 다른 활 끝)
var _nocked: Node3D        # 시위에 건 화살 (쏘면 숨기고, 날아가는 화살은 demo 가 따로 만듦)
var _aim_t := -1.0         # 활 쏘기 시작한 뒤 흐른 시간. -1 = 안 쏨
var _draw_time := 0.3
var _released := false
var _release_at := 0.0


## 색 묶음 look_name 의 몸 색, 윤곽선 색, 윤곽선 굵기(화면 픽셀)를 바꿉니다.
static func set_colors(body: Color, line: Color, width_px: float = 2.0, look_name: String = "default") -> void:
	var mat := _look_mat(look_name)
	mat.albedo_color = body
	var line_mat: ShaderMaterial = mat.next_pass
	line_mat.set_shader_parameter("line_color", line)
	line_mat.set_shader_parameter("width_px", width_px)


static func _look_mat(look_name: String) -> StandardMaterial3D:
	if not _looks.has(look_name):
		var line_mat := ShaderMaterial.new()
		line_mat.shader = OUTLINE_SHADER
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.next_pass = line_mat
		_looks[look_name] = mat
		if look_name == FLASH_LOOK:
			set_colors(Color(0.55, 0.55, 0.55), Color.WHITE, 2.0, look_name)
		else:
			set_colors(Color(0.07, 0.07, 0.07), Color.WHITE, 2.0, look_name)
	return _looks[look_name]


static func _mesh(kind: String) -> Mesh:
	if _meshes.is_empty():
		var head := SphereMesh.new()
		head.radius = 0.16
		head.height = 0.32
		head.radial_segments = 20
		head.rings = 10
		var torso := CapsuleMesh.new()
		torso.radius = 0.15
		torso.height = 0.46
		torso.radial_segments = 16
		torso.rings = 6
		var leg := CapsuleMesh.new()
		leg.radius = 0.062
		leg.height = 0.40
		leg.radial_segments = 10
		leg.rings = 3
		var arm := CapsuleMesh.new()
		arm.radius = 0.05
		arm.height = 0.34
		arm.radial_segments = 10
		arm.rings = 3
		var shaft := CylinderMesh.new()   # 화살대 (축 = Y)
		shaft.top_radius = 0.011
		shaft.bottom_radius = 0.011
		shaft.height = ARROW_LENGTH - 0.07
		shaft.radial_segments = 6
		shaft.rings = 1
		var head_tip := CylinderMesh.new()   # 화살촉 (위쪽이 뾰족)
		head_tip.top_radius = 0.0
		head_tip.bottom_radius = 0.032
		head_tip.height = 0.08
		head_tip.radial_segments = 8
		head_tip.rings = 1
		var feather := CapsuleMesh.new()   # 깃 (가는 막대 두 개를 뒤로 벌려 붙임)
		feather.radius = 0.009
		feather.height = 0.1
		feather.radial_segments = 6
		feather.rings = 2
		var string := CylinderMesh.new()   # 시위 (높이 1 을 늘려 씀)
		string.top_radius = 0.007
		string.bottom_radius = 0.007
		string.height = 1.0
		string.radial_segments = 4
		string.rings = 1
		_meshes = {"head": head, "torso": torso, "leg": leg, "arm": arm, "shaft": shaft,
			"arrow_head": head_tip, "feather": feather, "string": string, "bow": _bow_mesh()}
	return _meshes[kind]


## 활대: 손잡이는 굵고 끝으로 갈수록 가는 휜 관 하나 (윤곽선이 마디 없이 매끈하게 나오도록 한 덩어리로 만듦)
static func _bow_mesh() -> ArrayMesh:
	const SEG := 28
	const RING := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ends := []   # [중심, 바깥 방향, 반지름]
	for i in SEG + 1:
		var t := float(i) / SEG * 2.0 - 1.0
		var ang := t * BOW_ANGLE
		var c := Vector3(BOW_RADIUS * sin(ang), BOW_RADIUS * (1.0 - cos(ang)), 0.0)
		var tangent := Vector3(cos(ang), sin(ang), 0.0)
		var side := tangent.cross(Vector3.BACK).normalized()
		var r := lerpf(0.03, 0.013, absf(t))
		for j in RING:
			var phi := TAU * j / RING
			var n := side * cos(phi) + Vector3.BACK * sin(phi)
			st.set_normal(n)
			st.add_vertex(c + n * r)
		if i == 0:
			ends.append([c, -tangent, r])
		elif i == SEG:
			ends.append([c, tangent, r])
	for i in SEG:
		for j in RING:
			var a := i * RING + j
			var b := i * RING + (j + 1) % RING
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + RING)
			st.add_index(b)
			st.add_index(b + RING)
			st.add_index(a + RING)
	# 양 끝 마개 (끝에서 조금 튀어나온 꼭짓점 하나로 닫음)
	for e in 2:
		var c: Vector3 = ends[e][0]
		var out: Vector3 = ends[e][1]
		st.set_normal(out)
		st.add_vertex(c + out * ends[e][2])
		var tip := (SEG + 1) * RING + e
		var ring0 := 0 if e == 0 else SEG * RING
		for j in RING:
			var a := ring0 + j
			var b := ring0 + (j + 1) % RING
			st.add_index(tip)
			if e == 0:
				st.add_index(b)
				st.add_index(a)
			else:
				st.add_index(a)
				st.add_index(b)
	return st.commit()


## 화살 하나 (오늬가 원점, 촉이 -Z 쪽). look_name 색 묶음을 씁니다.
static func make_arrow(look_name: String) -> Node3D:
	var arrow := Node3D.new()
	var mat := _look_mat(look_name)
	var shaft := MeshInstance3D.new()
	shaft.mesh = _mesh("shaft")
	shaft.rotation.x = PI / 2.0
	shaft.position.z = -(ARROW_LENGTH - 0.07) * 0.5
	var head := MeshInstance3D.new()
	head.mesh = _mesh("arrow_head")
	head.rotation.x = -PI / 2.0
	head.position.z = -ARROW_LENGTH + 0.04
	for side: float in [-1.0, 1.0]:
		var feather := MeshInstance3D.new()
		feather.mesh = _mesh("feather")
		var d := Vector3(0.6 * side, 0.0, 0.8).normalized()   # 뒤쪽 바깥으로 벌어짐
		feather.basis = Basis(Quaternion(Vector3.UP, d))
		feather.position = Vector3(0, 0, -0.12) + d * 0.045
		arrow.add_child(feather)
	arrow.add_child(shaft)
	arrow.add_child(head)
	for m: MeshInstance3D in arrow.get_children():
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return arrow


func _ready() -> void:
	_hips = Node3D.new()
	add_child(_hips)
	_part(_hips, "torso", Vector3(0, 0.57, 0), Vector3(1, 1, 0.78))
	_part(_hips, "head", Vector3(0, 0.93, 0))
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.075 * side, 0.38, 0)
		_hips.add_child(leg)
		_part(leg, "leg", Vector3(0, -0.18, 0))
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.17 * side, 0.72, 0)
		_hips.add_child(arm)
		_part(arm, "arm", Vector3(0, -0.14, 0))
		_arms.append(arm)
	_apply_material(_look_mat(look))


func _part(parent: Node3D, kind: String, pos: Vector3, scl: Vector3 = Vector3.ONE) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _mesh(kind)
	m.position = pos
	m.scale = scl
	parent.add_child(m)
	_parts.append(m)


func _apply_material(mat: Material) -> void:
	for m in _parts:
		m.material_override = mat


## 활을 줍니다 (등에 멤). 활과 화살도 이 사람의 색 묶음을 씁니다.
func give_bow() -> void:
	if _bow != null:
		return
	if _string_mat == null:
		_string_mat = StandardMaterial3D.new()
		_string_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_string_mat.albedo_color = Color(0.05, 0.05, 0.05)
	_bow = Node3D.new()
	add_child(_bow)
	_part(_bow, "bow", Vector3.ZERO)
	for i in 2:
		var s := MeshInstance3D.new()
		s.mesh = _mesh("string")
		s.material_override = _string_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		_strings.append(s)
	_nocked = make_arrow(look)
	_nocked.visible = false
	add_child(_nocked)
	for m: MeshInstance3D in _nocked.get_children():
		_parts.append(m)
	_apply_material(_look_mat(look))


## 활을 쏩니다: 등에서 활을 꺼내 왼팔을 뻗고, draw_time 초 동안 시위를 당깁니다.
## 다 당긴 뒤 release() 를 부르면 화살이 떠나고, 잠시 뒤 활을 다시 등에 멥니다.
func shoot(draw_time: float) -> void:
	if _bow == null or _down_t >= 0.0:
		return
	_punch_t = -1.0
	_aim_t = 0.0
	_draw_time = draw_time
	_released = false


func is_aiming() -> bool:
	return _aim_t >= 0.0


## 시위를 놓습니다. 걸려 있던 화살의 (세상 기준) 자리와 방향을 돌려줍니다.
func release() -> Transform3D:
	var t := _nocked.global_transform
	_released = true
	_release_at = _aim_t
	_nocked.visible = false
	return t


## 다른 물건(예: 꽂힌 화살)을 몸에 붙입니다. 쓰러지면 같이 넘어갑니다 (색은 그 물건 것 그대로).
func attach(node: Node3D) -> void:
	node.reparent(_hips, true)


## 주먹을 냅니다 (양팔 번갈아). windup 초 동안 팔을 뒤로 당겼다가 내지릅니다.
## 주먹이 다 뻗는 순간은 windup + PUNCH_PEAK 초 뒤입니다.
func punch(windup: float = 0.0) -> void:
	if _down_t >= 0.0:
		return
	_aim_t = -1.0
	_windup = windup
	_punch_t = 0.0
	_punch_arm = 1 - _punch_arm


func is_punching() -> bool:
	return _punch_t >= 0.0


## 맞았을 때: 뒤로 휘청이고 잠깐 회색으로 번쩍입니다. 내던 주먹이나 당기던 활은 끊깁니다.
func hurt() -> void:
	if _down_t >= 0.0:
		return
	_punch_t = -1.0
	_cancel_aim()
	_hurt_t = 0.0
	_flash = 0.09
	_apply_material(_look_mat(FLASH_LOOK))


## 뒤로 벌러덩 쓰러집니다.
func knock_out() -> void:
	_punch_t = -1.0
	_cancel_aim()
	_hurt_t = -1.0
	_down_t = 0.0
	speed = 0.0
	_flash = 0.09
	_apply_material(_look_mat(FLASH_LOOK))


## 다시 일으켜 세웁니다 (처음부터 다시 할 때).
func revive() -> void:
	_down_t = -1.0
	_hurt_t = -1.0
	_punch_t = -1.0
	_cancel_aim()
	_apply_material(_look_mat(look))


func _cancel_aim() -> void:
	_aim_t = -1.0
	_released = false
	if _nocked != null:
		_nocked.visible = false


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_apply_material(_look_mat(look))

	# 걷기
	_walk = lerpf(_walk, clampf(speed / 1.1, 0.0, 1.4), 1.0 - exp(-8.0 * delta))
	# 다리 방향: 걷는 쪽이 옆보다 뒤면 뒷걸음질 (다리는 반대쪽을 향해 거꾸로 걸음). 옆 근처에서 깜빡이지 않게 여유를 둠
	var back := absf(walk_angle) > PI / 2.0 + (0.15 if _stride > 0.0 else -0.15)
	var yaw := wrapf(walk_angle + PI, -PI, PI) if back else walk_angle
	if back != (_stride < 0.0):
		_stride = -1.0 if back else 1.0
		_leg_yaw = yaw   # 앞↔뒤가 바뀌는 건 옆걸음일 때라 어느 쪽이든 같아 보여서 바로 바꿈
	else:
		_leg_yaw = lerp_angle(_leg_yaw, yaw, 1.0 - exp(-12.0 * delta))
	if speed > 0.02:
		_phase = wrapf(_phase + _stride * speed * delta / (STEP_LENGTH * 2.0) * TAU, 0.0, TAU)
	var swing := sin(_phase) * 0.55 * _walk
	var leg_x := [swing, -swing]
	var arm_x := [-swing * 0.85, swing * 0.85]
	var arm_z := [-0.14, 0.14]          # 팔을 몸에서 살짝 벌림 (왼팔 -, 오른팔 +)
	var arm_len := [1.0, 1.0]
	var lean := -0.07 * _walk           # 앞으로 살짝 숙임 (+ 는 뒤로 젖힘)
	var twist := 0.0
	var tilt := sin(_phase) * 0.035 * _walk
	var lift := absf(cos(_phase)) * 0.03 * _walk   # 두 발이 모일 때 가장 높음

	# 주먹: k = 1 이면 팔을 앞으로 쭉 뻗음, 음수면 뒤로 당기는 준비 자세
	if _punch_t >= 0.0:
		_punch_t += delta
		var k := 0.0
		if _punch_t < _windup:
			k = -0.5 * smoothstep(0.0, 1.0, _punch_t / _windup)
		else:
			var t := (_punch_t - _windup) / PUNCH_TIME
			var peak := PUNCH_PEAK / PUNCH_TIME
			var start := -0.5 if _windup > 0.0 else 0.0
			if t >= 1.0:
				_punch_t = -1.0
			elif t < peak:
				k = lerpf(start, 1.0, 1.0 - pow(1.0 - t / peak, 3.0))
			elif t < 0.5:
				k = 1.0
			else:
				k = 1.0 - smoothstep(0.5, 1.0, t)
		var a := _punch_arm
		var side := -1.0 if a == 0 else 1.0
		var reach := maxf(k, 0.0)
		arm_x[a] = lerpf(arm_x[a], 1.5, reach) + minf(k, 0.0) * 1.2
		arm_z[a] = lerpf(arm_z[a], -0.08 * side, reach)
		arm_len[a] = 1.0 + 0.3 * reach
		arm_x[1 - a] = lerpf(arm_x[1 - a], 0.6, absf(k))   # 다른 팔은 앞으로 들어 막는 자세
		twist = side * 0.4 * k
		lean -= 0.12 * k

	# 맞음: 뒤로 휘청, 팔이 벌어짐
	if _hurt_t >= 0.0:
		_hurt_t += delta
		var h := _hurt_t / 0.28
		if h >= 1.0:
			_hurt_t = -1.0
		else:
			var s := sin(PI * h)
			lean += 0.45 * s
			arm_z[0] -= 0.5 * s
			arm_z[1] += 0.5 * s

	# 활: aim = 활 자세로 들어간 정도, pull = 시위를 당긴 정도, follow = 놓은 뒤 손이 뒤로 빠지는 정도
	var aim := 0.0
	var pull := 0.0
	var follow := 0.0
	if _aim_t >= 0.0:
		_aim_t += delta
		if not _released:
			var p := _aim_t / _draw_time
			aim = smoothstep(0.0, 0.35, p)
			pull = smoothstep(0.3, 1.0, p)
		else:
			var r := (_aim_t - _release_at) / RECOVER
			if r >= 1.0:
				_aim_t = -1.0
			else:
				aim = 1.0 - smoothstep(0.4, 1.0, r)
				pull = 1.0
				follow = sin(minf(r / 0.3, 1.0) * PI * 0.5)
		twist = lerpf(twist, -0.5, aim)   # 왼어깨를 앞으로 내밀어 몸을 옆으로 세움
		lean = lerpf(lean, 0.0, aim)
		tilt *= 1.0 - aim

	# 쓰러짐: 발끝을 축으로 뒤로 넘어가 바닥에 눕고, 한 번 살짝 튕김
	if _down_t >= 0.0:
		_down_t += delta
		var f := minf(_down_t / 0.45, 1.0)
		var fall := f * f
		var bounce := sin(clampf((_down_t - 0.45) / 0.22, 0.0, 1.0) * PI) * 0.1
		lean = lerpf(lean, 1.5, fall) - bounce
		twist = 0.0
		tilt = 0.0
		lift = 0.12 * fall
		leg_x = [0.3 * fall, -0.1 * fall]
		arm_x = [lerpf(arm_x[0], 0.4, fall), lerpf(arm_x[1], -0.3, fall)]
		arm_z = [-0.14 - 1.1 * fall, 0.14 + 1.1 * fall]
		arm_len = [1.0, 1.0]

	_hips.position.y = lift
	_hips.rotation = Vector3(lean, twist, tilt)
	# 서 있을 때는 숨 쉬듯 아주 조금 늘었다 줄었다
	_breath += delta * 2.2
	var still := 0.0 if _down_t >= 0.0 else 1.0 - minf(_walk, 1.0)
	_hips.scale.y = 1.0 + sin(_breath) * 0.012 * still
	# 다리는 걷는 쪽으로 (몸통이 활 자세로 비튼 만큼은 되돌려서). 쓰러질 때는 몸을 따라감
	var leg_yaw := 0.0 if _down_t >= 0.0 else _leg_yaw - twist
	for i in 2:
		_legs[i].rotation = Vector3(leg_x[i], leg_yaw, 0.0)
		_arms[i].rotation = Vector3(arm_x[i], 0.0, arm_z[i])
		_arms[i].scale = Vector3(1.0, arm_len[i], 1.0)

	if _bow == null:
		return
	# 활 자세: 왼팔은 앞으로 쭉, 오른손은 시위를 잡고 뒤로. 위치는 몸(이 노드) 기준으로 계산
	var hips_tf := _hips.transform
	var to_hips := hips_tf.basis.orthonormalized().inverse()
	var fist := Vector3.ZERO
	var hand := Vector3.ZERO
	if aim > 0.0:
		var shoulder_l := hips_tf * _arms[0].position
		var shoulder_r := hips_tf * _arms[1].position
		fist = shoulder_l + Vector3(0, 0.03, -1).normalized() * ARM_LENGTH
		var rest := fist + Vector3.BACK * BOW_TIP.y
		var full := fist + Vector3.BACK * DRAW_BACK
		hand = rest.lerp(full, pull) + Vector3(0.1, 0.03, 0.07) * follow
		_aim_arm(0, fist - shoulder_l, to_hips, aim)
		_aim_arm(1, hand - shoulder_r, to_hips, aim)

	var back_tf := hips_tf * BOW_ON_BACK
	var hand_tf := Transform3D(Basis(Vector3.FORWARD, 0.45) * Basis(Vector3.RIGHT, PI / 2.0), fist)
	_bow.transform = back_tf.interpolate_with(hand_tf, aim) if aim > 0.0 else back_tf
	var tip_a := _bow.transform * BOW_TIP
	var tip_b := _bow.transform * Vector3(-BOW_TIP.x, BOW_TIP.y, 0.0)
	var nock := _bow.transform * Vector3(0.0, BOW_TIP.y, 0.0)
	if aim > 0.0 and not _released:
		nock = nock.lerp(hand, pull)
	_stretch(_strings[0], tip_a, nock)
	_stretch(_strings[1], nock, tip_b)
	_nocked.visible = aim > 0.6 and not _released
	if _nocked.visible:
		var dir := fist - nock
		if dir.length() < 0.05:
			dir = Vector3.FORWARD
		_nocked.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), nock)


## 팔 i 를 방향 dir(몸 기준)로 뻗게 합니다. 길이도 dir 길이에 맞춰 늘이고 줄입니다. weight 만큼만 섞음.
func _aim_arm(i: int, dir: Vector3, to_hips: Basis, weight: float) -> void:
	var arm := _arms[i]
	var want := Quaternion(Vector3.DOWN, (to_hips * dir).normalized())
	var now := Quaternion(Basis.from_euler(arm.rotation))
	var stretch := lerpf(arm.scale.y, dir.length() / ARM_LENGTH, weight)
	arm.basis = Basis(now.slerp(want, weight)) * Basis.from_scale(Vector3(1.0, stretch, 1.0))


## 원기둥 하나를 p 에서 q 까지 늘여 놓습니다 (시위).
func _stretch(node: MeshInstance3D, p: Vector3, q: Vector3) -> void:
	var d := q - p
	var l := d.length()
	if l < 0.001:
		node.visible = false
		return
	node.visible = true
	var y := d / l
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	node.transform = Transform3D(Basis(x, y * l, x.cross(y)), (p + q) * 0.5)
