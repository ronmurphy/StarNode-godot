## main.gd — StarNode main scene.
## Builds all UI in code. GraphEdit handles pan/zoom/connections natively.
extends Control

# ── UI references ────────────────────────────────────────────────────────────
var graph_edit: GraphEdit
var txt_ship_name: LineEdit
var lbl_credits: Label
var lbl_power: Label
var lbl_location: Button
var lbl_crew: Button
var _job_board_popup: PanelContainer  # active job board modal (if open)
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
var _shipyard_price_mult: float = 1.0            # location price multiplier for current port

# ── Game state ───────────────────────────────────────────────────────────────
var ship_name: String = "My Ship"
var credits: int = 2000
var _node_counter: int = 0
var _hull_edit_mode: bool = false
var _filtered_rooms: Array = []
var _current_system: String = "sol"   # tracked across jobs
var _room_textures:  Dictionary = {}   # node_uid → res:// texture path
var _room_colors:    Dictionary = {}   # node_uid → "#rrggbb" hex (empty = type default)
var _last_save_path: String    = ""   # most recent save/load path for auto-save
var _crew:           Array     = []   # Array of crew Dictionaries
var _crew_counter:   int       = 0    # for unique crew IDs
var _jobs_completed: int       = 0    # 0 = fresh ship (starter crew auto-assigned)
var _ship_log:       Array     = []   # Array of log entry Dicts: {date, from, to, days, earned, wages, lines}
var _ship_3d_layout: Dictionary = {}  # per-room 3D offsets from layout editor
var _layout_editor:  Control   = null # active ShipLayoutEditor (if open)
var _cargo_puzzle:   Control   = null # active CargoPuzzle (if open)
var _pending_job:    Dictionary = {}  # job awaiting launch after cargo puzzle
var _discovered_systems: Array = []   # system IDs the player has charted
var _traveled_routes:    Array = []   # [[from_id, to_id], ...] for star chart lines
var _percy_missions_completed: Array = []
var _active_percy_mission: String = ""
var _crew_missions_completed: Array = []
var _active_crew_mission: String = ""
var _log_overlay: Control = null       # captain's log overlay (if open)
var _web_load_cb  = null               # JS callback reference — must stay alive until file is picked
var _cached_jobs: Array = []           # cached job listings for current port visit (no rerolling)
var _mission_jobs_since_available: int = 0  # jobs done since a mission needs an undiscovered dest

const CARGO_JOB_TYPES: Array = ["Freight", "Smuggling", "Colony Supply"]

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
	_setup_display_scale()
	_setup_emoji_font()
	_build_ui()
	_update_header()


var _is_web: bool = false

func _setup_emoji_font() -> void:
	_is_web = OS.has_feature("web")
	# On desktop, the OS provides emoji glyphs automatically. On web there's no
	# reliable way to inject an emoji fallback font in Godot's WASM runtime, so
	# we simply strip emoji prefixes via the _e() helper instead.


## Return "emoji text" on desktop, plain "text" on web.
func _e(emoji: String, text: String) -> String:
	if _is_web:
		return text
	return emoji + " " + text


func _setup_display_scale() -> void:
	# Desktop: project.godot sets mode=2 (maximized) and stretch=canvas_items
	# so Godot scales the 1280x800 viewport to fill the window automatically.
	# We do NOT touch content_scale_factor on desktop — doing so shrinks the
	# virtual viewport below 1280px and clips the header buttons.
	#
	# Web: the browser canvas is sized in CSS pixels. On a 2K tablet with
	# devicePixelRatio=2 the CSS viewport may only be ~800px wide, making
	# everything appear tiny. We apply a gentle boost only when dpr > 1.3.
	if not OS.has_feature("web"):
		return

	var dpr = JavaScriptBridge.eval("window.devicePixelRatio || 1.0")
	dpr = clampf(float(dpr), 1.0, 4.0)

	# Only intervene on genuine HiDPI displays (tablets, Retina, 2K+).
	# Standard 1x browser screens look fine with stretch mode alone.
	if dpr <= 1.3:
		return

	# Scale proportionally to dpr, but stay conservative so the UI doesn't
	# overflow on smaller tablet viewport widths.
	# dpr 1.5 -> ~1.2x  |  dpr 2.0 -> ~1.5x  |  dpr 3.0 -> ~1.8x
	var scale := clampf(1.0 + (dpr - 1.0) * 0.5, 1.0, 2.0)
	get_window().content_scale_factor = scale


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

	var btn_location := _make_btn(_e("📍", "Sol"), 115, _on_location_click)
	btn_location.add_theme_color_override("font_color", CLR_DIM)
	lbl_location = btn_location
	hbox.add_child(btn_location)

	var btn_crew := _make_btn(_e("👥", "Crew: 0"), 100, _on_crew_click)
	btn_crew.add_theme_color_override("font_color", Color(0.65, 0.80, 0.95, 1.0))
	hbox.add_child(btn_crew)
	lbl_crew = btn_crew

	_add_vsep(hbox)

	var btn_log := _make_btn(_e("📖", "Log"), 65, _show_captains_log)
	btn_log.add_theme_color_override("font_color", Color(0.75, 0.70, 0.95, 1.0))
	hbox.add_child(btn_log)

	# Shipyard removed from top bar — access only via port merchant or Percy intro
	#var btn_shipyard := _make_btn("Shipyard", 90, func(): _show_shipyard(false))
	#btn_shipyard.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	#hbox.add_child(btn_shipyard)

	var btn_3d_layout := _make_btn(_e("🛠️", "Designer"), 90, _open_3d_layout)
	btn_3d_layout.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 1.0))
	hbox.add_child(btn_3d_layout)

	var btn_job := _make_btn(_e("📋", "Find Job"), 100, _on_find_job)
	btn_job.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6, 1.0))
	hbox.add_child(btn_job)

	_add_vsep(hbox)


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

const CREW_PORTRAITS := {
	"percy":   "res://assets/pictures/crew/percy_commander.png",
	"roswell": "res://assets/pictures/crew/roswell.png",
	"shadow":  "res://assets/pictures/crew/shadow_scout.png",
	"zester":  "res://assets/pictures/crew/zester_ensign.png",
	"mika":    "res://assets/pictures/crew/mika_counselor.png",
	# ── Extended roster ─────────────────────────────────────────────────────
	"bella":   "res://assets/pictures/crew/bella_twin.png",
	"rina":    "res://assets/pictures/crew/rina_twin.png",
	"tumbler": "res://assets/pictures/crew/tumbler_tradeboss.png",
	"murphy":  "res://assets/pictures/crew/murphy_merchant.png",
	"river":   "res://assets/pictures/crew/river_ambassador.png",
	"fluffy":  "res://assets/pictures/crew/fluffy_contractor.png",
}
const CREW_DISPLAY_NAMES := {
	"percy":   "Commander Percy",
	"roswell": "Roswell",
	"shadow":  "Shadow",
	"zester":  "Ensign Zester",
	"mika":    "Counselor Mika",
	# ── Extended roster ─────────────────────────────────────────────────────
	"bella":   "Bella",
	"rina":    "Rina",
	"tumbler": "Tumbler",
	"murphy":  "Murphy",
	"river":   "Ambassador River",
	"fluffy":  "Fluffy",
}
const CREW_MARKER_COLORS := {
	"percy":   Color(0.95, 0.55, 0.15),
	"roswell": Color(0.40, 0.95, 0.40),
	"shadow":  Color(0.40, 0.70, 0.95),
	"zester":  Color(0.95, 0.95, 0.30),
	"mika":    Color(0.85, 0.45, 0.90),
	# ── Extended roster ─────────────────────────────────────────────────────
	"bella":   Color(0.95, 0.60, 0.80),  # pink
	"rina":    Color(0.95, 0.80, 0.60),  # peach
	"tumbler": Color(0.70, 0.55, 0.95),  # purple
	"murphy":  Color(0.85, 0.70, 0.30),  # khaki gold
	"river":   Color(0.30, 0.85, 0.85),  # teal
	"fluffy":  Color(0.70, 0.70, 0.70),  # neutral grey
}


