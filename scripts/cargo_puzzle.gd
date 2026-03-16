## cargo_puzzle.gd — Cargo loading mini-game modal (Diablo inventory style).
## Player picks from excess cargo and arranges pieces to maximize value.
## More cargo is offered than fits — optimization is the puzzle.
class_name CargoPuzzle
extends Control

signal puzzle_done(bonus_credits: int)

# ── Piece colours ─────────────────────────────────────────────────────────────
const PIECE_COLORS: Array = [
	Color(0.95, 0.35, 0.35, 1.0),
	Color(0.35, 0.80, 0.95, 1.0),
	Color(0.95, 0.80, 0.25, 1.0),
	Color(0.40, 0.90, 0.45, 1.0),
	Color(0.80, 0.45, 0.95, 1.0),
	Color(0.95, 0.60, 0.25, 1.0),
	Color(0.40, 0.55, 0.95, 1.0),
	Color(0.95, 0.45, 0.75, 1.0),
]

# ── Shape catalog (classic polyominoes + extras) ──────────────────────────────
# Each shape is an array of Vector2i offsets from (0,0).
const SHAPES: Dictionary = {
	# --- Size 1 ---
	"crate_1x1":    [Vector2i(0,0)],
	# --- Size 2 ---
	"barrel_1x2":   [Vector2i(0,0), Vector2i(1,0)],
	"barrel_2x1":   [Vector2i(0,0), Vector2i(0,1)],
	# --- Size 3 ---
	"beam_I3":      [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
	"corner_L3":    [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1)],
	"corner_J3":    [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1)],
	# --- Size 4 ---
	"beam_I4":      [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)],
	"block_O":      [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
	"shape_T":      [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1)],
	"shape_L":      [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,2)],
	"shape_J":      [Vector2i(1,0), Vector2i(1,1), Vector2i(1,2), Vector2i(0,2)],
	"shape_S":      [Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1)],
	"shape_Z":      [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(2,1)],
	# --- Size 5 (pentominoes — the tricky ones) ---
	"pent_plus":    [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(1,2)],
	"pent_U":       [Vector2i(0,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	"pent_T":       [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1), Vector2i(1,2)],
	"pent_W":       [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,2), Vector2i(2,2)],
	"pent_F":       [Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,2)],
	"pent_I":       [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)],
}

# ── Cargo flavor names (mapped by size tier) ─────────────────────────────────
const CARGO_NAMES_SMALL: Array = [
	"Data Core", "Med Kit", "Ration Pack", "Sensor Probe",
	"Comm Relay", "Power Cell", "Ammo Case", "Trade Goods",
]
const CARGO_NAMES_MEDIUM: Array = [
	"Munitions Crate", "Medical Supplies", "Engine Parts", "Shield Generator",
	"Water Purifier", "Spice Container", "Mining Drill", "Nav Computer",
	"Reactor Core", "Weapons Module",
]
const CARGO_NAMES_LARGE: Array = [
	"Colony Prefab", "Fusion Reactor", "Ore Shipment", "Vehicle Bay",
	"Habitat Module", "Terraforming Unit", "Bulk Grain Silo", "Antimatter Pod",
]

# ── State ─────────────────────────────────────────────────────────────────────
var _cols:           int = 3
var _rows:           int = 3
var _pieces:         Array = []   # [{id, cells, color, name, value, placed}]
var _selected_pid:   int   = -1
var _cur_rotation:   int   = 0
var _job_pay_per_day: int  = 0
var _job_total_pay:  int   = 0
var _job_type:       String = ""
var _max_bonus:      int   = 0

# ── UI refs ───────────────────────────────────────────────────────────────────
var _grid_ctrl:      CargoPuzzleGrid
var _queue_vbox:     VBoxContainer
var _lbl_status:     Label
var _lbl_value:      Label
var _btn_confirm:    Button
var _piece_btns:     Dictionary   # pid -> Button
var _queue_scroll:   ScrollContainer


