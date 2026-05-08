#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SITE_ROOT = ROOT / "joeyslime.com"
DATA_DIR = SITE_ROOT / "assets" / "data"

PLAYER_PATH = ROOT / "Scripts" / "player.gd"
SKILLS_PATH = ROOT / "Scripts" / "skill_progression.gd"
CHAPTERS_PATH = ROOT / "Scripts" / "Chapter" / "chapter_content.gd"
ENEMY_DIR = ROOT / "Scripts" / "Chapter" / "Enemies"
ITEMS_DIR = ROOT / "InventorySystem" / "items"

GAME_COPY = {
    "title": "Joey's Slimeventure",
    "tagline": "Ein atmosphärisches Pixel-Art Metroidvania und Action-Platformer-Abenteuer über einen gefallenen Krieger, der als Slime in die Tiefe zurückkehrt.",
    "status": "Aktive Entwicklung",
    "developer": "Joshua Pond",
    "platforms": ["Windows", "macOS", "Browser Demo"],
    "genres": ["Action Platformer", "Metroidvania", "Pixel Art Adventure"],
    "hero_description": "Joey rutscht, springt, leuchtet und kaempft sich durch unterirdische Biome mit klarer Lernkurve, starkem Feedback und immer mehr Traversal-Freiheit.",
}

MECHANICS = [
    {
        "slug": "glow",
        "title": "Glow",
        "category": "Lesbarkeit",
        "summary": "Joey bringt seine eigene Lichtquelle mit. Das sorgt für Stimmung, macht Kanten lesbar und führt Spieler bewusst durch dunklere Abschnitte.",
        "points": [
            "Standardmäßig verfügbar und damit Teil des Einstiegs.",
            "Hilft, Plattformkanten, Gegner und pickups schneller zu lesen.",
            "Dient spielerisch als ruhiger Kontrast zu dunkleren Höhlengängen.",
        ],
    },
    {
        "slug": "movement",
        "title": "Slime Movement",
        "category": "Traversal",
        "summary": "Der Spielfluss baut auf weich reagierendem Movement auf: kurze Sprünge, kontrollierte Landungen und späteres vertikales Erweitern durch Freischaltungen.",
        "points": [
            "Zuerst sichere Horizontalräume, später mehr Höhenarbeit.",
            "Airtime und Landefeedback geben Tempo ohne das Spiel unlesbar zu machen.",
            "Traversal-Skills werden bewusst an Kapitel-Progression gekoppelt.",
        ],
    },
    {
        "slug": "combat",
        "title": "Combo Combat",
        "category": "Kampf",
        "summary": "Joeys Nahkampf ist auf Treffergefühl, Combo-Rhythmus und klares Ende von Angriffsketten ausgerichtet.",
        "points": [
            "Maximale Combo-Länge liegt aktuell bei 11 Treffern.",
            "Kritische Treffer und Trefferfeedback arbeiten mit klaren Audio- und VFX-Signalen.",
            "Feinde werden nicht blind gespawnt, sondern sollen den Raum ergänzen.",
        ],
    },
    {
        "slug": "essence",
        "title": "Essenz und Loot",
        "category": "Belohnung",
        "summary": "Kristallsplitter, Relikte und Materialdrops machen Erkundung wertvoll und geben Spielern einen greifbaren Fortschrittsloop.",
        "points": [
            "Essenz dient als unmittelbare Belohnung für Neugier und Nebenwege.",
            "Items bringen Zahlen, Wurfwerte oder Kampfboni mit.",
            "Seltene Drops geben dem Wiederholen von Begegnungen langfristig Sinn.",
        ],
    },
    {
        "slug": "stars",
        "title": "Stars und Begleiter",
        "category": "Systeme",
        "summary": "Legendäre Sterngeister erscheinen jetzt als seltene Fangbegegnungen und lassen sich in drei eigenen Stars-Slots ausrüsten.",
        "points": [
            "Lumora, Pyrion und Vortex tauchen zufällig in Runs auf und können eingefangen werden.",
            "Stars werden als eigene Begleiter-Items im Inventar gespeichert statt als einmaliger Event-Spawn.",
            "Drei Stars-Slots erlauben Builds mit mehreren aktiven Sterngeistern gleichzeitig.",
        ],
    },
    {
        "slug": "progression",
        "title": "Kapitel-Progression",
        "category": "Struktur",
        "summary": "Jedes Kapitel führt neue Anforderungen ein und macht weitere Hub-Türen sichtbar, sobald der vorherige Abschnitt sauber abgeschlossen wurde.",
        "points": [
            "Kapitel I dient als frühes Onboarding für Licht, Sprünge und Wall-Tools.",
            "Skill-Freischaltungen werden nicht auf einmal, sondern entlang der Lernkurve verteilt.",
            "Hub, Türen und Kapitelmarker halten den Fortschritt jederzeit klar lesbar.",
        ],
    },
]

