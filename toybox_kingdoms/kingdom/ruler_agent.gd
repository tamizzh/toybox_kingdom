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
var respawn_t: float = 0.0
var ai                        # KingdomAI brain, or null for the human
var castle                    # Castle node at this kingdom's home
var name_tag                  # Label3D floating over the castle
