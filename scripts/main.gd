## main.gd — StarNode main scene.
## Builds all UI in code. GraphEdit handles pan/zoom/connections natively.
extends Control

# ── UI references ────────────────────────────────────────────────────────────
var graph_edit: GraphEdit
var txt_ship_name: LineEdit
var lbl_credits: Label
var lbl_power: Label
var lbl_location: Label
var lst_rooms: ItemList
var lbl_room_detail: RichTextLabel
var cb_universe: OptionButton
var cb_type: OptionButton
var txt_search: LineEdit
var spin_days: SpinBox
var btn_delete_mode: Button
var btn_hull_edit: Button
var _blueprint_ctrl: ShipBlueprint
var _room_shape_preview: RoomShapePreview

# ── Game state ───────────────────────────────────────────────────────────────
var ship_name: String = "My Ship"
var credits: int = 2000
var _node_counter: int = 0
var _delete_mode: bool = false
var _hull_edit_mode: bool = false
var _filtered_rooms: Array = []
var _current_system: String = "sol"   # tracked across jobs
var _room_textures:  Dictionary = {}   # node_uid → res:// texture path
var _last_save_path: String    = ""   # most recent save/load path for auto-save

const SAVE_VERSION: int = 1

# All available hull textures for random assignment at room purchase
const ROOM_TEXTURES: Array[String] = [
	"res://assets/pictures/textures/tex_heat_ceramic.png",
	"res://assets/pictures/textures/tex_energy_conduit_mesh.png",
	"res://assets/pictures/textures/tex_krysthari_hull.png",
	"res://assets/pictures/textures/tex_aged_iron.png",
	"res://assets/pictures/textures/tex_carbon_composite.png",
	"res://assets/pictures/textures/tex_titanium.png",
	"res://assets/pictures/textures/tex_luminar_hull.png",
	"res://assets/pictures/textures/tex_polymer_coating.png",
	"res://assets/pictures/textures/tex_reinforced_glass.png",
	"res://assets/pictures/textures/tex_riveted_steel.png",
	"res://assets/pictures/textures/tex_vothaal_hull.png",
	"res://assets/pictures/textures/tex_varak_hull.png",
]

# ── Dark theme colors ────────────────────────────────────────────────────────
const CLR_BG        := Color(0.039, 0.059, 0.098, 1.0)
const CLR_PANEL     := Color(0.078, 0.110, 0.176, 1.0)
const CLR_HEADER    := Color(0.059, 0.086, 0.137, 1.0)
const CLR_TEXT      := Color(0.780, 0.847, 1.000, 1.0)
const CLR_DIM       := Color(0.470, 0.510, 0.620, 1.0)
const CLR_ACCENT    := Color(0.310, 0.537, 0.843, 1.0)
const CLR_GOLD      := Color(1.000, 0.820, 0.310, 1.0)
const CLR_PWR_POS   := Color(0.310, 0.863, 0.545, 1.0)
const CLR_PWR_NEG   := Color(0.863, 0.392, 0.310, 1.0)


# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_ui()
	_refresh_room_list()
	_update_header()


# ── Build UI ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Root background
	var bg := ColorRect.new()
	bg.color = CLR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	_build_header(root_vbox)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root_vbox.add_child(body)

	_build_graph(body)
	_build_sidebar(body)
	_build_blueprint_preview()


