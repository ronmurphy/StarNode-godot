## cargo_puzzle_grid.gd — Interactive grid for the cargo loading puzzle.
## Handles drawing the grid state and mouse input (place / remove pieces).
class_name CargoPuzzleGrid
extends Control

signal placement_changed

const PIECE_COLORS: Array = [
	Color(0.95, 0.35, 0.35, 1.0),  # red
	Color(0.35, 0.80, 0.95, 1.0),  # cyan
	Color(0.95, 0.80, 0.25, 1.0),  # yellow
	Color(0.40, 0.90, 0.45, 1.0),  # green
	Color(0.80, 0.45, 0.95, 1.0),  # purple
	Color(0.95, 0.60, 0.25, 1.0),  # orange
	Color(0.40, 0.55, 0.95, 1.0),  # blue
	Color(0.95, 0.45, 0.75, 1.0),  # pink
]

const CLR_EMPTY  := Color(0.10, 0.15, 0.24, 1.0)
const CLR_BORDER := Color(0.22, 0.32, 0.50, 1.0)

var cols: int = 2
var rows: int = 2
var cell_size: int = 72

# Grid state: [row][col] = piece_id or -1 (empty)
var grid: Array = []

# Interaction state — set by CargoPuzzle
var selected_pid: int   = -1
var hover_cells: Array  = []   # rotated cells of selected piece
var hover_valid: bool   = false

var _hover_origin: Vector2i = Vector2i(-1, -1)


func init_grid() -> void:
	grid = []
	for _r in rows:
		var row: Array = []
		for _c in cols:
			row.append(-1)
		grid.append(row)
	custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	for r in rows:
		for c in cols:
			var x: float = c * cell_size
			var y: float = r * cell_size
			var fill_rect := Rect2(x + 1, y + 1, cell_size - 2, cell_size - 2)
			var pid: int = grid[r][c]
			if pid == -1:
				draw_rect(fill_rect, CLR_EMPTY)
			else:
				var col: Color = PIECE_COLORS[pid % PIECE_COLORS.size()]
				draw_rect(fill_rect, col)
				# Highlight top edge of each piece cell
				draw_rect(Rect2(x + 1, y + 1, cell_size - 2, 3), col.lightened(0.35))
			# Cell border
			draw_rect(Rect2(x, y, cell_size, cell_size), CLR_BORDER, false, 1.0)

	# Hover preview
	if selected_pid >= 0 and _hover_origin.x >= 0 and not hover_cells.is_empty():
		var col: Color = PIECE_COLORS[selected_pid % PIECE_COLORS.size()]
		hover_valid = _can_place(_hover_origin, hover_cells)
		var alpha: float = 0.50 if hover_valid else 0.30
		var tint: Color = col if hover_valid else Color(1.0, 0.2, 0.2, 1.0)
		tint.a = alpha
		for offset in hover_cells:
			var gc: Vector2i = _hover_origin + offset
			if gc.x < 0 or gc.x >= cols or gc.y < 0 or gc.y >= rows:
				continue
			var fx: float = gc.x * cell_size
			var fy: float = gc.y * cell_size
			draw_rect(Rect2(fx + 1, fy + 1, cell_size - 2, cell_size - 2), tint)
			if hover_valid:
				draw_rect(Rect2(fx + 1, fy + 1, cell_size - 2, cell_size - 2),
					Color(1.0, 1.0, 1.0, 0.15), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_origin := _cell_at(event.position)
		if new_origin != _hover_origin:
			_hover_origin = new_origin
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var cell := _cell_at(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if selected_pid >= 0 and not hover_cells.is_empty():
					if _can_place(cell, hover_cells):
						_do_place(selected_pid, cell, hover_cells)
						placement_changed.emit()
			MOUSE_BUTTON_RIGHT:
				_do_remove(cell)
				placement_changed.emit()


func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / cell_size), int(pos.y / cell_size))


func _can_place(origin: Vector2i, cells: Array) -> bool:
	for offset in cells:
		var gc: Vector2i = origin + offset
		if gc.x < 0 or gc.x >= cols or gc.y < 0 or gc.y >= rows:
			return false
		if grid[gc.y][gc.x] != -1:
			return false
	return true


func _do_place(pid: int, origin: Vector2i, cells: Array) -> void:
	for offset in cells:
		var gc: Vector2i = origin + offset
		grid[gc.y][gc.x] = pid
	queue_redraw()


func _do_remove(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= rows:
		return
	var pid: int = grid[cell.y][cell.x]
	if pid < 0:
		return
	for r in rows:
		for c in cols:
			if grid[r][c] == pid:
				grid[r][c] = -1
	queue_redraw()


func remove_piece_by_id(pid: int) -> void:
	for r in rows:
		for c in cols:
			if grid[r][c] == pid:
				grid[r][c] = -1
	queue_redraw()


func is_full() -> bool:
	for r in rows:
		for c in cols:
			if grid[r][c] == -1:
				return false
	return true


func placed_piece_ids() -> Array:
	var found: Array = []
	for r in rows:
		for c in cols:
			var pid: int = grid[r][c]
			if pid >= 0 and not found.has(pid):
				found.append(pid)
	return found