# ── Setup (call before add_child) ────────────────────────────────────────────
func setup(cargo_count: int, pay_per_day: int, total_pay: int, job_type: String) -> void:
	_job_pay_per_day = pay_per_day
	_job_total_pay   = total_pay
	_job_type        = job_type
	_max_bonus       = int(total_pay * 0.25)

	# Grid dimensions: 3×3 base, grow alternating col/row per extra hold
	var grid_size := Vector2i(3, 3)
	for i in range(cargo_count - 1):
		if i % 2 == 0:
			grid_size.x += 1
		else:
			grid_size.y += 1
	_cols = grid_size.x
	_rows = grid_size.y

	_pieces = _generate_cargo(_cols, _rows, pay_per_day)


# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.96)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer_vb := VBoxContainer.new()
	outer_vb.add_theme_constant_override("separation", 10)
	center.add_child(outer_vb)

	_build_header(outer_vb)
	_build_content_row(outer_vb)
	_build_bottom_bar(outer_vb)

	_refresh_queue_panel()
	_update_status()


# ── UI builders ───────────────────────────────────────────────────────────────
func _build_header(parent: Control) -> void:
	var header := Label.new()
	header.text = "📦  CARGO LOADING  —  %s" % _job_type.to_upper()
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.92, 0.85, 0.50, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(header)

	var sub := Label.new()
	sub.text = "Too much cargo, not enough space! Pick the most valuable pieces.  R = Rotate  ·  Right-click = Remove"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.50, 0.62, 0.75, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sub)


func _build_content_row(parent: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	parent.add_child(hb)

	_build_queue_panel(hb)
	_build_grid_area(hb)
	_build_info_panel(hb)


func _build_queue_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color    = Color(0.08, 0.11, 0.18, 1.0)
	ps.border_color = Color(0.22, 0.32, 0.52, 1.0)
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top  = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left    = 4; ps.corner_radius_top_right    = 4
	ps.corner_radius_bottom_left = 4; ps.corner_radius_bottom_right = 4
	ps.content_margin_left = 8; ps.content_margin_right = 8
	ps.content_margin_top  = 8; ps.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var lbl := Label.new()
	lbl.text = "AVAILABLE CARGO"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl)

	var warn := Label.new()
	warn.text = "⚠ Won't all fit — choose wisely!"
	warn.add_theme_font_size_override("font_size", 10)
	warn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.30, 1.0))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(warn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.32, 0.52, 1.0))
	vb.add_child(sep)

	_queue_scroll = ScrollContainer.new()
	_queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_queue_scroll.custom_minimum_size = Vector2(0, 340)
	vb.add_child(_queue_scroll)

	_queue_vbox = VBoxContainer.new()
	_queue_vbox.add_theme_constant_override("separation", 4)
	_queue_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_scroll.add_child(_queue_vbox)


func _build_grid_area(parent: Control) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	var cell_sz: int = clampi(mini(480 / _cols, 480 / _rows), 42, 80)

	_grid_ctrl = CargoPuzzleGrid.new()
	_grid_ctrl.cols = _cols
	_grid_ctrl.rows = _rows
	_grid_ctrl.cell_size = cell_sz
	_grid_ctrl.init_grid()
	_grid_ctrl.placement_changed.connect(_on_placement_changed)
	center.add_child(_grid_ctrl)