func _build_header(parent: Control) -> void:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 52
	_style_panel(header, CLR_HEADER)
	parent.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.add_child(hbox)

	# Spacer left
	_add_spacer(hbox, 4)

	# Ship name
	var lbl_n := _make_label("Ship:", 10)
	hbox.add_child(lbl_n)

	txt_ship_name = LineEdit.new()
	txt_ship_name.text = ship_name
	txt_ship_name.custom_minimum_size.x = 160
	txt_ship_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_input(txt_ship_name)
	txt_ship_name.text_changed.connect(func(t): ship_name = t)
	hbox.add_child(txt_ship_name)

	hbox.add_child(_make_btn("New",  60, _on_new_ship))
	hbox.add_child(_make_btn("Save", 60, _on_save))
	hbox.add_child(_make_btn("Load", 60, _on_load))

	_add_vsep(hbox)

	lbl_credits = _make_label("Credits: 2,000", 13, CLR_GOLD)
	lbl_credits.custom_minimum_size.x = 130
	hbox.add_child(lbl_credits)

	lbl_power = _make_label("Power: 0", 13, CLR_PWR_POS)
	lbl_power.custom_minimum_size.x = 110
	hbox.add_child(lbl_power)

	lbl_location = _make_label("📍 Sol", 11, CLR_DIM)
	lbl_location.custom_minimum_size.x = 115
	hbox.add_child(lbl_location)

	_add_vsep(hbox)

	hbox.add_child(_make_label("Job days:", 10))
	spin_days = SpinBox.new()
	spin_days.min_value = 1
	spin_days.max_value = 30
	spin_days.value = 7
	spin_days.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spin_days.custom_minimum_size.x = 70
	hbox.add_child(spin_days)

	var btn_job := _make_btn("▶ Run Job", 90, _on_run_job)
	btn_job.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	hbox.add_child(btn_job)

	_add_spacer(hbox, 4)


func _build_graph(parent: Control) -> void:
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.minimap_enabled = false
	graph_edit.grid_pattern = GraphEdit.GRID_PATTERN_DOTS

	# Dark background for graph
	var ge_bg := StyleBoxFlat.new()
	ge_bg.bg_color = Color(0.051, 0.075, 0.122, 1.0)
	graph_edit.add_theme_stylebox_override("panel", ge_bg)

	parent.add_child(graph_edit)

	# Connect GraphEdit signals
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)


