## ship_layout_editor.gd — 3D Ship Layout Editor modal.
## Lets the player adjust per-room position, rotation, and scale in 3D space
## with a live preview and orbit camera.
class_name ShipLayoutEditor
extends Control

signal layout_saved(layout: Dictionary)
signal layout_cancelled

# ── Setup params (set via setup() before add_child) ─────────────────────────
var _params: Dictionary = {}

# ── Theme colors (matches main.gd) ──────────────────────────────────────────
const CLR_BG      := Color(0.039, 0.059, 0.098, 1.0)
const CLR_PANEL   := Color(0.078, 0.110, 0.176, 1.0)
const CLR_TEXT    := Color(0.780, 0.847, 1.000, 1.0)
const CLR_DIM     := Color(0.470, 0.510, 0.620, 1.0)
const CLR_ACCENT  := Color(0.310, 0.537, 0.843, 1.0)
const CLR_GOLD    := Color(1.000, 0.820, 0.310, 1.0)

# ── Type-level fallback textures ─────────────────────────────────────────────
const TEX_HULL  := "res://assets/pictures/textures/tex_titanium.png"
const TEX_WING  := "res://assets/pictures/textures/tex_carbon_composite.png"
const TEX_GLASS := "res://assets/pictures/textures/tex_reinforced_glass.png"
const TEX_IRON  := "res://assets/pictures/textures/tex_aged_iron.png"

# ── 3D scene refs ────────────────────────────────────────────────────────────
var _viewport:   SubViewport
var _world:      Node3D
var _camera:     Camera3D
var _ship_root:  Node3D

# ── Room data ────────────────────────────────────────────────────────────────
var _room_containers: Array = []   # Node3D per room
var _room_uids:       Array = []   # parallel uid strings
var _room_names:      Array = []   # parallel display names
var _room_types:      Array = []   # parallel type strings
var _layout:          Dictionary = {}  # uid → {ox,oy,oz,rot_y,scale}

# ── Selection ────────────────────────────────────────────────────────────────
var _selected_idx:    int = -1
var _highlight_mesh:  MeshInstance3D = null

# ── UI refs ──────────────────────────────────────────────────────────────────
var _room_list:    ItemList
var _lbl_selected: Label
var _slider_x:     HSlider
var _slider_y:     HSlider
var _slider_z:     HSlider
var _slider_rot:   HSlider
var _slider_scale: HSlider
var _val_x:        Label
var _val_y:        Label
var _val_z:        Label
var _val_rot:      Label
var _val_scale:    Label
var _vpc:          SubViewportContainer
var _ship_rot_slider: HSlider
var _ship_rot_val:    Label

# ── Camera orbit state ───────────────────────────────────────────────────────
var _cam_distance: float = 12.0
var _cam_yaw:      float = 0.0
var _cam_pitch:    float = -25.0
var _cam_target:   Vector3 = Vector3.ZERO
var _orbiting:     bool = false
const CAM_ZOOM_MIN  := 4.0
const CAM_ZOOM_MAX  := 30.0
const CAM_ZOOM_STEP := 1.0
const CAM_PITCH_MIN := -80.0
const CAM_PITCH_MAX := 10.0


# ════════════════════════════════════════════════════════════════════════════
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50

	# Dark overlay
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root vertical layout: main content on top, bottom bar at bottom
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Main layout: left panel + 3D viewport
	var root_hbox := HBoxContainer.new()
	root_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_hbox.set("theme_override_constants/separation", 0)
	root_vbox.add_child(root_hbox)

	_build_left_panel(root_hbox)
	_build_3d_viewport(root_hbox)

	# Bottom bar (part of flow, not overlay)
	_build_bottom_bar(root_vbox)

	# Build 3D content
	_build_environment()
	_build_grid()
	_build_ship_preview()
	_build_camera()
	_populate_room_list()


# ── Left Panel ───────────────────────────────────────────────────────────────

