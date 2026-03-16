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


func pick_destination(days: int, current_id: String, discovered: Array = []) -> Dictionary:
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
		if not discovered.is_empty() and not discovered.has(s.id):
			continue
		var d := current_pos.distance_to(s.pos)
		if abs(d - target_dist) <= tolerance:
			candidates.append(s)

	if candidates.is_empty():
		var all_others: Array = []
		for s in SYSTEMS:
			if s.id == current_id:
				continue
			if not discovered.is_empty() and not discovered.has(s.id):
				continue
			all_others.append(s)
		if all_others.is_empty():
			# Fallback: if no discovered systems match, use all
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


# ── Job board ────────────────────────────────────────────────────────────────

const JOB_TYPES: Array = [
	{ "tag": "Freight",            "desc": "Haul cargo containers to %s.",                      "pay_mult": 1.0  },
	{ "tag": "Personnel Transfer", "desc": "Transport crew rotation to %s.",                    "pay_mult": 0.9  },
	{ "tag": "Smuggling",          "desc": "Move undeclared goods to %s. No questions asked.",   "pay_mult": 1.4  },
	{ "tag": "Survey",             "desc": "Chart stellar phenomena near %s.",                   "pay_mult": 0.85 },
	{ "tag": "Medical Evac",       "desc": "Rush medical supplies to %s. Time-critical.",        "pay_mult": 1.1  },
	{ "tag": "Salvage Run",        "desc": "Recover wreckage in the vicinity of %s.",            "pay_mult": 1.2  },
	{ "tag": "Diplomatic Courier", "desc": "Deliver sealed documents to %s. Handle with care.",  "pay_mult": 0.95 },
	{ "tag": "Escort",             "desc": "Escort a convoy bound for %s.",                      "pay_mult": 1.15 },
	{ "tag": "Bounty Hunt",        "desc": "Track a fugitive last seen near %s.",                "pay_mult": 1.35 },
	{ "tag": "Colony Supply",      "desc": "Deliver building materials to %s.",                  "pay_mult": 1.05 },
]

func generate_job_listings(current_id: String, discovered: Array = []) -> Array:
	## Returns 1–5 random job listings from the current system.
	var current_sys := find_system(current_id)
	if current_sys.is_empty():
		current_sys = SYSTEMS[0]
	var current_pos: Vector3 = current_sys.pos

	# Gather all reachable destinations (exclude current, filter by discovered)
	var others: Array = []
	for s in SYSTEMS:
		if s.id == current_id:
			continue
		if not discovered.is_empty() and not discovered.has(s.id):
			continue
		others.append(s)
	others.shuffle()

	var count := randi_range(2, mini(5, others.size()))
	var listings: Array = []
	var used_types: Array = []

	for i in count:
		var dest: Dictionary = others[i]
		var dist: float = current_pos.distance_to(dest.pos)
		var days: int = maxi(1, roundi(dist / UNITS_PER_DAY))

		# Pick a job type (avoid repeats when possible)
		var pool: Array = JOB_TYPES.duplicate()
		pool.shuffle()
		var jtype: Dictionary = pool[0]
		for jt in pool:
			if not used_types.has(jt.tag):
				jtype = jt
				break
		used_types.append(jtype.tag)

		# Pay per day scales with distance and job type, with some variance
		var base_pay_per_day: int = roundi((45 + randi_range(0, 20)) * jtype.pay_mult)
		# Longer/riskier trips pay a bit more per day
		if days >= 10:
			base_pay_per_day += 8
		if days >= 20:
			base_pay_per_day += 12
		if is_harsh(dest.id):
			base_pay_per_day += 15

		listings.append({
			"destination_id":   dest.id,
			"destination_name": dest.name,
			"destination_desc": dest.desc,
			"days":             days,
			"pay_per_day":      base_pay_per_day,
			"total_pay":        base_pay_per_day * days,
			"job_type":         jtype.tag,
			"job_desc":         jtype.desc % dest.name,
			"harsh":            is_harsh(dest.id),
		})

	# Sort by days (shortest first)
	listings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.days < b.days)
	return listings


# ── Percy story missions ─────────────────────────────────────────────────────
# Sequential chain — each requires the previous completed.
# trigger types: "jobs_completed" (>= value), "system_discovered" (value in discovered)
const PERCY_MISSIONS: Array = [
	{
		"id":       "percy_01_first_steps",
		"title":    "First Steps",
		"location": "proxima",
		"trigger":  { "type": "jobs_completed", "value": 2 },
		"desc":     "Investigate a signal anomaly near Proxima Centauri.",
		"percy_msg": "\"Captain, I've been monitoring comm traffic and there's a strange repeating signal coming from Proxima. It's not natural — could be a buoy, could be something else. Swing by and take a look?\"",
		"days":     4,
		"reward":   500,
		"on_complete_discover": [],
	},
	{
		"id":       "percy_02_kepler_run",
		"title":    "Kepler Rendezvous",
		"location": "station_k",
		"trigger":  { "type": "jobs_completed", "value": 5 },
		"desc":     "Meet Percy's contact at Kepler Station for intel on unusual ship movements.",
		"percy_msg": "\"I've got an old friend at Kepler — retired Fleet Intelligence. She says there's been chatter about unmarked ships near the mid-rim. Dock at Kepler and I'll set up a meeting.\"",
		"days":     5,
		"reward":   800,
		"on_complete_discover": ["barnard", "new_haven"],
	},
	{
		"id":       "percy_03_barnard_trace",
		"title":    "The Cold Trail",
		"location": "barnard",
		"trigger":  { "type": "system_discovered", "value": "barnard" },
		"desc":     "Recover a flight recorder from a derelict near Barnard's Star.",
		"percy_msg": "\"That derelict near Barnard's Star — it's one of the unmarked ships we've been tracking. If we can pull its nav logs, we'll know where it came from. Are you in?\"",
		"days":     9,
		"reward":   1200,
		"on_complete_discover": ["cygnus"],
	},
	{
		"id":       "percy_04_cygnus_signal",
		"title":    "Into the Nebula",
		"location": "cygnus",
		"trigger":  { "type": "system_discovered", "value": "cygnus" },
		"desc":     "Follow the derelict's nav logs deep into Cygnus Reach.",
		"percy_msg": "\"The flight recorder data is clear — that ship came from deep inside Cygnus Reach. The nebula will mess with our comms, but we need to see what's out there. This is getting bigger than I expected.\"",
		"days":     16,
		"reward":   2000,
		"on_complete_discover": ["deneb", "hadley", "scylla"],
	},
	{
		"id":       "percy_05_frontier_contact",
		"title":    "Edge of the Map",
		"location": "frontier",
		"trigger":  { "type": "jobs_completed", "value": 12 },
		"desc":     "Meet an informant at Frontier Station who knows what those ships were doing.",
		"percy_msg": "\"I've pulled every string I have. There's someone at Frontier Station who knows what those ships were doing in Cygnus. Meet them, get the data, and get out. The Rim is no place to linger.\"",
		"days":     20,
		"reward":   3500,
		"on_complete_discover": ["elysium", "kronos", "the_rim"],
	},
]


func find_percy_mission(id: String) -> Dictionary:
	for m in PERCY_MISSIONS:
		if m.id == id:
			return m
	return {}
