## main.gd — StarNode main scene.
## Builds all UI in code. GraphEdit handles pan/zoom/connections natively.
extends Control

# ── UI references ────────────────────────────────────────────────────────────
var graph_edit: GraphEdit
var txt_ship_name: LineEdit
var lbl_credits: Label
var lbl_power: Label
var lbl_location: Label
var lbl_crew: Label
var _job_board_popup: PanelContainer  # active job board modal (if open)
var btn_delete_mode: Button
var btn_hull_edit: Button
var _blueprint_ctrl: ShipBlueprint

# ── Shipyard modal refs (created/destroyed on open/close) ────────────────────
var _shipyard_popup: Control           # the full-screen shipyard overlay
var _sy_lst_rooms: ItemList
var _sy_lbl_detail: RichTextLabel
var _sy_cb_universe: OptionButton
var _sy_cb_type: OptionButton
var _sy_txt_search: LineEdit
var _sy_shape_preview: RoomShapePreview
var _sy_lbl_credits: Label
var _return_to_port_after_shipyard: bool = false  # reopen port when shipyard closes

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
var _crew:           Array     = []   # Array of crew Dictionaries
var _crew_counter:   int       = 0    # for unique crew IDs
var _jobs_completed: int       = 0    # 0 = fresh ship (starter crew auto-assigned)
var _ship_log:       Array     = []   # Array of log entry Dicts: {date, from, to, days, earned, wages, lines}

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
	lbl_power.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_power.gui_input.connect(_on_power_click)
	lbl_power.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hbox.add_child(lbl_power)

	lbl_location = _make_label("📍 Sol", 11, CLR_DIM)
	lbl_location.custom_minimum_size.x = 115
	lbl_location.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_location.gui_input.connect(_on_location_click)
	lbl_location.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hbox.add_child(lbl_location)

	lbl_crew = _make_label("Crew: 0", 11, Color(0.65, 0.80, 0.95, 1.0))
	lbl_crew.custom_minimum_size.x = 70
	lbl_crew.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_crew.gui_input.connect(_on_crew_click)
	lbl_crew.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hbox.add_child(lbl_crew)

	_add_vsep(hbox)

	var btn_log := _make_btn("📖 Log", 65, _show_captains_log)
	btn_log.add_theme_color_override("font_color", Color(0.75, 0.70, 0.95, 1.0))
	hbox.add_child(btn_log)

	var btn_shipyard := _make_btn("🔧 Shipyard", 90, func(): _show_shipyard(false))
	btn_shipyard.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	hbox.add_child(btn_shipyard)

	var btn_job := _make_btn("📋 Find Job", 100, _on_find_job)
	btn_job.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	hbox.add_child(btn_job)

	_add_vsep(hbox)

	btn_delete_mode = _make_btn("DEL", 45, _on_toggle_delete_mode)
	btn_delete_mode.add_theme_font_size_override("font_size", 9)
	btn_delete_mode.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	hbox.add_child(btn_delete_mode)

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


## ─────────────────────────────────────────────────────────────────────────────
## SHIPYARD MODAL — room shopping (replaces the old sidebar)
## ─────────────────────────────────────────────────────────────────────────────

const PERCY_PORTRAIT := "res://assets/pictures/crew/percy_commander.png"


func _show_percy_hint(message: String, on_dismiss: Callable = Callable()) -> void:
	## Quick Percy popup with a message and a dismiss button.
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CLR_PANEL
	style.border_color = CLR_ACCENT.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -100
	panel.offset_bottom = 100
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var percy_tex := TextureRect.new()
	percy_tex.custom_minimum_size = Vector2(64, 64)
	percy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	percy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PERCY_PORTRAIT):
		percy_tex.texture = load(PERCY_PORTRAIT)
	hb.add_child(percy_tex)

	var speech_vb := VBoxContainer.new()
	speech_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_vb.add_theme_constant_override("separation", 2)
	hb.add_child(speech_vb)

	speech_vb.add_child(_make_label("Commander Percy", 13, CLR_ACCENT))

	var speech := RichTextLabel.new()
	speech.bbcode_enabled = true
	speech.fit_content = true
	speech.scroll_active = false
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.add_theme_font_size_override("normal_font_size", 11)
	speech.add_theme_color_override("default_color", CLR_TEXT)
	speech.text = "[color=#aabbdd]%s[/color]" % message
	speech_vb.add_child(speech)

	var _dismiss := on_dismiss  # capture for lambda
	var btn_ok := _make_btn("Got it", 80, func():
		overlay.queue_free()
		if _dismiss.is_valid():
			_dismiss.call()
	)
	btn_ok.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	vb.add_child(btn_ok)

	add_child(overlay)


