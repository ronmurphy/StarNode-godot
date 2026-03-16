## star_map.gd — 3D animated star map shown during job travel.
## Built entirely in code. Instantiated by main.gd, covers full screen.
## Emits job_finished(result) when the ship arrives.
class_name StarMap
extends Control

signal job_finished(result: Dictionary)

# ── Setup params (set via setup() before add_child) ─────────────────────────
var _params: Dictionary = {}

# ── 3D scene refs ────────────────────────────────────────────────────────────
var _viewport:     SubViewport
var _world:        Node3D
var _camera:       Camera3D
var _ship_pivot:   Node3D      # moves & rotates along path
var _engine_glow:  MeshInstance3D
var _engine_trail: GPUParticles3D

# ── Travel state ─────────────────────────────────────────────────────────────
var _path_ids:    Array[String]  = []   # system IDs in travel order
var _waypoints:   Array[Vector3] = []   # world positions
var _wp_names:    Array[String]  = []   # display names
var _wp_index:    int   = 0    # current segment (from [i] to [i+1])
var _seg_progress: float = 0.0 # 0..1 within current segment
var _seg_duration: float = 5.0 # real seconds for this segment (at 1×)
var _traveling:   bool  = false
var _time_scale:  float = 1.0

# ── Day / wear tracking ──────────────────────────────────────────────────────
var _day_accumulator: float = 0.0  # fractional days elapsed
var _days_elapsed:    int   = 0    # full in-game days passed so far

# ── Job result ───────────────────────────────────────────────────────────────
var _earned:          int        = 0
var _ship_nodes_ref:  Array      = []
var _log_lines:       Array      = []
var _events:          Array      = []  # pre-rolled: {at, type, ...}
var _events_done:     Array      = []  # indices already fired
var _n_cinematic_segs: int       = 0   # first N waypoint-segments are pre-travel cinematic
var _sys_nodes:        Dictionary = {}  # system_id → Node3D (for proximity fade)
var _adjacencies:      Dictionary = {}  # node_uid → [{uid, type}] — hull adjacency map
var _room_containers:  Array      = []  # Node3D per ship room (same order as _ship_nodes_ref)

# ── Camera phases: 0=departure, 1=stationary flyby at midpoint, 2=chase ──
var _cam_phase:     int     = 0
var _cam_midpoint:  Vector3 = Vector3.ZERO  # stationary observation point
var _cam_travel_dir: Vector3 = Vector3.FORWARD  # overall origin→dest direction

# ── HUD refs ─────────────────────────────────────────────────────────────────
var _lbl_system:  Label
var _lbl_route:   Label
var _lbl_day:     Label
var _btn_speed:   Button
var _log_box:     RichTextLabel

# ── Constants ────────────────────────────────────────────────────────────────
const DAY_SECS   := 10.0   # real seconds per in-game day at 1× speed
var _cam_back:  float = 14.0
var _cam_up:    float =  5.0
const CAM_AHEAD  :=  9.0
const CAM_ZOOM_MIN := 5.0
const CAM_ZOOM_MAX := 40.0
const CAM_ZOOM_STEP := 2.0

# Texture paths (loaded gracefully — falls back to color if missing)
const TEX_HULL   := "res://assets/pictures/textures/tex_titanium.png"
const TEX_WING   := "res://assets/pictures/textures/tex_carbon_composite.png"
const TEX_GLASS  := "res://assets/pictures/textures/tex_reinforced_glass.png"
const TEX_IRON   := "res://assets/pictures/textures/tex_aged_iron.png"


# ════════════════════════════════════════════════════════════════════════════
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_viewport()
	_build_hud()
	_init_job()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cam_back = maxf(CAM_ZOOM_MIN, _cam_back - CAM_ZOOM_STEP)
				_cam_up   = _cam_back * 0.36
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cam_back = minf(CAM_ZOOM_MAX, _cam_back + CAM_ZOOM_STEP)
				_cam_up   = _cam_back * 0.36
				get_viewport().set_input_as_handled()


# ── 3D Viewport ──────────────────────────────────────────────────────────────
func _build_viewport() -> void:
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_PASS   # let wheel events reach _unhandled_input
	add_child(vpc)

	_viewport = SubViewport.new()
	_viewport.world_3d        = World3D.new()   # isolated 3D world for this viewport
	_viewport.transparent_bg  = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	_build_environment()
	_build_bg_stars()
	_build_star_systems()
	_build_ship()
	_build_camera()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.004, 0.016, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.12, 0.13, 0.20, 1.0)
	env.ambient_light_energy = 1.2
	env.glow_enabled          = true
	env.glow_normalized       = false
	env.glow_intensity        = 1.3
	env.glow_bloom            = 0.35
	env.glow_blend_mode       = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold    = 0.8
	# Subtle fog for depth
	env.fog_enabled           = true
	env.fog_light_color       = Color(0.03, 0.04, 0.08, 1.0)
	env.fog_density           = 0.0008
	env.fog_light_energy      = 0.2
	env_node.environment = env
	_world.add_child(env_node)

	# Subtle directional "star light" so the ship has shading definition
	var sun := DirectionalLight3D.new()
	sun.light_color    = Color(0.75, 0.82, 1.0)
	sun.light_energy   = 0.35
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	sun.shadow_enabled = false
	_world.add_child(sun)


func _build_bg_stars() -> void:
	# Star color palette for visual variety
	var star_colors: Array[Color] = [
		Color(1.0,  1.0,  1.0),    # white
		Color(0.85, 0.90, 1.0),    # blue-white
		Color(0.70, 0.80, 1.0),    # light blue
		Color(1.0,  0.95, 0.80),   # warm white
		Color(1.0,  0.85, 0.60),   # yellow
		Color(1.0,  0.70, 0.50),   # orange
		Color(0.60, 0.70, 1.0),    # blue
	]

	var base_mesh := SphereMesh.new()
	base_mesh.radius = 0.07
	base_mesh.height = 0.14
	base_mesh.radial_segments = 4
	base_mesh.rings = 2

	var rng := RandomNumberGenerator.new()
	rng.seed = 42314
	for _i in 700:
		var inst := MeshInstance3D.new()
		inst.mesh = base_mesh
		var theta := rng.randf() * TAU
		var phi   := acos(2.0 * rng.randf() - 1.0)
		var r     := rng.randf_range(180.0, 320.0)
		inst.position = Vector3(
			r * sin(phi) * cos(theta),
			r * cos(phi),
			r * sin(phi) * sin(theta))
		# Per-star color + brightness variation
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		var star_clr: Color = star_colors[rng.randi() % star_colors.size()]
		mat.emission = star_clr
		mat.emission_energy_multiplier = rng.randf_range(1.2, 3.5)
		inst.set_surface_override_material(0, mat)
		# Size variation: some stars bigger/brighter
		var sz := rng.randf_range(0.6, 1.8)
		inst.scale = Vector3(sz, sz, sz)
		_world.add_child(inst)