func _show_crew_hint(crew_id: String, message: String, on_dismiss: Callable = Callable()) -> void:
	## Quick crew popup with a portrait, message, and a dismiss button.
	var vp_size := get_viewport().get_visible_rect().size
	var overlay := Control.new()
	overlay.top_level = true
	overlay.z_index = 100
	overlay.position = Vector2.ZERO
	overlay.size = vp_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = vp_size
	bg.color = Color(0.02, 0.03, 0.06, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var accent_col: Color = CREW_MARKER_COLORS.get(crew_id, CLR_ACCENT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CLR_PANEL
	style.border_color = accent_col.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	var pw := 520.0
	panel.position = Vector2((vp_size.x - pw) * 0.5, vp_size.y * 0.35)
	panel.custom_minimum_size.x = pw
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var portrait_path: String = CREW_PORTRAITS.get(crew_id, CREW_PORTRAITS.percy)
	var crew_tex := TextureRect.new()
	crew_tex.custom_minimum_size = Vector2(120, 160)
	crew_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crew_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crew_tex.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	crew_tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if ResourceLoader.exists(portrait_path):
		crew_tex.texture = load(portrait_path)
	hb.add_child(crew_tex)

	var speech_vb := VBoxContainer.new()
	speech_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_vb.add_theme_constant_override("separation", 2)
	hb.add_child(speech_vb)

	var display_name: String = CREW_DISPLAY_NAMES.get(crew_id, "Unknown")
	speech_vb.add_child(_make_label(display_name, 13, accent_col))

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
	_shipyard_price_mult = StarMapData.get_price_multiplier(_current_system)

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
		percy_tex.custom_minimum_size = Vector2(120, 160)
		percy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		percy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		percy_tex.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		percy_tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if ResourceLoader.exists(CREW_PORTRAITS.percy):
			percy_tex.texture = load(CREW_PORTRAITS.percy)
		intro_hb.add_child(percy_tex)

		var speech_vb := VBoxContainer.new()
		speech_vb.add_theme_constant_override("separation", 2)
		speech_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var room_adj_cost := int(float(room.cost) * _shipyard_price_mult)
		var affordable: bool = credits >= room_adj_cost
		var label: String = "%s  (%d cr)" % [room.name, room_adj_cost]
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
	var adj_cost := int(float(def.cost) * _shipyard_price_mult)
	var mult_note := "" if _shipyard_price_mult <= 1.0 else \
		"  [color=#ff8844](%s %.0fx)[/color]" % [StarMapData.get_price_tier_name(_current_system), _shipyard_price_mult]
	_sy_lbl_detail.text = (
		"[b][color=#c8d8ff]%s[/color][/b]\n" % def.name +
		"[color=#7090b0]%s  ·  %s[/color]\n" % [def.type, def.universe] +
		"Cost: [color=#ffd050]%d[/color] cr%s   Power: [color=%s]%s[/color]\n" % [adj_cost, mult_note, pwr_color, pwr_str] +
		"Durability: %d\n\n" % def.durability +
		"[color=#9090aa]%s[/color]" % def.desc
	)


func _sy_buy_room(inventory: Array = []) -> void:
	var sel: Array = _sy_lst_rooms.get_selected_items()
	if sel.is_empty():
		_toast("Select a room from the list first.")
		return
	var def: Dictionary = _filtered_rooms[sel[0]]
	var adj_cost := int(float(def.cost) * _shipyard_price_mult)

	if credits < adj_cost:
		_toast("Not enough credits! Need %d, have %d." % [adj_cost, credits])
		return

	_node_counter += 1
	var uid := "node_%d" % _node_counter

	var ship_node := ShipNode.new()
	ship_node.name = uid
	graph_edit.add_child(ship_node)
	ship_node.setup(def, uid)
	ship_node.sell_requested.connect(_on_sell_requested)

	var cx: float = -graph_edit.scroll_offset.x + graph_edit.size.x * 0.5 - 80.0
	var cy: float = -graph_edit.scroll_offset.y + graph_edit.size.y * 0.5 - 40.0
	ship_node.position_offset = Vector2(cx + randf_range(-80, 80), cy + randf_range(-60, 60))
	ship_node.hull_pos = _next_hull_slot()

	credits -= adj_cost
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
func _on_node_selected(_node: Node) -> void:
	pass  # Room detail now shown in Shipyard modal


func _on_delete_nodes_request(nodes: Array) -> void:
	for node_name in nodes:
		var n := graph_edit.get_node_or_null(NodePath(node_name))
		if n != null:
			_delete_ship_node(n as ShipNode)


func _on_sell_requested(ship_node: ShipNode) -> void:
	if ship_node == null:
		return
	var value := ship_node.sell_value()
	var dlg := ConfirmationDialog.new()
	dlg.title = "Sell Room"
	dlg.dialog_text = "Sell \"%s\" for %d credits?" % [ship_node.title, value]
	dlg.ok_button_text = "Sell"
	dlg.confirmed.connect(func():
		_sell_ship_node(ship_node, value)
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


func _sell_ship_node(ship_node: ShipNode, value: int) -> void:
	# Remove all connections to/from this node
	var conns: Array = graph_edit.get_connection_list()
	for conn in conns:
		if conn.from_node == ship_node.name or conn.to_node == ship_node.name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	credits += value
	_room_textures.erase(ship_node.node_uid)
	_room_colors.erase(ship_node.node_uid)
	_ship_3d_layout.erase(ship_node.node_uid)
	# Unassign any crew from this room
	for cm in _crew:
		if cm.assigned_to == ship_node.node_uid:
			cm.assigned_to = ""
	_toast("Sold %s for %d cr" % [ship_node.title, value])
	ship_node.queue_free()
	_update_header()


func _delete_ship_node(ship_node: ShipNode) -> void:
	if ship_node == null:
		return
	var conns: Array = graph_edit.get_connection_list()
	for conn in conns:
		if conn.from_node == ship_node.name or conn.to_node == ship_node.name:
			graph_edit.disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	credits += ship_node.sell_value()
	_room_textures.erase(ship_node.node_uid)
	_room_colors.erase(ship_node.node_uid)
	ship_node.queue_free()
	_update_header()


# ── Header updates ────────────────────────────────────────────────────────────
func _update_header() -> void:
	lbl_credits.text = "Credits: %s" % _format_number(credits)
	var pwr := _total_power()
	lbl_power.text = "Power: %s%d" % ["+" if pwr >= 0 else "", pwr]
	lbl_power.add_theme_color_override("font_color", CLR_PWR_POS if pwr >= 0 else CLR_PWR_NEG)
	var sys := StarMapData.find_system(_current_system)
	lbl_location.text = _e("📍", "%s") % (sys.get("name", "Unknown") if not sys.is_empty() else "Unknown")
	if lbl_crew != null:
		lbl_crew.text = _e("👥", "Crew: %d") % _crew.size()


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


func _calc_engine_tier() -> int:
	## Returns max speed multiplier based on total Engine-type room cost.
	## <600 = 2x, 600+ = 4x, 1200+ = 6x, 2000+ = 8x.
	var total_engine_cost := 0
	for child in graph_edit.get_children():
		var sn := child as ShipNode
		if sn == null:
			continue
		var def := RoomData.find(sn.def_id)
		if def.get("type", "") == "Engines":
			total_engine_cost += def.get("cost", 0)
	if total_engine_cost >= 2000:
		return 8
	if total_engine_cost >= 1200:
		return 6
	if total_engine_cost >= 600:
		return 4
	return 2


func _calc_cargo_grade() -> int:
	## Returns bonus columns for cargo puzzle based on avg Utility room cost.
	## <250 = +0, 250+ = +1, 500+ = +2, 800+ = +3.
	var costs: Array = []
	for child in graph_edit.get_children():
		var sn := child as ShipNode
		if sn == null:
			continue
		var def := RoomData.find(sn.def_id)
		if def.get("type", "") == "Utility":
			costs.append(def.get("cost", 0))
	if costs.is_empty():
		return 0
	var avg: float = 0.0
	for c in costs:
		avg += c
	avg /= costs.size()
	if avg >= 800:
		return 3
	if avg >= 500:
		return 2
	if avg >= 250:
		return 1
	return 0


# ── Header label clicks ──────────────────────────────────────────────────────
func _on_location_click() -> void:
	if _jobs_completed > 0:
		_open_port_menu("summary")
	else:
		_toast("Complete a job first to access the port.")


func _on_crew_click() -> void:
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
		"room_colors":    _room_colors,
		"start_tab":      tab,
		"price_mult":     StarMapData.get_price_multiplier(_current_system),
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
	## Full-screen overlay with tabs: Voyages + Star Chart.
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.queue_free()
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)
	_log_overlay = overlay

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
	panel.offset_left   = -400
	panel.offset_right  =  400
	panel.offset_top    = -310
	panel.offset_bottom =  310

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := Label.new()
	title.text = _e("📖", " CAPTAIN'S LOG") + "  --  %s" % ship_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.70, 0.95, 1.0))
	vb.add_child(title)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vb.add_child(tab_bar)

	# Content area — children swapped when tabs clicked
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(content)

	var btn_voyages := Button.new()
	btn_voyages.text = _e("📜", "Voyages")
	btn_voyages.custom_minimum_size = Vector2(120, 28)
	btn_voyages.add_theme_font_size_override("font_size", 11)
	btn_voyages.pressed.connect(func() -> void: _log_show_voyages(content))
	tab_bar.add_child(btn_voyages)

	var btn_chart := Button.new()
	btn_chart.text = _e("🗺", "Star Chart")
	btn_chart.custom_minimum_size = Vector2(120, 28)
	btn_chart.add_theme_font_size_override("font_size", 11)
	btn_chart.pressed.connect(func() -> void: _log_show_star_chart(content))
	tab_bar.add_child(btn_chart)

	# Legend (shows in tab bar, right-aligned)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(spacer)

	var lbl_loc := Label.new()
	lbl_loc.text = (_e("📍", "%s") + "  |  %d/%d systems charted") % [
		StarMapData.find_system(_current_system).get("name", "Unknown"),
		_discovered_systems.size(), StarMapData.SYSTEMS.size()]
	lbl_loc.add_theme_font_size_override("font_size", 10)
	lbl_loc.add_theme_color_override("font_color", CLR_DIM)
	tab_bar.add_child(lbl_loc)

	# Default: show voyages tab
	_log_show_voyages(content)

	# Close button
	var btn_close := Button.new()
	btn_close.text = "Close"
	btn_close.custom_minimum_size.x = 100
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.pressed.connect(func() -> void:
		overlay.queue_free()
		_log_overlay = null)
	vb.add_child(btn_close)


