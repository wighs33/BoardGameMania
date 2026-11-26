class_name HeroSprites
extends Node
## 판 위 그림(영웅 · 성 · 벽 · 지뢰 …)을 하나씩 작은 화면에 그려 두고 그림으로 재사용
## 모습이 바뀐 것만 다시 그려요 (매 프레임 모두 새로 그리면 폰이 뜨거워져요)
## 투명한 화면에 그린 그림이라 색에 투명도가 이미 곱해져 있음 → 쓰는 층은 UIKit.premult_material()로 그려야 함

const BOX := 1.35         # 그림 한 장의 폭 (칸 단위, 칸 가운데 기준)
const OVER := 1.25        # 화면보다 크게 그려 줄여 쓰면 가장자리가 매끈함 (크면 그래픽 메모리를 많이 씀)
const MAX_SIDE := 448     # 그림 한 장의 한도 (픽셀)

var _cell: float = 0.0
var _px: float = 0.0      # 화면 배율
var _scale: float = 1.0   # 그려 두는 배율
var _slots: Dictionary = {}   # 번호 -> {vp, painter, key, paint, box(칸 단위 폭)}
var _fresh: Dictionary = {}   # 막 그린 그림 번호


func _process(_delta: float) -> void:
	for n in _fresh.keys():
		if not _slots.has(n) or UIKit.release_paint(_slots[n]["vp"], _slots[n]["painter"]):
			_fresh.erase(n)


## 칸 크기나 화면 배율이 바뀌면 모두 다시 그림
func prepare(cell: float, px_scale: float) -> void:
	if is_equal_approx(cell, _cell) and is_equal_approx(px_scale, _px):
		return
	_cell = cell
	_px = px_scale
	_scale = minf(maxf(0.1, px_scale) * OVER, MAX_SIDE / (cell * BOX))
	for n in _slots:
		var s: Dictionary = _slots[n]
		s["key"] = null
		_fit(s)


func _fit(s: Dictionary) -> void:
	var side := maxi(8, int(ceil(_cell * float(s["box"]) * _scale)))
	(s["vp"] as SubViewport).size = Vector2i(side, side)
	var p: Node2D = s["painter"]
	p.position = Vector2(side, side) / 2.0
	p.scale = Vector2(_scale, _scale)


## n번 그림의 모습(key)이 달라졌는지
func changed(n: int, key: Array) -> bool:
	return not _slots.has(n) or _slots[n]["key"] != key


## n번 그림을 다시 그림. paint(ci): 칸 가운데를 (0, 0)으로 보고 그리는 함수, tint: 그리는 것마다 곱할 색
func bake(n: int, key: Array, paint: Callable, tint: Color = Color.WHITE, box: float = BOX) -> void:
	if not _slots.has(n):
		var vp := SubViewport.new()
		vp.disable_3d = true
		vp.transparent_bg = true
		vp.gui_disable_input = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var node := Node2D.new()
		node.draw.connect(_on_paint.bind(n))
		vp.add_child(node)
		add_child(vp)
		_slots[n] = {"vp": vp, "painter": node, "key": null, "paint": paint, "box": box}
		_fit(_slots[n])
	var s: Dictionary = _slots[n]
	s["key"] = key
	s["paint"] = paint
	var p: Node2D = s["painter"]
	p.modulate = tint
	p.queue_redraw()
	(s["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_fresh[n] = true


func _on_paint(n: int) -> void:
	var s: Dictionary = _slots[n]
	(s["paint"] as Callable).call(s["painter"])


## color: 곱할 색 (투명도를 쓰면 색에도 곱해서 줄 것)
func draw(ci: CanvasItem, n: int, center: Vector2, zoom: float = 1.0, color: Color = Color.WHITE) -> void:
	if not _slots.has(n):
		return
	var vp: SubViewport = _slots[n]["vp"]
	var w := Vector2(vp.size) / _scale * zoom
	ci.draw_texture_rect(vp.get_texture(), Rect2(center - w / 2.0, w), false, color)


## from번부터 to번까지의 그림 버리기
func drop(from: int, to: int) -> void:
	for n in _slots.keys():
		if n >= from and n <= to:
			(_slots[n]["vp"] as Node).queue_free()
			_slots.erase(n)
