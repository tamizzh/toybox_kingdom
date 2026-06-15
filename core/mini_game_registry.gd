class_name MiniGameRegistry
extends RefCounted

# THE EXTENSION POINT. Add a new mini-game by appending one dictionary here.
# Each entry: { script, title, category, duration }.

# "tagline" drives the HUD subtitle banner. "launch": true marks a game as part of
# the curated launch roster (the game grid shows only these; the rest ship later as
# free content updates). See launch_indices().
const GAMES: Array = [
	# --- Racing / Speed ---
	{"script": "res://minigames/racing/sprint_race.gd", "title": "Sprint Race", "category": "Racing", "duration": 20.0, "tagline": "Hold to run — first to the line!", "launch": true},
	{"script": "res://minigames/racing/lane_switch.gd", "title": "Lane Switch", "category": "Racing", "duration": 30.0, "tagline": "Dodge into the open lanes!"},
	{"script": "res://minigames/racing/obstacle_dash.gd", "title": "Obstacle Dash", "category": "Racing", "duration": 30.0, "tagline": "Weave through the chaos!", "launch": true},
	{"script": "res://minigames/racing/ice_slide.gd", "title": "Ice Slide Race", "category": "Racing", "duration": 25.0, "tagline": "Slip, slide and survive!"},
	{"script": "res://minigames/racing/hill_climb.gd", "title": "Hill Climb", "category": "Racing", "duration": 25.0, "tagline": "Climb higher than the rest!"},
	# --- Arena Combat ---
	{"script": "res://minigames/combat/tank_battle.gd", "title": "Tank Battle", "category": "Combat", "duration": 40.0, "tagline": "Last tank rolling wins!", "launch": true},
	{"script": "res://minigames/combat/sword_duel.gd", "title": "Sword Duel", "category": "Combat", "duration": 40.0, "tagline": "Slash first — last one standing!"},
	{"script": "res://minigames/combat/bomb_throw.gd", "title": "Bomb Throw", "category": "Combat", "duration": 40.0, "tagline": "Toss bombs — don't get caught!", "launch": true},
	{"script": "res://minigames/combat/laser_survival.gd", "title": "Laser Survival", "category": "Combat", "duration": 30.0, "tagline": "Dodge the beams!"},
	{"script": "res://minigames/combat/mini_shooter.gd", "title": "Mini Shooter", "category": "Combat", "duration": 40.0, "tagline": "Outshoot everyone!"},
	{"script": "res://minigames/combat/beyblade.gd", "title": "Beyblade", "category": "Combat", "duration": 45.0, "tagline": "Rip it in — last top spinning wins!", "launch": true},
	# --- Growth / Survival ---
	{"script": "res://minigames/growth/snake_battle.gd", "title": "Snake Battle", "category": "Growth", "duration": 45.0, "tagline": "Grow & survive — don't crash!", "launch": true},
	{"script": "res://minigames/growth/blob_growth.gd", "title": "Blob Growth", "category": "Growth", "duration": 30.0, "tagline": "Eat orbs, get huge!"},
	{"script": "res://minigames/growth/zone_shrink.gd", "title": "Zone Shrink", "category": "Growth", "duration": 30.0, "tagline": "Stay in the safe zone!", "launch": true},
	{"script": "res://minigames/growth/king_of_arena.gd", "title": "King of Arena", "category": "Growth", "duration": 30.0, "tagline": "Hold the throne!", "launch": true},
	{"script": "res://minigames/growth/virus_spread.gd", "title": "Virus Spread", "category": "Growth", "duration": 30.0, "tagline": "Infect the most tiles!"},
	# --- Physics Sports ---
	{"script": "res://minigames/sports/mini_soccer.gd", "title": "Mini Soccer", "category": "Sports", "duration": 40.0, "tagline": "Score the most goals!", "launch": true},
	{"script": "res://minigames/sports/sumo_push.gd", "title": "Sumo Push", "category": "Sports", "duration": 40.0, "tagline": "Shove them off the ring!", "launch": true},
	{"script": "res://minigames/sports/basketball_rush.gd", "title": "Basketball Rush", "category": "Sports", "duration": 30.0, "tagline": "Sink the most hoops!"},
	{"script": "res://minigames/sports/tug_of_war.gd", "title": "Tug of War", "category": "Sports", "duration": 20.0, "tagline": "Pull them over the line!"},
	{"script": "res://minigames/sports/hockey_slide.gd", "title": "Hockey Slide", "category": "Sports", "duration": 40.0, "tagline": "Slap shots for the win!"},
	# --- Reaction / Timing ---
	{"script": "res://minigames/reaction/reaction_tap.gd", "title": "Reaction Tap", "category": "Reaction", "duration": 15.0, "tagline": "Tap the instant it's green!", "launch": true},
	{"script": "res://minigames/reaction/stop_timer.gd", "title": "Stop Timer", "category": "Reaction", "duration": 20.0, "tagline": "Stop it as close to zero!"},
	{"script": "res://minigames/reaction/color_match.gd", "title": "Color Match", "category": "Reaction", "duration": 25.0, "tagline": "Match the colour, fast!"},
	{"script": "res://minigames/reaction/light_signal.gd", "title": "Light Signal", "category": "Reaction", "duration": 15.0, "tagline": "React on the signal!"},
	{"script": "res://minigames/reaction/memory_sequence.gd", "title": "Memory Sequence", "category": "Reaction", "duration": 30.0, "tagline": "Remember the pattern!"},
	# --- Platform / Survival ---
	{"script": "res://minigames/platform/falling_platforms.gd", "title": "Falling Platforms", "category": "Platform", "duration": 35.0, "tagline": "Don't fall through the gaps!", "launch": true},
	{"script": "res://minigames/platform/lava_rising.gd", "title": "Lava Rising", "category": "Platform", "duration": 35.0, "tagline": "Climb above the lava!", "launch": true},
	{"script": "res://minigames/platform/jump_gap.gd", "title": "Jump Gap", "category": "Platform", "duration": 30.0, "tagline": "Time your jumps!"},
	{"script": "res://minigames/platform/moving_block.gd", "title": "Moving Block Escape", "category": "Platform", "duration": 30.0, "tagline": "Don't get crushed!"},
	{"script": "res://minigames/platform/rotating_platform.gd", "title": "Rotating Platform", "category": "Platform", "duration": 30.0, "tagline": "Hang on — don't fly off!"},
	# --- Board / Classic ---
	{"script": "res://minigames/board/ludo.gd", "title": "Ludo", "category": "Board", "duration": 150.0, "tagline": "Roll the die, race all 4 tokens home!", "launch": true},
]

# Short asset key derived from the script filename, e.g.
# "res://minigames/combat/tank_battle.gd" -> "tank_battle".
# Used to locate matching PNGs under res://assets/.
static func slug(entry: Dictionary) -> String:
	var path: String = entry.get("script", "")
	return path.get_file().get_basename()

# Indices into GAMES for the curated launch roster (the grid shows only these).
# Falls back to ALL games if nothing is flagged, so the grid is never empty.
static func launch_indices() -> Array:
	var out: Array = []
	for i in GAMES.size():
		if GAMES[i].get("launch", false):
			out.append(i)
	if out.is_empty():
		for i in GAMES.size():
			out.append(i)
	return out

# Session play counts — incremented each time a game is picked this run.
static var play_counts: Dictionary = {}

static func record_play(index: int) -> void:
	play_counts[index] = play_counts.get(index, 0) + 1

static func get_play_count(index: int) -> int:
	return play_counts.get(index, 0)
