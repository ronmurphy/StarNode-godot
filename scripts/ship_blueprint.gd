## ship_blueprint.gd — Live 2D bird's-eye hull layout preview.
## Reads ShipNode positions from the GraphEdit and draws flat coloured room
## shapes each frame so dragging nodes updates the silhouette in real-time.
## When edit_mode is ON, rooms can be dragged to adjust their hull_offset.
class_name ShipBlueprint
extends Control

var graph_ref: GraphEdit = null
var edit_mode: bool = false

const _BG      := Color(0.025, 0.040, 0.072, 0.88)
const _BORD    := Color(0.18,  0.26,  0.42,  0.90)
const _BORD_ED := Color(0.35,  0.65,  1.00,  0.90)   # edit-mode border highlight
const _DIM     := Color(0.42,  0.52,  0.72,  0.70)
const _PAD     := 12.0
const _TTL     := 15.0   # pixels reserved for title row

# ── Drag state ───────────────────────────────────────────────────────────────
var _drag_node: ShipNode = null       # room currently being dragged
var _last_mouse: Vector2 = Vector2.ZERO
# Cached transform values (recomputed each frame in _draw, read by input)
var _sc: float = 1.0                  # preview-to-graph scale


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not edit_mode or graph_ref == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_try_pick(mb.position)
			else:
				_drag_node = null

	elif event is InputEventMouseMotion and _drag_node != null:
		var mm := event as InputEventMouseMotion
		# Convert screen-space delta to GraphEdit-space offset
		var delta := mm.relative / _sc
		_drag_node.hull_offset += delta


func _try_pick(pos: Vector2) -> void:
	## Find the room shape under the mouse click (in screen coords).
	_drag_node = null
	var nodes := _gather_nodes()
	if nodes.is_empty():
		return

	var bb := _bounding_box(nodes)
	var draw_w := size.x - _PAD * 2.0
	var draw_h := size.y - _PAD * 2.0 - _TTL
	var span   := Vector2(maxf(bb.mx.x - bb.mn.x, 160.0), maxf(bb.mx.y - bb.mn.y, 160.0))
	var sc     := minf(draw_w / span.x, draw_h / span.y) * 0.80
	var ctr    := (bb.mn + bb.mx) * 0.5
	var orig   := Vector2(size.x * 0.5, _TTL + _PAD + draw_h * 0.5)

	# Walk rooms in reverse (top-drawn = highest priority)
	for i in range(nodes.size() - 1, -1, -1):
		var sn := nodes[i] as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		var rpos := orig + (sn.position_offset + sn.hull_offset - ctr) * sc

		var rw: float; var rh: float
		match def.get("type", "Utility"):
			"Power":    rw = 28.0; rh = 28.0
			"Engines":  rw = 20.0; rh = 32.0
			"Command":  rw = 32.0; rh = 24.0
			"Tactical": rw = 24.0; rh = 24.0
			_:          rw = 22.0; rh = 22.0

		if Rect2(rpos - Vector2(rw, rh) * 0.5, Vector2(rw, rh)).has_point(pos):
			_drag_node = sn
			return


func _draw() -> void:
	if graph_ref == null:
		return

	var w    := size.x
	var h    := size.y
	var font := ThemeDB.fallback_font
	var fsz  := 9

	# Panel background + border (highlighted in edit mode)
	draw_rect(Rect2(Vector2.ZERO, size), _BG)
	draw_rect(Rect2(Vector2.ZERO, size), _BORD_ED if edit_mode else _BORD, false,
		2.0 if edit_mode else 1.0)

	# Title
	var title := "HULL EDIT" if edit_mode else "HULL LAYOUT"
	draw_string(font, Vector2(_PAD, _TTL - 1.0),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
		_BORD_ED if edit_mode else _DIM)

	# Gather ShipNodes
	var nodes := _gather_nodes()
	if nodes.is_empty():
		draw_string(font, Vector2(w * 0.5, h * 0.5 + 5.0),
			"— no rooms —",
			HORIZONTAL_ALIGNMENT_CENTER, -1, fsz, _DIM.darkened(0.35))
		return

	# Bounding box (includes hull offsets)
	var bb  := _bounding_box(nodes)
	var draw_w := w - _PAD * 2.0
	var draw_h := h - _PAD * 2.0 - _TTL
	var span   := Vector2(maxf(bb.mx.x - bb.mn.x, 160.0), maxf(bb.mx.y - bb.mn.y, 160.0))
	var sc     := minf(draw_w / span.x, draw_h / span.y) * 0.80
	var ctr    := (bb.mn + bb.mx) * 0.5
	var orig   := Vector2(w * 0.5, _TTL + _PAD + draw_h * 0.5)
	_sc = sc   # cache for input handler

	# Connection lines (drawn first, behind rooms)
	for conn in graph_ref.get_connection_list():
		var fn := graph_ref.get_node_or_null(NodePath(str(conn.from_node))) as ShipNode
		var tn := graph_ref.get_node_or_null(NodePath(str(conn.to_node)))   as ShipNode
		if fn == null or tn == null: continue
		var p0 := orig + (fn.position_offset + fn.hull_offset - ctr) * sc
		var p1 := orig + (tn.position_offset + tn.hull_offset - ctr) * sc
		draw_line(p0, p1, Color(0.30, 0.45, 0.75, 0.30), 0.8)

	# Room shapes
	for node in nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		var rtype:    String = def.get("type",     "Utility")
		var universe: String = def.get("universe", "Universal")
		var col   := RoomData.type_color(rtype)
		var rpos  := orig + (sn.position_offset + sn.hull_offset - ctr) * sc

		# Room scale — aspect ratios match 3D box_sz proportions
		var rw: float; var rh: float
		match rtype:
			"Power":    rw = 28.0; rh = 28.0
			"Engines":  rw = 20.0; rh = 32.0
			"Command":  rw = 32.0; rh = 24.0
			"Tactical": rw = 24.0; rh = 24.0
			_:          rw = 22.0; rh = 22.0

		ShapeDrawer.draw_room(self, rtype, universe, col, rpos, minf(rw, rh) / 56.0)

		# Highlight the room being dragged
		if edit_mode and sn == _drag_node:
			draw_rect(Rect2(rpos - Vector2(rw, rh) * 0.5, Vector2(rw, rh)),
				Color(1.0, 1.0, 1.0, 0.35), false, 1.5)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _gather_nodes() -> Array:
	var nodes: Array = []
	for child in graph_ref.get_children():
		if child is ShipNode:
			nodes.append(child)
	return nodes


func _bounding_box(nodes: Array) -> Dictionary:
	## Returns {mn: Vector2, mx: Vector2} including hull offsets.
	var mn := Vector2(INF,  INF)
	var mx := Vector2(-INF, -INF)
	for node in nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var p := sn.position_offset + sn.hull_offset
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return {"mn": mn, "mx": mx}
