## ship_node.gd — A placed room on the ship canvas.
## Extends GraphNode so GraphEdit handles connections natively.
class_name ShipNode
extends GraphNode

var def_id: String = ""
var node_uid: String = ""          # stable ID for save/load (different from name)
var current_durability: int = 100
var max_durability: int = 100
var hull_offset: Vector2 = Vector2.ZERO   # visual offset for hull layout (GraphEdit-space px)

var _lbl_power: Label
var _lbl_type: Label
var _dur_bar: ProgressBar


func setup(def: Dictionary, uid: String) -> void:
	def_id = def.id
	node_uid = uid
	title = def.name
	current_durability = def.durability
	max_durability = def.durability

	custom_minimum_size = Vector2(160, 0)

	# Title bar color via theme override
	var title_color: Color = RoomData.type_color(def.type)
	add_theme_color_override("title_color", Color.WHITE)
	add_theme_stylebox_override("titlebar", _make_titlebar(title_color))
	add_theme_stylebox_override("titlebar_selected", _make_titlebar(title_color.lightened(0.2)))
	add_theme_stylebox_override("panel", _make_panel())
	add_theme_stylebox_override("panel_selected", _make_panel_selected())

	# Body content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_lbl_power = Label.new()
	_lbl_power.text = RoomData.power_label(def.power)
	_lbl_power.add_theme_color_override("font_color",
		Color(0.30, 0.90, 0.55, 1.0) if def.power >= 0 else Color(0.90, 0.40, 0.30, 1.0))
	_lbl_power.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_lbl_power)

	_lbl_type = Label.new()
	_lbl_type.text = "%s  ·  %s" % [def.type, def.universe]
	_lbl_type.add_theme_color_override("font_color", Color(0.60, 0.68, 0.85, 1.0))
	_lbl_type.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_lbl_type)

	# Durability bar
	var dur_row := HBoxContainer.new()
	vbox.add_child(dur_row)

	var dur_lbl := Label.new()
	dur_lbl.text = "DUR"
	dur_lbl.add_theme_font_size_override("font_size", 10)
	dur_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
	dur_lbl.custom_minimum_size.x = 28
	dur_row.add_child(dur_lbl)

	_dur_bar = ProgressBar.new()
	_dur_bar.max_value = max_durability
	_dur_bar.value = current_durability
	_dur_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dur_bar.custom_minimum_size.y = 12
	_dur_bar.show_percentage = false
	dur_row.add_child(_dur_bar)

	_refresh_dur_bar()

	# Left input port + right output port on slot 0 (first child = vbox)
	set_slot(0,
		true, 0, Color(0.30, 0.70, 1.00, 1.0),   # left input
		true, 0, Color(0.30, 0.70, 1.00, 1.0))    # right output


func apply_damage(amount: int) -> void:
	current_durability = max(0, current_durability - amount)
	_refresh_dur_bar()


func repair_full(def: Dictionary) -> void:
	current_durability = def.durability
	_refresh_dur_bar()


func _refresh_dur_bar() -> void:
	if _dur_bar == null:
		return
	_dur_bar.value = current_durability
	var pct: float = float(current_durability) / float(max_durability)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.24, 0.70, 0.32, 1.0) if pct > 0.6 \
		else (Color(0.80, 0.66, 0.15, 1.0) if pct > 0.3 else Color(0.80, 0.22, 0.22, 1.0))
	_dur_bar.add_theme_stylebox_override("fill", bar_style)


# ── Style helpers ────────────────────────────────────────────────────────────

static func _make_titlebar(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func _make_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.14, 0.22, 1.0)
	s.border_color = Color(0.23, 0.31, 0.47, 1.0)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s


static func _make_panel_selected() -> StyleBoxFlat:
	var s := _make_panel()
	s.border_color = Color(0.60, 0.30, 1.00, 1.0)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	return s