CONTROLS = [
    {"input": "A / D", "title": "Bewegen", "description": "Joey fließt über Boden, Kanten und später durch komplexere Risse und Schächte."},
    {"input": "Space", "title": "Springen", "description": "Der Einstieg bleibt fair, bevor Kapitel I langsam Höhe und Präzision steigert."},
    {"input": "Shift", "title": "Sprint / Druck", "description": "Hilft, Lücken sauber zu überbrücken und Schwung durch den Raum zu tragen."},
    {"input": "Linksklick", "title": "Angreifen", "description": "Startet Joeys Combo-Kette. Treffer sollen lesbar, direkt und rhythmisch sein."},
    {"input": "F", "title": "Glow umschalten", "description": "Toggelt Joeys Leuchten für Lesbarkeit, Stil und Cave-Atmosphäre."},
    {"input": "Esc", "title": "Pause", "description": "Pausiert das Spiel im Hub und während der Kapitel für eine ruhige Navigation."},
]

PAGE_INDEX = [
    {"path": "/", "title": "Joey's Slimeventure", "summary": "Offizielle Website zum Pixel-Art Metroidvania und Action-Platformer Joey's Slimeventure mit Demo, Welt, Wiki und Devlog.", "tags": ["joey's slimeventure", "joey slimeventure", "official website", "pixel art metroidvania", "action platformer", "browser demo", "indie game"]},
    {"path": "/play/", "title": "Spielen", "summary": "Browser-Demo, Gameplay, Controls, Plattformen und Einstieg in Joey's Slimeventure.", "tags": ["spielen", "browser demo", "controls", "gameplay", "platforms", "official demo"]},
    {"path": "/world/", "title": "Welt", "summary": "Story, Hub, Kapitel, Biome, Bosse und Progression der Kampagne.", "tags": ["story", "kapitel", "biome", "welt", "hub", "bosses"]},
    {"path": "/devlog/", "title": "Devlog", "summary": "Echte Entwicklungsupdates direkt aus dem Git-Verlauf von Joey's Slimeventure.", "tags": ["devlog", "git", "updates", "development", "changelog"]},
    {"path": "/wiki/", "title": "Game Wiki", "summary": "Wissenszentrale fuer Mechaniken, Gegner, Items, Stars und Progression.", "tags": ["wiki", "guide", "mechaniken", "enemies", "items", "stars", "progression"]},
    {"path": "/wiki/mechanics/", "title": "Wiki: Mechaniken", "summary": "Controls, Movement, Kampf, Stars und Lesbarkeit im Detail.", "tags": ["movement", "combat", "glow", "controls", "mechanics", "stars"]},
    {"path": "/wiki/enemies/", "title": "Wiki: Gegner", "summary": "Gegnerrollen, Leben, Schaden und Verhalten.", "tags": ["gegner", "bat", "boss", "enemy", "combat"]},
    {"path": "/wiki/items/", "title": "Wiki: Items", "summary": "Materialien, Relikte, Stars, Drop-Raten und Boni.", "tags": ["items", "loot", "drops", "relics", "stars", "resources"]},
    {"path": "/wiki/progression/", "title": "Wiki: Progression", "summary": "Skill-Freischaltungen, Kapitel-Meilensteine und Progression.", "tags": ["progression", "skills", "freischaltungen", "metroidvania progression"]},
    {"path": "/media/", "title": "Media", "summary": "Screenshots, Fact Sheet, Brandmaterial und Press-Kit.", "tags": ["media", "screenshots", "press kit", "fact sheet"]},
    {"path": "/reward/", "title": "Daily Rewards", "summary": "Live-Belohnungen, Reward-Pool und Reset-Zeiten fuer Joey's Slimeventure.", "tags": ["daily rewards", "items", "reward pool", "live rewards"]},
    {"path": "/about/", "title": "Entwickler", "summary": "Joshua Pond, PondSec und der Hintergrund hinter Joey's Slimeventure.", "tags": ["entwickler", "pondsec", "joshua pond", "official studio"]},
    {"path": "/faq/", "title": "FAQ", "summary": "Antworten auf die wichtigsten Fragen rund um Demo, Plattformen, Fortschritt und Content.", "tags": ["faq", "hilfe", "support", "demo", "platforms"]},
]


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    site_data = build_site_data()
    devlog_data = build_devlog()
    search_index = build_search_index(site_data)

    write_json(DATA_DIR / "site-data.json", site_data)
    write_json(DATA_DIR / "devlog.json", devlog_data)
    write_json(DATA_DIR / "search-index.json", search_index)
    subprocess.check_call([sys.executable, str(Path(__file__).with_name("build_site_pages.py"))])
    subprocess.check_call([sys.executable, str(Path(__file__).with_name("build_seo_assets.py"))])


