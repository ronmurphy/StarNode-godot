## crew_data.gd — Static crew data: name generation, roles, portraits, crew factory.
## Autoload registered as "CrewData".
extends Node


# ── Portraits ────────────────────────────────────────────────────────────────
const PORTRAITS: Array[String] = [
	"res://assets/pictures/profiles/human_male.png",
	"res://assets/pictures/profiles/human_female.png",
	"res://assets/pictures/profiles/alien_crystal.png",
	"res://assets/pictures/profiles/alien_deepspace.png",
	"res://assets/pictures/profiles/alien_fungal.png",
	"res://assets/pictures/profiles/alien_gaseous.png",
	"res://assets/pictures/profiles/alien_insectoid.png",
	"res://assets/pictures/profiles/alien_luminar.png",
	"res://assets/pictures/profiles/alien_reptilian.png",
	"res://assets/pictures/profiles/alien_stone.png",
	"res://assets/pictures/profiles/space_cat.png",
	"res://assets/pictures/profiles/space_dog_golden.png",
	"res://assets/pictures/profiles/space_dog_terrier.png",
]

# ── Names ────────────────────────────────────────────────────────────────────
const FIRST_NAMES: Array[String] = [
	"Kira", "Marcus", "Zara", "Jace", "Lyra", "Dax", "Senna", "Rook",
	"Thane", "Nova", "Cassius", "Vex", "Mira", "Orion", "Petra", "Ash",
	"Talen", "Yara", "Cade", "Nyx", "Renn", "Zephyr", "Kael", "Indra",
	"Sol", "Vash", "Echo", "Rhea", "Talon", "Juno", "Hex", "Sable",
	"Quinn", "Drex", "Lumen", "Kova", "Brynn", "Xander", "Elara", "Rune",
]

const LAST_NAMES: Array[String] = [
	"Vasquez", "Chen", "Okafor", "Stark", "Volkov", "Tanaka", "Reeves",
	"Khoury", "Strand", "Cortez", "Novak", "Thorne", "Kai", "Asari",
	"Voss", "Draven", "Sato", "Malik", "Cruz", "Fenris", "Lokir",
	"Vael", "Qyn", "Torr", "Nexis", "Drell", "Xaris", "Rynn", "Jorik",
	"Kellan",
]

# ── Roles ────────────────────────────────────────────────────────────────────
# Role name → room type it matches
const ROLES: Dictionary = {
	"Engineer":   "Engines",
	"Officer":    "Command",
	"Security":   "Tactical",
	"Technician": "Power",
	"Specialist": "Utility",
}

const ROLE_LIST: Array[String] = ["Engineer", "Officer", "Security", "Technician", "Specialist"]

# ── Economy ──────────────────────────────────────────────────────────────────
const WAGE_PER_DAY: int = 8
const HIRE_COST_BASE: int = 80        # scaled by efficiency
const SHORE_LEAVE_COST_PER_DAY: int = 15

# ── Veteran thresholds ────────────────────────────────────────────────────────
# {min_trips: efficiency_bonus} — cumulative (each tier adds its bonus once)
const VETERAN_TIERS: Array[Dictionary] = [
	{"trips": 3,  "bonus": 0.03, "rank": "Seasoned"},
	{"trips": 7,  "bonus": 0.04, "rank": "Veteran"},
	{"trips": 12, "bonus": 0.05, "rank": "Elite"},
	{"trips": 20, "bonus": 0.05, "rank": "Legendary"},
]


# ── Name generation ──────────────────────────────────────────────────────────

static func generate_name() -> String:
	var first := FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last  := LAST_NAMES[randi() % LAST_NAMES.size()]
	return "%s %s" % [first, last]


# ── Crew factory ─────────────────────────────────────────────────────────────

static func generate_crew(role_hint: String = "", id_num: int = -1) -> Dictionary:
	## Create a random crew member.  role_hint can be a role name ("Engineer")
	## or a room type ("Engines") — either works.  If empty, picks random role.
	var role: String
	if role_hint.is_empty():
		role = ROLE_LIST[randi() % ROLE_LIST.size()]
	elif ROLES.has(role_hint):
		role = role_hint
	else:
		# Might be a room type — reverse lookup
		role = role_for_room_type(role_hint)

	# Efficiency: weighted toward 0.5–0.7 (bell-ish curve via averaging two rolls)
	var eff := clampf((randf_range(0.35, 1.0) + randf_range(0.35, 1.0)) * 0.5, 0.40, 1.0)
	eff = snappedf(eff, 0.01)

	return {
		"id":               "crew_%d" % id_num if id_num >= 0 else "crew_tmp",
		"name":             generate_name(),
		"portrait":         PORTRAITS[randi() % PORTRAITS.size()],
		"role":             role,
		"efficiency":       eff,
		"assigned_to":      "",        # node_uid or ""
		"status":           "active",  # "active", "shore_leave", "arrested"
		"shore_leave_days": 0,
		"trips":            0,         # completed voyages — drives veteran bonuses
	}


static func generate_pool(count: int, start_id: int = 0) -> Array:
	## Generate a pool of random crew for port recruitment.
	var pool: Array = []
	for i in count:
		pool.append(generate_crew("", start_id + i))
	return pool


static func hire_cost(crew: Dictionary) -> int:
	## Cost to hire a crew member (scales with efficiency).
	return int(HIRE_COST_BASE * (0.6 + crew.efficiency * 0.8))


# ── Lookups ──────────────────────────────────────────────────────────────────

static func role_for_room_type(room_type: String) -> String:
	## "Engines" → "Engineer", etc.
	for role_name in ROLES:
		if ROLES[role_name] == room_type:
			return role_name
	return "Specialist"   # fallback


static func room_type_for_role(role: String) -> String:
	## "Engineer" → "Engines", etc.
	return ROLES.get(role, "Utility")


static func wage_for_trip(crew_count: int, days: int) -> int:
	return crew_count * WAGE_PER_DAY * days


# ── Veteran system ────────────────────────────────────────────────────────────

static func veteran_rank(trips: int) -> String:
	## Return the highest veteran rank achieved, or "" for rookies.
	var rank := ""
	for tier in VETERAN_TIERS:
		if trips >= tier.trips:
			rank = tier.rank
	return rank


static func apply_trip_completion(crew: Array) -> Array:
	## Call after a voyage completes.  Increments trips for all active crew,
	## and applies any newly-earned veteran efficiency bonuses.
	## Returns an Array of Strings describing promotions (for logging).
	var promotions: Array = []
	for cm in crew:
		if cm.get("status", "active") != "active":
			continue
		var old_trips: int = cm.get("trips", 0)
		cm.trips = old_trips + 1
		# Check if we crossed a tier threshold
		for tier in VETERAN_TIERS:
			if old_trips < tier.trips and cm.trips >= tier.trips:
				cm.efficiency = minf(cm.efficiency + tier.bonus, 1.0)
				cm.efficiency = snappedf(cm.efficiency, 0.01)
				promotions.append("%s is now %s! (efficiency +%d%%)" % [
					cm.name, tier.rank, int(tier.bonus * 100)])
	return promotions
