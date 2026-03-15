## shape_drawer.gd — Static 2D room-silhouette drawing shared by the room
## detail preview and the hull-layout blueprint.  All coordinates are scaled
## by `s` so the same art works at any size (s=1.0 for full preview, ~0.43 for
## the small blueprint cells).
class_name ShapeDrawer


## Entry point — draw the fandom-aware silhouette onto `canvas`.
static func draw_room(canvas: CanvasItem, rtype: String, universe: String,
		col: Color, center: Vector2, s: float) -> void:
	match universe:
		"Star Trek": _trek(canvas, rtype, col, center, s)
		"Star Wars": _wars(canvas, rtype, col, center, s)
		"Babylon 5": _b5(canvas,   rtype, col, center, s)
		"Dune":      _dune(canvas,  rtype, col, center, s)
		_:           _generic(canvas, rtype, col, center, s)


# ── Internal draw helpers ─────────────────────────────────────────────────────

static func _fill(cv: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	cv.draw_polygon(pts, PackedColorArray([col]))

static func _wire(cv: CanvasItem, pts: PackedVector2Array, col: Color,
		w: float = 1.0) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	cv.draw_polyline(closed, col, w)

static func _ell(cx: float, cy: float, rx: float, ry: float,
		n: int = 28) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		p.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return p

static func _reg(center: Vector2, r: float, n: int,
		off: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n) + off
		p.append(center + Vector2(cos(a), sin(a)) * r)
	return p

static func _lw(s: float) -> float:
	return maxf(1.0, s)   # minimum 1 px line width at any scale


# ── Star Trek Federation ──────────────────────────────────────────────────────

static func _trek(cv: CanvasItem, rtype: String, col: Color,
		c: Vector2, s: float) -> void:
	var fill := col.darkened(0.28)
	var edge := col.lightened(0.20)
	match rtype:
		"Command":
			# Saucer section + bridge dome + navigation deflector
			var saucer := _ell(c.x, c.y + 5.0*s, 28.0*s, 13.0*s)
			_fill(cv, saucer, fill);  _wire(cv, saucer, edge)
			var dome := _ell(c.x, c.y - 9.0*s, 9.0*s, 6.0*s)
			_fill(cv, dome, col.lightened(0.08));  _wire(cv, dome, edge)
			cv.draw_circle(Vector2(c.x, c.y + 17.5*s), 5.5*s,
				Color(0.28, 0.55, 0.90))
			cv.draw_circle(Vector2(c.x, c.y + 17.5*s), 5.5*s,
				Color(0.55, 0.80, 1.0), false, _lw(s))
		"Engines":
			# Twin warp nacelles + bussard collectors + pylon strut
			for side: float in [-13.0, 13.0]:
				var nac := _ell(c.x, c.y + side*s, 22.0*s, 5.5*s)
				_fill(cv, nac, fill);  _wire(cv, nac, edge)
				cv.draw_circle(Vector2(c.x - 20.0*s, c.y + side*s),
					5.5*s, Color(0.85, 0.28, 0.15))
				cv.draw_circle(Vector2(c.x - 20.0*s, c.y + side*s),
					5.5*s, Color(1.0, 0.55, 0.3), false, _lw(s))
			cv.draw_rect(Rect2(c.x - 2.0*s, c.y - 8.0*s,
				4.0*s, 16.0*s), col.darkened(0.40))
		"Power":
			# Secondary hull (trapezoid) + deflector dish
			var hull := PackedVector2Array([
				Vector2(c.x - 18.0*s, c.y - 22.0*s),
				Vector2(c.x + 18.0*s, c.y - 22.0*s),
				Vector2(c.x +  9.0*s, c.y + 18.0*s),
				Vector2(c.x -  9.0*s, c.y + 18.0*s),
			])
			_fill(cv, hull, fill);  _wire(cv, hull, edge)
			cv.draw_circle(Vector2(c.x, c.y + 28.0*s), 8.5*s,
				Color(0.25, 0.50, 0.90))
			cv.draw_circle(Vector2(c.x, c.y + 28.0*s), 8.5*s,
				Color(0.55, 0.80, 1.0), false, _lw(s))
		"Tactical":
			# Phaser arc strips + photon torpedo tubes
			cv.draw_arc(c, 25.0*s, deg_to_rad(-152.0), deg_to_rad(-28.0),
				24, col, 4.5*s)
			cv.draw_arc(c, 25.0*s, deg_to_rad( 28.0),  deg_to_rad(152.0),
				24, col, 4.5*s)
			cv.draw_rect(Rect2(c.x - 17.0*s, c.y - 6.0*s, 14.0*s, 12.0*s), fill)
			cv.draw_rect(Rect2(c.x +  3.0*s, c.y - 6.0*s, 14.0*s, 12.0*s), fill)
			cv.draw_rect(Rect2(c.x - 17.0*s, c.y - 6.0*s, 14.0*s, 12.0*s),
				edge, false)
			cv.draw_rect(Rect2(c.x +  3.0*s, c.y - 6.0*s, 14.0*s, 12.0*s),
				edge, false)
		_:
			_generic(cv, rtype, col, c, s)


# ── Star Wars Imperial ────────────────────────────────────────────────────────

static func _wars(cv: CanvasItem, rtype: String, col: Color,
		c: Vector2, s: float) -> void:
	var fill := col.darkened(0.28)
	var edge := col.lightened(0.20)
	match rtype:
		"Command":
			# Star Destroyer triangular wedge (top-down) + bridge tower
			var wedge := PackedVector2Array([
				Vector2(c.x,          c.y - 30.0*s),
				Vector2(c.x + 22.0*s, c.y + 22.0*s),
				Vector2(c.x,          c.y + 12.0*s),
				Vector2(c.x - 22.0*s, c.y + 22.0*s),
			])
			_fill(cv, wedge, fill);  _wire(cv, wedge, edge)
			cv.draw_rect(Rect2(c.x - 5.5*s, c.y - 12.0*s,
				11.0*s, 18.0*s), col.lightened(0.14))
			cv.draw_rect(Rect2(c.x - 5.5*s, c.y - 12.0*s,
				11.0*s, 18.0*s), edge, false)
		"Engines":
			# Engine room block + 4 circular ion exhaust ports (2×2)
			cv.draw_rect(Rect2(c.x - 24.0*s, c.y - 22.0*s,
				48.0*s, 42.0*s), fill)
			cv.draw_rect(Rect2(c.x - 24.0*s, c.y - 22.0*s,
				48.0*s, 42.0*s), edge, false)
			for ex: float in [-11.0, 11.0]:
				for ey: float in [-9.0, 9.0]:
					cv.draw_circle(Vector2(c.x + ex*s, c.y + ey*s),
						6.5*s, col.darkened(0.44))
					cv.draw_circle(Vector2(c.x + ex*s, c.y + ey*s),
						6.5*s, col.lightened(0.14), false, _lw(s))
		"Power":
			# Hexagonal reactor core + 3 power spokes + central ring
			var hex := _reg(c, 26.0*s, 6, deg_to_rad(30.0))
			_fill(cv, hex, fill);  _wire(cv, hex, edge)
			for i in 3:
				var a := TAU * float(i) / 3.0
				cv.draw_line(c, c + Vector2(cos(a), sin(a)) * 26.0*s,
					edge.darkened(0.20), 1.0)
			cv.draw_circle(c, 10.0*s, col.lightened(0.05))
			cv.draw_circle(c, 10.0*s, col.lightened(0.40), false, _lw(s))
		"Tactical":
			# Turbolaser base + 3 dome mounts on top
			cv.draw_rect(Rect2(c.x - 25.0*s, c.y - 6.0*s,
				50.0*s, 24.0*s), fill)
			cv.draw_rect(Rect2(c.x - 25.0*s, c.y - 6.0*s,
				50.0*s, 24.0*s), edge, false)
			for tx: float in [-14.0, 0.0, 14.0]:
				cv.draw_circle(Vector2(c.x + tx*s, c.y - 6.0*s),
					7.5*s, col.lightened(0.08))
				cv.draw_circle(Vector2(c.x + tx*s, c.y - 6.0*s),
					7.5*s, edge, false, _lw(s))
		_:
			_generic(cv, rtype, col, c, s)


# ── Babylon 5 ─────────────────────────────────────────────────────────────────

static func _b5(cv: CanvasItem, rtype: String, col: Color,
		c: Vector2, s: float) -> void:
	var fill := col.darkened(0.28)
	var edge := col.lightened(0.20)
	match rtype:
		"Command":
			# Hexagonal C&C module + central viewport dome
			var hex := _reg(c, 25.0*s, 6)
			_fill(cv, hex, fill);  _wire(cv, hex, edge)
			cv.draw_circle(c, 9.0*s, col.lightened(0.10))
			cv.draw_circle(c, 9.0*s, edge, false, _lw(s))
		"Engines":
			# Cylindrical drive body + exhaust nozzle + swept fins
			var body := _ell(c.x - 5.0*s, c.y, 18.0*s, 8.0*s)
			_fill(cv, body, fill);  _wire(cv, body, edge)
			cv.draw_circle(Vector2(c.x + 19.0*s, c.y), 10.0*s, col.darkened(0.40))
			cv.draw_circle(Vector2(c.x + 19.0*s, c.y), 10.0*s, edge, false, _lw(s))
			cv.draw_circle(Vector2(c.x + 19.0*s, c.y),  5.0*s, col.lightened(0.20))
			for side: float in [-1.0, 1.0]:
				cv.draw_line(Vector2(c.x - 18.0*s, c.y),
					Vector2(c.x - 5.0*s, c.y + side * 20.0*s), edge, 2.0*s)
		"Power":
			# Circular fusion reactor + 4 radiating heat-sink fins
			cv.draw_circle(c, 17.0*s, fill)
			cv.draw_circle(c, 17.0*s, edge, false, _lw(s))
			cv.draw_circle(c, 7.0*s, col.lightened(0.22))
			for i in 4:
				var a := TAU * float(i) / 4.0 + deg_to_rad(45.0)
				var tip  := c + Vector2(cos(a), sin(a)) * 32.0*s
				var base := c + Vector2(cos(a), sin(a)) * 17.0*s
				cv.draw_line(base, tip, edge, 4.0*s)
		"Tactical":
			# Forward-pointing weapons pod (trapezoid) + gun barrels
			var pod := PackedVector2Array([
				Vector2(c.x - 10.0*s, c.y - 26.0*s),
				Vector2(c.x + 10.0*s, c.y - 26.0*s),
				Vector2(c.x + 26.0*s, c.y + 22.0*s),
				Vector2(c.x - 26.0*s, c.y + 22.0*s),
			])
			_fill(cv, pod, fill);  _wire(cv, pod, edge)
			for gx: float in [-9.0, 9.0]:
				cv.draw_rect(Rect2(c.x + gx*s - 2.5*s, c.y - 38.0*s,
					5.0*s, 14.0*s), col.lightened(0.10))
		_:
			_generic(cv, rtype, col, c, s)


# ── Dune ──────────────────────────────────────────────────────────────────────

static func _dune(cv: CanvasItem, rtype: String, col: Color,
		c: Vector2, s: float) -> void:
	var fill := col.darkened(0.28)
	var edge := col.lightened(0.20)
	match rtype:
		"Command":
			# Navigator's chamber — large egg + nested inner oval + portholes
			var outer := _ell(c.x, c.y, 27.0*s, 21.0*s)
			_fill(cv, outer, fill);  _wire(cv, outer, edge)
			var inner := _ell(c.x, c.y, 15.0*s, 11.0*s)
			_fill(cv, inner, col.darkened(0.42))
			_wire(cv, inner, col.lightened(0.32))
			for px: float in [-17.0, 0.0, 17.0]:
				cv.draw_circle(Vector2(c.x + px*s, c.y + 23.0*s),
					2.8*s, col.lightened(0.22))
		"Engines":
			# Suspensor anti-gravity array — 5 discs in X pattern
			var spots: Array[Vector2] = [
				c,
				c + Vector2(-19.0, -14.0) * s,
				c + Vector2( 19.0, -14.0) * s,
				c + Vector2(-19.0,  14.0) * s,
				c + Vector2( 19.0,  14.0) * s,
			]
			for sp: Vector2 in spots.slice(1):
				cv.draw_line(c, sp, col.darkened(0.22), 1.0)
			for sp: Vector2 in spots:
				cv.draw_circle(sp, 9.5*s, fill)
				cv.draw_circle(sp, 9.5*s, edge, false, _lw(s))
				cv.draw_circle(sp, 4.0*s, col.lightened(0.28))
		"Power":
			# Holtzman field generator — two interlocking diamonds + core
			for ox: float in [-9.5, 9.5]:
				var diamond := PackedVector2Array([
					Vector2(c.x + ox*s,          c.y - 25.0*s),
					Vector2(c.x + ox*s + 19.0*s,  c.y),
					Vector2(c.x + ox*s,           c.y + 25.0*s),
					Vector2(c.x + ox*s - 19.0*s,  c.y),
				])
				_fill(cv, diamond, fill);  _wire(cv, diamond, edge)
			cv.draw_circle(c, 8.0*s, col.lightened(0.32))
			cv.draw_circle(c, 8.0*s, col.lightened(0.55), false, _lw(s))
		"Tactical":
			# Lasgun battery — paired angled parallelogram blades + emitter tips
			for tx: float in [-13.0, 13.0]:
				var blade := PackedVector2Array([
					Vector2(c.x + tx*s - 7.0*s,  c.y - 22.0*s),
					Vector2(c.x + tx*s + 7.0*s,  c.y - 22.0*s),
					Vector2(c.x + tx*s + 15.0*s, c.y + 22.0*s),
					Vector2(c.x + tx*s + 1.0*s,  c.y + 22.0*s),
				])
				_fill(cv, blade, fill);  _wire(cv, blade, edge)
				cv.draw_circle(Vector2(c.x + tx*s, c.y - 25.0*s),
					3.5*s, col.lightened(0.42))
		_:
			_generic(cv, rtype, col, c, s)


# ── Generic / Universal ───────────────────────────────────────────────────────

static func _generic(cv: CanvasItem, rtype: String, col: Color,
		c: Vector2, s: float) -> void:
	var fill := col.darkened(0.28)
	var edge := col.lightened(0.20)
	match rtype:
		"Command":
			var hull := _ell(c.x, c.y + 5.0*s, 22.0*s, 18.0*s)
			_fill(cv, hull, fill);  _wire(cv, hull, edge)
			cv.draw_rect(Rect2(c.x - 18.0*s, c.y - 10.0*s, 36.0*s, 9.0*s),
				Color(0.28, 0.52, 0.82, 0.38))
			var dome := _ell(c.x, c.y - 19.0*s, 7.0*s, 6.0*s)
			_fill(cv, dome, fill);  _wire(cv, dome, edge)
		"Engines":
			cv.draw_rect(Rect2(c.x - 20.0*s, c.y - 16.0*s,
				40.0*s, 26.0*s), fill)
			cv.draw_rect(Rect2(c.x - 20.0*s, c.y - 16.0*s,
				40.0*s, 26.0*s), edge, false)
			for ex: float in [-10.0, 10.0]:
				cv.draw_circle(Vector2(c.x + ex*s, c.y + 20.0*s),
					8.5*s, col.darkened(0.38))
				cv.draw_circle(Vector2(c.x + ex*s, c.y + 20.0*s),
					8.5*s, edge, false, _lw(s))
		"Power":
			var oct := _reg(c, 22.0*s, 8, deg_to_rad(22.5))
			_fill(cv, oct, fill);  _wire(cv, oct, edge)
			cv.draw_circle(c, 9.0*s, col.lightened(0.18))
			cv.draw_circle(c, 9.0*s, col.lightened(0.42), false, _lw(s))
		"Tactical":
			cv.draw_rect(Rect2(c.x - 20.0*s, c.y - 12.0*s,
				40.0*s, 24.0*s), fill)
			cv.draw_rect(Rect2(c.x - 20.0*s, c.y - 12.0*s,
				40.0*s, 24.0*s), edge, false)
			cv.draw_rect(Rect2(c.x - 5.0*s, c.y - 26.0*s,
				10.0*s, 16.0*s), col.lightened(0.08))
			cv.draw_circle(Vector2(c.x, c.y - 8.0*s), 6.5*s,
				col.lightened(0.12))
		_: # Utility
			cv.draw_rect(Rect2(c.x - 22.0*s, c.y - 20.0*s,
				44.0*s, 40.0*s), fill)
			cv.draw_rect(Rect2(c.x - 22.0*s, c.y - 20.0*s,
				44.0*s, 40.0*s), edge, false)
			cv.draw_line(Vector2(c.x - 18.0*s, c.y - 6.0*s),
				Vector2(c.x + 18.0*s, c.y - 6.0*s), edge.darkened(0.30), 0.8)
			cv.draw_line(Vector2(c.x - 18.0*s, c.y + 6.0*s),
				Vector2(c.x + 18.0*s, c.y + 6.0*s), edge.darkened(0.30), 0.8)
