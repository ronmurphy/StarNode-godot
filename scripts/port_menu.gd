## port_menu.gd — Full-screen docking/port menu shown after arriving at a system.
## Tabs: Summary, Repair, Crew, Shore Leave, Away Missions, Shipyard.
## "Depart" button closes and returns.
class_name PortMenu
extends Control

signal port_closed(result: Dictionary)
signal visit_shipyard(inventory: Array)

# ── Theme (matches main.gd dark palette) ─────────────────────────────────────
const _BG      := Color(0.02, 0.03, 0.06, 0.92)
const _PANEL   := Color(0.078, 0.110, 0.176, 1.0)
const _HEADER  := Color(0.059, 0.086, 0.137, 1.0)
const _TEXT    := Color(0.780, 0.847, 1.000, 1.0)
const _DIM     := Color(0.470, 0.510, 0.620, 1.0)
const _ACCENT  := Color(0.310, 0.537, 0.843, 1.0)
const _GOLD    := Color(1.000, 0.820, 0.310, 1.0)
const _GREEN   := Color(0.310, 0.863, 0.545, 1.0)
const _RED     := Color(0.863, 0.392, 0.310, 1.0)
const _ORANGE  := Color(1.000, 0.600, 0.200, 1.0)
const _PURPLE  := Color(0.700, 0.400, 0.900, 1.0)

# ── State ────────────────────────────────────────────────────────────────────
var _params: Dictionary = {}
var _credits: int = 0
var _crew: Array = []
var _crew_counter: int = 0
var _hire_pool: Array = []
var _ship_nodes: Array = []
var _current_system: String = ""
var _result: Dictionary = {}
var _wages: int = 0

# ── Away missions ────────────────────────────────────────────────────────────
var _away_missions: Array = []       # available mission listings
var _active_mission: Dictionary = {} # currently running mission (empty = none)
var _mission_party: Array = []       # crew Dictionaries on the active mission

# ── Port events ──────────────────────────────────────────────────────────────
var _port_event: Dictionary = {}     # random event that fires on arrival (or empty)

# ── UI refs ──────────────────────────────────────────────────────────────────
var _content_area: Control
var _lbl_credits: Label
var _tab_buttons: Array[Button] = []
var _current_tab: String = "summary"


func setup(params: Dictionary) -> void:
	_params        = params
	_credits       = params.get("credits", 0)
	_crew          = params.get("crew", [])
	_crew_counter  = params.get("crew_counter", 0)
	_current_system = params.get("current_system", "sol")
	_result        = params.get("result", {})
	_wages         = params.get("wages", 0)
	_ship_nodes    = params.get("ship_nodes", [])

	_start_tab = params.get("start_tab", "summary")

	# Generate hire pool (3-5 random crew available at port)
	var pool_size := 3 + randi() % 3
	_hire_pool = CrewData.generate_pool(pool_size, _crew_counter + 100)

	# Generate away missions for this port
	_away_missions = _generate_away_missions()


var _start_tab: String = "summary"

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 50
	_build_ui()
	_show_tab(_start_tab)
	# Roll for a random port event (~35% chance)
	if randi() % 100 < 35:
		_roll_port_event()


func _build_ui() -> void:
	# Dark overlay background
	var bg := ColorRect.new()
	bg.color = _BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Centered panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL
	style.border_color = _ACCENT.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -310
	panel.offset_bottom = 310
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# ── Header row ───────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var sys := StarMapData.find_system(_current_system)
	var sys_name: String = sys.get("name", "Unknown") if not sys.is_empty() else "Unknown"
	header.add_child(_lbl("PORT: %s" % sys_name.to_upper(), 16, _ACCENT))

	header.add_child(_spacer())

	_lbl_credits = _lbl("Credits: %d" % _credits, 13, _GOLD)
	header.add_child(_lbl_credits)

	header.add_child(_lbl("Crew: %d" % _crew.size(), 13, _TEXT))

	# ── Tab bar ──────────────────────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	for tab_name in ["summary", "repair", "crew", "shore_leave", "away_missions", "shipyard"]:
		var btn := Button.new()
		btn.text = tab_name.replace("_", " ").to_upper()
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_show_tab.bind(tab_name))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# ── Separator ────────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", _ACCENT.darkened(0.4))
	vbox.add_child(sep)

	# ── Content area (swapped per tab) ───────────────────────────────────────
	_content_area = VBoxContainer.new()
	_content_area.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(_content_area)

	# ── Bottom bar ───────────────────────────────────────────────────────────
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator", _ACCENT.darkened(0.4))
	vbox.add_child(sep2)

	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)
	bottom.add_child(_spacer())

	var btn_close := Button.new()
	btn_close.text = "CLOSE"
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.add_theme_color_override("font_color", _GREEN)
	btn_close.custom_minimum_size = Vector2(140, 36)
	btn_close.pressed.connect(_on_depart)
	bottom.add_child(btn_close)


func _show_tab(tab_name: String) -> void:
	_current_tab = tab_name
	# Clear content
	for child in _content_area.get_children():
		child.queue_free()
	# Highlight active tab
	for i in _tab_buttons.size():
		var names := ["summary", "repair", "crew", "shore_leave", "away_missions", "shipyard"]
		_tab_buttons[i].add_theme_color_override("font_color",
			_ACCENT if names[i] == tab_name else _DIM)
	# Build tab content
	match tab_name:
		"summary":     _build_summary()
		"repair":      _build_repair()
		"crew":        _build_crew()
		"shore_leave":    _build_shore_leave()
		"away_missions":  _build_away_missions()
		"shipyard":       _build_shipyard()


# ══════════════════════════════════════════════════════════════════════════════
# TAB: SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
func _build_summary() -> void:
	var vb := _content_area as VBoxContainer
	var earned: int = _result.get("earned", 0)
	var days: int   = _result.get("days", 0)
	var dest: String = _result.get("destination", "Unknown")

	vb.add_child(_lbl("ARRIVAL SUMMARY", 14, _ACCENT))
	vb.add_child(_lbl("Destination: %s" % dest, 12, _TEXT))
	vb.add_child(_lbl("Journey: %d days" % days, 12, _TEXT))
	vb.add_child(_lbl(""))

	vb.add_child(_lbl("Gross earnings: +%d cr" % earned, 12, _GREEN))
	if _wages > 0:
		vb.add_child(_lbl("Crew wages (%d crew x %d days x %d cr/day): -%d cr" % [
			_crew.size(), days, CrewData.WAGE_PER_DAY, _wages], 12, _RED))
	vb.add_child(_lbl("Net income: %s%d cr" % [
		"+" if earned - _wages >= 0 else "", earned - _wages], 12,
		_GOLD if earned - _wages >= 0 else _RED))

	# Travel log
	vb.add_child(_lbl(""))
	vb.add_child(_lbl("TRAVEL LOG", 12, _ACCENT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 140
	vb.add_child(scroll)

	var log_lbl := RichTextLabel.new()
	log_lbl.bbcode_enabled = true
	log_lbl.fit_content = true
	log_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	log_lbl.add_theme_font_size_override("normal_font_size", 10)
	log_lbl.add_theme_color_override("default_color", _DIM)
	scroll.add_child(log_lbl)

	var lines: Array = _result.get("log_lines", [])
	for line in lines:
		log_lbl.append_text(str(line) + "\n")


# ══════════════════════════════════════════════════════════════════════════════
# TAB: REPAIR
# ══════════════════════════════════════════════════════════════════════════════
func _build_repair() -> void:
	var vb := _content_area as VBoxContainer
	vb.add_child(_lbl("REPAIR SERVICES", 14, _ACCENT))
	vb.add_child(_lbl("Cost scales with damage and room value", 10, _DIM))
	vb.add_child(_lbl(""))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)

	var total_repair_cost := 0
	var damaged_count := 0
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if sn.current_durability >= sn.max_durability: continue
		damaged_count += 1

		var cost := _repair_cost(sn, def)
		total_repair_cost += cost

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var pct := float(sn.current_durability) / float(sn.max_durability)
		var dur_col := _GREEN if pct > 0.6 else (_GOLD if pct > 0.3 else _RED)
		row.add_child(_lbl("%s" % def.get("name", "Room"), 11, _TEXT))
		row.add_child(_lbl("%d/%d" % [sn.current_durability, sn.max_durability], 11, dur_col))
		row.add_child(_spacer())

		var btn := Button.new()
		btn.text = "Repair (%d cr)" % cost
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_repair_room.bind(sn, def))
		row.add_child(btn)

	if damaged_count == 0:
		list.add_child(_lbl("All rooms in good condition!", 12, _GREEN))
	else:
		# Repair all button
		vb.add_child(_lbl(""))
		var btn_all := Button.new()
		btn_all.text = "REPAIR ALL (%d cr)" % total_repair_cost
		btn_all.add_theme_font_size_override("font_size", 12)
		btn_all.add_theme_color_override("font_color", _GREEN)
		btn_all.pressed.connect(_repair_all)
		vb.add_child(btn_all)


