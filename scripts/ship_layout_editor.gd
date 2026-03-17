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

# All available hull textures — hardcoded so web export doesn't need DirAccess
const ALL_TEXTURES: Array[String] = [
	"res://assets/pictures/textures/tex_aged_iron.png",
	"res://assets/pictures/textures/tex_biometal.png",
	"res://assets/pictures/textures/tex_carbon_composite.png",
	"res://assets/pictures/textures/tex_darktech.png",
	"res://assets/pictures/textures/tex_darkmetal.png",
	"res://assets/pictures/textures/tex_energy_conduit_mesh.png",
	"res://assets/pictures/textures/tex_heat_ceramic.png",
	"res://assets/pictures/textures/tex_holometal.png",
	"res://assets/pictures/textures/tex_krysthari_hull.png",
	"res://assets/pictures/textures/tex_luminar_hull.png",
	"res://assets/pictures/textures/tex_oldfreighter.png",
	"res://assets/pictures/textures/tex_polymer_coating.png",
	"res://assets/pictures/textures/tex_reinforced_glass.png",
	"res://assets/pictures/textures/tex_riveted_steel.png",
	"res://assets/pictures/textures/tex_runemetal.png",
	"res://assets/pictures/textures/tex_scaled.png",
	"res://assets/pictures/textures/tex_technology.png",
	"res://assets/pictures/textures/tex_titanium.png",
	"res://assets/pictures/textures/tex_varak_hull.png",
	"res://assets/pictures/textures/tex_vothaal_hull.png",
]

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

# ── Texture panel ─────────────────────────────────────────────────────────────
var _tex_paths:    Array  = []   # res:// paths to all texture pngs
var _tex_buttons:  Array  = []   # Array of {btn, path}
var _lbl_tex_name: Label  = null # readout of currently highlighted tex
var _color_picker_btn: ColorPickerButton = null  # per-room tint chooser
var _lbl_tint_name:    Label  = null

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
	_build_texture_panel(root_hbox)

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

		# Resolve texture: layout override > per-room purchase > type fallback
		var tex: Texture2D = null
		var layout_tex: String = ""
		if _layout.has(sn.node_uid):
			layout_tex = (_layout[sn.node_uid] as Dictionary).get("tex", "")
		if not layout_tex.is_empty() and ResourceLoader.exists(layout_tex):
			tex = load(layout_tex) as Texture2D
		if tex == null:
			var tex_path: String = room_textures.get(sn.node_uid, "")
			if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
				tex = load(tex_path) as Texture2D
		if tex == null:
			tex = type_textures.get(rtype, null) as Texture2D
		var room_colors: Dictionary = _params.get("room_colors", {})
		var custom_hex: String = room_colors.get(sn.node_uid, "")
		var color_ov := Color(-1, -1, -1)
		if not custom_hex.is_empty():
			color_ov = Color.html(custom_hex)
		var mat := ShipBuilder3D.room_material(rtype, tex, color_ov)

		var container := Node3D.new()
		container.position = base_pos
		container.set_meta("base_pos", base_pos)
		container.set_meta("base_mat", mat)
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
		_refresh_tex_panel("")
		if _color_picker_btn:
			_color_picker_btn.disabled = true
			_lbl_tint_name.text = ""
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

	# Refresh texture panel: layout override → purchase texture → ""
	var sel_uid: String = _room_uids[idx]
	var cur_tex: String = ""
	if _layout.has(sel_uid):
		cur_tex = (_layout[sel_uid] as Dictionary).get("tex", "")
	if cur_tex.is_empty():
		cur_tex = (_params.get("room_textures", {}) as Dictionary).get(sel_uid, "")
	_refresh_tex_panel(cur_tex)

	# Refresh tint color picker
	_refresh_tint_picker(sel_uid)


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
	# Clean up: remove entries at default values (keep if tex override or non-default transform)
	var clean: Dictionary = {}
	for uid in _layout:
		var e: Dictionary = _layout[uid]
		var has_transform := absf(e.get("ox", 0.0)) > 0.01 or absf(e.get("oy", 0.0)) > 0.01 \
				or absf(e.get("oz", 0.0)) > 0.01 \
				or absf(e.get("rot_y", 0.0)) > 0.5 \
				or absf(e.get("scale", 1.0) - 1.0) > 0.01
		var has_tex: bool = not (e.get("tex", "") as String).is_empty()
		if has_transform or has_tex:
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


# ── Texture Panel ─────────────────────────────────────────────────────────────

