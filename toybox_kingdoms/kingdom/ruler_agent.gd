extends RefCounted

# ── Per-ruler state (human or AI) ────────────────────────────────────────────
# Both kinds go through the identical grid seam (enter_cell), capture and death.
# The only difference: a human's avatar drives itself from InputManager; an AI's
# avatar is driven by the match from its KingdomAI brain (because InputManager is
# capped at 4 slots and we want many more kingdoms).

var kid: int = 0              # grid kingdom id (>=1; 0 is neutral)
var is_ai: bool = false
var avatar                    # Avatar3D
var home: Vector2i = Vector2i.ZERO
var last_cell: Vector2i = Vector2i.ZERO
var alive: bool = true
var eliminated: bool = false   # territory fully conquered -> out of the match
var defense: int = 0           # towers/castle upgrades add here (raises conquest level-gate)

# ── economy (per ruler; human spends via the panel, AI buys via a heuristic) ──
var coins: int = 60
var income: float = 12.0       # coins per minute
var coin_accum: float = 0.0
var farms: int = 0
var towers: int = 0
var barracks: int = 0
var castle_floor: int = 1      # min castle level bought via CASTLE
var respawn_t: float = 0.0
var ai                        # KingdomAI brain, or null for the human
var castle                    # PRIMARY Castle node (castles[0].node) — spawn/AI home
var castles: Array = []       # all owned castles: [{cell: Vector2i, node: Castle}, ...]
                              # you only fall when ALL of these are captured.
var name_tag                  # Label3D floating over the (primary) castle