static func _repair_cost(sn: ShipNode, def: Dictionary) -> int:
	## Cost scales with damage points lost and room cost tier.
	var damage: int = sn.max_durability - sn.current_durability
	if damage <= 0:
		return 0
	# Rate per durability point: base 0.5 cr + scales with room cost
	var room_cost: int = def.get("cost", 100)
	var rate: float = 0.5 + float(room_cost) / 500.0
	return maxi(5, roundi(float(damage) * rate))


func _repair_room(sn: ShipNode, def: Dictionary) -> void:
	var cost := _repair_cost(sn, def)
	if _credits < cost:
		return
	_credits -= cost
	sn.repair_full(def)
	_refresh_credits()
	_show_tab("repair")


func _repair_all() -> void:
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if sn.current_durability < sn.max_durability:
			var cost := _repair_cost(sn, def)
			if _credits >= cost:
				_credits -= cost
				sn.repair_full(def)
	_refresh_credits()
	_show_tab("repair")


# ══════════════════════════════════════════════════════════════════════════════
# TAB: CREW
# ══════════════════════════════════════════════════════════════════════════════
func _build_crew() -> void:
	var vb := _content_area as VBoxContainer

	# ── Your Crew section ────────────────────────────────────────────────────
	vb.add_child(_lbl("YOUR CREW (%d)" % _crew.size(), 14, _ACCENT))

	var crew_scroll := ScrollContainer.new()
	crew_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	crew_scroll.custom_minimum_size.y = 160
	vb.add_child(crew_scroll)
	var crew_list := VBoxContainer.new()
	crew_list.size_flags_horizontal = SIZE_EXPAND_FILL
	crew_list.add_theme_constant_override("separation", 4)
	crew_scroll.add_child(crew_list)

	if _crew.is_empty():
		crew_list.add_child(_lbl("No crew yet. Hire some below!", 11, _DIM))
	else:
		for cm in _crew:
			crew_list.add_child(_crew_row(cm, true))

	# ── Hire section ─────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", _ACCENT.darkened(0.4))
	vb.add_child(sep)
	vb.add_child(_lbl("AVAILABLE FOR HIRE", 13, _ACCENT))

	if _hire_pool.is_empty():
		vb.add_child(_lbl("No one available at this port.", 11, _DIM))
	else:
		var hire_scroll := ScrollContainer.new()
		hire_scroll.size_flags_vertical = SIZE_EXPAND_FILL
		hire_scroll.custom_minimum_size.y = 120
		vb.add_child(hire_scroll)
		var hire_list := VBoxContainer.new()
		hire_list.size_flags_horizontal = SIZE_EXPAND_FILL
		hire_list.add_theme_constant_override("separation", 4)
		hire_scroll.add_child(hire_list)

		for cm in _hire_pool:
			hire_list.add_child(_crew_row(cm, false))


func _crew_row(cm: Dictionary, is_owned: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 52

	# Portrait — clickable for stats popup
	var portrait_btn := Button.new()
	portrait_btn.custom_minimum_size = Vector2(48, 48)
	portrait_btn.flat = true
	portrait_btn.pressed.connect(_show_crew_stats.bind(cm))
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(48, 48)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path: String = cm.get("portrait", "")
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		tex_rect.texture = load(portrait_path)
	portrait_btn.add_child(tex_rect)
	row.add_child(portrait_btn)

	# Name + role
	var name_lbl := _lbl(cm.get("name", "Unknown"), 11, _TEXT)
	name_lbl.custom_minimum_size.x = 130
	row.add_child(name_lbl)

	var role_lbl := _lbl(cm.get("role", "?"), 10, _DIM)
	role_lbl.custom_minimum_size.x = 75
	row.add_child(role_lbl)

	# Efficiency
	var eff: float = cm.get("efficiency", 0.5)
	var eff_col := _GREEN if eff >= 0.7 else (_GOLD if eff >= 0.5 else _RED)
	var eff_lbl := _lbl("Eff: %d%%" % int(eff * 100), 10, eff_col)
	eff_lbl.custom_minimum_size.x = 60
	row.add_child(eff_lbl)

	if is_owned:
		# Assignment info
		var assigned: String = cm.get("assigned_to", "")
		var status: String = cm.get("status", "active")
		if status == "shore_leave":
			row.add_child(_lbl("ON LEAVE", 10, _GOLD))
		elif status == "on_mission":
			row.add_child(_lbl("ON MISSION", 10, _PURPLE))
		elif status == "arrested":
			row.add_child(_lbl("ARRESTED", 10, _RED))
		elif assigned.is_empty():
			row.add_child(_lbl("Unassigned", 10, _DIM))

			# Assign button
			var btn := Button.new()
			btn.text = "Assign..."
			btn.add_theme_font_size_override("font_size", 10)
			btn.pressed.connect(_show_assign_dialog.bind(cm))
			row.add_child(btn)
		else:
			# Find the room name
			var room_name := assigned
			for node in _ship_nodes:
				var sn := node as ShipNode
				if sn != null and sn.node_uid == assigned:
					var def := RoomData.find(sn.def_id)
					room_name = def.get("name", assigned) if not def.is_empty() else assigned
					break
			row.add_child(_lbl("-> %s" % room_name, 10, _GREEN))

			var btn_un := Button.new()
			btn_un.text = "Unassign"
			btn_un.add_theme_font_size_override("font_size", 10)
			btn_un.pressed.connect(_unassign_crew.bind(cm))
			row.add_child(btn_un)

		# Dismiss button (available for all owned crew in any status)
		var btn_dismiss := Button.new()
		btn_dismiss.text = "Dismiss"
		btn_dismiss.add_theme_font_size_override("font_size", 10)
		btn_dismiss.add_theme_color_override("font_color", _RED)
		btn_dismiss.pressed.connect(_dismiss_crew.bind(cm))
		row.add_child(btn_dismiss)
	else:
		# Hire button
		row.add_child(_spacer())
		var cost := CrewData.hire_cost(cm)
		var btn := Button.new()
		btn.text = "Hire (%d cr)" % cost
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", _GREEN)
		btn.pressed.connect(_hire_crew.bind(cm))
		row.add_child(btn)

	return row


func _hire_crew(cm: Dictionary) -> void:
	var cost := CrewData.hire_cost(cm)
	if _credits < cost:
		return
	_credits -= cost
	_crew_counter += 1
	cm.id = "crew_%d" % _crew_counter
	_crew.append(cm)
	_hire_pool.erase(cm)
	_refresh_credits()
	_show_tab("crew")


func _unassign_crew(cm: Dictionary) -> void:
	cm.assigned_to = ""
	_show_tab("crew")


func _dismiss_crew(cm: Dictionary) -> void:
	var severance: int = randi_range(1, 7) * CrewData.WAGE_PER_DAY
	var crew_name: String = cm.get("name", "Crew")
	_credits -= severance
	if _credits < 0:
		_credits = 0
	_crew.erase(cm)
	_refresh_credits()
	_show_tab("crew")

	# Brief toast-style popup
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style.border_color = _RED
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 60

	var lbl := _lbl("%s dismissed. Severance: %d cr" % [crew_name, severance], 12, _TEXT)
	popup.add_child(lbl)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(PRESET_CENTER)
	popup.offset_left = -160
	popup.offset_right = 160
	popup.offset_top = -20
	popup.offset_bottom = 20

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.tween_callback(popup.queue_free)


func _show_assign_dialog(cm: Dictionary) -> void:
	## Show a simple popup to pick a room matching this crew's role.
	var role: String = cm.get("role", "Specialist")
	var target_type: String = CrewData.room_type_for_role(role)

	# Find matching rooms
	var options: Array = []
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if def.get("type", "") == target_type:
			# Check if already occupied
			var occupied := false
			for other in _crew:
				if other.get("assigned_to", "") == sn.node_uid and other.get("id", "") != cm.get("id", ""):
					occupied = true
					break
			if not occupied:
				options.append({"uid": sn.node_uid, "name": def.get("name", sn.node_uid)})

	if options.is_empty():
		# No matching rooms — try assigning to any room
		for node in _ship_nodes:
			var sn := node as ShipNode
			if sn == null: continue
			var def := RoomData.find(sn.def_id)
			if def.is_empty(): continue
			var occupied := false
			for other in _crew:
				if other.get("assigned_to", "") == sn.node_uid and other.get("id", "") != cm.get("id", ""):
					occupied = true
					break
			if not occupied:
				options.append({"uid": sn.node_uid, "name": def.get("name", sn.node_uid)})

	if options.is_empty():
		return

	# Create simple popup
	var popup := PopupMenu.new()
	popup.add_theme_font_size_override("font_size", 11)
	for i in options.size():
		var opt: Dictionary = options[i]
		var label: String = opt.name
		if options[i].get("uid", "") in _get_matching_room_uids(target_type):
			label += " (matched)"
		popup.add_item(label, i)

	add_child(popup)
	popup.id_pressed.connect(func(id: int) -> void:
		cm.assigned_to = options[id].uid
		popup.queue_free()
		_show_tab("crew"))
	popup.popup_centered(Vector2i(220, 0))


func _get_matching_room_uids(room_type: String) -> Array:
	var uids: Array = []
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if not def.is_empty() and def.get("type", "") == room_type:
			uids.append(sn.node_uid)
	return uids


# ══════════════════════════════════════════════════════════════════════════════
# TAB: SHORE LEAVE
# ══════════════════════════════════════════════════════════════════════════════
func _build_shore_leave() -> void:
	var vb := _content_area as VBoxContainer
	vb.add_child(_lbl("SHORE LEAVE", 14, _ACCENT))
	vb.add_child(_lbl("Send crew planetside. They may return with loot... or trouble.", 10, _DIM))
	vb.add_child(_lbl("Cost: %d cr per crew per day" % CrewData.SHORE_LEAVE_COST_PER_DAY, 10, _DIM))
	vb.add_child(_lbl(""))

	# Show who's currently on leave
	var on_leave: Array = []
	var max_days := 0
	for cm in _crew:
		if cm.get("status", "") == "shore_leave":
			on_leave.append(cm)
			var d: int = cm.get("shore_leave_days", 0)
			if d > max_days:
				max_days = d

	if not on_leave.is_empty():
		vb.add_child(_lbl("ON LEAVE (%d crew, %d days remaining)" % [on_leave.size(), max_days], 12, _GOLD))
		for cm in on_leave:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			vb.add_child(row)
			row.add_child(_lbl(cm.get("name", "?"), 11, _TEXT))
			row.add_child(_lbl(cm.get("role", "?"), 10, _DIM))
			row.add_child(_lbl("%d days left" % cm.get("shore_leave_days", 0), 10, _GOLD))

		vb.add_child(_lbl(""))
		# Wait button — advances time, resolves all shore leave
		var btn_wait := Button.new()
		btn_wait.text = "WAIT FOR SHORE LEAVE (%d days)" % max_days
		btn_wait.add_theme_font_size_override("font_size", 12)
		btn_wait.add_theme_color_override("font_color", _ACCENT)
		btn_wait.custom_minimum_size = Vector2(0, 32)
		btn_wait.pressed.connect(_wait_for_shore_leave)
		vb.add_child(btn_wait)

		vb.add_child(_lbl("NOTE: Departing while crew are on leave will abandon them!", 10, _RED))
		vb.add_child(_lbl(""))

	# Send active crew on leave
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var active_crew: Array = []
	for cm in _crew:
		if cm.get("status", "active") == "active":
			active_crew.append(cm)

	if active_crew.is_empty() and on_leave.is_empty():
		list.add_child(_lbl("No crew available.", 11, _DIM))
	elif not active_crew.is_empty():
		list.add_child(_lbl("SEND ON LEAVE", 12, _ACCENT))
		for cm in active_crew:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)

			row.add_child(_lbl(cm.get("name", "?"), 11, _TEXT))
			row.add_child(_lbl(cm.get("role", "?"), 10, _DIM))
			row.add_child(_spacer())

			for days in [1, 2, 3]:
				var cost : int = CrewData.SHORE_LEAVE_COST_PER_DAY * days
				var btn := Button.new()
				btn.text = "%dd (%d cr)" % [days, cost]
				btn.add_theme_font_size_override("font_size", 10)
				btn.pressed.connect(_send_on_leave.bind(cm, days))
				row.add_child(btn)