func _show_shipyard(show_intro: bool, inventory: Array = []) -> void:
	if _shipyard_popup and is_instance_valid(_shipyard_popup):
		return  # already open

	var popup := Control.new()
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.z_index = 50
	_shipyard_popup = popup

	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)

	# Main panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CLR_PANEL
	style.border_color = CLR_ACCENT.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -340
	panel.offset_bottom = 340
	popup.add_child(panel)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 8)
	panel.add_child(root_vb)

	# ── Percy intro (first time only) ────────────────────────────────────────
	if show_intro:
		var intro_hb := HBoxContainer.new()
		intro_hb.add_theme_constant_override("separation", 12)
		root_vb.add_child(intro_hb)

		var percy_tex := TextureRect.new()
		percy_tex.custom_minimum_size = Vector2(72, 72)
		percy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		percy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(PERCY_PORTRAIT):
			percy_tex.texture = load(PERCY_PORTRAIT)
		intro_hb.add_child(percy_tex)

		var speech_vb := VBoxContainer.new()
		speech_vb.add_theme_constant_override("separation", 2)
		intro_hb.add_child(speech_vb)

		var name_lbl := _make_label("Commander Percy", 13, CLR_ACCENT)
		speech_vb.add_child(name_lbl)

		var speech := RichTextLabel.new()
		speech.bbcode_enabled = true
		speech.fit_content = true
		speech.scroll_active = false
		speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speech.add_theme_font_size_override("normal_font_size", 11)
		speech.add_theme_color_override("default_color", CLR_TEXT)
		speech.text = (
			"[color=#aabbdd]\"Welcome, Captain. You've got [color=#ffd050]%d credits[/color] " +
			"to outfit your ship. You'll need at least a [color=#4fdf8c]Power[/color] source, " +
			"an [color=#4fdf8c]Engine[/color], and a [color=#4fdf8c]Command[/color] room to fly. " +
			"Whatever's left over, spend on crew — you'll want at least two hands on deck. " +
			"Choose wisely, and good luck out there.\"[/color]"
		) % credits
		speech_vb.add_child(speech)

		var sep := HSeparator.new()
		sep.add_theme_color_override("separator", CLR_ACCENT.darkened(0.4))
		root_vb.add_child(sep)

	# ── Header row ───────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_vb.add_child(header)

	header.add_child(_make_label("SHIPYARD", 16, CLR_ACCENT))
	header.add_child(_spacer_ctrl())

	_sy_lbl_credits = _make_label("Credits: %s" % _format_number(credits), 13, CLR_GOLD)
	header.add_child(_sy_lbl_credits)

	var rooms_count := _make_label("Rooms: %d" % _all_nodes().size(), 11, CLR_DIM)
	rooms_count.name = "lbl_rooms_count"
	header.add_child(rooms_count)

	# ── Body: filters + list on left, detail on right ────────────────────────
	var body_hb := HBoxContainer.new()
	body_hb.add_theme_constant_override("separation", 10)
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_child(body_hb)

	# Left column: filters + room list
	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 4)
	left_vb.custom_minimum_size.x = 300
	body_hb.add_child(left_vb)

	# Search
	_sy_txt_search = LineEdit.new()
	_sy_txt_search.placeholder_text = "Search rooms..."
	_style_input(_sy_txt_search)
	_sy_txt_search.text_changed.connect(func(_t): _sy_refresh_room_list(inventory))
	left_vb.add_child(_sy_txt_search)

	# Filters row
	var filter_hb := HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", 4)
	left_vb.add_child(filter_hb)

	_sy_cb_universe = OptionButton.new()
	_sy_cb_universe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for u in RoomData.UNIVERSES:
		_sy_cb_universe.add_item(u)
	_sy_cb_universe.selected = 0
	_sy_cb_universe.item_selected.connect(func(_i): _sy_refresh_room_list(inventory))
	filter_hb.add_child(_sy_cb_universe)

	_sy_cb_type = OptionButton.new()
	_sy_cb_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in RoomData.TYPES:
		_sy_cb_type.add_item(t)
	_sy_cb_type.selected = 0
	_sy_cb_type.item_selected.connect(func(_i): _sy_refresh_room_list(inventory))
	filter_hb.add_child(_sy_cb_type)

	# Room list
	_sy_lst_rooms = ItemList.new()
	_sy_lst_rooms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sy_lst_rooms.item_selected.connect(_sy_on_room_selected)
	_sy_lst_rooms.item_activated.connect(func(_i): _sy_buy_room(inventory))
	left_vb.add_child(_sy_lst_rooms)

	# Buy button
	var btn_buy := _make_btn("+ Buy Room", -1, func(): _sy_buy_room(inventory))
	btn_buy.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	left_vb.add_child(btn_buy)

	# Right column: room detail
	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 4)
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hb.add_child(right_vb)

	right_vb.add_child(_make_label("Room Details", 11, CLR_ACCENT))

	# Shape preview
	_sy_shape_preview = RoomShapePreview.new()
	_sy_shape_preview.custom_minimum_size = Vector2(0, 140)
	var shape_style := StyleBoxFlat.new()
	shape_style.bg_color = Color(0.055, 0.078, 0.125, 1.0)
	shape_style.border_color = Color(0.15, 0.20, 0.32, 1.0)
	shape_style.set_border_width_all(1)
	_sy_shape_preview.add_theme_stylebox_override("panel", shape_style)
	right_vb.add_child(_sy_shape_preview)

	# Detail text
	_sy_lbl_detail = RichTextLabel.new()
	_sy_lbl_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sy_lbl_detail.bbcode_enabled = true
	_sy_lbl_detail.fit_content = false
	_sy_lbl_detail.scroll_active = false
	_sy_lbl_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sy_lbl_detail.text = "[color=#7090b0]Select a room to see details.[/color]"
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.055, 0.078, 0.125, 1.0)
	detail_style.border_color = Color(0.15, 0.20, 0.32, 1.0)
	detail_style.set_border_width_all(1)
	detail_style.set_content_margin_all(8)
	_sy_lbl_detail.add_theme_stylebox_override("normal", detail_style)
	right_vb.add_child(_sy_lbl_detail)

	# ── Bottom bar ───────────────────────────────────────────────────────────
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator", CLR_ACCENT.darkened(0.4))
	root_vb.add_child(sep2)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root_vb.add_child(bottom)

	var help := _make_label("Double-click a room to buy it instantly", 9, CLR_DIM)
	bottom.add_child(help)

	bottom.add_child(_spacer_ctrl())

	var btn_close := _make_btn("Close Shipyard", 130, _close_shipyard)
	btn_close.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	bottom.add_child(btn_close)

	add_child(popup)
	_sy_refresh_room_list(inventory)


