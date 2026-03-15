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
const CAM_BACK   := 14.0
const CAM_UP     :=  5.0
const CAM_AHEAD  :=  9.0

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


# ── 3D Viewport ──────────────────────────────────────────────────────────────
func _build_viewport() -> void:
	var vpc := SubViewportContainer.new()
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
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
	env.glow_intensity        = 1.1
	env.glow_bloom            = 0.25
	env.glow_blend_mode       = Environment.GLOW_BLEND_MODE_ADDITIVE
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
	# Shared emissive mesh for all background stars
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode       = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled   = true
	mat.emission           = Color.WHITE
	mat.emission_energy_multiplier = 2.0
	mesh.surface_set_material(0, mat)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42314  # fixed seed = same stars every run
	for _i in 600:
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		var theta := rng.randf() * TAU
		var phi   := acos(2.0 * rng.randf() - 1.0)
		var r     := rng.randf_range(180.0, 320.0)
		inst.position = Vector3(
			r * sin(phi) * cos(theta),
			r * cos(phi),
			r * sin(phi) * sin(theta))
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

		_build_room_shape(room_container, rtype, universe, cost, mat, box_sz)
		_add_room_lights(room_container, rtype, box_sz)

		# Tiny billboard label above the composite shape
		var lbl := Label3D.new()
		lbl.text          = def.get("name", "")
		lbl.font_size     = 11
		lbl.pixel_size    = 0.005
		lbl.modulate      = Color(0.85, 0.92, 1.0, 0.65)
		lbl.position      = Vector3(0.0, box_sz.y * 1.3 + 0.2, 0.0)
		lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = false
		room_container.add_child(lbl)

	# ── Compute hull adjacency map for gameplay bonuses ──────────────────────
	_adjacencies = ShipBlueprint.compute_adjacencies(ship_nodes)
	if not _adjacencies.is_empty():
		var total_pairs := 0
		for uid in _adjacencies:
			total_pairs += (_adjacencies[uid] as Array).size()
		total_pairs /= 2  # each pair counted twice
		if total_pairs > 0:
			_log("[color=#55cc77]⬡ Hull adjacency: %d room pair%s detected[/color]" % [
				total_pairs, "s" if total_pairs != 1 else ""])

	return maxf(max_z, 0.0) + 1.0   # engine glow just behind rearmost room


func _build_room_shape(container: Node3D, rtype: String, universe: String,
		cost: int, base_mat: StandardMaterial3D, box_sz: Vector3) -> void:
	## Fandom-aware composite 3D shape for a ship room.
	match universe:
		"Star Trek": _3d_trek(container, rtype, base_mat, box_sz)
		"Star Wars": _3d_wars(container, rtype, base_mat, box_sz)
		"Babylon 5": _3d_b5(container,   rtype, base_mat, box_sz)
		"Dune":      _3d_dune(container,  rtype, base_mat, box_sz)
		_:           _3d_generic(container, rtype, cost, base_mat, box_sz)


# ── Star Trek Federation 3D shapes ────────────────────────────────────────────