func _build_info_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.08, 0.11, 0.18, 1.0)
	ps.border_color  = Color(0.22, 0.32, 0.52, 1.0)
	ps.border_width_left  = 1; ps.border_width_right  = 1
	ps.border_width_top   = 1; ps.border_width_bottom = 1
	ps.corner_radius_top_left    = 4; ps.corner_radius_top_right    = 4
	ps.corner_radius_bottom_left = 4; ps.corner_radius_bottom_right = 4
	ps.content_margin_left = 10; ps.content_margin_right = 10
	ps.content_margin_top  = 10; ps.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", ps)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var hdr := Label.new()
	hdr.text = "CARGO MANIFEST"
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85, 1.0))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hdr)

	vb.add_child(HSeparator.new())

	# Value loaded
	_lbl_value = Label.new()
	_lbl_value.add_theme_font_size_override("font_size", 13)
	_lbl_value.add_theme_color_override("font_color", Color(0.45, 0.90, 0.55, 1.0))
	_lbl_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_lbl_value)

	vb.add_child(HSeparator.new())

	# Fill status
	_lbl_status = Label.new()
	_lbl_status.add_theme_font_size_override("font_size", 11)
	_lbl_status.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55, 1.0))
	_lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_status)

	vb.add_child(HSeparator.new())

	var instructions := [
		"• Click a piece\n  from the list",
		"• Hover grid\n  to preview",
		"• Left-click\n  to place",
		"• [R] to rotate",
		"• Right-click\n  to remove",
		"• Maximize value\n  for best bonus!",
	]
	for line in instructions:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", Color(0.50, 0.58, 0.70, 1.0))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		vb.add_child(l)


func _build_bottom_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)

	var btn_rot := Button.new()
	btn_rot.text = "↻ Rotate (R)"
	btn_rot.custom_minimum_size = Vector2(110, 30)
	btn_rot.add_theme_font_size_override("font_size", 11)
	btn_rot.pressed.connect(_rotate_selected)
	bar.add_child(btn_rot)

	var btn_clear := Button.new()
	btn_clear.text = "✕ Remove Selected"
	btn_clear.custom_minimum_size = Vector2(130, 30)
	btn_clear.add_theme_font_size_override("font_size", 11)
	btn_clear.pressed.connect(_clear_selected)
	bar.add_child(btn_clear)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var lbl_max := Label.new()
	lbl_max.text = "Max bonus: +%d cr" % _max_bonus
	lbl_max.add_theme_font_size_override("font_size", 11)
	lbl_max.add_theme_color_override("font_color", Color(0.55, 0.65, 0.85, 1.0))
	lbl_max.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(lbl_max)

	# Skip
	var btn_skip := Button.new()
	btn_skip.text = "Skip"
	btn_skip.custom_minimum_size = Vector2(70, 30)
	btn_skip.add_theme_font_size_override("font_size", 11)
	btn_skip.add_theme_color_override("font_color", Color(0.75, 0.45, 0.45, 1.0))
	btn_skip.pressed.connect(func() -> void: puzzle_done.emit(0))
	bar.add_child(btn_skip)

	# Confirm
	_btn_confirm = Button.new()
	_btn_confirm.text = "✔ Launch"
	_btn_confirm.custom_minimum_size = Vector2(100, 30)
	_btn_confirm.add_theme_font_size_override("font_size", 11)
	_btn_confirm.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55, 1.0))
	_btn_confirm.pressed.connect(_on_confirm)
	bar.add_child(_btn_confirm)