func _close_shipyard() -> void:
	if _shipyard_popup and is_instance_valid(_shipyard_popup):
		_shipyard_popup.queue_free()
		_shipyard_popup = null
	_update_header()
	# If we came from the port menu, reopen it
	if _return_to_port_after_shipyard:
		_return_to_port_after_shipyard = false
		_open_port_menu("shipyard")


func _spacer_ctrl() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _sy_refresh_room_list(inventory: Array = []) -> void:
	if _sy_lst_rooms == null:
		return
	var uni: String = RoomData.UNIVERSES[_sy_cb_universe.selected]
	var room_type: String = RoomData.TYPES[_sy_cb_type.selected]
	var search: String = _sy_txt_search.text

	if inventory.is_empty():
		_filtered_rooms = RoomData.filter(uni, room_type, search)
	else:
		# Port merchant: filter from subset
		var uni_all := (uni == "All")
		var type_all := (room_type == "All" or room_type == "All Types")
		_filtered_rooms = []
		for room in inventory:
			if not uni_all and room.universe != uni:
				continue
			if not type_all and room.type != room_type:
				continue
			if not search.is_empty() and search.to_lower() not in room.name.to_lower():
				continue
			_filtered_rooms.append(room)

	_sy_lst_rooms.clear()
	for room in _filtered_rooms:
		var type_color: Color = RoomData.type_color(room.type)
		var affordable: bool = credits >= room.cost
		var label: String = "%s  (%d cr)" % [room.name, room.cost]
		_sy_lst_rooms.add_item(label, null, true)
		var idx := _sy_lst_rooms.item_count - 1
		_sy_lst_rooms.set_item_custom_fg_color(idx,
			type_color.lightened(0.3) if affordable else Color(0.45, 0.42, 0.40, 1.0))


func _sy_on_room_selected(index: int) -> void:
	if index < 0 or index >= _filtered_rooms.size():
		return
	var def: Dictionary = _filtered_rooms[index]
	_sy_shape_preview.set_room(def)
	var pwr_color: String = "#4fdf8c" if def.power >= 0 else "#df6650"
	var pwr_str: String = RoomData.power_label(def.power)
	_sy_lbl_detail.text = (
		"[b][color=#c8d8ff]%s[/color][/b]\n" % def.name +
		"[color=#7090b0]%s  ·  %s[/color]\n" % [def.type, def.universe] +
		"Cost: [color=#ffd050]%d[/color] cr   Power: [color=%s]%s[/color]\n" % [def.cost, pwr_color, pwr_str] +
		"Durability: %d\n\n" % def.durability +
		"[color=#9090aa]%s[/color]" % def.desc
	)