def build_site_data() -> dict:
    player_text = PLAYER_PATH.read_text(encoding="utf-8")
    skills_text = SKILLS_PATH.read_text(encoding="utf-8")
    chapter_text = CHAPTERS_PATH.read_text(encoding="utf-8")

    site_data = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "game": GAME_COPY,
        "controls": CONTROLS,
        "player_stats": parse_player_stats(player_text),
        "skills": parse_skills(skills_text),
        "chapters": parse_chapters(chapter_text),
        "enemies": parse_enemies(),
        "items": parse_items(),
        "mechanics": enrich_mechanics(parse_skills(skills_text)),
    }
    return site_data


def build_devlog() -> dict:
    command = [
        "git",
        "-C",
        str(ROOT),
        "log",
        "--date=short",
        "--pretty=format:%H%x1f%h%x1f%cs%x1f%s%x1f%b%x1e",
        "-n",
        "36",
    ]
    raw = subprocess.check_output(command, text=True)
    entries = []
    for chunk in raw.strip("\x1e").split("\x1e"):
        if not chunk.strip():
            continue
        commit_hash, short_hash, date, subject, body = [part.strip() for part in chunk.split("\x1f")]
        category_key, category = categorize_commit(subject)
        summary = summarize_commit(subject, body)
        entries.append(
            {
                "hash": commit_hash,
                "hash_short": short_hash,
                "date": date,
                "subject": subject,
                "body": one_line(body),
                "summary": summary,
                "category_key": category_key,
                "category": category,
            }
        )

    latest_ref = subprocess.check_output(
        ["git", "-C", str(ROOT), "rev-parse", "--abbrev-ref", "HEAD"],
        text=True,
    ).strip()

    return {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "latest_ref": latest_ref,
        "entries": entries,
    }


def build_search_index(site_data: dict) -> dict:
    entries = list(PAGE_INDEX)
    entries.extend(
        {
            "path": f"/wiki/mechanics/#{item['slug']}",
            "title": item["title"],
            "summary": item["summary"],
            "tags": [item["category"], "wiki", "mechanik"],
        }
        for item in site_data.get("mechanics", [])
    )
    entries.extend(
        {
            "path": "/wiki/enemies/",
            "title": enemy["name"],
            "summary": enemy["description"],
            "tags": [enemy["biome"], enemy["role"], "gegner"],
        }
        for enemy in site_data.get("enemies", [])
    )
    entries.extend(
        {
            "path": "/wiki/items/",
            "title": item["name"],
            "summary": item["description"],
            "tags": [item["kind"], item["rarity"], "item"],
        }
        for item in site_data.get("items", [])
    )
    entries.extend(
        {
            "path": "/wiki/progression/",
            "title": skill["title"],
            "summary": skill.get("description", "Freischaltbare Fertigkeit."),
            "tags": skill.get("marker_labels", []) + ["skill", "progression"],
        }
        for skill in site_data.get("skills", [])
    )
    entries.extend(
        {
            "path": "/world/",
            "title": chapter["title"],
            "summary": chapter["description"],
            "tags": [chapter["status"], chapter["signature"], "kapitel"],
        }
        for chapter in site_data.get("chapters", [])
    )
    return {"generated_at": datetime.now(timezone.utc).isoformat(), "entries": entries}