func _build_star_systems() -> void:
	for sd in StarMapData.SYSTEMS:
		var sys_node := Node3D.new()
		sys_node.name     = "sys_" + sd.id
		sys_node.position = sd.pos
		_world.add_child(sys_node)

		# Body mesh
		var sphere := SphereMesh.new()
		sphere.radius          = sd.size * 0.5
		sphere.height          = sd.size
		sphere.radial_segments = 20
		sphere.rings           = 10
		var mat := StandardMaterial3D.new()

		match sd.type:
			"star":
				mat.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.emission_enabled         = true
				mat.emission                 = sd.color
				mat.emission_energy_multiplier = 3.5
				mat.albedo_color             = sd.color
				var light := OmniLight3D.new()
				light.light_color  = sd.color.lightened(0.15)
				light.light_energy = 1.8
				light.omni_range   = 60.0
				sys_node.add_child(light)
			"planet":
				mat.albedo_color = sd.color
				mat.roughness    = 0.65
				mat.metallic     = 0.05
			"station":
				mat.albedo_color             = sd.color
				mat.metallic                 = 0.80
				mat.roughness                = 0.20
				mat.emission_enabled         = true
				mat.emission                 = sd.color
				mat.emission_energy_multiplier = 0.5
			"black_hole":
				mat.albedo_color             = Color(0.0,  0.0,  0.02, 1.0)
				mat.emission_enabled         = true
				mat.emission                 = Color(0.22, 0.0,  0.42, 1.0)
				mat.emission_energy_multiplier = 1.4
			"nebula":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(sd.color.r, sd.color.g, sd.color.b, 0.32)
				mat.emission_enabled         = true
				mat.emission                 = sd.color
				mat.emission_energy_multiplier = 0.35
			"asteroid":
				mat.albedo_color = sd.color
				mat.roughness    = 0.95

		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.set_surface_override_material(0, mat)
		sys_node.add_child(mi)

		_sys_nodes[sd.id] = sys_node

		# Billboard name label
		var lbl := Label3D.new()
		lbl.text          = sd.name
		lbl.font_size     = 22
		lbl.modulate      = Color(0.80, 0.92, 1.0, 0.85)
		lbl.position      = Vector3(0.0, sd.size * 0.65 + 0.6, 0.0)
		lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size    = 0.009
		sys_node.add_child(lbl)


func _build_ship() -> void:
	_ship_pivot = Node3D.new()
	_ship_pivot.name = "ShipPivot"
	_world.add_child(_ship_pivot)

	var vis := Node3D.new()
	vis.name = "ShipVis"
	_ship_pivot.add_child(vis)

	# Texture loader — null on missing file, always safe to use
	var load_tex := func(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null

	var textures: Dictionary = {
		"Power":    load_tex.call(TEX_HULL),
		"Engines":  load_tex.call(TEX_IRON),
		"Command":  load_tex.call(TEX_GLASS),
		"Tactical": load_tex.call(TEX_WING),
		"Utility":  load_tex.call(TEX_HULL),
	}

	var ship_nodes: Array = _params.get("ship_nodes", [])
	var rear_z: float

	if ship_nodes.is_empty():
		rear_z = _build_fallback_hull(vis, textures)
	else:
		rear_z = _build_from_layout(vis, ship_nodes, textures)

	_attach_engine_glow(vis, rear_z)


func _build_from_layout(vis: Node3D, ship_nodes: Array, textures: Dictionary) -> float:
	## Build ship mesh from the player's room layout in the GraphEdit.
	## GraphEdit X  →  ship lateral (3D X: port/starboard)
	## GraphEdit Y  →  ship fore-aft (low Y = nose = -Z, high Y = rear = +Z)
	## Room shape complexity scales with cost tier; texture per room from save data.

	# ── Find bounding box of all room positions ───────────────────────────────
	var min_x := INF;  var max_x := -INF
	var min_y := INF;  var max_y := -INF
	for node in ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		min_x = minf(min_x, sn.hull_pos.x)
		max_x = maxf(max_x, sn.hull_pos.x)
		min_y = minf(min_y, sn.hull_pos.y)
		max_y = maxf(max_y, sn.hull_pos.y)

	var center   := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var extent   := maxf(max_x - min_x, max_y - min_y)
	# Normalise: spread across 5 world units max; min extent avoids single-room div-by-zero
	var px_scale := 5.0 / maxf(extent, 200.0)

	# Per-room texture map passed from main.gd (uid → res:// path)
	var room_textures: Dictionary = _params.get("room_textures", {})

	var max_z := -INF  # rearmost room Z, for engine glow placement

	# ── One compound shape per room, positioned by layout ─────────────────────
	for node in ship_nodes:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue

		var rel      := sn.hull_pos - center
		var room_pos := Vector3(rel.x * px_scale, 0.0, rel.y * px_scale)
		max_z = maxf(max_z, room_pos.z)

		var rtype:    String = def.get("type",     "Utility")
		var universe: String = def.get("universe", "Universal")
		var cost:     int    = def.get("cost", 100)

		# Box size varies by room type
		var box_sz: Vector3
		match rtype:
			"Power":    box_sz = Vector3(1.50, 0.75, 1.50)
			"Engines":  box_sz = Vector3(1.15, 0.55, 1.80)
			"Command":  box_sz = Vector3(1.75, 0.65, 1.35)
			"Tactical": box_sz = Vector3(1.35, 0.60, 1.35)
			_:          box_sz = Vector3(1.25, 0.48, 1.25)

		# Base material: prefer per-room saved texture, fall back to type texture
		var mat := StandardMaterial3D.new()
		mat.albedo_color = RoomData.type_color(rtype).darkened(0.10)
		mat.metallic     = 0.55
		mat.roughness    = 0.40
		var tex_path: String = room_textures.get(sn.node_uid, "")
		var tex: Texture2D = null
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if tex == null:
			tex = textures.get(rtype, null) as Texture2D
		if tex != null:
			mat.albedo_texture = tex

		# Room container node: all shape primitives parented here
		var room_container := Node3D.new()
		room_container.position = room_pos
		vis.add_child(room_container)
		_room_containers.append(room_container)

		# Apply player's 3D layout offsets (from layout editor)
		var layout_3d: Dictionary = _params.get("ship_3d_layout", {})
		if layout_3d.has(sn.node_uid):
			var entry: Dictionary = layout_3d[sn.node_uid]
			room_container.position += Vector3(entry.get("ox", 0.0), entry.get("oy", 0.0), entry.get("oz", 0.0))
			room_container.rotation_degrees.y = entry.get("rot_y", 0.0)
			var s: float = entry.get("scale", 1.0)
			room_container.scale = Vector3(s, s, s)
		# Track rearmost extent including scale and box depth
		var room_rear := room_container.position.z + box_sz.z * 0.5 * room_container.scale.z
		max_z = maxf(max_z, room_rear)

		_build_room_shape(room_container, rtype, universe, cost, mat, box_sz)
		_add_room_lights(room_container, rtype, box_sz)

	# ── Compute hull adjacency map for gameplay bonuses ──────────────────────
	_adjacencies = ShipBlueprint.compute_adjacencies(ship_nodes)
	if not _adjacencies.is_empty():
		var total_pairs := 0
		for uid in _adjacencies:
			total_pairs += (_adjacencies[uid] as Array).size()
		total_pairs /= 2  # each pair counted twice
		if total_pairs > 0:
			_log("[color=#55cc77]* Hull adjacency: %d room pair%s detected[/color]" % [
				total_pairs, "s" if total_pairs != 1 else ""])

	return maxf(max_z, 0.0) + 1.0   # engine glow just behind rearmost room


func _build_room_shape(container: Node3D, rtype: String, universe: String,
		cost: int, base_mat: StandardMaterial3D, box_sz: Vector3) -> void:
	ShipBuilder3D.build_room_shape(container, rtype, universe, cost, base_mat, box_sz)


func _add_room_lights(container: Node3D, rtype: String, sz: Vector3) -> void:
	ShipBuilder3D.add_room_lights(container, rtype, sz)


# ── Combat explosion VFX ─────────────────────────────────────────────────────

func _spawn_explosion(room_idx: int) -> void:
	## Spawn a fiery explosion burst on the room at `room_idx`.
	if room_idx < 0 or room_idx >= _room_containers.size():
		return
	var container: Node3D = _room_containers[room_idx]

	# Room is parented to _ship_pivot child (vis) — get world position
	var world_pos: Vector3 = container.global_position

	# ── Flash sphere (quick bright expand + fade) ────────────────────────
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6;  sphere.height = 1.2
	sphere.radial_segments = 12;  sphere.rings = 6
	flash.mesh = sphere
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.95)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.6, 0.15)
	flash_mat.emission_energy_multiplier = 4.0
	flash.set_surface_override_material(0, flash_mat)
	flash.global_position = world_pos
	_world.add_child(flash)

	# ── Debris sparks (small bright spheres flying outward) ──────────────
	var sparks: Array[MeshInstance3D] = []
	var spark_dirs: Array[Vector3] = []
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.12;  spark_mesh.height = 0.24
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.4, 0.05)
	spark_mat.emission_energy_multiplier = 3.0
	for i in 8:
		var sp := MeshInstance3D.new()
		sp.mesh = spark_mesh
		sp.set_surface_override_material(0, spark_mat)
		sp.global_position = world_pos
		_world.add_child(sp)
		sparks.append(sp)
		spark_dirs.append(Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.2, 1.0),
			randf_range(-1.0, 1.0)
		).normalized())

	# ── Omni light flash ────────────────────────────────────────────────
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.global_position = world_pos
	_world.add_child(light)

	# ── Animate via tween ────────────────────────────────────────────────
	var tw := create_tween()
	tw.set_parallel(true)

	# Flash sphere: expand + fade out over 0.6s
	tw.tween_property(flash, "scale", Vector3(3.5, 3.5, 3.5), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.5).set_delay(0.1)

	# Sparks: fly outward over 0.8s then fade
	for i in sparks.size():
		var target_pos := world_pos + spark_dirs[i] * randf_range(2.5, 5.0)
		tw.tween_property(sparks[i], "global_position", target_pos, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(spark_mat, "albedo_color:a", 0.0, 0.4).set_delay(0.5)

	# Light: fade out
	tw.tween_property(light, "light_energy", 0.0, 0.7)

	# Cleanup after animation
	tw.set_parallel(false)
	tw.tween_callback(func():
		flash.queue_free()
		for sp in sparks:
			sp.queue_free()
		light.queue_free()
	).set_delay(1.0)


func _build_fallback_hull(vis: Node3D, textures: Dictionary) -> float:
	## Minimal static hull shown when no rooms have been placed yet.
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.90, 0.42, 2.90)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.43, 0.54, 1.0)
	mat.metallic     = 0.65
	mat.roughness    = 0.30
	var tex: Texture2D = textures.get("Power", null) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	vis.add_child(mi)
	return 1.55