func _show_captains_log_chart() -> void:
	## Opens the captain's log directly on the Star Chart tab.
	_show_captains_log()
	# The log was just created — find the content area and switch to chart
	if _log_overlay and is_instance_valid(_log_overlay):
		# Content area is the 4th child of the VBox in the panel
		var panel: PanelContainer = _log_overlay.get_child(1) as PanelContainer
		if panel:
			var vb: VBoxContainer = panel.get_child(0) as VBoxContainer
			if vb and vb.get_child_count() > 2:
				var content: Control = vb.get_child(2)
				_log_show_star_chart(content)


func _log_show_voyages(container: Control) -> void:
	for c in container.get_children():
		c.queue_free()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

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
		for i in range(_ship_log.size() - 1, -1, -1):
			var entry: Dictionary = _ship_log[i]
			_build_log_entry(log_vb, entry)


# ── Star Chart tab ────────────────────────────────────────────────────────────
const CHART_MARGIN := 50.0
const CHART_TYPE_COLORS: Dictionary = {
	"star":       Color(1.0, 0.9, 0.4, 1.0),
	"planet":     Color(0.35, 0.75, 0.45, 1.0),
	"station":    Color(0.5, 0.7, 1.0, 1.0),
	"nebula":     Color(0.6, 0.3, 0.8, 1.0),
	"asteroid":   Color(0.65, 0.55, 0.38, 1.0),
	"black_hole": Color(0.5, 0.1, 0.6, 1.0),
}

func _log_show_star_chart(container: Control) -> void:
	for c in container.get_children():
		c.queue_free()

	var chart := Control.new()
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(chart)

	# Tooltip label (hidden by default)
	var tooltip := RichTextLabel.new()
	tooltip.name = "ChartTooltip"
	tooltip.bbcode_enabled = true
	tooltip.fit_content = true
	tooltip.scroll_active = false
	tooltip.visible = false
	tooltip.z_index = 55
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.custom_minimum_size = Vector2(230, 0)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.06, 0.12, 0.95)
	ts.border_color = Color(0.45, 0.40, 0.70, 1.0)
	ts.set_border_width_all(1)
	ts.set_corner_radius_all(4)
	ts.set_content_margin_all(8)
	tooltip.add_theme_stylebox_override("normal", ts)
	tooltip.add_theme_font_size_override("normal_font_size", 10)
	chart.add_child(tooltip)

	chart.draw.connect(func() -> void: _draw_star_chart(chart))
	chart.gui_input.connect(func(event: InputEvent) -> void:
		_chart_input(chart, event, tooltip))
	chart.queue_redraw()


func _chart_project(pos: Vector3, chart_size: Vector2) -> Vector2:
	## Project 3D system position to 2D chart (X→x, Z→y, ignore Y).
	var min_x := -85.0
	var max_x := 115.0
	var min_z := -65.0
	var max_z := 90.0
	var draw_w := chart_size.x - CHART_MARGIN * 2.0
	var draw_h := chart_size.y - CHART_MARGIN * 2.0
	var sx := CHART_MARGIN + (pos.x - min_x) / (max_x - min_x) * draw_w
	var sy := CHART_MARGIN + (pos.z - min_z) / (max_z - min_z) * draw_h
	return Vector2(sx, sy)