func _build_texture_panel(parent: Control) -> void:
	# Use the hardcoded list — DirAccess doesn't work in web exports
	_tex_paths = Array(ALL_TEXTURES)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 196
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CLR_PANEL
	style.border_color = CLR_ACCENT.darkened(0.3)
	style.border_width_left = 2
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "TEXTURES"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", CLR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_lbl_tex_name = Label.new()
	_lbl_tex_name.text = "--"
	_lbl_tex_name.add_theme_font_size_override("font_size", 9)
	_lbl_tex_name.add_theme_color_override("font_color", CLR_DIM)
	_lbl_tex_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_tex_name.clip_text = true
	vb.add_child(_lbl_tex_name)

	# ── Color tint row ──────────────────────────────────────────────────────
	var tint_row := HBoxContainer.new()
	tint_row.add_theme_constant_override("separation", 6)
	vb.add_child(tint_row)

	var tint_lbl := Label.new()
	tint_lbl.text = "Tint"
	tint_lbl.custom_minimum_size.x = 28
	tint_lbl.add_theme_font_size_override("font_size", 10)
	tint_lbl.add_theme_color_override("font_color", CLR_DIM)
	tint_row.add_child(tint_lbl)

	_color_picker_btn = ColorPickerButton.new()
	_color_picker_btn.custom_minimum_size = Vector2(32, 24)
	_color_picker_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker_btn.color = Color(0.5, 0.5, 0.5)
	_color_picker_btn.edit_alpha = false
	_color_picker_btn.disabled = true
	_color_picker_btn.add_theme_font_size_override("font_size", 1)
	_color_picker_btn.color_changed.connect(_on_tint_color_changed)
	tint_row.add_child(_color_picker_btn)

	var btn_reset_tint := Button.new()
	btn_reset_tint.text = "Reset"
	btn_reset_tint.custom_minimum_size = Vector2(44, 24)
	btn_reset_tint.add_theme_font_size_override("font_size", 9)
	btn_reset_tint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	btn_reset_tint.pressed.connect(_on_reset_tint)
	tint_row.add_child(btn_reset_tint)

	_lbl_tint_name = Label.new()
	_lbl_tint_name.text = ""
	_lbl_tint_name.add_theme_font_size_override("font_size", 8)
	_lbl_tint_name.add_theme_color_override("font_color", CLR_DIM)
	_lbl_tint_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_lbl_tint_name)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", CLR_ACCENT.darkened(0.4))
	vb.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)

	for path: String in _tex_paths:
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(54, 54)
		btn.icon               = tex
		btn.expand_icon        = true
		btn.clip_text          = true
		btn.tooltip_text       = path.get_file().get_basename().trim_prefix("tex_").replace("_", " ")
		btn.pressed.connect(func(): _on_texture_thumb_clicked(path))
		grid.add_child(btn)
		_tex_buttons.append({"btn": btn, "path": path})

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", CLR_ACCENT.darkened(0.4))
	vb.add_child(sep2)

	var btn_clear := _make_btn("X Clear", -1, _on_clear_texture)
	btn_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_clear.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	vb.add_child(btn_clear)


func _on_texture_thumb_clicked(path: String) -> void:
	if _selected_idx < 0:
		return
	var uid: String = _room_uids[_selected_idx]
	if not _layout.has(uid):
		_layout[uid] = {"ox": 0.0, "oy": 0.0, "oz": 0.0, "rot_y": 0.0, "scale": 1.0}
	_layout[uid]["tex"] = path
	_apply_tex_to_container(_room_containers[_selected_idx], path)
	_refresh_tex_panel(path)


func _on_clear_texture() -> void:
	if _selected_idx < 0:
		return
	var uid: String = _room_uids[_selected_idx]
	if _layout.has(uid):
		_layout[uid].erase("tex")
	# Revert to purchase texture or type fallback
	var fallback: String = (_params.get("room_textures", {}) as Dictionary).get(uid, "")
	_apply_tex_to_container(_room_containers[_selected_idx], fallback)
	_refresh_tex_panel("")


func _apply_tex_to_container(container: Node3D, tex_path: String) -> void:
	var mat: StandardMaterial3D = container.get_meta("base_mat", null)
	if mat == null:
		return
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path) as Texture2D
	else:
		mat.albedo_texture = null


func _refresh_tex_panel(active_path: String) -> void:
	if _lbl_tex_name != null:
		if active_path.is_empty():
			_lbl_tex_name.text = "--"
		else:
			_lbl_tex_name.text = active_path.get_file().get_basename().trim_prefix("tex_").replace("_", " ")

	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color    = CLR_ACCENT.darkened(0.2)
	sel_style.border_color = CLR_GOLD
	sel_style.set_border_width_all(2)

	for entry: Dictionary in _tex_buttons:
		var btn: Button = entry["btn"]
		var path: String = entry["path"]
		if path == active_path:
			btn.add_theme_stylebox_override("normal", sel_style)
		else:
			btn.remove_theme_stylebox_override("normal")


# ── Color Tint ────────────────────────────────────────────────────────────────

func _refresh_tint_picker(uid: String) -> void:
	if _color_picker_btn == null:
		return
	_color_picker_btn.disabled = false
	var room_colors: Dictionary = _params.get("room_colors", {})
	var custom_hex: String = room_colors.get(uid, "")
	if custom_hex.is_empty():
		# Show the type default
		var rtype: String = _room_types[_selected_idx] if _selected_idx >= 0 else "Utility"
		_color_picker_btn.color = RoomData.type_color(rtype)
		_lbl_tint_name.text = "default"
	else:
		_color_picker_btn.color = Color.html(custom_hex)
		_lbl_tint_name.text = "#" + custom_hex


func _on_tint_color_changed(color: Color) -> void:
	if _selected_idx < 0:
		return
	var uid: String = _room_uids[_selected_idx]
	var hex: String = color.to_html(false)

	# Store in params so it persists for this session
	var room_colors: Dictionary = _params.get("room_colors", {})
	room_colors[uid] = hex
	_params["room_colors"] = room_colors

	# Update the 3D preview material
	_apply_tint_to_container(_room_containers[_selected_idx], color)
	_lbl_tint_name.text = "#" + hex


func _on_reset_tint() -> void:
	if _selected_idx < 0:
		return
	var uid: String = _room_uids[_selected_idx]

	# Remove custom color
	var room_colors: Dictionary = _params.get("room_colors", {})
	room_colors.erase(uid)
	_params["room_colors"] = room_colors

	# Revert to type default
	var rtype: String = _room_types[_selected_idx]
	var type_clr: Color = RoomData.type_color(rtype)
	_color_picker_btn.color = type_clr
	_apply_tint_to_container(_room_containers[_selected_idx], type_clr)
	_lbl_tint_name.text = "default"


func _apply_tint_to_container(container: Node3D, color: Color) -> void:
	var mat: StandardMaterial3D = container.get_meta("base_mat", null)
	if mat == null:
		return
	mat.albedo_color = color.darkened(0.10)