func _send_on_leave(cm: Dictionary, days: int) -> void:
	var cost := CrewData.SHORE_LEAVE_COST_PER_DAY * days
	if _credits < cost:
		return
	_credits -= cost
	cm.status = "shore_leave"
	cm.shore_leave_days = days
	cm.assigned_to = ""   # unassign while on leave
	_refresh_credits()
	_show_tab("shore_leave")


func _wait_for_shore_leave() -> void:
	## Wait for all crew on shore leave to return, then resolve outcomes.
	var results: Array = []
	var waited := 0
	for cm in _crew:
		if cm.get("status", "") == "shore_leave":
			var d: int = cm.get("shore_leave_days", 0)
			if d > waited:
				waited = d

	for cm in _crew.duplicate():
		if cm.get("status", "") == "shore_leave":
			cm.shore_leave_days = 0
			var outcome := _resolve_shore_leave(cm)
			results.append(outcome)
			if cm.get("status", "") != "arrested":
				cm.status = "active"

	# Show results in the shore leave tab
	_show_tab("shore_leave")

	# Display results as a popup
	if not results.is_empty():
		var popup := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
		style.border_color = _GOLD
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(16)
		popup.add_theme_stylebox_override("panel", style)
		popup.z_index = 60

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		popup.add_child(vb)

		vb.add_child(_lbl("SHORE LEAVE RESULTS (%d days passed)" % waited, 14, _GOLD))
		vb.add_child(_lbl(""))
		for msg in results:
			vb.add_child(_lbl(msg, 11, _TEXT))
		vb.add_child(_lbl(""))

		var btn_ok := Button.new()
		btn_ok.text = "OK"
		btn_ok.add_theme_font_size_override("font_size", 12)
		btn_ok.custom_minimum_size = Vector2(80, 28)
		btn_ok.pressed.connect(func() -> void:
			popup.queue_free()
			_show_tab("shore_leave"))
		vb.add_child(btn_ok)

		add_child(popup)
		popup.set_anchors_and_offsets_preset(PRESET_CENTER)
		popup.offset_left = -200
		popup.offset_right = 200
		popup.offset_top = -120
		popup.offset_bottom = 120

	_refresh_credits()


func _resolve_shore_leave(cm: Dictionary) -> String:
	var roll := randi() % 100
	var crew_name: String = cm.get("name", "Crew")

	if roll < 50:
		# Normal return
		return "%s returned from leave — rested and ready." % crew_name
	elif roll < 70:
		# Found loot
		var loot := 50 + randi() % 151
		_credits += loot
		return "%s found valuable salvage on leave! +%d cr" % [crew_name, loot]
	elif roll < 85:
		# Found a recruit
		_crew_counter += 1
		var recruit := CrewData.generate_crew("", _crew_counter)
		_crew.append(recruit)
		return "%s brought back a recruit: %s (%s)" % [crew_name, recruit.name, recruit.role]
	elif roll < 95:
		# Arrested
		cm.status = "arrested"
		return "%s was ARRESTED! Pay bail at next port or lose them." % crew_name
	else:
		# Efficiency boost
		var boost := randf_range(0.05, 0.10)
		cm.efficiency = minf(cm.get("efficiency", 0.5) + boost, 1.0)
		return "%s had a great time! Efficiency increased to %d%%." % [
			crew_name, int(cm.efficiency * 100)]


# ══════════════════════════════════════════════════════════════════════════════
# TAB: AWAY MISSIONS
# ══════════════════════════════════════════════════════════════════════════════

const _AWAY_DANGER_COLORS: Dictionary = {
	"safe":      Color(0.40, 0.80, 0.50, 1.0),
	"moderate":  Color(0.90, 0.80, 0.30, 1.0),
	"dangerous": Color(0.90, 0.50, 0.20, 1.0),
	"extreme":   Color(0.95, 0.25, 0.20, 1.0),
}

