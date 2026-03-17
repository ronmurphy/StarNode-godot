## room_data.gd — Autoloaded as "RoomData"
## Static database of all room definitions.
extends Node

const ROOMS: Array = [
	# ── Star Trek ──────────────────────────────────────────────────────────
	{ "id":"trek_warpcore",    "name":"Warp Core",           "universe":"Star Trek",  "type":"Power",    "cost":800,  "power":500,  "durability":100, "desc":"Primary antimatter reactor. Heart of Federation vessels." },
	{ "id":"trek_impulse",     "name":"Impulse Engine",      "universe":"Star Trek",  "type":"Engines",  "cost":400,  "power":-200, "durability":90,  "desc":"Sub-light drive system." },
	{ "id":"trek_bridge",      "name":"Federation Bridge",   "universe":"Star Trek",  "type":"Command",  "cost":600,  "power":-30,  "durability":80,  "desc":"Command and control center." },
	{ "id":"trek_phaser",      "name":"Phaser Bank",         "universe":"Star Trek",  "type":"Tactical", "cost":500,  "power":-150, "durability":75,  "desc":"Directed energy weapon array." },
	{ "id":"trek_shields",     "name":"Shield Generator",    "universe":"Star Trek",  "type":"Tactical", "cost":550,  "power":-180, "durability":85,  "desc":"Deflector shield emitter array." },
	{ "id":"trek_deflector",   "name":"Deflector Array",     "universe":"Star Trek",  "type":"Utility",  "cost":300,  "power":-50,  "durability":70,  "desc":"Navigation deflector dish." },
	{ "id":"trek_cartography", "name":"Stellar Cartography", "universe":"Star Trek",  "type":"Utility",  "cost":200,  "power":-20,  "durability":60,  "desc":"Advanced stellar mapping lab." },
	{ "id":"trek_maintenance", "name":"Maintenance Bay",     "universe":"Star Trek",  "type":"Utility",  "cost":150,  "power":-30,  "durability":65,  "desc":"Systems repair and maintenance." },
	{ "id":"trek_transporter", "name":"Transporter Room",    "universe":"Star Trek",  "type":"Utility",  "cost":350,  "power":-60,  "durability":70,  "desc":"Molecular transporter array." },
	{ "id":"trek_sickbay",     "name":"Sickbay",             "universe":"Star Trek",  "type":"Utility",  "cost":250,  "power":-25,  "durability":65,  "desc":"Medical and trauma center." },
	{ "id":"trek_torpedo",     "name":"Torpedo Bay",         "universe":"Star Trek",  "type":"Tactical", "cost":450,  "power":-100, "durability":80,  "desc":"Photon torpedo launcher." },
	# ── Star Wars ──────────────────────────────────────────────────────────
	{ "id":"sw_hypermatter",   "name":"Hypermatter Reactor", "universe":"Star Wars",  "type":"Power",    "cost":900,  "power":600,  "durability":100, "desc":"Imperial-grade hypermatter annihilator." },
	{ "id":"sw_kyber",         "name":"Kyber Crystal Matrix","universe":"Star Wars",  "type":"Power",    "cost":1500, "power":1000, "durability":95,  "desc":"Ancient Jedi power crystal array. Immense output." },
	{ "id":"sw_ionengine",     "name":"Ion Engine",          "universe":"Star Wars",  "type":"Engines",  "cost":350,  "power":-150, "durability":85,  "desc":"Standard ion drive propulsion." },
	{ "id":"sw_bridge",        "name":"Imperial Bridge",     "universe":"Star Wars",  "type":"Command",  "cost":600,  "power":-30,  "durability":75,  "desc":"Standard Imperial command bridge." },
	{ "id":"sw_turbolaser",    "name":"Turbolaser Battery",  "universe":"Star Wars",  "type":"Tactical", "cost":650,  "power":-200, "durability":80,  "desc":"Heavy turbolaser cannon array." },
	{ "id":"sw_tractor",       "name":"Tractor Beam",        "universe":"Star Wars",  "type":"Tactical", "cost":400,  "power":-100, "durability":70,  "desc":"Gravitational tractor beam emitter." },
	{ "id":"sw_navicomp",      "name":"Navicomputer",        "universe":"Star Wars",  "type":"Utility",  "cost":200,  "power":-20,  "durability":65,  "desc":"Hyperspace navigation computer." },
	{ "id":"sw_hangar",        "name":"Hangar Bay",          "universe":"Star Wars",  "type":"Utility",  "cost":500,  "power":-80,  "durability":75,  "desc":"TIE/X-Wing hangar and launch bay." },
	{ "id":"sw_shield",        "name":"Ray Shield Generator","universe":"Star Wars",  "type":"Tactical", "cost":550,  "power":-170, "durability":80,  "desc":"Deflector shield array." },
	{ "id":"sw_cargo",         "name":"Cargo Hold",          "universe":"Star Wars",  "type":"Utility",  "cost":150,  "power":-10,  "durability":70,  "desc":"Bulk cargo storage bay." },
	# ── Babylon 5 ──────────────────────────────────────────────────────────
	{ "id":"b5_fusion",        "name":"Fusion Reactor",       "universe":"Babylon 5", "type":"Power",    "cost":750,  "power":400,  "durability":100, "desc":"EarthForce standard fusion power plant." },
	{ "id":"b5_quantium",      "name":"Quantium-40 Generator","universe":"Babylon 5", "type":"Power",    "cost":650,  "power":300,  "durability":90,  "desc":"Minbari-derived quantium power source." },
	{ "id":"b5_gravimetric",   "name":"Gravimetric Engine",   "universe":"Babylon 5", "type":"Engines",  "cost":400,  "power":-120, "durability":85,  "desc":"Gravimetric propulsion system." },
	{ "id":"b5_cic",           "name":"Earthforce CIC",       "universe":"Babylon 5", "type":"Command",  "cost":550,  "power":-40,  "durability":75,  "desc":"Combat information center." },
	{ "id":"b5_jumpgate",      "name":"Jump Gate Array",      "universe":"Babylon 5", "type":"Engines",  "cost":800,  "power":-250, "durability":80,  "desc":"Hyperspace jump point generator." },
	{ "id":"b5_interceptor",   "name":"Interceptor Grid",     "universe":"Babylon 5", "type":"Tactical", "cost":500,  "power":-160, "durability":75,  "desc":"Point defense interceptor array." },
	{ "id":"b5_medlab",        "name":"MedLab",               "universe":"Babylon 5", "type":"Utility",  "cost":250,  "power":-30,  "durability":65,  "desc":"Advanced trauma and medical lab." },
	{ "id":"b5_cargo",         "name":"Cargo Module",         "universe":"Babylon 5", "type":"Utility",  "cost":120,  "power":-10,  "durability":70,  "desc":"Modular cargo storage." },
	# ── Dune ───────────────────────────────────────────────────────────────
	{ "id":"dune_holtzman",    "name":"Holtzman Generator",  "universe":"Dune",       "type":"Power",    "cost":850,  "power":350,  "durability":100, "desc":"Holtzman effect shield and power generator." },
	{ "id":"dune_spice",       "name":"Spice Reactor",       "universe":"Dune",       "type":"Power",    "cost":1200, "power":450,  "durability":90,  "desc":"Spice-fueled power matrix. Highly valuable." },
	{ "id":"dune_suspensor",   "name":"Suspensor Drive",     "universe":"Dune",       "type":"Engines",  "cost":500,  "power":-130, "durability":85,  "desc":"Holtzman suspensor propulsion." },
	{ "id":"dune_navchamber",  "name":"Navigation Chamber",  "universe":"Dune",       "type":"Command",  "cost":700,  "power":-25,  "durability":80,  "desc":"Guild navigator prescience chamber." },
	{ "id":"dune_lasgun",      "name":"Lasgun Array",        "universe":"Dune",       "type":"Tactical", "cost":600,  "power":-140, "durability":75,  "desc":"Coherent light weapon battery." },
	{ "id":"dune_shield",      "name":"Holtzman Shield",     "universe":"Dune",       "type":"Tactical", "cost":500,  "power":-120, "durability":80,  "desc":"Personal and ship-scale shield matrix." },
	{ "id":"dune_stillsuit",   "name":"Life Support Bay",    "universe":"Dune",       "type":"Utility",  "cost":200,  "power":-20,  "durability":65,  "desc":"Fremen-inspired life support systems." },
	{ "id":"dune_cargo",       "name":"Spice Storage",       "universe":"Dune",       "type":"Utility",  "cost":300,  "power":-15,  "durability":70,  "desc":"Pressurized melange storage vault." },
	# ── Battlestar Galactica ───────────────────────────────────────────────
	{ "id":"bsg_tylium",       "name":"Tylium Reactor",      "universe":"BSG",        "type":"Power",    "cost":700,  "power":420,  "durability":100, "desc":"Refined tylium nuclear fission reactor. Colonial standard." },
	{ "id":"bsg_ftl",          "name":"FTL Drive",           "universe":"BSG",        "type":"Engines",  "cost":900,  "power":-280, "durability":85,  "desc":"Faster-than-light jump drive. Colonial and Cylon design." },
	{ "id":"bsg_sublight",     "name":"Sublight Engines",    "universe":"BSG",        "type":"Engines",  "cost":380,  "power":-140, "durability":90,  "desc":"Primary sub-light ion propulsion array." },
	{ "id":"bsg_cic",          "name":"Combat Info Center",  "universe":"BSG",        "type":"Command",  "cost":600,  "power":-45,  "durability":80,  "desc":"Command hub for fleet and combat coordination." },
	{ "id":"bsg_flak",         "name":"Flak Battery",        "universe":"BSG",        "type":"Tactical", "cost":480,  "power":-130, "durability":75,  "desc":"Point-defense flak cannon array." },
	{ "id":"bsg_kew",          "name":"Kinetic Weapons",     "universe":"BSG",        "type":"Tactical", "cost":550,  "power":-160, "durability":78,  "desc":"Heavy kinetic energy weapon batteries." },
	{ "id":"bsg_hangar",       "name":"Viper Bay",           "universe":"BSG",        "type":"Utility",  "cost":600,  "power":-70,  "durability":75,  "desc":"Viper and Raptor launch and recovery bay." },
	{ "id":"bsg_sickbay",      "name":"Sickbay",             "universe":"BSG",        "type":"Utility",  "cost":220,  "power":-25,  "durability":65,  "desc":"Colonial military medical facility." },
	{ "id":"bsg_dc",           "name":"Damage Control",      "universe":"BSG",        "type":"Utility",  "cost":180,  "power":-15,  "durability":70,  "desc":"Rapid damage control and repair station." },
	# ── The Expanse ────────────────────────────────────────────────────────
	{ "id":"exp_epstein",      "name":"Epstein Drive",       "universe":"The Expanse","type":"Engines",  "cost":1100, "power":-300, "durability":90,  "desc":"High-efficiency fusion torch. Transformed the solar system." },
	{ "id":"exp_fusion",       "name":"Fusion Reactor",      "universe":"The Expanse","type":"Power",    "cost":800,  "power":500,  "durability":100, "desc":"Compact deuterium fusion power plant." },
	{ "id":"exp_rcs",          "name":"RCS Thrusters",       "universe":"The Expanse","type":"Engines",  "cost":300,  "power":-80,  "durability":85,  "desc":"Reaction control system for maneuvering." },
	{ "id":"exp_cic",          "name":"Command & Control",   "universe":"The Expanse","type":"Command",  "cost":580,  "power":-40,  "durability":78,  "desc":"MCRN or OPA command information center." },
	{ "id":"exp_pdc",          "name":"PDC Battery",         "universe":"The Expanse","type":"Tactical", "cost":500,  "power":-140, "durability":75,  "desc":"Point defense cannon array for close-in threats." },
	{ "id":"exp_torpedo",      "name":"Torpedo Launcher",    "universe":"The Expanse","type":"Tactical", "cost":620,  "power":-100, "durability":72,  "desc":"Keel-mounted torpedo launch system." },
	{ "id":"exp_railgun",      "name":"Rail Gun",            "universe":"The Expanse","type":"Tactical", "cost":850,  "power":-250, "durability":70,  "desc":"Electromagnetic mass driver. Devastating range." },
	{ "id":"exp_medbay",       "name":"Med Bay",             "universe":"The Expanse","type":"Utility",  "cost":230,  "power":-25,  "durability":65,  "desc":"Trauma care and autodoc station." },
	{ "id":"exp_cargo",        "name":"Cargo Bay",           "universe":"The Expanse","type":"Utility",  "cost":160,  "power":-10,  "durability":70,  "desc":"Standard pressurized cargo bay." },
	# ── Mass Effect ────────────────────────────────────────────────────────
	{ "id":"me_eezo",          "name":"Element Zero Core",   "universe":"Mass Effect", "type":"Power",    "cost":950,  "power":550,  "durability":95,  "desc":"Mass effect field generator. Enables FTL travel." },
	{ "id":"me_drive",         "name":"Drive Core",          "universe":"Mass Effect", "type":"Engines",  "cost":700,  "power":-200, "durability":88,  "desc":"Tantalus drive core for FTL and sublight propulsion." },
	{ "id":"me_thruster",      "name":"Maneuvering Thrusters","universe":"Mass Effect","type":"Engines",  "cost":280,  "power":-90,  "durability":80,  "desc":"RCS thruster suite for evasive maneuvers." },
	{ "id":"me_cic",           "name":"Combat Information Ctr","universe":"Mass Effect","type":"Command", "cost":620,  "power":-40,  "durability":78,  "desc":"Alliance or Cerberus command nerve center." },
	{ "id":"me_thanix",        "name":"Thanix Cannon",       "universe":"Mass Effect", "type":"Tactical", "cost":950,  "power":-260, "durability":72,  "desc":"Reaper-derived mass accelerator cannon." },
	{ "id":"me_gardian",       "name":"GARDIAN System",      "universe":"Mass Effect", "type":"Tactical", "cost":480,  "power":-130, "durability":76,  "desc":"Point defense laser grid against fighters and missiles." },
	{ "id":"me_kinetic",       "name":"Kinetic Barriers",    "universe":"Mass Effect", "type":"Tactical", "cost":560,  "power":-160, "durability":82,  "desc":"Mass effect field kinetic barrier array." },
	{ "id":"me_medbay",        "name":"Medical Bay",         "universe":"Mass Effect", "type":"Utility",  "cost":240,  "power":-25,  "durability":65,  "desc":"Alliance-spec trauma center and medi-gel dispensary." },
	{ "id":"me_lab",           "name":"Research Lab",        "universe":"Mass Effect", "type":"Utility",  "cost":320,  "power":-35,  "durability":60,  "desc":"Weapons and tech upgrade research facility." },
	{ "id":"me_cargo",         "name":"Cargo Hold",          "universe":"Mass Effect", "type":"Utility",  "cost":140,  "power":-10,  "durability":70,  "desc":"Pressurized cargo and equipment storage." },
	# ── Star Mercenaries ───────────────────────────────────────────────────
	{ "id":"merc_salvage_reactor",  "name":"Salvage Reactor",      "universe":"Mercs", "type":"Power",    "cost":350,  "power":220,  "durability":75,  "desc":"Frankensteined power plant bolted from scrapyard parts. Ugly but reliable." },
	{ "id":"merc_scrapyard_gen",    "name":"Scrapyard Generator",  "universe":"Mercs", "type":"Power",    "cost":900,  "power":520,  "durability":85,  "desc":"Massive jury-rigged generator. Three different reactor types welded into one." },
	{ "id":"merc_hotrod_drive",     "name":"Hotrod Drive",         "universe":"Mercs", "type":"Engines",  "cost":600,  "power":-180, "durability":80,  "desc":"Oversized thruster bolted to an undersized frame. Fast and terrifying." },
	{ "id":"merc_afterburner",      "name":"Afterburner Array",    "universe":"Mercs", "type":"Engines",  "cost":1100, "power":-320, "durability":70,  "desc":"Military-grade afterburners stripped from a decommissioned frigate." },
	{ "id":"merc_smuggler_cockpit", "name":"Smuggler's Cockpit",   "universe":"Mercs", "type":"Command",  "cost":400,  "power":-25,  "durability":70,  "desc":"Cramped asymmetric cockpit with a bubble canopy and too many screens." },
	{ "id":"merc_command_deck",     "name":"Merc Command Deck",    "universe":"Mercs", "type":"Command",  "cost":750,  "power":-40,  "durability":78,  "desc":"Battle-scarred command center with mismatched consoles from three different ships." },
	{ "id":"merc_jury_turret",      "name":"Jury-Rigged Turret",   "universe":"Mercs", "type":"Tactical", "cost":300,  "power":-90,  "durability":60,  "desc":"Improvised weapon mount. Bolted on crooked but hits hard enough." },
	{ "id":"merc_railgun_salvage",  "name":"Railgun Salvage Mount","universe":"Mercs", "type":"Tactical", "cost":800,  "power":-220, "durability":68,  "desc":"Salvaged military railgun. Half the housing is missing but the barrel still works." },
	{ "id":"merc_bounty_suite",     "name":"Bounty Hunter Suite",  "universe":"Mercs", "type":"Utility",  "cost":280,  "power":-20,  "durability":72,  "desc":"Holding cells, weapon lockers, and a reinforced interrogation room." },
	{ "id":"merc_hidden_cargo",     "name":"Hidden Cargo Bay",     "universe":"Mercs", "type":"Utility",  "cost":200,  "power":-10,  "durability":65,  "desc":"Shielded smuggling compartment. Invisible to standard cargo scans." },
	# ── Universal ──────────────────────────────────────────────────────────
	{ "id":"uni_junction",     "name":"Junction Node",       "universe":"Universal",  "type":"Utility",  "cost":50,   "power":0,    "durability":100, "desc":"Power/data routing junction." },
	{ "id":"uni_conduit",      "name":"Power Conduit",       "universe":"Universal",  "type":"Power",    "cost":80,   "power":0,    "durability":100, "desc":"Power distribution conduit." },
	{ "id":"uni_hull_primary", "name":"Primary Hull",        "universe":"Universal",  "type":"Utility",  "cost":200,  "power":-5,   "durability":120, "desc":"Reinforced primary hull section." },
	{ "id":"uni_hull_sec",     "name":"Secondary Hull",      "universe":"Universal",  "type":"Utility",  "cost":100,  "power":-3,   "durability":90,  "desc":"Secondary hull section." },
	{ "id":"uni_airlock",      "name":"Airlock",             "universe":"Universal",  "type":"Utility",  "cost":80,   "power":-5,   "durability":75,  "desc":"Standard pressurized airlock." },
	{ "id":"uni_crew",         "name":"Crew Quarters",       "universe":"Universal",  "type":"Utility",  "cost":120,  "power":-15,  "durability":70,  "desc":"Standard crew living quarters." },
]

