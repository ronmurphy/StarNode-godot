## ship_builder_3d.gd — Static utility: 3D room shape builders shared by
## StarMap (spaceflight) and ShipLayoutEditor (3D layout editing).
## All methods are static — no instance state.
class_name ShipBuilder3D


# ── Mesh helpers ──────────────────────────────────────────────────────────────

static func box_mesh(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = sz
	return m


static func glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	## Fresh emissive material for accent elements (no texture, pure glow).
	var m := StandardMaterial3D.new()
	m.albedo_color                 = col
	m.emission_enabled             = true
	m.emission                     = col
	m.emission_energy_multiplier   = energy
	return m


static func add_mi(parent: Node3D, mesh: Mesh, mat: Material,
		pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh     = mesh
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi


# ── Room sizing + material ───────────────────────────────────────────────────

static func room_box_size(rtype: String) -> Vector3:
	match rtype:
		"Power":    return Vector3(1.50, 0.75, 1.50)
		"Engines":  return Vector3(1.15, 0.55, 1.80)
		"Command":  return Vector3(1.75, 0.65, 1.35)
		"Tactical": return Vector3(1.35, 0.60, 1.35)
		_:          return Vector3(1.25, 0.48, 1.25)


static func room_material(rtype: String, tex: Texture2D, color_override: Color = Color(-1, -1, -1)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if color_override.r < 0:
		mat.albedo_color = RoomData.type_color(rtype).darkened(0.10)
	else:
		mat.albedo_color = color_override.darkened(0.10)
	mat.metallic     = 0.55
	mat.roughness    = 0.40
	if tex != null:
		mat.albedo_texture = tex
	return mat


# ── Shape dispatcher ─────────────────────────────────────────────────────────

static func build_room_shape(container: Node3D, rtype: String, universe: String,
		cost: int, base_mat: StandardMaterial3D, box_sz: Vector3) -> void:
	## Fandom-aware composite 3D shape for a ship room.
	match universe:
		"Star Trek": _trek(container, rtype, base_mat, box_sz)
		"Star Wars": _wars(container, rtype, base_mat, box_sz)
		"Babylon 5": _b5(container,   rtype, base_mat, box_sz)
		"Dune":      _dune(container,  rtype, base_mat, box_sz)
		_:           _generic(container, rtype, cost, base_mat, box_sz)


# ── Star Trek Federation 3D shapes ──────────────────────────────────────────

static func _trek(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			var disc := CylinderMesh.new()
			disc.top_radius = sz.x * 0.52;  disc.bottom_radius = disc.top_radius
			disc.height = sz.y * 0.55;  disc.radial_segments = 32
			add_mi(container, disc, mat, Vector3(0.0, -sz.y * 0.08, 0.0))
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.20;  dome.height = dome.radius
			add_mi(container, dome, mat, Vector3(0.0, sz.y * 0.32, -sz.z * 0.15))
			var defl := SphereMesh.new()
			defl.radius = sz.x * 0.13;  defl.height = defl.radius * 2.0
			add_mi(container, defl,
				glow_mat(Color(0.28, 0.55, 0.90), 1.6),
				Vector3(0.0, -sz.y * 0.22, sz.z * 0.42))
		"Engines":
			var nac := CylinderMesh.new()
			nac.top_radius = sz.z * 0.16;  nac.bottom_radius = nac.top_radius
			nac.height = sz.z * 1.05;  nac.radial_segments = 10
			for sx: float in [-sz.x * 0.38, sz.x * 0.38]:
				var nmi := add_mi(container, nac, mat, Vector3(sx, sz.y * 0.10, 0.0))
				nmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var bm := glow_mat(Color(0.85, 0.25, 0.10), 1.2)
			var bc := SphereMesh.new()
			bc.radius = sz.z * 0.175;  bc.height = bc.radius * 2.0
			for sx: float in [-sz.x * 0.38, sz.x * 0.38]:
				add_mi(container, bc, bm, Vector3(sx, sz.y * 0.10, -sz.z * 0.52))
			add_mi(container,
				box_mesh(Vector3(sz.x * 0.76, sz.y * 0.12, sz.z * 0.18)),
				mat, Vector3.ZERO)
		"Power":
			var hull := CylinderMesh.new()
			hull.top_radius    = sz.x * 0.52
			hull.bottom_radius = sz.x * 0.30
			hull.height        = sz.y * 1.0
			hull.radial_segments = 4
			add_mi(container, hull, mat, Vector3.ZERO)
			var dish := SphereMesh.new()
			dish.radius = sz.x * 0.24;  dish.height = dish.radius * 2.0
			add_mi(container, dish,
				glow_mat(Color(0.25, 0.50, 0.92), 1.4),
				Vector3(0.0, -sz.y * 0.10, sz.z * 0.62))
		"Tactical":
			var ring := TorusMesh.new()
			ring.inner_radius = sz.x * 0.38;  ring.outer_radius = sz.x * 0.50
			ring.rings = 24;  ring.ring_segments = 16
			add_mi(container, ring, mat, Vector3(0.0, sz.y * 0.08, 0.0))
			for sx: float in [-sz.x * 0.30, sz.x * 0.30]:
				add_mi(container,
					box_mesh(Vector3(sz.x * 0.26, sz.y * 0.50, sz.z * 0.22)),
					mat, Vector3(sx, -sz.y * 0.12, 0.0))
		_:
			_generic(container, rtype, 0, mat, sz)


# ── Star Wars Imperial 3D shapes ────────────────────────────────────────────

static func _wars(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			# Imperial bridge tower — terraced trapezoid with viewport band + shield domes
			# Base tier: wide hull foundation
			var base := CylinderMesh.new()
			base.top_radius = sz.x * 0.42;  base.bottom_radius = sz.x * 0.56
			base.height = sz.y * 0.35;  base.radial_segments = 4
			var bmi := add_mi(container, base, mat, Vector3(0.0, -sz.y * 0.28, sz.z * 0.05))
			bmi.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			# Mid tier: narrower stepped section
			var mid := CylinderMesh.new()
			mid.top_radius = sz.x * 0.30;  mid.bottom_radius = sz.x * 0.40
			mid.height = sz.y * 0.35;  mid.radial_segments = 4
			var mmi := add_mi(container, mid, mat, Vector3(0.0, sz.y * 0.06, sz.z * 0.05))
			mmi.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			# Upper tier: bridge housing
			var upper := CylinderMesh.new()
			upper.top_radius = sz.x * 0.22;  upper.bottom_radius = sz.x * 0.30
			upper.height = sz.y * 0.28;  upper.radial_segments = 4
			var umi := add_mi(container, upper, mat, Vector3(0.0, sz.y * 0.38, sz.z * 0.05))
			umi.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			# Viewport band — thin glowing strip angled forward
			var vp := box_mesh(Vector3(sz.x * 0.52, sz.y * 0.06, sz.z * 0.04))
			add_mi(container, vp,
				glow_mat(Color(0.70, 0.85, 1.00), 1.2),
				Vector3(0.0, sz.y * 0.42, -sz.z * 0.18))
			# Shield generator domes (the iconic twin spheres)
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.10;  dome.height = dome.radius * 1.3
			dome.radial_segments = 12;  dome.rings = 6
			for dx: float in [-sz.x * 0.16, sz.x * 0.16]:
				add_mi(container, dome, mat, Vector3(dx, sz.y * 0.58, sz.z * 0.05))
			# Antenna spire between domes
			var spire := CylinderMesh.new()
			spire.top_radius = 0.01;  spire.bottom_radius = sz.x * 0.02
			spire.height = sz.y * 0.22;  spire.radial_segments = 4
			add_mi(container, spire, mat, Vector3(0.0, sz.y * 0.64, sz.z * 0.05))
		"Engines":
			add_mi(container, box_mesh(sz), mat, Vector3.ZERO)
			var exh := CylinderMesh.new()
			exh.top_radius = sz.x * 0.17;  exh.bottom_radius = exh.top_radius
			exh.height = sz.y * 1.05;  exh.radial_segments = 14
			var em := glow_mat(RoomData.type_color("Engines"), 1.2)
			for ex: float in [-sz.x * 0.28, sz.x * 0.28]:
				for ez: float in [-sz.z * 0.28, sz.z * 0.28]:
					add_mi(container, exh, em, Vector3(ex, 0.0, ez))
		"Power":
			var hex := CylinderMesh.new()
			hex.top_radius = sz.x * 0.50;  hex.bottom_radius = hex.top_radius
			hex.height = sz.y;  hex.radial_segments = 6
			add_mi(container, hex, mat, Vector3.ZERO)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.20;  core.height = core.radius * 2.0
			add_mi(container, core,
				glow_mat(RoomData.type_color("Power"), 1.6),
				Vector3(0.0, sz.y * 0.12, 0.0))
		"Tactical":
			add_mi(container, box_mesh(Vector3(sz.x, sz.y * 0.55, sz.z)),
				mat, Vector3(0.0, -sz.y * 0.20, 0.0))
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.18;  dome.height = dome.radius
			for dx: float in [-sz.x * 0.38, 0.0, sz.x * 0.38]:
				add_mi(container, dome, mat, Vector3(dx, sz.y * 0.22, 0.0))
		_:
			_generic(container, rtype, 0, mat, sz)


# ── Babylon 5 Earth Alliance 3D shapes ──────────────────────────────────────

static func _b5(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			var hex := CylinderMesh.new()
			hex.top_radius = sz.x * 0.50;  hex.bottom_radius = hex.top_radius
			hex.height = sz.y * 1.10;  hex.radial_segments = 6
			add_mi(container, hex, mat, Vector3.ZERO)
			var dome := SphereMesh.new()
			dome.radius = sz.x * 0.22;  dome.height = dome.radius
			add_mi(container, dome, mat, Vector3(0.0, sz.y * 0.65, 0.0))
		"Engines":
			var body := CylinderMesh.new()
			body.top_radius = sz.x * 0.38;  body.bottom_radius = body.top_radius
			body.height = sz.z * 0.80;  body.radial_segments = 12
			var bmi := add_mi(container, body, mat, Vector3(0.0, 0.0, -sz.z * 0.12))
			bmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			var noz := CylinderMesh.new()
			noz.top_radius = sz.x * 0.44;  noz.bottom_radius = sz.x * 0.28
			noz.height = sz.z * 0.28;  noz.radial_segments = 14
			var nmi := add_mi(container, noz,
				glow_mat(RoomData.type_color("Engines"), 1.4),
				Vector3(0.0, 0.0, sz.z * 0.40))
			nmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			for sx: float in [-1.0, 1.0]:
				var fmi := add_mi(container,
					box_mesh(Vector3(sz.x * 0.12, sz.y * 0.16, sz.z * 0.68)),
					mat, Vector3(sx * sz.x * 0.54, -sz.y * 0.12, 0.0))
				fmi.rotation_degrees = Vector3(0.0, 0.0, sx * 14.0)
		"Power":
			var body := CylinderMesh.new()
			body.top_radius = sz.x * 0.44;  body.bottom_radius = body.top_radius
			body.height = sz.y;  body.radial_segments = 16
			add_mi(container, body, mat, Vector3.ZERO)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.18;  core.height = core.radius * 2.0
			add_mi(container, core,
				glow_mat(RoomData.type_color("Power"), 1.6),
				Vector3(0.0, sz.y * 0.08, 0.0))
			for i in 4:
				var a := TAU * float(i) / 4.0 + deg_to_rad(45.0)
				var fp := Vector3(cos(a) * sz.x * 0.56, 0.0, sin(a) * sz.z * 0.56)
				var fmi := add_mi(container,
					box_mesh(Vector3(sz.x * 0.12, sz.y * 0.85, sz.z * 0.40)),
					mat, fp)
				fmi.rotation_degrees = Vector3(0.0, rad_to_deg(a), 0.0)
		"Tactical":
			var pod_rear := sz.x * 0.22
			var pod_front := sz.x * 0.48
			var pod := CylinderMesh.new()
			pod.top_radius = pod_rear;  pod.bottom_radius = pod_front
			pod.height = sz.z * 0.85;  pod.radial_segments = 4
			var pmi := add_mi(container, pod, mat, Vector3(0.0, -sz.y * 0.10, 0.0))
			pmi.rotation_degrees = Vector3(90.0, 45.0, 0.0)
			var barrel := CylinderMesh.new()
			barrel.top_radius = sz.x * 0.06;  barrel.bottom_radius = barrel.top_radius
			barrel.height = sz.z * 0.50;  barrel.radial_segments = 8
			for sx: float in [-sz.x * 0.20, sz.x * 0.20]:
				var bmi := add_mi(container, barrel, mat,
					Vector3(sx, sz.y * 0.10, -sz.z * 0.52))
				bmi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		_:
			_generic(container, rtype, 0, mat, sz)


# ── Dune Holtzman Tech 3D shapes ────────────────────────────────────────────

static func _dune(container: Node3D, rtype: String,
		mat: StandardMaterial3D, sz: Vector3) -> void:
	match rtype:
		"Command":
			var outer := SphereMesh.new()
			outer.radius = sz.x * 0.52;  outer.height = sz.y * 1.10
			add_mi(container, outer, mat, Vector3.ZERO)
			var inner := SphereMesh.new()
			inner.radius = sz.x * 0.25;  inner.height = sz.y * 0.54
			add_mi(container, inner,
				glow_mat(RoomData.type_color("Command"), 1.2),
				Vector3(0.0, sz.y * 0.04, 0.0))
		"Engines":
			var em := glow_mat(RoomData.type_color("Engines"), 1.4)
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
				add_mi(container, sp, em, off)
		"Power":
			var dsz := Vector3(sz.x * 0.48, sz.y * 0.72, sz.z * 0.20)
			for ox: float in [-sz.x * 0.18, sz.x * 0.18]:
				var dmi := add_mi(container, box_mesh(dsz), mat,
					Vector3(ox, 0.0, 0.0))
				dmi.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			var core := SphereMesh.new()
			core.radius = sz.x * 0.16;  core.height = core.radius * 2.0
			add_mi(container, core,
				glow_mat(RoomData.type_color("Power").lightened(0.40), 2.0),
				Vector3.ZERO)
		"Tactical":
			for sx: float in [-1.0, 1.0]:
				var blade := box_mesh(Vector3(sz.x * 0.22, sz.y * 0.85, sz.z * 0.16))
				var bmi := add_mi(container, blade, mat,
					Vector3(sx * sz.x * 0.28, 0.0, 0.0))
				bmi.rotation_degrees = Vector3(0.0, 0.0, sx * 12.0)
			var tip := SphereMesh.new()
			tip.radius = sz.x * 0.10;  tip.height = tip.radius * 2.0
			var tm := glow_mat(RoomData.type_color("Tactical").lightened(0.30), 1.4)
			for sx: float in [-1.0, 1.0]:
				add_mi(container, tip, tm,
					Vector3(sx * sz.x * 0.28, sz.y * 0.52, 0.0))
		_:
			_generic(container, rtype, 0, mat, sz)


# ── Generic / Universal cost-tier shapes ────────────────────────────────────

static func _generic(container: Node3D, rtype: String, cost: int,
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
	add_mi(container, box_mesh(box_sz), base_mat, Vector3.ZERO)
	if cost < 200:
		return

	# Tier 2: corner cylinder pillars
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius    = pr;  col_mesh.bottom_radius = pr
	col_mesh.height        = box_sz.y * 0.92;  col_mesh.radial_segments = 6
	for c: Vector2 in corners:
		add_mi(container, col_mesh, base_mat, Vector3(c.x, 0.0, c.y))
	if cost < 500:
		return

	# Tier 3: raised spine + angled side panels
	var spine_h := box_sz.y * 0.30
	add_mi(container,
		box_mesh(Vector3(box_sz.x * 0.20, spine_h, box_sz.z * 0.78)),
		base_mat, Vector3(0.0, (box_sz.y + spine_h) * 0.5, 0.0))
	for side in [-1.0, 1.0]:
		var pw  := box_sz.x * 0.16
		var ph  := box_sz.y * 0.52
		var pmi := add_mi(container,
			box_mesh(Vector3(pw, ph, box_sz.z * 0.60)),
			base_mat, Vector3(side * (hs_x + pw * 0.35), box_sz.y * 0.08, 0.0))
		pmi.rotation = Vector3(0.0, 0.0, deg_to_rad(side * -16.0))
	if cost < 800:
		return

	# Tier 4: corner fins + sensor dome
	for c: Vector2 in corners:
		var fmi := add_mi(container,
			box_mesh(Vector3(box_sz.x * 0.09, box_sz.y * 0.78, box_sz.z * 0.09)),
			base_mat, Vector3(c.x * 1.32, box_sz.y * 0.22, c.y * 1.32))
		fmi.rotation = Vector3(0.0, atan2(c.x, c.y) + deg_to_rad(45.0), 0.0)
	var dome_r := minf(hs_x, hs_z) * 0.30
	var dome   := SphereMesh.new()
	dome.radius = dome_r;  dome.height = dome_r * 1.1
	dome.radial_segments = 10;  dome.rings = 5
	add_mi(container, dome, base_mat, Vector3(0.0, box_sz.y * 0.5 + dome_r * 0.45, 0.0))
	if cost < 1200:
		return

	# Tier 5: emissive crystal spires + glowing core
	var spire_mat := glow_mat(RoomData.type_color(rtype).lightened(0.35), 2.0)
	for c: Vector2 in corners:
		var spire := CylinderMesh.new()
		spire.top_radius = 0.02;  spire.bottom_radius = pr * 1.1
		spire.height = box_sz.y * 0.85;  spire.radial_segments = 5
		add_mi(container, spire, spire_mat,
			Vector3(c.x * 0.75, box_sz.y * 0.72, c.y * 0.75))
	var core_r := minf(hs_x, hs_z) * 0.20
	var core   := SphereMesh.new()
	core.radius = core_r;  core.height = core_r * 2.0
	core.radial_segments = 8;  core.rings = 4
	add_mi(container, core,
		glow_mat(RoomData.type_color(rtype), 1.8),
		Vector3(0.0, box_sz.y * 0.10, 0.0))


# ── Per-room exterior lighting ───────────────────────────────────────────────

static func add_room_lights(container: Node3D, rtype: String, sz: Vector3) -> void:
	var hy := sz.y * 0.5
	match rtype:
		"Command":
			_omni(container, Color(0.70, 0.82, 1.00), 1.4, 3.8,
				Vector3(0.0, hy + 0.15, -sz.z * 0.45))
			_omni(container, Color(0.90, 0.18, 0.12), 0.7, 2.2,
				Vector3(-sz.x * 0.55, hy * 0.3, 0.0))
			_omni(container, Color(0.12, 0.85, 0.22), 0.7, 2.2,
				Vector3( sz.x * 0.55, hy * 0.3, 0.0))
			_omni(container, Color(0.55, 0.65, 0.90), 0.5, 2.5,
				Vector3(0.0, hy + 0.25, 0.0))
		"Engines":
			_omni(container, Color(1.00, 0.45, 0.10), 2.0, 4.5,
				Vector3(0.0, 0.0, sz.z * 0.55))
			_omni(container, Color(0.40, 0.60, 1.00), 0.8, 2.8,
				Vector3(-sz.x * 0.42, hy * 0.4, -sz.z * 0.20))
			_omni(container, Color(0.40, 0.60, 1.00), 0.8, 2.8,
				Vector3( sz.x * 0.42, hy * 0.4, -sz.z * 0.20))
		"Power":
			_omni(container, Color(0.25, 0.70, 1.00), 2.2, 5.0,
				Vector3(0.0, hy * 0.2, 0.0))
			_omni(container, Color(0.15, 0.55, 0.65), 0.6, 2.5,
				Vector3(0.0, -hy * 0.6, sz.z * 0.35))
			_omni(container, Color(0.15, 0.55, 0.65), 0.6, 2.5,
				Vector3(0.0, -hy * 0.6, -sz.z * 0.35))
		"Tactical":
			_omni(container, Color(1.00, 0.35, 0.15), 1.5, 3.5,
				Vector3(0.0, hy + 0.10, -sz.z * 0.40))
			_omni(container, Color(0.85, 0.20, 0.10), 0.8, 2.8,
				Vector3(-sz.x * 0.40, hy * 0.5, 0.0))
			_omni(container, Color(0.85, 0.20, 0.10), 0.8, 2.8,
				Vector3( sz.x * 0.40, hy * 0.5, 0.0))
		_:
			_omni(container, Color(0.90, 0.82, 0.60), 0.9, 3.0,
				Vector3(0.0, hy + 0.10, 0.0))
			_omni(container, Color(0.70, 0.72, 0.80), 0.5, 2.2,
				Vector3(0.0, -hy * 0.5, 0.0))


static func _omni(parent: Node3D, col: Color, energy: float, rng: float,
		pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color               = col
	light.light_energy              = energy
	light.omni_range                = rng
	light.omni_attenuation          = 1.8
	light.shadow_enabled            = false
	light.position                  = pos
	parent.add_child(light)
