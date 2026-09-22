extends Control

const PLAYER_TEXTURE := preload("res://Assets/slime-sprite2.png")
const CROWNED_PLAYER_TEXTURE := preload("res://Assets/slime_early_supporter_crown.png")
const HERO_IDLE_TEXTURE := preload("res://Assets/player/hero/individual_sheets/male_hero-idle.png")
const CROWNED_HERO_IDLE_TEXTURE := preload("res://Assets/player/hero/early_supporter_crown_sheets/male_hero-idle.png")
const CROWN_ICON := preload("res://Assets/Cosmetics/early_supporter_crown.png")
const SLIME_FRAME_SIZE := Vector2i(512, 512)
const HERO_FRAME_SIZE := Vector2i(128, 128)
# The Deluxe idle sheet has a 16×32 opaque character inside each 128px cell.
# Previewing the full transparent cell made the hero appear miniature.
const HERO_IDLE_CONTENT_RECT := Rect2(50.0, 46.0, 16.0, 32.0)
# The crown extends naturally above the normal head bounds. This wider crop
# keeps the full cosmetic visible while making the Hero preview less oversized.
const CROWNED_HERO_IDLE_CONTENT_RECT := Rect2(40.0, 24.0, 48.0, 64.0)
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
var crown_equipped := false
var crown_button: TextureButton
var crown_disabled_mark: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_crown_toggle()
	if not SteamEntitlements.entitlement_refreshed.is_connected(_refresh_crown_toggle):
		SteamEntitlements.entitlement_refreshed.connect(_refresh_crown_toggle)
	if not SteamEntitlements.early_supporter_crown_equipped_changed.is_connected(_refresh_crown_toggle):
		SteamEntitlements.early_supporter_crown_equipped_changed.connect(_refresh_crown_toggle)
	_refresh_crown_toggle()
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
	body.position = Vector2(46.0, 15.0) if is_hero_preview else Vector2(38.0, 20.0)
	weapon.position = Vector2(98.0, 88.0)
	weapon.rotation = deg_to_rad(16.0)
	shadow.modulate.a = 0.42


func set_hero_form_active(active: bool) -> void:
	if is_hero_preview == active and current_frame >= 0:
		return
	is_hero_preview = active
	animation_time = 0.0
	current_frame = -1
	body.size = Vector2(88.0, 112.0) if is_hero_preview else Vector2(92.0, 92.0)
	body.position = Vector2(46.0, 15.0) if is_hero_preview else Vector2(38.0, 20.0)
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
	atlas.atlas = CROWNED_PLAYER_TEXTURE if crown_equipped else PLAYER_TEXTURE
	atlas.region = Rect2(float(frame_index * SLIME_FRAME_SIZE.x), 0.0, float(SLIME_FRAME_SIZE.x), float(SLIME_FRAME_SIZE.y))
	return atlas


func _make_hero_idle_frame(frame_index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	if crown_equipped:
		# Exported directly from the Hero's Aseprite idle tag. Its frame layout is
		# identical to the ordinary individual sheet, so no packed-sheet offsets
		# can affect the preview.
		atlas.atlas = CROWNED_HERO_IDLE_TEXTURE
		atlas.region = Rect2(
			float(frame_index * HERO_FRAME_SIZE.x) + CROWNED_HERO_IDLE_CONTENT_RECT.position.x,
			CROWNED_HERO_IDLE_CONTENT_RECT.position.y,
			CROWNED_HERO_IDLE_CONTENT_RECT.size.x,
			CROWNED_HERO_IDLE_CONTENT_RECT.size.y
		)
	else:
		atlas.atlas = HERO_IDLE_TEXTURE
		atlas.region = Rect2(
			float(frame_index * HERO_FRAME_SIZE.x) + HERO_IDLE_CONTENT_RECT.position.x,
			HERO_IDLE_CONTENT_RECT.position.y,
			HERO_IDLE_CONTENT_RECT.size.x,
			HERO_IDLE_CONTENT_RECT.size.y
		)
	return atlas


func _build_crown_toggle() -> void:
	crown_button = TextureButton.new()
	crown_button.name = "EarlySupporterCrownToggle"
	crown_button.position = Vector2(130.0, 4.0)
	crown_button.size = Vector2(42.0, 42.0)
	crown_button.ignore_texture_size = true
	crown_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	crown_button.texture_normal = CROWN_ICON
	crown_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown_button.tooltip_text = "Early Supporter Crown ein-/ausblenden"
	crown_button.pressed.connect(_toggle_crown)
	add_child(crown_button)

	crown_disabled_mark = Control.new()
	crown_disabled_mark.name = "DisabledMark"
	crown_disabled_mark.position = crown_button.position
	crown_disabled_mark.size = crown_button.size
	crown_disabled_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slash := ColorRect.new()
	slash.color = Color("e54848")
	slash.position = Vector2(-4.0, 19.0)
	slash.size = Vector2(50.0, 4.0)
	slash.pivot_offset = slash.size * 0.5
	slash.rotation = deg_to_rad(-45.0)
	crown_disabled_mark.add_child(slash)
	add_child(crown_disabled_mark)


func _toggle_crown() -> void:
	if not SteamEntitlements.has_early_supporter_crown():
		return
	SteamEntitlements.set_early_supporter_crown_equipped(not SteamEntitlements.is_early_supporter_crown_equipped())


func _refresh_crown_toggle(_unused: bool = false) -> void:
	var can_use_crown := SteamEntitlements.has_early_supporter_crown()
	var should_wear := SteamEntitlements.is_early_supporter_crown_equipped()
	if crown_button != null:
		crown_button.visible = can_use_crown
	if crown_disabled_mark != null:
		crown_disabled_mark.visible = can_use_crown and not should_wear
	if crown_equipped == should_wear:
		return
	crown_equipped = should_wear
	slime_body_frames.clear()
	hero_body_frames.clear()
	for frame in range(4):
		slime_body_frames.append(_make_slime_frame(frame))
	for frame in range(10):
		hero_body_frames.append(_make_hero_idle_frame(frame))
	current_frame = -1
	_update_frame(0)
