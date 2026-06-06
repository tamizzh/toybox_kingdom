class_name MiniGameRegistry
extends RefCounted

# THE EXTENSION POINT. Add a new mini-game by appending one dictionary here.
# Each entry: { script, title, category, duration }.

const GAMES: Array = [
	# --- Racing / Speed ---
	{"script": "res://minigames/racing/sprint_race.gd", "title": "Sprint Race", "category": "Racing", "duration": 20.0},
	{"script": "res://minigames/racing/lane_switch.gd", "title": "Lane Switch", "category": "Racing", "duration": 30.0},
	{"script": "res://minigames/racing/obstacle_dash.gd", "title": "Obstacle Dash", "category": "Racing", "duration": 30.0},
	{"script": "res://minigames/racing/ice_slide.gd", "title": "Ice Slide Race", "category": "Racing", "duration": 25.0},
	{"script": "res://minigames/racing/hill_climb.gd", "title": "Hill Climb", "category": "Racing", "duration": 25.0},
	# --- Arena Combat ---
	{"script": "res://minigames/combat/tank_battle.gd", "title": "Tank Battle", "category": "Combat", "duration": 40.0},
	{"script": "res://minigames/combat/sword_duel.gd", "title": "Sword Duel", "category": "Combat", "duration": 40.0},
	{"script": "res://minigames/combat/bomb_throw.gd", "title": "Bomb Throw", "category": "Combat", "duration": 40.0},
	{"script": "res://minigames/combat/laser_survival.gd", "title": "Laser Survival", "category": "Combat", "duration": 30.0},
	{"script": "res://minigames/combat/mini_shooter.gd", "title": "Mini Shooter", "category": "Combat", "duration": 40.0},
	# --- Growth / Survival ---
	{"script": "res://minigames/growth/snake_battle.gd", "title": "Snake Battle", "category": "Growth", "duration": 45.0},
	{"script": "res://minigames/growth/blob_growth.gd", "title": "Blob Growth", "category": "Growth", "duration": 30.0},
	{"script": "res://minigames/growth/zone_shrink.gd", "title": "Zone Shrink", "category": "Growth", "duration": 30.0},
	{"script": "res://minigames/growth/king_of_arena.gd", "title": "King of Arena", "category": "Growth", "duration": 30.0},
	{"script": "res://minigames/growth/virus_spread.gd", "title": "Virus Spread", "category": "Growth", "duration": 30.0},
	# --- Physics Sports ---
	{"script": "res://minigames/sports/mini_soccer.gd", "title": "Mini Soccer", "category": "Sports", "duration": 40.0},
	{"script": "res://minigames/sports/sumo_push.gd", "title": "Sumo Push", "category": "Sports", "duration": 40.0},
	{"script": "res://minigames/sports/basketball_rush.gd", "title": "Basketball Rush", "category": "Sports", "duration": 30.0},
	{"script": "res://minigames/sports/tug_of_war.gd", "title": "Tug of War", "category": "Sports", "duration": 20.0},
	{"script": "res://minigames/sports/hockey_slide.gd", "title": "Hockey Slide", "category": "Sports", "duration": 40.0},
	# --- Reaction / Timing ---
	{"script": "res://minigames/reaction/reaction_tap.gd", "title": "Reaction Tap", "category": "Reaction", "duration": 15.0},
	{"script": "res://minigames/reaction/stop_timer.gd", "title": "Stop Timer", "category": "Reaction", "duration": 20.0},
	{"script": "res://minigames/reaction/color_match.gd", "title": "Color Match", "category": "Reaction", "duration": 25.0},
	{"script": "res://minigames/reaction/light_signal.gd", "title": "Light Signal", "category": "Reaction", "duration": 15.0},
	{"script": "res://minigames/reaction/memory_sequence.gd", "title": "Memory Sequence", "category": "Reaction", "duration": 30.0},
	# --- Platform / Survival ---
	{"script": "res://minigames/platform/falling_platforms.gd", "title": "Falling Platforms", "category": "Platform", "duration": 35.0},
	{"script": "res://minigames/platform/lava_rising.gd", "title": "Lava Rising", "category": "Platform", "duration": 35.0},
	{"script": "res://minigames/platform/jump_gap.gd", "title": "Jump Gap", "category": "Platform", "duration": 30.0},
	{"script": "res://minigames/platform/moving_block.gd", "title": "Moving Block Escape", "category": "Platform", "duration": 30.0},
	{"script": "res://minigames/platform/rotating_platform.gd", "title": "Rotating Platform", "category": "Platform", "duration": 30.0},
]

# Short asset key derived from the script filename, e.g.
# "res://minigames/combat/tank_battle.gd" -> "tank_battle".
# Used to locate matching PNGs under res://assets/.
static func slug(entry: Dictionary) -> String:
	var path: String = entry.get("script", "")
	return path.get_file().get_basename()