func _attach_engine_glow(vis: Node3D, rear_z: float) -> void:
	## Emissive glow sphere placed at the rear of the ship (+Z = aft).
	_engine_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius          = 0.30
	glow_mesh.height          = 0.60
	glow_mesh.radial_segments = 10
	glow_mesh.rings           = 6
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled           = true
	glow_mat.emission                   = Color(0.35, 0.65, 1.00, 1.0)
	glow_mat.emission_energy_multiplier = 5.0
	_engine_glow.mesh = glow_mesh
	_engine_glow.set_surface_override_material(0, glow_mat)
	_engine_glow.position = Vector3(0.0, 0.0, rear_z)
	vis.add_child(_engine_glow)

	var eng_light := OmniLight3D.new()
	eng_light.light_color  = Color(0.30, 0.60, 1.00, 1.0)
	eng_light.light_energy = 2.5
	eng_light.omni_range   = 8.0
	_engine_glow.add_child(eng_light)

	# Engine exhaust trail particles
	_engine_trail = GPUParticles3D.new()
	_engine_trail.amount = 60
	_engine_trail.lifetime = 1.5
	_engine_trail.speed_scale = 1.0
	_engine_trail.local_coords = false  # particles stay in world space = trail effect
	_engine_trail.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))

	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(0.0, 0.0, 1.0)   # emit backward
	trail_mat.spread = 8.0
	trail_mat.initial_velocity_min = 1.5
	trail_mat.initial_velocity_max = 3.0
	trail_mat.gravity = Vector3.ZERO
	trail_mat.damping_min = 1.0
	trail_mat.damping_max = 2.0
	trail_mat.scale_min = 0.6
	trail_mat.scale_max = 1.2
	trail_mat.color = Color(0.3, 0.55, 1.0, 0.7)
	var trail_gradient := GradientTexture1D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.7, 1.0, 0.8))
	grad.add_point(0.4, Color(0.25, 0.45, 0.9, 0.5))
	grad.set_color(2, Color(0.1, 0.2, 0.6, 0.0))
	trail_gradient.gradient = grad
	trail_mat.color_ramp = trail_gradient
	_engine_trail.process_material = trail_mat

	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.06
	trail_mesh.height = 0.12
	trail_mesh.radial_segments = 4
	trail_mesh.rings = 2
	var trail_draw_mat := StandardMaterial3D.new()
	trail_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_draw_mat.emission_enabled = true
	trail_draw_mat.emission = Color(0.3, 0.55, 1.0)
	trail_draw_mat.emission_energy_multiplier = 2.5
	trail_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_draw_mat.vertex_color_use_as_albedo = true
	trail_mesh.surface_set_material(0, trail_draw_mat)
	_engine_trail.draw_pass_1 = trail_mesh

	_engine_trail.position = Vector3(0.0, 0.0, rear_z + 0.3)
	vis.add_child(_engine_trail)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 65.0
	_world.add_child(_camera)
	# Initial position set in _init_job after waypoints are known