func _draw_star_chart(chart: Control) -> void:
	var sz := chart.size

	# Background grid lines (subtle)
	var grid_col := Color(0.12, 0.15, 0.22, 0.5)
	for gx in range(0, int(sz.x), 60):
		chart.draw_line(Vector2(gx, 0), Vector2(gx, sz.y), grid_col, 1.0)
	for gy in range(0, int(sz.y), 60):
		chart.draw_line(Vector2(0, gy), Vector2(sz.x, gy), grid_col, 1.0)

	# Traveled routes
	for route in _traveled_routes:
		if route.size() < 2:
			continue
		var from_sys := StarMapData.find_system(route[0] as String)
		var to_sys   := StarMapData.find_system(route[1] as String)
		if from_sys.is_empty() or to_sys.is_empty():
			continue
		var p1 := _chart_project(from_sys.pos, sz)
		var p2 := _chart_project(to_sys.pos, sz)
		chart.draw_line(p1, p2, Color(0.30, 0.45, 0.65, 0.45), 1.5, true)

	# Systems
	var font := ThemeDB.fallback_font
	for sys in StarMapData.SYSTEMS:
		var screen_pos := _chart_project(sys.pos as Vector3, sz)
		var is_disc: bool = _discovered_systems.has(sys.id as String)
		var is_cur: bool  = (sys.id as String) == _current_system

		if not is_disc:
			# Undiscovered — tiny dim dot
			chart.draw_circle(screen_pos, 2.0, Color(0.20, 0.22, 0.30, 0.35))
			continue

		var type_col: Color = CHART_TYPE_COLORS.get(sys.type as String, Color(0.7, 0.7, 0.7, 1.0))
		var radius: float = 3.5 + (sys.size as float) * 0.5

		# Current location — gold ring
		if is_cur:
			chart.draw_arc(screen_pos, radius + 5.0, 0.0, TAU, 32,
				Color(1.0, 0.85, 0.30, 0.9), 2.0, true)

		# Percy mission marker — orange ring
		var percy_id := _get_percy_mission_at(sys.id as String)
		if not percy_id.is_empty():
			var pcol: Color = CREW_MARKER_COLORS.get("percy", Color(0.95, 0.50, 0.15))
			chart.draw_arc(screen_pos, radius + 8.0, 0.0, TAU, 32,
				pcol.lerp(Color.WHITE, 0.1), 2.0, true)
			chart.draw_string(font, screen_pos + Vector2(radius + 8.0, -6.0),
				"!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, pcol)

		# Crew mission marker — colored ring per crew member
		var crew_mid := _get_crew_mission_at(sys.id as String)
		if not crew_mid.is_empty():
			var cm := StarMapData.find_crew_mission(crew_mid)
			var ccol: Color = CREW_MARKER_COLORS.get(cm.get("crew", "") as String, CLR_ACCENT)
			var ring_r: float = radius + 8.0 if percy_id.is_empty() else radius + 12.0
			chart.draw_arc(screen_pos, ring_r, 0.0, TAU, 32,
				ccol.lerp(Color.WHITE, 0.1), 2.0, true)
			chart.draw_string(font, screen_pos + Vector2(ring_r, -6.0),
				"!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ccol)

		# System dot
		chart.draw_circle(screen_pos, radius, type_col)
		# Highlight edge
		chart.draw_arc(screen_pos, radius, 0.0, TAU, 24,
			type_col.lightened(0.3), 1.0, true)

		# Label
		chart.draw_string(font, screen_pos + Vector2(radius + 4.0, 4.0),
			sys.name as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.75, 0.78, 0.88, 0.9))


func _chart_hit_test(mouse_pos: Vector2, chart_size: Vector2) -> Dictionary:
	## Returns the discovered system under the mouse, or empty.
	for sys in StarMapData.SYSTEMS:
		if not _discovered_systems.has(sys.id as String):
			continue
		var sp := _chart_project(sys.pos as Vector3, chart_size)
		if mouse_pos.distance_to(sp) <= 12.0:
			return sys
	return {}


func _chart_input(chart: Control, event: InputEvent, tooltip: RichTextLabel) -> void:
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		var hit := _chart_hit_test(pos, chart.size)
		if hit.is_empty():
			tooltip.visible = false
			return
		tooltip.visible = true
		# Keep tooltip inside panel bounds
		var tx: float = pos.x + 14.0
		var ty: float = pos.y + 14.0
		if tx + 240.0 > chart.size.x:
			tx = pos.x - 250.0
		if ty + 100.0 > chart.size.y:
			ty = pos.y - 110.0
		tooltip.position = Vector2(tx, ty)
		var mission_lines := ""
		var percy_id := _get_percy_mission_at(hit.id as String)
		if not percy_id.is_empty():
			var pm := StarMapData.find_percy_mission(percy_id)
			mission_lines += "\n[color=#ff8833][!] Commander Percy: %s[/color]\n[color=#ff8833]%s[/color]" % [
				pm.get("title", ""), pm.get("desc", "")]
		var crew_mid := _get_crew_mission_at(hit.id as String)
		if not crew_mid.is_empty():
			var cm := StarMapData.find_crew_mission(crew_mid)
			var cid: String = cm.get("crew", "") as String
			var cname: String = CREW_DISPLAY_NAMES.get(cid, "Unknown")
			var ccol: Color = CREW_MARKER_COLORS.get(cid, CLR_ACCENT)
			var hex := "#%02x%02x%02x" % [int(ccol.r * 255), int(ccol.g * 255), int(ccol.b * 255)]
			mission_lines += "\n[color=%s][!] %s: %s[/color]\n[color=%s]%s[/color]" % [
				hex, cname, cm.get("title", ""), hex, cm.get("desc", "")]
		var is_cur: String = "  [color=#ffd050]<< YOU ARE HERE[/color]" if (hit.id as String) == _current_system else ""
		tooltip.text = "[b]%s[/b]%s\nType: %s\n%s%s" % [
			hit.name, is_cur, (hit.type as String).capitalize(), hit.desc, mission_lines]

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit := _chart_hit_test(mb.position, chart.size)
			if hit.is_empty():
				return
			# Percy missions take priority on click
			var percy_id := _get_percy_mission_at(hit.id as String)
			if not percy_id.is_empty():
				_show_percy_mission_dialog(percy_id)
				return
			var crew_mid := _get_crew_mission_at(hit.id as String)
			if not crew_mid.is_empty():
				_show_crew_mission_dialog(crew_mid)


func _show_percy_mission_dialog(mission_id: String) -> void:
	var m := StarMapData.find_percy_mission(mission_id)
	if m.is_empty():
		return
	var loc_sys := StarMapData.find_system(m.location as String)
	var loc_name: String = loc_sys.get("name", "Unknown") as String

	# Close captain's log so the dialog is on top
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.queue_free()
		_log_overlay = null

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	ps.border_color = Color(0.90, 0.50, 0.15, 0.8)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -160
	panel.offset_bottom = 160
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# Percy portrait + message
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var portrait := TextureRect.new()
	var tex := load(CREW_PORTRAITS.percy)
	if tex:
		portrait.texture = tex
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(120, 160)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(portrait)

	var speech_vb := VBoxContainer.new()
	speech_vb.add_theme_constant_override("separation", 4)
	speech_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(speech_vb)

	var lbl_name := Label.new()
	lbl_name.text = "Commander Percy"
	lbl_name.add_theme_font_size_override("font_size", 12)
	lbl_name.add_theme_color_override("font_color", Color(0.95, 0.50, 0.15, 1.0))
	speech_vb.add_child(lbl_name)

	var speech := RichTextLabel.new()
	speech.bbcode_enabled = true
	speech.fit_content = true
	speech.scroll_active = false
	speech.text = m.percy_msg as String
	speech.add_theme_font_size_override("normal_font_size", 11)
	speech.add_theme_color_override("default_color", Color(0.75, 0.80, 0.90, 1.0))
	speech_vb.add_child(speech)

	# Mission details
	var details := Label.new()
	details.text = "[ %s ]  --  %s  |  ~%d days  |  Reward: %d cr" % [
		m.title, loc_name, m.days as int, m.reward as int]
	details.add_theme_font_size_override("font_size", 11)
	details.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55, 1.0))
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(details)

	var desc := Label.new()
	desc.text = m.desc as String
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", CLR_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(desc)

	# Accept / Decline
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var btn_accept := Button.new()
	btn_accept.text = "Accept Mission"
	btn_accept.custom_minimum_size = Vector2(140, 32)
	btn_accept.add_theme_font_size_override("font_size", 12)
	btn_accept.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55, 1.0))
	btn_accept.pressed.connect(func() -> void:
		_active_percy_mission = mission_id
		overlay.queue_free()
		_launch_percy_mission())
	btn_row.add_child(btn_accept)

	var btn_decline := Button.new()
	btn_decline.text = "Not Now"
	btn_decline.custom_minimum_size = Vector2(100, 32)
	btn_decline.add_theme_font_size_override("font_size", 11)
	btn_decline.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55, 1.0))
	btn_decline.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_captains_log_chart())
	btn_row.add_child(btn_decline)


