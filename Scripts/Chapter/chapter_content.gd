class_name ChapterContent
extends RefCounted

const IMPLEMENTED_CHAPTERS := [1]


static func get_chapter_count() -> int:
	return 7


static func is_chapter_playable(chapter_index: int) -> bool:
	return IMPLEMENTED_CHAPTERS.has(chapter_index)


static func get_chapter_meta(chapter_index: int) -> Dictionary:
	match chapter_index:
		1:
			return {
				"title": "Die Tropfsteinhoehle",
				"short_title": "Tropfsteinhoehle",
				"door_suffix": "Kapitel I",
				"accent": Color(0.52, 0.84, 0.74, 1.0),
				"description": "Feuchte Hallen aus Kalkstein, kaltem Wasser und leuchtenden Kristallen."
			}
		2:
			return {
				"title": "Die Knochenkatakomben",
				"short_title": "Knochenkatakomben",
				"door_suffix": "Kapitel II",
				"accent": Color(0.92, 0.89, 0.78, 1.0),
				"description": "Ein versiegeltes Ossarium unter der Hoehle."
			}
		3:
			return {
				"title": "Der Pilzwald",
				"short_title": "Pilzwald",
				"door_suffix": "Kapitel III",
				"accent": Color(0.68, 0.96, 0.52, 1.0),
				"description": "Wuchernde Pilze und toxische Sporen warten tiefer unten."
			}
		4:
			return {
				"title": "Der Lava-Abgrund",
				"short_title": "Lava-Abgrund",
				"door_suffix": "Kapitel IV",
				"accent": Color(1.0, 0.55, 0.24, 1.0),
				"description": "Brodelnde Hitze hinter alten Basalttoren."
			}
		5:
			return {
				"title": "Die Faulniskluft",
				"short_title": "Faulniskluft",
				"door_suffix": "Kapitel V",
				"accent": Color(0.74, 0.84, 0.44, 1.0),
				"description": "Verdorbene Tiefen, in denen Morgraths Atem haengt."
			}
		6:
			return {
				"title": "Der Schwarzkristallkern",
				"short_title": "Schwarzkristallkern",
				"door_suffix": "Kapitel VI",
				"accent": Color(0.73, 0.67, 1.0, 1.0),
				"description": "Ein Herz aus dunklem Glas und stummer Magie."
			}
		7:
			return {
				"title": "Der Thronvorhof",
				"short_title": "Thronvorhof",
				"door_suffix": "Kapitel VII",
				"accent": Color(1.0, 0.28, 0.38, 1.0),
				"description": "Das letzte Tor vor Morgraths eigentlichem Sitz."
			}
		_:
			return {
				"title": "Unbekannt",
				"short_title": "Unbekannt",
				"door_suffix": "Kapitel ?",
				"accent": Color(0.82, 0.82, 0.82, 1.0),
				"description": ""
			}


static func get_level_count(chapter_index: int) -> int:
	if chapter_index == 1:
		return _chapter_one_levels().size()
	return 0


static func get_level_data(chapter_index: int, level_index: int) -> Dictionary:
	if chapter_index != 1:
		return {}

	var levels: Array = _chapter_one_levels()
	if level_index < 0 or level_index >= levels.size():
		return {}

	var base_level: Dictionary = levels[level_index]
	var level_copy: Dictionary = base_level.duplicate(true)
	level_copy["chapter_index"] = chapter_index
	level_copy["level_index"] = level_index
	level_copy["level_label"] = "Level %d / %d" % [level_index + 1, levels.size()]
	_normalize_chapter_one_level(level_copy)
	return level_copy


static func _platform(x: int, y: int, width: int, height: int = 1, style: String = "stone") -> Dictionary:
	return {
		"x": x,
		"y": y,
		"w": width,
		"h": height,
		"style": style
	}


static func _enemy(enemy_type: String, x: int, y: int, extras: Dictionary = {}) -> Dictionary:
	var definition: Dictionary = {
		"type": enemy_type,
		"x": x,
		"y": y
	}
	for key: Variant in extras.keys():
		definition[str(key)] = extras[key]
	return definition


static func _hazard(hazard_type: String, x: int, y: int, count: int = 1) -> Dictionary:
	return {
		"type": hazard_type,
		"x": x,
		"y": y,
		"count": count
	}