func _build_left_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 260
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CLR_PANEL
	style.border_color = CLR_ACCENT.darkened(0.3)
	style.border_width_right = 2
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# Header
	var title := Label.new()
	title.text = "3D SHIP LAYOUT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", CLR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	# Room list
	var list_lbl := Label.new()
	list_lbl.text = "Rooms"
	list_lbl.add_theme_font_size_override("font_size", 10)
	list_lbl.add_theme_color_override("font_color", CLR_DIM)
	vb.add_child(list_lbl)

	_room_list = ItemList.new()
	_room_list.custom_minimum_size.y = 160
	_room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_list.add_theme_color_override("font_color", CLR_TEXT)
	_room_list.add_theme_font_size_override("font_size", 11)
	_room_list.item_selected.connect(_on_list_selected)
	vb.add_child(_room_list)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", CLR_ACCENT.darkened(0.4))
	vb.add_child(sep)

	# Selected label
	_lbl_selected = Label.new()
	_lbl_selected.text = "No room selected"
	_lbl_selected.add_theme_font_size_override("font_size", 12)
	_lbl_selected.add_theme_color_override("font_color", CLR_GOLD)
	_lbl_selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_selected)

	# Sliders
	var pairs := _make_slider(vb, "X Pos", -5.0, 5.0, 0.0, 0.05)
	_slider_x = pairs[0];  _val_x = pairs[1]
	pairs = _make_slider(vb, "Y Pos", -3.0, 3.0, 0.0, 0.05)
	_slider_y = pairs[0];  _val_y = pairs[1]
	pairs = _make_slider(vb, "Z Pos", -5.0, 5.0, 0.0, 0.05)
	_slider_z = pairs[0];  _val_z = pairs[1]
	pairs = _make_slider(vb, "Rotate", 0.0, 360.0, 0.0, 5.0)
	_slider_rot = pairs[0];  _val_rot = pairs[1]
	pairs = _make_slider(vb, "Scale", 0.5, 2.0, 1.0, 0.05)
	_slider_scale = pairs[0];  _val_scale = pairs[1]


func _make_slider(parent: Control, label_text: String, min_val: float,
		max_val: float, default_val: float, step: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 48
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", CLR_DIM)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_val
	val_lbl.custom_minimum_size.x = 38
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", CLR_TEXT)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	return [slider, val_lbl]


# ── 3D Viewport ──────────────────────────────────────────────────────────────

func _build_3d_viewport(parent: Control) -> void:
	# Wrap viewport + rotation slider in a VBox
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	parent.add_child(vbox)

	_vpc = SubViewportContainer.new()
	_vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.stretch = true
	_vpc.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_vpc)
	_vpc.gui_input.connect(_on_viewport_input)

	_viewport = SubViewport.new()
	_viewport.world_3d = World3D.new()
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vpc.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	# Ship rotation slider bar at the bottom of the 3D view
	var rot_bar := HBoxContainer.new()
	rot_bar.add_theme_constant_override("separation", 8)
	rot_bar.custom_minimum_size.y = 28
	var rot_style := StyleBoxFlat.new()
	rot_style.bg_color = Color(0.04, 0.06, 0.10, 0.90)
	rot_style.set_content_margin_all(4)
	var rot_panel := PanelContainer.new()
	rot_panel.add_theme_stylebox_override("panel", rot_style)
	vbox.add_child(rot_panel)
	rot_panel.add_child(rot_bar)

	var rot_lbl := Label.new()
	rot_lbl.text = "Rotate Ship"
	rot_lbl.add_theme_font_size_override("font_size", 10)
	rot_lbl.add_theme_color_override("font_color", CLR_DIM)
	rot_bar.add_child(rot_lbl)

	_ship_rot_slider = HSlider.new()
	_ship_rot_slider.min_value = 0.0
	_ship_rot_slider.max_value = 360.0
	_ship_rot_slider.step = 1.0
	_ship_rot_slider.value = 0.0
	_ship_rot_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_rot_slider.value_changed.connect(_on_ship_rotation_changed)
	rot_bar.add_child(_ship_rot_slider)

	_ship_rot_val = Label.new()
	_ship_rot_val.text = "0°"
	_ship_rot_val.custom_minimum_size.x = 35
	_ship_rot_val.add_theme_font_size_override("font_size", 10)
	_ship_rot_val.add_theme_color_override("font_color", CLR_TEXT)
	rot_bar.add_child(_ship_rot_val)


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.004, 0.016, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.15, 0.16, 0.24, 1.0)
	env.ambient_light_energy = 1.5  # brighter than flight for editing
	env.glow_enabled         = true
	env.glow_intensity       = 0.4
	env.glow_bloom           = 0.1
	env_node.environment = env
	_world.add_child(env_node)

	# Directional fill light
	var sun := DirectionalLight3D.new()
	sun.light_color  = Color(0.85, 0.88, 1.0)
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	_world.add_child(sun)