func _launch_percy_mission() -> void:
	## Builds a synthetic job dict and launches the Percy mission flight.
	var m := StarMapData.find_percy_mission(_active_percy_mission)
	if m.is_empty():
		return
	var loc_sys := StarMapData.find_system(m.location as String)
	var job := {
		"destination_id":   m.location as String,
		"destination_name": loc_sys.get("name", "Unknown") as String,
		"days":             m.days as int,
		"pay_per_day":      (m.reward as int) / maxi(1, m.days as int),
		"total_pay":        m.reward as int,
		"job_type":         "Percy Mission",
		"job_desc":         m.desc as String,
		"harsh":            StarMapData.is_harsh(m.location as String),
		"is_percy":         true,
	}
	_launch_flight(job, 0)


func _show_crew_mission_dialog(mission_id: String) -> void:
	var m := StarMapData.find_crew_mission(mission_id)
	if m.is_empty():
		return
	var crew_id: String = m.crew as String
	var loc_sys := StarMapData.find_system(m.location as String)
	var loc_name: String = loc_sys.get("name", "Unknown") as String
	var accent: Color = CREW_MARKER_COLORS.get(crew_id, CLR_ACCENT)
	var display_name: String = CREW_DISPLAY_NAMES.get(crew_id, "Unknown")
	var portrait_path: String = CREW_PORTRAITS.get(crew_id, CREW_PORTRAITS.percy)

	# Close captain's log so the dialog is on top
	if _log_overlay and is_instance_valid(_log_overlay):
		_log_overlay.queue_free()
		_log_overlay = null

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.14, 0.98)
	ps.border_color = accent.lerp(Color.WHITE, 0.15)
	ps.border_color.a = 0.8
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -160
	panel.offset_bottom = 160
	overlay.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var portrait := TextureRect.new()
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(120, 160)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(portrait)

	var speech_vb := VBoxContainer.new()
	speech_vb.add_theme_constant_override("separation", 4)
	speech_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(speech_vb)

	var lbl_name := Label.new()
	lbl_name.text = display_name
	lbl_name.add_theme_font_size_override("font_size", 12)
	lbl_name.add_theme_color_override("font_color", accent)
	speech_vb.add_child(lbl_name)

	var speech := RichTextLabel.new()
	speech.bbcode_enabled = true
	speech.fit_content = true
	speech.scroll_active = false
	speech.text = m.crew_msg as String
	speech.add_theme_font_size_override("normal_font_size", 11)
	speech.add_theme_color_override("default_color", Color(0.75, 0.80, 0.90, 1.0))
	speech_vb.add_child(speech)

	var details := Label.new()
	details.text = "[ %s ]  --  %s  |  ~%d days  |  Reward: %d cr" % [
		m.title, loc_name, m.days as int, m.reward as int]
	details.add_theme_font_size_override("font_size", 11)
	details.add_theme_color_override("font_color", accent.lightened(0.3))
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(details)

	var desc := Label.new()
	desc.text = m.desc as String
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", CLR_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var btn_accept := Button.new()
	btn_accept.text = "Accept Mission"
	btn_accept.custom_minimum_size = Vector2(140, 32)
	btn_accept.add_theme_font_size_override("font_size", 12)
	btn_accept.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55, 1.0))
	btn_accept.pressed.connect(func() -> void:
		_active_crew_mission = mission_id
		overlay.queue_free()
		_launch_crew_mission())
	btn_row.add_child(btn_accept)

	var btn_decline := Button.new()
	btn_decline.text = "Not Now"
	btn_decline.custom_minimum_size = Vector2(100, 32)
	btn_decline.add_theme_font_size_override("font_size", 11)
	btn_decline.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55, 1.0))
	btn_decline.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_captains_log_chart())
	btn_row.add_child(btn_decline)


func _launch_crew_mission() -> void:
	## Builds a synthetic job dict and launches a crew member mission flight.
	var m := StarMapData.find_crew_mission(_active_crew_mission)
	if m.is_empty():
		return
	var crew_id: String = m.crew as String
	var display_name: String = CREW_DISPLAY_NAMES.get(crew_id, "Unknown")
	var loc_sys := StarMapData.find_system(m.location as String)
	var job := {
		"destination_id":   m.location as String,
		"destination_name": loc_sys.get("name", "Unknown") as String,
		"days":             m.days as int,
		"pay_per_day":      (m.reward as int) / maxi(1, m.days as int),
		"total_pay":        m.reward as int,
		"job_type":         "%s Mission" % display_name,
		"job_desc":         m.desc as String,
		"harsh":            StarMapData.is_harsh(m.location as String),
		"is_crew_mission":  true,
		"crew_mission_id":  _active_crew_mission,
	}
	_launch_flight(job, 0)


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
	hdr.text = "Voyage #%d  --  %s >> %s" % [voyage_num, from_name, to_name]
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
	btn_expand.text = "> %d events" % events.size()
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
		btn_expand.text = ("v %d events" if detail_box.visible else "> %d events") % events.size()
	)


# ── Mode buttons ──────────────────────────────────────────────────────────────

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


# ── 3D Layout Editor ──────────────────────────────────────────────────────────
func _open_3d_layout() -> void:
	if _layout_editor != null:
		return  # already open
	if _all_nodes().is_empty():
		_toast("Add some rooms first!")
		return
	var editor := ShipLayoutEditor.new()
	editor.setup({
		"ship_nodes":      _all_nodes(),
		"room_textures":   _room_textures,
		"room_colors":     _room_colors,
		"existing_layout": _ship_3d_layout,
	})
	_layout_editor = editor
	editor.layout_saved.connect(func(layout: Dictionary) -> void:
		_ship_3d_layout = layout
		for uid: String in layout:
			var tex: String = layout[uid].get("tex", "")
			if not tex.is_empty():
				_room_textures[uid] = tex
		# Sync color tint data back to ShipNode properties (for save/load)
		for sn in _all_nodes():
			var ship_node := sn as ShipNode
			if ship_node == null:
				continue
			var hex: String = _room_colors.get(ship_node.node_uid, "")
			if hex.is_empty():
				ship_node.color_tint = Color(-1, -1, -1)
			else:
				ship_node.color_tint = Color.html(hex)
		_layout_editor = null
		_toast("3D layout saved!"))
	editor.layout_cancelled.connect(func() -> void:
		_layout_editor = null)
	add_child(editor)


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
	_room_colors.clear()
	_cached_jobs.clear()
	_mission_jobs_since_available = 0
	_crew.clear()
	_crew_counter   = 0
	_jobs_completed = 0
	_ship_log.clear()
	_ship_3d_layout.clear()
	_discovered_systems.clear()
	_traveled_routes.clear()
	_percy_missions_completed.clear()
	_active_percy_mission = ""
	_crew_missions_completed.clear()
	_active_crew_mission = ""
	_init_discovery()
	txt_ship_name.text = ship_name
	_update_header()
	# Open the shipyard with Percy's intro for the new captain
	_show_shipyard(true)


func _init_discovery() -> void:
	## Seeds the starting discovered systems if empty (new ship or old save migration).
	if _discovered_systems.is_empty():
		_discovered_systems = ["sol", "proxima", "alpha_cen", "station_k"]