static func _torch(x: int, y: int, brightness: float = 1.0) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"brightness": brightness
	}


static func _crystal(x: int, y: int, scale: float = 1.0, tint: Color = Color(0.8, 0.95, 1.0, 1.0)) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"scale": scale,
		"tint": tint
	}


static func _pickup(pickup_id: String, x: int, y: int, message: String) -> Dictionary:
	return {
		"id": pickup_id,
		"x": x,
		"y": y,
		"message": message
	}


static func _trigger(trigger_id: String, x: int, y: int, width: int, height: int, message: String, toast_type: String = "info", banner: String = "") -> Dictionary:
	return {
		"id": trigger_id,
		"x": x,
		"y": y,
		"w": width,
		"h": height,
		"message": message,
		"toast_type": toast_type,
		"banner": banner
	}


static func _tutorial_trigger(trigger_id: String, x: int, y: int, width: int, height: int, title: String, body: String, controls: String, kicker: String = "TUTORIAL", banner: String = "", accent: Color = Color(0.62, 0.96, 1.0, 1.0), toast_type: String = "info") -> Dictionary:
	var trigger_data: Dictionary = _trigger(trigger_id, x, y, width, height, body, toast_type, banner)
	trigger_data["tutorial"] = {
		"kicker": kicker,
		"title": title,
		"body": body,
		"controls": controls,
		"accent": accent,
		"duration": 5.4
	}
	return trigger_data


static func _normalize_chapter_one_level(level_data: Dictionary) -> void:
	var enemies: Array = level_data.get("enemies", []) as Array
	var normalized_enemies: Array = []
	for enemy_variant: Variant in enemies:
		normalized_enemies.append((enemy_variant as Dictionary).duplicate(true))
	level_data["enemies"] = normalized_enemies

	var pickups: Array = level_data.get("pickups", []) as Array
	var normalized_pickups: Array = []
	for pickup_variant: Variant in pickups:
		normalized_pickups.append((pickup_variant as Dictionary).duplicate(true))

	var crystals: Array = level_data.get("crystals", []) as Array
	for crystal_index: int in range(crystals.size()):
		var crystal_data: Dictionary = crystals[crystal_index] as Dictionary
		normalized_pickups.append(
			_pickup(
				"c1_auto_fragment_%d_%d" % [int(level_data.get("level_index", 0)), crystal_index],
				int(crystal_data.get("x", 0)),
				int(crystal_data.get("y", 0)),
				"Essenzsplitter geborgen."
			)
		)
	level_data["pickups"] = normalized_pickups
	level_data["crystals"] = []

	var triggers: Array = level_data.get("triggers", []) as Array
	for trigger_index: int in range(triggers.size()):
		var trigger_data: Dictionary = triggers[trigger_index] as Dictionary
		var message: String = str(trigger_data.get("message", ""))
		message = message.replace("Kleine Slimes sind ideal, um Joeys Schlagtempo warm zu halten.", "Fledermaeuse bestrafen Hast. Schlag erst, spring dann.")
		triggers[trigger_index] = trigger_data
		trigger_data["message"] = message
	level_data["triggers"] = triggers