func _build_grid() -> void:
	var grid := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	plane.subdivide_width = 20
	plane.subdivide_depth = 20
	grid.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.3, 0.5, 0.08)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grid.set_surface_override_material(0, mat)
	grid.position.y = -1.0
	_world.add_child(grid)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_world.add_child(_camera)
	_update_camera()


func _update_camera() -> void:
	var yaw_rad := deg_to_rad(_cam_yaw)
	var pitch_rad := deg_to_rad(_cam_pitch)
	var offset := Vector3(
		_cam_distance * cos(pitch_rad) * sin(yaw_rad),
		-_cam_distance * sin(pitch_rad),
		_cam_distance * cos(pitch_rad) * cos(yaw_rad))
	_camera.position = _cam_target + offset
	_camera.look_at(_cam_target, Vector3.UP)


# ── Ship Building ────────────────────────────────────────────────────────────

func _build_ship_preview() -> void:
	_ship_root = Node3D.new()
	_world.add_child(_ship_root)

	var ship_nodes: Array = _params.get("ship_nodes", [])
	var room_textures: Dictionary = _params.get("room_textures", {})
	_layout = (_params.get("existing_layout", {}) as Dictionary).duplicate(true)

	if ship_nodes.is_empty():
		return

	# Load type-level fallback textures
	var load_tex := func(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null

	var type_textures: Dictionary = {
		"Power":    load_tex.call(TEX_HULL),
		"Engines":  load_tex.call(TEX_IRON),
		"Command":  load_tex.call(TEX_GLASS),
		"Tactical": load_tex.call(TEX_WING),
		"Utility":  load_tex.call(TEX_HULL),
	}

	# Compute bounding box + scale (same as star_map._build_from_layout)
	var min_x := INF;  var max_x := -INF
	var min_y := INF;  var max_y := -INF
	for node in ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		min_x = minf(min_x, sn.hull_pos.x)
		max_x = maxf(max_x, sn.hull_pos.x)
		min_y = minf(min_y, sn.hull_pos.y)
		max_y = maxf(max_y, sn.hull_pos.y)

	var center := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var extent := maxf(max_x - min_x, max_y - min_y)
	var px_scale := 5.0 / maxf(extent, 200.0)

	for node in ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue

		var rel := sn.hull_pos - center
		var base_pos := Vector3(rel.x * px_scale, 0.0, rel.y * px_scale)

		var rtype:    String = def.get("type", "Utility")
		var universe: String = def.get("universe", "Universal")
		var cost:     int    = def.get("cost", 100)
		var box_sz := ShipBuilder3D.room_box_size(rtype)

		# Resolve texture: per-room first, then type fallback
		var tex: Texture2D = null
		var tex_path: String = room_textures.get(sn.node_uid, "")
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if tex == null:
			tex = type_textures.get(rtype, null) as Texture2D
		var mat := ShipBuilder3D.room_material(rtype, tex)

		var container := Node3D.new()
		container.position = base_pos
		container.set_meta("base_pos", base_pos)
		_ship_root.add_child(container)

		ShipBuilder3D.build_room_shape(container, rtype, universe, cost, mat, box_sz)
		ShipBuilder3D.add_room_lights(container, rtype, box_sz)

		_room_containers.append(container)
		_room_uids.append(sn.node_uid)
		_room_names.append(sn.title)
		_room_types.append(rtype)

		# Apply existing layout if present
		_apply_layout_to_container(container, sn.node_uid)

	# Center camera on ship
	_cam_target = Vector3.ZERO


func _apply_layout_to_container(container: Node3D, uid: String) -> void:
	var base_pos: Vector3 = container.get_meta("base_pos")
	if _layout.has(uid):
		var entry: Dictionary = _layout[uid]
		container.position = base_pos + Vector3(
			entry.get("ox", 0.0),
			entry.get("oy", 0.0),
			entry.get("oz", 0.0))
		container.rotation_degrees.y = entry.get("rot_y", 0.0)
		var s: float = entry.get("scale", 1.0)
		container.scale = Vector3(s, s, s)
	else:
		container.position = base_pos
		container.rotation_degrees.y = 0.0
		container.scale = Vector3.ONE


# ── Room List ────────────────────────────────────────────────────────────────

func _populate_room_list() -> void:
	for i in _room_uids.size():
		_room_list.add_item(_room_names[i])
		_room_list.set_item_custom_fg_color(i, RoomData.type_color(_room_types[i]))


func _on_list_selected(idx: int) -> void:
	_select_room(idx)


# ── Room Selection ───────────────────────────────────────────────────────────

func _select_room(idx: int) -> void:
	# Remove old highlight
	if _highlight_mesh and is_instance_valid(_highlight_mesh):
		_highlight_mesh.queue_free()
		_highlight_mesh = null

	_selected_idx = idx

	if idx < 0 or idx >= _room_containers.size():
		_lbl_selected.text = "No room selected"
		_room_list.deselect_all()
		_zero_sliders()
		return

	_room_list.select(idx)
	_lbl_selected.text = _room_names[idx]

	# Add highlight wireframe box
	var container: Node3D = _room_containers[idx]
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 1.6, 2.2)
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.mesh = box
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.82, 0.31, 0.20)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_highlight_mesh.set_surface_override_material(0, hmat)
	container.add_child(_highlight_mesh)

	_update_sliders_from_layout(_room_uids[idx])