func _discover_nearby(system_id: String) -> Array:
	## Discovers the given system and all systems within 15 units.
	## Returns array of newly discovered system names (for toast).
	var new_finds: Array = []
	var sys := StarMapData.find_system(system_id)
	if sys.is_empty():
		return new_finds
	if not _discovered_systems.has(system_id):
		_discovered_systems.append(system_id)
		new_finds.append(sys.name as String)
	var pos: Vector3 = sys.pos
	for s in StarMapData.SYSTEMS:
		if _discovered_systems.has(s.id):
			continue
		if pos.distance_to(s.pos as Vector3) <= 15.0:
			_discovered_systems.append(s.id as String)
			new_finds.append(s.name as String)
	return new_finds


func _get_available_percy_missions() -> Array:
	## Returns Percy missions whose triggers are met and not completed/active.
	var available: Array = []
	for m in StarMapData.PERCY_MISSIONS:
		var mid: String = m.id as String
		if _percy_missions_completed.has(mid):
			continue
		if _active_percy_mission == mid:
			continue
		# Sequential: previous mission must be completed
		var idx: int = StarMapData.PERCY_MISSIONS.find(m)
		if idx > 0:
			var prev: Dictionary = StarMapData.PERCY_MISSIONS[idx - 1]
			if not _percy_missions_completed.has(prev.id as String):
				continue
		# Check trigger
		var trigger: Dictionary = m.get("trigger", {})
		var ttype: String = trigger.get("type", "") as String
		if ttype == "jobs_completed":
			if _jobs_completed < (trigger.get("value", 999) as int):
				continue
		elif ttype == "system_discovered":
			if not _discovered_systems.has(trigger.get("value", "") as String):
				continue
		available.append(m)
	return available


func _get_percy_mission_at(system_id: String) -> String:
	## Returns the percy mission ID available at this system, or "".
	for m in _get_available_percy_missions():
		if (m.location as String) == system_id:
			return m.id as String
	return ""


func _get_available_crew_missions() -> Array:
	## Returns crew missions whose triggers are met and not completed/active.
	## Enforces per-crew sequential order (each crew's chain is independent).
	var available: Array = []
	for m in StarMapData.CREW_MISSIONS:
		var mid: String = m.id as String
		if _crew_missions_completed.has(mid):
			continue
		if _active_crew_mission == mid:
			continue
		# Sequential within same crew: previous mission by this crew must be done
		var crew_id: String = m.crew as String
		var idx_in_crew: int = 0
		var prev_mid: String = ""
		for other in StarMapData.CREW_MISSIONS:
			if (other.crew as String) == crew_id:
				if (other.id as String) == mid:
					break
				prev_mid = other.id as String
				idx_in_crew += 1
		if not prev_mid.is_empty() and not _crew_missions_completed.has(prev_mid):
			continue
		# Check trigger
		var trigger: Dictionary = m.get("trigger", {})
		var ttype: String = trigger.get("type", "") as String
		if ttype == "jobs_completed":
			if _jobs_completed < (trigger.get("value", 999) as int):
				continue
		elif ttype == "system_discovered":
			if not _discovered_systems.has(trigger.get("value", "") as String):
				continue
		available.append(m)
	return available


func _get_crew_mission_at(system_id: String) -> String:
	## Returns the first available crew mission ID at this system, or "".
	for m in _get_available_crew_missions():
		if (m.location as String) == system_id:
			return m.id as String
	return ""


func _check_mission_destination_failsafe() -> void:
	## After each regular job, check if a mission destination is undiscovered.
	## After 3 jobs with an undiscovered mission dest, auto-discover it.
	var undiscovered_dest: String = ""
	var hint_crew: String = "percy"
	var hint_name: String = ""

	# Check Percy missions first
	for m in _get_available_percy_missions():
		var loc: String = m.location as String
		if not _discovered_systems.has(loc):
			undiscovered_dest = loc
			hint_crew = "percy"
			hint_name = StarMapData.find_system(loc).get("name", "unknown") as String
			break

	# Then crew missions
	if undiscovered_dest.is_empty():
		for m in _get_available_crew_missions():
			var loc: String = m.location as String
			if not _discovered_systems.has(loc):
				undiscovered_dest = loc
				hint_crew = m.get("crew", "percy") as String
				hint_name = StarMapData.find_system(loc).get("name", "unknown") as String
				break

	if undiscovered_dest.is_empty():
		_mission_jobs_since_available = 0
		return

	_mission_jobs_since_available += 1
	if _mission_jobs_since_available < 3:
		return

	# Failsafe fires — auto-discover the destination
	_discovered_systems.append(undiscovered_dest)
	_mission_jobs_since_available = 0
	var display_name: String = CREW_DISPLAY_NAMES.get(hint_crew, "Percy")
	_toast("%s charted a route to %s!" % [display_name, hint_name])


func _inject_mission_failsafe_job() -> void:
	## Ensures mission destinations appear on the job board.
	## If an existing job already goes there, tag it with the crew name.
	## If not, inject a guaranteed job and tag it.
	## Collects all available missions with discovered destinations.
	var mission_dests: Array = []  # [{loc, crew_id}]

	for m in _get_available_percy_missions():
		var loc: String = m.location as String
		if _discovered_systems.has(loc):
			mission_dests.append({"loc": loc, "crew_id": "percy"})
	for m in _get_available_crew_missions():
		var loc: String = m.location as String
		if _discovered_systems.has(loc):
			mission_dests.append({"loc": loc, "crew_id": m.get("crew", "") as String})

	for md in mission_dests:
		var loc: String = md.loc
		var crew_name: String = CREW_DISPLAY_NAMES.get(md.crew_id, "Crew")
		# Check if an existing job already goes there
		var found_existing := false
		for j in _cached_jobs:
			if j.destination_id == loc:
				j["mission_for"] = crew_name
				found_existing = true
				break
		if not found_existing:
			# Inject a new job to that destination
			var forced: Array = StarMapData.generate_job_listings(
				_current_system, _discovered_systems, loc)
			if not forced.is_empty():
				var job: Dictionary = forced[0]
				job["mission_for"] = crew_name
				_cached_jobs.append(job)


func _on_save() -> void:
	if OS.get_name() == "Web":
		_save_to_web()
		return
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
	if OS.get_name() == "Web":
		_load_from_web()
		return
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


# ── Web save/load (browser download / file-input upload) ──────────────────────

func _save_to_web() -> void:
	var json_str: String = JSON.stringify(_build_save_dict(), "\t")
	var bytes: PackedByteArray = json_str.to_utf8_buffer()
	JavaScriptBridge.download_buffer(bytes, ship_name + ".snship", "application/octet-stream")
	_toast("Ship '%s' downloaded!" % ship_name)


func _load_from_web() -> void:
	_web_load_cb = JavaScriptBridge.create_callback(func(args: Array) -> void:
		_web_load_cb = null
		if args.is_empty() or (args[0] as String).is_empty():
			_toast("Load cancelled.")
			return
		var parsed: Variant = JSON.parse_string(args[0] as String)
		if parsed == null or not parsed is Dictionary:
			_toast("Load failed: invalid file format.")
			return
		_apply_save_data(parsed as Dictionary, ""))
	JavaScriptBridge.get_interface("window").godot_load_callback = _web_load_cb
	JavaScriptBridge.eval("""(function(){
		var inp = document.createElement('input');
		inp.type = 'file'; inp.accept = '.snship,.json';
		inp.style.display = 'none';
		document.body.appendChild(inp);
		inp.addEventListener('change', function(e){
			var f = e.target.files[0];
			document.body.removeChild(inp);
			if (!f) { window.godot_load_callback(''); return; }
			var r = new FileReader();
			r.onload = function(re){ window.godot_load_callback(re.target.result); };
			r.readAsText(f);
		});
		inp.click();
	})();""")
	_toast("Opening file picker…")


# ── Core save/load helpers ────────────────────────────────────────────────────