static func _chapter_one_levels() -> Array:
	return [
		{
			"title": "Der Erste Tropfen",
			"subtitle": "Joey lernt, dass ein Slime nicht marschiert, sondern fliesst.",
			"objective": "Finde den ersten Hohlgang durch kleine Spruenge und sichere Landungen.",
			"size": Vector2i(102, 38),
			"spawn": Vector2i(4, 28),
			"exit": Vector2i(96, 24),
			"platforms": [
				_platform(0, 31, 102, 4, "floor"),
				_platform(8, 27, 7, 1),
				_platform(18, 25, 7, 1),
				_platform(29, 23, 6, 1),
				_platform(40, 27, 8, 1),
				_platform(53, 24, 6, 1),
				_platform(63, 22, 6, 1),
				_platform(74, 24, 6, 1),
				_platform(86, 26, 8, 1),
				_platform(92, 24, 8, 1)
			],
			"hazards": [],
			"enemies": [
				_enemy("slime", 21, 22),
				_enemy("mushroom", 57, 21)
			],
			"torches": [
				_torch(6, 27, 0.95),
				_torch(32, 22, 1.0),
				_torch(68, 21, 1.05),
				_torch(95, 23, 1.15)
			],
			"crystals": [
				_crystal(16, 24, 0.9),
				_crystal(49, 22, 1.1),
				_crystal(82, 23, 1.0)
			],
			"pickups": [
				_pickup("c1_l1_essence_a", 14, 25, "Essenzsplitter aus dem Kalk geluest."),
				_pickup("c1_l1_essence_b", 66, 20, "Die Kristallader reagiert auf Joeys Kern.")
			],
			"triggers": [
				_tutorial_trigger("c1_l1_intro", 3, 26, 7, 4, "Bewegung und Sprung", "Joey liest die Hoehle ueber Schwung. Kurze, saubere Linien sind sicherer als hektische Korrekturen mitten im Sprung.", "A / D laufen   SHIFT sprinten   SPACE springen", "TUTORIAL", "Kapitel I", Color(0.64, 0.95, 1.0, 1.0)),
				_tutorial_trigger("c1_l1_mid", 35, 24, 8, 5, "Glowcap lesen", "Wenn Glowcap dein Licht frisst, laedt sie Sporen auf. Nimm Joeys Glow im Lade-Moment kurz raus, dann taumelt der Pilz und wird offen fuer deinen Angriff.", "F fuer Glow   Licht an zum Locken, aus zum Unterbrechen.", "TUTORIAL"),
				_trigger("c1_l1_exit", 92, 22, 5, 5, "Vor dir beginnt die eigentliche Tropfsteinhoehle.", "reward", "Weiter")
			],
			"worm_count": 0
		},
		{
			"title": "Der Tiefe Riss",
			"subtitle": "Abwaerts fuehren nur ruhige Augen und saubere Landungen.",
			"objective": "Lese die Hoehle und falle kontrolliert durch den Riss.",
			"size": Vector2i(108, 40),
			"spawn": Vector2i(6, 12),
			"exit": Vector2i(98, 30),
			"platforms": [
				_platform(0, 14, 20, 1, "ledge"),
				_platform(0, 32, 108, 4, "floor"),
				_platform(23, 19, 7, 1),
				_platform(33, 23, 6, 1),
				_platform(43, 27, 8, 1),
				_platform(56, 24, 7, 1),
				_platform(66, 20, 7, 1),
				_platform(77, 23, 6, 1),
				_platform(88, 27, 7, 1),
				_platform(95, 30, 8, 1)
			],
			"hazards": [
				_hazard("spikes", 31, 31, 2),
				_hazard("spikes", 73, 31, 2)
			],
			"enemies": [
				_enemy("slime", 45, 26),
				_enemy("slime", 80, 22)
			],
			"torches": [
				_torch(5, 13, 1.0),
				_torch(36, 22, 0.9),
				_torch(70, 19, 0.95),
				_torch(99, 29, 1.1)
			],
			"crystals": [
				_crystal(28, 18, 0.95),
				_crystal(52, 23, 1.15),
				_crystal(85, 26, 0.95)
			],
			"pickups": [
				_pickup("c1_l2_essence_a", 59, 23, "Feuchte Essenz sammelt sich in sicheren Nischen.")
			],
			"triggers": [
				_trigger("c1_l2_intro", 5, 10, 10, 4, "Nicht jeder Sturz ist Gefahr. Schaue nach sicheren Absatzen, dann fliehst du dem Dornengraben.", "info"),
				_trigger("c1_l2_drop", 41, 22, 8, 7, "Lange Falllinien lesen sich wie Wasser. Joey ist am staerksten, wenn du den Fluss erkennst.", "info")
			],
			"worm_count": 0
		},
		{
			"title": "Flatterkamm",
			"subtitle": "Fledermaeuse zwingen Joey, seine Spruenge im Raum zu timen.",
			"objective": "Quere die gebrochenen Bruestungen und halte die Luft frei.",
			"size": Vector2i(118, 38),
			"spawn": Vector2i(4, 28),
			"exit": Vector2i(110, 24),
			"platforms": [
				_platform(0, 31, 20, 4, "floor"),
				_platform(24, 29, 7, 1),
				_platform(36, 26, 8, 1),
				_platform(49, 23, 7, 1),
				_platform(62, 26, 8, 1),
				_platform(77, 22, 7, 1),
				_platform(91, 26, 8, 1),
				_platform(105, 24, 10, 1),
				_platform(112, 31, 6, 4, "floor")
			],
			"hazards": [
				_hazard("spikes", 31, 31, 3),
				_hazard("spikes", 58, 31, 3),
				_hazard("spikes", 84, 31, 3)
			],
			"enemies": [
				_enemy("bat", 31, 22),
				_enemy("bat", 68, 18),
				_enemy("slime", 109, 23)
			],
			"torches": [
				_torch(8, 27, 1.0),
				_torch(53, 22, 0.95),
				_torch(109, 23, 1.15)
			],
			"crystals": [
				_crystal(42, 25, 0.9),
				_crystal(79, 21, 1.0),
				_crystal(104, 23, 1.2)
			],
			"pickups": [
				_pickup("c1_l3_essence_a", 78, 19, "Der Wind zwischen den Klingen traegt rohe Essenz.")
			],
			"triggers": [
				_trigger("c1_l3_intro", 5, 26, 8, 4, "Fliegende Gegner wollen Joey aus der Bahn druecken. Schlag sie, bevor du abspringst.", "info", "Luftkontrolle"),
				_trigger("c1_l3_mid", 60, 20, 8, 8, "Wenn eine Fledermaus ueber dir kreist, zwing sie in deinen Schlagbogen statt in die Landelinie.", "info")
			],
			"worm_count": 0
		},
		{
			"title": "Schattenrinne",
			"subtitle": "Joeys Licht ist Schutz und Risiko zugleich.",
			"objective": "Fuehre dein Glow bewusst durch die dunkle Rinne.",
			"size": Vector2i(114, 40),
			"spawn": Vector2i(4, 28),
			"exit": Vector2i(100, 25),
			"platforms": [
				_platform(0, 31, 108, 4, "floor"),
				_platform(14, 28, 8, 1),
				_platform(29, 26, 8, 1),
				_platform(45, 24, 7, 1),
				_platform(59, 22, 7, 1),
				_platform(72, 25, 8, 1),
				_platform(87, 28, 9, 1),
				_platform(96, 25, 8, 1)
			],
			"hazards": [
				_hazard("spikes", 39, 31, 2),
				_hazard("spikes", 81, 31, 2)
			],
			"enemies": [
				_enemy("slime", 32, 25),
				_enemy("bat", 62, 17)
			],
			"torches": [
				_torch(6, 27, 0.8),
				_torch(47, 23, 0.6),
				_torch(99, 24, 1.2)
			],
			"crystals": [
				_crystal(20, 27, 0.85, Color(0.58, 0.82, 1.0, 1.0)),
				_crystal(58, 21, 1.05, Color(0.54, 0.76, 1.0, 1.0))
			],
			"pickups": [
				_pickup("c1_l4_essence_a", 76, 23, "Im Schatten haengen besonders dichte Essenzsplitter.")
			],
			"triggers": [
				_tutorial_trigger("c1_l4_intro", 3, 26, 10, 4, "Glow einsetzen", "Joeys Glow oeffnet den Blick in dunklen Rinnen und haelt versteckte Gefahren lesbar. Schalte ihn bewusst ein, wenn die Hoehle zu still wird.", "F fuer Glow   Licht an in dunklen Rinnen, aus wenn du schon sicher liest.", "TUTORIAL", "Glow", Color(0.56, 0.9, 1.0, 1.0)),
				_trigger("c1_l4_dark", 55, 20, 10, 8, "Bleib nicht zu lange blind. In der Rinne lieben die Wuermer stilles Dunkel.", "info")
			],
			"worm_count": 1
		},
		{
			"title": "Kristallgraben",
			"subtitle": "Die Hoehle wird enger, die Kaempfe dichter und die Routen riskanter.",
			"objective": "Durchbrich das erste Kampffeld und halte den Rhythmus.",
			"size": Vector2i(132, 44),
			"spawn": Vector2i(5, 29),
			"exit": Vector2i(112, 24),
			"platforms": [
				_platform(0, 32, 120, 4, "floor"),
				_platform(12, 27, 10, 1),
				_platform(25, 24, 10, 1),
				_platform(40, 28, 8, 1),
				_platform(54, 24, 10, 1),
				_platform(69, 20, 8, 1),
				_platform(84, 24, 10, 1),
				_platform(99, 28, 8, 1),
				_platform(108, 24, 9, 1)
			],
			"hazards": [
				_hazard("spikes", 35, 31, 2),
				_hazard("spikes", 48, 31, 2),
				_hazard("spikes", 78, 31, 2)
			],
			"enemies": [
				_enemy("slime", 15, 26),
				_enemy("slime", 31, 23),
				_enemy("bat", 58, 18),
				_enemy("slime", 88, 23),
				_enemy("bat", 104, 20)
			],
			"torches": [
				_torch(6, 28, 1.0),
				_torch(42, 27, 0.9),
				_torch(72, 19, 0.9),
				_torch(111, 23, 1.15)
			],
			"crystals": [
				_crystal(27, 23, 1.15),
				_crystal(65, 22, 1.0),
				_crystal(96, 27, 1.0)
			],
			"pickups": [
				_pickup("c1_l5_essence_a", 45, 26, "Der Graben belohnt aggressive, saubere Linien."),
				_pickup("c1_l5_essence_b", 103, 26, "Kristallstaub laedt Joeys Kern wieder auf.")
			],
			"triggers": [
				_trigger("c1_l5_intro", 5, 27, 8, 4, "Jetzt werden Route und Kampf eins. Lass keine Fledermaus deine Landung diktieren.", "info", "Druck steigt"),
				_trigger("c1_l5_combo", 63, 19, 8, 6, "Kleine Slimes sind ideal, um Joeys Schlagtempo warm zu halten.", "info")
			],
			"worm_count": 0
		},
		{
			"title": "Der Vertikale Atem",
			"subtitle": "Eine steile Kristallschlucht prueft Rhythmus, Blick und Nerven.",
			"objective": "Steige durch den Schacht auf und halte die Wandwechsel sauber.",
			"size": Vector2i(104, 62),
			"spawn": Vector2i(6, 46),
			"exit": Vector2i(79, 10),
			"platforms": [
				_platform(0, 49, 92, 5, "floor"),
				_platform(12, 43, 10, 1),
				_platform(25, 38, 8, 1),
				_platform(13, 33, 7, 1),
				_platform(28, 29, 8, 1),
				_platform(47, 25, 8, 1),
				_platform(34, 21, 7, 1),
				_platform(52, 17, 8, 1),
				_platform(70, 14, 10, 1),
				_platform(76, 10, 10, 1)
			],
			"hazards": [
				_hazard("spikes", 22, 48, 2),
				_hazard("spikes", 44, 48, 3),
				_hazard("spikes", 60, 48, 2)
			],
			"enemies": [
				_enemy("bat", 18, 35),
				_enemy("bat", 40, 24),
				_enemy("slime", 73, 13)
			],
			"torches": [
				_torch(5, 45, 0.85),
				_torch(30, 28, 0.8),
				_torch(54, 16, 0.95),
				_torch(80, 9, 1.15)
			],
			"crystals": [
				_crystal(18, 42, 1.0),
				_crystal(50, 24, 1.2),
				_crystal(74, 13, 1.05)
			],
			"pickups": [
				_pickup("c1_l6_essence_a", 34, 28, "Hoch in der Hoehle schwingt die Essenz klarer."),
				_pickup("c1_l6_essence_b", 58, 16, "Jeder Aufstieg staerkt Joeys neuen Koerper.")
			],
			"triggers": [
				_tutorial_trigger("c1_l6_intro", 4, 44, 8, 4, "Wall Slide", "An rauen Waenden kann Joey Tempo herausnehmen und den Sturz kontrollieren. Nutze das, um steile Schaechte in Etappen zu lesen statt sie in Panik zu erzwingen.", "An die Wand halten   Joey gleitet langsamer und oeffnet dir den naechsten Zug.", "SKILL", "Aufstieg", Color(0.74, 0.94, 1.0, 1.0)),
				_tutorial_trigger("c1_l6_top", 69, 12, 8, 5, "Wall Jump", "Vom Wall Slide aus wird die Wand zum Absprungpunkt. Spring erst ab, wenn Joey stabil haftet, dann nimm die Gegenwand als neue Route.", "An der Wand haften   SPACE fuer Wandsprung   Rhythmus statt Spam.", "SKILL", "", Color(0.66, 0.92, 1.0, 1.0), "reward")
			],
			"worm_count": 0
		},
		{
			"title": "Das Schimmernde Heiligtum",
			"subtitle": "Der letzte Pruefraum vor dem Mini-Boss bindet alles zusammen.",
			"objective": "Meistere den Mix aus Schatten, Luftkampf und Nahdruck.",
			"size": Vector2i(136, 46),
			"spawn": Vector2i(5, 28),
			"exit": Vector2i(114, 21),
			"platforms": [
				_platform(0, 31, 124, 4, "floor"),
				_platform(15, 26, 9, 1),
				_platform(29, 23, 8, 1),
				_platform(44, 20, 8, 1),
				_platform(58, 23, 8, 1),
				_platform(73, 26, 8, 1),
				_platform(88, 22, 10, 1),
				_platform(104, 24, 9, 1),
				_platform(111, 21, 10, 1)
			],
			"hazards": [
				_hazard("spikes", 25, 31, 2),
				_hazard("spikes", 52, 31, 2),
				_hazard("spikes", 69, 31, 2),
				_hazard("spikes", 99, 31, 2)
			],
			"enemies": [
				_enemy("slime", 18, 25),
				_enemy("bat", 34, 18),
				_enemy("slime", 61, 22),
				_enemy("bat", 80, 18),
				_enemy("slime", 108, 23)
			],
			"torches": [
				_torch(7, 27, 0.85),
				_torch(45, 19, 0.75),
				_torch(74, 25, 0.8),
				_torch(116, 20, 1.25)
			],
			"crystals": [
				_crystal(21, 25, 1.0),
				_crystal(49, 19, 1.2),
				_crystal(91, 21, 1.15)
			],
			"pickups": [
				_pickup("c1_l7_essence_a", 47, 18, "Das Heiligtum speichert alte Schleim-Essenz."),
				_pickup("c1_l7_essence_b", 113, 20, "Joeys Kern pocht jetzt mit echtem Widerstand.")
			],
			"triggers": [
				_trigger("c1_l7_intro", 4, 26, 10, 4, "Alles, was die Hoehle lehren wollte, prueft sie hier auf einmal.", "info", "Pruefung"),
				_trigger("c1_l7_exit", 110, 19, 8, 5, "Hinter dem naechsten Tor wartet der Koenig der Hoehlenschleime.", "reward", "Mini-Boss")
			],
			"worm_count": 1
		},
		{
			"title": "Der Koenig der Hoehlenschleime",
			"subtitle": "Eine traege Masse, die Joeys neue Form spiegeln will.",
			"objective": "Besiege den Mini-Boss und sichere Joeys ersten grossen Sieg.",
			"size": Vector2i(134, 48),
			"spawn": Vector2i(8, 28),
			"exit": Vector2i(106, 24),
			"platforms": [
				_platform(0, 31, 116, 4, "floor"),
				_platform(20, 25, 10, 1),
				_platform(85, 25, 10, 1)
			],
			"hazards": [
				_hazard("spikes", 33, 31, 2),
				_hazard("spikes", 79, 31, 2)
			],
			"enemies": [],
			"torches": [
				_torch(8, 27, 0.95),
				_torch(26, 24, 0.85),
				_torch(91, 24, 0.85),
				_torch(108, 23, 1.3)
			],
			"crystals": [
				_crystal(22, 24, 1.25),
				_crystal(92, 24, 1.25)
			],
			"pickups": [],
			"triggers": [
				_trigger("c1_l8_intro", 7, 26, 10, 4, "Das ist kein weiterer Tropfen. Das ist die ganze Hoehle, die auf Joey zurueckschlaegt.", "info", "Koenig"),
				_trigger("c1_l8_mid", 52, 21, 12, 8, "Bleib nicht unter dem Boss stehen. Lass ihn springen, dann schneide die Gegenlinie.", "info")
			],
			"worm_count": 0,
			"boss": {
				"type": "slime_king",
				"x": 58,
				"y": 26
			},
			"boss_exit_message": "Der Schleimkoenig zerfliesst. Eine neue Tuere antwortet tief im Hub."
		}
	]
