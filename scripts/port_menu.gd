## port_menu.gd — Full-screen docking/port menu shown after arriving at a system.
## Tabs: Summary, Repair, Crew, Shore Leave.  "Depart" button closes and returns.
class_name PortMenu
extends Control

signal port_closed(result: Dictionary)

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


var _start_tab: String = "summary"

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 50
	_build_ui()
	_show_tab(_start_tab)


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

	for tab_name in ["summary", "repair", "crew", "shore_leave"]:
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
		var names := ["summary", "repair", "crew", "shore_leave"]
		_tab_buttons[i].add_theme_color_override("font_color",
			_ACCENT if names[i] == tab_name else _DIM)
	# Build tab content
	match tab_name:
		"summary":     _build_summary()
		"repair":      _build_repair()
		"crew":        _build_crew()
		"shore_leave": _build_shore_leave()


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
	vb.add_child(_lbl("50 cr per room", 10, _DIM))
	vb.add_child(_lbl(""))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(list)

	var damaged_count := 0
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if sn.current_durability >= sn.max_durability: continue
		damaged_count += 1

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)

		var pct := float(sn.current_durability) / float(sn.max_durability)
		var dur_col := _GREEN if pct > 0.6 else (_GOLD if pct > 0.3 else _RED)
		row.add_child(_lbl("%s" % def.get("name", "Room"), 11, _TEXT))
		row.add_child(_lbl("%d/%d" % [sn.current_durability, sn.max_durability], 11, dur_col))
		row.add_child(_spacer())

		var btn := Button.new()
		btn.text = "Repair (50 cr)"
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_repair_room.bind(sn, def))
		row.add_child(btn)

	if damaged_count == 0:
		list.add_child(_lbl("All rooms in good condition!", 12, _GREEN))
	else:
		# Repair all button
		vb.add_child(_lbl(""))
		var btn_all := Button.new()
		btn_all.text = "REPAIR ALL (%d cr)" % (damaged_count * 50)
		btn_all.add_theme_font_size_override("font_size", 12)
		btn_all.add_theme_color_override("font_color", _GREEN)
		btn_all.pressed.connect(_repair_all)
		vb.add_child(btn_all)


func _repair_room(sn: ShipNode, def: Dictionary) -> void:
	if _credits < 50:
		return
	_credits -= 50
	sn.repair_full(def)
	_refresh_credits()
	_show_tab("repair")   # refresh


func _repair_all() -> void:
	for node in _ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if sn.current_durability < sn.max_durability and _credits >= 50:
			_credits -= 50
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
# DEPART
# ══════════════════════════════════════════════════════════════════════════════
func _on_depart() -> void:
	# Abandon crew still on shore leave or arrested — they're removed from roster
	var abandoned: Array = []
	for cm in _crew.duplicate():
		var status: String = cm.get("status", "active")
		if status == "shore_leave" or status == "arrested":
			abandoned.append(cm.get("name", "Unknown"))
			_crew.erase(cm)

	port_closed.emit({
		"credits":      _credits,
		"crew":         _crew,
		"crew_counter": _crew_counter,
		"abandoned":    abandoned,
	})
	queue_free()


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