func _build_save_dict() -> Dictionary:
	var nodes_data: Array = []
	for n in _all_nodes():
		var ship_node := n as ShipNode
		nodes_data.append({
			"uid":        ship_node.node_uid,
			"name":       ship_node.name,
			"def_id":     ship_node.def_id,
			"pos_x":      ship_node.position_offset.x,
			"pos_y":      ship_node.position_offset.y,
			"durability": ship_node.current_durability,
			"texture":    _room_textures.get(ship_node.node_uid, ""),
			"color_tint": _room_colors.get(ship_node.node_uid, ""),
			"hull_px":    ship_node.hull_pos.x,
			"hull_py":    ship_node.hull_pos.y,
		})
	var conn_data: Array = []
	for conn in graph_edit.get_connection_list():
		conn_data.append({
			"from":      conn.from_node,
			"from_port": conn.from_port,
			"to":        conn.to_node,
			"to_port":   conn.to_port,
		})
	return {
		"version":        SAVE_VERSION,
		"ship_name":      ship_name,
		"credits":        credits,
		"counter":        _node_counter,
		"current_system": _current_system,
		"crew":           _crew,
		"crew_counter":   _crew_counter,
		"jobs_completed": _jobs_completed,
		"ship_log":       _ship_log,
		"ship_3d_layout": _ship_3d_layout,
		"discovered_systems":       _discovered_systems,
		"traveled_routes":          _traveled_routes,
		"percy_missions_completed": _percy_missions_completed,
		"active_percy_mission":     _active_percy_mission,
		"crew_missions_completed":  _crew_missions_completed,
		"active_crew_mission":      _active_crew_mission,
		"nodes":       nodes_data,
		"connections": conn_data,
	}


func _save_to_file(path: String) -> void:
	_last_save_path = path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_toast("Save failed: could not open file.")
		return
	file.store_string(JSON.stringify(_build_save_dict(), "\t"))
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
	_apply_save_data(parsed as Dictionary, path)


func _apply_save_data(data: Dictionary, path: String) -> void:

	# Clear current ship
	for n in _all_nodes():
		n.queue_free()
	graph_edit.clear_connections()
	_room_textures.clear()
	_room_colors.clear()
	_cached_jobs.clear()
	_mission_jobs_since_available = 0

	ship_name       = data.get("ship_name",      "My Ship")
	credits         = data.get("credits",        2000)
	_node_counter   = data.get("counter",        0)
	_current_system = data.get("current_system", "sol")
	_crew           = data.get("crew",           [])
	_crew_counter   = data.get("crew_counter",   0)
	_jobs_completed = data.get("jobs_completed", 0)
	_ship_log       = data.get("ship_log",       [])
	_ship_3d_layout = data.get("ship_3d_layout", {})
	_discovered_systems       = data.get("discovered_systems", [])
	_traveled_routes          = data.get("traveled_routes", [])
	_percy_missions_completed = data.get("percy_missions_completed", [])
	_active_percy_mission     = (data.get("active_percy_mission", "") as String)
	_crew_missions_completed  = data.get("crew_missions_completed", [])
	_active_crew_mission      = (data.get("active_crew_mission", "") as String)
	_init_discovery()   # migration for old saves without discovery data

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
		ship_node.sell_requested.connect(_on_sell_requested)
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
		# Per-room color tint (new saves only; old saves default to type color)
		var tint_hex: String = nd.get("color_tint", "")
		if not tint_hex.is_empty():
			ship_node.set_color_tint(Color.html(tint_hex))
			_room_colors[nd.uid] = tint_hex
		name_map[nd.name] = ship_node

	# Restore connections (must happen after all nodes exist)
	for conn in data.get("connections", []):
		graph_edit.connect_node(conn.from, conn.from_port, conn.to, conn.to_port)

	_last_save_path = path
	_update_header()
	_toast("Ship '%s' loaded." % ship_name)

	# Auto-save if legacy textures were assigned so they persist (desktop only)
	if legacy_textures_assigned and not path.is_empty() and OS.get_name() != "Web":
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

	if _cached_jobs.is_empty():
		_cached_jobs = StarMapData.generate_job_listings(_current_system, _discovered_systems)
		_inject_mission_failsafe_job()
	if _cached_jobs.is_empty():
		_toast("No jobs available right now.")
		return

	_show_job_board(_cached_jobs)


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

	# Percy mission at this location — special entry at top
	if not _active_percy_mission.is_empty():
		var pm := StarMapData.find_percy_mission(_active_percy_mission)
		if not pm.is_empty() and (pm.location as String) == _current_system:
			var percy_row := _build_percy_job_row(pm, popup)
			vb.add_child(percy_row)
			vb.add_child(HSeparator.new())

	# Crew mission at this location
	if not _active_crew_mission.is_empty():
		var cm := StarMapData.find_crew_mission(_active_crew_mission)
		if not cm.is_empty() and (cm.location as String) == _current_system:
			var crew_row := _build_crew_job_row(cm, popup)
			vb.add_child(crew_row)
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

	# Job type + destination (with crew name if mission-guaranteed job)
	var mission_for: String = job.get("mission_for", "")
	var lbl_title := RichTextLabel.new()
	lbl_title.bbcode_enabled = true
	lbl_title.fit_content = true
	lbl_title.scroll_active = false
	lbl_title.add_theme_font_size_override("normal_font_size", 12)
	lbl_title.add_theme_font_size_override("bold_font_size", 12)
	lbl_title.add_theme_color_override("default_color", Color(0.9, 0.92, 1.0, 1.0))
	if mission_for.is_empty():
		lbl_title.text = "%s >> %s" % [job.job_type, job.destination_name]
	else:
		lbl_title.text = "[b][color=#ffd050]%s[/color][/b] -- %s >> %s" % [
			mission_for, job.job_type, job.destination_name]
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
		stats_text += "  |  [!] Hazardous"
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
		warn_lbl.text = "[!] " + "  ".join(at_risk)
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


func _build_percy_job_row(pm: Dictionary, popup: PanelContainer) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.08, 0.04, 1.0)
	row_style.border_color = Color(0.90, 0.50, 0.15, 0.7)
	row_style.set_border_width_all(2)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(10)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row_panel.add_child(hb)

	var info_vb := VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 2)
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	var lbl_title := Label.new()
	lbl_title.text = "[!] PERCY MISSION -- %s" % (pm.title as String)
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.20, 1.0))
	info_vb.add_child(lbl_title)

	var lbl_desc := Label.new()
	lbl_desc.text = pm.desc as String
	lbl_desc.add_theme_font_size_override("font_size", 10)
	lbl_desc.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55, 1.0))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(lbl_desc)

	var lbl_stats := Label.new()
	lbl_stats.text = "~%d days  |  Reward: %d cr" % [pm.days as int, pm.reward as int]
	lbl_stats.add_theme_font_size_override("font_size", 10)
	lbl_stats.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55, 1.0))
	info_vb.add_child(lbl_stats)

	var btn := Button.new()
	btn.text = "Launch"
	btn.custom_minimum_size = Vector2(70, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.95, 0.55, 0.20, 1.0))
	btn.pressed.connect(func() -> void:
		popup.queue_free()
		_job_board_popup = null
		_launch_percy_mission())
	hb.add_child(btn)

	return row_panel


