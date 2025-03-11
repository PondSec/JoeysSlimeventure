extends CanvasLayer

@onready var preview_sprite = $Control/Sprite2D  # Vorschau Sprite
@onready var player = $"../PlayerModel"  # Der Spieler in der Hauptszene

# Eine Liste der Skins (Pfad zu den Texturen oder Animationen)
var skins = {
	"Slime": preload("res://Assets/slime-sprite.png"),
	"Skeleton": preload("res://Assets/Enemy/skeleton.png"),
}

func change_skin(skin_name: String):
	if skin_name in skins:
		preview_sprite.texture = skins[skin_name]  # Vorschau aktualisieren
		player.set_texture(skins[skin_name])  # Spieler Skin ändern (je nach Spieler-Setup evtl. andere Methode)

func _on_slime_pressed() -> void:
	change_skin("Slime")



func _on_skeleton_pressed() -> void:
	change_skin("Skeleton")
