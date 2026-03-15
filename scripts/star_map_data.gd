## star_map_data.gd — Autoloaded as "StarMapData"
## Fixed 3D galaxy map. Positions do NOT change between sessions.
## One unit ≈ 3.5 days of travel at standard speed.
extends Node

# ── Star system definitions ──────────────────────────────────────────────────
# Fields: id, name, type, pos (Vector3), color, size (visual radius), desc
# Types: "star"  "planet"  "station"  "nebula"  "asteroid"  "black_hole"
const SYSTEMS: Array = [
	# ── Inner systems (0–20 units from Sol) ─────────────────────────────────
	{ "id":"sol",        "name":"Sol",              "type":"star",       "pos":Vector3(  0,  0,  0), "color":Color(1.00,0.85,0.30,1), "size":3.0, "desc":"Home system. Yellow dwarf star."                  },
	{ "id":"proxima",    "name":"Proxima Centauri",  "type":"star",       "pos":Vector3( 12,  2,  8), "color":Color(0.90,0.40,0.20,1), "size":1.5, "desc":"Nearest neighbor. Quiet red dwarf."               },
	{ "id":"alpha_cen",  "name":"Alpha Centauri",    "type":"star",       "pos":Vector3( 18, -3,  6), "color":Color(1.00,0.90,0.60,1), "size":2.5, "desc":"Binary system, slightly cooler than Sol."         },
	{ "id":"station_k",  "name":"Kepler Station",    "type":"station",    "pos":Vector3(-15,  5, 14), "color":Color(0.50,0.70,1.00,1), "size":1.2, "desc":"Trade hub and primary refueling stop."            },
	{ "id":"belt_1",     "name":"Kepler Belt",       "type":"asteroid",   "pos":Vector3(  8, 10,-18), "color":Color(0.60,0.50,0.40,1), "size":2.0, "desc":"Dense asteroid mining belt. Navigation hazard."   },
	# ── Mid systems (20–50 units) ────────────────────────────────────────────
	{ "id":"sirius",     "name":"Sirius",            "type":"star",       "pos":Vector3( 32, -6, 15), "color":Color(0.70,0.85,1.00,1), "size":3.5, "desc":"Brilliant blue-white star. Intense radiation."    },
	{ "id":"vega",       "name":"Vega Prime",        "type":"planet",     "pos":Vector3( 45,  4,-12), "color":Color(0.30,0.60,0.90,1), "size":2.0, "desc":"Inhabited ocean world. Major trade port."         },
	{ "id":"rigel_out",  "name":"Rigel Outpost",     "type":"station",    "pos":Vector3( 38, 18, -8), "color":Color(0.50,0.70,1.00,1), "size":1.2, "desc":"Frontier military outpost. Well-armed."           },
	{ "id":"barnard",    "name":"Barnard's Star",    "type":"star",       "pos":Vector3(-30, -8, 25), "color":Color(0.90,0.35,0.15,1), "size":1.6, "desc":"Fast-moving red dwarf. Lonely and cold."          },
	{ "id":"new_haven",  "name":"New Haven",         "type":"planet",     "pos":Vector3(-22, 12,-28), "color":Color(0.55,0.72,0.38,1), "size":1.8, "desc":"Young colony world. Resources still untapped."    },
	# ── Far systems (50–85 units) ────────────────────────────────────────────
	{ "id":"cygnus",     "name":"Cygnus Reach",      "type":"nebula",     "pos":Vector3(-55, 20, 35), "color":Color(0.50,0.20,0.80,1), "size":4.5, "desc":"Vast ionized gas nebula. Comms interference."     },
	{ "id":"deneb",      "name":"Deneb",             "type":"star",       "pos":Vector3( 70,-12, 28), "color":Color(0.80,0.90,1.00,1), "size":4.5, "desc":"Supergiant. Luminosity 200,000× Sol."             },
	{ "id":"hadley",     "name":"Hadley's Hope",     "type":"planet",     "pos":Vector3(-38,-18, 62), "color":Color(0.40,0.55,0.30,1), "size":1.8, "desc":"Terraformed colony world. Rough but livable."     },
	{ "id":"polaris_st", "name":"Polaris Station",   "type":"station",    "pos":Vector3(  5, 55, 20), "color":Color(0.50,0.70,1.00,1), "size":1.4, "desc":"High-orbit nav beacon. Last safe stop north."     },
	{ "id":"iron_belt",  "name":"Iron Belt",         "type":"asteroid",   "pos":Vector3( 62,  8, 50), "color":Color(0.55,0.48,0.38,1), "size":2.5, "desc":"Rich iron and nickel deposits. Pirate activity."  },
	# ── Deep systems (85–120 units) ──────────────────────────────────────────
	{ "id":"tartarus",   "name":"Tartarus Void",     "type":"black_hole", "pos":Vector3( 65,  8,-42), "color":Color(0.05,0.00,0.10,1), "size":2.5, "desc":"Stellar-mass black hole. Extreme tidal stress."   },
	{ "id":"scylla",     "name":"Scylla Nebula",     "type":"nebula",     "pos":Vector3(-75, 28,-18), "color":Color(0.80,0.30,0.20,1), "size":5.5, "desc":"Stellar graveyard. Dense radiation. Hull wears fast."},
	{ "id":"elysium",    "name":"Elysium",           "type":"planet",     "pos":Vector3( 85, 28, 75), "color":Color(0.50,0.80,0.40,1), "size":2.2, "desc":"Legendary paradise world. Long journey, big reward."},
	{ "id":"frontier",   "name":"Frontier Station",  "type":"station",    "pos":Vector3(-68, -5, 82), "color":Color(0.50,0.70,1.00,1), "size":1.5, "desc":"Last outpost before the Rim. Anything for a price."},
	{ "id":"kronos",     "name":"Kronos Deep",       "type":"black_hole", "pos":Vector3( 95,-22, 48), "color":Color(0.00,0.02,0.05,1), "size":3.5, "desc":"Supermassive relic. Space-time distortion nearby."  },
	{ "id":"the_rim",    "name":"The Rim",           "type":"asteroid",   "pos":Vector3(108, 12,-58), "color":Color(0.50,0.45,0.35,1), "size":3.0, "desc":"Outermost frontier. No law. Extreme conditions."   },
]