func _sy_buy_room(inventory: Array = []) -> void:
	var sel: Array = _sy_lst_rooms.get_selected_items()
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
	ship_node.name = uid
	graph_edit.add_child(ship_node)
	ship_node.setup(def, uid)

	var cx: float = -graph_edit.scroll_offset.x + graph_edit.size.x * 0.5 - 80.0
	var cy: float = -graph_edit.scroll_offset.y + graph_edit.size.y * 0.5 - 40.0
	ship_node.position_offset = Vector2(cx + randf_range(-80, 80), cy + randf_range(-60, 60))
	ship_node.hull_pos = _next_hull_slot()

	credits -= def.cost
	_room_textures[uid] = ROOM_TEXTURES[randi() % ROOM_TEXTURES.size()]

	# Fresh ship: auto-assign one starter crew member per room
	if _jobs_completed == 0:
		_crew_counter += 1
		var cm := CrewData.generate_crew(def.type, _crew_counter)
		cm.assigned_to = uid
		_crew.append(cm)

	_update_header()

	# Update shipyard UI
	if _sy_lbl_credits:
		_sy_lbl_credits.text = "Credits: %s" % _format_number(credits)
	# Update room count label
	if _shipyard_popup and is_instance_valid(_shipyard_popup):
		var rc := _shipyard_popup.find_child("lbl_rooms_count", true, false)
		if rc:
			(rc as Label).text = "Rooms: %d" % _all_nodes().size()
	_sy_refresh_room_list(inventory)


func _build_blueprint_preview() -> void:
	_blueprint_ctrl = ShipBlueprint.new()
	_blueprint_ctrl.graph_ref     = graph_edit
	_blueprint_ctrl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_blueprint_ctrl.z_index       = 10
	# Anchor bottom-left of the window — sits inside the graph area
	_blueprint_ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_blueprint_ctrl.offset_left   =  10.0
	_blueprint_ctrl.offset_right  = 192.0   # 10 + 182 wide
	_blueprint_ctrl.offset_top    = -152.0  # 142 tall + 10 margin from bottom
	_blueprint_ctrl.offset_bottom =  -10.0
	add_child(_blueprint_ctrl)

	# Hull edit button anchored just above the blueprint preview
	var btn_hull := Button.new()
	btn_hull.text = "Edit Hull"
	btn_hull.add_theme_font_size_override("font_size", 10)
	btn_hull.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	btn_hull.z_index = 11
	btn_hull.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	btn_hull.offset_left   =  10.0
	btn_hull.offset_right  = 100.0
	btn_hull.offset_top    = -172.0
	btn_hull.offset_bottom = -155.0
	btn_hull.pressed.connect(_on_toggle_hull_edit)
	btn_hull.name = "btn_hull_edit_overlay"
	add_child(btn_hull)
	btn_hull_edit = btn_hull


# ── Adding nodes (kept for hull slot logic) ───────────────────────────────────


func _next_hull_slot() -> Vector2:
	## Find next available grid position for a new room in hull layout.
	## Lays out rooms in a grid: 4 columns, ~50px spacing.
	var existing: Array[Vector2] = []
	for child in graph_edit.get_children():
		var sn := child as ShipNode
		if sn != null and sn.hull_pos != Vector2.ZERO:
			existing.append(sn.hull_pos)
	var cols := 4
	var spacing := 50.0
	var idx := existing.size()   # this room's index (0-based)
	var col := idx % cols
	var row := idx / cols
	return Vector2(col * spacing, row * spacing)


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

	pass  # Room detail now shown in Shipyard modal


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
	if lbl_crew != null:
		lbl_crew.text = "Crew: %d" % _crew.size()


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


# ── Header label clicks ──────────────────────────────────────────────────────
func _on_location_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _jobs_completed > 0:
			_open_port_menu("summary")
		else:
			_toast("Complete a job first to access the port.")


func _on_crew_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _jobs_completed > 0:
			_open_port_menu("crew")
		else:
			_toast("Complete a job first to manage crew.")


func _on_power_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_power_breakdown()


func _open_port_menu(tab: String = "summary") -> void:
	## Open the port menu from the node screen (not after a job).
	var port := PortMenu.new()
	port.setup({
		"credits":        credits,
		"crew":           _crew,
		"crew_counter":   _crew_counter,
		"current_system": _current_system,
		"result":         {},
		"wages":          0,
		"ship_nodes":     _all_nodes(),
		"room_textures":  _room_textures,
		"start_tab":      tab,
	})
	add_child(port)
	port.port_closed.connect(_on_port_closed)
	port.visit_shipyard.connect(_on_visit_shipyard.bind(port))