# ── HUD ──────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	# ── Top bar ──────────────────────────────────────────────────────────────
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size.y = 50
	top_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.04, 0.06, 0.12, 0.86)
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	top_panel.add_child(hbox)

	_add_sp(hbox, 10)

	var lbl_tag := _hlabel("◈ IN TRANSIT", 10, Color(0.50, 0.78, 1.0, 1.0))
	lbl_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl_tag)

	hbox.add_child(_vsep())

	_lbl_system = _hlabel("—", 15, Color(0.90, 0.95, 1.0, 1.0))
	hbox.add_child(_lbl_system)

	hbox.add_child(_vsep())

	_lbl_route = _hlabel("→  —", 11, Color(0.60, 0.75, 0.95, 1.0))
	hbox.add_child(_lbl_route)

	# Expand filler
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(fill)

	_lbl_day = _hlabel("Day 0", 12, Color(0.80, 0.88, 1.0, 1.0))
	hbox.add_child(_lbl_day)

	hbox.add_child(_vsep())

	_btn_speed = Button.new()
	_btn_speed.text = "▶  1×"
	_btn_speed.flat = true
	_btn_speed.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 1.0))
	_btn_speed.add_theme_font_size_override("font_size", 12)
	_btn_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_btn_speed.pressed.connect(_cycle_speed)
	hbox.add_child(_btn_speed)

	_add_sp(hbox, 10)

	# ── Bottom log ───────────────────────────────────────────────────────────
	var bot_panel := PanelContainer.new()
	bot_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_panel.custom_minimum_size.y = 115
	bot_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.03, 0.05, 0.10, 0.82)
	bot_panel.add_theme_stylebox_override("panel", bot_style)
	add_child(bot_panel)

	_log_box = RichTextLabel.new()
	_log_box.bbcode_enabled   = true
	_log_box.scroll_following = true
	_log_box.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	_log_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_box.add_theme_font_size_override("normal_font_size", 11)
	bot_panel.add_child(_log_box)

	# Flush any log lines that were queued before the HUD was built
	for line in _log_lines:
		_log_box.append_text(line + "\n")