def parse_player_stats(text: str) -> dict:
    targets = {
        "max_health": ("var", "max_health", "Basis-Lebenspunkte von Joey."),
        "walk_speed": ("const", "DEFAULT_WALK_SPEED", "Kontrolliertes Grundtempo für lesbare Jump-Passagen."),
        "run_speed": ("const", "DEFAULT_RUN_SPEED", "Schnelleres Traversal auf sicheren Geraden."),
        "base_attack_damage": ("var", "base_attack_damage", "Grundschaden von Joeys Nahkampf."),
        "max_combo": ("const", "MAX_COMBO", "Maximale Zahl der Combo-Stufen."),
        "jump_velocity": ("const", "JUMP_VELOCITY", "Vertikale Basis für Standardsprünge."),
        "wall_jump_x": ("const", "WALL_JUMP_VELOCITY_X", "Horizontaler Schub beim Wall Jump."),
        "wall_jump_y": ("const", "WALL_JUMP_VELOCITY_Y", "Vertikale Höhe beim Wall Jump."),
        "dash_speed": ("const", "BASE_DASH_SPEED", "Basistempo für den Dash."),
        "teleport_distance": ("const", "TELEPORT_DISTANCE", "Maximale Distanz für Teleport-Fähigkeit."),
    }
    result = {}
    for key, (kind, name, note) in targets.items():
        pattern = rf"{kind}\s+{re.escape(name)}\s*(?::[^=]+)?(?::)?=\s*([-0-9.]+)"
        match = re.search(pattern, text)
        if match:
            raw = match.group(1)
            value = int(float(raw)) if raw.endswith(".0") or raw.isdigit() or raw.startswith("-") and raw[1:].isdigit() else float(raw)
            result[key] = {"value": value, "note": note}
    return result


def parse_skills(text: str) -> list[dict]:
    milestone_block = extract_const_block(text, "SKILL_MILESTONES")
    title_block = extract_const_block(text, "SKILL_TITLES")
    baseline_block = extract_const_block(text, "BASELINE_SKILLS")

    titles = {key: value for key, value in re.findall(r'"([^"]+)":\s*"([^"]+)"', title_block)}
    descriptions = {
        "glow": "Joeys Leuchten macht dunkle Bereiche lesbar und setzt Cave-Atmosphäre unter Spannung.",
        "wall_slide": "Gibt Joey Kontrolle an vertikalen Flächen und öffnet sichere Höhenwechsel.",
        "regeneration": "Belohnt ruhige Spielmomente mit einem defensiven Rückzugswerkzeug.",
        "double_jump": "Hebt die Traversal-Freiheit in Kapitel I spürbar an.",
        "sticky_form": "Verankert Joey an Oberflächen und erweitert Plattformrätsel.",
        "wall_run": "Beschleunigt späteres Movement entlang klarer Wandstrecken.",
        "heal_burst": "Schnelle Notheilung für druckvolle Begegnungen.",
        "dash": "Kurzer Tempoburst für Kampf, Timing und Gap-Crossing.",
        "mana_shield": "Absorbiert Druckspitzen in späteren Kapiteln.",
        "teleport": "Verlegt Joey gezielt über größere Distanzen.",
        "slime_minion": "Unterstützt Kampfbegegnungen mit Begleitwesen.",
        "acid_spit": "Gibt Joey eine neue Reichweitenachse im Kampf.",
        "thorns": "Bestrafung für nahen Kontakt mit späteren Gegnern.",
        "slime_wings": "Reduziert Falltempo und erweitert Luftkontrolle.",
        "gravity_slime": "Endgame-Movement mit radikal veränderter Raumlogik.",
        "ult": "Spitzenskills für große Bossphasen.",
        "phoenix_slime": "High-end Power-Fantasy für späte Kapitel.",
    }

    baseline_keys = {
        key
        for key, value in re.findall(r'"([^"]+)":\s*(true|false)', baseline_block)
        if value == "true"
    }

    skills = []
    for key, markers_blob in re.findall(r'"([^"]+)":\s*\[(.*?)\]', milestone_block, flags=re.S):
        markers = re.findall(r'"([^"]+)"', markers_blob)
        skills.append(
            {
                "id": key,
                "title": titles.get(key, pretty_name(key)),
                "markers": markers,
                "marker_labels": [format_marker(marker) for marker in markers],
                "baseline": key in baseline_keys,
                "description": descriptions.get(key, "Freischaltung für Traversal, Kampf oder Überleben."),
            }
        )

    # keep baseline-only entries that have no marker array and might not appear above
    for key in baseline_keys:
        if not any(skill["id"] == key for skill in skills):
            skills.append(
                {
                    "id": key,
                    "title": titles.get(key, pretty_name(key)),
                    "markers": [],
                    "marker_labels": [],
                    "baseline": True,
                    "description": descriptions.get(key, "Grundfertigkeit."),
                }
            )

    skills.sort(key=lambda entry: (entry["baseline"] is False, entry["marker_labels"][0] if entry["marker_labels"] else "", entry["title"]))
    return skills


