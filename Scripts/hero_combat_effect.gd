extends Node2D

class_name HeroCombatEffect

const SLASH_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 1A-5.png"
const AIR_JUMP_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 1A-8.png"
const HIT_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 2A-3.png"
const LANDING_BURST_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 2A-1.png"
const WALL_KICK_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 3A-5.png"
const SLIDE_SMOKE_SHEET := "res://Assets/SmokeFXLite/SmokeFX Lite SpriteSheet 4A-1.png"

var kind := "hit"
var facing_left := false
var accent := Color(0.9, 0.95, 1.0, 1.0)
var intensity := 1.0
var elapsed := 0.0
var duration := 0.22
var effect_rotation := 0.0
var texture_cache: Dictionary = {}
var sheet_meta_cache: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(effect_kind: String, face_left: bool, effect_color: Color, effect_intensity: float = 1.0, rotation_radians: float = 0.0) -> void:
	kind = effect_kind
	facing_left = face_left
	accent = effect_color
	intensity = maxf(effect_intensity, 0.1)
	effect_rotation = rotation_radians
	match kind:
		"landing":
			duration = 0.34
		"slide":
			duration = 0.4
		"wall_jump":
			duration = 0.28
		"air_jump":
			duration = 0.26
		"slash":
			duration = 0.24
		_:
			duration = 0.2
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	match kind:
		"landing":
			_draw_landing(t)
		"slide":
			_draw_slide(t)
		"wall_jump":
			_draw_wall_jump(t)
		"air_jump":
			_draw_air_jump(t)
		"slash":
			_draw_slash(t)
		_:
			_draw_hit(t)


func _draw_hit(t: float) -> void:
	if _draw_sheet_frame(HIT_SHEET, t, Vector2.ZERO, 0.98 * intensity, _fade(Color(1.0, 1.0, 1.0, 1.0), 0.92 - t * 0.24), 0.0, false):
		return

	var alpha := (1.0 - t) * 0.72
	var sign := -1.0 if facing_left else 1.0
	var core := accent
	core.a = alpha
	var hot := Color(1.0, 1.0, 0.82, alpha * 0.92)
	var radius := lerpf(4.0, 14.0, t) * intensity
	var burst_points := [
		Vector2(sign * radius, -2.0),
		Vector2(sign * radius * 0.45, -radius * 0.72),
		Vector2(-sign * radius * 0.24, -radius * 0.48),
		Vector2(-sign * radius * 0.36, radius * 0.28),
		Vector2(sign * radius * 0.52, radius * 0.62),
	]

	_draw_diamond(Vector2.ZERO, 4.4 * intensity * (1.0 - t * 0.35), hot)
	for i in range(burst_points.size()):
		var p: Vector2 = burst_points[i]
		var size := maxf(1.5, (3.6 - float(i) * 0.34) * (1.0 - t * 0.55)) * intensity
		_draw_pixel_rect(p, Vector2(size * 1.25, size), 0.35 * sign * (float(i) - 2.0), core if i % 2 == 0 else hot)