const _AWAY_MISSION_DEFS: Array = [
	{ "name": "Reactor Calibration",    "desc": "Recalibrate the local power grid.",                     "role": "Engineer",   "danger": "safe",      "party": 2 },
	{ "name": "Cargo Inspection",       "desc": "Audit a warehouse for contraband.",                     "role": "Officer",    "danger": "safe",      "party": 2 },
	{ "name": "Medical Aid",            "desc": "Provide emergency medical assistance planetside.",      "role": "Specialist", "danger": "safe",      "party": 2 },
	{ "name": "System Repairs",         "desc": "Fix a malfunctioning station subsystem.",               "role": "Engineer",   "danger": "safe",      "party": 3 },
	{ "name": "Security Patrol",        "desc": "Assist local security with a routine sweep.",           "role": "Security",   "danger": "moderate",  "party": 3 },
	{ "name": "Diplomatic Escort",      "desc": "Escort a diplomat through contested territory.",        "role": "Officer",    "danger": "moderate",  "party": 3 },
	{ "name": "Mining Survey",          "desc": "Survey unstable asteroid tunnels for mineral deposits.","role": "Engineer",   "danger": "moderate",  "party": 2 },
	{ "name": "Data Recovery",          "desc": "Retrieve encrypted data from a damaged outpost.",       "role": "Specialist", "danger": "moderate",  "party": 2 },
	{ "name": "Pirate Holdout Raid",    "desc": "Clear a pirate hideout in the lower decks.",            "role": "Security",   "danger": "dangerous", "party": 3 },
	{ "name": "Rescue Operation",       "desc": "Extract survivors from a collapsed structure.",         "role": "Engineer",   "danger": "dangerous", "party": 3 },
	{ "name": "Hostage Negotiation",    "desc": "Negotiate release of hostages from insurgents.",        "role": "Officer",    "danger": "dangerous", "party": 4 },
	{ "name": "Artifact Retrieval",     "desc": "Recover a valuable artifact from hostile territory.",   "role": "Specialist", "danger": "dangerous", "party": 3 },
	{ "name": "Black Market Deal",      "desc": "Handle a high-value exchange in lawless territory.",    "role": "Officer",    "danger": "extreme",   "party": 3 },
	{ "name": "Warlord Takedown",       "desc": "Eliminate a local warlord destabilizing the sector.",   "role": "Security",   "danger": "extreme",   "party": 4 },
	{ "name": "Reactor Meltdown",       "desc": "Prevent a cascading reactor failure. No margin for error.", "role": "Engineer", "danger": "extreme", "party": 3 },
	{ "name": "Deep Recon",             "desc": "Infiltrate a fortified compound for intel.",            "role": "Security",   "danger": "extreme",   "party": 4 },
]

const _AWAY_PAY_RANGES: Dictionary = {
	"safe":      { "min": 30, "max": 60 },
	"moderate":  { "min": 60, "max": 120 },
	"dangerous": { "min": 120, "max": 220 },
	"extreme":   { "min": 220, "max": 400 },
}

const _AWAY_CREW_DAILY_COST: int = 12  # cost per crew per day on mission


func _generate_away_missions() -> Array:
	var pool := _AWAY_MISSION_DEFS.duplicate()
	pool.shuffle()
	var count := randi_range(2, mini(4, pool.size()))
	var missions: Array = []
	for i in count:
		var def: Dictionary = pool[i]
		var duration := randi_range(1, 4)
		var pay_range: Dictionary = _AWAY_PAY_RANGES[def.danger]
		var pay_per_day := randi_range(pay_range.min, pay_range.max)
		# Longer missions pay a small daily premium
		if duration >= 3:
			pay_per_day += 15
		missions.append({
			"name":         def.name,
			"desc":         def.desc,
			"required_role": def.role,
			"danger":       def.danger,
			"party_size":   def.party,
			"duration":     duration,
			"pay_per_day":  pay_per_day,
			"total_pay":    pay_per_day * duration,
			"crew_cost":    _AWAY_CREW_DAILY_COST * def.party * duration,
		})
	# Sort safe → extreme
	var danger_order := { "safe": 0, "moderate": 1, "dangerous": 2, "extreme": 3 }
	missions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return danger_order.get(a.danger, 0) < danger_order.get(b.danger, 0))
	return missions


func _build_away_missions() -> void:
	var vb := _content_area as VBoxContainer

	var sys := StarMapData.find_system(_current_system)
	var loc_name: String = sys.get("name", "Unknown") if not sys.is_empty() else "Unknown"
	vb.add_child(_lbl("AWAY MISSIONS — %s" % loc_name, 14, _ACCENT))
	vb.add_child(_lbl("Send a crew party planetside for local contracts.", 10, _DIM))
	vb.add_child(_lbl(""))

	# ── Active mission status ────────────────────────────────────────────────
	if not _active_mission.is_empty():
		_build_active_mission_panel(vb)
		return

	# ── Available missions ───────────────────────────────────────────────────
	if _away_missions.is_empty():
		vb.add_child(_lbl("No contracts available at this port.", 12, _DIM))
		return

	var available_crew := _get_available_crew()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for mission in _away_missions:
		list.add_child(_build_mission_card(mission, available_crew))