func _build_sidebar(parent: Control) -> void:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size.x = 272
	_style_panel(sidebar, CLR_PANEL)
	parent.add_child(sidebar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	sidebar.add_child(vbox)

	# Section label
	vbox.add_child(_make_label("ROOMS", 10, CLR_ACCENT))

	# Search
	txt_search = LineEdit.new()
	txt_search.placeholder_text = "Search rooms..."
	_style_input(txt_search)
	txt_search.text_changed.connect(func(_t): _refresh_room_list())
	vbox.add_child(txt_search)

	# Universe filter
	cb_universe = OptionButton.new()
	for u in RoomData.UNIVERSES:
		cb_universe.add_item(u)
	cb_universe.selected = 0
	cb_universe.item_selected.connect(func(_i): _refresh_room_list())
	vbox.add_child(cb_universe)

	# Type filter
	cb_type = OptionButton.new()
	for t in RoomData.TYPES:
		cb_type.add_item(t)
	cb_type.selected = 0
	cb_type.item_selected.connect(func(_i): _refresh_room_list())
	vbox.add_child(cb_type)

	# Room list
	lst_rooms = ItemList.new()
	lst_rooms.custom_minimum_size = Vector2(0, 240)
	lst_rooms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst_rooms.item_selected.connect(_on_room_selected)
	lst_rooms.item_activated.connect(_on_room_activated)
	vbox.add_child(lst_rooms)

	# Add button
	var btn_add := _make_btn("+ Add Room to Ship", -1, _on_add_room)
	btn_add.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	vbox.add_child(btn_add)

	# Detail box — HBox: [shape preview | room text]
	vbox.add_child(_make_label("Room Details", 10, CLR_ACCENT))

	var detail_hbox := HBoxContainer.new()
	detail_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(detail_hbox)

	# Shape preview (left side — fandom-aware silhouette)
	_room_shape_preview = RoomShapePreview.new()
	_room_shape_preview.custom_minimum_size = Vector2(76, 110)
	var shape_style := StyleBoxFlat.new()
	shape_style.bg_color = Color(0.055, 0.078, 0.125, 1.0)
	shape_style.border_color = Color(0.15, 0.20, 0.32, 1.0)
	shape_style.set_border_width_all(1)
	_room_shape_preview.add_theme_stylebox_override("panel", shape_style)
	detail_hbox.add_child(_room_shape_preview)

	# Room detail text (right side)
	lbl_room_detail = RichTextLabel.new()
	lbl_room_detail.custom_minimum_size = Vector2(0, 110)
	lbl_room_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_room_detail.bbcode_enabled = true
	lbl_room_detail.fit_content = false
	lbl_room_detail.scroll_active = false
	lbl_room_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl_room_detail.text = "[color=#7090b0]Select a room from the list above.[/color]"
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.055, 0.078, 0.125, 1.0)
	detail_style.border_color = Color(0.15, 0.20, 0.32, 1.0)
	detail_style.set_border_width_all(1)
	detail_style.set_content_margin_all(6)
	lbl_room_detail.add_theme_stylebox_override("normal", detail_style)
	detail_hbox.add_child(lbl_room_detail)

	# Mode buttons
	btn_delete_mode = _make_btn("Delete Mode: OFF", -1, _on_toggle_delete_mode)
	btn_delete_mode.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	vbox.add_child(btn_delete_mode)

	btn_hull_edit = _make_btn("Hull Edit: OFF", -1, _on_toggle_hull_edit)
	btn_hull_edit.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	vbox.add_child(btn_hull_edit)

	var btn_clear := _make_btn("Clear All Nodes", -1, _on_clear_all)
	btn_clear.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	vbox.add_child(btn_clear)

	# Repair button
	var btn_repair := _make_btn("Repair All (50 cr/node)", -1, _on_repair_all)
	btn_repair.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7, 1.0))
	vbox.add_child(btn_repair)

	# Help text
	var help := _make_label(
		"Drag ports to connect  •  Delete key removes selected\nRight-click + drag to pan  •  Scroll to zoom", 9, CLR_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(help)


func _build_blueprint_preview() -> void:
	_blueprint_ctrl = ShipBlueprint.new()
	_blueprint_ctrl.graph_ref     = graph_edit
	_blueprint_ctrl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_blueprint_ctrl.z_index       = 10
	# Anchor bottom-left of the window — sits inside the graph area
	# (sidebar is on the right, header is only 52px tall)
	_blueprint_ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_blueprint_ctrl.offset_left   =  10.0
	_blueprint_ctrl.offset_right  = 192.0   # 10 + 182 wide
	_blueprint_ctrl.offset_top    = -152.0  # 142 tall + 10 margin from bottom
	_blueprint_ctrl.offset_bottom =  -10.0
	add_child(_blueprint_ctrl)


# ── Room list ─────────────────────────────────────────────────────────────────
func _refresh_room_list() -> void:
	var uni: String = RoomData.UNIVERSES[cb_universe.selected]
	var room_type: String = RoomData.TYPES[cb_type.selected]
	var search: String = txt_search.text
	_filtered_rooms = RoomData.filter(uni, room_type, search)

	lst_rooms.clear()
	for room in _filtered_rooms:
		var type_color: Color = RoomData.type_color(room.type)
		lst_rooms.add_item(room.name, null, true)
		var idx := lst_rooms.item_count - 1
		lst_rooms.set_item_custom_fg_color(idx, type_color.lightened(0.3))
		lst_rooms.set_item_tooltip(idx, "[%s] %s\nCost: %d cr | Power: %s" % [
			room.type, room.universe, room.cost, RoomData.power_label(room.power)])


func _on_room_selected(index: int) -> void:
	if index < 0 or index >= _filtered_rooms.size():
		return
	_show_room_detail(_filtered_rooms[index])


func _on_room_activated(index: int) -> void:
	_on_add_room()


func _show_room_detail(def: Dictionary) -> void:
	_room_shape_preview.set_room(def)
	var pwr_color: String = "#4fdf8c" if def.power >= 0 else "#df6650"
	var pwr_str: String = RoomData.power_label(def.power)
	lbl_room_detail.text = (
		"[b][color=#c8d8ff]%s[/color][/b]\n" % def.name +
		"[color=#7090b0]%s  ·  %s[/color]\n" % [def.type, def.universe] +
		"Cost: [color=#ffd050]%d[/color] cr   Power: [color=%s]%s[/color]\n" % [def.cost, pwr_color, pwr_str] +
		"Durability: %d\n\n" % def.durability +
		"[color=#9090aa]%s[/color]" % def.desc
	)


# ── Adding nodes ──────────────────────────────────────────────────────────────
func _on_add_room() -> void:
	var sel := lst_rooms.get_selected_items()
	if sel.is_empty():
		_toast("Select a room from the list first.")
		return
	var def: Dictionary = _filtered_rooms[sel[0]]

	if credits < def.cost:
		_toast("Not enough credits! Need %d, have %d." % [def.cost, credits])
		return

	_node_counter += 1
	var uid := "node_%d" % _node_counter

	var ship_node := ShipNode.new()
	ship_node.name = uid          # GraphEdit uses name as key
	graph_edit.add_child(ship_node)
	ship_node.setup(def, uid)

	# Place near center + small random offset
	var cx: float = -graph_edit.scroll_offset.x + graph_edit.size.x * 0.5 - 80.0
	var cy: float = -graph_edit.scroll_offset.y + graph_edit.size.y * 0.5 - 40.0
	ship_node.position_offset = Vector2(cx + randf_range(-80, 80), cy + randf_range(-60, 60))

	credits -= def.cost
	# Assign a random hull texture (persists in save file)
	_room_textures[uid] = ROOM_TEXTURES[randi() % ROOM_TEXTURES.size()]
	_update_header()


# ── Graph connections ─────────────────────────────────────────────────────────
func _on_connection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int,
		to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)