func _hlabel(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return lbl


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.add_theme_color_override("color", Color(0.20, 0.28, 0.44, 1.0))
	return s


func _add_sp(parent: Control, w: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.x = w
	parent.add_child(sp)


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_box != null:
		_log_box.append_text(msg + "\n")


# ── Job initialization ────────────────────────────────────────────────────────
func _init_job() -> void:
	var days:       int    = _params.get("days",       7)
	var pwr:        int    = _params.get("power",      0)
	var node_count: int    = _params.get("node_count", 0)
	var name_str:   String = _params.get("ship_name",  "Ship")
	var cur_sys:    String = _params.get("current_system", "sol")
	_ship_nodes_ref = _params.get("ship_nodes", [])

	# ── Build path ──────────────────────────────────────────────────────────
	var dest_id: String = _params.get("destination_id", "")
	var dest_sys: Dictionary
	if not dest_id.is_empty():
		dest_sys = StarMapData.find_system(dest_id)
	if dest_sys.is_empty():
		var discovered: Array = _params.get("discovered", [])
		dest_sys = StarMapData.pick_destination(days, cur_sys, discovered)
	_path_ids = StarMapData.build_path(cur_sys, dest_sys.id, days)

	for sid in _path_ids:
		var s := StarMapData.find_system(sid)
		if not s.is_empty():
			_waypoints.append(s.pos)
			_wp_names.append(s.name)

	# Fallback if path is too short
	if _waypoints.size() < 2:
		_waypoints = [Vector3.ZERO, Vector3(12, 2, 8)]
		_wp_names  = ["Sol", "Proxima Centauri"]

	# ── Pull final waypoint back so ship parks near destination ───────────────
	# (stops in front of the system rather than flying through it)
	var approach: Vector3 = (_waypoints[-1] - _waypoints[-2]).normalized()
	var dest_sd := StarMapData.find_system(_path_ids[-1] if not _path_ids.is_empty() else "sol")
	var park_back: float = dest_sd.get("size", 2.0) * 0.5 + 3.5
	_waypoints[-1] = _waypoints[-1] - approach * park_back

	# ── Departure cinematic: launch from above origin, sweep past it ──────────
	# Inserts 2 pre-travel waypoints so the ship starts high above the
	# origin star, arcs down through it, then lines up for the real journey.
	var origin_name: String = _wp_names[0] if not _wp_names.is_empty() else "Origin"
	var orig_pos: Vector3   = _waypoints[0]
	var to_dest:  Vector3   = (_waypoints[-1] - orig_pos).normalized() \
		if _waypoints.size() >= 2 else Vector3.FORWARD
	var launch_pos := orig_pos - to_dest * 15.0 + Vector3.UP * 11.0
	var flyby_pos  := orig_pos + to_dest *  5.5 + Vector3.UP *  1.5
	_waypoints.insert(0, launch_pos)
	_waypoints.insert(1, flyby_pos)
	_wp_names.insert(0, "Launching")
	_wp_names.insert(1, "Departing " + origin_name)
	_n_cinematic_segs = 2

	# ── Compute midpoint camera observation post ─────────────────────────────
	# Camera will park here during phase 1, watching the ship approach & fly by.
	var real_origin := _waypoints[_n_cinematic_segs]    # first actual system
	var real_dest   := _waypoints[-1]                   # destination system
	var mid_pos     := real_origin.lerp(real_dest, 0.5)
	_cam_travel_dir  = (real_dest - real_origin).normalized()
	# Offset to the side + above so the ship doesn't fly straight into the lens
	var perp := _cam_travel_dir.cross(Vector3.UP).normalized()
	_cam_midpoint = mid_pos + perp * 10.0 + Vector3.UP * 6.0
	_cam_phase = 0

	# ── Place ship at origin ─────────────────────────────────────────────────
	_ship_pivot.global_position = _waypoints[0]

	# ── Initial camera ───────────────────────────────────────────────────────
	var initial_forward := (_waypoints[1] - _waypoints[0]).normalized()
	_camera.global_position = _waypoints[0] - initial_forward * _cam_back + Vector3.UP * _cam_up
	if _camera.global_position.distance_squared_to(_waypoints[0] + initial_forward * CAM_AHEAD) > 0.01:
		_camera.look_at(_waypoints[0] + initial_forward * CAM_AHEAD, Vector3.UP)

	# ── Base earnings ────────────────────────────────────────────────────────
	var job_pay_per_day: int = _params.get("job_pay_per_day", 0)
	if job_pay_per_day > 0:
		# Job board pay rate — ship bonuses stack on top
		var power_bonus: int = maxi(0, pwr / 100) * 10
		var room_bonus:  int = node_count * 5
		_earned = days * (job_pay_per_day + power_bonus + room_bonus)
	else:
		# Fallback legacy calculation
		var power_bonus: int = maxi(0, pwr / 100) * 10
		var room_bonus:  int = node_count * 5
		_earned = days * (50 + power_bonus + room_bonus)
	if pwr < 0:
		_earned = int(_earned * 0.7)

	# Cargo loading bonus from puzzle
	var cargo_bonus: int = _params.get("cargo_bonus", 0)
	if cargo_bonus > 0:
		_earned += cargo_bonus

	# ── Pre-roll travel events ───────────────────────────────────────────────
	_pre_roll_events(days, node_count)

	# ── HUD initial state ────────────────────────────────────────────────────
	_lbl_system.text = _wp_names[0]
	_lbl_route.text  = "→  " + _wp_names[-1]
	_lbl_day.text    = "Day 1 / %d" % days

	# ── Opening log ──────────────────────────────────────────────────────────
	var job_type: String = _params.get("job_type", "")
	var job_label: String = "  —  %d-day voyage to %s" % [days, _wp_names[-1]]
	if not job_type.is_empty():
		job_label = "  —  %s  —  %d days to %s" % [job_type, days, _wp_names[-1]]
	_log("[color=#4488ff]═══  %s%s  ═══[/color]" % [name_str, job_label])
	_log("[color=#6688cc]  Departing %s. Engines spooling up…[/color]" % origin_name)
	# Show real waypoints (skip the 2 cinematic entries at the front)
	if _wp_names.size() > _n_cinematic_segs + 2:
		var stops := _wp_names.slice(_n_cinematic_segs + 1, -1)
		_log("[color=#6677aa]  Via: %s[/color]" % ", ".join(stops))
	if pwr < 0:
		_log("[color=#ff6644]⚠ Negative power grid — earnings reduced.[/color]")

	# ── Begin travel ─────────────────────────────────────────────────────────
	_seg_duration = _calc_seg_duration(0, days)
	_traveling    = true


func _calc_seg_duration(idx: int, days: int) -> float:
	if idx >= _waypoints.size() - 1:
		return 1.0
	# Pre-travel cinematic segments run for a fixed real-time duration
	if idx < _n_cinematic_segs:
		return 6.0
	# Real travel segments share the full journey time proportionally by distance
	var real_total: float = 0.0
	for i in range(_n_cinematic_segs, _waypoints.size() - 1):
		real_total += _waypoints[i].distance_to(_waypoints[i + 1])
	if real_total <= 0.0:
		return 1.0
	var seg_dist := _waypoints[idx].distance_to(_waypoints[idx + 1])
	return (seg_dist / real_total) * float(days) * DAY_SECS


func _pre_roll_events(days: int, node_count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n_events: int = maxi(1, days / 3)
	var used: Array = []

	# Scale damage by job pay — every 50 cr/day above 0 adds bite
	var pay: int = _params.get("job_pay_per_day", 0)
	var pay_tier: int = clampi(pay / 50, 0, 3)   # 0-3 based on ~0, 50, 100, 150+ cr/day
	var dmg_min: int = 5  + pay_tier * 4          # 5 / 9 / 13 / 17
	var dmg_max: int = 22 + pay_tier * 8          # 22 / 30 / 38 / 46

	for _i in range(n_events):
		# Pick a milestone (0..1 along whole journey), avoid clustering
		var at := rng.randf_range(0.05, 0.95)
		for _t in 10:
			var ok := true
			for m in used:
				if abs(at - float(m)) < 0.08:
					ok = false
					break
			if ok:
				break
			at = rng.randf_range(0.05, 0.95)
		used.append(at)

		var roll := rng.randi_range(1, 100)
		var ev:  Dictionary
		if roll <= 20 and node_count > 0:
			var dmg := rng.randi_range(dmg_min, dmg_max)
			var tgt := rng.randi_range(0, node_count - 1)
			if roll <= 14:
				# Hostile attacker — Tactical rooms can fight back
				# Higher-paying jobs attract tougher enemies
				var attacker_table := [
					{"name": "Pirate Scout",   "sal_min": 50,  "sal_max": 180},
					{"name": "Raider",         "sal_min": 120, "sal_max": 320},
					{"name": "Bounty Hunter",  "sal_min": 280, "sal_max": 550},
					{"name": "Patrol Craft",   "sal_min": 400, "sal_max": 750},
				]
				var att_min_idx: int = maxi(0, pay_tier - 1)
				var att_max_idx: int = mini(attacker_table.size() - 1, pay_tier + 1)
				var att: Dictionary = attacker_table[rng.randi_range(att_min_idx, att_max_idx)]
				ev = { "at":at, "type":"combat", "amount":dmg, "target_idx":tgt,
					"attacker": att.name, "sal_min": att.sal_min, "sal_max": att.sal_max }
			else:
				# Hazard damage — no counter-fire (asteroid, malfunction, etc.)
				ev = { "at":at, "type":"damage", "amount":dmg, "target_idx":tgt }
		elif roll <= 40:
			var bonus := rng.randi_range(120, 450)
			ev = { "at":at, "type":"bonus", "amount":bonus, "msg":"Diplomatic contract" }
		elif roll <= 60:
			var cargo := rng.randi_range(80, 320)
			ev = { "at":at, "type":"bonus", "amount":cargo, "msg":"Profitable cargo run" }
		else:
			ev = { "at":at, "type":"routine" }
		_events.append(ev)

	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.at) < float(b.at))


# ── Travel loop ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _traveling:
		return

	var days: int = _params.get("days", 7)
	var scaled := delta * _time_scale

	# ── Day tracking & passive wear (skipped during cinematic intro) ──────────
	if _wp_index >= _n_cinematic_segs:
		_day_accumulator += scaled / DAY_SECS
		while _day_accumulator >= 1.0:
			_day_accumulator -= 1.0
			_days_elapsed    += 1
			_lbl_day.text = "Day %d / %d" % [_days_elapsed + 1, days]
			_apply_daily_wear()

	# ── Advance segment progress ─────────────────────────────────────────────
	_seg_progress += scaled / _seg_duration

	# ── Interpolate ship position with gentle lateral drift ──────────────────
	var p0 := _waypoints[_wp_index]
	var p1 := _waypoints[_wp_index + 1]
	var t  := minf(_seg_progress, 1.0)

	var seg_dir  := p1 - p0
	var perp     := seg_dir.cross(Vector3.UP).normalized()
	var drift    := sin(t * PI) * minf(seg_dir.length() * 0.07, 2.5)
	_ship_pivot.global_position = p0.lerp(p1, t) + perp * drift

	# ── Orient ship toward travel direction ──────────────────────────────────
	var forward := seg_dir.normalized()
	if forward.length_squared() > 0.01:
		var look_target := _ship_pivot.global_position + forward
		if look_target.distance_squared_to(_ship_pivot.global_position) > 0.001:
			_ship_pivot.look_at(look_target, Vector3.UP)

	# ── Engine glow pulse ─────────────────────────────────────────────────────
	if _engine_glow:
		var pulse := 0.88 + sin(Time.get_ticks_msec() * 0.005) * 0.12
		_engine_glow.scale = Vector3.ONE * pulse

	# ── Camera follow ─────────────────────────────────────────────────────────
	_update_camera(delta, forward)

	# ── Proximity fade for star systems (real-time delta, not scaled) ─────────
	_update_system_fades(delta)

	# ── Fire pre-rolled events ────────────────────────────────────────────────
	_check_events()

	# ── Waypoint advance ──────────────────────────────────────────────────────
	if _seg_progress >= 1.0:
		_wp_index += 1
		if _wp_index >= _waypoints.size() - 1:
			_ship_pivot.global_position = _waypoints[-1]
			_traveling = false
			_finish_travel()
		else:
			_seg_progress = 0.0
			_seg_duration = _calc_seg_duration(_wp_index, days)
			_lbl_system.text = _wp_names[_wp_index]
			if _wp_index == _n_cinematic_segs:
				# First real waypoint — origin system, course now locked
				_log("[color=#88aaff]  Course locked. Initiating FTL burn.[/color]")
			elif _wp_index > _n_cinematic_segs:
				_log("[color=#aaccff]→ Passing through %s[/color]" % _wp_names[_wp_index])


func _update_camera(delta: float, forward: Vector3) -> void:
	var ship_pos := _ship_pivot.global_position

	# ── Phase 0: departure cinematic — slow chase behind the ship ─────────
	if _cam_phase == 0:
		var target_cam := ship_pos - forward * _cam_back + Vector3.UP * _cam_up
		_camera.global_position = _camera.global_position.lerp(target_cam, delta * 1.0)
		var look_target := ship_pos + forward * CAM_AHEAD
		if look_target.distance_squared_to(_camera.global_position) > 0.04:
			var target_xform := _camera.global_transform.looking_at(look_target, Vector3.UP)
			_camera.global_transform = \
				_camera.global_transform.interpolate_with(target_xform, delta * 1.8)
		# Transition → phase 1 once departure cinematic segments end
		if _wp_index >= _n_cinematic_segs:
			_cam_phase = 1

	# ── Phase 1: stationary flyby — camera parked at midpoint, tracks ship ─
	elif _cam_phase == 1:
		# Smoothly glide camera to the midpoint observation post
		_camera.global_position = _camera.global_position.lerp(_cam_midpoint, delta * 1.6)
		# Always look at the ship
		if ship_pos.distance_squared_to(_camera.global_position) > 0.04:
			var target_xform := _camera.global_transform.looking_at(ship_pos, Vector3.UP)
			_camera.global_transform = \
				_camera.global_transform.interpolate_with(target_xform, delta * 4.0)
		# Transition → phase 2 once ship passes the midpoint (dot product flips sign)
		var to_ship := ship_pos - _cam_midpoint
		var passed  := to_ship.dot(_cam_travel_dir) > 6.0  # ship is 6 units past midpoint
		if passed:
			_cam_phase = 2

	# ── Phase 2: chase follow — classic behind-the-ship camera ────────────
	else:
		var target_cam := ship_pos - forward * _cam_back + Vector3.UP * _cam_up
		_camera.global_position = _camera.global_position.lerp(target_cam, delta * 2.2)
		var look_target := ship_pos + forward * CAM_AHEAD
		if look_target.distance_squared_to(_camera.global_position) > 0.04:
			var target_xform := _camera.global_transform.looking_at(look_target, Vector3.UP)
			_camera.global_transform = \
				_camera.global_transform.interpolate_with(target_xform, delta * 5.0)


func _update_system_fades(delta: float) -> void:
	## Smooth distance-based fade: systems become transparent as ship approaches.
	## Uses raw delta so fade speed is independent of the time-scale multiplier.
	var ship_pos := _ship_pivot.global_position
	for sys_id in _sys_nodes:
		var sys_node: Node3D = _sys_nodes[sys_id]
		if not is_instance_valid(sys_node):
			continue
		var sys := StarMapData.find_system(sys_id)
		if sys.is_empty():
			continue
		var dist:      float = ship_pos.distance_to(sys.pos as Vector3)
		var radius:    float = float(sys.get("size", 2.0)) * 0.5
		var fade_start: float = radius + 6.0  # start fading at this distance
		var fade_end:   float = radius + 1.5  # fully transparent at this distance
		# Smooth gradient: 0 = fully opaque, 0.88 = fully transparent
		var target_t: float = 0.0
		if dist < fade_start:
			target_t = clampf(1.0 - (dist - fade_end) / (fade_start - fade_end), 0.0, 1.0) * 0.88
		var spd: float = delta * 5.0
		for child in sys_node.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).transparency = \
					lerpf((child as MeshInstance3D).transparency, target_t, spd)
			elif child is Label3D:
				(child as Label3D).modulate.a = \
					lerpf((child as Label3D).modulate.a, 1.0 - target_t * 0.85, spd)
			elif child is OmniLight3D:
				(child as OmniLight3D).light_energy = \
					lerpf((child as OmniLight3D).light_energy, 1.8 * (1.0 - target_t), spd)


