class_name TileClassifier
extends RefCounted

const TerrainResolver := preload("res://Scripts/Chapter/terrain_resolver.gd")

const TILE_TOP_LEFT := Vector2i(0, 0)
const TILE_TOP := Vector2i(1, 0)
const TILE_TOP_RIGHT := Vector2i(2, 0)
const TILE_LEFT := Vector2i(0, 1)
const TILE_CENTER := Vector2i(1, 1)
const TILE_RIGHT := Vector2i(2, 1)
const TILE_BOTTOM_LEFT := Vector2i(0, 2)
const TILE_BOTTOM := Vector2i(1, 2)
const TILE_BOTTOM_RIGHT := Vector2i(2, 2)
const TILE_GENERATED_CORNER := Vector2i(7, 0)

# TileMap transformations are encoded in the alternative tile value.
const TRANSFORM_FLIP_H := 1 << 12
const TRANSFORM_FLIP_V := 1 << 13
const TRANSFORM_TRANSPOSE := 1 << 14
const TRANSFORM_ROTATE_CW := TRANSFORM_TRANSPOSE | TRANSFORM_FLIP_H
const TRANSFORM_ROTATE_CCW := TRANSFORM_TRANSPOSE | TRANSFORM_FLIP_V
const TRANSFORM_ROTATE_180 := TRANSFORM_FLIP_H | TRANSFORM_FLIP_V
const MASK_N := 1
const MASK_NE := 2
const MASK_E := 4
const MASK_SE := 8
const MASK_S := 16
const MASK_SW := 32
const MASK_W := 64
const MASK_NW := 128

const TILE_LOOKUP := {
	"isolated": TILE_CENTER,
	"center": TILE_CENTER,
	"floor_top": TILE_TOP,
	"ceiling_bottom": TILE_BOTTOM,
	"left_wall": TILE_LEFT,
	"right_wall": TILE_RIGHT,
	# Outer corners retain the original authored edge tiles.
	"outer_corner_top_left": TILE_TOP_LEFT,
	"outer_corner_top_right": TILE_TOP_RIGHT,
	"outer_corner_bottom_left": TILE_BOTTOM_LEFT,
	"outer_corner_bottom_right": TILE_BOTTOM_RIGHT,
	# Only concave corners originate from the single authored (7, 0) tile.
	# The appropriate orientation is supplied in TILE_ALTERNATIVE_LOOKUP.
	"inner_corner_top_left": TILE_GENERATED_CORNER,
	"inner_corner_top_right": TILE_GENERATED_CORNER,
	"inner_corner_bottom_left": TILE_GENERATED_CORNER,
	"inner_corner_bottom_right": TILE_GENERATED_CORNER,
	"ledge_end_left": TILE_TOP_LEFT,
	"ledge_end_right": TILE_TOP_RIGHT,
	"ceiling_end_left": TILE_BOTTOM_LEFT,
	"ceiling_end_right": TILE_BOTTOM_RIGHT,
	"pillar_cap": TILE_TOP,
	"pillar_body": TILE_CENTER,
	"pillar_base": TILE_BOTTOM,
	"thin_support": TILE_CENTER
}

const TILE_ALTERNATIVE_LOOKUP := {
	# (7, 0) is the canonical upper-left inner corner. Rotate it into the
	# three other concave directions, keeping every transition pixel-aligned.
	"inner_corner_top_right": TRANSFORM_ROTATE_CW,
	"inner_corner_bottom_left": TRANSFORM_ROTATE_CCW,
	"inner_corner_bottom_right": TRANSFORM_ROTATE_180,
}

const DEBUG_COLORS := {
	"isolated": Color(1.0, 0.22, 0.42, 0.54),
	"center": Color(0.24, 0.44, 0.88, 0.22),
	"floor_top": Color(0.24, 0.92, 0.58, 0.34),
	"ceiling_bottom": Color(0.92, 0.72, 0.24, 0.34),
	"left_wall": Color(0.38, 0.72, 1.0, 0.34),
	"right_wall": Color(0.56, 0.72, 1.0, 0.34),
	"outer_corner_top_left": Color(0.2, 1.0, 0.78, 0.48),
	"outer_corner_top_right": Color(0.2, 1.0, 0.78, 0.48),
	"outer_corner_bottom_left": Color(1.0, 0.58, 0.26, 0.48),
	"outer_corner_bottom_right": Color(1.0, 0.58, 0.26, 0.48),
	"inner_corner_top_left": Color(0.78, 0.48, 1.0, 0.4),
	"inner_corner_top_right": Color(0.78, 0.48, 1.0, 0.4),
	"inner_corner_bottom_left": Color(0.78, 0.48, 1.0, 0.4),
	"inner_corner_bottom_right": Color(0.78, 0.48, 1.0, 0.4),
	"ledge_end_left": Color(0.24, 1.0, 0.72, 0.52),
	"ledge_end_right": Color(0.24, 1.0, 0.72, 0.52),
	"ceiling_end_left": Color(1.0, 0.76, 0.28, 0.52),
	"ceiling_end_right": Color(1.0, 0.76, 0.28, 0.52),
	"pillar_cap": Color(0.24, 0.94, 0.48, 0.46),
	"pillar_body": Color(0.26, 0.58, 0.94, 0.28),
	"pillar_base": Color(0.98, 0.62, 0.34, 0.46),
	"thin_support": Color(1.0, 0.32, 0.84, 0.46)
}