# ── Node selection ────────────────────────────────────────────────────────────
func _on_node_selected(node: Node) -> void:
	if _delete_mode:
		_delete_ship_node(node as ShipNode)
		return

	var ship_node := node as ShipNode
	if ship_node == null:
		return
	var def := RoomData.find(ship_node.def_id)
	if not def.is_empty():
		_show_room_detail(def)


func _on_delete_nodes_request(nodes: Array) -> void:
	for node_name in nodes:
		var n := graph_edit.get_node_or_null(NodePath(node_name))
		if n != null:
			_delete_ship_node(n as ShipNode)


func _delete_ship_node(ship_node: ShipNode) -> void:
	if ship_node == null:
		return
	# Remove all connections to/from this node
	var conns: Array = graph_edit.get_connection_list()
	for conn in conns:
		if conn.from_node == ship_node.name or conn.to_node == ship_node.name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	# 50% refund
	var def := RoomData.find(ship_node.def_id)
	if not def.is_empty():
		credits += def.cost / 2
	_room_textures.erase(ship_node.node_uid)
	ship_node.queue_free()
	_update_header()


# ── Header updates ────────────────────────────────────────────────────────────
func _update_header() -> void:
	lbl_credits.text = "Credits: %s" % _format_number(credits)
	var pwr := _total_power()
	lbl_power.text = "Power: %s%d" % ["+" if pwr >= 0 else "", pwr]
	lbl_power.add_theme_color_override("font_color", CLR_PWR_POS if pwr >= 0 else CLR_PWR_NEG)
	var sys := StarMapData.find_system(_current_system)
	lbl_location.text = "📍 %s" % (sys.get("name", "Unknown") if not sys.is_empty() else "Unknown")


func _total_power() -> int:
	var total := 0
	for child in graph_edit.get_children():
		var ship_node := child as ShipNode
		if ship_node == null:
			continue
		var def := RoomData.find(ship_node.def_id)
		if not def.is_empty():
			total += def.power
	return total


func _all_nodes() -> Array:
	var result: Array = []
	for child in graph_edit.get_children():
		if child is ShipNode:
			result.append(child)
	return result


# ── Mode buttons ──────────────────────────────────────────────────────────────
func _on_toggle_delete_mode() -> void:
	_delete_mode = not _delete_mode
	btn_delete_mode.text = "Delete Mode: %s" % ("ON — click nodes to remove" if _delete_mode else "OFF")


