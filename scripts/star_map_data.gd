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


func get_price_multiplier(system_id: String) -> float:
	## Price multiplier based on distance from Sol (origin).
	## Core = 1.0x, Mid-Ring = 1.25x, Outer = 1.5x, Deep Rim = 2.0x.
	var sys := find_system(system_id)
	if sys.is_empty():
		return 1.0
	var dist: float = sys.pos.length()
	if dist < 20.0:
		return 1.0    # Core (Sol, Proxima, Alpha Cen, Station K, Belt)
	if dist < 50.0:
		return 1.25   # Mid-Ring (Sirius, Vega, Rigel, Barnard, New Haven)
	if dist < 90.0:
		return 1.5    # Outer (Cygnus, Deneb, Hadley, Polaris, Iron Belt)
	return 2.0        # Deep Rim (Tartarus, Scylla, Elysium, Frontier, Kronos, The Rim)


func get_price_tier_name(system_id: String) -> String:
	var mult := get_price_multiplier(system_id)
	if mult <= 1.0:
		return "Core"
	if mult <= 1.25:
		return "Mid-Ring"
	if mult <= 1.5:
		return "Outer Rim"
	return "Deep Rim"


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

func generate_job_listings(current_id: String, discovered: Array = [], forced_destination: String = "") -> Array:
	## Returns 1–5 random job listings from the current system.
	## If forced_destination is set, returns exactly 1 job to that system.
	var current_sys := find_system(current_id)
	if current_sys.is_empty():
		current_sys = SYSTEMS[0]
	var current_pos: Vector3 = current_sys.pos

	# ── Forced single-destination mode (for mission failsafe) ─────────────
	if not forced_destination.is_empty():
		var dest := find_system(forced_destination)
		if dest.is_empty():
			return []
		var dist: float = current_pos.distance_to(dest.pos)
		var days: int = maxi(1, roundi(dist / UNITS_PER_DAY))
		var pool: Array = JOB_TYPES.duplicate()
		pool.shuffle()
		var jtype: Dictionary = pool[0]
		var base_pay_per_day: int = roundi((45 + randi_range(0, 20)) * jtype.pay_mult)
		if days >= 10:
			base_pay_per_day += 8
		if days >= 20:
			base_pay_per_day += 12
		if is_harsh(dest.id):
			base_pay_per_day += 15
		return [{
			"destination_id":   dest.id,
			"destination_name": dest.name,
			"destination_desc": dest.desc,
			"days":             days,
			"pay_per_day":      base_pay_per_day,
			"total_pay":        base_pay_per_day * days,
			"job_type":         jtype.tag,
			"job_desc":         jtype.desc % dest.name,
			"harsh":            is_harsh(dest.id),
		}]

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
		"dialogue": [
			{ "speaker": "percy", "text": "Captain, got a minute? I've been monitoring comm traffic on the long-range array." },
			{ "speaker": "captain", "text": "(You set down your coffee and turn to the console.)" },
			{ "speaker": "percy", "text": "There's a strange repeating signal coming from Proxima. It's not natural — could be a buoy, could be something else entirely." },
			{ "speaker": "percy", "text": "It's worth checking out. Swing by Proxima and take a look?" },
		],
		"debrief": [
			{ "speaker": "percy", "text": "Captain, you're going to want to see this." },
			{ "speaker": "captain", "text": "(You lean over Percy's console as he pulls up the scan data.)" },
			{ "speaker": "percy", "text": "That signal? It was a nav buoy — but not one of ours. The encryption is military-grade, and it's using a frequency band that was decommissioned years ago." },
			{ "speaker": "percy", "text": "Someone is running ghost traffic through Proxima. This isn't random. I need to dig deeper." },
		],
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
		"dialogue": [
			{ "speaker": "percy", "text": "Captain, I called in a favor. I've got an old friend at Kepler — retired Fleet Intelligence." },
			{ "speaker": "captain", "text": "(You raise an eyebrow. Percy doesn't call in favors lightly.)" },
			{ "speaker": "percy", "text": "She says there's been chatter about unmarked ships near the mid-rim. No transponders, no registry. They appear, they vanish." },
			{ "speaker": "percy", "text": "Dock at Kepler and I'll set up a meeting. Whatever this is, it's connected to that buoy at Proxima." },
		],
		"debrief": [
			{ "speaker": "percy", "text": "That meeting was... illuminating." },
			{ "speaker": "captain", "text": "(Percy looks troubled — more than usual.)" },
			{ "speaker": "percy", "text": "My contact confirmed it. At least a dozen sightings of unmarked ships in the last six months. They're running dark — no comms, no IDs, nothing." },
			{ "speaker": "percy", "text": "She gave us two leads. Barnard's Star and New Haven. One of those ships was last spotted near Barnard — and it's not moving anymore." },
			{ "speaker": "captain", "text": "(A derelict. That changes things.)" },
		],
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
		"dialogue": [
			{ "speaker": "percy", "text": "That derelict near Barnard's Star — I've confirmed it. It's one of the unmarked ships." },
			{ "speaker": "captain", "text": "(You pull up the scan. The hull is dark. No life signs.)" },
			{ "speaker": "percy", "text": "If we can board it and pull the flight recorder, we'll finally know where these ships are coming from." },
			{ "speaker": "percy", "text": "It's a cold run — lonely system, no backup. Are you in?" },
		],
		"debrief": [
			{ "speaker": "percy", "text": "We got the flight recorder. Took some work — the data core was half-fried — but I pulled the nav logs." },
			{ "speaker": "captain", "text": "(You watch Percy's face as he scrolls through the data.)" },
			{ "speaker": "percy", "text": "Captain... this ship came from deep inside Cygnus Reach. The nebula. It made at least four round trips before whatever happened to it happened." },
			{ "speaker": "percy", "text": "Four trips to the same coordinates. Someone has a base out there. Or something worse." },
		],
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
		"dialogue": [
			{ "speaker": "percy", "text": "The flight recorder data is clear. Those coordinates are deep inside Cygnus Reach." },
			{ "speaker": "captain", "text": "(You study the star chart. The nebula is vast — and known for disrupting comms.)" },
			{ "speaker": "percy", "text": "I won't lie to you, Captain. The nebula will mess with our communications. Once we're in, we're on our own." },
			{ "speaker": "percy", "text": "But we've come too far to turn back. This is getting bigger than I expected — and I need to know what's out there." },
		],
		"debrief": [
			{ "speaker": "percy", "text": "Captain. You need to sit down for this." },
			{ "speaker": "captain", "text": "(The look on Percy's face tells you everything and nothing at once.)" },
			{ "speaker": "percy", "text": "We found a staging area. Supply caches. Fuel depots. Enough infrastructure for a small fleet to operate indefinitely." },
			{ "speaker": "percy", "text": "And it's not pirates. The equipment is too clean, too organized. This is institutional. Someone with real resources built this." },
			{ "speaker": "percy", "text": "I've charted four new systems from the data we pulled. Deneb, Hadley, Scylla, and Frontier Station. The answers are out there somewhere." },
		],
		"days":     16,
		"reward":   2000,
		"on_complete_discover": ["deneb", "hadley", "scylla", "frontier"],
	},
	{
		"id":       "percy_05_frontier_contact",
		"title":    "Edge of the Map",
		"location": "frontier",
		"trigger":  { "type": "jobs_completed", "value": 12 },
		"desc":     "Meet an informant at Frontier Station who knows what those ships were doing.",
		"percy_msg": "\"I've pulled every string I have. There's someone at Frontier Station who knows what those ships were doing in Cygnus. Meet them, get the data, and get out. The Rim is no place to linger.\"",
		"dialogue": [
			{ "speaker": "percy", "text": "I've pulled every string I have. This is it, Captain." },
			{ "speaker": "captain", "text": "(You can hear the weight in his voice. This has been building for a long time.)" },
			{ "speaker": "percy", "text": "There's someone at Frontier Station who knows what those ships were doing in Cygnus. An informant — ex-operations, gone to ground." },
			{ "speaker": "percy", "text": "Meet them, get the data, and get out. The Rim is no place to linger." },
		],
		"debrief": [
			{ "speaker": "percy", "text": "We got what we came for. The informant came through." },
			{ "speaker": "captain", "text": "(Percy is quiet for a long moment before he speaks again.)" },
			{ "speaker": "percy", "text": "Those ships — the ghost fleet — they were running a survey operation. Mapping something in deep space. Something they didn't want anyone to know about." },
			{ "speaker": "percy", "text": "The informant gave us coordinates to three more systems. Elysium, Kronos Deep, The Rim. Whatever they were mapping... it's out there." },
			{ "speaker": "percy", "text": "Captain, I started this thinking it was smugglers or pirates. It's not. This goes all the way up. We need to be careful who we trust from here." },
		],
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


# ── Crew Member Story Missions ──────────────────────────────────────────────
# Each crew member has a sequential chain (enforced per-crew, not global).
# "crew" field links to portrait/name lookups in main.gd.

const CREW_MISSIONS: Array = [
	# ── Roswell — "The Truth Is Out There" ──────────────────────────────────
	{
		"id":       "roswell_01_strange_signals",
		"crew":     "roswell",
		"title":    "Strange Signals",
		"location": "belt_1",
		"trigger":  { "type": "jobs_completed", "value": 3 },
		"desc":     "Roswell swears he's picking up non-human transmissions from the asteroid belt.",
		"crew_msg": "\"Captain! CAPTAIN! You gotta hear this — I rigged the long-range array to scan sub-harmonic frequencies and there's SOMETHING out there in the Belt. It's patterned. It's STRUCTURED. Everyone says it's just pulsar bleed but pulsars don't transmit in prime-number intervals! Just — please — one detour. That's all I'm asking.\"",
		"dialogue": [
			{ "speaker": "roswell", "text": "Captain! CAPTAIN! You gotta hear this!" },
			{ "speaker": "captain", "text": "(Roswell is practically vibrating as he shoves a headset at you.)" },
			{ "speaker": "roswell", "text": "I rigged the long-range array to scan sub-harmonic frequencies and there's SOMETHING out there in the Belt. It's patterned. It's STRUCTURED." },
			{ "speaker": "captain", "text": "(You listen. There is... something. A rhythm in the static.)" },
			{ "speaker": "roswell", "text": "Everyone says it's just pulsar bleed but pulsars don't transmit in prime-number intervals! Just — please — one detour. That's all I'm asking." },
		],
		"debrief": [
			{ "speaker": "roswell", "text": "Captain. I need you to look at this and tell me I'm not crazy." },
			{ "speaker": "captain", "text": "(You look at the scan data. The pattern is undeniable.)" },
			{ "speaker": "roswell", "text": "The signal is real. It's structured, it's repeating, and it's coming from deeper in space. The Belt was just picking up the echo." },
			{ "speaker": "roswell", "text": "I'm going to run a triangulation. If I can find the source... Captain, this could be the biggest discovery in human history. Or I'm wrong and Mika gets to schedule me for that psych eval." },
		],
		"days":     3,
		"reward":   300,
		"on_complete_discover": [],
	},
	{
		"id":       "roswell_02_vega_anomaly",
		"crew":     "roswell",
		"title":    "The Vega Anomaly",
		"location": "vega",
		"trigger":  { "type": "system_discovered", "value": "vega" },
		"desc":     "Roswell traced the Belt signal to an energy source near Vega. Mika thinks he needs a psych eval.",
		"crew_msg": "\"I TOLD you the Belt signals were real! I ran a triangulation and the origin point is Vega. It's a BEACON, Captain. Mika keeps scheduling me for 'wellness checks' but I'm not crazy — well, maybe a little — but I'm not WRONG. Vega. We need to get to Vega.\"",
		"dialogue": [
			{ "speaker": "roswell", "text": "I TOLD you the Belt signals were real! The triangulation came back!" },
			{ "speaker": "captain", "text": "(You glance at Mika, who is standing in the doorway with a very patient expression.)" },
			{ "speaker": "mika", "text": "For the record, I've scheduled Roswell for a wellness check. He hasn't slept in three days." },
			{ "speaker": "roswell", "text": "I don't NEED sleep, I need VEGA! The origin point is Vega Prime — it's a BEACON, Captain. I'm not crazy. Well, maybe a little. But I'm not WRONG." },
		],
		"debrief": [
			{ "speaker": "roswell", "text": "It's a relay. A RELAY, Captain!" },
			{ "speaker": "captain", "text": "(Roswell's hands are shaking as he shows you the readings.)" },
			{ "speaker": "roswell", "text": "Vega wasn't the source. It was bouncing the signal — amplifying it and sending it deeper into space. Whatever is transmitting, it's further out. Much further." },
			{ "speaker": "roswell", "text": "I'm picking up a faint materials signature from the Iron Belt. Something... anomalous. I need to trace it." },
			{ "speaker": "mika", "text": "Roswell. Sleep first. Then trace." },
		],
		"days":     7,
		"reward":   600,
		"on_complete_discover": [],
	},
	{
		"id":       "roswell_03_proof",
		"crew":     "roswell",
		"title":    "Roswell's Proof",
		"location": "iron_belt",
		"trigger":  { "type": "jobs_completed", "value": 8 },
		"desc":     "An alien artifact in the Iron Belt. The crew is skeptical, but the readings don't lie.",
		"crew_msg": "\"OK so Vega was a relay — it was bouncing the signal DEEPER. I've traced it to the Iron Belt and Captain, I'm picking up a materials signature that doesn't match anything in our database. Not human. Not natural. I know nobody believes me but when we pull this thing out of the rock, they will. They ALL will.\"",
		"dialogue": [
			{ "speaker": "roswell", "text": "OK. I've traced it. The Iron Belt. The materials signature doesn't match ANYTHING in our database." },
			{ "speaker": "captain", "text": "(You pull up the scan. He's right — the composition is unlike anything on record.)" },
			{ "speaker": "roswell", "text": "Not human. Not natural. I know nobody believes me. But when we pull this thing out of the rock, they will." },
			{ "speaker": "roswell", "text": "They ALL will." },
		],
		"debrief": [
			{ "speaker": "roswell", "text": "..." },
			{ "speaker": "captain", "text": "(Roswell is standing in the cargo bay, staring at the object on the deck. For once, he's speechless.)" },
			{ "speaker": "roswell", "text": "It's... it's beautiful, Captain. Look at the geometry. No human hand made this. No known process could shape it." },
			{ "speaker": "roswell", "text": "I've spent my whole life looking, and here it is. Proof. Real, physical, undeniable proof." },
			{ "speaker": "captain", "text": "(The artifact pulses faintly. A soft, rhythmic glow.)" },
			{ "speaker": "roswell", "text": "And it's... I think it's waking up." },
		],
		"days":     12,
		"reward":   1000,
		"on_complete_discover": ["polaris_st"],
	},
	{
		"id":       "roswell_04_first_contact",
		"crew":     "roswell",
		"title":    "First Contact",
		"location": "tartarus",
		"trigger":  { "type": "system_discovered", "value": "tartarus" },
		"desc":     "The artifact is transmitting coordinates to Tartarus. Something is waiting there.",
		"crew_msg": "\"It's activated. The artifact — it started transmitting the moment we pulled it aboard. Coordinates. Tartarus. Captain, I've spent my whole life being the guy people laugh at. The conspiracy nut. The space case. But this is REAL and whatever is at those coordinates has been waiting a very long time for someone to show up. I think it should be us.\"",
		"dialogue": [
			{ "speaker": "roswell", "text": "It's activated. The artifact — it started transmitting the moment we pulled it aboard." },
			{ "speaker": "captain", "text": "(The cargo bay hums with a low, resonant tone you can feel in your teeth.)" },
			{ "speaker": "roswell", "text": "Coordinates. Tartarus Void. Captain, I've spent my whole life being the guy people laugh at. The conspiracy nut. The space case." },
			{ "speaker": "roswell", "text": "But this is REAL. Whatever is at those coordinates has been waiting a very long time for someone to show up." },
			{ "speaker": "roswell", "text": "I think it should be us." },
		],
		"debrief": [
			{ "speaker": "captain", "text": "(The void is silent. The artifact has gone dark.)" },
			{ "speaker": "roswell", "text": "Captain, I... I don't have words. And you know how rare that is for me." },
			{ "speaker": "roswell", "text": "Whatever was at Tartarus — it acknowledged us. The artifact lit up like a star, transmitted a burst of data we'll be decoding for years, and then... went quiet." },
			{ "speaker": "roswell", "text": "Not dead. Just... finished. Like it did what it was built to do." },
			{ "speaker": "captain", "text": "(Roswell wipes his eyes. He's not embarrassed about it.)" },
			{ "speaker": "roswell", "text": "My whole life, Captain. My whole life I said we weren't alone. And now I know. Thank you for believing me. Even when it was hard to." },
		],
		"days":     18,
		"reward":   2500,
		"on_complete_discover": [],
	},

	# ── Zester — "Hold My Drink" ────────────────────────────────────────────
	{
		"id":       "zester_01_bar_tab",
		"crew":     "zester",
		"title":    "Bar Tab",
		"location": "alpha_cen",
		"trigger":  { "type": "jobs_completed", "value": 4 },
		"desc":     "Zester ran up a massive bar tab at Alpha Centauri. A bounty hunter is asking questions.",
		"crew_msg": "\"So, uh, Captain... funny story. Remember when we docked at Alpha Cen last month? And I said I was going to 'study local customs'? Well, turns out the local customs include a drink called a Supernova Slam and also I may have challenged someone to a drinking contest and also I lost and also there's a bounty hunter? Can we maybe swing by and settle this before I get spaced? Percy is SO mad.\"",
		"dialogue": [
			{ "speaker": "zester", "text": "So, uh, Captain... funny story." },
			{ "speaker": "captain", "text": "(That phrase has never once preceded a funny story.)" },
			{ "speaker": "zester", "text": "Remember when we docked at Alpha Cen last month? And I said I was going to 'study local customs'?" },
			{ "speaker": "zester", "text": "Turns out the local customs include a drink called a Supernova Slam and also I may have challenged someone to a drinking contest and also I lost and also there's a bounty hunter?" },
			{ "speaker": "percy", "text": "I am SO mad right now." },
			{ "speaker": "zester", "text": "Can we maybe swing by and settle this before I get spaced?" },
		],
		"debrief": [
			{ "speaker": "zester", "text": "OK so good news and bad news." },
			{ "speaker": "captain", "text": "(You brace yourself.)" },
			{ "speaker": "zester", "text": "Good news: the bounty hunter is paid off, the bar tab is settled, and I am NOT getting spaced!" },
			{ "speaker": "zester", "text": "Bad news: I may have promised we'd come back for a rematch. But that's a future Zester problem." },
			{ "speaker": "percy", "text": "There will be no rematch." },
		],
		"days":     2,
		"reward":   200,
		"on_complete_discover": [],
	},
	{
		"id":       "zester_02_the_bet",
		"crew":     "zester",
		"title":    "The Bet",
		"location": "sirius",
		"trigger":  { "type": "system_discovered", "value": "sirius" },
		"desc":     "Zester bet a Sirius dock boss he could run the gap in under 5 days. Now he needs your ship.",
		"crew_msg": "\"Captain, I can explain. See, there's this guy at Sirius — Big Ren — and he said NO ship could run the Sirius gap in under five days and I said OURS could and he said prove it and I said BET and now there's money on the line and also our reputation and also possibly my kneecaps? But the PAYOUT, Captain! Think of the payout!\"",
		"dialogue": [
			{ "speaker": "zester", "text": "Captain, I can explain. See, there's this guy at Sirius — Big Ren." },
			{ "speaker": "captain", "text": "(You already know where this is going.)" },
			{ "speaker": "zester", "text": "He said NO ship could run the Sirius gap in under five days and I said OURS could and he said prove it and I said BET!" },
			{ "speaker": "zester", "text": "And now there's money on the line and also our reputation and also possibly my kneecaps? But the PAYOUT, Captain! Think of the payout!" },
		],
		"debrief": [
			{ "speaker": "zester", "text": "WE DID IT! Four days, seventeen hours! Big Ren's face was PRICELESS!" },
			{ "speaker": "captain", "text": "(Zester is doing a victory dance in the cockpit. Even Shadow is wagging.)" },
			{ "speaker": "zester", "text": "He paid up, every credit, AND he told me about a supply outpost — Rigel. Off the main charts. Said it's a good spot to refuel if we're ever out that way." },
			{ "speaker": "zester", "text": "See? My ideas WORK. Sometimes. Occasionally. This time for sure though." },
		],
		"days":     5,
		"reward":   450,
		"on_complete_discover": ["rigel_out"],
	},
	{
		"id":       "zester_03_contraband_kitten",
		"crew":     "zester",
		"title":    "Contraband Kitten",
		"location": "new_haven",
		"trigger":  { "type": "system_discovered", "value": "new_haven" },
		"desc":     "Zester smuggled an exotic creature aboard from New Haven. Customs is scanning ships.",
		"crew_msg": "\"OK DON'T BE MAD but there's a creature in my quarters and before you say anything — it FOLLOWED me! It's some kind of bioluminescent space cat thing and it's ADORABLE and also technically classified as a protected xenofauna specimen and also New Haven customs is scanning every ship that left dock. Shadow's been helping me hide it but it keeps teleporting into the vents. We gotta return it before we all get arrested.\"",
		"dialogue": [
			{ "speaker": "zester", "text": "OK DON'T BE MAD." },
			{ "speaker": "captain", "text": "(That's even worse than 'funny story.')" },
			{ "speaker": "zester", "text": "There's a creature in my quarters and before you say anything — it FOLLOWED me! It's some kind of bioluminescent space cat thing and it's ADORABLE." },
			{ "speaker": "shadow", "text": "I've been helping hide it, sir. It's very soft." },
			{ "speaker": "zester", "text": "Also it's technically classified as a protected xenofauna specimen and New Haven customs is scanning every ship that left dock. And it keeps teleporting into the vents. We gotta return it before we all get arrested." },
		],
		"debrief": [
			{ "speaker": "zester", "text": "OK so the space cat is back home. Safely. Officially." },
			{ "speaker": "captain", "text": "(Zester looks genuinely sad for once.)" },
			{ "speaker": "zester", "text": "The wildlife officer said it's a Lumin Kit — they're endangered. She wasn't mad, actually. Said it happens a lot. They're apparently very... social." },
			{ "speaker": "shadow", "text": "I miss it already, sir." },
			{ "speaker": "zester", "text": "Me too. But hey — customs cleared us, no fines, and the officer said we did the right thing bringing it back. Percy almost smiled. Almost." },
		],
		"days":     8,
		"reward":   900,
		"on_complete_discover": [],
	},
	{
		"id":       "zester_04_gambit",
		"crew":     "zester",
		"title":    "Zester's Gambit",
		"location": "scylla",
		"trigger":  { "type": "jobs_completed", "value": 10 },
		"desc":     "Zester stumbled into a smuggling ring at Scylla. For once, his chaos might actually help.",
		"crew_msg": "\"Captain, OK, so I was at this bar on Scylla — I know, I know — but LISTEN. These guys were talking about moving cargo through unmarked ships and fake transponder codes and I accidentally sat at their table and they think I'm a buyer and I kind of played along? And now I know their whole operation and I think we can take them DOWN. For real this time. No kittens involved. Probably.\"",
		"dialogue": [
			{ "speaker": "zester", "text": "Captain, OK, so I was at this bar on Scylla — I know, I KNOW — but LISTEN." },
			{ "speaker": "captain", "text": "(You pinch the bridge of your nose.)" },
			{ "speaker": "zester", "text": "These guys were talking about moving cargo through unmarked ships and fake transponder codes and I accidentally sat at their table." },
			{ "speaker": "zester", "text": "They think I'm a buyer and I kind of played along? And now I know their whole operation." },
			{ "speaker": "zester", "text": "Captain, I think we can take them DOWN. For real this time. No kittens involved. Probably." },
		],
		"debrief": [
			{ "speaker": "zester", "text": "Captain... we actually did it." },
			{ "speaker": "captain", "text": "(Zester is unusually quiet. It's unsettling.)" },
			{ "speaker": "zester", "text": "The intel was good. Security moved in, shut down the whole ring. Fake transponders, forged manifests, all of it." },
			{ "speaker": "percy", "text": "I'll admit it, Zester. You did good work. Reckless, foolish, unauthorized work — but good work." },
			{ "speaker": "zester", "text": "Did... did Percy just compliment me? Captain, did you hear that? I'm framing this moment." },
		],
		"days":     14,
		"reward":   1800,
		"on_complete_discover": [],
	},

	# ── Shadow — "Good Boy" ─────────────────────────────────────────────────
	{
		"id":       "shadow_01_lost_freighter",
		"crew":     "shadow",
		"title":    "Lost Freighter",
		"location": "rigel_out",
		"trigger":  { "type": "system_discovered", "value": "rigel_out" },
		"desc":     "Shadow picked up a faint distress signal near Rigel Outpost. He won't stop whining about it.",
		"crew_msg": "\"Captain, sir? I... I keep hearing something on channel 9. It's faint but it sounds like people, sir. Scared people. I think there's a freighter out near Rigel that's in real trouble and nobody else is close enough to help. I know it's out of our way and I know it might be nothing but... what if it's not nothing, sir? I couldn't live with myself.\"",
		"dialogue": [
			{ "speaker": "shadow", "text": "Captain, sir? I... I keep hearing something on channel 9." },
			{ "speaker": "captain", "text": "(Shadow's ears are practically flat against his head. He's worried.)" },
			{ "speaker": "shadow", "text": "It's faint but it sounds like people, sir. Scared people. I think there's a freighter out near Rigel that's in real trouble." },
			{ "speaker": "shadow", "text": "Nobody else is close enough to help. I know it's out of our way but... what if it's not nothing, sir? I couldn't live with myself." },
		],
		"debrief": [
			{ "speaker": "shadow", "text": "They're safe, sir. All twelve of them." },
			{ "speaker": "captain", "text": "(Shadow is beaming. His whole body is wagging.)" },
			{ "speaker": "shadow", "text": "The freighter's nav system failed and they drifted off-course. They'd been rationing food for a week. The kids were so scared, sir." },
			{ "speaker": "shadow", "text": "But we got there in time. The station is taking care of them now. The captain — she said to tell you thank you. She cried a little." },
			{ "speaker": "shadow", "text": "I cried a little too, sir. Don't tell Zester." },
		],
		"days":     6,
		"reward":   400,
		"on_complete_discover": [],
	},
	{
		"id":       "shadow_02_friend",
		"crew":     "shadow",
		"title":    "Shadow's Friend",
		"location": "hadley",
		"trigger":  { "type": "system_discovered", "value": "hadley" },
		"desc":     "Someone Shadow befriended at Hadley is in trouble with local enforcers.",
		"crew_msg": "\"Captain, sir, I need to tell you something. When we were at Hadley, I met this person — Kel — and they were really kind to me, sir. Shared their rations and everything. But now Kel sent me a message saying the local enforcers are after them for something they didn't do. Roswell says the enforcers are 'government agents' but I just think they're wrong about Kel. Can we help, sir? Please?\"",
		"dialogue": [
			{ "speaker": "shadow", "text": "Captain, sir, I need to tell you something. When we were at Hadley, I met this person — Kel." },
			{ "speaker": "captain", "text": "(Shadow fidgets with his sleeve, not meeting your eyes.)" },
			{ "speaker": "shadow", "text": "They were really kind to me, sir. Shared their rations and everything. But now Kel sent me a message — the local enforcers are after them for something they didn't do." },
			{ "speaker": "roswell", "text": "The enforcers are government agents! I've seen the files!" },
			{ "speaker": "shadow", "text": "I just think they're wrong about Kel. Can we help, sir? Please?" },
		],
		"debrief": [
			{ "speaker": "shadow", "text": "Kel is safe, sir. We cleared their name." },
			{ "speaker": "captain", "text": "(Shadow looks relieved enough to float.)" },
			{ "speaker": "shadow", "text": "Turns out the enforcers had Kel confused with someone else — same shuttle registry number, different person entirely. Once we showed them the records, they dropped the whole thing." },
			{ "speaker": "shadow", "text": "Kel said... Kel said I was the only one who believed them. That means a lot, sir. To both of us." },
		],
		"days":     9,
		"reward":   700,
		"on_complete_discover": [],
	},
	{
		"id":       "shadow_03_rescue_run",
		"crew":     "shadow",
		"title":    "Rescue Run",
		"location": "polaris_st",
		"trigger":  { "type": "system_discovered", "value": "polaris_st" },
		"desc":     "Medical emergency at Polaris Station. Shadow volunteered us before asking.",
		"crew_msg": "\"Captain, sir, I may have done a thing. Polaris Station put out an emergency medical call — they need supplies and they need them fast and the regular supply runs can't get there in time. And I... I told them we'd come, sir. I know I should have asked first and I'm real sorry but people are sick and Mika says she can help with the triage if we can just get the supplies there. I'll do extra shifts, sir. Whatever it takes.\"",
		"dialogue": [
			{ "speaker": "shadow", "text": "Captain, sir, I may have done a thing." },
			{ "speaker": "captain", "text": "(Shadow is already in his 'please don't be mad' posture.)" },
			{ "speaker": "shadow", "text": "Polaris Station put out an emergency medical call — they need supplies fast and the regular supply runs can't get there in time." },
			{ "speaker": "shadow", "text": "And I... I told them we'd come, sir. I know I should have asked first and I'm real sorry." },
			{ "speaker": "mika", "text": "For what it's worth, Captain, I can help with triage when we arrive. Shadow made the right call." },
		],
		"debrief": [
			{ "speaker": "mika", "text": "Fourteen patients stabilized. The supplies arrived just in time." },
			{ "speaker": "captain", "text": "(Mika and Shadow are both exhausted but glowing.)" },
			{ "speaker": "shadow", "text": "We saved them, sir. All of them. The station doctor said another day and they would have lost people." },
			{ "speaker": "mika", "text": "Shadow worked through three shifts straight. Wouldn't leave the med bay until everyone was stable." },
			{ "speaker": "shadow", "text": "I just carried things, sir. Mika did the real work. Oh — and the station cartographer gave us updated charts. Something about a system called Tartarus nearby." },
		],
		"days":     11,
		"reward":   1100,
		"on_complete_discover": ["tartarus"],
	},
	{
		"id":       "shadow_04_long_way_home",
		"crew":     "shadow",
		"title":    "The Long Way Home",
		"location": "elysium",
		"trigger":  { "type": "system_discovered", "value": "elysium" },
		"desc":     "An old friend of Shadow's is stranded at Elysium. Shadow refuses to leave without them.",
		"crew_msg": "\"Captain, sir, I know this is a lot to ask. My friend Brin — we served together before I joined your crew — they're stranded at Elysium. Their ship broke down and there's no repair yard out that far and they've been there for weeks, sir. I can't sleep thinking about them alone out there. Elysium is beautiful but it's so far from everything. Please, sir. I'll owe you everything.\"",
		"dialogue": [
			{ "speaker": "shadow", "text": "Captain, sir, I know this is a lot to ask." },
			{ "speaker": "captain", "text": "(Shadow takes a deep breath. This is clearly hard for him.)" },
			{ "speaker": "shadow", "text": "My friend Brin — we served together before I joined your crew — they're stranded at Elysium. Ship broke down. No repair yard out that far." },
			{ "speaker": "shadow", "text": "They've been there for weeks, sir. I can't sleep thinking about them alone out there. Elysium is beautiful but it's so far from everything." },
			{ "speaker": "shadow", "text": "Please, sir. I'll owe you everything." },
		],
		"debrief": [
			{ "speaker": "shadow", "text": "Brin is on board, sir. They're safe." },
			{ "speaker": "captain", "text": "(Shadow and Brin are sitting in the galley. They haven't stopped talking for hours.)" },
			{ "speaker": "shadow", "text": "Their drive coil cracked — unfixable without a proper yard. They'd been surviving on emergency rations and rainwater. Three weeks alone on the most beautiful planet in the galaxy." },
			{ "speaker": "shadow", "text": "Brin said the sunsets were incredible but they couldn't enjoy them because they kept thinking nobody was coming." },
			{ "speaker": "shadow", "text": "But we came, sir. We always come. That's what this crew does." },
		],
		"days":     16,
		"reward":   2200,
		"on_complete_discover": [],
	},

	# ── Mika — "The Calm Center" ────────────────────────────────────────────
	{
		"id":       "mika_01_session_notes",
		"crew":     "mika",
		"title":    "Session Notes",
		"location": "station_k",
		"trigger":  { "type": "jobs_completed", "value": 6 },
		"desc":     "A crew member at Station K is having a breakdown. Mika is the only qualified counselor in range.",
		"crew_msg": "\"Captain, I've received a priority request from Kepler Station's medical officer. One of their long-haul freighter crews has a navigator showing signs of acute dissociative episodes — talking about 'ships that aren't there' and 'signals in the static.' Sound familiar? I don't think this is coincidence. Whatever Percy's been investigating with those unmarked ships, it's affecting people. I need to get there.\"",
		"dialogue": [
			{ "speaker": "mika", "text": "Captain, I've received a priority request from Kepler Station's medical officer." },
			{ "speaker": "captain", "text": "(Mika's voice is calm, but her eyes say otherwise.)" },
			{ "speaker": "mika", "text": "One of their freighter crews has a navigator showing signs of acute dissociative episodes. He keeps talking about 'ships that aren't there' and 'signals in the static.'" },
			{ "speaker": "captain", "text": "(That sounds familiar. Too familiar.)" },
			{ "speaker": "mika", "text": "Whatever Percy's been investigating with those unmarked ships — it's affecting people. I need to get there." },
		],
		"debrief": [
			{ "speaker": "mika", "text": "The navigator is stabilized. He'll need long-term care, but the crisis is past." },
			{ "speaker": "captain", "text": "(Mika sets down a cup of tea she hasn't touched.)" },
			{ "speaker": "mika", "text": "Captain, what he described — the ships, the signals — it matches Percy's reports almost exactly. This man wasn't delusional. He saw something real." },
			{ "speaker": "mika", "text": "Whatever is happening out there, it's leaving marks on the people who encounter it. Psychological marks. I'll be watching our crew carefully." },
		],
		"days":     4,
		"reward":   350,
		"on_complete_discover": [],
	},
	{
		"id":       "mika_02_negotiator",
		"crew":     "mika",
		"title":    "The Negotiator",
		"location": "deneb",
		"trigger":  { "type": "system_discovered", "value": "deneb" },
		"desc":     "Hostage situation at Deneb. Mika is the only one who can talk the captain down.",
		"crew_msg": "\"A freighter captain at Deneb has locked down his ship with passengers aboard. He's demanding safe passage out of the system — says someone is hunting him. Local security wants to breach but there are civilians inside. I can talk him down, Captain. I've handled worse. Just... keep Zester away from the comms this time. Last thing we need is him 'helping.'\"",
		"dialogue": [
			{ "speaker": "mika", "text": "A freighter captain at Deneb has locked down his ship with passengers aboard." },
			{ "speaker": "captain", "text": "(You pull up the security feed. Thirty civilians. One armed captain.)" },
			{ "speaker": "mika", "text": "He's demanding safe passage out of the system — says someone is hunting him. Local security wants to breach." },
			{ "speaker": "mika", "text": "I can talk him down, Captain. I've handled worse." },
			{ "speaker": "zester", "text": "I could help! I'm great with people—" },
			{ "speaker": "mika", "text": "Keep Zester away from the comms. Last thing we need is him 'helping.'" },
		],
		"debrief": [
			{ "speaker": "mika", "text": "All passengers are safe. The captain surrendered peacefully." },
			{ "speaker": "captain", "text": "(Mika looks tired but satisfied.)" },
			{ "speaker": "mika", "text": "He wasn't a bad man, Captain. He was terrified. Said he'd seen unmarked ships tailing his routes for months. When he reported it, his employer fired him." },
			{ "speaker": "mika", "text": "He locked down because he thought the ships had finally come for him. The paranoia was real — but so was the threat that caused it." },
			{ "speaker": "mika", "text": "Another thread connecting back to Percy's investigation. This web keeps getting wider." },
		],
		"days":     10,
		"reward":   800,
		"on_complete_discover": [],
	},
	{
		"id":       "mika_03_old_ghosts",
		"crew":     "mika",
		"title":    "Old Ghosts",
		"location": "kronos",
		"trigger":  { "type": "system_discovered", "value": "kronos" },
		"desc":     "At Kronos, Mika encounters a former patient — now running a pirate crew.",
		"crew_msg": "\"I need to tell you something, Captain. Before I joined your crew, I worked at a rehabilitation facility on the inner worlds. One of my patients — Vasek — was deeply troubled. Brilliant, but broken. I thought I helped them. I was wrong. Vasek is at Kronos now, running a crew of outcasts, and they're getting dangerous. This is my responsibility. I failed them once. I won't fail them again.\"",
		"dialogue": [
			{ "speaker": "mika", "text": "I need to tell you something, Captain. Something personal." },
			{ "speaker": "captain", "text": "(Mika closes the door. She never closes the door.)" },
			{ "speaker": "mika", "text": "Before I joined your crew, I worked at a rehabilitation facility. One of my patients — Vasek — was deeply troubled. Brilliant, but broken." },
			{ "speaker": "mika", "text": "I thought I helped them. I was wrong. Vasek is at Kronos now, running a crew of outcasts. They're getting dangerous." },
			{ "speaker": "mika", "text": "This is my responsibility. I failed them once. I won't fail them again." },
		],
		"debrief": [
			{ "speaker": "mika", "text": "Vasek listened. Eventually." },
			{ "speaker": "captain", "text": "(Mika is staring out the viewport. Her hands are steady but her voice isn't quite.)" },
			{ "speaker": "mika", "text": "They were angry at first. Called me a fraud. Said my 'therapy' was just words and the universe doesn't run on words." },
			{ "speaker": "mika", "text": "But I sat with them. For hours. And eventually the anger ran out and what was underneath was just... hurt. A lot of hurt." },
			{ "speaker": "mika", "text": "Vasek agreed to stand down. Their crew is dispersing peacefully. I gave them a comm frequency — mine. For when they need to talk." },
			{ "speaker": "mika", "text": "I can't fix what I missed before. But I can be there now. That has to be enough." },
		],
		"days":     15,
		"reward":   1500,
		"on_complete_discover": [],
	},
	{
		"id":       "mika_04_breaking_point",
		"crew":     "mika",
		"title":    "Breaking Point",
		"location": "the_rim",
		"trigger":  { "type": "jobs_completed", "value": 15 },
		"desc":     "At The Rim, everything Percy uncovered comes to a head. Mika must keep the crew together.",
		"crew_msg": "\"Captain, I won't sugarcoat this. What Percy found — what those unmarked ships were doing out here — it's bigger than any of us expected. The crew is scared. Roswell's oscillating between vindication and paranoia. Shadow hasn't slept. Even Zester's gone quiet, and that terrifies me more than anything. We're going to The Rim, and we're going to finish this. But I need you to trust me when I say: the biggest danger out there isn't what we'll find. It's what it'll do to us. I'll keep them together. That's my job. That's what I do.\"",
		"dialogue": [
			{ "speaker": "mika", "text": "Captain, I won't sugarcoat this." },
			{ "speaker": "captain", "text": "(Mika's usual calm has an edge to it you haven't heard before.)" },
			{ "speaker": "mika", "text": "What Percy found — what those unmarked ships were doing out here — it's bigger than any of us expected. The crew is scared." },
			{ "speaker": "mika", "text": "Roswell's oscillating between vindication and paranoia. Shadow hasn't slept. Even Zester's gone quiet, and that terrifies me more than anything." },
			{ "speaker": "mika", "text": "We're going to The Rim, and we're going to finish this. But I need you to trust me: the biggest danger isn't what we'll find. It's what it'll do to us." },
			{ "speaker": "mika", "text": "I'll keep them together. That's my job. That's what I do." },
		],
		"debrief": [
			{ "speaker": "mika", "text": "We made it, Captain. All of us. Together." },
			{ "speaker": "captain", "text": "(The crew is gathered in the galley. Nobody's talking, but nobody's alone.)" },
			{ "speaker": "mika", "text": "The Rim tested us. Every one of us hit a wall out there — fear, doubt, the sheer weight of what we found." },
			{ "speaker": "mika", "text": "But nobody broke. Roswell kept his head. Shadow found his courage. Zester... well, Zester made a terrible joke at the worst possible moment. It was exactly what we needed." },
			{ "speaker": "mika", "text": "Captain, I've served on a lot of ships. I've never seen a crew hold together like this one." },
			{ "speaker": "mika", "text": "Whatever comes next — and something will come next — we'll be ready. Because we have each other." },
		],
		"days":     22,
		"reward":   3000,
		"on_complete_discover": [],
	},

	# ── Bella — "The Right Rooms" ────────────────────────────────────────────
	{
		"id":       "bella_01_the_gala",
		"crew":     "bella",
		"title":    "The Gala",
		"location": "station_k",
		"trigger":  { "type": "jobs_completed", "value": 4 },
		"desc":     "Bella needs premium cargo delivered to Kepler Station for a charity gala. She also needs an escort who looks the part.",
		"crew_msg": "\"Oh, Captain, perfect timing. The Merchant Guild's annual charity gala is at Kepler Station and I promised them a shipment of Centauri vintage that absolutely cannot be late. I'll also need you to attend — as my escort, obviously. Don't worry about what to wear, Rina already picked something out for you. Just try to look like you belong and don't let Zester anywhere near the drinks table.\"",
		"dialogue": [
			{ "speaker": "bella", "text": "Oh, Captain, perfect timing. I need to discuss the gala." },
			{ "speaker": "captain", "text": "(Bella sweeps in with the air of someone who has never not been in charge of a room.)" },
			{ "speaker": "bella", "text": "The Merchant Guild's annual charity gala is at Kepler Station and I promised them a shipment of Centauri vintage that absolutely cannot be late." },
			{ "speaker": "bella", "text": "I'll also need you to attend — as my escort, obviously. Rina already picked something out for you." },
			{ "speaker": "bella", "text": "Just try to look like you belong. And don't let Zester anywhere near the drinks table." },
		],
		"debrief": [
			{ "speaker": "bella", "text": "The gala was a triumph, Captain. You clean up surprisingly well." },
			{ "speaker": "captain", "text": "(You're not sure if that was a compliment.)" },
			{ "speaker": "bella", "text": "The vintage arrived on time, the Guild chair was delighted, and I secured three new trade contacts that will be extremely useful." },
			{ "speaker": "rina", "text": "She also danced with the Trade Commissioner. Twice." },
			{ "speaker": "bella", "text": "That was networking, Rina. Highly strategic networking." },
		],
		"days":     4,
		"reward":   380,
		"on_complete_discover": [],
	},
	{
		"id":       "bella_02_the_switch",
		"crew":     "bella",
		"title":    "The Switch",
		"location": "sirius",
		"trigger":  { "type": "system_discovered", "value": "sirius" },
		"desc":     "Rina got into trouble at Sirius using Bella's name. Now Bella has to fix it before it destroys her standing in the gala circuit.",
		"crew_msg": "\"I am going to kill my sister. Rina — lovely, impulsive, disaster-prone Rina — went to Sirius ahead of me, introduced herself as me, and apparently made some rather memorable promises to a shipping consortium that I absolutely cannot keep. Now my name is on a contract for something I don't understand and the consortium is asking questions. We need to get to Sirius, quietly, before this becomes an incident.\"",
		"dialogue": [
			{ "speaker": "bella", "text": "I am going to kill my sister." },
			{ "speaker": "captain", "text": "(Bella is holding a comm tablet like she wants to snap it in half.)" },
			{ "speaker": "bella", "text": "Rina — lovely, impulsive, disaster-prone Rina — went to Sirius, introduced herself as ME, and made promises to a shipping consortium I absolutely cannot keep." },
			{ "speaker": "bella", "text": "Now my name is on a contract for something I don't understand. We need to get to Sirius before this becomes an incident." },
		],
		"debrief": [
			{ "speaker": "bella", "text": "The contract is voided. My reputation is intact. Barely." },
			{ "speaker": "captain", "text": "(Bella and Rina are pointedly not looking at each other.)" },
			{ "speaker": "bella", "text": "The consortium was... understanding, once I explained the situation. They actually found it charming, which is infuriating." },
			{ "speaker": "rina", "text": "I was trying to help! The terms they were pushing were predatory—" },
			{ "speaker": "bella", "text": "You impersonated me, Rina. Again. We will discuss this privately. At length." },
		],
		"days":     7,
		"reward":   650,
		"on_complete_discover": [],
	},
	{
		"id":       "bella_03_auction",
		"crew":     "bella",
		"title":    "The Auction",
		"location": "new_haven",
		"trigger":  { "type": "system_discovered", "value": "new_haven" },
		"desc":     "Bella and Rina are bidding on a rare artifact at New Haven. So is Murphy — on behalf of someone else. [CROSSOVER: Murphy]",
		"crew_msg": "\"There is a pre-colonial navigational sphere coming up at New Haven's antiquities auction and Rina and I intend to have it. It's stunning, it's historically significant, and several other very wealthy people also want it, which only makes it more appealing. The complication is that there's a man there — calls himself Murphy, looks like he slept in his jacket — who is apparently also bidding on behalf of some merchant. Captain, we need you there to authenticate the piece. You know how these auctions can be.\"",
		"dialogue": [
			{ "speaker": "bella", "text": "There is a pre-colonial navigational sphere at New Haven's antiquities auction. Rina and I intend to have it." },
			{ "speaker": "captain", "text": "(Bella produces a catalog. The sphere is genuinely beautiful.)" },
			{ "speaker": "bella", "text": "The complication is that man — Murphy. Looks like he slept in his jacket. He's bidding on behalf of some merchant." },
			{ "speaker": "bella", "text": "Captain, we need you there to authenticate the piece. These auctions can get... competitive." },
		],
		"debrief": [
			{ "speaker": "bella", "text": "Well. That was unexpected." },
			{ "speaker": "captain", "text": "(The auction room is empty. Everyone looks slightly stunned.)" },
			{ "speaker": "bella", "text": "Murphy outbid us. Politely. Charmingly, even. His employer — Tumbler, apparently — wanted it for some kind of preservation project." },
			{ "speaker": "rina", "text": "I'm not even mad. Murphy was very... persuasive about why the sphere should be preserved properly." },
			{ "speaker": "bella", "text": "We lost the sphere but gained a contact. Tumbler's collection is legitimate, and his network reaches everywhere. That may prove more valuable than any artifact." },
		],
		"days":     9,
		"reward":   900,
		"on_complete_discover": [],
	},
	{
		"id":       "bella_04_scandal",
		"crew":     "bella",
		"title":    "Society Scandal",
		"location": "deneb",
		"trigger":  { "type": "system_discovered", "value": "deneb" },
		"desc":     "Forged documents are circulating at Deneb that could destroy both twins' reputations. Someone is trying to erase them from the social register.",
		"crew_msg": "\"Captain. I need you to understand I am not a person who panics. I am also not panicking now. However — there are forged letters circulating at Deneb, apparently originating from our ship's manifest records, that claim Rina and I have been running unlicensed cargo for years. It's fabricated. All of it. But fabrications have a way of becoming truth once enough people believe them. Someone wants us gone from these circles. I intend to find out who, and I intend to be very unpleasant about it.\"",
		"dialogue": [
			{ "speaker": "bella", "text": "Captain. I need you to understand I am not a person who panics." },
			{ "speaker": "captain", "text": "(Bella's composure is flawless, which means something is very wrong.)" },
			{ "speaker": "bella", "text": "There are forged letters circulating at Deneb claiming Rina and I have been running unlicensed cargo for years. Fabricated. All of it." },
			{ "speaker": "bella", "text": "But fabrications become truth once enough people believe them. Someone wants us gone from these circles." },
			{ "speaker": "bella", "text": "I intend to find out who. And I intend to be very unpleasant about it." },
		],
		"debrief": [
			{ "speaker": "bella", "text": "Found them. A former business rival — petty, jealous, and thoroughly outclassed." },
			{ "speaker": "captain", "text": "(Bella looks like a woman who has just won a war.)" },
			{ "speaker": "bella", "text": "The forgeries were sloppy once you knew where to look. Wrong manifest codes, wrong date formats. Amateur work." },
			{ "speaker": "rina", "text": "Bella confronted them at their own dinner party. In front of everyone. It was magnificent and terrifying." },
			{ "speaker": "bella", "text": "Our standing is restored. Their standing is... less so. Nobody forges my name and gets away with it." },
		],
		"days":     13,
		"reward":   1600,
		"on_complete_discover": [],
	},

	# ── Rina — "Half the Story" ──────────────────────────────────────────────
	{
		"id":       "rina_01_my_version",
		"crew":     "rina",
		"title":    "My Version",
		"location": "sirius",
		"trigger":  { "type": "system_discovered", "value": "sirius" },
		"desc":     "Rina has her own account of what happened at Sirius. It is very different from Bella's.",
		"crew_msg": "\"OK so Bella told you her version of the Sirius thing. I want to tell you my version because hers is technically accurate but emotionally completely wrong. Yes, I used her name. Yes, there's a contract. But the consortium is shady — the terms they were pushing would have locked her into three years of exclusivity that she'd have hated. I was protecting her. Also the man they had negotiating is extraordinarily handsome and I may have gotten a little off-track. But my heart was in the right place. Captain, can we go fix this together? Without Bella?\"",
		"dialogue": [
			{ "speaker": "rina", "text": "OK so Bella told you her version of the Sirius thing. I want to tell you mine." },
			{ "speaker": "captain", "text": "(Rina checks the corridor to make sure Bella isn't nearby.)" },
			{ "speaker": "rina", "text": "Hers is technically accurate but emotionally completely wrong. Yes, I used her name. Yes, there's a contract." },
			{ "speaker": "rina", "text": "But the consortium is shady — the terms would have locked her into three years of exclusivity. I was protecting her!" },
			{ "speaker": "rina", "text": "Also the negotiator is extraordinarily handsome and I may have gotten a little off-track. But my heart was in the right place. Can we fix this together? Without Bella?" },
		],
		"debrief": [
			{ "speaker": "rina", "text": "OK so... I was right about the consortium. They ARE shady." },
			{ "speaker": "captain", "text": "(Rina is holding a data tablet with a look of vindication.)" },
			{ "speaker": "rina", "text": "When we dug into the contract terms, we found hidden clauses that would have siphoned Bella's trade contacts into their network. It was a trap." },
			{ "speaker": "rina", "text": "So yes, I went about it the wrong way. But I was RIGHT. Please tell Bella that. Actually, don't — I'll tell her myself. Eventually. Maybe." },
		],
		"days":     7,
		"reward":   650,
		"on_complete_discover": [],
	},
	{
		"id":       "rina_02_the_find",
		"crew":     "rina",
		"title":    "Rina's Find",
		"location": "belt_1",
		"trigger":  { "type": "jobs_completed", "value": 6 },
		"desc":     "Rina quietly bought something unusual at a Kepler Belt salvage auction. She doesn't want Bella to know what it is yet.",
		"crew_msg": "\"Captain! Just you, please — don't get Bella. I picked something up at the Kepler Belt salvage auction. Small, weird-looking, nobody else bid on it, I got it for almost nothing. Thing is, when I got it back to my quarters it started... glowing. A little. Intermittently. I'm not saying it's important, I'm just saying Roswell looked at it and went very quiet, which I've never seen him do before. We should go back to the Belt and check where it came from. Before Bella finds out I spent our gala budget on a glowing mystery rock.\"",
		"dialogue": [
			{ "speaker": "rina", "text": "Captain! Just you, please — don't get Bella." },
			{ "speaker": "captain", "text": "(Rina glances around conspiratorially.)" },
			{ "speaker": "rina", "text": "I picked something up at the Kepler Belt salvage auction. Small, weird-looking, nobody else bid on it." },
			{ "speaker": "rina", "text": "When I got it back to my quarters it started... glowing. A little. Intermittently." },
			{ "speaker": "roswell", "text": "..." },
			{ "speaker": "rina", "text": "Roswell looked at it and went very quiet, which I've NEVER seen him do before. We should go back to the Belt and check where it came from. Before Bella finds out I spent our gala budget on a glowing mystery rock." },
		],
		"debrief": [
			{ "speaker": "rina", "text": "OK so the mystery rock? It's real. REALLY real." },
			{ "speaker": "captain", "text": "(Rina and Roswell are huddled over a scanner, both wide-eyed.)" },
			{ "speaker": "roswell", "text": "It's emitting the same frequency patterns as the signals I've been tracking. This thing is connected to everything." },
			{ "speaker": "rina", "text": "I bought an alien artifact for twelve credits at a junk auction. Bella is going to be furious. And then impressed. Mostly furious." },
		],
		"days":     5,
		"reward":   500,
		"on_complete_discover": [],
	},
	{
		"id":       "rina_03_the_real_deal",
		"crew":     "rina",
		"title":    "The Real Deal",
		"location": "iron_belt",
		"trigger":  { "type": "system_discovered", "value": "iron_belt" },
		"desc":     "The rock Rina bought is a pre-colonial calibration device. Murphy's boss Tumbler wants it badly — and so does someone else. [CROSSOVER: Murphy, Tumbler]",
		"crew_msg": "\"So. Murphy came to see me. Politely. Very politely. He says the thing I bought — which turns out to be a navigation calibrator from the first expansion era, which is EXTREMELY rare — is on a list of things his employer is looking for. He was charming about it. He said his employer has been quietly assembling a collection at the Iron Belt for preservation purposes. I believe him. But someone else has been following our ship since Kepler, and they are not charming at all. Captain, I think we need to be careful about who else knows what I've got.\"",
		"dialogue": [
			{ "speaker": "rina", "text": "So. Murphy came to see me. Politely. Very politely." },
			{ "speaker": "captain", "text": "(Rina looks both flattered and concerned.)" },
			{ "speaker": "rina", "text": "The thing I bought turns out to be a navigation calibrator from the first expansion era. EXTREMELY rare. Murphy's employer wants it for a preservation collection." },
			{ "speaker": "rina", "text": "I believe him. But someone else has been following our ship since Kepler. And they are NOT charming." },
			{ "speaker": "rina", "text": "Captain, we need to be careful about who else knows what I've got." },
		],
		"debrief": [
			{ "speaker": "rina", "text": "The calibrator is safe. Murphy's employer — Tumbler — is the real deal." },
			{ "speaker": "captain", "text": "(The Iron Belt facility is more impressive than expected. Climate-controlled, professionally curated.)" },
			{ "speaker": "rina", "text": "The people following us? Murphy handled them. Quietly. He's more capable than he looks." },
			{ "speaker": "rina", "text": "I donated the calibrator to Tumbler's collection. Bella would say I gave away a fortune. But some things are worth more than money. Don't tell her I said that." },
		],
		"days":     12,
		"reward":   1200,
		"on_complete_discover": [],
	},

	# ── Tumbler — "The Trade Boss" ───────────────────────────────────────────
	{
		"id":       "tumbler_01_the_toll",
		"crew":     "tumbler",
		"title":    "The Toll",
		"location": "belt_1",
		"trigger":  { "type": "jobs_completed", "value": 5 },
		"desc":     "Someone is levying illegal tariffs on Kepler Belt trade routes using forged Merchant Guild credentials.",
		"crew_msg": "\"Captain. I'll be brief because I don't waste time on pleasantries. Someone is running a toll scheme through the Kepler Belt using credentials that look like mine. They're good forgeries — good enough that three of my captains paid without question. Murphy is occupied, my eyesight makes field work impractical, and the Guild won't move without evidence. You go, you document it, you get me names. I pay on results. Ask anyone.\"",
		"dialogue": [
			{ "speaker": "tumbler", "text": "Captain. I'll be brief because I don't waste time on pleasantries." },
			{ "speaker": "captain", "text": "(Tumbler's voice is measured. Every word costs him something to say.)" },
			{ "speaker": "tumbler", "text": "Someone is running a toll scheme through the Kepler Belt using credentials that look like mine. Good forgeries — three of my captains paid without question." },
			{ "speaker": "tumbler", "text": "Murphy is occupied, my eyesight makes field work impractical, and the Guild won't move without evidence." },
			{ "speaker": "tumbler", "text": "You go. You document it. You get me names. I pay on results. Ask anyone." },
		],
		"debrief": [
			{ "speaker": "tumbler", "text": "Names. Give me the names." },
			{ "speaker": "captain", "text": "(You hand Tumbler the data. His expression doesn't change, but his grip on the tablet tightens.)" },
			{ "speaker": "tumbler", "text": "Former Guild associates. Of course. I suspected as much." },
			{ "speaker": "tumbler", "text": "They'll be dealt with through proper channels. I don't do revenge, Captain. I do consequences. There is a difference." },
			{ "speaker": "tumbler", "text": "You did clean work. I'll remember that." },
		],
		"days":     5,
		"reward":   600,
		"on_complete_discover": [],
	},
	{
		"id":       "tumbler_02_murphy_is_late",
		"crew":     "tumbler",
		"title":    "Murphy Is Late",
		"location": "barnard",
		"trigger":  { "type": "system_discovered", "value": "barnard" },
		"desc":     "Murphy went dark on a retrieval run to Barnard's Star. Tumbler is too proud to say he's worried. [CROSSOVER: Murphy]",
		"crew_msg": "\"Murphy is twelve days overdue from a retrieval at Barnard's Star. This is not unusual. Murphy is often late. However, twelve days is pushing it even for him and I find I am... monitoring the comms more than typical. If you are going near Barnard, I am not asking you to look for him. I am merely noting that I would be informed of any information you happened to come across. There would be a finder's fee. Of a professional nature. Not a sentimental one.\"",
		"dialogue": [
			{ "speaker": "tumbler", "text": "Murphy is twelve days overdue from a retrieval at Barnard's Star." },
			{ "speaker": "captain", "text": "(Tumbler's face is perfectly neutral. Too neutral.)" },
			{ "speaker": "tumbler", "text": "This is not unusual. Murphy is often late. However, twelve days is pushing it even for him." },
			{ "speaker": "tumbler", "text": "I find I am... monitoring the comms more than typical. If you are going near Barnard, I am not asking you to look for him." },
			{ "speaker": "tumbler", "text": "I am merely noting that there would be a finder's fee. Of a professional nature. Not a sentimental one." },
		],
		"debrief": [
			{ "speaker": "tumbler", "text": "Murphy. Report." },
			{ "speaker": "murphy", "text": "Got pinned down by claim jumpers, boss. Three days behind a rock formation. Found some excellent artifacts though!" },
			{ "speaker": "tumbler", "text": "You were twelve days overdue. That is unacceptable." },
			{ "speaker": "murphy", "text": "Fourteen, actually. The extra two were because I found a really interesting—" },
			{ "speaker": "tumbler", "text": "Captain. Thank you. The finder's fee will be in your account. This conversation is over." },
			{ "speaker": "captain", "text": "(Tumbler turns away, but not before you catch something that might be relief on his face.)" },
		],
		"days":     9,
		"reward":   800,
		"on_complete_discover": [],
	},
	{
		"id":       "tumbler_03_the_collection",
		"crew":     "tumbler",
		"title":    "The Collection",
		"location": "iron_belt",
		"trigger":  { "type": "jobs_completed", "value": 10 },
		"desc":     "Tumbler needs items picked up and delivered to a secure Iron Belt location. He won't say what they are.",
		"crew_msg": "\"I have several items at different locations that need to reach a secure facility at the Iron Belt. Each is marked with a gold seal — you'll know them when you see them. Handle them carefully. They are irreplaceable. No, I won't tell you what they are. That's not relevant to the job. What is relevant is that nobody else knows about this run. Not Murphy, not the Guild, not your crew. This is between you and me, Captain. Are we clear?\"",
		"dialogue": [
			{ "speaker": "tumbler", "text": "I have items at different locations that need to reach a secure facility at the Iron Belt." },
			{ "speaker": "captain", "text": "(Tumbler slides a manifest across the table. It's encrypted.)" },
			{ "speaker": "tumbler", "text": "Each is marked with a gold seal. Handle them carefully. They are irreplaceable." },
			{ "speaker": "tumbler", "text": "No, I won't tell you what they are. That's not relevant to the job." },
			{ "speaker": "tumbler", "text": "Nobody else knows about this run. Not Murphy, not the Guild, not your crew. This is between you and me. Are we clear?" },
		],
		"debrief": [
			{ "speaker": "tumbler", "text": "Everything arrived intact. Good." },
			{ "speaker": "captain", "text": "(The Iron Belt facility is larger than you expected. Climate-controlled. Museum-grade storage.)" },
			{ "speaker": "tumbler", "text": "You're wondering what this is. I can hear it in your silence." },
			{ "speaker": "tumbler", "text": "It's a museum, Captain. Or it will be. Humanity's expansion — the real history, not the version they print in textbooks. Artifacts, records, first-hand accounts." },
			{ "speaker": "tumbler", "text": "Someone needs to preserve what actually happened before it's lost. I have the means. So I do it." },
		],
		"days":     14,
		"reward":   1400,
		"on_complete_discover": [],
	},
	{
		"id":       "tumbler_04_clear_sight",
		"crew":     "tumbler",
		"title":    "Clear Sight",
		"location": "elysium",
		"trigger":  { "type": "system_discovered", "value": "elysium" },
		"desc":     "A surgeon at Elysium may be able to restore Tumbler's eyesight — but the procedure requires a rare material Murphy has been quietly collecting for years. [CROSSOVER: Murphy]",
		"crew_msg": "\"There is a microsurgeon at Elysium. Dr. Voss. She believes she can restore my vision using a crystalline neural compound found only at the outer rim. I would not normally tell anyone this. I am telling you because Murphy — who never once mentioned this to me — has apparently spent three years quietly collecting the compound on his retrieval runs. I found out by accident. He never said a word. I need you to bring me to Elysium, Captain. And if you see Murphy before I do, tell him... tell him he's getting a raise.\"",
		"dialogue": [
			{ "speaker": "tumbler", "text": "There is a microsurgeon at Elysium. Dr. Voss. She believes she can restore my vision." },
			{ "speaker": "captain", "text": "(Tumbler's voice is steady, but his hands are not.)" },
			{ "speaker": "tumbler", "text": "The procedure requires a crystalline neural compound found only at the outer rim. I would not normally tell anyone this." },
			{ "speaker": "tumbler", "text": "I am telling you because Murphy — who never once mentioned this to me — has apparently spent three years quietly collecting the compound on his retrieval runs." },
			{ "speaker": "tumbler", "text": "I found out by accident. He never said a word. Bring me to Elysium, Captain. And tell Murphy... tell him he's getting a raise." },
		],
		"debrief": [
			{ "speaker": "tumbler", "text": "Captain." },
			{ "speaker": "captain", "text": "(Tumbler is standing at the viewport. For the first time, he's actually looking at the stars.)" },
			{ "speaker": "tumbler", "text": "Dr. Voss says the procedure was successful. Full recovery expected within weeks. I will see clearly again." },
			{ "speaker": "tumbler", "text": "Murphy is here. He won't look at me. He keeps saying it was 'just something he picked up along the way.'" },
			{ "speaker": "tumbler", "text": "Three years. Every retrieval run. 'Just something he picked up.' That man is the worst liar I have ever employed. And the best person." },
			{ "speaker": "tumbler", "text": "I owe you a debt, Captain. I pay my debts." },
		],
		"days":     18,
		"reward":   2800,
		"on_complete_discover": [],
	},

	# ── Murphy — "Procurement" ───────────────────────────────────────────────
	{
		"id":       "murphy_01_vega_job",
		"crew":     "murphy",
		"title":    "Vega Job",
		"location": "vega",
		"trigger":  { "type": "system_discovered", "value": "vega" },
		"desc":     "Murphy needs a ride to Vega Prime to retrieve a pre-colonial artifact from a private collection. He's cheerful about it. The owner doesn't know he's coming.",
		"crew_msg": "\"Captain! Great news — I need a lift to Vega Prime. There's a navigational astrolabe from the First Expansion sitting in a private collection out there and the current owner has absolutely no idea what it's worth, historically speaking. I have a very reasonable plan to acquire it. The plan involves charm, a believable cover story, and if necessary, a fast exit. You provide the fast exit, I handle everything else. My employer will compensate you generously. He always does. Eventually. The paperwork takes a while.\"",
		"dialogue": [
			{ "speaker": "murphy", "text": "Captain! Great news — I need a lift to Vega Prime." },
			{ "speaker": "captain", "text": "(Murphy's definition of 'great news' is always concerning.)" },
			{ "speaker": "murphy", "text": "There's a navigational astrolabe from the First Expansion sitting in a private collection. The current owner has no idea what it's worth." },
			{ "speaker": "murphy", "text": "I have a very reasonable plan. Charm, a believable cover story, and if necessary — a fast exit. You provide the fast exit." },
			{ "speaker": "murphy", "text": "My employer will compensate you generously. He always does. Eventually. The paperwork takes a while." },
		],
		"debrief": [
			{ "speaker": "murphy", "text": "The astrolabe is secured, the owner is happy, and nobody had to run!" },
			{ "speaker": "captain", "text": "(Murphy is cradling the artifact like a newborn.)" },
			{ "speaker": "murphy", "text": "Turns out the owner was delighted to sell once I explained what it actually was. He thought it was a fancy paperweight his grandfather left him." },
			{ "speaker": "murphy", "text": "Paid a fair price. Tumbler will be pleased. This is a First Expansion original — there are maybe six of these left in existence." },
			{ "speaker": "murphy", "text": "I love this job, Captain. Every piece has a story. You just have to know how to listen." },
		],
		"days":     7,
		"reward":   550,
		"on_complete_discover": [],
	},
	{
		"id":       "murphy_02_lost_in_the_rock",
		"crew":     "murphy",
		"title":    "Lost in the Rock",
		"location": "iron_belt",
		"trigger":  { "type": "system_discovered", "value": "iron_belt" },
		"desc":     "Murphy is pinned down by claim jumpers in the Iron Belt. Roswell heard his distress call before Murphy officially sent one. [CROSSOVER: Roswell]",
		"crew_msg": "\"...OK, so, small situation. The retrieval at the Iron Belt went sideways. Claim jumpers — six of them, well-armed, not in the mood to talk. I'm wedged behind a very aesthetically interesting rock formation and my ship has exactly one working thruster. Funny thing is, I heard Roswell's voice on the comms before I even sent a distress call — something about sub-harmonic frequencies? I don't know how he found me but I'm choosing not to question it. Captain, if you could come get me, that would be wonderful. I've found three remarkable things out here, incidentally. Real finds. Worth the trip, I promise.\"",
		"dialogue": [
			{ "speaker": "murphy", "text": "...OK, so, small situation." },
			{ "speaker": "captain", "text": "(The comm is crackling. Murphy sounds winded but cheerful.)" },
			{ "speaker": "murphy", "text": "Retrieval went sideways. Claim jumpers — six of them. I'm wedged behind a rock formation and my ship has one working thruster." },
			{ "speaker": "roswell", "text": "I found him! Sub-harmonic frequencies — his distress beacon was transmitting before he even activated it. Weird, right?" },
			{ "speaker": "murphy", "text": "I don't know how Roswell found me but I'm choosing not to question it. Captain, if you could come get me? I found three remarkable things out here. Worth the trip." },
		],
		"debrief": [
			{ "speaker": "murphy", "text": "I'm alive, everything's intact, and LOOK at these finds!" },
			{ "speaker": "captain", "text": "(Murphy is covered in rock dust and grinning like it's his birthday.)" },
			{ "speaker": "murphy", "text": "The claim jumpers scattered the moment your ship showed up. Cowards. But effective cowards — they stripped my secondary thruster clean." },
			{ "speaker": "roswell", "text": "Murphy, how did your beacon transmit before you activated it? That's not how beacons work." },
			{ "speaker": "murphy", "text": "Roswell, I was behind a rock being shot at. I didn't take notes. Thank you for finding me. Let's never speak of the beacon thing again." },
		],
		"days":     10,
		"reward":   900,
		"on_complete_discover": [],
	},
	{
		"id":       "murphy_03_provenance",
		"crew":     "murphy",
		"title":    "Provenance",
		"location": "new_haven",
		"trigger":  { "type": "system_discovered", "value": "new_haven" },
		"desc":     "Murphy is at the New Haven auction for the same artifact as Bella and Rina. He asks the Captain to mediate. [CROSSOVER: Bella, Rina]",
		"crew_msg": "\"Captain. Good news and complicated news. Good news: the navigation sphere at New Haven is genuine — I've seen its twin in a museum on Kepler and the provenance markers match. Complicated news: two very charming, very persistent women who I believe are somehow the same person are also bidding on it and they keep asking me questions I'm finding difficult to answer coherently. My employer needs that sphere. The twins seem very attached to the idea of having it. I think maybe you could talk to everyone? You're good at people. I'm good at artifacts. This situation requires both.\"",
		"dialogue": [
			{ "speaker": "murphy", "text": "Captain. Good news and complicated news." },
			{ "speaker": "captain", "text": "(Murphy looks slightly flushed. That's new.)" },
			{ "speaker": "murphy", "text": "Good news: the navigation sphere at New Haven is genuine. Complicated news: two very charming women who may be the same person are also bidding on it." },
			{ "speaker": "murphy", "text": "They keep asking me questions I'm finding difficult to answer coherently. My employer needs that sphere." },
			{ "speaker": "murphy", "text": "You're good at people. I'm good at artifacts. This situation requires both." },
		],
		"debrief": [
			{ "speaker": "murphy", "text": "The sphere is secured for Tumbler's collection. The twins are... not entirely unhappy about it." },
			{ "speaker": "captain", "text": "(Murphy keeps glancing toward the door Bella and Rina left through.)" },
			{ "speaker": "murphy", "text": "I explained what the collection is for — preservation, documentation, making sure these pieces survive. They understood." },
			{ "speaker": "murphy", "text": "Rina said I was 'surprisingly eloquent for someone who sleeps in his jacket.' I choose to take that as a compliment." },
			{ "speaker": "murphy", "text": "Captain, between you and me — this job gets lonely. It was nice to talk to people who actually care about history." },
		],
		"days":     9,
		"reward":   900,
		"on_complete_discover": [],
	},
	{
		"id":       "murphy_04_what_tumbler_wants",
		"crew":     "murphy",
		"title":    "What Tumbler Wants",
		"location": "hadley",
		"trigger":  { "type": "system_discovered", "value": "hadley" },
		"desc":     "At Hadley's Hope, Murphy finally tells the Captain what the collection is really for — and why he never told Tumbler about the compound.",
		"crew_msg": "\"Captain, can I tell you something in confidence? Everything I've retrieved — everything sitting in that Iron Belt facility — Tumbler is building a museum. A real one. Permanent. He wants to document humanity's entire expansion before the records are lost or rewritten. He doesn't talk about his eyesight but I've known for years it's more than just vision. He's running out of time and he's trying to leave something behind. I've been finding the neural compound on every job for three years. I didn't tell him because he'd have told me to stop and focus on the work. He would never ask for help. Some people are like that. You just help them anyway.\"",
		"dialogue": [
			{ "speaker": "murphy", "text": "Captain, can I tell you something in confidence?" },
			{ "speaker": "captain", "text": "(Murphy's usual cheerfulness is gone. He looks serious for the first time.)" },
			{ "speaker": "murphy", "text": "Everything in that Iron Belt facility — Tumbler is building a museum. A real one. He wants to document humanity's entire expansion before the records are lost." },
			{ "speaker": "murphy", "text": "He doesn't talk about his eyesight but I've known for years. He's running out of time. He's trying to leave something behind." },
			{ "speaker": "murphy", "text": "I've been finding the neural compound on every job for three years. I didn't tell him because he'd have told me to stop. He would never ask for help." },
			{ "speaker": "murphy", "text": "Some people are like that. You just help them anyway." },
		],
		"debrief": [
			{ "speaker": "murphy", "text": "The compound is stored. Enough for the procedure. Dr. Voss confirmed it." },
			{ "speaker": "captain", "text": "(Murphy stares at the storage case with an expression you can't quite read.)" },
			{ "speaker": "murphy", "text": "Three years of side trips, extra stops, 'just checking one more site.' He never asked. He never knew." },
			{ "speaker": "murphy", "text": "When he finds out — and he will, eventually — he's going to be furious. And then he's going to be something else. Something he doesn't have a word for." },
			{ "speaker": "murphy", "text": "Thank you for bringing me here, Captain. Some jobs you do for the pay. This one I did for him." },
		],
		"days":     12,
		"reward":   1100,
		"on_complete_discover": [],
	},

	# ── River — "Diplomatic Channel" ────────────────────────────────────────
	{
		"id":       "river_01_diplomatic_pouch",
		"crew":     "river",
		"title":    "Diplomatic Pouch",
		"location": "proxima",
		"trigger":  { "type": "jobs_completed", "value": 3 },
		"desc":     "Ambassador River needs urgent, unannounced passage to Proxima. GEC credentials mean no searches — but also no weapons.",
		"crew_msg": "\"Captain, I'll be direct. I work with Commander Percy's division — the GEC Corps. He speaks well of you. I need passage to Proxima Centauri and I need it unannounced. My diplomatic status means I can't carry weapons through the transit corridor, and neither can your crew while I'm aboard — it's treaty law, I'm sorry. The contents of the diplomatic pouch cannot be discussed. What I can tell you is that it matters, that Percy knows we're coming, and that I will make sure your cooperation is recognized in the right places.\"",
		"dialogue": [
			{ "speaker": "river", "text": "Captain, I'll be direct. I work with Commander Percy's division — the GEC Corps." },
			{ "speaker": "captain", "text": "(River carries themselves with the careful precision of someone used to choosing every word.)" },
			{ "speaker": "river", "text": "I need passage to Proxima Centauri. Unannounced. My diplomatic status means no weapons through the transit corridor — for your crew as well. Treaty law." },
			{ "speaker": "river", "text": "The contents of the diplomatic pouch cannot be discussed. What I can tell you is that it matters, and Percy knows we're coming." },
		],
		"debrief": [
			{ "speaker": "river", "text": "The pouch is delivered. Thank you, Captain." },
			{ "speaker": "captain", "text": "(River looks relieved for the first time since boarding.)" },
			{ "speaker": "river", "text": "I can tell you this much now: the pouch contained evidence of unauthorized operations in the outer systems. Evidence that needed to reach the right hands." },
			{ "speaker": "river", "text": "Percy's investigation and my work — they're connected. More than either of us realized when we started." },
			{ "speaker": "river", "text": "Your cooperation will be recognized. I keep my promises, Captain." },
		],
		"days":     4,
		"reward":   400,
		"on_complete_discover": [],
	},
	{
		"id":       "river_02_asylum",
		"crew":     "river",
		"title":    "Right of Asylum",
		"location": "barnard",
		"trigger":  { "type": "system_discovered", "value": "barnard" },
		"desc":     "A refugee colony at Barnard's Star is requesting GEC protection. River finds evidence connected to Percy's derelict investigation. [CROSSOVER: Percy]",
		"crew_msg": "\"There's a colony at Barnard's Star — about four hundred people — who have formally requested GEC protection. Corporate security from an unlicensed mining operation is moving on them. I need to get there before they do. I should also tell you — when I filed the Barnard brief, I cross-referenced it with Percy's recent reports. The unmarked derelict he investigated? The colony has seen those ships before. They've been watching them for months. Whatever Percy is untangling, Captain, it's bigger than one ship. And it starts here.\"",
		"dialogue": [
			{ "speaker": "river", "text": "There's a colony at Barnard's Star — four hundred people — requesting GEC protection." },
			{ "speaker": "captain", "text": "(River pulls up the brief. The situation is urgent.)" },
			{ "speaker": "river", "text": "Corporate security from an unlicensed mining operation is moving on them. I need to get there first." },
			{ "speaker": "river", "text": "I should also tell you — when I filed the brief, I cross-referenced it with Percy's reports. The colony has seen those unmarked ships. For months." },
			{ "speaker": "river", "text": "Whatever Percy is untangling, Captain — it's bigger than one ship. And it starts here." },
		],
		"debrief": [
			{ "speaker": "river", "text": "The colony is under GEC protection. Corporate security has withdrawn." },
			{ "speaker": "captain", "text": "(River is reviewing testimony recordings from the colonists.)" },
			{ "speaker": "river", "text": "The colonists confirmed everything. The unmarked ships have been making regular passes through Barnard for months. Always at night. Always running dark." },
			{ "speaker": "percy", "text": "River shared the testimony with me. It matches our flight recorder data exactly. Same routes, same timing." },
			{ "speaker": "river", "text": "Percy and I are pulling the same thread from different ends. Eventually, they'll meet. I'm not sure either of us is ready for what's at the center." },
		],
		"days":     9,
		"reward":   850,
		"on_complete_discover": [],
	},
	{
		"id":       "river_03_the_treaty_table",
		"crew":     "river",
		"title":    "The Treaty Table",
		"location": "cygnus",
		"trigger":  { "type": "system_discovered", "value": "cygnus" },
		"desc":     "River is the appointed GEC mediator between two factions at war inside Cygnus Reach. What they're fighting over connects directly to what Percy found. [CROSSOVER: Percy]",
		"crew_msg": "\"Two factions have been shooting at each other inside Cygnus Reach for seven months. I've been appointed GEC mediator. The ceasefire window is fourteen days. I need to be there. The complication — and there's always a complication — is that what they're fighting over is access to the same region of the nebula where Percy found that derelict. I don't think that's a coincidence. I'm going in there to negotiate a peace, but I may also be walking into the middle of whatever Percy has been chasing. I'm not sure I mind. I'd like to know what it is.\"",
		"dialogue": [
			{ "speaker": "river", "text": "Two factions have been shooting at each other inside Cygnus Reach for seven months. I've been appointed GEC mediator." },
			{ "speaker": "captain", "text": "(River produces a ceasefire timeline. The window is narrow.)" },
			{ "speaker": "river", "text": "The complication is that what they're fighting over is access to the same region where Percy found that derelict." },
			{ "speaker": "river", "text": "I don't think that's a coincidence. I'm going in to negotiate a peace — but I may be walking into the middle of whatever Percy has been chasing." },
			{ "speaker": "river", "text": "I'm not sure I mind. I'd like to know what it is." },
		],
		"debrief": [
			{ "speaker": "river", "text": "Ceasefire signed. Both factions stood down." },
			{ "speaker": "captain", "text": "(River looks exhausted but composed. Fourteen days of negotiation in a war zone.)" },
			{ "speaker": "river", "text": "They weren't fighting over territory, Captain. They were fighting over information. Both factions found evidence of the same thing Percy found — the staging area, the supply caches." },
			{ "speaker": "river", "text": "Each side thought the other was responsible. They were both wrong. Whatever built that infrastructure, it wasn't either faction." },
			{ "speaker": "river", "text": "I'm running out of explanations that don't involve something very large and very hidden operating in our space. And I don't like that." },
		],
		"days":     16,
		"reward":   2200,
		"on_complete_discover": [],
	},
	{
		"id":       "river_04_gambits_end",
		"crew":     "river",
		"title":    "River's Gambit",
		"location": "frontier",
		"trigger":  { "type": "system_discovered", "value": "frontier" },
		"desc":     "River reveals the unmarked ships were GEC shadow operations. Percy was never meant to find them. River must choose: the cover-up or the truth. [CROSSOVER: Percy, Mika]",
		"crew_msg": "\"Captain. I owe you honesty and I'm going to give it to you even though it may cost me my commission. The unmarked ships Percy has been tracking — they were ours. GEC shadow operations. Unsanctioned. I was sent to manage the diplomatic fallout if they were ever found. I was not told Percy would be the one to find them. He wasn't supposed to be out that far. I've spent six months deciding what to do about this and I've made my choice: I'm going to Frontier Station to file a full disclosure report. I'll need your ship to get there. And Captain — don't tell Percy until we're in transit. Let me tell him myself.\"",
		"dialogue": [
			{ "speaker": "river", "text": "Captain. I owe you honesty. Even though it may cost me my commission." },
			{ "speaker": "captain", "text": "(River closes the door and lowers their voice.)" },
			{ "speaker": "river", "text": "The unmarked ships Percy has been tracking — they were ours. GEC shadow operations. Unsanctioned." },
			{ "speaker": "river", "text": "I was sent to manage the diplomatic fallout if they were ever found. Percy wasn't supposed to be out that far." },
			{ "speaker": "river", "text": "I've spent six months deciding what to do. I've made my choice: full disclosure. Frontier Station. I'll need your ship." },
			{ "speaker": "river", "text": "And Captain — don't tell Percy until we're in transit. Let me tell him myself." },
		],
		"debrief": [
			{ "speaker": "river", "text": "The report is filed. Full disclosure. Everything." },
			{ "speaker": "captain", "text": "(River sits across from Percy. The silence between them is heavy.)" },
			{ "speaker": "percy", "text": "You knew. This whole time. You knew what those ships were." },
			{ "speaker": "river", "text": "I knew what they were supposed to be. I didn't know what they'd become. None of us did." },
			{ "speaker": "percy", "text": "..." },
			{ "speaker": "river", "text": "I chose the truth, Percy. That has to count for something." },
			{ "speaker": "mika", "text": "Give it time. Both of you. Trust breaks fast and heals slow. But it does heal." },
		],
		"days":     20,
		"reward":   3500,
		"on_complete_discover": [],
	},

	# ── Fluffy — "No Questions Asked" ───────────────────────────────────────
	{
		"id":       "fluffy_01_proposition",
		"crew":     "fluffy",
		"title":    "A Business Proposition",
		"location": "alpha_cen",
		"trigger":  { "type": "jobs_completed", "value": 2 },
		"desc":     "Fluffy appears at Alpha Centauri with a short, well-paying escort job. The client is unusual. The cargo is stranger.",
		"crew_msg": "\"I heard you run a tight ship. I have a job — one stop, no detours, good pay, no questions asked. I know everyone says that last part and then asks a lot of questions, so let me be clear: I mean it literally. You don't ask, I don't explain, we both get paid, we go our separate ways. I'm not crew. I'm not a friend. I'm a professional. If that works for you, we leave at 0600. If not, I'll find another captain. I'd prefer not to — yours came recommended — but I'll manage.\"",
		"dialogue": [
			{ "speaker": "fluffy", "text": "I heard you run a tight ship. I have a job." },
			{ "speaker": "captain", "text": "(Fluffy's expression gives away nothing. Professional doesn't begin to cover it.)" },
			{ "speaker": "fluffy", "text": "One stop, no detours, good pay, no questions asked. I mean that last part literally." },
			{ "speaker": "fluffy", "text": "I'm not crew. I'm not a friend. I'm a professional. If that works for you, we leave at 0600." },
			{ "speaker": "fluffy", "text": "If not, I'll find another captain. I'd prefer not to — yours came recommended — but I'll manage." },
		],
		"debrief": [
			{ "speaker": "fluffy", "text": "Job's done. Clean. As promised." },
			{ "speaker": "captain", "text": "(Fluffy is already packing their kit.)" },
			{ "speaker": "fluffy", "text": "Payment is in your account. I don't do handshakes or thank-yous. The work speaks for itself." },
			{ "speaker": "fluffy", "text": "Your crew is... interesting. The loud one tried to buy me a drink. The big one kept asking if I needed anything. The counselor just watched me. Quietly." },
			{ "speaker": "fluffy", "text": "If another job comes up, I know where to find you. Don't read anything into that." },
		],
		"days":     3,
		"reward":   350,
		"on_complete_discover": [],
	},
	{
		"id":       "fluffy_02_extraction",
		"crew":     "fluffy",
		"title":    "Extraction",
		"location": "rigel_out",
		"trigger":  { "type": "system_discovered", "value": "rigel_out" },
		"desc":     "Fluffy is stuck at Rigel Outpost after a job went wrong. Shadow heard their signal before they sent one. [CROSSOVER: Shadow]",
		"crew_msg": "\"...I need a pickup. Rigel Outpost. Job went sideways — not my fault, client gave bad intel, not the first time. My ship is impounded pending an 'investigation' that will conveniently take six to eight weeks. I'm not asking for help. I'm asking for a commercial transport arrangement. Standard rate. Your crewman — Shadow, I think — apparently picked up my distress beacon before I activated it, which is either impressive or unsettling, I haven't decided. Tell him I said thanks. Don't make it weird.\"",
		"dialogue": [
			{ "speaker": "fluffy", "text": "...I need a pickup. Rigel Outpost." },
			{ "speaker": "captain", "text": "(Fluffy's voice is clipped. They hate asking for anything.)" },
			{ "speaker": "fluffy", "text": "Job went sideways — not my fault. My ship is impounded. I'm asking for a commercial transport arrangement. Standard rate." },
			{ "speaker": "shadow", "text": "I heard their beacon before they activated it, sir! Sub-harmonic frequencies again!" },
			{ "speaker": "fluffy", "text": "Tell Shadow I said thanks. Don't make it weird." },
		],
		"debrief": [
			{ "speaker": "fluffy", "text": "I'm off Rigel. Thank you. Standard rate applies." },
			{ "speaker": "captain", "text": "(Fluffy is sitting in the corner of the galley, very deliberately not making eye contact with Shadow, who is beaming at them.)" },
			{ "speaker": "fluffy", "text": "The client who gave me bad intel has been... informed of my displeasure. Professionally." },
			{ "speaker": "shadow", "text": "Are you OK? Do you need anything? Water? A blanket?" },
			{ "speaker": "fluffy", "text": "I need Shadow to stop looking at me like that. But... the water would be fine. Thank you." },
		],
		"days":     6,
		"reward":   480,
		"on_complete_discover": [],
	},
	{
		"id":       "fluffy_03_the_client",
		"crew":     "fluffy",
		"title":    "The Client",
		"location": "scylla",
		"trigger":  { "type": "system_discovered", "value": "scylla" },
		"desc":     "Fluffy reveals their Cygnus client was Tumbler — investigating the same network Percy is chasing, from the trade side. Nobody planned for these threads to cross. [CROSSOVER: Tumbler, Percy]",
		"crew_msg": "\"I'm going to tell you something I don't normally tell clients. The job in Cygnus — the one that started all of this — I was hired by a merchant named Tumbler. Merchant Guild. He wanted eyes on some shipping irregularities that the Guild couldn't officially investigate. I didn't know what I was walking into. I didn't know your commander was already pulling at the same thread from the other end. I've been running jobs inside a situation I didn't understand and I don't like that. I like to know what I'm in. So — what are we in, Captain? Because I think you know.\"",
		"dialogue": [
			{ "speaker": "fluffy", "text": "I'm going to tell you something I don't normally tell clients." },
			{ "speaker": "captain", "text": "(Fluffy sits down. That's new — they usually stand near the exit.)" },
			{ "speaker": "fluffy", "text": "The Cygnus job — I was hired by a merchant named Tumbler. Merchant Guild. He wanted eyes on shipping irregularities." },
			{ "speaker": "fluffy", "text": "I didn't know your commander was already pulling at the same thread from the other end." },
			{ "speaker": "fluffy", "text": "I've been running jobs inside a situation I didn't understand. I don't like that. So — what are we in, Captain?" },
		],
		"debrief": [
			{ "speaker": "fluffy", "text": "Now I know. I wish I didn't, but I know." },
			{ "speaker": "captain", "text": "(Fluffy is processing. Their usual detachment has cracks in it.)" },
			{ "speaker": "fluffy", "text": "Tumbler's shipping irregularities, Percy's unmarked ships, the staging area in Cygnus — it's all the same operation. Different angles, same picture." },
			{ "speaker": "fluffy", "text": "I've spent my career staying out of other people's problems. Strictly professional. No attachments. No sides." },
			{ "speaker": "fluffy", "text": "That's getting harder. I thought you should know that too." },
		],
		"days":     15,
		"reward":   2000,
		"on_complete_discover": [],
	},
	{
		"id":       "fluffy_04_picking_a_side",
		"crew":     "fluffy",
		"title":    "Picking a Side",
		"location": "the_rim",
		"trigger":  { "type": "jobs_completed", "value": 14 },
		"desc":     "At The Rim, Fluffy has been offered final payment to deliver something to a third party. After everything, they're not sure they can take it. [CROSSOVER: Percy, River, Mika]",
		"crew_msg": "\"I have an offer on the table. Final payment, clean exit, my impounder ship released. All I have to do is deliver one data package to a contact at the Rim before your commander gets there. I've taken harder jobs for less. The thing is — I've been on your ship for a while now. I've watched how you run things. Shadow trusts everyone and somehow isn't dead. Zester breaks everything and it mostly gets fixed. That counselor of yours looked at me last week like she already knew what I was going to say before I said it. I don't have loyalty to anyone. That's always been the deal. I'm at the Rim. I have a choice to make. I wanted you to know before I made it.\"",
		"dialogue": [
			{ "speaker": "fluffy", "text": "I have an offer on the table. Final payment, clean exit, my ship released." },
			{ "speaker": "captain", "text": "(Fluffy is standing by the airlock. Packed bag at their feet.)" },
			{ "speaker": "fluffy", "text": "All I have to do is deliver one data package to a contact at the Rim before your commander gets there." },
			{ "speaker": "fluffy", "text": "I've taken harder jobs for less. The thing is — I've been on your ship for a while now. I've watched how you run things." },
			{ "speaker": "fluffy", "text": "Shadow trusts everyone and somehow isn't dead. Zester breaks everything and it mostly gets fixed. Mika looked at me last week like she already knew what I was going to say." },
			{ "speaker": "fluffy", "text": "I don't have loyalty to anyone. That's always been the deal. I have a choice to make. I wanted you to know before I made it." },
		],
		"debrief": [
			{ "speaker": "fluffy", "text": "I turned it down." },
			{ "speaker": "captain", "text": "(Fluffy's bag is unpacked. They're still here.)" },
			{ "speaker": "fluffy", "text": "The data package — it would have compromised everything Percy and River have been building. Everything this crew has risked." },
			{ "speaker": "fluffy", "text": "A year ago I would have taken the money without thinking. A month ago I would have taken it and felt bad about it." },
			{ "speaker": "fluffy", "text": "Today I didn't take it. I'm not sure what that makes me. I've never been part of a crew before." },
			{ "speaker": "shadow", "text": "It makes you one of us." },
			{ "speaker": "fluffy", "text": "...Don't make it weird, Shadow." },
		],
		"days":     22,
		"reward":   3800,
		"on_complete_discover": [],
	},
]


func find_crew_mission(id: String) -> Dictionary:
	for m in CREW_MISSIONS:
		if m.id == id:
			return m
	return {}