func _draw_slash(t: float) -> void:
	var sign := -1.0 if facing_left else 1.0
	if _draw_sheet_frame(SLASH_SHEET, t, Vector2(sign * 8.0, -1.0), 1.34 * intensity, _fade(Color(0.96, 1.0, 1.0, 1.0), 0.98 - t * 0.18), effect_rotation, facing_left):
		_draw_diamond(Vector2(sign * 26.0, -12.0) + Vector2(sign * t * 8.0, -t * 3.0), 2.2 * intensity * (1.0 - t * 0.34), _fade(Color(1.0, 1.0, 0.82, 1.0), 0.62 - t * 0.22))
		_draw_diamond(Vector2(sign * 15.0, 8.0) + Vector2(sign * t * 5.0, t * 2.0), 1.7 * intensity * (1.0 - t * 0.28), _fade(Color(0.7, 0.98, 1.0, 1.0), 0.56 - t * 0.18))
		return

	var alpha := (1.0 - t) * 0.68
	var color := Color(0.76, 0.96, 1.0, alpha)
	var edge := Color(1.0, 1.0, 0.84, alpha * 0.72)
	var shadow := Color(0.32, 0.62, 0.7, alpha * 0.35)
	var center := Vector2(sign * 3.0, 4.0)
	var visible_segments := clampi(ceili(8.0 * (0.38 + t * 0.8)), 3, 8)

	for i in range(visible_segments):
		var u := float(i) / 7.0
		var angle := lerpf(-0.92, 0.55, u) * sign
		var radius := lerpf(12.0, 31.0, u) * intensity
		var arc_pos := center + Vector2(cos(angle) * radius * sign, sin(angle) * radius - 4.0)
		var width := lerpf(5.6, 2.8, u) * intensity * (1.0 - t * 0.28)
		var height := lerpf(3.4, 1.8, u) * intensity * (1.0 - t * 0.32)
		var segment_color := edge if i == visible_segments - 1 else color
		_draw_pixel_rect(arc_pos + Vector2(-sign * 2.0, 2.0), Vector2(width * 0.82, height), angle * 0.82, shadow)
		_draw_pixel_rect(arc_pos, Vector2(width, height), angle * 0.82, segment_color)

	for i in range(3):
		var chip_t := float(i) / 2.0
		var chip_pos := Vector2(sign * lerpf(12.0, 28.0, chip_t), lerpf(10.0, -9.0, chip_t)) + Vector2(sign * t * 5.0, -t * 3.0)
		_draw_diamond(chip_pos, (2.1 - chip_t * 0.5) * intensity * (1.0 - t * 0.45), edge)


func _draw_slide(t: float) -> void:
	var sign := -1.0 if facing_left else 1.0
	if _draw_sheet_frame(SLIDE_SMOKE_SHEET, t, Vector2(-sign * 18.0, 0.0), 0.98 * intensity, _fade(Color(0.78, 0.96, 0.88, 1.0), 0.82 - t * 0.18), effect_rotation, not facing_left, "bottom"):
		_draw_diamond(Vector2(-sign * 8.0, -3.0), 2.1 * intensity * (1.0 - t * 0.24), _fade(Color(0.9, 1.0, 0.76, 1.0), 0.48 - t * 0.16))
		return

	var alpha := (1.0 - t) * 0.7
	var dust := Color(0.76, 0.92, 0.86, alpha)
	var spark := Color(0.68, 1.0, 0.88, alpha)
	for i in range(7):
		var back := float(i) * 15.0 + t * 46.0
		var pos := Vector2(-sign * back, 18.0 + sin(float(i)) * 5.0)
		var size := lerpf(8.0, 2.0, t) * (1.0 - float(i) * 0.045) * intensity
		draw_rect(Rect2(pos - Vector2.ONE * size * 0.5, Vector2(size, maxf(size * 0.55, 1.0))), dust, true)
	for i in range(3):
		var start := Vector2(-sign * (18.0 + i * 26.0), 10.0 + i * 4.0)
		_draw_pixel_rect(start + Vector2(-sign * t * 12.0, -t * 4.0), Vector2(8.0 - i * 1.5, 2.0), -0.25 * sign, spark)