func _on_toggle_hull_edit() -> void:
	_hull_edit_mode = not _hull_edit_mode
	btn_hull_edit.text = "Hull Edit: %s" % ("ON — drag shapes in preview" if _hull_edit_mode else "OFF")
	_blueprint_ctrl.edit_mode = _hull_edit_mode
	_blueprint_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP if _hull_edit_mode else Control.MOUSE_FILTER_IGNORE


func _on_clear_all() -> void:
	var nodes := _all_nodes()
	if nodes.is_empty():
		return
	# Simple confirm via OS dialog
	var confirmed := true  # In a full game, show a confirmation dialog
	if confirmed:
		for n in nodes:
			n.queue_free()
		graph_edit.clear_connections()
		_update_header()


func _on_repair_all() -> void:
	var nodes := _all_nodes()
	if nodes.is_empty():
		_toast("No rooms to repair.")
		return
	var cost := nodes.size() * 50
	if credits < cost:
		_toast("Not enough credits to repair all rooms. Need %d cr." % cost)
		return
	credits -= cost
	for n in nodes:
		var ship_node := n as ShipNode
		var def := RoomData.find(ship_node.def_id)
		if not def.is_empty():
			ship_node.repair_full(def)
	_update_header()
	_toast("All rooms repaired for %d cr." % cost)


# ── New / Save / Load ─────────────────────────────────────────────────────────
func _on_new_ship() -> void:
	for n in _all_nodes():
		n.queue_free()
	graph_edit.clear_connections()
	ship_name       = "My Ship"
	credits         = 2000
	_node_counter   = 0
	_current_system = "sol"
	_room_textures.clear()
	txt_ship_name.text = ship_name
	_update_header()


func _on_save() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.snship ; StarNode Ship", "*.json ; JSON"]
	dialog.current_file = ship_name + ".snship"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		_save_to_file(path)
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 500))


func _on_load() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.snship ; StarNode Ship", "*.json ; JSON"]
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		_load_from_file(path)
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 500))


