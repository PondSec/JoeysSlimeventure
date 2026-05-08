extends Control

const PLAYER_TEXTURE := preload("res://Assets/slime-sprite2.png")
const FRAME_SIZE := Vector2i(512, 512)
const ItemRegistry := preload("res://Scripts/item_registry.gd")

@onready var body: TextureRect = $Body
@onready var weapon: TextureRect = $Weapon
@onready var shadow: ColorRect = $Shadow
@onready var name_label: Label = $NameLabel
@onready var skill_label: Label = $SkillLabel

var body_frames: Array[AtlasTexture] = []
var animation_time := 0.0
var current_frame := -1
var current_weapon: InvItem = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for frame in range(4):
		body_frames.append(_make_player_frame(frame))
	_update_frame(0)
	set_preview_item(ItemRegistry.get_default_weapon())


func _process(delta: float) -> void:
	animation_time += delta
	var next_frame: int = int(floor(animation_time * 5.0)) % maxi(body_frames.size(), 1)
	if next_frame != current_frame:
		_update_frame(next_frame)

	var bob := sin(animation_time * 2.6) * 5.0
	body.position = Vector2(38.0, 20.0 + bob)
	weapon.position = Vector2(98.0, 88.0 + bob * 0.5)
	weapon.rotation = deg_to_rad(16.0 + sin(animation_time * 2.2) * 3.0)
	shadow.modulate.a = 0.42 + max(sin(animation_time * 1.6), 0.0) * 0.08


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
	current_frame = frame_index
	body.texture = body_frames[frame_index]


func _make_player_frame(frame_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = PLAYER_TEXTURE
	atlas.region = Rect2(float(frame_index * FRAME_SIZE.x), 0.0, float(FRAME_SIZE.x), float(FRAME_SIZE.y))
	return atlas