func _show_power_breakdown() -> void:
	## Show an itemized popup of power production/consumption per room.
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style.border_color = CLR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 55

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	popup.add_child(vb)

	var title := Label.new()
	title.text = "POWER BREAKDOWN"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", CLR_ACCENT)
	vb.add_child(title)

	var total_gen := 0
	var total_use := 0
	var nodes := _all_nodes()

	if nodes.is_empty():
		var lbl := Label.new()
		lbl.text = "No rooms installed."
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", CLR_DIM)
		vb.add_child(lbl)
	else:
		# Generators first
		var generators: Array = []
		var consumers: Array = []
		for n in nodes:
			var sn := n as ShipNode
			var def := RoomData.find(sn.def_id)
			if def.is_empty(): continue
			if def.power > 0:
				generators.append(def)
				total_gen += def.power
			elif def.power < 0:
				consumers.append(def)
				total_use += def.power

		if not generators.is_empty():
			var hdr := Label.new()
			hdr.text = "GENERATORS"
			hdr.add_theme_font_size_override("font_size", 11)
			hdr.add_theme_color_override("font_color", CLR_PWR_POS)
			vb.add_child(hdr)
			for def in generators:
				var row := Label.new()
				row.text = "  %s: +%d PWR" % [def.name, def.power]
				row.add_theme_font_size_override("font_size", 10)
				row.add_theme_color_override("font_color", CLR_PWR_POS)
				vb.add_child(row)

		if not consumers.is_empty():
			var hdr := Label.new()
			hdr.text = "CONSUMERS"
			hdr.add_theme_font_size_override("font_size", 11)
			hdr.add_theme_color_override("font_color", CLR_PWR_NEG)
			vb.add_child(hdr)
			for def in consumers:
				var row := Label.new()
				row.text = "  %s: %d PWR" % [def.name, def.power]
				row.add_theme_font_size_override("font_size", 10)
				row.add_theme_color_override("font_color", CLR_PWR_NEG)
				vb.add_child(row)

		# Summary
		var sep := HSeparator.new()
		vb.add_child(sep)
		var net := total_gen + total_use
		var net_lbl := Label.new()
		net_lbl.text = "Generated: +%d  |  Used: %d  |  Net: %s%d" % [
			total_gen, total_use, "+" if net >= 0 else "", net]
		net_lbl.add_theme_font_size_override("font_size", 12)
		net_lbl.add_theme_color_override("font_color", CLR_GOLD)
		vb.add_child(net_lbl)

	# Close button
	var btn := Button.new()
	btn.text = "Close"
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void: popup.queue_free())
	vb.add_child(btn)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.offset_left = -180
	popup.offset_right = 180
	popup.offset_top = -150
	popup.offset_bottom = 150


# ── Captain's Log ─────────────────────────────────────────────────────────────
func _show_captains_log() -> void:
	## Full-screen overlay showing the ship's voyage history.
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.98)
	style.border_color = Color(0.45, 0.40, 0.70, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = 51
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -340
	panel.offset_right  =  340
	panel.offset_top    = -260
	panel.offset_bottom =  260

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "📖  CAPTAIN'S LOG  —  %s" % ship_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.70, 0.95, 1.0))
	vb.add_child(title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	# Scrollable log area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var log_vb := VBoxContainer.new()
	log_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vb.add_theme_constant_override("separation", 8)
	scroll.add_child(log_vb)

	if _ship_log.is_empty():
		var empty := Label.new()
		empty.text = "No voyages recorded yet. Complete a job to begin your log."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", CLR_DIM)
		log_vb.add_child(empty)
	else:
		# Show voyages in reverse order (most recent first)
		for i in range(_ship_log.size() - 1, -1, -1):
			var entry: Dictionary = _ship_log[i]
			_build_log_entry(log_vb, entry)

	# Close button
	var btn_close := Button.new()
	btn_close.text = "Close"
	btn_close.custom_minimum_size.x = 100
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.pressed.connect(func() -> void: overlay.queue_free())
	vb.add_child(btn_close)


func _build_log_entry(parent: Control, entry: Dictionary) -> void:
	## Build one voyage entry in the Captain's Log.
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.08, 0.14, 1.0)
	cs.border_color = Color(0.3, 0.28, 0.5, 0.5)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(4)
	cs.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)

	var voyage_num: int  = entry.get("voyage", 0)
	var from_id: String  = entry.get("from", "sol")
	var to_name: String  = entry.get("to_name", "Unknown")
	var days: int        = entry.get("days", 0)
	var earned: int      = entry.get("earned", 0)
	var wages: int       = entry.get("wages", 0)
	var crew_count: int  = entry.get("crew", 0)

	# Look up origin system name
	var from_name := from_id
	for sys in StarMapData.SYSTEMS:
		if sys.id == from_id:
			from_name = sys.name
			break

	# Header line
	var hdr := Label.new()
	hdr.text = "Voyage #%d  —  %s → %s" % [voyage_num, from_name, to_name]
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(0.75, 0.70, 0.95, 1.0))
	vb.add_child(hdr)

	# Stats line
	var net: int = earned - wages
	var stats := Label.new()
	stats.text = "%d days  |  Earned: %d cr  |  Wages: -%d cr  |  Net: %s%d cr  |  Crew: %d" % [
		days, earned, wages, "+" if net >= 0 else "", net, crew_count]
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", CLR_DIM)
	vb.add_child(stats)

	# Expandable event log — show a summary, click to expand
	var lines: Array = entry.get("lines", [])
	if lines.is_empty():
		return

	# Count notable events (skip empty lines and routine "Day X" lines)
	var events: Array = []
	for line in lines:
		var s: String = line
		if s.is_empty(): continue
		# Strip BBCode for plain-text check
		var plain := s.replace("[color=", "").replace("[/color]", "")
		if plain.find("═══") >= 0: continue  # header/footer dividers
		if plain.find("Arrived at") >= 0: continue
		if plain.find("Net earned") >= 0: continue
		if plain.find("Crew wages") >= 0: continue
		events.append(s)

	if events.is_empty():
		return

	var btn_expand := Button.new()
	btn_expand.text = "▶ %d events" % events.size()
	btn_expand.add_theme_font_size_override("font_size", 9)
	btn_expand.flat = true
	btn_expand.add_theme_color_override("font_color", CLR_ACCENT)
	vb.add_child(btn_expand)

	var detail_box := RichTextLabel.new()
	detail_box.bbcode_enabled = true
	detail_box.fit_content = true
	detail_box.scroll_active = false
	detail_box.custom_minimum_size.y = 0
	detail_box.add_theme_font_size_override("normal_font_size", 9)
	detail_box.add_theme_color_override("default_color", Color(0.6, 0.65, 0.75, 1.0))
	detail_box.visible = false
	vb.add_child(detail_box)

	var event_text := "\n".join(events)
	detail_box.text = event_text

	btn_expand.pressed.connect(func() -> void:
		detail_box.visible = not detail_box.visible
		btn_expand.text = ("▼ %d events" if detail_box.visible else "▶ %d events") % events.size()
	)