func _apply_daily_wear() -> void:
	## Passive hull wear each in-game day. Engines & Power take more.
	## Harsh destination systems add extra wear.
	## Crew assigned to matching rooms reduce wear.
	## Adjacency bonuses: Engines adj Power = -1, Utility adj any = -1 on neighbor.
	var dest_id: String = _path_ids[-1] if not _path_ids.is_empty() else ""
	var harsh := StarMapData.is_harsh(dest_id)
	var crew: Array = _params.get("crew", [])

	# ── Pre-compute adjacency wear reductions ────────────────────────────────
	# adj_wear_bonus[node_uid] = total adjacency-based wear reduction (capped at 2)
	var adj_wear_bonus: Dictionary = {}
	for node in _ship_nodes_ref:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		var rtype: String = def.get("type", "")
		var neighbors: Array = _adjacencies.get(sn.node_uid, [])

		# Engines adjacent to Power → Engines gets -1 wear
		if rtype == "Engines":
			for adj in neighbors:
				if (adj as Dictionary).get("type", "") == "Power":
					adj_wear_bonus[sn.node_uid] = mini(
						(adj_wear_bonus.get(sn.node_uid, 0) as int) + 1, 2)
					break  # only once per Power neighbor

		# Utility adjacent to any room → that neighbor gets -1 wear
		if rtype == "Utility":
			for adj in neighbors:
				var adj_uid: String = (adj as Dictionary).get("uid", "")
				if not adj_uid.is_empty():
					adj_wear_bonus[adj_uid] = mini(
						(adj_wear_bonus.get(adj_uid, 0) as int) + 1, 2)

	for node in _ship_nodes_ref:
		var ship_node := node as ShipNode
		if ship_node == null:
			continue
		var def := RoomData.find(ship_node.def_id)
		var wear := 1
		match def.get("type", ""):
			"Engines": wear = 2
			"Power":   wear = 2
			_:         wear = 1
		if harsh:
			wear += 1
		if _params.get("power", 0) < 0:
			wear += 1

		# Crew reduction: matching role assigned to this room reduces wear
		var crew_reduced := false
		for cm in crew:
			if cm.get("assigned_to", "") == ship_node.node_uid and cm.get("status", "") == "active":
				var crew_type: String = CrewData.room_type_for_role(cm.get("role", ""))
				if crew_type == def.get("type", "") and cm.get("efficiency", 0.0) >= 0.5:
					wear = maxi(0, wear - 1)
					crew_reduced = true
					break

		# Adjacency reduction (capped at 2 total from all adjacency sources)
		var adj_red: int = adj_wear_bonus.get(ship_node.node_uid, 0) as int
		if adj_red > 0:
			wear = maxi(0, wear - adj_red)

		ship_node.apply_damage(wear)

		if crew_reduced and wear > 0 and _days_elapsed == 1:
			_log("[color=#44aaff]🔧 %s reduces wear on %s[/color]" % [
				_find_crew_name(crew, ship_node.node_uid), ship_node.title])

		if adj_red > 0 and _days_elapsed == 1:
			_log("[color=#55cc77]* Adjacency: -%d wear on %s[/color]" % [adj_red, ship_node.title])

		if ship_node.current_durability == 0:
			_log("[color=#ff3311]⚠ CRITICAL: %s has failed![/color]" % ship_node.title)


