## ship_blueprint.gd — Live 2D bird's-eye hull layout preview.
## Fully decoupled from GraphEdit node positions — uses only ShipNode.hull_pos.
## When edit_mode is ON, rooms can be dragged to reposition their hull_pos,
## and the preview expands to 2× size for easier editing.
## Shows adjacency/overlap guides between nearby rooms.
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

# ── Adjacency thresholds (hull-space pixels, before any scale) ───────────────
const ADJ_DIST     := 55.0   # rooms are "adjacent" — touching in 3D
const OVERLAP_DIST := 30.0   # rooms overlap / clip in 3D
const STACK_DIST   := 15.0   # rooms stacked on top of each other

const _CLR_ADJ     := Color(0.20, 0.75, 0.35, 0.40)   # green — adjacent
const _CLR_OVERLAP := Color(0.90, 0.75, 0.15, 0.55)   # yellow — overlapping
const _CLR_STACK   := Color(0.90, 0.25, 0.20, 0.65)   # red — stacked

# ── Drag state ───────────────────────────────────────────────────────────────
var _drag_node: ShipNode = null       # room currently being dragged
var _last_mouse: Vector2 = Vector2.ZERO
# Cached transform values (recomputed each frame in _draw, read by input)
var _sc: float = 1.0                  # preview-to-hull scale


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
		# Convert screen-space delta to hull-space offset
		var delta := mm.relative / _sc
		_drag_node.hull_pos += delta


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
	var ctr    : Vector2 = (bb.mn + bb.mx) * 0.5
	var orig   := Vector2(size.x * 0.5, _TTL + _PAD + draw_h * 0.5)

	# Walk rooms in reverse (top-drawn = highest priority)
	for i in range(nodes.size() - 1, -1, -1):
		var sn := nodes[i] as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		var rpos := orig + (sn.hull_pos - ctr) * sc

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
	var title := "HULL EDIT  ✦  drag rooms to reposition" if edit_mode else "HULL LAYOUT"
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

	# Bounding box (hull_pos only — fully decoupled from GraphEdit)
	var bb  := _bounding_box(nodes)
	var draw_w := w - _PAD * 2.0
	var draw_h := h - _PAD * 2.0 - _TTL
	var span   := Vector2(maxf(bb.mx.x - bb.mn.x, 160.0), maxf(bb.mx.y - bb.mn.y, 160.0))
	var sc     := minf(draw_w / span.x, draw_h / span.y) * 0.80
	var ctr    : Vector2 = (bb.mn + bb.mx) * 0.5
	var orig   := Vector2(w * 0.5, _TTL + _PAD + draw_h * 0.5)
	_sc = sc   # cache for input handler

	# ── Adjacency / overlap guides (drawn behind everything else) ────────────
	var adj_count := 0
	for i in nodes.size():
		var sn_a := nodes[i] as ShipNode
		if sn_a == null: continue
		for j in range(i + 1, nodes.size()):
			var sn_b := nodes[j] as ShipNode
			if sn_b == null: continue
			var dist := sn_a.hull_pos.distance_to(sn_b.hull_pos)
			if dist > ADJ_DIST:
				continue

			var pa := orig + (sn_a.hull_pos - ctr) * sc
			var pb := orig + (sn_b.hull_pos - ctr) * sc

			if dist <= STACK_DIST:
				# Red — stacked
				draw_line(pa, pb, _CLR_STACK, 2.5)
				var mid := (pa + pb) * 0.5
				draw_string(font, mid + Vector2(-3, -4), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, _CLR_STACK)
			elif dist <= OVERLAP_DIST:
				# Yellow — overlapping
				draw_line(pa, pb, _CLR_OVERLAP, 2.0)
			else:
				# Green — adjacent (touching)
				draw_line(pa, pb, _CLR_ADJ, 1.5)
				adj_count += 1

	# Connection lines (drawn behind rooms, on top of adjacency)
	for conn in graph_ref.get_connection_list():
		var fn := graph_ref.get_node_or_null(NodePath(str(conn.from_node))) as ShipNode
		var tn := graph_ref.get_node_or_null(NodePath(str(conn.to_node)))   as ShipNode
		if fn == null or tn == null: continue
		var p0 := orig + (fn.hull_pos - ctr) * sc
		var p1 := orig + (tn.hull_pos - ctr) * sc
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
		var rpos  := orig + (sn.hull_pos - ctr) * sc

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

	# Adjacency count label (bottom-right corner of blueprint)
	if adj_count > 0:
		var adj_text := "ADJ: %d" % adj_count
		var adj_col := _CLR_ADJ if not edit_mode else Color(0.30, 0.85, 0.45, 0.80)
		draw_string(font, Vector2(w - _PAD - 40.0, h - _PAD + 2.0),
			adj_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, adj_col)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _gather_nodes() -> Array:
	var nodes: Array = []
	for child in graph_ref.get_children():
		if child is ShipNode:
			nodes.append(child)
	return nodes


func _bounding_box(nodes: Array) -> Dictionary:
	## Returns {mn: Vector2, mx: Vector2} using hull_pos only.
	var mn := Vector2(INF,  INF)
	var mx := Vector2(-INF, -INF)
	for node in nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var p := sn.hull_pos
		mn.x = minf(mn.x, p.x)
		mn.y = minf(mn.y, p.y)
		mx.x = maxf(mx.x, p.x)
		mx.y = maxf(mx.y, p.y)
	return {"mn": mn, "mx": mx}


## Static adjacency check — also used by star_map.gd for gameplay bonuses.
static func compute_adjacencies(nodes: Array) -> Dictionary:
	## Returns {node_uid: [{uid: String, type: String}]} for rooms within ADJ_DIST.
	var result: Dictionary = {}
	for i in nodes.size():
		var sn_a := nodes[i] as ShipNode
		if sn_a == null: continue
		if not result.has(sn_a.node_uid):
			result[sn_a.node_uid] = []
		for j in range(i + 1, nodes.size()):
			var sn_b := nodes[j] as ShipNode
			if sn_b == null: continue
			if not result.has(sn_b.node_uid):
				result[sn_b.node_uid] = []
			if sn_a.hull_pos.distance_to(sn_b.hull_pos) <= ADJ_DIST:
				var def_a := RoomData.find(sn_a.def_id)
				var def_b := RoomData.find(sn_b.def_id)
				var type_a: String = def_a.get("type", "Utility") if not def_a.is_empty() else "Utility"
				var type_b: String = def_b.get("type", "Utility") if not def_b.is_empty() else "Utility"
				result[sn_a.node_uid].append({"uid": sn_b.node_uid, "type": type_b})
				result[sn_b.node_uid].append({"uid": sn_a.node_uid, "type": type_a})
	return result
