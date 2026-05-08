extends Node2D

class_name HeroTransformEffect

const HERO_COLOR := Color(0.98, 0.34, 0.83, 1.0)
const SLIME_COLOR := Color(0.45, 1.0, 0.54, 1.0)
const CORE_COLOR := Color(0.93, 1.0, 0.72, 1.0)

var duration := 0.72
var elapsed := 0.0
var to_hero := true
var body_height := 128.0


func configure(should_be_hero: bool, height: float = 128.0) -> void:
	to_hero = should_be_hero
	body_height = height
	elapsed = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var pulse := sin(t * PI)
	var primary := HERO_COLOR if to_hero else SLIME_COLOR
	var secondary := SLIME_COLOR if to_hero else HERO_COLOR
	var center := Vector2(0.0, -body_height * 0.47)

	_draw_scan_gate(center, pulse, primary, secondary)
	_draw_pixel_ring(center, lerpf(18.0, body_height * 0.62, t), primary, 4.0, 0.95 - t * 0.5)
	_draw_pixel_ring(center, lerpf(body_height * 0.48, 22.0, t), secondary, 3.0, 0.35 + pulse * 0.45)
	_draw_controlled_sparks(center, t, primary, secondary)
	_draw_core_flash(center, pulse, primary)


func _draw_scan_gate(center: Vector2, pulse: float, primary: Color, secondary: Color) -> void:
	var gate_height := body_height * lerpf(0.45, 1.18, pulse)
	var gate_width := body_height * 0.92
	var bar_width := 6.0
	for index in range(4):
		var side := -1.0 if index < 2 else 1.0
		var inset := float(index % 2) * 10.0
		var x := center.x + side * (gate_width * 0.5 - inset)
		var alpha := 0.16 + pulse * (0.24 - float(index % 2) * 0.05)
		var color := primary if index % 2 == 0 else secondary
		color.a = alpha
		draw_rect(Rect2(Vector2(x - bar_width * 0.5, center.y - gate_height * 0.5), Vector2(bar_width, gate_height)), color, true)


func _draw_pixel_ring(center: Vector2, radius: float, color: Color, width: float, alpha: float) -> void:
	var c := color
	c.a = clampf(alpha, 0.0, 1.0)
	var half_w := width * 0.5
	var top := center + Vector2(0.0, -radius)
	var right := center + Vector2(radius * 0.82, 0.0)
	var bottom := center + Vector2(0.0, radius)
	var left := center + Vector2(-radius * 0.82, 0.0)
	draw_line(top, right, c, width)
	draw_line(right, bottom, c, width)
	draw_line(bottom, left, c, width)
	draw_line(left, top, c, width)
	for point in [top, right, bottom, left]:
		draw_rect(Rect2(point - Vector2(half_w + 1.0, half_w + 1.0), Vector2(width + 2.0, width + 2.0)), c, true)


func _draw_controlled_sparks(center: Vector2, t: float, primary: Color, secondary: Color) -> void:
	var pulse := sin(t * PI)
	var count := 10
	for index in range(count):
		var phase := (float(index) / float(count)) * TAU + t * TAU * 0.35
		var radius := body_height * (0.22 + 0.34 * pulse) + float(index % 3) * 7.0
		var pos := center + Vector2(cos(phase) * radius * 0.75, sin(phase) * radius)
		var size := 3.0 + float(index % 2) * 2.0
		var color := primary if index % 2 == 0 else secondary
		color.a = 0.34 + pulse * 0.36
		draw_rect(Rect2(pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), color, true)


func _draw_core_flash(center: Vector2, pulse: float, primary: Color) -> void:
	var color := CORE_COLOR.lerp(primary, 0.35)
	color.a = 0.24 + pulse * 0.52
	var size := Vector2(body_height * (0.12 + pulse * 0.18), body_height * (0.035 + pulse * 0.04))
	draw_rect(Rect2(center - size * 0.5, size), color, true)
	draw_rect(Rect2(center - Vector2(size.y * 0.5, size.x * 0.5), Vector2(size.y, size.x)), color, true)