# ── Mode buttons ──────────────────────────────────────────────────────────────
func _on_toggle_delete_mode() -> void:
	_delete_mode = not _delete_mode
	btn_delete_mode.text = "DEL %s" % ("ON" if _delete_mode else "")
	btn_delete_mode.add_theme_color_override("font_color",
		Color(1.0, 0.3, 0.3, 1.0) if _delete_mode else Color(1.0, 0.55, 0.55, 1.0))


func _on_toggle_hull_edit() -> void:
	_hull_edit_mode = not _hull_edit_mode
	btn_hull_edit.text = "HULL %s" % ("ON" if _hull_edit_mode else "")
	btn_hull_edit.add_theme_color_override("font_color",
		Color(0.3, 0.95, 1.0, 1.0) if _hull_edit_mode else Color(0.55, 0.85, 1.0, 1.0))
	_blueprint_ctrl.edit_mode = _hull_edit_mode
	_blueprint_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP if _hull_edit_mode else Control.MOUSE_FILTER_IGNORE
	# 2× preview size when editing
	if _hull_edit_mode:
		_blueprint_ctrl.offset_left   =  10.0
		_blueprint_ctrl.offset_right  = 374.0   # 364 wide
		_blueprint_ctrl.offset_top    = -294.0   # 284 tall
		_blueprint_ctrl.offset_bottom =  -10.0
	else:
		_blueprint_ctrl.offset_left   =  10.0
		_blueprint_ctrl.offset_right  = 192.0   # 182 wide
		_blueprint_ctrl.offset_top    = -152.0   # 142 tall
		_blueprint_ctrl.offset_bottom =  -10.0


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
	_crew.clear()
	_crew_counter   = 0
	_jobs_completed = 0
	_ship_log.clear()
	txt_ship_name.text = ship_name
	_update_header()
	# Open the shipyard with Percy's intro for the new captain
	_show_shipyard(true)


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
		"hull_px":    ship_node.hull_pos.x,
		"hull_py":    ship_node.hull_pos.y,
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
		"crew":           _crew,
		"crew_counter":   _crew_counter,
		"jobs_completed": _jobs_completed,
		"ship_log":       _ship_log,
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
	_crew           = data.get("crew",           [])
	_crew_counter   = data.get("crew_counter",   0)
	_jobs_completed = data.get("jobs_completed", 0)
	_ship_log       = data.get("ship_log",       [])

	# Sanitize crew status — clear any in-progress states from a mid-session save
	for cm in _crew:
		var status: String = cm.get("status", "active")
		if status in ["on_mission", "shore_leave", "arrested"]:
			cm.status = "active"
			cm.assigned_to = ""
			cm.shore_leave_days = 0
		# Migration: ensure trips field exists for old saves
		if not cm.has("trips"):
			cm.trips = 0
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
		# Hull position migration: new key → old offset key → fallback to GraphEdit pos
		if nd.has("hull_px"):
			ship_node.hull_pos = Vector2(nd.hull_px, nd.hull_py)
		elif nd.has("hull_ox"):
			ship_node.hull_pos = Vector2(nd.pos_x + nd.hull_ox, nd.pos_y + nd.hull_oy)
		else:
			ship_node.hull_pos = Vector2(nd.pos_x, nd.pos_y)
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
func _on_find_job() -> void:
	var nodes := _all_nodes()
	if nodes.is_empty():
		_toast("Your ship has no rooms!")
		return
	if _job_board_popup and is_instance_valid(_job_board_popup):
		return   # already open

	var listings: Array = StarMapData.generate_job_listings(_current_system)
	if listings.is_empty():
		_toast("No jobs available right now.")
		return

	_show_job_board(listings)