func _build_active_mission_panel(vb: VBoxContainer) -> void:
	var m := _active_mission
	var danger_col: Color = _AWAY_DANGER_COLORS.get(m.danger, _TEXT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.15, 1.0)
	style.border_color = danger_col.darkened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	vb.add_child(panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	panel.add_child(pv)

	pv.add_child(_lbl("ACTIVE MISSION: %s" % m.name, 13, danger_col))
	pv.add_child(_lbl(m.desc, 10, _DIM))
	pv.add_child(_lbl("Danger: %s  |  Duration: %d days  |  Pay: %d cr" % [
		m.danger.to_upper(), m.duration, m.total_pay], 11, _TEXT))

	# Show party members
	pv.add_child(_lbl(""))
	pv.add_child(_lbl("AWAY TEAM:", 11, _ACCENT))
	for cm in _mission_party:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		pv.add_child(row)

		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(32, 32)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var pp: String = cm.get("portrait", "")
		if not pp.is_empty() and ResourceLoader.exists(pp):
			tex.texture = load(pp)
		row.add_child(tex)
		row.add_child(_lbl(cm.get("name", "?"), 11, _TEXT))
		row.add_child(_lbl(cm.get("role", "?"), 10, _DIM))

	pv.add_child(_lbl(""))

	# Wait button
	var btn_wait := Button.new()
	btn_wait.text = "WAIT FOR MISSION COMPLETION (%d days)" % m.duration
	btn_wait.add_theme_font_size_override("font_size", 13)
	btn_wait.add_theme_color_override("font_color", _ACCENT)
	btn_wait.custom_minimum_size = Vector2(0, 36)
	btn_wait.pressed.connect(_resolve_away_mission)
	pv.add_child(btn_wait)

	vb.add_child(_lbl(""))
	vb.add_child(_lbl("Departing with an active mission will abandon the away team!", 10, _RED))


func _build_mission_card(mission: Dictionary, available_crew: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var danger_col: Color = _AWAY_DANGER_COLORS.get(mission.danger, _TEXT)
	style.bg_color = Color(0.06, 0.09, 0.15, 1.0)
	style.border_color = danger_col.darkened(0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)

	# Left: mission info
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	hb.add_child(info)

	# Title + danger badge
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_lbl(mission.name, 12, _TEXT))
	title_row.add_child(_lbl("[%s]" % mission.danger.to_upper(), 10, danger_col))

	# Description
	var desc_lbl := _lbl(mission.desc, 10, _DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	# Stats
	var crew_cost: int = mission.crew_cost
	var net_pay: int = mission.total_pay - crew_cost
	var stats := "%d days  |  Pay: %d cr  |  Crew cost: %d cr  |  Net: %s%d cr" % [
		mission.duration, mission.total_pay, crew_cost,
		"+" if net_pay >= 0 else "", net_pay]
	var stats_col := _GREEN if net_pay > 0 else (_GOLD if net_pay == 0 else _RED)
	info.add_child(_lbl(stats, 10, stats_col))

	# Requirements
	var req_text := "Requires: %s + %d crew" % [mission.required_role, mission.party_size]
	info.add_child(_lbl(req_text, 10, _ACCENT))

	# Check eligibility
	var has_role := false
	var active_count := 0
	for cm in available_crew:
		if cm.get("status", "active") == "active":
			active_count += 1
			if cm.get("role", "") == mission.required_role:
				has_role = true

	var can_send := true

	# Banners
	if not has_role:
		var banner := _lbl("MISSING REQUIRED: %s" % mission.required_role, 10, _RED)
		info.add_child(banner)
		can_send = false

	if active_count < mission.party_size:
		var banner := _lbl("NOT ENOUGH CREW (need %d, have %d active)" % [
			mission.party_size, active_count], 10, _RED)
		info.add_child(banner)
		can_send = false

	# Right: Send button
	var btn_col := VBoxContainer.new()
	btn_col.size_flags_vertical = SIZE_SHRINK_CENTER
	hb.add_child(btn_col)

	var btn := Button.new()
	btn.text = "Send Team"
	btn.custom_minimum_size = Vector2(90, 32)
	btn.add_theme_font_size_override("font_size", 11)
	if can_send:
		btn.add_theme_color_override("font_color", _GREEN)
		btn.pressed.connect(_show_party_select.bind(mission))
	else:
		btn.disabled = true
	btn_col.add_child(btn)

	return card


func _get_available_crew() -> Array:
	var result: Array = []
	for cm in _crew:
		if cm.get("status", "active") == "active":
			result.append(cm)
	return result


func _show_party_select(mission: Dictionary) -> void:
	## Popup to pick crew for the away team.
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.border_color = _ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 60

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	popup.add_child(vb)

	var danger_col: Color = _AWAY_DANGER_COLORS.get(mission.danger, _TEXT)
	vb.add_child(_lbl("SELECT AWAY TEAM — %s" % mission.name, 14, danger_col))
	vb.add_child(_lbl("Required: %s  |  Party size: %d" % [mission.required_role, mission.party_size], 11, _ACCENT))
	vb.add_child(_lbl(""))

	var selected: Array = []
	var checkboxes: Array = []  # parallel with available_crew
	var available := _get_available_crew()

	# Sort so the required role appears first
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_match := 1 if a.get("role", "") == mission.required_role else 0
		var b_match := 1 if b.get("role", "") == mission.required_role else 0
		return a_match > b_match)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 200
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var crew_list := VBoxContainer.new()
	crew_list.size_flags_horizontal = SIZE_EXPAND_FILL
	crew_list.add_theme_constant_override("separation", 4)
	scroll.add_child(crew_list)

	var lbl_status := _lbl("Selected: 0 / %d" % mission.party_size, 12, _GOLD)
	var btn_confirm := Button.new()

	for cm in available:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 36
		crew_list.add_child(row)

		var cb := CheckBox.new()
		row.add_child(cb)
		checkboxes.append(cb)

		# Portrait mini
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(32, 32)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var pp: String = cm.get("portrait", "")
		if not pp.is_empty() and ResourceLoader.exists(pp):
			tex.texture = load(pp)
		row.add_child(tex)

		var nm := _lbl(cm.get("name", "?"), 11, _TEXT)
		nm.custom_minimum_size.x = 120
		row.add_child(nm)

		var role_col := _ACCENT if cm.get("role", "") == mission.required_role else _DIM
		var role_suffix := " (req)" if cm.get("role", "") == mission.required_role else ""
		row.add_child(_lbl(cm.get("role", "?") + role_suffix, 10, role_col))

		var eff: float = cm.get("efficiency", 0.5)
		var eff_col := _GREEN if eff >= 0.7 else (_GOLD if eff >= 0.5 else _RED)
		row.add_child(_lbl("Eff: %d%%" % int(eff * 100), 10, eff_col))

		# Closure over cm
		var crew_ref: Dictionary = cm
		cb.toggled.connect(func(pressed: bool) -> void:
			if pressed and not selected.has(crew_ref):
				selected.append(crew_ref)
			elif not pressed and selected.has(crew_ref):
				selected.erase(crew_ref)
			lbl_status.text = "Selected: %d / %d" % [selected.size(), mission.party_size]
			# Enable confirm only when exactly party_size selected and has required role
			var has_req := false
			for sel in selected:
				if sel.get("role", "") == mission.required_role:
					has_req = true
					break
			btn_confirm.disabled = selected.size() != mission.party_size or not has_req
		)

	vb.add_child(lbl_status)
	vb.add_child(_lbl(""))

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)

	btn_confirm.text = "Deploy Away Team"
	btn_confirm.add_theme_font_size_override("font_size", 12)
	btn_confirm.add_theme_color_override("font_color", _GREEN)
	btn_confirm.custom_minimum_size = Vector2(160, 32)
	btn_confirm.disabled = true
	btn_confirm.pressed.connect(func() -> void:
		popup.queue_free()
		_deploy_away_team(mission, selected))
	btn_row.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.add_theme_font_size_override("font_size", 12)
	btn_cancel.custom_minimum_size = Vector2(80, 32)
	btn_cancel.pressed.connect(func() -> void: popup.queue_free())
	btn_row.add_child(btn_cancel)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(PRESET_CENTER)
	popup.offset_left  = -240
	popup.offset_right =  240
	popup.offset_top   = -200
	popup.offset_bottom = 200


func _deploy_away_team(mission: Dictionary, party: Array) -> void:
	# Pay upfront
	_credits += mission.total_pay
	# Deduct crew costs upfront
	_credits -= mission.crew_cost

	_active_mission = mission
	_mission_party = party

	# Set crew status
	for cm in party:
		cm.status = "on_mission"
		cm.assigned_to = ""

	_refresh_credits()
	_show_tab("away_missions")


func _resolve_away_mission() -> void:
	## Resolve the active mission — outcomes per crew member based on danger.
	var mission := _active_mission
	var danger: String = mission.get("danger", "safe")
	var results: Array = []  # Array of { crew, outcome, text, lost }
	var reporter: Dictionary = {}  # crew member who gives the debrief
	var party := _mission_party.duplicate()

	# Average team efficiency affects success odds
	var avg_eff := 0.0
	for cm in party:
		avg_eff += cm.get("efficiency", 0.5)
	avg_eff /= maxf(party.size(), 1.0)
	# Efficiency bonus: high efficiency shifts outcomes toward success (+0 to +15)
	var eff_bonus: int = roundi((avg_eff - 0.5) * 30.0)

	for cm in party:
		var roll: int = randi() % 100 + eff_bonus
		var outcome := _roll_mission_outcome(cm, danger, roll)
		results.append(outcome)

	# Pick a surviving crew member as reporter
	for r in results:
		if not r.lost:
			reporter = r.crew
			break
	# If everyone is lost, use the first one's data for the portrait anyway
	if reporter.is_empty() and not results.is_empty():
		reporter = results[0].crew

	# Apply outcomes
	for r in results:
		if r.lost:
			_crew.erase(r.crew)
		else:
			r.crew.status = "active"

	_active_mission = {}
	_mission_party = []

	_refresh_credits()
	_show_tab("away_missions")

	# Show debrief popup
	_show_mission_debrief(mission, results, reporter)


func _roll_mission_outcome(cm: Dictionary, danger: String, roll: int) -> Dictionary:
	## Roll outcome for a single crew member.  Higher roll = better.
	var crew_name: String = cm.get("name", "Crew")
	var result := { "crew": cm, "lost": false, "text": "" }

	# Thresholds shift with danger (lower = more dangerous)
	var death_thresh := 0
	var lost_thresh  := 0   # AWOL / captured / kidnapped
	var injury_thresh := 0
	var bonus_thresh := 0

	match danger:
		"safe":
			death_thresh  = -10  # essentially impossible
			lost_thresh   = -5
			injury_thresh = 5
			bonus_thresh  = 75
		"moderate":
			death_thresh  = 3
			lost_thresh   = 10
			injury_thresh = 25
			bonus_thresh  = 70
		"dangerous":
			death_thresh  = 10
			lost_thresh   = 22
			injury_thresh = 40
			bonus_thresh  = 65
		"extreme":
			death_thresh  = 20
			lost_thresh   = 38
			injury_thresh = 55
			bonus_thresh  = 65

	if roll < death_thresh:
		# Killed in action
		result.lost = true
		var causes := ["killed in a firefight", "caught in an explosion",
			"fatally wounded during extraction", "lost to hostile fire"]
		result.text = "%s was %s." % [crew_name, causes[randi() % causes.size()]]
	elif roll < lost_thresh:
		# AWOL / captured / kidnapped
		result.lost = true
		var causes := ["went AWOL and never returned", "was captured by hostiles",
			"was kidnapped during the operation", "disappeared without a trace",
			"defected to a local faction"]
		result.text = "%s %s." % [crew_name, causes[randi() % causes.size()]]
	elif roll < injury_thresh:
		# Injured — efficiency drops
		var loss := randf_range(0.05, 0.15)
		cm.efficiency = maxf(0.15, cm.get("efficiency", 0.5) - loss)
		result.text = "%s was injured. Efficiency dropped to %d%%." % [
			crew_name, int(cm.efficiency * 100)]
	elif roll >= bonus_thresh:
		# Exceptional performance — bonus loot or efficiency gain
		var bonus_roll := randi() % 100
		if bonus_roll < 50:
			var loot := randi_range(40, 200)
			_credits += loot
			result.text = "%s recovered valuable goods during the mission. +%d cr" % [crew_name, loot]
		elif bonus_roll < 80:
			var boost := randf_range(0.03, 0.08)
			cm.efficiency = minf(1.0, cm.get("efficiency", 0.5) + boost)
			result.text = "%s performed exceptionally. Efficiency now %d%%." % [
				crew_name, int(cm.efficiency * 100)]
		else:
			# Intel bonus — discovered something
			var finds := ["a stash of rare components (+120 cr)", "a hidden cache of credits (+80 cr)",
				"classified intel worth selling (+150 cr)", "a crate of medical supplies (+60 cr)"]
			var pick: String = finds[randi() % finds.size()]
			var val := 80
			if "+120" in pick: val = 120
			elif "+150" in pick: val = 150
			elif "+60" in pick: val = 60
			_credits += val
			result.text = "%s found %s" % [crew_name, pick]
	else:
		# Clean return
		var clean := ["completed the mission without incident.",
			"returned safely — mission accomplished.",
			"executed the objective and returned to ship.",
			"finished the job. No complications."]
		result.text = "%s %s" % [crew_name, clean[randi() % clean.size()]]

	return result