def parse_chapters(text: str) -> list[dict]:
    pattern = re.compile(
        r"(?P<index>\d+):\s*return\s*\{\s*"
        r'"title":\s*"(?P<title>[^"]+)".*?'
        r'"short_title":\s*"(?P<short>[^"]+)".*?'
        r'"description":\s*"(?P<description>[^"]+)"',
        re.S,
    )
    boss_map = {
        1: "König der Höhlenschleime",
        2: "Wächter der Gebeine",
        3: "Mycelia",
        4: "Pyros",
        5: "Morgraths Vorhut",
        6: "Schwarzkristall-Herz",
        7: "Thronvorhof-Kommandant",
    }
    skill_map = {
        1: "Sticky Form",
        2: "Dash",
        3: "Teleport",
        4: "Acid Spit",
        5: "Slime Wings",
        6: "Gravity Slime",
        7: "Ultimate / Phoenix Slime",
    }
    signature_map = {
        1: "Kalkstein, kaltes Wasser, Kristalle",
        2: "Staub, Knochen, Wandfackeln",
        3: "Pilzlicht, Sporen, Wurzeln",
        4: "Basalt, Magma, Hitzezonen",
        5: "Faulnis, Gift, Verderbnis",
        6: "Schwarzkristall, Echo, Leere",
        7: "Vorhof, Garde, Endspielspannung",
    }
    implemented = {1}
    chapters = []
    for match in pattern.finditer(text):
        index = int(match.group("index"))
        roman = romanize(index)
        chapters.append(
            {
                "index": index,
                "roman": roman,
                "title": normalize_public_text(match.group("title")),
                "short_title": normalize_public_text(match.group("short")),
                "description": normalize_public_text(match.group("description")),
                "status": "Spielbar" if index in implemented else "In Planung",
                "boss": boss_map.get(index),
                "skill_unlock": skill_map.get(index),
                "signature": signature_map.get(index, "Noch in Arbeit"),
            }
        )
    return chapters


def parse_enemies() -> list[dict]:
    enemies = []
    bat_text = (ENEMY_DIR / "cave_bat.gd").read_text(encoding="utf-8")
    king_text = (ENEMY_DIR / "slime_king.gd").read_text(encoding="utf-8")
    enemies.append(
        {
            "name": "Cave Bat",
            "slug": "cave-bat",
            "biome": "Tropfsteinhöhle",
            "role": "Luftdruck",
            "description": "Die Fledermaus kontrolliert frühe Luftachsen und zwingt saubere Trefferfenster statt hektischem Button-Spam.",
            "health": int(extract_number(bat_text, "max_health", "export")),
            "contact_damage": int(extract_number(bat_text, "contact_damage", "export")),
            "move_speed": f"Schweben {int(extract_number(bat_text, 'hover_speed', 'export'))} / Jagen {int(extract_number(bat_text, 'chase_speed', 'export'))}",
            "signature": f"Swoop-Speed {int(extract_number(bat_text, 'swoop_speed', 'export'))}",
            "image": "/assets/media/bat.gif",
        }
    )
    enemies.append(
        {
            "name": "Slime King",
            "slug": "slime-king",
            "biome": "Kapitel-I-Mini-Boss",
            "role": "Bossdruck",
            "description": "Der träge, schwere Mini-Boss prüft, ob Joeys Movement, Tempo und Hit-Commitment bereits sauber sitzen.",
            "health": int(extract_number(king_text, "max_health", "export")),
            "contact_damage": int(extract_number(king_text, "contact_damage", "export")),
            "move_speed": f"Hop-Angriff {int(extract_number(king_text, 'move_force_x', 'export'))}",
            "signature": f"Slam-Schaden {int(extract_number(king_text, 'slam_damage', 'export'))}",
            "image": None,
        }
    )
    return enemies


