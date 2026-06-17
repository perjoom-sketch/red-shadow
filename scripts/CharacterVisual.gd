extends Node2D
## CharacterVisual.gd — stylized "Red Shadow" silhouette.
## Drawn with vector primitives (no sprite assets required).
##
## Design goal: a single bold black mass (wide hat + long coat) read
## as one shape, with ONE red accent (the scarf) and glowing cat eyes.
## The reader should instantly think "this is Red Shadow" — not a stickman.
##
## Centered on this node's origin so rotating it produces a clean flip.

# --- Palette: a few muted tones + one bold red, matching the concept art ---
const COL_BLACK := Color(0.03, 0.03, 0.04)   # Deepest black: hat, head.
const COL_BODY  := Color(0.08, 0.08, 0.10)   # Coat base.
const COL_BODY_HI := Color(0.15, 0.15, 0.19) # Coat highlight / fold.
const COL_BOOT  := Color(0.12, 0.09, 0.08)   # Old leather boots.
const COL_SCARF := Color(0.78, 0.12, 0.14)   # The single red accent.
const COL_SCARF_DK := Color(0.50, 0.07, 0.09) # Scarf shadow fold.
const COL_EYE   := Color(0.98, 0.85, 0.30)   # Glowing cat eyes.
const COL_STEEL := Color(0.70, 0.74, 0.82)   # Katana blade.
const COL_STEEL_DK := Color(0.40, 0.43, 0.50) # Blade shadow side.


func _draw() -> void:
	# Drawn back-to-front. A tall, lean swordsman: wide hat + cat ears,
	# windswept red scarf, long tattered coat, boots, drawn katana.

	# --- Windswept red scarf, flowing up and behind (the hero element) ---
	# Lower trailing ribbon.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -16), Vector2(-30, -6), Vector2(-58, 4), Vector2(-66, 0),
		Vector2(-50, -8), Vector2(-28, -16), Vector2(-8, -22)
	]), COL_SCARF_DK)
	# Upper billowing ribbon.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -24), Vector2(-26, -40), Vector2(-50, -56), Vector2(-58, -50),
		Vector2(-42, -40), Vector2(-24, -28), Vector2(-8, -20)
	]), COL_SCARF)

	# --- CAT TAIL: long, swishing, curling up behind — the cat essence ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 28), Vector2(24, 24), Vector2(38, 12), Vector2(45, -8),
		Vector2(43, -26), Vector2(50, -25), Vector2(52, -6),
		Vector2(46, 14), Vector2(32, 28), Vector2(14, 34)
	]), COL_BLACK)

	# --- Back coat-tail sweeping behind (long, tattered) ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 2), Vector2(-30, 26), Vector2(-46, 52), Vector2(-36, 54),
		Vector2(-26, 38), Vector2(-22, 50), Vector2(-14, 30), Vector2(-8, 20)
	]), COL_BODY)

	# --- Long coat: main body mass, narrow waist, ragged tattered hem ---
	var coat := PackedVector2Array([
		Vector2(-13, -20), Vector2(13, -20),   # shoulders
		Vector2(9, -2), Vector2(13, 18),       # right side -> hip
		Vector2(20, 52), Vector2(14, 38),      # ragged hem (down/up...)
		Vector2(11, 56), Vector2(6, 40),
		Vector2(2, 58), Vector2(-3, 42),
		Vector2(-7, 56), Vector2(-12, 40),
		Vector2(-17, 53), Vector2(-13, 18),    # left hip
		Vector2(-9, -2)                        # left waist
	])
	draw_colored_polygon(coat, COL_BODY)
	# Coat highlight strip (catches light down the front edge).
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -18), Vector2(7, -2), Vector2(6, 30), Vector2(2, 44),
		Vector2(0, 30), Vector2(0, -16)
	]), COL_BODY_HI)

	# --- Boots peeking below the coat ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 50), Vector2(-2, 50), Vector2(-1, 60), Vector2(-13, 60)
	]), COL_BOOT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 50), Vector2(12, 50), Vector2(14, 60), Vector2(2, 60)
	]), COL_BOOT)

	# --- Drawn katana, held low and angled forward ---
	draw_line(Vector2(10, 4), Vector2(50, 40), COL_STEEL, 3.0)      # blade
	draw_line(Vector2(11, 6), Vector2(49, 41), COL_STEEL_DK, 1.0)   # edge shadow
	draw_line(Vector2(6, -2), Vector2(12, 6), COL_BLACK, 4.0)       # hilt (wrapped)
	draw_line(Vector2(7, 2), Vector2(13, 2), COL_SCARF, 3.0)        # red-wrapped guard

	# --- BIG cat ears: the dominant feature so the cat reads first ---
	draw_colored_polygon(PackedVector2Array([   # left ear (tall)
		Vector2(-17, -42), Vector2(-26, -68), Vector2(-2, -50)
	]), COL_BLACK)
	draw_colored_polygon(PackedVector2Array([   # right ear (tall)
		Vector2(17, -42), Vector2(26, -68), Vector2(2, -50)
	]), COL_BLACK)
	# Inner-ear (dark red) to emphasise the feline shape.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -45), Vector2(-21, -62), Vector2(-7, -50)
	]), COL_SCARF_DK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(15, -45), Vector2(21, -62), Vector2(7, -50)
	]), COL_SCARF_DK)

	# --- Head (hidden face in shadow between hat brim and scarf) ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -42), Vector2(11, -42),
		Vector2(9, -22), Vector2(-9, -22)
	]), COL_BLACK)

	# --- Glowing cat eyes: the only feature peeking from the hat shadow ---
	# Sit them high so the wide brim above reads as shadow over the eyes.
	draw_colored_polygon(PackedVector2Array([   # left eye (almond)
		Vector2(-9, -36), Vector2(-3, -38), Vector2(-2, -33), Vector2(-8, -31)
	]), COL_EYE)
	draw_colored_polygon(PackedVector2Array([   # right eye (almond)
		Vector2(9, -36), Vector2(3, -38), Vector2(2, -33), Vector2(8, -31)
	]), COL_EYE)

	# --- Wide hat: broad down-turned brim, the iconic top of the form ---
	draw_colored_polygon(PackedVector2Array([   # wide brim, drooping at the sides
		Vector2(-34, -38), Vector2(-22, -44), Vector2(22, -44), Vector2(34, -38),
		Vector2(30, -34), Vector2(16, -38), Vector2(-16, -38), Vector2(-30, -34)
	]), COL_BLACK)
	draw_colored_polygon(PackedVector2Array([   # tall tapered crown
		Vector2(-12, -43), Vector2(12, -43),
		Vector2(8, -64), Vector2(-8, -64)
	]), COL_BLACK)
	# Red hat band ties the scarf colour up to the head.
	draw_line(Vector2(-11, -44), Vector2(11, -44), COL_SCARF, 3.0)

	# --- Red scarf: pulled up to cover the mouth/lower face (priority) ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -30), Vector2(12, -30),   # top edge, just below the eyes
		Vector2(13, -8), Vector2(-13, -8)      # wraps down over the neck
	]), COL_SCARF)
	# Folded knot for depth.
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -20), Vector2(12, -15), Vector2(9, -4), Vector2(-1, -11)
	]), COL_SCARF_DK)