# ── Queue panel ───────────────────────────────────────────────────────────────
func _refresh_queue_panel() -> void:
	for child in _queue_vbox.get_children():
		child.queue_free()
	_piece_btns.clear()

	var placed := _grid_ctrl.placed_piece_ids() if _grid_ctrl else []

	for p in _pieces:
		var pid: int = (p as Dictionary).get("id", -1)
		var is_placed: bool = placed.has(pid)
		var pname: String = (p as Dictionary).get("name", "Cargo")
		var pvalue: int   = (p as Dictionary).get("value", 0)
		var pcells: Array = (p as Dictionary).get("cells", [])

		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(180, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var base_col: Color = p.color
		var is_sel: bool = pid == _selected_pid
		btn.add_theme_stylebox_override("normal",   _make_piece_btn_style(
			base_col.darkened(0.7),
			base_col if is_sel else base_col.darkened(0.4),
			is_sel))
		btn.add_theme_stylebox_override("hover",    _make_piece_btn_style(base_col.darkened(0.6), base_col, false))
		btn.add_theme_stylebox_override("pressed",  _make_piece_btn_style(base_col.darkened(0.5), base_col, true))

		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 6)
		btn.add_child(hb)

		var icon := _make_piece_icon(p)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(icon)

		var info_vb := VBoxContainer.new()
		info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vb.add_theme_constant_override("separation", 0)
		info_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(info_vb)

		var lbl_name := Label.new()
		lbl_name.text = pname
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color",
			Color(0.45, 0.90, 0.45, 1.0) if is_placed else Color(0.85, 0.88, 0.95, 1.0))
		info_vb.add_child(lbl_name)

		var lbl_detail := Label.new()
		lbl_detail.text = "%d cells · %d cr%s" % [pcells.size(), pvalue,
			"  ✔" if is_placed else ""]
		lbl_detail.add_theme_font_size_override("font_size", 9)
		lbl_detail.add_theme_color_override("font_color",
			Color(0.45, 0.80, 0.45, 0.8) if is_placed else Color(0.60, 0.65, 0.78, 1.0))
		info_vb.add_child(lbl_detail)

		btn.pressed.connect(func() -> void: _select_piece(pid))
		_piece_btns[pid] = btn
		_queue_vbox.add_child(btn)