def parse_items() -> list[dict]:
    descriptions = {
        "bat_artefact": "Extrem seltener Reliktdrop mit offensivem Build-Potenzial.",
        "bat_claw": "Früher Bat-Drop, ideal für Wurf- und Materialspiel.",
        "copper_nugget": "Häufige Grundressource für den frühen Loot-Loop.",
        "iron_nugget": "Stabilerer Drop mit spürbar mehr Wurf-Schaden.",
        "gold_nugget": "Seltener Fund für wertigere Runs.",
        "golem_heart": "Seltene Boss-nahe Ressource mit Lebensbonus.",
        "stone": "Rohmaterial ohne markanten Kampfbonus.",
    }
    rarity_labels = [
        (0.01, "Mythisch"),
        (0.05, "Selten"),
        (0.18, "Ungewöhnlich"),
        (1.0, "Häufig"),
    ]
    image_map = {
        "bat_artefact": "/assets/media/bat_artefact.png",
        "bat_claw": "/assets/media/bat_claw.png",
        "copper_nugget": "/assets/media/copper_nugget.png",
        "gold_nugget": "/assets/media/gold_nugget.png",
        "golem_heart": "/assets/media/golem_heart.png",
        "iron_nugget": "/assets/media/iron_nugget.png",
    }

    items = []
    for path in sorted(ITEMS_DIR.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        name = extract_resource_value(text, "name")
        if not name:
            continue
        drop = extract_float_value(text, "drop_chance")
        bonuses = []
        for field, label in [
            ("health_bonus", "Health-Bonus"),
            ("damage_bonus", "Damage-Bonus"),
            ("crit_chance_bonus", "Crit-Chance"),
            ("crit_damage_bonus", "Crit-Damage"),
        ]:
            value = extract_float_value(text, field)
            if value and value != 0:
                bonuses.append({"label": label, "value": f"{value:g}"})

        rarity = "Nicht festgelegt"
        if drop is not None:
            for threshold, label in rarity_labels:
                if drop <= threshold:
                    rarity = label
                    break
        items.append(
            {
                "id": name,
                "name": pretty_name(name),
                "kind": "Relikt" if "artefact" in name or "heart" in name else "Ressource",
                "rarity": rarity,
                "description": descriptions.get(name, "Bekannter Inventar-Gegenstand."),
                "drop_chance": f"{drop * 100:.1f}%" if drop is not None else None,
                "throw_damage": extract_float_value(text, "throw_damage"),
                "bonuses": bonuses,
                "image": image_map.get(name),
            }
        )

    items.extend(
        [
            {
                "id": "lumora",
                "name": "Lumora",
                "kind": "Star",
                "rarity": "Legendär",
                "description": "Heilender Sterngeist, der Joey mit Licht, Regeneration und skalierenden Support-Buffs begleitet.",
                "drop_chance": "Zufälliger Fang",
                "throw_damage": 0,
                "bonuses": [
                    {"label": "Slots", "value": "Stars (1/3)"},
                    {"label": "Rolle", "value": "Heal / Support"},
                ],
                "image": None,
            },
            {
                "id": "pyrion",
                "name": "Pyrion",
                "kind": "Star",
                "rarity": "Legendär",
                "description": "Offensiver Sterngeist mit Feuer-Schild, Combo-Druck und aggressiven Crit-/Tempo-Buffs.",
                "drop_chance": "Zufälliger Fang",
                "throw_damage": 0,
                "bonuses": [
                    {"label": "Slots", "value": "Stars (1/3)"},
                    {"label": "Rolle", "value": "Offense / Combo"},
                ],
                "image": None,
            },
            {
                "id": "vortex",
                "name": "Vortex",
                "kind": "Star",
                "rarity": "Legendär",
                "description": "Kontroll-Sterngeist mit Slow-Aura, defensiven Buffs und stabiler Kampfkontrolle.",
                "drop_chance": "Zufälliger Fang",
                "throw_damage": 0,
                "bonuses": [
                    {"label": "Slots", "value": "Stars (1/3)"},
                    {"label": "Rolle", "value": "Control / Defense"},
                ],
                "image": None,
            },
        ]
    )
    return items


def enrich_mechanics(skills: list[dict]) -> list[dict]:
    by_id = {skill["id"]: skill for skill in skills}
    mechanics = []
    for mechanic in MECHANICS:
        merged = dict(mechanic)
        if mechanic["slug"] in by_id:
            merged.setdefault("points", []).append(
                "Freischaltung: %s" % (", ".join(by_id[mechanic["slug"]]["marker_labels"]) or "Grundausstattung")
            )
        mechanics.append(merged)
    return mechanics


def extract_const_block(text: str, const_name: str) -> str:
    marker = f"const {const_name} := "
    start = text.find(marker)
    if start == -1:
        return ""
    brace_start = text.find("{", start)
    depth = 0
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace_start:index + 1]
    return ""


