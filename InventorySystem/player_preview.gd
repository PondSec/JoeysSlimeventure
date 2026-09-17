extends Control

const PLAYER_TEXTURE := preload("res://Assets/slime-sprite2.png")
const HERO_IDLE_TEXTURE := preload("res://Assets/player/hero/individual_sheets/male_hero-idle.png")
const SLIME_FRAME_SIZE := Vector2i(512, 512)
const HERO_FRAME_SIZE := Vector2i(128, 128)
const ItemRegistry := preload("res://Scripts/item_registry.gd")

@onready var body: TextureRect = $Body
@onready var weapon: TextureRect = $Weapon
@onready var shadow: ColorRect = $Shadow
@onready var name_label: Label = $NameLabel
@onready var skill_label: Label = $SkillLabel

var slime_body_frames: Array[AtlasTexture] = []
var hero_body_frames: Array[AtlasTexture] = []
var animation_time := 0.0
var current_frame := -1
var current_weapon: InvItem = null
var is_hero_preview := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for frame in range(4):
		slime_body_frames.append(_make_slime_frame(frame))
	for frame in range(10):
		hero_body_frames.append(_make_hero_idle_frame(frame))
	set_hero_form_active(false)
	set_preview_item(ItemRegistry.get_default_weapon())


func _process(delta: float) -> void:
	animation_time += delta
	var frames := hero_body_frames if is_hero_preview else slime_body_frames
	var idle_fps := 9.0 if is_hero_preview else 5.0
	var next_frame: int = int(floor(animation_time * idle_fps)) % maxi(frames.size(), 1)
	if next_frame != current_frame:
		_update_frame(next_frame)

	# The preview is a character sheet, not a floating collectible: authored
	# idle frames animate it while its world position and weapon stay still.
	body.position = Vector2(26.0, 2.0) if is_hero_preview else Vector2(38.0, 20.0)
	weapon.position = Vector2(98.0, 88.0)
	weapon.rotation = deg_to_rad(16.0)
	shadow.modulate.a = 0.42


func set_hero_form_active(active: bool) -> void:
	if is_hero_preview == active and current_frame >= 0:
		return
	is_hero_preview = active
	animation_time = 0.0
	current_frame = -1
	body.size = Vector2(128.0, 128.0) if is_hero_preview else Vector2(92.0, 92.0)
	body.position = Vector2(26.0, 2.0) if is_hero_preview else Vector2(38.0, 20.0)
	weapon.visible = not is_hero_preview
	_update_frame(0)


func set_preview_item(item: InvItem) -> void:
	current_weapon = item if item != null else ItemRegistry.get_default_weapon()
	weapon.texture = current_weapon.texture if current_weapon else null
	_set_labels(current_weapon)


func _set_labels(item: InvItem) -> void:
	if item == null:
		name_label.text = "Keine Waffe"
		skill_label.text = ""
		return
	name_label.text = item.get_display_name()
	skill_label.text = item.skill_name if not item.skill_name.is_empty() else "Basisangriff"


func _update_frame(frame_index: int) -> void:
	var frames := hero_body_frames if is_hero_preview else slime_body_frames
	if frames.is_empty():
		return
	current_frame = frame_index
	body.texture = frames[frame_index % frames.size()]


func _make_slime_frame(frame_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = PLAYER_TEXTURE
	atlas.region = Rect2(float(frame_index * SLIME_FRAME_SIZE.x), 0.0, float(SLIME_FRAME_SIZE.x), float(SLIME_FRAME_SIZE.y))
	return atlas


func _make_hero_idle_frame(frame_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HERO_IDLE_TEXTURE
	atlas.region = Rect2(float(frame_index * HERO_FRAME_SIZE.x), 0.0, float(HERO_FRAME_SIZE.x), float(HERO_FRAME_SIZE.y))
	return atlas