func _find_crew_name(crew: Array, node_uid: String) -> String:
	for cm in crew:
		if cm.get("assigned_to", "") == node_uid:
			return cm.get("name", "Crew")
	return "Crew"


func _check_events() -> void:
	# Events only fire during real travel segments, not during the cinematic intro
	if _wp_index < _n_cinematic_segs:
		return
	var real_segs: int = (_waypoints.size() - 1) - _n_cinematic_segs
	if real_segs <= 0:
		return
	var real_idx := _wp_index - _n_cinematic_segs
	var norm := (float(real_idx) + minf(_seg_progress, 1.0)) / float(real_segs)
	for i in range(_events.size()):
		if _events_done.has(i):
			continue
		if norm >= float(_events[i].at):
			_fire_event(_events[i])
			_events_done.append(i)


func _fire_event(ev: Dictionary) -> void:
	var crew: Array = _params.get("crew", [])

	match ev.type:
		"damage":
			var idx: int = ev.get("target_idx", 0)
			if idx < _ship_nodes_ref.size():
				var target := _ship_nodes_ref[idx] as ShipNode
				var dmg:    int = ev.get("amount", 10)

				# Security crew in Tactical rooms reduce combat damage
				var sec_eff := _best_crew_efficiency(crew, "Security", "Tactical")
				if sec_eff > 0.0:
					var reduction := int(float(dmg) * sec_eff * 0.3)
					dmg = maxi(1, dmg - reduction)
					_log("[color=#44aaff]🛡 Security crew mitigated %d damage[/color]" % reduction)

				# Adjacency bonus: Tactical adjacent to Command → extra 10% dmg reduction
				# Tactical adjacent to Power → extra 5% reduction
				var adj_dmg_pct := 0.0
				for node in _ship_nodes_ref:
					var sn := node as ShipNode
					if sn == null: continue
					var sn_def := RoomData.find(sn.def_id)
					if sn_def.is_empty(): continue
					if sn_def.get("type", "") != "Tactical": continue
					var neighbors: Array = _adjacencies.get(sn.node_uid, [])
					for adj in neighbors:
						var adj_type: String = (adj as Dictionary).get("type", "")
						if adj_type == "Command":
							adj_dmg_pct += 0.10
						elif adj_type == "Power":
							adj_dmg_pct += 0.05
				adj_dmg_pct = minf(adj_dmg_pct, 0.25)  # cap at 25%
				if adj_dmg_pct > 0.0:
					var adj_red := int(float(dmg) * adj_dmg_pct)
					if adj_red > 0:
						dmg = maxi(1, dmg - adj_red)
						_log("[color=#55cc77]* Hull synergy: Tactical adjacency reduced %d damage[/color]" % adj_red)

				target.apply_damage(dmg)
				_spawn_explosion(idx)
				_earned -= randi_range(50, 180)
				_earned  = maxi(0, _earned)
				_log("[color=#ff5533]⚠ Combat! -%d dur to [b]%s[/b].[/color]" % [dmg, target.title])
		"combat":
			var cidx: int        = ev.get("target_idx", 0)
			var attacker: String = ev.get("attacker", "Unknown")
			var cdmg: int        = ev.get("amount", 10)

			# Security crew mitigation
			var sec_eff2 := _best_crew_efficiency(crew, "Security", "Tactical")
			if sec_eff2 > 0.0:
				var creduction := int(float(cdmg) * sec_eff2 * 0.3)
				cdmg = maxi(1, cdmg - creduction)
				_log("[color=#44aaff]🛡 Security crew mitigated %d damage[/color]" % creduction)

			# Tactical adjacency damage reduction
			var cadj_pct := 0.0
			for cnode in _ship_nodes_ref:
				var csn := cnode as ShipNode
				if csn == null: continue
				var csn_def := RoomData.find(csn.def_id)
				if csn_def.is_empty(): continue
				if csn_def.get("type", "") != "Tactical": continue
				var cneighbors: Array = _adjacencies.get(csn.node_uid, [])
				for cadj in cneighbors:
					var cadj_type: String = (cadj as Dictionary).get("type", "")
					if cadj_type == "Command":  cadj_pct += 0.10
					elif cadj_type == "Power":  cadj_pct += 0.05
			cadj_pct = minf(cadj_pct, 0.25)
			if cadj_pct > 0.0:
				var cadj_red := int(float(cdmg) * cadj_pct)
				if cadj_red > 0:
					cdmg = maxi(1, cdmg - cadj_red)
					_log("[color=#55cc77]* Hull synergy: Tactical adjacency reduced %d damage[/color]" % cadj_red)

			# Apply incoming hit
			if cidx < _ship_nodes_ref.size():
				var ctarget := _ship_nodes_ref[cidx] as ShipNode
				ctarget.apply_damage(cdmg)
				_spawn_explosion(cidx)
				_log("[color=#ff5533]⚠ [b]%s[/b] attacking! -%d dur to [b]%s[/b][/color]" \
					% [attacker, cdmg, ctarget.title])
			_earned -= randi_range(50, 180)
			_earned  = maxi(0, _earned)

			# ── Counter-fire resolution ───────────────────────────────────────
			var hit_pct := _tactical_hit_chance()
			if hit_pct <= 0.0:
				_log("[color=#888888]  No Tactical systems to return fire.[/color]")
			else:
				var tac_count := _count_effective_tactical()
				_log("[color=#88ccff]🎯 %d Tactical room(s) engaging... (%.0f%% hit)[/color]" \
					% [tac_count, hit_pct * 100.0])
				if randf() < hit_pct:
					var salvage := randi_range(ev.get("sal_min", 50), ev.get("sal_max", 200))
					_earned += salvage
					_spawn_counter_shot(true)
					_log("[color=#44ff88]💥 Direct hit! [b]%s[/b] destroyed.[/color]" % attacker)
					_log("[color=#ffd050]  Salvage recovered: +%d cr[/color]" % salvage)
				else:
					_spawn_counter_shot(false)
					_log("[color=#ff8844]✗ Missed! [b]%s[/b] returns fire![/color]" % attacker)
					if not _ship_nodes_ref.is_empty():
						var tgt2 := randi_range(0, _ship_nodes_ref.size() - 1)
						var t2   := _ship_nodes_ref[tgt2] as ShipNode
						var dmg2 := randi_range(3, 14)
						t2.apply_damage(dmg2)
						_spawn_explosion(tgt2)
						_log("[color=#ff3311]⚠ Retaliation! -%d dur to [b]%s[/b][/color]" \
							% [dmg2, t2.title])
		"bonus":
			var amt: int = ev.get("amount", 100)

			# Officer crew in Command rooms boost bonus payouts
			var off_eff := _best_crew_efficiency(crew, "Officer", "Command")
			if off_eff > 0.0:
				var bonus_extra := int(float(amt) * off_eff * 0.2)
				amt += bonus_extra
				_log("[color=#44aaff]📋 Officer negotiated +%d cr bonus[/color]" % bonus_extra)

			# Adjacency bonus: Command adjacent to any room → +5% payout per neighbor (max +15%)
			var cmd_adj_count := 0
			for node in _ship_nodes_ref:
				var sn := node as ShipNode
				if sn == null: continue
				var sn_def := RoomData.find(sn.def_id)
				if sn_def.is_empty(): continue
				if sn_def.get("type", "") == "Command":
					cmd_adj_count += (_adjacencies.get(sn.node_uid, []) as Array).size()
			cmd_adj_count = mini(cmd_adj_count, 3)  # cap at 3 neighbors = +15%
			if cmd_adj_count > 0:
				var adj_bonus := int(float(amt) * 0.05 * float(cmd_adj_count))
				if adj_bonus > 0:
					amt += adj_bonus
					_log("[color=#55cc77]* Hull synergy: Command adjacency +%d cr[/color]" % adj_bonus)

			_earned += amt
			_log("[color=#44ee88]✔ %s — +%d cr[/color]" % [ev.get("msg", "Bonus"), amt])
		"routine":
			_log("[color=#556677]  Routine transit.[/color]")


