class_name TerrainResolver
extends RefCounted

const CELL_EMPTY := 0
const CELL_SOLID := 1
const CELL_ONE_WAY := 2
const CELL_BACKGROUND_WALL := 3
const CELL_DECORATIVE := 4
const CELL_HAZARD := 5

const CARDINAL_OFFSETS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONAL_OFFSETS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]


static func build_logical_map(source_grid: Array, size: Vector2i) -> Dictionary:
	var logical_map: Dictionary = {
		"size": size,
		"cells": _copy_grid(source_grid, size),
		"one_way_cells": [],
		"background_cells": [],
		"decorative_cells": [],
		"hazard_cells": []
	}
	_run_cleanup_passes(logical_map)
	return logical_map


static func duplicate_cells(logical_map: Dictionary) -> Array:
	var cells: Array = logical_map.get("cells", []) as Array
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	return _copy_grid(cells, size)


static func is_solid(logical_map: Dictionary, cell: Vector2i) -> bool:
	return get_cell(logical_map, cell) == CELL_SOLID


static func get_cell(logical_map: Dictionary, cell: Vector2i) -> int:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return CELL_EMPTY
	var cells: Array = logical_map.get("cells", []) as Array
	if cell.y >= cells.size():
		return CELL_EMPTY
	var row: PackedByteArray = cells[cell.y] as PackedByteArray
	if cell.x >= row.size():
		return CELL_EMPTY
	return row[cell.x]


static func count_cardinal_solids(logical_map: Dictionary, cell: Vector2i) -> int:
	var count: int = 0
	for offset_variant: Variant in CARDINAL_OFFSETS:
		var offset: Vector2i = offset_variant as Vector2i
		if is_solid(logical_map, cell + offset):
			count += 1
	return count


static func count_diagonal_solids(logical_map: Dictionary, cell: Vector2i) -> int:
	var count: int = 0
	for offset_variant: Variant in DIAGONAL_OFFSETS:
		var offset: Vector2i = offset_variant as Vector2i
		if is_solid(logical_map, cell + offset):
			count += 1
	return count


static func _run_cleanup_passes(logical_map: Dictionary) -> void:
	_fill_single_tile_voids(logical_map)
	_fill_thin_vertical_gaps(logical_map)
	_remove_lonely_solids(logical_map)
	_fill_diagonal_support_gaps(logical_map)


static func _fill_single_tile_voids(logical_map: Dictionary) -> void:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	var current_cells: Array = logical_map.get("cells", []) as Array
	var next_cells: Array = _copy_grid(current_cells, size)
	for grid_y: int in range(size.y):
		var next_row: PackedByteArray = next_cells[grid_y] as PackedByteArray
		for grid_x: int in range(size.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if is_solid(logical_map, cell):
				continue
			if count_cardinal_solids(logical_map, cell) >= 3:
				next_row[grid_x] = CELL_SOLID
		next_cells[grid_y] = next_row
	logical_map["cells"] = next_cells


static func _remove_lonely_solids(logical_map: Dictionary) -> void:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	var current_cells: Array = logical_map.get("cells", []) as Array
	var next_cells: Array = _copy_grid(current_cells, size)
	for grid_y: int in range(size.y):
		var next_row: PackedByteArray = next_cells[grid_y] as PackedByteArray
		for grid_x: int in range(size.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if not is_solid(logical_map, cell):
				continue
			var cardinal_count: int = count_cardinal_solids(logical_map, cell)
			var diagonal_count: int = count_diagonal_solids(logical_map, cell)
			if cardinal_count <= 1 and diagonal_count <= 1:
				next_row[grid_x] = CELL_EMPTY
		next_cells[grid_y] = next_row
	logical_map["cells"] = next_cells


static func _fill_thin_vertical_gaps(logical_map: Dictionary) -> void:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	var current_cells: Array = logical_map.get("cells", []) as Array
	var next_cells: Array = _copy_grid(current_cells, size)
	for grid_y: int in range(size.y):
		var next_row: PackedByteArray = next_cells[grid_y] as PackedByteArray
		for grid_x: int in range(size.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if is_solid(logical_map, cell):
				continue
			var solid_up: bool = is_solid(logical_map, cell + Vector2i.UP)
			var solid_down: bool = is_solid(logical_map, cell + Vector2i.DOWN)
			var solid_left: bool = is_solid(logical_map, cell + Vector2i.LEFT)
			var solid_right: bool = is_solid(logical_map, cell + Vector2i.RIGHT)
			if solid_up and solid_down and (solid_left or solid_right):
				next_row[grid_x] = CELL_SOLID
		next_cells[grid_y] = next_row
	logical_map["cells"] = next_cells


static func _remove_edge_needles(logical_map: Dictionary) -> void:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	var current_cells: Array = logical_map.get("cells", []) as Array
	var next_cells: Array = _copy_grid(current_cells, size)
	for grid_y: int in range(size.y):
		var next_row: PackedByteArray = next_cells[grid_y] as PackedByteArray
		for grid_x: int in range(size.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if not is_solid(logical_map, cell):
				continue
			var solid_up: bool = is_solid(logical_map, cell + Vector2i.UP)
			var solid_down: bool = is_solid(logical_map, cell + Vector2i.DOWN)
			var solid_left: bool = is_solid(logical_map, cell + Vector2i.LEFT)
			var solid_right: bool = is_solid(logical_map, cell + Vector2i.RIGHT)
			if not solid_left and not solid_right and (not solid_up or not solid_down):
				next_row[grid_x] = CELL_EMPTY
			elif not solid_up and not solid_down and (not solid_left or not solid_right):
				next_row[grid_x] = CELL_EMPTY
		next_cells[grid_y] = next_row
	logical_map["cells"] = next_cells


static func _fill_diagonal_support_gaps(logical_map: Dictionary) -> void:
	var size: Vector2i = logical_map.get("size", Vector2i.ZERO) as Vector2i
	var current_cells: Array = logical_map.get("cells", []) as Array
	var next_cells: Array = _copy_grid(current_cells, size)
	for grid_y: int in range(size.y):
		var next_row: PackedByteArray = next_cells[grid_y] as PackedByteArray
		for grid_x: int in range(size.x):
			var cell: Vector2i = Vector2i(grid_x, grid_y)
			if is_solid(logical_map, cell):
				continue
			var solid_left: bool = is_solid(logical_map, cell + Vector2i.LEFT)
			var solid_right: bool = is_solid(logical_map, cell + Vector2i.RIGHT)
			var solid_up: bool = is_solid(logical_map, cell + Vector2i.UP)
			var solid_down: bool = is_solid(logical_map, cell + Vector2i.DOWN)
			if (solid_left and solid_right and solid_down) or (solid_up and solid_left and solid_right):
				next_row[grid_x] = CELL_SOLID
		next_cells[grid_y] = next_row
	logical_map["cells"] = next_cells


static func _copy_grid(source_grid: Array, size: Vector2i) -> Array:
	var copied_grid: Array = []
	for grid_y: int in range(size.y):
		var row := PackedByteArray()
		row.resize(size.x)
		for grid_x: int in range(size.x):
			row[grid_x] = CELL_EMPTY
		if grid_y < source_grid.size():
			var source_row: PackedByteArray = source_grid[grid_y] as PackedByteArray
			for grid_x: int in range(mini(size.x, source_row.size())):
				row[grid_x] = source_row[grid_x]
		copied_grid.append(row)
	return copied_grid