static func _make_piece_btn_style(bg: Color, border: Color, selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	s.border_width_left   = 2 if selected else 1
	s.border_width_right  = 2 if selected else 1
	s.border_width_top    = 2 if selected else 1
	s.border_width_bottom = 2 if selected else 1
	s.corner_radius_top_left    = 3
	s.corner_radius_top_right   = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left   = 6
	s.content_margin_right  = 6
	s.content_margin_top    = 3
	s.content_margin_bottom = 3
	return s


func _make_piece_icon(piece: Dictionary) -> Control:
	var cells: Array = piece.cells
	var max_x: int = 0
	var max_y: int = 0
	for c in cells:
		max_x = maxi(max_x, (c as Vector2i).x)
		max_y = maxi(max_y, (c as Vector2i).y)

	var mini_sz: int = 9
	var occupied := {}
	for c in cells:
		occupied[c] = true

	var grid_c := GridContainer.new()
	grid_c.columns = max_x + 1
	grid_c.add_theme_constant_override("h_separation", 1)
	grid_c.add_theme_constant_override("v_separation", 1)
	grid_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_c.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	for r in range(max_y + 1):
		for c in range(max_x + 1):
			var box := ColorRect.new()
			box.custom_minimum_size = Vector2(mini_sz, mini_sz)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.color = piece.color if occupied.get(Vector2i(c, r), false) else Color(0, 0, 0, 0)
			grid_c.add_child(box)

	return grid_c


# ── Interaction ───────────────────────────────────────────────────────────────
func _select_piece(pid: int) -> void:
	if _selected_pid == pid:
		_selected_pid = -1
		_cur_rotation = 0
		_sync_grid_selection()
		_refresh_queue_panel()
		return

	# If piece is already placed on grid, remove it first so player can reposition
	if _grid_ctrl.placed_piece_ids().has(pid):
		_grid_ctrl.remove_piece_by_id(pid)

	_selected_pid  = pid
	_cur_rotation  = 0
	_sync_grid_selection()
	_refresh_queue_panel()


func _rotate_selected() -> void:
	if _selected_pid < 0:
		return
	_cur_rotation = (_cur_rotation + 1) % 4
	_sync_grid_selection()


func _clear_selected() -> void:
	if _selected_pid < 0:
		return
	_grid_ctrl.remove_piece_by_id(_selected_pid)
	_selected_pid = -1
	_cur_rotation = 0
	_sync_grid_selection()
	_refresh_queue_panel()
	_update_status()


func _on_placement_changed() -> void:
	if _selected_pid >= 0 and _grid_ctrl.placed_piece_ids().has(_selected_pid):
		_selected_pid = -1
		_cur_rotation = 0
		_sync_grid_selection()
	_refresh_queue_panel()
	_update_status()


func _on_confirm() -> void:
	var loaded_value := _calc_loaded_value()
	var fill_pct := _calc_fill_pct()

	# Bonus scales: 90%+ fill = full value ratio, 75-89% = 3/4, 50-74% = half, <50% = quarter
	var ratio: float
	if fill_pct >= 0.90:
		ratio = 1.0
	elif fill_pct >= 0.75:
		ratio = 0.75
	elif fill_pct >= 0.50:
		ratio = 0.50
	else:
		ratio = 0.25

	# Bonus = (loaded_value / total_available_value) * max_bonus * fill_ratio
	var total_val: int = _total_available_value()
	var value_ratio: float = float(loaded_value) / float(maxi(total_val, 1))
	var bonus: int = int(value_ratio * ratio * _max_bonus)
	bonus = clampi(bonus, 0, _max_bonus)

	puzzle_done.emit(bonus)


func _sync_grid_selection() -> void:
	if _selected_pid < 0 or _grid_ctrl == null:
		_grid_ctrl.selected_pid  = -1
		_grid_ctrl.hover_cells   = []
		_grid_ctrl.queue_redraw()
		return

	var piece: Dictionary = _find_piece(_selected_pid)
	if piece.is_empty():
		return

	var cells: Array = piece.cells.duplicate()
	for _i in _cur_rotation:
		cells = _rotate_cells_cw(cells)

	_grid_ctrl.selected_pid = _selected_pid
	_grid_ctrl.hover_cells  = cells
	_grid_ctrl.queue_redraw()


func _update_status() -> void:
	if _grid_ctrl == null or _lbl_status == null or _btn_confirm == null:
		return
	var total: int = _cols * _rows
	var filled: int = _count_filled()
	var fill_pct: float = float(filled) / float(maxi(total, 1))
	var loaded_val: int = _calc_loaded_value()

	# Fill bar text
	var pct_int: int = int(fill_pct * 100.0)
	_lbl_status.text = "Hold: %d/%d (%d%%)" % [filled, total, pct_int]
	if fill_pct >= 0.90:
		_lbl_status.add_theme_color_override("font_color", Color(0.40, 0.95, 0.50, 1.0))
	elif fill_pct >= 0.75:
		_lbl_status.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55, 1.0))
	else:
		_lbl_status.add_theme_color_override("font_color", Color(0.90, 0.55, 0.45, 1.0))

	# Value loaded
	_lbl_value.text = "Loaded: %d cr\nof %d cr available" % [loaded_val, _total_available_value()]

	# Always allow confirm (even partial loads pay something)
	var has_any: bool = not _grid_ctrl.placed_piece_ids().is_empty()
	_btn_confirm.disabled = not has_any


func _calc_loaded_value() -> int:
	var placed_ids := _grid_ctrl.placed_piece_ids()
	var val: int = 0
	for p in _pieces:
		if placed_ids.has((p as Dictionary).get("id", -1)):
			val += (p as Dictionary).get("value", 0)
	return val


func _total_available_value() -> int:
	var val: int = 0
	for p in _pieces:
		val += (p as Dictionary).get("value", 0)
	return val


func _count_filled() -> int:
	var n: int = 0
	for r in _grid_ctrl.rows:
		for c in _grid_ctrl.cols:
			if _grid_ctrl.grid[r][c] != -1:
				n += 1
	return n


func _calc_fill_pct() -> float:
	return float(_count_filled()) / float(maxi(_cols * _rows, 1))


# ── Input (R to rotate) ──────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_rotate_selected()
			get_viewport().set_input_as_handled()