func _draw_air_jump(t: float) -> void:
	var sign := -1.0 if facing_left else 1.0
	var air_color := _fade(Color(0.78, 1.0, 0.9, 1.0), 0.9 - t * 0.2)
	var left_drawn := _draw_sheet_frame(AIR_JUMP_SHEET, t, Vector2(-10.0, 8.0), 1.08 * intensity, air_color, -0.1, false)
	var right_drawn := _draw_sheet_frame(AIR_JUMP_SHEET, t, Vector2(10.0, 8.0), 1.08 * intensity, air_color, 0.1, true)
	if left_drawn or right_drawn:
		_draw_diamond(Vector2(sign * 2.0, 3.0) + Vector2(sign * t * 4.0, -t * 7.0), 2.0 * intensity * (1.0 - t * 0.28), _fade(Color(1.0, 0.98, 0.82, 1.0), 0.56 - t * 0.18))
		_draw_diamond(Vector2(-sign * 6.0, 10.0) + Vector2(-sign * t * 3.0, t * 2.0), 1.5 * intensity * (1.0 - t * 0.22), _fade(Color(0.74, 0.98, 1.0, 1.0), 0.44 - t * 0.16))
		return

	var alpha := (1.0 - t) * 0.72
	for i in range(4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector2(side * (8.0 + float(i) * 2.6), 8.0 + float(i) * 1.6) + Vector2(side * t * 4.0, -t * 10.0)
		_draw_diamond(pos, (2.2 - float(i) * 0.22) * intensity * (1.0 - t * 0.28), Color(0.78, 1.0, 0.9, alpha))


func _draw_landing(t: float) -> void:
	var dust_color := _fade(Color(0.82, 0.98, 0.9, 1.0), 0.84 - t * 0.18)
	var left_drawn := _draw_sheet_frame(SLIDE_SMOKE_SHEET, t, Vector2(-18.0, 0.0), 0.94 * intensity, dust_color, 0.0, false, "bottom")
	var right_drawn := _draw_sheet_frame(SLIDE_SMOKE_SHEET, t, Vector2(18.0, 0.0), 0.94 * intensity, dust_color, 0.0, true, "bottom")
	var burst_drawn := _draw_sheet_frame(LANDING_BURST_SHEET, t, Vector2.ZERO, 0.96 * intensity, _fade(Color(1.0, 0.96, 0.82, 1.0), 0.76 - t * 0.18), 0.0, false, "bottom")
	if left_drawn or right_drawn or burst_drawn:
		_draw_diamond(Vector2(0.0, -10.0 - t * 5.0), 2.4 * intensity * (1.0 - t * 0.24), _fade(Color(1.0, 0.96, 0.82, 1.0), 0.44 - t * 0.14))
		return

	var alpha := (1.0 - t) * 0.78
	for i in range(6):
		var side := -1.0 if i < 3 else 1.0
		var spread := 8.0 + float(i % 3) * 8.0
		var pos := Vector2(side * spread, -2.0 + float(i % 3) * 2.0) + Vector2(side * t * 10.0, -t * 6.0)
		_draw_pixel_rect(pos, Vector2(5.0 - float(i % 3), 2.4), side * 0.12, Color(0.82, 0.98, 0.9, alpha))


func _draw_wall_jump(t: float) -> void:
	var sign := -1.0 if facing_left else 1.0
	if _draw_sheet_frame(WALL_KICK_SHEET, t, Vector2(sign * 4.0, 0.0), 1.04 * intensity, _fade(Color(0.92, 1.0, 0.9, 1.0), 0.9 - t * 0.22), effect_rotation, facing_left):
		return

	var alpha := (1.0 - t) * 0.66
	var color := Color(0.72, 1.0, 0.94, alpha)
	var hot := Color(1.0, 1.0, 0.78, alpha * 0.82)
	var dust := Color(0.64, 0.86, 0.78, alpha * 0.62)
	var wall_x := sign * 6.0

	for i in range(5):
		var u := float(i) / 4.0
		var pos := Vector2(wall_x + sign * lerpf(3.0, 13.0, t + u * 0.2), lerpf(-11.0, 11.0, u) - t * 6.0)
		var size := lerpf(3.5, 1.6, u) * (1.0 - t * 0.42) * intensity
		_draw_diamond(pos, size, color if i % 2 == 0 else dust)

	for i in range(3):
		var pos := Vector2(wall_x - sign * 1.5, -7.0 + i * 7.0)
		_draw_pixel_rect(pos, Vector2(3.0, 5.0 - i * 0.5), 0.0, hot if i == 1 else dust)


func _draw_sheet_frame(path: String, t: float, center: Vector2, draw_scale: float, modulate: Color, rotation: float = 0.0, flip_h: bool = false, anchor_mode: String = "center") -> bool:
	var meta := _get_sheet_meta(path)
	var texture := meta.get("texture") as Texture2D
	if texture == null:
		return false

	var visible_frames: Array = meta.get("visible_frames", [])
	var frame_bboxes: Array = meta.get("frame_bboxes", [])
	if visible_frames.is_empty() or frame_bboxes.is_empty():
		return false

	var frame_t := _smoothstep01(t)
	var visible_index := clampi(int(floor(frame_t * float(visible_frames.size()))), 0, visible_frames.size() - 1)
	var frame_index := int(visible_frames[visible_index])
	var frame_width := int(meta.get("frame_width", 64))
	var bbox: Rect2i = frame_bboxes[frame_index]
	if bbox.size.x <= 0 or bbox.size.y <= 0:
		return false

	var src_rect := Rect2(
		float(frame_index * frame_width + bbox.position.x),
		float(bbox.position.y),
		float(bbox.size.x),
		float(bbox.size.y)
	)
	var size := Vector2(float(bbox.size.x), float(bbox.size.y)) * draw_scale
	var draw_origin := -size * 0.5
	if anchor_mode == "bottom":
		draw_origin = Vector2(-size.x * 0.5, -size.y)

	draw_set_transform(center, rotation, Vector2(-1.0 if flip_h else 1.0, 1.0))
	draw_texture_rect_region(
		texture,
		Rect2(draw_origin, size),
		src_rect,
		modulate
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


func _get_sheet_meta(path: String) -> Dictionary:
	if sheet_meta_cache.has(path):
		return sheet_meta_cache[path] as Dictionary

	var texture := _get_texture(path)
	var meta := {
		"texture": texture,
		"frame_width": 64,
		"frame_bboxes": [],
		"visible_frames": [],
	}
	if texture == null:
		sheet_meta_cache[path] = meta
		return meta

	var image := texture.get_image()
	if image == null:
		sheet_meta_cache[path] = meta
		return meta
	if image.is_compressed():
		image.decompress()

	var frame_width := 64
	var frame_height := image.get_height()
	var frame_count := maxi(int(image.get_width() / frame_width), 1)
	var bboxes: Array[Rect2i] = []
	var visible_frames: Array[int] = []
	for frame_index in range(frame_count):
		var bbox := _find_alpha_bounds(image, frame_index * frame_width, frame_width, frame_height)
		bboxes.append(bbox)
		if bbox.size.x > 0 and bbox.size.y > 0:
			visible_frames.append(frame_index)

	meta["frame_bboxes"] = bboxes
	meta["visible_frames"] = visible_frames
	sheet_meta_cache[path] = meta
	return meta


func _find_alpha_bounds(image: Image, frame_x: int, frame_width: int, frame_height: int) -> Rect2i:
	var min_x := frame_width
	var min_y := frame_height
	var max_x := -1
	var max_y := -1
	for y in range(frame_height):
		for x in range(frame_width):
			if image.get_pixel(frame_x + x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _get_texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path] as Texture2D

	var texture := load(path) as Texture2D
	texture_cache[path] = texture
	return texture


func _smoothstep01(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _fade(color: Color, alpha: float) -> Color:
	color.a = clampf(alpha, 0.0, 1.0)
	return color


func _draw_pixel_rect(center: Vector2, size: Vector2, rotation: float, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var points := PackedVector2Array([
		Vector2(-hx, -hy).rotated(rotation) + center,
		Vector2(hx, -hy).rotated(rotation) + center,
		Vector2(hx, hy).rotated(rotation) + center,
		Vector2(-hx, hy).rotated(rotation) + center,
	])
	draw_colored_polygon(points, color)


func _draw_diamond(center: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -size),
		center + Vector2(size, 0.0),
		center + Vector2(0.0, size),
		center + Vector2(-size, 0.0),
	])
	draw_colored_polygon(points, color)