func _build_crew_job_row(cm: Dictionary, popup: PanelContainer) -> PanelContainer:
	var crew_id: String = cm.get("crew", "") as String
	var accent: Color = CREW_MARKER_COLORS.get(crew_id, CLR_ACCENT)
	var display_name: String = CREW_DISPLAY_NAMES.get(crew_id, "Unknown")

	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 1.0)
	row_style.border_color = accent.lerp(Color.WHITE, 0.1)
	row_style.border_color.a = 0.7
	row_style.set_border_width_all(2)
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(10)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row_panel.add_child(hb)

	var info_vb := VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 2)
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info_vb)

	var lbl_title := Label.new()
	lbl_title.text = "[!] %s -- %s" % [display_name.to_upper(), cm.title as String]
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", accent)
	info_vb.add_child(lbl_title)

	var lbl_desc := Label.new()
	lbl_desc.text = cm.desc as String
	lbl_desc.add_theme_font_size_override("font_size", 10)
	lbl_desc.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55, 1.0))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vb.add_child(lbl_desc)

	var lbl_stats := Label.new()
	lbl_stats.text = "~%d days  |  Reward: %d cr" % [cm.days as int, cm.reward as int]
	lbl_stats.add_theme_font_size_override("font_size", 10)
	lbl_stats.add_theme_color_override("font_color", accent.lightened(0.3))
	info_vb.add_child(lbl_stats)

	var mid: String = cm.id as String
	var btn := Button.new()
	btn.text = "Launch"
	btn.custom_minimum_size = Vector2(70, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", accent)
	btn.pressed.connect(func() -> void:
		popup.queue_free()
		_job_board_popup = null
		_active_crew_mission = mid
		_launch_crew_mission())
	hb.add_child(btn)

	return row_panel


func _accept_job(job: Dictionary) -> void:
	# Show cargo puzzle if this is a cargo-type job and player has cargo holds
	if CARGO_JOB_TYPES.has(job.job_type) and _count_cargo_holds() > 0:
		if _cargo_puzzle == null:
			_pending_job = job
			_show_cargo_puzzle(job)
			return

	_launch_flight(job, 0)


func _count_cargo_holds() -> int:
	var count: int = 0
	for sn in _all_nodes():
		var node := sn as ShipNode
		if node and node.def_id.contains("cargo"):
			count += 1
	return count


func _show_cargo_puzzle(job: Dictionary) -> void:
	var cargo_count: int = _count_cargo_holds()
	var puzzle := CargoPuzzle.new()
	puzzle.setup(cargo_count, job.pay_per_day, job.total_pay, job.job_type, _calc_cargo_grade())
	puzzle.puzzle_done.connect(func(bonus: int) -> void:
		puzzle.queue_free()
		_cargo_puzzle = null
		if bonus > 0:
			_toast("Cargo loaded efficiently! +%d cr bonus" % bonus)
		_launch_flight(_pending_job, bonus)
		_pending_job = {})
	add_child(puzzle)
	_cargo_puzzle = puzzle


func _launch_flight(job: Dictionary, cargo_bonus: int) -> void:
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
		"room_colors":     _room_colors,
		"crew":            _crew,
		"wages":           wages,
		"ship_3d_layout":  _ship_3d_layout,
		"cargo_bonus":     cargo_bonus,
		"discovered":      _discovered_systems,
		"is_percy":        job.get("is_percy", false),
		"is_crew_mission": job.get("is_crew_mission", false),
		"max_speed":       _calc_engine_tier(),
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
	_cached_jobs.clear()  # fresh jobs at new port (no rerolling)
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

	# ── Discovery expansion ──
	var route := [prev_system, _current_system]
	if not _traveled_routes.has(route):
		_traveled_routes.append(route)
	var newly_found := _discover_nearby(_current_system)
	if not newly_found.is_empty():
		_toast("Sensors charted %d new system(s): %s" % [
			newly_found.size(), ", ".join(newly_found)])

	# ── Mission destination failsafe ──
	# If a mission is available but its destination hasn't been discovered,
	# auto-discover it after 3 regular jobs so players don't get stuck.
	var is_story_job: bool = result.get("is_percy", false) or result.get("is_crew_mission", false)
	if not is_story_job:
		_check_mission_destination_failsafe()

	# ── Percy mission completion ──
	var is_percy: bool = result.get("is_percy", false)
	if is_percy and _active_percy_mission != "":
		var pm := StarMapData.find_percy_mission(_active_percy_mission)
		_percy_missions_completed.append(_active_percy_mission)
		_active_percy_mission = ""
		var bonus_sys: Array = pm.get("on_complete_discover", [])
		for sid in bonus_sys:
			if not _discovered_systems.has(sid as String):
				_discovered_systems.append(sid)
		if not bonus_sys.is_empty():
			var names: Array = []
			for sid in bonus_sys:
				var s := StarMapData.find_system(sid as String)
				if not s.is_empty():
					names.append(s.name as String)
			_toast("Mission complete! New systems charted: %s" % ", ".join(names))
		var _result := result
		var _wages := wages
		_show_crew_hint("percy",
			"\"Outstanding work, Captain. The data we recovered will " +
			"change everything. Stand by — I'll have new orders soon.\"",
			func(): _open_port_after_job(_result, _wages))
		return

	# ── Crew mission completion ──
	var is_crew_m: bool = result.get("is_crew_mission", false)
	if is_crew_m and _active_crew_mission != "":
		var cm := StarMapData.find_crew_mission(_active_crew_mission)
		var crew_id: String = cm.get("crew", "") as String
		_crew_missions_completed.append(_active_crew_mission)
		_active_crew_mission = ""
		var bonus_sys: Array = cm.get("on_complete_discover", [])
		for sid in bonus_sys:
			if not _discovered_systems.has(sid as String):
				_discovered_systems.append(sid)
		if not bonus_sys.is_empty():
			var names: Array = []
			for sid in bonus_sys:
				var s := StarMapData.find_system(sid as String)
				if not s.is_empty():
					names.append(s.name as String)
			_toast("Mission complete! New systems charted: %s" % ", ".join(names))
		var display_name: String = CREW_DISPLAY_NAMES.get(crew_id, "Unknown")
		var _result := result
		var _wages := wages
		_show_crew_hint(crew_id,
			"\"That was something, Captain. %s reporting mission complete. " % display_name +
			"I'll let you know if anything else comes up.\"",
			func(): _open_port_after_job(_result, _wages))
		return

	# ── Mission nudges — notify if a new mission became available ──
	# Percy nudge takes priority, then crew nudge (only show one per arrival)
	if not is_percy and not is_crew_m:
		var percy_avail := _get_available_percy_missions()
		if not percy_avail.is_empty():
			var next_m: Dictionary = percy_avail[0]
			var _result := result
			var _wages := wages
			_show_crew_hint("percy",
				"\"Captain, I've got something for you. Check the " +
				"[color=#ffd050]Star Chart[/color] in your log — " +
				"system [color=#4fdf8c]%s[/color].\"" % (
					StarMapData.find_system(
						next_m.location as String).get("name", "unknown")),
				func(): _open_port_after_job(_result, _wages))
			return

		var crew_avail := _get_available_crew_missions()
		if not crew_avail.is_empty():
			var next_cm: Dictionary = crew_avail[0]
			var cid: String = next_cm.get("crew", "") as String
			var cname: String = CREW_DISPLAY_NAMES.get(cid, "Someone")
			var loc_name: String = StarMapData.find_system(
				next_cm.location as String).get("name", "unknown")
			var _result := result
			var _wages := wages
			_show_crew_hint(cid,
				"\"Captain, got a minute? Check the " +
				"[color=#ffd050]Star Chart[/color] — " +
				"system [color=#4fdf8c]%s[/color]. " % loc_name +
				"%s has something to say.\"" % cname,
				func(): _open_port_after_job(_result, _wages))
			return

	# Percy's crew hint after the very first job — defer port until dismissed
	if _jobs_completed == 1:
		var _result := result
		var _wages := wages
		_show_crew_hint("percy",
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
		"room_colors":    _room_colors,
		"price_mult":     StarMapData.get_price_multiplier(_current_system),
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