func _show_mission_debrief(mission: Dictionary, results: Array, reporter: Dictionary) -> void:
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	var danger_col: Color = _AWAY_DANGER_COLORS.get(mission.danger, _ACCENT)
	style.border_color = danger_col
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 65

	var outer_hb := HBoxContainer.new()
	outer_hb.add_theme_constant_override("separation", 16)
	popup.add_child(outer_hb)

	# Left: reporter portrait
	var portrait_vb := VBoxContainer.new()
	portrait_vb.add_theme_constant_override("separation", 4)
	outer_hb.add_child(portrait_vb)

	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(96, 96)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var pp: String = reporter.get("portrait", "")
	if not pp.is_empty() and ResourceLoader.exists(pp):
		tex.texture = load(pp)
	portrait_vb.add_child(tex)
	portrait_vb.add_child(_lbl(reporter.get("name", "Unknown"), 11, _TEXT))
	portrait_vb.add_child(_lbl("Reporting", 9, _DIM))

	# Right: debrief
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.size_flags_horizontal = SIZE_EXPAND_FILL
	outer_hb.add_child(vb)

	vb.add_child(_lbl("MISSION DEBRIEF", 15, danger_col))
	vb.add_child(_lbl(mission.name, 12, _TEXT))
	vb.add_child(_lbl(""))

	# Outcome lines
	var losses := 0
	for r in results:
		var col := _RED if r.lost else (_GOLD if "injured" in r.text.to_lower() or "dropped" in r.text.to_lower() else _TEXT)
		if r.lost:
			losses += 1
		var outcome_lbl := _lbl(r.text, 11, col)
		outcome_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(outcome_lbl)

	vb.add_child(_lbl(""))

	# Summary line
	if losses == 0:
		vb.add_child(_lbl("All crew returned safely.", 12, _GREEN))
	elif losses == results.size():
		vb.add_child(_lbl("The entire team was lost.", 12, _RED))
	else:
		vb.add_child(_lbl("%d crew member%s lost." % [losses, "s" if losses > 1 else ""], 12, _ORANGE))

	vb.add_child(_lbl(""))

	var btn_ok := Button.new()
	btn_ok.text = "Acknowledged"
	btn_ok.add_theme_font_size_override("font_size", 12)
	btn_ok.custom_minimum_size = Vector2(120, 32)
	btn_ok.pressed.connect(func() -> void:
		popup.queue_free()
		_show_tab("away_missions"))
	vb.add_child(btn_ok)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(PRESET_CENTER)
	popup.offset_left  = -260
	popup.offset_right =  260
	popup.offset_top   = -180
	popup.offset_bottom = 180


# ══════════════════════════════════════════════════════════════════════════════
# TAB: SHIPYARD — port parts dealer
# ══════════════════════════════════════════════════════════════════════════════

func _build_shipyard() -> void:
	var vb := _content_area as VBoxContainer

	var sys := StarMapData.find_system(_current_system)
	var sys_name: String = sys.get("name", "Unknown") if not sys.is_empty() else "Unknown"
	var sys_type: String = sys.get("type", "star") if not sys.is_empty() else "star"

	vb.add_child(_lbl("PARTS DEALER — %s" % sys_name, 14, _ACCENT))
	vb.add_child(_lbl("The local merchant has parts in stock. Not everything — you take what they've got.", 10, _DIM))
	vb.add_child(_lbl(""))

	# Generate port-specific inventory
	var inventory := _generate_port_inventory(sys_type)

	# Show inventory summary
	var type_counts: Dictionary = {}
	for room in inventory:
		var t: String = room.get("type", "?")
		type_counts[t] = type_counts.get(t, 0) + 1
	var summary_parts: Array = []
	for t in type_counts:
		summary_parts.append("%d %s" % [type_counts[t], t])
	vb.add_child(_lbl("In stock: %d parts (%s)" % [inventory.size(), ", ".join(summary_parts)], 11, _GOLD))
	vb.add_child(_lbl(""))

	# List some highlights
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	# Group by type
	var by_type: Dictionary = {}
	for room in inventory:
		var t: String = room.get("type", "Other")
		if not by_type.has(t):
			by_type[t] = []
		by_type[t].append(room)

	for rtype in ["Power", "Engines", "Command", "Tactical", "Utility"]:
		if not by_type.has(rtype):
			continue
		list.add_child(_lbl(rtype.to_upper(), 11, _ACCENT))
		for room in by_type[rtype]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)

			var pwr_str: String = ""
			var pwr_val: int = room.get("power", 0)
			if pwr_val > 0:
				pwr_str = "  [color=#4fdf8c]+%d PWR[/color]" % pwr_val
			elif pwr_val < 0:
				pwr_str = "  [color=#df6650]%d PWR[/color]" % pwr_val

			var name_lbl := RichTextLabel.new()
			name_lbl.bbcode_enabled = true
			name_lbl.fit_content = true
			name_lbl.scroll_active = false
			name_lbl.custom_minimum_size.x = 260
			name_lbl.add_theme_font_size_override("normal_font_size", 10)
			name_lbl.text = "[color=#c8d8ff]%s[/color]  [color=#7090b0]%s[/color]%s" % [
				room.name, room.universe, pwr_str]
			row.add_child(name_lbl)

			row.add_child(_spacer())
			row.add_child(_lbl("%d cr" % room.cost, 10,
				_GOLD if _credits >= room.cost else _RED))

		list.add_child(_lbl(""))

	# Visit shipyard button
	vb.add_child(_lbl(""))
	var btn := Button.new()
	btn.text = "OPEN SHIPYARD (%d parts available)" % inventory.size()
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", _GREEN)
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(func() -> void: visit_shipyard.emit(inventory))
	vb.add_child(btn)

	vb.add_child(_lbl("This will close the port menu so you can access your ship.", 9, _DIM))


func _generate_port_inventory(sys_type: String) -> Array:
	## Generate a random subset of rooms available at this port.
	## Different system types stock different amounts and leanings.
	var all_rooms: Array = RoomData.ROOMS.duplicate()
	all_rooms.shuffle()

	# Base stock size varies by system type
	var stock_size := 12
	match sys_type:
		"station": stock_size = randi_range(15, 22)  # trade stations have more
		"planet":  stock_size = randi_range(10, 18)
		"star":    stock_size = randi_range(8, 14)
		"nebula":  stock_size = randi_range(6, 10)    # remote, sparse
		"asteroid": stock_size = randi_range(8, 12)
		"black_hole": stock_size = randi_range(4, 8)  # barely anything

	stock_size = mini(stock_size, all_rooms.size())

	# Always try to include at least one of each essential type
	var inventory: Array = []
	var has_type: Dictionary = {}
	for essential in ["Power", "Engines", "Command"]:
		for room in all_rooms:
			if room.get("type", "") == essential and not inventory.has(room):
				inventory.append(room)
				has_type[essential] = true
				break

	# Fill remaining slots randomly
	for room in all_rooms:
		if inventory.size() >= stock_size:
			break
		if not inventory.has(room):
			inventory.append(room)

	# Sort by type then cost
	var type_order := { "Power": 0, "Engines": 1, "Command": 2, "Tactical": 3, "Utility": 4 }
	inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = type_order.get(a.get("type", ""), 5)
		var tb: int = type_order.get(b.get("type", ""), 5)
		if ta != tb:
			return ta < tb
		return a.get("cost", 0) < b.get("cost", 0))
	return inventory