# Extra wear per day for systems with harsh environments
const HARSH_SYSTEMS: Array = ["scylla", "tartarus", "kronos", "iron_belt", "belt_1"]

# Units of distance per in-game day at standard speed
const UNITS_PER_DAY: float = 3.5


# ── Query helpers ────────────────────────────────────────────────────────────
func find_system(id: String) -> Dictionary:
	for s in SYSTEMS:
		if s.id == id:
			return s
	return {}


func pick_destination(days: int, current_id: String) -> Dictionary:
	var current_sys := find_system(current_id)
	if current_sys.is_empty():
		current_sys = SYSTEMS[0]
	var current_pos: Vector3 = current_sys.pos

	var target_dist: float = float(days) * UNITS_PER_DAY
	var tolerance: float   = target_dist * 0.45

	var candidates: Array = []
	for s in SYSTEMS:
		if s.id == current_id:
			continue
		var d := current_pos.distance_to(s.pos)
		if abs(d - target_dist) <= tolerance:
			candidates.append(s)

	if candidates.is_empty():
		# Fall back: pick the system whose distance is closest to target
		var all_others: Array = []
		for s in SYSTEMS:
			if s.id != current_id:
				all_others.append(s)
		all_others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return abs(current_pos.distance_to(a.pos) - target_dist) \
			     < abs(current_pos.distance_to(b.pos) - target_dist))
		return all_others[0] if not all_others.is_empty() else SYSTEMS[1]

	return candidates[randi() % candidates.size()]


func build_path(origin_id: String, dest_id: String, days: int) -> Array[String]:
	## Returns Array of system IDs: [origin, ...waypoints..., dest]
	var path: Array[String] = [origin_id]

	var origin_sys := find_system(origin_id)
	var dest_sys   := find_system(dest_id)
	if origin_sys.is_empty() or dest_sys.is_empty():
		if not path.has(dest_id):
			path.append(dest_id)
		return path

	var o_pos: Vector3 = origin_sys.pos
	var d_pos: Vector3 = dest_sys.pos

	# Add 0, 1, or 2 intermediate waypoints depending on trip length
	var n_wps := 0
	if days >= 10: n_wps = 1
	if days >= 20: n_wps = 2

	for i in range(n_wps):
		var t := float(i + 1) / float(n_wps + 1)
		var target_pos := o_pos.lerp(d_pos, t)
		# Find the system closest to this interpolated point (not already in path)
		var best: Dictionary = {}
		var best_dist := INF
		for s in SYSTEMS:
			if path.has(s.id) or s.id == dest_id:
				continue
			var d := target_pos.distance_to(s.pos)
			if d < best_dist:
				best_dist = d
				best = s
		if not best.is_empty():
			path.append(best.id)

	path.append(dest_id)
	return path


func is_harsh(system_id: String) -> bool:
	return HARSH_SYSTEMS.has(system_id)