func _try_select_room(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var from := _camera.project_ray_origin(screen_pos)
	var dir  := _camera.project_ray_normal(screen_pos)

	var best_idx := -1
	var best_dist := INF
	for i in _room_containers.size():
		var center_pos: Vector3 = _room_containers[i].global_position
		var hit_radius := 1.2
		# Ray-sphere intersection
		var oc := from - center_pos
		var b := oc.dot(dir)
		var c_val := oc.dot(oc) - hit_radius * hit_radius
		var disc := b * b - c_val
		if disc >= 0.0:
			var t := -b - sqrt(disc)
			if t > 0.0 and t < best_dist:
				best_dist = t
				best_idx = i

	if best_idx >= 0:
		_select_room(best_idx)


# ── Slider Controls ──────────────────────────────────────────────────────────

func _zero_sliders() -> void:
	_slider_x.set_value_no_signal(0.0);      _val_x.text = "0.00"
	_slider_y.set_value_no_signal(0.0);      _val_y.text = "0.00"
	_slider_z.set_value_no_signal(0.0);      _val_z.text = "0.00"
	_slider_rot.set_value_no_signal(0.0);    _val_rot.text = "0.00"
	_slider_scale.set_value_no_signal(1.0);  _val_scale.text = "1.00"


func _update_sliders_from_layout(uid: String) -> void:
	if _layout.has(uid):
		var e: Dictionary = _layout[uid]
		_slider_x.set_value_no_signal(e.get("ox", 0.0))
		_slider_y.set_value_no_signal(e.get("oy", 0.0))
		_slider_z.set_value_no_signal(e.get("oz", 0.0))
		_slider_rot.set_value_no_signal(e.get("rot_y", 0.0))
		_slider_scale.set_value_no_signal(e.get("scale", 1.0))
	else:
		_slider_x.set_value_no_signal(0.0)
		_slider_y.set_value_no_signal(0.0)
		_slider_z.set_value_no_signal(0.0)
		_slider_rot.set_value_no_signal(0.0)
		_slider_scale.set_value_no_signal(1.0)
	# Update readouts
	_val_x.text = "%.2f" % _slider_x.value
	_val_y.text = "%.2f" % _slider_y.value
	_val_z.text = "%.2f" % _slider_z.value
	_val_rot.text = "%.0f" % _slider_rot.value
	_val_scale.text = "%.2f" % _slider_scale.value


func _on_slider_changed(_value: float) -> void:
	if _selected_idx < 0:
		return
	var uid: String = _room_uids[_selected_idx]

	if not _layout.has(uid):
		_layout[uid] = {"ox": 0.0, "oy": 0.0, "oz": 0.0, "rot_y": 0.0, "scale": 1.0}

	_layout[uid]["ox"]    = _slider_x.value
	_layout[uid]["oy"]    = _slider_y.value
	_layout[uid]["oz"]    = _slider_z.value
	_layout[uid]["rot_y"] = _slider_rot.value
	_layout[uid]["scale"] = _slider_scale.value

	# Update readouts
	_val_x.text = "%.2f" % _slider_x.value
	_val_y.text = "%.2f" % _slider_y.value
	_val_z.text = "%.2f" % _slider_z.value
	_val_rot.text = "%.0f" % _slider_rot.value
	_val_scale.text = "%.2f" % _slider_scale.value

	_apply_layout_to_container(_room_containers[_selected_idx], uid)


func _on_ship_rotation_changed(value: float) -> void:
	if _ship_root != null:
		_ship_root.rotation_degrees.y = value
	_ship_rot_val.text = "%d°" % int(value)


# ── Viewport Input (orbit + select + zoom) ──────────────────────────────────

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cam_distance = maxf(CAM_ZOOM_MIN, _cam_distance - CAM_ZOOM_STEP)
				_update_camera()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cam_distance = minf(CAM_ZOOM_MAX, _cam_distance + CAM_ZOOM_STEP)
				_update_camera()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_try_select_room(mb.position)
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		_cam_yaw += mm.relative.x * 0.3
		_cam_pitch = clampf(_cam_pitch + mm.relative.y * 0.3, CAM_PITCH_MIN, CAM_PITCH_MAX)
		_update_camera()


# ── Bottom Bar ───────────────────────────────────────────────────────────────

func _build_bottom_bar(parent: Control) -> void:
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size.y = 48
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_END
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.03, 0.05, 0.10, 0.95)
	bar_style.set_content_margin_all(4)
	bar_bg.add_theme_stylebox_override("panel", bar_style)
	parent.add_child(bar_bg)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 40
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 10)
	bar_bg.add_child(bar)

	_add_sp(bar, 12)
	bar.add_child(_make_btn("Reset Room", 100, _reset_selected_room))
	bar.add_child(_make_btn("Reset All", 90, _reset_all_rooms))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var hint := Label.new()
	hint.text = "Right-click drag to orbit  |  Scroll to zoom  |  Left-click to select"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", CLR_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer2)

	var btn_cancel := _make_btn("Cancel", 80, _on_cancel)
	btn_cancel.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	bar.add_child(btn_cancel)

	var btn_save := _make_btn("Save Layout", 110, _on_save_layout)
	btn_save.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	bar.add_child(btn_save)

	_add_sp(bar, 12)