func _show_job_board(listings: Array) -> void:
	var popup := PanelContainer.new()
	_job_board_popup = popup
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.border_color = CLR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 55

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	popup.add_child(vb)

	# Title
	var cur_sys := StarMapData.find_system(_current_system)
	var loc_name: String = cur_sys.get("name", _current_system) if not cur_sys.is_empty() else _current_system
	var title := Label.new()
	title.text = "JOB BOARD — %s" % loc_name
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", CLR_GOLD)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%d listing%s available" % [listings.size(), "s" if listings.size() != 1 else ""]
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", CLR_DIM)
	vb.add_child(subtitle)

	vb.add_child(HSeparator.new())

	# Job listings
	for job in listings:
		var row := _build_job_row(job, popup)
		vb.add_child(row)

	# Close button
	var btn_close := Button.new()
	btn_close.text = "Close"
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.pressed.connect(func() -> void:
		popup.queue_free()
		_job_board_popup = null)
	vb.add_child(btn_close)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.offset_left  = -260
	popup.offset_right =  260
	popup.offset_top   = -220
	popup.offset_bottom = 220


func _build_job_row(job: Dictionary, popup: PanelContainer) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.06, 0.09, 0.15, 1.0)
	row_style.border_color = Color(0.15, 0.22, 0.35, 1.0)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(10)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row_panel.add_child(hb)

	# Left: job info
	var info_vb := VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 2)
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	# Job type + destination
	var lbl_title := Label.new()
	lbl_title.text = "%s → %s" % [job.job_type, job.destination_name]
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0, 1.0))
	info_vb.add_child(lbl_title)

	# Description
	var lbl_desc := Label.new()
	lbl_desc.text = job.job_desc
	lbl_desc.add_theme_font_size_override("font_size", 10)
	lbl_desc.add_theme_color_override("font_color", CLR_DIM)
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(lbl_desc)

	# Stats line: days, pay/day, total, hazard
	var stats_text := "%d days  |  %d cr/day  |  Total: %d cr" % [
		job.days, job.pay_per_day, job.total_pay]
	if job.harsh:
		stats_text += "  |  ⚠ Hazardous"
	var lbl_stats := Label.new()
	lbl_stats.text = stats_text
	lbl_stats.add_theme_font_size_override("font_size", 10)
	lbl_stats.add_theme_color_override("font_color",
		Color(0.86, 0.39, 0.31, 1.0) if job.harsh else Color(0.55, 0.72, 0.55, 1.0))
	info_vb.add_child(lbl_stats)

	# Durability warnings — estimate which rooms may fail during this trip
	var at_risk := _estimate_at_risk_rooms(job.days, job.harsh)
	if not at_risk.is_empty():
		var warn_lbl := Label.new()
		warn_lbl.text = "⚠ " + "  ".join(at_risk)
		warn_lbl.add_theme_font_size_override("font_size", 10)
		warn_lbl.add_theme_color_override("font_color", Color(0.95, 0.30, 0.25, 1.0))
		info_vb.add_child(warn_lbl)

	# Right: Accept button
	var btn := Button.new()
	btn.text = "Accept"
	btn.custom_minimum_size = Vector2(70, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	btn.pressed.connect(func() -> void:
		popup.queue_free()
		_job_board_popup = null
		_accept_job(job))
	hb.add_child(btn)

	return row_panel


func _accept_job(job: Dictionary) -> void:
	var nodes := _all_nodes()
	var days: int  = job.days
	var pwr: int   = _total_power()
	var wages: int = CrewData.wage_for_trip(_crew.size(), days)

	var star_map := StarMap.new()
	star_map.setup({
		"days":            days,
		"power":           pwr,
		"node_count":      nodes.size(),
		"ship_name":       ship_name,
		"ship_nodes":      nodes,
		"current_system":  _current_system,
		"destination_id":  job.destination_id,
		"job_type":        job.job_type,
		"job_pay_per_day": job.pay_per_day,
		"room_textures":   _room_textures,
		"crew":            _crew,
		"wages":           wages,
	})
	add_child(star_map)
	star_map.job_finished.connect(_on_job_finished)
	_jobs_completed += 1


func _estimate_at_risk_rooms(days: int, harsh: bool) -> Array:
	## Returns array of "!XX" initials for rooms whose durability may hit 0.
	var nodes := _all_nodes()
	var pwr := _total_power()
	var warnings: Array = []
	for node in nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue

		# Estimate daily wear (mirrors star_map.gd logic, simplified)
		var wear := 1
		match def.get("type", ""):
			"Engines": wear = 2
			"Power":   wear = 2
		if harsh:
			wear += 1
		if pwr < 0:
			wear += 1
		# Crew reduction (best case, assigned matching crew)
		for cm in _crew:
			if cm.get("assigned_to", "") == sn.node_uid and cm.get("status", "") == "active":
				var crew_type: String = CrewData.room_type_for_role(cm.get("role", ""))
				if crew_type == def.get("type", ""):
					wear = maxi(0, wear - 1)
					break

		var total_wear := wear * days
		if sn.current_durability - total_wear <= 0:
			# Build initials: "Warp Core" → "WC", "Ion Engine" → "IE"
			var room_name: String = def.get("name", "?")
			var initials := ""
			for word in room_name.split(" "):
				if not word.is_empty():
					initials += word[0].to_upper()
			warnings.append("!%s" % initials)
	return warnings


func _on_job_finished(result: Dictionary) -> void:
	var earned: int = result.get("earned", 0)
	var wages: int  = result.get("wages", 0)
	credits += earned - wages
	var prev_system := _current_system
	_current_system = result.get("destination_id", _current_system)
	_update_header()

	# ── Crew veteran progression ──
	var promotions: Array = CrewData.apply_trip_completion(_crew)
	for promo in promotions:
		_toast(promo)

	# ── Record voyage in Captain's Log ──
	_ship_log.append({
		"voyage":  _jobs_completed,
		"from":    prev_system,
		"to":      result.get("destination_id", "unknown"),
		"to_name": result.get("destination", "Unknown"),
		"days":    result.get("days", 0),
		"earned":  earned,
		"wages":   wages,
		"crew":    _crew.size(),
		"lines":   result.get("log_lines", []),
		"promotions": promotions,
	})

	# Percy's crew hint after the very first job — defer port until dismissed
	if _jobs_completed == 1:
		var _result := result
		var _wages := wages
		_show_percy_hint(
			"\"Good work, Captain! Now that you've docked at a new port, " +
			"head to the [color=#4fdf8c]Crew[/color] tab — you can " +
			"[color=#ffd050]hire crew[/color] here. More hands means " +
			"less wear on your ship and better pay. Don't fly short-staffed!\"",
			func(): _open_port_after_job(_result, _wages)
		)
		return

	_open_port_after_job(result, wages)


func _open_port_after_job(result: Dictionary, wages: int) -> void:
	var port := PortMenu.new()
	port.setup({
		"credits":        credits,
		"crew":           _crew,
		"crew_counter":   _crew_counter,
		"current_system": _current_system,
		"result":         result,
		"wages":          wages,
		"ship_nodes":     _all_nodes(),
		"room_textures":  _room_textures,
	})
	add_child(port)
	port.port_closed.connect(_on_port_closed)
	port.visit_shipyard.connect(_on_visit_shipyard.bind(port))


func _on_port_closed(result: Dictionary) -> void:
	credits       = result.get("credits", credits)
	_crew         = result.get("crew", _crew)
	_crew_counter = result.get("crew_counter", _crew_counter)
	_update_header()

	var abandoned: Array = result.get("abandoned", [])
	if not abandoned.is_empty():
		_toast("Left behind: %s" % ", ".join(abandoned))

	# Auto-save if we have a path
	if not _last_save_path.is_empty():
		_save_to_file(_last_save_path)


func _on_visit_shipyard(inventory: Array, port: Control) -> void:
	## Port's "Open Shipyard" button was pressed — close port, open shipyard,
	## and flag so we reopen port when the shipyard closes.
	# Sync state from port before closing it
	if port.has_method("get_state"):
		var st: Dictionary = port.get_state()
		credits       = st.get("credits", credits)
		_crew         = st.get("crew", _crew)
		_crew_counter = st.get("crew_counter", _crew_counter)
	port.queue_free()
	_return_to_port_after_shipyard = true
	_show_shipyard(false, inventory)


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
