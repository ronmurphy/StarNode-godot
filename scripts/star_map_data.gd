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