# ── Button Actions ───────────────────────────────────────────────────────────

func _reset_selected_room() -> void:
	if _selected_idx < 0: return
	var uid: String = _room_uids[_selected_idx]
	_layout.erase(uid)
	_apply_layout_to_container(_room_containers[_selected_idx], uid)
	_update_sliders_from_layout(uid)


func _reset_all_rooms() -> void:
	_layout.clear()
	for i in _room_containers.size():
		_apply_layout_to_container(_room_containers[i], _room_uids[i])
	if _selected_idx >= 0:
		_update_sliders_from_layout(_room_uids[_selected_idx])


func _on_cancel() -> void:
	layout_cancelled.emit()
	queue_free()


func _on_save_layout() -> void:
	# Clean up: remove entries at default values
	var clean: Dictionary = {}
	for uid in _layout:
		var e: Dictionary = _layout[uid]
		if absf(e.get("ox", 0.0)) > 0.01 or absf(e.get("oy", 0.0)) > 0.01 \
				or absf(e.get("oz", 0.0)) > 0.01 \
				or absf(e.get("rot_y", 0.0)) > 0.5 \
				or absf(e.get("scale", 1.0) - 1.0) > 0.01:
			clean[uid] = e
	layout_saved.emit(clean)
	queue_free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_btn(text: String, min_w: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.x = min_w
	btn.add_theme_font_size_override("font_size", 11)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(callback)
	return btn


func _add_sp(parent: Control, px: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.x = px
	parent.add_child(sp)