func _3d_trek(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			# Saucer disc + bridge dome + glowing deflector sphere
			var disc := CylinderMesh.new()
			disc.top_radius = sz.x * 0.52;  disc.bottom_radius = disc.top_radius
			disc.height = sz.y * 0.55;  disc.radial_segments = 32
			_add_mi(container, disc, mat, Vector3(0.0, -sz.y * 0.08, 0.0))
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.20;  dome.height = dome.radius
			_add_mi(container, dome, mat, Vector3(0.0, sz.y * 0.32, -sz.z * 0.15))
			var defl := SphereMesh.new()
			defl.radius = sz.x * 0.13;  defl.height = defl.radius * 2.0
			_add_mi(container, defl,
				_glow_mat(Color(0.28, 0.55, 0.90), 1.6),
				Vector3(0.0, -sz.y * 0.22, sz.z * 0.42))
		"Engines":
			# Twin nacelle tubes (rotated 90°X) + red bussard collectors + pylon strut
			var nac := CylinderMesh.new()
			nac.top_radius = sz.z * 0.16;  nac.bottom_radius = nac.top_radius
			nac.height = sz.z * 1.05;  nac.radial_segments = 10
			for sx: float in [-sz.x * 0.38, sz.x * 0.38]:
				var nmi := _add_mi(container, nac, mat, Vector3(sx, sz.y * 0.10, 0.0))
				nmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var bm := _glow_mat(Color(0.85, 0.25, 0.10), 1.2)
			var bc := SphereMesh.new()
			bc.radius = sz.z * 0.175;  bc.height = bc.radius * 2.0
			for sx: float in [-sz.x * 0.38, sz.x * 0.38]:
				_add_mi(container, bc, bm, Vector3(sx, sz.y * 0.10, -sz.z * 0.52))
			_add_mi(container,
				_box_mesh(Vector3(sz.x * 0.76, sz.y * 0.12, sz.z * 0.18)),
				mat, Vector3.ZERO)
		"Power":
			# Secondary hull box + glowing deflector dish at rear
			_add_mi(container, _box_mesh(sz), mat, Vector3.ZERO)
			var dish := SphereMesh.new()
			dish.radius = sz.x * 0.24;  dish.height = dish.radius * 2.0
			_add_mi(container, dish,
				_glow_mat(Color(0.25, 0.50, 0.92), 1.4),
				Vector3(0.0, -sz.y * 0.10, sz.z * 0.62))
		_:
			_3d_generic(container, rtype, 0, mat, sz)


# ── Star Wars Imperial 3D shapes ──────────────────────────────────────────────

func _3d_wars(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			# Wide flat hull + tall bridge tower
			_add_mi(container, _box_mesh(Vector3(sz.x * 1.10, sz.y * 0.55, sz.z)),
				mat, Vector3(0.0, -sz.y * 0.18, 0.0))
			_add_mi(container, _box_mesh(Vector3(sz.x * 0.24, sz.y * 0.95, sz.z * 0.32)),
				mat, Vector3(0.0, sz.y * 0.40, 0.0))
		"Engines":
			# Engine block + 4 circular ion exhaust cylinders (2×2 grid)
			_add_mi(container, _box_mesh(sz), mat, Vector3.ZERO)
			var exh := CylinderMesh.new()
			exh.top_radius = sz.x * 0.17;  exh.bottom_radius = exh.top_radius
			exh.height = sz.y * 1.05;  exh.radial_segments = 14
			var em := _glow_mat(RoomData.type_color("Engines"), 1.2)
			for ex: float in [-sz.x * 0.28, sz.x * 0.28]:
				for ez: float in [-sz.z * 0.28, sz.z * 0.28]:
					_add_mi(container, exh, em, Vector3(ex, 0.0, ez))
		"Power":
			# Hexagonal prism reactor + emissive core sphere
			var hex := CylinderMesh.new()
			hex.top_radius = sz.x * 0.50;  hex.bottom_radius = hex.top_radius
			hex.height = sz.y;  hex.radial_segments = 6
			_add_mi(container, hex, mat, Vector3.ZERO)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.20;  core.height = core.radius * 2.0
			_add_mi(container, core,
				_glow_mat(RoomData.type_color("Power"), 1.6),
				Vector3(0.0, sz.y * 0.12, 0.0))
		"Tactical":
			# Flat turret base + 3 dome turbolaser mounts
			_add_mi(container, _box_mesh(Vector3(sz.x, sz.y * 0.55, sz.z)),
				mat, Vector3(0.0, -sz.y * 0.20, 0.0))
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.18;  dome.height = dome.radius
			for dx: float in [-sz.x * 0.38, 0.0, sz.x * 0.38]:
				_add_mi(container, dome, mat, Vector3(dx, sz.y * 0.22, 0.0))
		_:
			_3d_generic(container, rtype, 0, mat, sz)


# ── Babylon 5 Earth Alliance 3D shapes ────────────────────────────────────────

func _3d_b5(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			# Tall hexagonal C&C module + viewport dome
			var hex := CylinderMesh.new()
			hex.top_radius = sz.x * 0.50;  hex.bottom_radius = hex.top_radius
			hex.height = sz.y * 1.10;  hex.radial_segments = 6
			_add_mi(container, hex, mat, Vector3.ZERO)
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.22;  dome.height = dome.radius
			_add_mi(container, dome, mat, Vector3(0.0, sz.y * 0.65, 0.0))
		"Engines":
			# Cylindrical drive pod + glowing exhaust nozzle + swept fin boxes
			var body := CylinderMesh.new()
			body.top_radius = sz.x * 0.38;  body.bottom_radius = body.top_radius
			body.height = sz.z * 0.80;  body.radial_segments = 12
			var bmi := _add_mi(container, body, mat, Vector3(0.0, 0.0, -sz.z * 0.12))
			bmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var noz := CylinderMesh.new()
			noz.top_radius = sz.x * 0.44;  noz.bottom_radius = sz.x * 0.28
			noz.height = sz.z * 0.28;  noz.radial_segments = 14
			var nmi := _add_mi(container, noz,
				_glow_mat(RoomData.type_color("Engines"), 1.4),
				Vector3(0.0, 0.0, sz.z * 0.40))
			nmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			for sx: float in [-1.0, 1.0]:
				var fmi := _add_mi(container,
					_box_mesh(Vector3(sz.x * 0.12, sz.y * 0.16, sz.z * 0.68)),
					mat, Vector3(sx * sz.x * 0.54, -sz.y * 0.12, 0.0))
				fmi.rotation_degrees = Vector3(0.0, 0.0, sx * 14.0)
		"Power":
			# Circular fusion reactor cylinder + 4 radiating fin boxes + glowing core
			var body := CylinderMesh.new()
			body.top_radius = sz.x * 0.44;  body.bottom_radius = body.top_radius
			body.height = sz.y;  body.radial_segments = 16
			_add_mi(container, body, mat, Vector3.ZERO)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.18;  core.height = core.radius * 2.0
			_add_mi(container, core,
				_glow_mat(RoomData.type_color("Power"), 1.6),
				Vector3(0.0, sz.y * 0.08, 0.0))
			for i in 4:
				var a := TAU * float(i) / 4.0 + deg_to_rad(45.0)
				var fp := Vector3(cos(a) * sz.x * 0.56, 0.0, sin(a) * sz.z * 0.56)
				var fmi := _add_mi(container,
					_box_mesh(Vector3(sz.x * 0.12, sz.y * 0.85, sz.z * 0.40)),
					mat, fp)
				fmi.rotation_degrees = Vector3(0.0, rad_to_deg(a), 0.0)
		_:
			_3d_generic(container, rtype, 0, mat, sz)


# ── Dune Holtzman Tech 3D shapes ──────────────────────────────────────────────

func _3d_dune(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			# Oblate sphere navigator's chamber + glowing inner spice core
			var outer := SphereMesh.new()
			outer.radius = sz.x * 0.52;  outer.height = sz.y * 1.10
			_add_mi(container, outer, mat, Vector3.ZERO)
			var inner := SphereMesh.new()
			inner.radius = sz.x * 0.25;  inner.height = sz.y * 0.54
			_add_mi(container, inner,
				_glow_mat(RoomData.type_color("Command"), 1.2),
				Vector3(0.0, sz.y * 0.04, 0.0))
		"Engines":
			# Suspensor anti-gravity array: 5 emissive spheres in X pattern
			var em := _glow_mat(RoomData.type_color("Engines"), 1.4)
			var sp := SphereMesh.new()
			sp.radius = sz.x * 0.20;  sp.height = sp.radius * 2.0
			var offsets: Array[Vector3] = [
				Vector3.ZERO,
				Vector3(-sz.x * 0.46, 0.0, -sz.z * 0.40),
				Vector3( sz.x * 0.46, 0.0, -sz.z * 0.40),
				Vector3(-sz.x * 0.46, 0.0,  sz.z * 0.40),
				Vector3( sz.x * 0.46, 0.0,  sz.z * 0.40),
			]
			for off: Vector3 in offsets:
				_add_mi(container, sp, em, off)
		"Power":
			# Holtzman field generator: two BoxMesh diamonds (45°/135°) + bright core
			var dsz := Vector3(sz.x * 0.58, sz.y * 0.72, sz.z * 0.58)
			var dm := _glow_mat(RoomData.type_color("Power"), 0.8)
			for ang: float in [45.0, 135.0]:
				var dmi := _add_mi(container, _box_mesh(dsz), dm, Vector3.ZERO)
				dmi.rotation_degrees = Vector3(0.0, ang, 0.0)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.16;  core.height = core.radius * 2.0
			_add_mi(container, core,
				_glow_mat(RoomData.type_color("Power").lightened(0.40), 2.0),
				Vector3.ZERO)
		_:
			_3d_generic(container, rtype, 0, mat, sz)


# ── Generic / Universal cost-tier shapes ──────────────────────────────────────

func _3d_generic(container: Node3D, rtype: String, cost: int,
		base_mat: StandardMaterial3D, box_sz: Vector3) -> void:
	var hs_x := box_sz.x * 0.5
	var hs_z := box_sz.z * 0.5
	var pr   := minf(hs_x, hs_z) * 0.13
	var px   := hs_x - pr
	var pz   := hs_z - pr
	var corners: Array[Vector2] = [
		Vector2( px,  pz), Vector2(-px,  pz),
		Vector2( px, -pz), Vector2(-px, -pz),
	]

	# Tier 1: base box
	_add_mi(container, _box_mesh(box_sz), base_mat, Vector3.ZERO)
	if cost < 200:
		return

	# Tier 2: corner cylinder pillars
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius    = pr;  col_mesh.bottom_radius = pr
	col_mesh.height        = box_sz.y * 0.92;  col_mesh.radial_segments = 6
	for c: Vector2 in corners:
		_add_mi(container, col_mesh, base_mat, Vector3(c.x, 0.0, c.y))
	if cost < 500:
		return

	# Tier 3: raised spine + angled side panels
	var spine_h := box_sz.y * 0.30
	_add_mi(container,
		_box_mesh(Vector3(box_sz.x * 0.20, spine_h, box_sz.z * 0.78)),
		base_mat, Vector3(0.0, (box_sz.y + spine_h) * 0.5, 0.0))
	for side in [-1.0, 1.0]:
		var pw  := box_sz.x * 0.16
		var ph  := box_sz.y * 0.52
		var pmi := _add_mi(container,
			_box_mesh(Vector3(pw, ph, box_sz.z * 0.60)),
			base_mat, Vector3(side * (hs_x + pw * 0.35), box_sz.y * 0.08, 0.0))
		pmi.rotation = Vector3(0.0, 0.0, deg_to_rad(side * -16.0))
	if cost < 800:
		return

	# Tier 4: corner fins + sensor dome
	for c: Vector2 in corners:
		var fmi := _add_mi(container,
			_box_mesh(Vector3(box_sz.x * 0.09, box_sz.y * 0.78, box_sz.z * 0.09)),
			base_mat, Vector3(c.x * 1.32, box_sz.y * 0.22, c.y * 1.32))
		fmi.rotation = Vector3(0.0, atan2(c.x, c.y) + deg_to_rad(45.0), 0.0)
	var dome_r := minf(hs_x, hs_z) * 0.30
	var dome   := SphereMesh.new()
	dome.radius = dome_r;  dome.height = dome_r * 1.1
	dome.radial_segments = 10;  dome.rings = 5
	_add_mi(container, dome, base_mat, Vector3(0.0, box_sz.y * 0.5 + dome_r * 0.45, 0.0))
	if cost < 1200:
		return

	# Tier 5: emissive crystal spires + glowing core
	var spire_mat := _glow_mat(RoomData.type_color(rtype).lightened(0.35), 2.0)
	for c: Vector2 in corners:
		var spire := CylinderMesh.new()
		spire.top_radius = 0.02;  spire.bottom_radius = pr * 1.1
		spire.height = box_sz.y * 0.85;  spire.radial_segments = 5
		_add_mi(container, spire, spire_mat,
			Vector3(c.x * 0.75, box_sz.y * 0.72, c.y * 0.75))
	var core_r := minf(hs_x, hs_z) * 0.20
	var core   := SphereMesh.new()
	core.radius = core_r;  core.height = core_r * 2.0
	core.radial_segments = 8;  core.rings = 4
	_add_mi(container, core,
		_glow_mat(RoomData.type_color(rtype), 1.8),
		Vector3(0.0, box_sz.y * 0.10, 0.0))


# ── Per-room exterior lighting ────────────────────────────────────────────────

func _add_room_lights(container: Node3D, rtype: String, sz: Vector3) -> void:
	## Attach small OmniLight3D nodes to a room container so the ship is visibly
	## lit from the outside.  Colours and positions differ per room type.
	var hy := sz.y * 0.5   # half-height
	match rtype:
		"Command":
			# Bridge viewscreen glow (cool blue-white, forward-facing)
			_omni(container, Color(0.70, 0.82, 1.00), 1.4, 3.8,
				Vector3(0.0, hy + 0.15, -sz.z * 0.45))
			# Side running lights (port=red, starboard=green)
			_omni(container, Color(0.90, 0.18, 0.12), 0.7, 2.2,
				Vector3(-sz.x * 0.55, hy * 0.3, 0.0))
			_omni(container, Color(0.12, 0.85, 0.22), 0.7, 2.2,
				Vector3( sz.x * 0.55, hy * 0.3, 0.0))
			# Instrument panel warm under-glow
			_omni(container, Color(0.55, 0.65, 0.90), 0.5, 2.5,
				Vector3(0.0, hy + 0.25, 0.0))
		"Engines":
			# Hot exhaust glow (bright orange-red, rear-facing)
			_omni(container, Color(1.00, 0.45, 0.10), 2.0, 4.5,
				Vector3(0.0, 0.0, sz.z * 0.55))
			# Nacelle running strips (cooler blue along sides)
			_omni(container, Color(0.40, 0.60, 1.00), 0.8, 2.8,
				Vector3(-sz.x * 0.42, hy * 0.4, -sz.z * 0.20))
			_omni(container, Color(0.40, 0.60, 1.00), 0.8, 2.8,
				Vector3( sz.x * 0.42, hy * 0.4, -sz.z * 0.20))
		"Power":
			# Reactor core glow (intense cyan pulse visible through hull)
			_omni(container, Color(0.25, 0.70, 1.00), 2.2, 5.0,
				Vector3(0.0, hy * 0.2, 0.0))
			# Coolant vents (dim teal, underneath)
			_omni(container, Color(0.15, 0.55, 0.65), 0.6, 2.5,
				Vector3(0.0, -hy * 0.6, sz.z * 0.35))
			_omni(container, Color(0.15, 0.55, 0.65), 0.6, 2.5,
				Vector3(0.0, -hy * 0.6, -sz.z * 0.35))
		"Tactical":
			# Weapons charging glow (amber/red, menacing)
			_omni(container, Color(1.00, 0.35, 0.15), 1.5, 3.5,
				Vector3(0.0, hy + 0.10, -sz.z * 0.40))
			# Targeting sensor sweep (dim red pulsing)
			_omni(container, Color(0.85, 0.20, 0.10), 0.8, 2.8,
				Vector3(-sz.x * 0.40, hy * 0.5, 0.0))
			_omni(container, Color(0.85, 0.20, 0.10), 0.8, 2.8,
				Vector3( sz.x * 0.40, hy * 0.5, 0.0))
		_: # Utility
			# Soft warm interior spill through windows
			_omni(container, Color(0.90, 0.82, 0.60), 0.9, 3.0,
				Vector3(0.0, hy + 0.10, 0.0))
			# Secondary under-hull work light
			_omni(container, Color(0.70, 0.72, 0.80), 0.5, 2.2,
				Vector3(0.0, -hy * 0.5, 0.0))


func _omni(parent: Node3D, col: Color, energy: float, rng: float,
		pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color               = col
	light.light_energy              = energy
	light.omni_range                = rng
	light.omni_attenuation          = 1.8  # softer falloff
	light.shadow_enabled            = false
	light.position                  = pos
	parent.add_child(light)


# ── Mesh helpers ──────────────────────────────────────────────────────────────

static func _box_mesh(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = sz
	return m


static func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	## Fresh emissive material for accent elements (no texture, pure glow).
	var m := StandardMaterial3D.new()
	m.albedo_color                 = col
	m.emission_enabled             = true
	m.emission                     = col
	m.emission_energy_multiplier   = energy
	return m


func _add_mi(parent: Node3D, mesh: Mesh, mat: Material,
		pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh     = mesh
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi


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
	var bot_style := StyleBoxFlat.new()
	bot_style.bg_color = Color(0.03, 0.05, 0.10, 0.82)
	bot_panel.add_theme_stylebox_override("panel", bot_style)
	add_child(bot_panel)

	_log_box = RichTextLabel.new()
	_log_box.bbcode_enabled   = true
	_log_box.scroll_following = true
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
	var dest_sys: Dictionary = StarMapData.pick_destination(days, cur_sys)
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
	_camera.global_position = _waypoints[0] - initial_forward * CAM_BACK + Vector3.UP * CAM_UP
	if _camera.global_position.distance_squared_to(_waypoints[0] + initial_forward * CAM_AHEAD) > 0.01:
		_camera.look_at(_waypoints[0] + initial_forward * CAM_AHEAD, Vector3.UP)

	# ── Base earnings ────────────────────────────────────────────────────────
	var power_bonus: int = maxi(0, pwr / 100) * 10
	var room_bonus:  int = node_count * 5
	_earned = days * (50 + power_bonus + room_bonus)
	if pwr < 0:
		_earned = int(_earned * 0.7)

	# ── Pre-roll travel events ───────────────────────────────────────────────
	_pre_roll_events(days, node_count)

	# ── HUD initial state ────────────────────────────────────────────────────
	_lbl_system.text = _wp_names[0]
	_lbl_route.text  = "→  " + _wp_names[-1]
	_lbl_day.text    = "Day 1 / %d" % days

	# ── Opening log ──────────────────────────────────────────────────────────
	_log("[color=#4488ff]═══  %s  —  %d-day voyage to %s  ═══[/color]" % [name_str, days, _wp_names[-1]])
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
			var dmg := rng.randi_range(5, 22)
			var tgt := rng.randi_range(0, node_count - 1)
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
		var target_cam := ship_pos - forward * CAM_BACK + Vector3.UP * CAM_UP
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
		var target_cam := ship_pos - forward * CAM_BACK + Vector3.UP * CAM_UP
		_camera.global_position = _camera.global_position.lerp(target_cam, delta * 2.2)
		var look_target := ship_pos + forward * CAM_AHEAD
		if look_target.distance_squared_to(_camera.global_position) > 0.04:
			var target_xform := _camera.global_transform.looking_at(look_target, Vector3.UP)
			_camera.global_transform = \
				_camera.global_transform.interpolate_with(target_xform, delta * 5.0)


func _update_system_fades(delta: float) -> void:
	## When the ship overlaps a star system body, fade it to ~88% transparent
	## so the ship stays visible during departure and fly-throughs.
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
		var near:      bool  = dist < radius + 3.5
		var target_t:  float = 0.88 if near else 0.0
		var spd:       float = delta * 5.0
		for child in sys_node.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).transparency = \
					lerpf((child as MeshInstance3D).transparency, target_t, spd)
			elif child is Label3D:
				# Label alpha goes inverse — full opacity when solid, dim when faded
				(child as Label3D).modulate.a = \
					lerpf((child as Label3D).modulate.a, 1.0 - target_t * 0.85, spd)
			elif child is OmniLight3D:
				# Dim the star light so it doesn't blow out the ship mesh
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
			_log("[color=#55cc77]⬡ Adjacency: -%d wear on %s[/color]" % [adj_red, ship_node.title])

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
						_log("[color=#55cc77]⬡ Hull synergy: Tactical adjacency reduced %d damage[/color]" % adj_red)

				target.apply_damage(dmg)
				_earned -= randi_range(50, 180)
				_earned  = maxi(0, _earned)
				_log("[color=#ff5533]⚠ Combat! -%d dur to [b]%s[/b].[/color]" % [dmg, target.title])
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
					_log("[color=#55cc77]⬡ Hull synergy: Command adjacency +%d cr[/color]" % adj_bonus)

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
		})
		queue_free()
	)


func _cycle_speed() -> void:
	match _time_scale:
		1.0: _time_scale = 2.0; _btn_speed.text = "▶▶ 2×"
		2.0: _time_scale = 4.0; _btn_speed.text = "▶▶▶ 4×"
		_:   _time_scale = 1.0; _btn_speed.text = "▶  1×"