# ══════════════════════════════════════════════════════════════════════════════
# PORT EVENTS — random encounters on arrival
# ══════════════════════════════════════════════════════════════════════════════

func _roll_port_event() -> void:
	## Pick and execute a random port event. Called once on arrival (~35% chance).
	var sys := StarMapData.find_system(_current_system)
	var sys_name: String = sys.get("name", "this port") if not sys.is_empty() else "this port"
	var sys_type: String = sys.get("type", "star") if not sys.is_empty() else "star"

	# Weighted event pool — some events need prerequisites
	var pool: Array = []

	# Always available
	pool.append({ "id": "merchant",     "weight": 20 })
	pool.append({ "id": "bar_rumor",    "weight": 15 })
	pool.append({ "id": "mysterious_package", "weight": 10 })

	# Need crew to have these
	if _crew.size() >= 1:
		pool.append({ "id": "stowaway",     "weight": 15 })
		pool.append({ "id": "bar_fight",    "weight": 12 })
		pool.append({ "id": "crew_bonding", "weight": 12 })

	if _crew.size() >= 2:
		pool.append({ "id": "old_friend",   "weight": 8 })

	# Station/planet specific
	if sys_type in ["station", "planet"]:
		pool.append({ "id": "customs_inspection", "weight": 10 })
		pool.append({ "id": "refugee",            "weight": 8 })

	# Dangerous areas
	if StarMapData.is_harsh(sys.get("id", "")):
		pool.append({ "id": "black_market_tip", "weight": 15 })
		pool.append({ "id": "hull_scrape",       "weight": 10 })

	# Weighted pick
	var total_weight := 0
	for e in pool:
		total_weight += e.weight
	var roll := randi() % total_weight
	var pick_id := "bar_rumor"
	var running := 0
	for e in pool:
		running += e.weight
		if roll < running:
			pick_id = e.id
			break

	_execute_port_event(pick_id, sys_name)


func _execute_port_event(event_id: String, sys_name: String) -> void:
	var title := ""
	var text := ""
	var icon := ""
	var color := _ACCENT
	var choices: Array = []  # { label, callback }

	match event_id:
		"stowaway":
			_crew_counter += 1
			var stowaway := CrewData.generate_crew("", _crew_counter)
			stowaway.efficiency = snappedf(randf_range(0.25, 0.55), 0.01)
			icon  = "👤"
			title = "STOWAWAY FOUND"
			text  = "Security found %s hiding in a cargo bay. They claim to be a %s looking for work. Low experience, but they'll work for free — no hire cost." % [
				stowaway.name, stowaway.role]
			color = _GOLD
			choices.append({ "label": "Welcome aboard", "action": func() -> void:
				_crew.append(stowaway)
				_show_tab(_current_tab) })
			choices.append({ "label": "Turn them away", "action": func() -> void: pass })

		"merchant":
			var discount := randi_range(20, 45)
			var bonus_cr := randi_range(60, 200)
			icon  = "💰"
			title = "TRAVELLING MERCHANT"
			text  = "A merchant approaches your ship offering surplus supplies at a steep discount. Pay %d cr now for goods worth reselling at your next stop." % bonus_cr
			color = _GOLD
			var cost: int = int(bonus_cr * (1.0 - discount / 100.0))
			choices.append({ "label": "Buy goods (%d cr)" % cost, "action": func() -> void:
				if _credits >= cost:
					_credits -= cost
					# Store the profit for next port arrival — simplified: just give it now
					_credits += bonus_cr
					_refresh_credits() })
			choices.append({ "label": "No thanks", "action": func() -> void: pass })

		"bar_rumor":
			icon  = "🍺"
			title = "BAR RUMOR"
			var rumors := [
				"A drunk pilot swears there's a derelict full of salvage near %s. Could be worth checking out on your next run." % sys_name,
				"Word at the bar: a shipping guild is looking for reliable captains. Freight jobs from %s should pay better for a while." % sys_name,
				"An old spacer tells you about a shortcut through the nebula. \"Saves two days, but your hull won't thank you.\"",
				"Rumor has it a pirate fleet is regrouping near the outer systems. Tactical crews are in high demand.",
				"A trader mentions that crew from %s tend to be more experienced. Might be worth hiring here." % sys_name,
			]
			text = rumors[randi() % rumors.size()]
			color = _ACCENT
			# Some rumors have a small tangible benefit
			if randi() % 100 < 40:
				var tip_cr := randi_range(15, 50)
				text += "\n\nThe information proves useful — you adjust your plans accordingly. +%d cr" % tip_cr
				_credits += tip_cr
				_refresh_credits()
			choices.append({ "label": "Interesting...", "action": func() -> void: pass })

		"bar_fight":
			icon  = "👊"
			title = "BAR FIGHT"
			var victim: Dictionary = _crew[randi() % _crew.size()]
			var victim_name: String = victim.get("name", "A crew member")
			var roll := randi() % 100
			if roll < 50:
				text = "%s got into a scuffle at a local bar but came out on top. No harm done — just a bruised ego on the other guy." % victim_name
				color = _GREEN
			elif roll < 80:
				var fine := randi_range(20, 60)
				text = "%s started a fight at the cantina. Station security slapped you with a %d cr fine." % [victim_name, fine]
				_credits = maxi(0, _credits - fine)
				_refresh_credits()
				color = _ORANGE
			else:
				var loss := randf_range(0.03, 0.08)
				victim.efficiency = maxf(0.20, victim.get("efficiency", 0.5) - loss)
				text = "%s took a beating in a bar fight. Efficiency dropped to %d%%." % [
					victim_name, int(victim.efficiency * 100)]
				color = _RED
			choices.append({ "label": "Noted", "action": func() -> void: _show_tab(_current_tab) })

		"mysterious_package":
			icon  = "📦"
			title = "MYSTERIOUS PACKAGE"
			text  = "A hooded figure left a sealed crate at your docking bay with a note: \"Don't open until you're in deep space.\" Do you take it?"
			color = _PURPLE
			choices.append({ "label": "Take the crate", "action": func() -> void:
				var outcome := randi() % 100
				if outcome < 40:
					var loot := randi_range(80, 250)
					_credits += loot
					_refresh_credits()
					_show_event_followup("📦", "CRATE OPENED",
						"Inside: a stash of rare components worth %d cr. Lucky find." % loot, _GREEN)
				elif outcome < 70:
					_crew_counter += 1
					var recruit := CrewData.generate_crew("", _crew_counter)
					_crew.append(recruit)
					_show_event_followup("📦", "CRATE OPENED",
						"It's... a cryo pod? %s (%s) thaws out and offers to join your crew." % [
							recruit.name, recruit.role], _ACCENT)
				elif outcome < 90:
					_show_event_followup("📦", "CRATE OPENED",
						"Empty. Just packing foam and a note that says \"GOTCHA\". Waste of time.", _DIM)
				else:
					var fine := randi_range(80, 150)
					_credits = maxi(0, _credits - fine)
					_refresh_credits()
					_show_event_followup("📦", "CRATE OPENED",
						"Contraband. Station security confiscates it and fines you %d cr." % fine, _RED)
			})
			choices.append({ "label": "Leave it alone", "action": func() -> void: pass })

		"old_friend":
			icon  = "🤝"
			title = "OLD FRIEND"
			var crew_member: Dictionary = _crew[randi() % _crew.size()]
			var cm_name: String = crew_member.get("name", "One of your crew")
			var boost := randf_range(0.04, 0.10)
			crew_member.efficiency = minf(1.0, crew_member.get("efficiency", 0.5) + boost)
			text = "%s ran into an old academy friend at the port. They swapped stories and techniques over drinks. Efficiency increased to %d%%." % [
				cm_name, int(crew_member.efficiency * 100)]
			color = _GREEN
			choices.append({ "label": "Good for them", "action": func() -> void: _show_tab(_current_tab) })

		"customs_inspection":
			icon  = "🔍"
			title = "CUSTOMS INSPECTION"
			var roll := randi() % 100
			if roll < 65:
				text = "Port authority conducted a routine inspection of your vessel. Everything checks out — you're cleared."
				color = _GREEN
			else:
				var fine := randi_range(30, 100)
				text = "Customs found an expired cargo manifest and hit you with a %d cr administrative fine. Bureaucracy at its finest." % fine
				_credits = maxi(0, _credits - fine)
				_refresh_credits()
				color = _ORANGE
			choices.append({ "label": "Understood", "action": func() -> void: pass })

		"refugee":
			icon  = "🚀"
			title = "REFUGEE REQUEST"
			_crew_counter += 1
			var refugee := CrewData.generate_crew("", _crew_counter)
			refugee.efficiency = snappedf(randf_range(0.40, 0.70), 0.01)
			var payment := randi_range(40, 120)
			text = "A %s named %s approaches your ship, desperate for passage. They offer %d cr and their skills if you'll take them on. Efficiency: %d%%." % [
				refugee.role, refugee.name, payment, int(refugee.efficiency * 100)]
			color = _ACCENT
			choices.append({ "label": "Take them in (+%d cr)" % payment, "action": func() -> void:
				_credits += payment
				_crew.append(refugee)
				_refresh_credits()
				_show_tab(_current_tab) })
			choices.append({ "label": "Can't help", "action": func() -> void: pass })

		"black_market_tip":
			icon  = "🕶"
			title = "BLACK MARKET TIP"
			var payout := randi_range(100, 300)
			var risk_cost := randi_range(40, 80)
			text = "A shady contact offers you intel on a lucrative deal. Invest %d cr now, get %d cr back. \"Guaranteed,\" they say." % [risk_cost, payout]
			color = _PURPLE
			choices.append({ "label": "Invest %d cr" % risk_cost, "action": func() -> void:
				if _credits >= risk_cost:
					_credits -= risk_cost
					if randi() % 100 < 70:  # 70% chance it pays off
						_credits += payout
						_refresh_credits()
						_show_event_followup("🕶", "DEAL COMPLETE",
							"The contact came through. +%d cr profit." % (payout - risk_cost), _GREEN)
					else:
						_refresh_credits()
						_show_event_followup("🕶", "DEAL GONE WRONG",
							"The contact vanished with your money. -%d cr." % risk_cost, _RED)
			})
			choices.append({ "label": "Too risky", "action": func() -> void: pass })

		"hull_scrape":
			icon  = "💥"
			title = "DOCKING DAMAGE"
			text = "Rough docking conditions at this station scraped your hull during approach."
			color = _ORANGE
			var damaged_rooms := 0
			for node in _ship_nodes:
				var sn := node as ShipNode
				if sn == null: continue
				if randi() % 100 < 30:  # 30% chance per room
					sn.apply_damage(randi_range(2, 6))
					damaged_rooms += 1
			if damaged_rooms > 0:
				text += " %d room%s took minor damage." % [damaged_rooms, "s" if damaged_rooms > 1 else ""]
			else:
				text += " Luckily, no significant damage."
				color = _GREEN
			choices.append({ "label": "Check the damage report", "action": func() -> void: _show_tab("repair") })

		"crew_bonding":
			icon  = "🎯"
			title = "CREW BONDING"
			var boosted: Array = []
			for cm in _crew:
				if cm.get("status", "active") == "active" and randi() % 100 < 40:
					var boost := randf_range(0.02, 0.05)
					cm.efficiency = minf(1.0, cm.get("efficiency", 0.5) + boost)
					boosted.append(cm.get("name", "?"))
			if boosted.is_empty():
				text = "Your crew spent some downtime together at the station, but nothing remarkable happened."
				color = _DIM
			elif boosted.size() == 1:
				text = "Your crew spent downtime together. %s picked up some new techniques from the others. Efficiency increased." % boosted[0]
				color = _GREEN
			else:
				text = "Shore time brought your crew closer together. %s and %s improved their skills." % [
					", ".join(boosted.slice(0, -1)), boosted[-1]]
				color = _GREEN
			choices.append({ "label": "Good to hear", "action": func() -> void: _show_tab(_current_tab) })

	# Show the event popup
	if not title.is_empty():
		_show_port_event_popup(icon, title, text, color, choices)