func _best_crew_efficiency(crew: Array, role: String, room_type: String) -> float:
	## Find the best efficiency among crew of the given role assigned to matching rooms.
	var best := 0.0
	for cm in crew:
		if cm.get("role", "") != role or cm.get("status", "") != "active":
			continue
		var assigned: String = cm.get("assigned_to", "")
		if assigned.is_empty():
			continue
		# Check the assigned room type
		for node in _ship_nodes_ref:
			var sn := node as ShipNode
			if sn != null and sn.node_uid == assigned:
				var def := RoomData.find(sn.def_id)
				if not def.is_empty() and def.get("type", "") == room_type:
					best = maxf(best, cm.get("efficiency", 0.0))
				break
	return best


# ── Combat helpers ────────────────────────────────────────────────────────────

func _count_effective_tactical() -> int:
	## Count Tactical rooms with enough durability to fire (>25% health).
	var count := 0
	for node in _ship_nodes_ref:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if def.get("type", "") == "Tactical" and sn.max_durability > 0:
			if float(sn.current_durability) / float(sn.max_durability) > 0.25:
				count += 1
	return count


func _avg_room_health(rtype: String) -> float:
	## Average durability ratio for all rooms of a given type (1.0 if none present).
	var total := 0.0
	var count := 0
	for node in _ship_nodes_ref:
		var sn := node as ShipNode
		if sn == null: continue
		var def := RoomData.find(sn.def_id)
		if def.is_empty(): continue
		if def.get("type", "") == rtype and sn.max_durability > 0:
			total += float(sn.current_durability) / float(sn.max_durability)
			count += 1
	return total / float(count) if count > 0 else 1.0


func _tactical_hit_chance() -> float:
	## Hit probability for counter-fire. Diminishing returns per Tactical room.
	## 1→35%  2→57%  3→72%  4+→80% cap. Reduced if Power rooms are damaged.
	var tac := _count_effective_tactical()
	if tac == 0:
		return 0.0
	var base := minf(1.0 - pow(0.65, float(tac)), 0.80)
	var pwr_health := _avg_room_health("Power")
	if pwr_health < 0.5:
		base *= (0.6 + pwr_health * 0.8)
	return base


# ── Counter-shot visuals ───────────────────────────────────────────────────────

func _spawn_counter_shot(hit: bool) -> void:
	## Fires a cyan energy bolt from the ship toward the attacker direction.
	## If hit=true, the bolt reaches its target and spawns a green impact flash.
	if _ship_pivot == null:
		return
	var origin  := _ship_pivot.global_position
	var fwd     := -_ship_pivot.global_transform.basis.z.normalized()
	var side    := _ship_pivot.global_transform.basis.x.normalized()
	var target_pos := origin + fwd * 9.0 + side * randf_range(-3.0, 3.0) \
		+ Vector3.UP * randf_range(-1.0, 2.0)

	# Bolt mesh (thin cyan cylinder)
	var bolt := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius    = 0.045;  cyl.bottom_radius = 0.045
	cyl.height        = 0.85;   cyl.radial_segments = 6
	bolt.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color              = Color(0.35, 0.85, 1.0, 1.0)
	bmat.emission_enabled          = true
	bmat.emission                  = Color(0.25, 0.75, 1.0)
	bmat.emission_energy_multiplier = 5.0
	bmat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt.set_surface_override_material(0, bmat)
	bolt.global_position = origin
	if target_pos.distance_squared_to(origin) > 0.01:
		bolt.look_at(target_pos, Vector3.UP)
		bolt.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	_world.add_child(bolt)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bolt, "global_position", target_pos, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_property(bmat, "albedo_color:a", 0.0, 0.18).set_delay(0.18)
	tw.set_parallel(false)
	tw.tween_callback(func():
		bolt.queue_free()
		if hit:
			_spawn_impact_flash(target_pos))


func _spawn_impact_flash(pos: Vector3) -> void:
	## Green burst at the attacker's position when the counter-shot connects.
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5;  sphere.height = 1.0
	sphere.radial_segments = 10;  sphere.rings = 5
	flash.mesh = sphere
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.albedo_color              = Color(0.35, 1.0, 0.55, 0.95)
	fmat.emission_enabled          = true
	fmat.emission                  = Color(0.25, 0.9, 0.45)
	fmat.emission_energy_multiplier = 5.0
	flash.set_surface_override_material(0, fmat)
	flash.global_position = pos
	_world.add_child(flash)

	var light := OmniLight3D.new()
	light.light_color  = Color(0.4, 1.0, 0.6)
	light.light_energy = 5.0
	light.omni_range   = 9.0
	light.global_position = pos
	_world.add_child(light)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(4.5, 4.5, 4.5), 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(fmat,  "albedo_color:a", 0.0, 0.45).set_delay(0.1)
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.set_parallel(false)
	tw.tween_callback(func():
		flash.queue_free()
		light.queue_free()).set_delay(0.6)


func _finish_travel() -> void:
	var days: int = _params.get("days", 7)
	_lbl_system.text = _wp_names[-1]
	_lbl_route.text  = "✔ Arrived"
	_lbl_day.text    = "Day %d / %d" % [days, days]

	_log("")
	_log("[color=#ffd050]═══  Arrived at %s  ═══[/color]" % _wp_names[-1])
	_log("[color=#ffd050]Net earned: %s credits[/color]" % _earned)

	var t := create_tween()
	t.tween_interval(2.8)
	var wages: int = _params.get("wages", 0)
	if wages > 0:
		_log("[color=#ff8844]Crew wages: -%d cr[/color]" % wages)

	t.tween_callback(func() -> void:
		job_finished.emit({
			"earned":         _earned,
			"log_lines":      _log_lines,
			"destination":    _wp_names[-1],
			"destination_id": _path_ids[-1] if not _path_ids.is_empty() else "sol",
			"days":           days,
			"wages":          wages,
			"is_percy":       _params.get("is_percy", false),
			"is_crew_mission": _params.get("is_crew_mission", false),
		})
		queue_free()
	)


func _cycle_speed() -> void:
	match _time_scale:
		1.0: _time_scale = 2.0; _btn_speed.text = "▶▶ 2×"
		2.0: _time_scale = 4.0; _btn_speed.text = "▶▶▶ 4×"
		_:   _time_scale = 1.0; _btn_speed.text = "▶  1×"