# ── Cargo generation ──────────────────────────────────────────────────────────
func _generate_cargo(cols: int, rows: int, pay_per_day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var grid_area: int = cols * rows
	# Generate 140-180% of grid area in total piece cells
	var pay_tier: int = clampi(pay_per_day / 40, 0, 4)
	var overflow_pct: float = [1.4, 1.5, 1.6, 1.7, 1.8][pay_tier]
	var target_cells: int = int(grid_area * overflow_pct)

	# Shape pools weighted by pay tier (higher pay = more large awkward shapes)
	var small_shapes: Array  = ["crate_1x1", "barrel_1x2", "barrel_2x1"]
	var medium_shapes: Array = ["beam_I3", "corner_L3", "corner_J3", "block_O",
		"shape_T", "shape_L", "shape_J", "shape_S", "shape_Z"]
	var large_shapes: Array  = ["beam_I4", "pent_plus", "pent_U", "pent_T",
		"pent_W", "pent_F", "pent_I"]

	# Weights: [small, medium, large] — higher tier pushes toward larger pieces
	var weights: Array = [
		[50, 40, 10],   # tier 0 — cheap jobs, mostly small/medium
		[35, 45, 20],   # tier 1
		[25, 40, 35],   # tier 2
		[15, 35, 50],   # tier 3
		[10, 30, 60],   # tier 4 — expensive jobs, lots of big awkward cargo
	]
	var w: Array = weights[pay_tier]

	var pieces: Array = []
	var pid: int = 0
	var total_cells: int = 0

	while total_cells < target_cells:
		# Pick size category
		var roll: int = rng.randi_range(1, 100)
		var shape_key: String
		if roll <= w[0]:
			shape_key = small_shapes[rng.randi() % small_shapes.size()]
		elif roll <= w[0] + w[1]:
			shape_key = medium_shapes[rng.randi() % medium_shapes.size()]
		else:
			shape_key = large_shapes[rng.randi() % large_shapes.size()]

		var cells: Array = SHAPES[shape_key].duplicate()
		var cell_count: int = cells.size()

		# Value: base per cell + bonus for size + randomness
		var base_per_cell: int = clampi(pay_per_day / 8, 5, 40)
		var size_bonus: float = 1.0 + (cell_count - 1) * 0.15  # bigger pieces worth more per cell
		var value: int = int(cell_count * base_per_cell * size_bonus * rng.randf_range(0.8, 1.3))

		# Flavor name
		var cargo_name: String
		if cell_count <= 2:
			cargo_name = CARGO_NAMES_SMALL[rng.randi() % CARGO_NAMES_SMALL.size()]
		elif cell_count <= 4:
			cargo_name = CARGO_NAMES_MEDIUM[rng.randi() % CARGO_NAMES_MEDIUM.size()]
		else:
			cargo_name = CARGO_NAMES_LARGE[rng.randi() % CARGO_NAMES_LARGE.size()]

		pieces.append({
			"id":    pid,
			"cells": cells,
			"color": PIECE_COLORS[pid % PIECE_COLORS.size()],
			"name":  cargo_name,
			"value": value,
		})
		pid += 1
		total_cells += cell_count

	# Sort by value descending so the best pieces are at the top
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.value > b.value)

	return pieces


static func _normalize_cells(cells: Array) -> Array:
	var min_x: int = 9999
	var min_y: int = 9999
	for c in cells:
		min_x = mini(min_x, (c as Vector2i).x)
		min_y = mini(min_y, (c as Vector2i).y)
	var result: Array = []
	for c in cells:
		result.append(Vector2i((c as Vector2i).x - min_x, (c as Vector2i).y - min_y))
	return result


static func _rotate_cells_cw(cells: Array) -> Array:
	var rotated: Array = []
	for c in cells:
		rotated.append(Vector2i((c as Vector2i).y, -(c as Vector2i).x))
	return _normalize_cells(rotated)


func _find_piece(pid: int) -> Dictionary:
	for p in _pieces:
		if (p as Dictionary).get("id") == pid:
			return p
	return {}