def extract_number(text: str, name: str, kind: str) -> float:
    pattern = rf"@export\s+var\s+{re.escape(name)}\s*:\s*[^=]+\s*(?::)?=\s*([-0-9.]+)" if kind == "export" else rf"(?:const|var)\s+{re.escape(name)}\s*(?::[^=]+)?(?::)?=\s*([-0-9.]+)"
    match = re.search(pattern, text)
    if not match:
        raise ValueError(f"Could not find {name}")
    return float(match.group(1))


def extract_resource_value(text: str, field: str) -> str | None:
    match = re.search(rf"^{re.escape(field)}\s*=\s*\"([^\"]+)\"", text, re.M)
    return match.group(1) if match else None


def extract_float_value(text: str, field: str) -> float | None:
    match = re.search(rf"^{re.escape(field)}\s*=\s*([-0-9.]+)", text, re.M)
    return float(match.group(1)) if match else None


def categorize_commit(subject: str) -> tuple[str, str]:
    lowered = subject.lower()
    mapping = [
        ("chapter", ("world", "World / Level Design")),
        ("level", ("world", "World / Level Design")),
        ("tile", ("world", "World / Level Design")),
        ("player", ("combat", "Player / Combat")),
        ("bat", ("combat", "Player / Combat")),
        ("lumora", ("systems", "Systems / AI")),
        ("ui", ("presentation", "Presentation / UI")),
        ("sound", ("presentation", "Presentation / UI")),
        ("website", ("web", "Website / Marketing")),
        ("save", ("systems", "Systems / AI")),
    ]
    for keyword, value in mapping:
        if keyword in lowered:
            return value
    return ("updates", "General Update")


def summarize_commit(subject: str, body: str) -> str:
    cleaned_body = one_line(body)
    if cleaned_body:
        return cleaned_body
    lowered = subject.lower()
    if "fix" in lowered:
        return "Stabilisiert einen bestehenden Teil des Projekts und entfernt Reibung beim Spielen oder Entwickeln."
    if "add" in lowered or "added" in lowered:
        return "Fügt einen neuen Baustein hinzu, der Spiel, Präsentation oder Produktionsfluss erweitert."
    if "refactor" in lowered:
        return "Ordnet Systeme neu, damit sie robuster und später leichter ausbaubar bleiben."
    return "Aktualisiert Joey's Slimeventure mit sichtbaren Änderungen im laufenden Entwicklungsstand."


def one_line(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def format_marker(marker: str) -> str:
    if marker.endswith("_complete"):
        chapter = marker.removesuffix("_complete").replace("chapter", "")
        return f"Kapitel {romanize(int(chapter))} abgeschlossen"
    parts = marker.split("_")
    if len(parts) == 3 and parts[0].startswith("chapter") and parts[1] == "level":
        chapter = int(parts[0].replace("chapter", ""))
        return f"Kapitel {romanize(chapter)} • Level {parts[2]}"
    return pretty_name(marker)


def romanize(value: int) -> str:
    numerals = {
        1: "I",
        2: "II",
        3: "III",
        4: "IV",
        5: "V",
        6: "VI",
        7: "VII",
        8: "VIII",
    }
    return numerals.get(value, str(value))


def pretty_name(raw: str) -> str:
    return raw.replace("_", " ").title()


def normalize_public_text(value: str) -> str:
    return (
        value
        .replace("Tropfsteinhoehle", "Tropfsteinhöhle")
        .replace("Hoehle", "Höhle")
        .replace("haengt", "hängt")
    )


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