const UNIVERSES: Array = ["All", "Star Trek", "Star Wars", "Babylon 5", "Dune", "BSG", "The Expanse", "Mass Effect", "Mercs", "Universal"]

const TYPES: Array = ["All Types", "Power", "Engines", "Command", "Tactical", "Utility"]

const FACTION_CREDITS: Dictionary = {
	"Independent": 2000,
	"Federation":  5000,
	"Empire":      6000,
	"Harkonnen":   8000,
}

const TYPE_COLORS: Dictionary = {
	"Power":    Color(0.20, 0.45, 0.85, 1.0),
	"Engines":  Color(0.20, 0.65, 0.30, 1.0),
	"Command":  Color(0.75, 0.45, 0.10, 1.0),
	"Tactical": Color(0.75, 0.18, 0.18, 1.0),
	"Utility":  Color(0.30, 0.30, 0.55, 1.0),
}


func find(id: String) -> Dictionary:
	for room in ROOMS:
		if room.id == id:
			return room
	return {}


func filter(universe: String, room_type: String, search: String) -> Array:
	var result: Array = []
	var s := search.to_lower()
	for room in ROOMS:
		if universe != "All" and room.universe != universe:
			continue
		if room_type != "All Types" and room.type != room_type:
			continue
		if s != "" and not room.name.to_lower().contains(s):
			continue
		result.append(room)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.name < b.name)
	return result


func power_label(power: int) -> String:
	if power > 0:
		return "+%d PWR" % power
	elif power < 0:
		return "%d PWR" % power
	return "No PWR"


func type_color(type_name: String) -> Color:
	return TYPE_COLORS.get(type_name, Color(0.4, 0.4, 0.4, 1.0))