func _save_to_file(path: String) -> void:
	_last_save_path = path
	var nodes_data: Array = []
	for n in _all_nodes():
		var ship_node := n as ShipNode
		nodes_data.append({
			"uid":      ship_node.node_uid,
			"name":     ship_node.name,
			"def_id":   ship_node.def_id,
			"pos_x":    ship_node.position_offset.x,
			"pos_y":    ship_node.position_offset.y,
			"durability": ship_node.current_durability,
		"texture":    _room_textures.get(ship_node.node_uid, ""),
		"hull_ox":    ship_node.hull_offset.x,
		"hull_oy":    ship_node.hull_offset.y,
		})

	var conn_data: Array = []
	for conn in graph_edit.get_connection_list():
		conn_data.append({
			"from": conn.from_node,
			"from_port": conn.from_port,
			"to": conn.to_node,
			"to_port": conn.to_port,
		})

	var save_dict := {
		"version":        SAVE_VERSION,
		"ship_name":      ship_name,
		"credits":        credits,
		"counter":        _node_counter,
		"current_system": _current_system,
		"nodes":          nodes_data,
		"connections":    conn_data,
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_toast("Save failed: could not open file.")
		return
	file.store_string(JSON.stringify(save_dict, "\t"))
	file.close()
	_toast("Ship '%s' saved!" % ship_name)


func _load_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_toast("Load failed: could not open file.")
		return
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_toast("Load failed: invalid file format.")
		return

	# Clear current ship
	for n in _all_nodes():
		n.queue_free()
	graph_edit.clear_connections()
	_room_textures.clear()

	var data: Dictionary = parsed
	ship_name       = data.get("ship_name",      "My Ship")
	credits         = data.get("credits",        2000)
	_node_counter   = data.get("counter",        0)
	_current_system = data.get("current_system", "sol")
	txt_ship_name.text = ship_name

	# Restore nodes
	var name_map: Dictionary = {}  # saved name -> new node
	var legacy_textures_assigned := false
	for nd in data.get("nodes", []):
		var def := RoomData.find(nd.def_id)
		if def.is_empty():
			continue
		var ship_node := ShipNode.new()
		ship_node.name = nd.name
		graph_edit.add_child(ship_node)
		ship_node.setup(def, nd.uid)
		ship_node.position_offset = Vector2(nd.pos_x, nd.pos_y)
		ship_node.current_durability = nd.durability
		ship_node.hull_offset = Vector2(nd.get("hull_ox", 0.0), nd.get("hull_oy", 0.0))
		ship_node._refresh_dur_bar()
		var tex_path: String = nd.get("texture", "")
		if not tex_path.is_empty():
			_room_textures[nd.uid] = tex_path
		else:
			# Legacy save without texture data — assign a random hull texture
			_room_textures[nd.uid] = ROOM_TEXTURES[randi() % ROOM_TEXTURES.size()]
			legacy_textures_assigned = true
		name_map[nd.name] = ship_node

	# Restore connections (must happen after all nodes exist)
	for conn in data.get("connections", []):
		graph_edit.connect_node(conn.from, conn.from_port, conn.to, conn.to_port)

	_last_save_path = path
	_update_header()
	_toast("Ship '%s' loaded." % ship_name)

	# Auto-save if legacy textures were assigned so they persist
	if legacy_textures_assigned:
		_save_to_file(path)
		_toast("Textures assigned to legacy rooms — save updated.")


# ── Job system ────────────────────────────────────────────────────────────────
func _on_run_job() -> void:
	var nodes := _all_nodes()
	if nodes.is_empty():
		_toast("Your ship has no rooms!")
		return

	var days := int(spin_days.value)
	var pwr  := _total_power()

	# Launch the 3D star map — it handles all travel, damage, and events
	var star_map := StarMap.new()
	star_map.setup({
		"days":           days,
		"power":          pwr,
		"node_count":     nodes.size(),
		"ship_name":      ship_name,
		"ship_nodes":     nodes,
		"current_system": _current_system,
		"room_textures":  _room_textures,
	})
	add_child(star_map)
	star_map.job_finished.connect(_on_job_finished)


func _on_job_finished(result: Dictionary) -> void:
	var earned: int = result.get("earned", 0)
	credits += earned
	_current_system = result.get("destination_id", _current_system)
	_update_header()
	_toast("Arrived at %s. +%s cr." % [
		result.get("destination", "destination"),
		_format_number(earned)])


# ── UI helpers ────────────────────────────────────────────────────────────────
func _make_label(text: String, size: int = 10,
		color: Color = CLR_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return lbl


func _make_btn(text: String, min_width: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	if min_width > 0:
		btn.custom_minimum_size.x = min_width
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.flat = false
	btn.pressed.connect(callback)
	return btn


func _style_panel(ctrl: Control, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	ctrl.add_theme_stylebox_override("panel", s)


func _style_input(ctrl: Control) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.071, 0.102, 0.165, 1.0)
	s.border_color = Color(0.18, 0.26, 0.42, 1.0)
	s.set_border_width_all(1)
	s.set_content_margin_all(5)
	ctrl.add_theme_stylebox_override("normal", s)
	ctrl.add_theme_stylebox_override("focus", s)
	ctrl.add_theme_color_override("font_color", CLR_TEXT)


func _add_spacer(parent: Control, width: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.x = width
	parent.add_child(sp)


func _add_vsep(parent: Control) -> void:
	var sep := VSeparator.new()
	sep.add_theme_color_override("color", Color(0.20, 0.27, 0.42, 1.0))
	parent.add_child(sep)


func _format_number(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func _toast(msg: String) -> void:
	# Simple popup label that fades away
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.22, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	lbl.add_theme_stylebox_override("normal", style)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.position = Vector2(20, -60)
	lbl.z_index = 100
	add_child(lbl)

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)


func _show_dialog(title_text: String, body: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body
	dialog.size = Vector2i(500, 360)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()