func _show_port_event_popup(icon: String, title: String, text: String,
		color: Color, choices: Array) -> void:
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.97)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 70

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	popup.add_child(vb)

	# Icon + title
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vb.add_child(header)
	header.add_child(_lbl(icon, 22, color))
	header.add_child(_lbl(title, 16, color))

	# Body text
	var body := _lbl(text, 11, _TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(body)

	vb.add_child(_lbl(""))

	# Choice buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vb.add_child(btn_row)

	for choice in choices:
		var btn := Button.new()
		btn.text = choice.label
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(120, 30)
		var action: Callable = choice.action
		btn.pressed.connect(func() -> void:
			action.call()
			popup.queue_free())
		btn_row.add_child(btn)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(PRESET_CENTER)
	popup.offset_left  = -230
	popup.offset_right =  230
	popup.offset_top   = -120
	popup.offset_bottom = 120


func _show_event_followup(icon: String, title: String, text: String, color: Color) -> void:
	## Small follow-up popup for delayed event outcomes (e.g. opening the crate).
	_show_port_event_popup(icon, title, text, color, [
		{ "label": "OK", "action": func() -> void: _show_tab(_current_tab) }
	])


# ══════════════════════════════════════════════════════════════════════════════
# DEPART
# ══════════════════════════════════════════════════════════════════════════════
func _on_depart() -> void:
	# Abandon crew still on shore leave or arrested — they're removed from roster
	var abandoned: Array = []
	for cm in _crew.duplicate():
		var status: String = cm.get("status", "active")
		if status in ["shore_leave", "arrested", "on_mission"]:
			abandoned.append(cm.get("name", "Unknown"))
			_crew.erase(cm)

	port_closed.emit({
		"credits":      _credits,
		"crew":         _crew,
		"crew_counter": _crew_counter,
		"abandoned":    abandoned,
	})
	queue_free()


func get_state() -> Dictionary:
	return { "credits": _credits, "crew": _crew, "crew_counter": _crew_counter }


# ══════════════════════════════════════════════════════════════════════════════
# UI HELPERS
# ══════════════════════════════════════════════════════════════════════════════
func _lbl(text: String, font_size: int = 11, color: Color = _TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	return s


func _refresh_credits() -> void:
	if _lbl_credits != null:
		_lbl_credits.text = "Credits: %d" % _credits


func _show_crew_stats(cm: Dictionary) -> void:
	## Popup with full crew member details + large portrait.
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style.border_color = _ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	popup.z_index = 60

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	popup.add_child(hb)

	# Large portrait
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(96, 96)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path: String = cm.get("portrait", "")
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		tex.texture = load(portrait_path)
	hb.add_child(tex)

	# Stats column
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)

	vb.add_child(_lbl(cm.get("name", "Unknown"), 14, _TEXT))
	vb.add_child(_lbl("Role: %s" % cm.get("role", "?"), 12, _ACCENT))
	var eff: float = cm.get("efficiency", 0.5)
	var eff_col := _GREEN if eff >= 0.7 else (_GOLD if eff >= 0.5 else _RED)
	vb.add_child(_lbl("Efficiency: %d%%" % int(eff * 100), 12, eff_col))
	vb.add_child(_lbl("Status: %s" % cm.get("status", "active").to_upper(), 11,
		_GREEN if cm.get("status", "active") == "active" else _GOLD))

	var assigned: String = cm.get("assigned_to", "")
	if assigned.is_empty():
		vb.add_child(_lbl("Assignment: None", 11, _DIM))
	else:
		var room_name := assigned
		for node in _ship_nodes:
			var sn := node as ShipNode
			if sn != null and sn.node_uid == assigned:
				var def := RoomData.find(sn.def_id)
				room_name = def.get("name", assigned) if not def.is_empty() else assigned
				break
		vb.add_child(_lbl("Assignment: %s" % room_name, 11, _GREEN))

	# Veteran info
	var trips: int = cm.get("trips", 0)
	var rank: String = CrewData.veteran_rank(trips)
	if rank.is_empty():
		vb.add_child(_lbl("Voyages: %d  (Rookie)" % trips, 11, _DIM))
	else:
		var rank_col := Color(0.75, 0.70, 0.95, 1.0) if rank != "Legendary" else _GOLD
		vb.add_child(_lbl("Voyages: %d  ★ %s" % [trips, rank], 11, rank_col))

	var match_type: String = CrewData.room_type_for_role(cm.get("role", ""))
	vb.add_child(_lbl("Best in: %s rooms" % match_type, 10, _DIM))

	# Close button
	var btn_close := Button.new()
	btn_close.text = "Close"
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.pressed.connect(func() -> void: popup.queue_free())
	vb.add_child(btn_close)

	add_child(popup)
	popup.set_anchors_and_offsets_preset(PRESET_CENTER)
	popup.offset_left = -140
	popup.offset_right = 140
	popup.offset_top = -80
	popup.offset_bottom = 80