static func resolve_solid_cell(logical_map: Dictionary, cell: Vector2i) -> Dictionary:
	var neighbor_info: Dictionary = _neighbor_info(logical_map, cell)
	var classification: String = classify_solid_cell(logical_map, cell, neighbor_info)
	var atlas_coords: Vector2i = TILE_LOOKUP.get(classification, TILE_CENTER) as Vector2i
	return {
		"atlas_coords": atlas_coords,
		"alternative": int(TILE_ALTERNATIVE_LOOKUP.get(classification, 0)),
		"classification": classification,
		"mask": int(neighbor_info.get("mask", 0))
	}


static func classify_solid_cell(logical_map: Dictionary, cell: Vector2i, neighbor_info: Dictionary = {}) -> String:
	var info: Dictionary = neighbor_info
	if info.is_empty():
		info = _neighbor_info(logical_map, cell)

	var solid_up: bool = bool(info.get("up", false))
	var solid_right: bool = bool(info.get("right", false))
	var solid_down: bool = bool(info.get("down", false))
	var solid_left: bool = bool(info.get("left", false))
	var solid_up_right: bool = bool(info.get("up_right", false))
	var solid_down_right: bool = bool(info.get("down_right", false))
	var solid_down_left: bool = bool(info.get("down_left", false))
	var solid_up_left: bool = bool(info.get("up_left", false))

	if not solid_up and not solid_right and not solid_down and not solid_left:
		return "isolated"

	if solid_up and solid_right and solid_down and solid_left:
		if not solid_up_left:
			return "inner_corner_top_left"
		if not solid_up_right:
			return "inner_corner_top_right"
		if not solid_down_left:
			return "inner_corner_bottom_left"
		if not solid_down_right:
			return "inner_corner_bottom_right"
		return "center"

	if not solid_up:
		if not solid_left and solid_right and solid_down:
			return "outer_corner_top_left"
		if not solid_right and solid_left and solid_down:
			return "outer_corner_top_right"
		if not solid_left and not solid_right and solid_down:
			return "pillar_cap"
		if not solid_left:
			return "ledge_end_left"
		if not solid_right:
			return "ledge_end_right"
		return "floor_top"

	if not solid_down:
		if not solid_left and solid_right and solid_up:
			return "outer_corner_bottom_left"
		if not solid_right and solid_left and solid_up:
			return "outer_corner_bottom_right"
		if not solid_left and not solid_right and solid_up:
			return "pillar_base"
		if not solid_left:
			return "ceiling_end_left"
		if not solid_right:
			return "ceiling_end_right"
		return "ceiling_bottom"

	if not solid_left and not solid_right:
		if solid_up and solid_down:
			return "thin_support"
		return "pillar_body"

	if not solid_left:
		return "left_wall"

	if not solid_right:
		return "right_wall"

	return "center"


static func debug_color(classification: String) -> Color:
	return DEBUG_COLORS.get(classification, Color(1.0, 1.0, 1.0, 0.2)) as Color


static func _neighbor_info(logical_map: Dictionary, cell: Vector2i) -> Dictionary:
	var up: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i.UP)
	var up_right: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i(1, -1))
	var right: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i.RIGHT)
	var down_right: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i(1, 1))
	var down: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i.DOWN)
	var down_left: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i(-1, 1))
	var left: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i.LEFT)
	var up_left: bool = TerrainResolver.is_solid(logical_map, cell + Vector2i(-1, -1))

	var mask: int = 0
	if up:
		mask |= MASK_N
	if up_right:
		mask |= MASK_NE
	if right:
		mask |= MASK_E
	if down_right:
		mask |= MASK_SE
	if down:
		mask |= MASK_S
	if down_left:
		mask |= MASK_SW
	if left:
		mask |= MASK_W
	if up_left:
		mask |= MASK_NW

	return {
		"up": up,
		"up_right": up_right,
		"right": right,
		"down_right": down_right,
		"down": down,
		"down_left": down_left,
		"left": left,
		"up_left": up_left,
		"mask": mask
	}
