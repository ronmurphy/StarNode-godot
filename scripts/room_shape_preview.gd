## room_shape_preview.gd — Fandom-aware 2D silhouette of a ship room.
## Delegates all drawing to ShapeDrawer so the same art appears in both
## the sidebar detail panel and the hull-layout blueprint.
class_name RoomShapePreview
extends Control

var _def: Dictionary = {}


func set_room(def: Dictionary) -> void:
	_def = def
	queue_redraw()


func clear_room() -> void:
	_def = {}
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.09, 0.82))

	if _def.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(c.x, c.y + 4.0),
			"--", HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
			Color(0.35, 0.42, 0.58, 0.55))
		return

	var rtype:    String = _def.get("type",     "Utility")
	var universe: String = _def.get("universe", "Universal")
	ShapeDrawer.draw_room(self, rtype, universe, RoomData.type_color(rtype), c, 1.0)
