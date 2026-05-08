#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SITE_ROOT = ROOT / "joeyslime.com"
DATA_DIR = SITE_ROOT / "assets" / "data"

SITE_NAME = "Joey's Slimeventure"
SITE_URL = "https://joeyslime.com"
DEFAULT_IMAGE = "/assets/media/hero-screenshot.png"

NAV_ITEMS = [
    ("/", "Start"),
    ("/play/", "Spiel"),
    ("/world/", "Welt"),
    ("/devlog/", "Devlog"),
    ("/wiki/", "Wiki"),
    ("/media/", "Media"),
    ("/faq/", "FAQ"),
    ("/about/", "Über"),
    ("/reward/", "Daily Rewards"),
]

FAQ_ENTRIES = [
    {
        "id": "faq-demo",
        "question": "Gibt es schon eine spielbare Demo?",
        "answer": "Ja. Du kannst Joey's Slimeventure direkt im Browser testen. Auf der Spiel-Seite findest du die Browser-Demo, Controls, Plattformen und den schnellsten Einstieg in den aktuellen Build.",
    },
    {
        "id": "faq-platforms",
        "question": "Für welche Plattformen ist Joey's Slimeventure gedacht?",
        "answer": "Aktuell liegt der Fokus auf Browser-Demo, Windows und macOS. Die offizielle Website zeigt klar, welche Wege schon spielbar sind und welche Inhalte sich noch in aktiver Entwicklung befinden.",
    },
    {
        "id": "faq-progression",
        "question": "Wie funktioniert die Kapitel-Progression?",
        "answer": "Joey startet in einem zentralen Hub. Nach abgeschlossenen Kapiteln öffnen sich neue Türen, Biome und Skills. Kapitel I führt Licht, Movement, frühe Kämpfe und die ersten Traversal-Werkzeuge ein.",
    },
    {
        "id": "faq-devlog",
        "question": "Wie aktuell ist der Devlog?",
        "answer": "Der Devlog wird direkt aus dem Git-Verlauf erzeugt. Dadurch zeigt die Website echte Entwicklungsupdates aus dem Projekt statt nachträglich geschriebener Platzhalter-News.",
    },
    {
        "id": "faq-wiki",
        "question": "Wofür ist das Game Wiki gedacht?",
        "answer": "Das Game Wiki bündelt Mechaniken, Gegner, Items und Progression. So finden neue Spieler Gameplay-Systeme, Werte und Freischaltungen schnell wieder, ohne die komplette Website durchsuchen zu müssen.",
    },
    {
        "id": "faq-contact",
        "question": "Wo finde ich den Entwickler?",
        "answer": "Auf der Über-Seite findest du Joshua Pond, PondSec, Portfolio, GitHub, YouTube und weitere offizielle Kontakt- und Projektlinks an einem zentralen Ort.",
    },
]

WORLD_STORY = [
    "Joey war einst ein Krieger und fiel im Kampf gegen Morgrath, den Fäulnisfürsten. Tief unter dem Schlachtfeld verband sich seine Essenz mit uraltem Schleim und gab ihm eine neue, formbare Existenz.",
    "Aus dieser Verwandlung entsteht kein klassischer Ritter mehr, sondern ein Held, der über Bewegung, Licht, Anpassung und Timing überlebt. Genau daraus speist sich das besondere Slime-Movement des Spiels.",
    "Kapitel I beginnt in der Tropfsteinhöhle. Dort lernen Spieler zuerst Lesbarkeit, frühe Traversal-Freiheit, kontrollierte Gegnerbegegnungen und den Kernloop aus Erkundung, Kampf, Essenz und Freischaltungen kennen.",
]

PLAY_GUIDE = [
    {
        "title": "Direkt im Browser testen",
        "text": "Die Browser-Demo ist der schnellste Weg, Joeys Movement, Treffergefühl und Höhlenatmosphäre ohne Download selbst zu erleben.",
    },
    {
        "title": "Controls in unter einer Minute verstehen",
        "text": "Unter der Demo findest du alle Eingaben auf einen Blick. Neue Spieler müssen nicht raten, wie Joey springt, kämpft, leuchtet oder pausiert.",
    },
    {
        "title": "Kapitel I ist der ideale Einstieg",
        "text": "Die erste spielbare Route führt Lesbarkeit, frühe Traversal und kontrollierte Encounters sauber ein, statt Besucher sofort mit Systemtiefe zu überfordern.",
    },
    {
        "title": "Nach der Demo tiefer einsteigen",
        "text": "Wenn du nach dem ersten Run mehr willst, führen dich Welt, Wiki und Devlog direkt zu Story, Freischaltungen und laufender Entwicklung.",
    },
]

HOME_STARTER_STEPS = [
    {
        "step": "01",
        "title": "Demo spielen",
        "text": "Teste Joey's Slimeventure direkt im Browser und spüre sofort, wie sich Slime-Movement, Licht und Combat anfühlen.",
        "href": "/web_demo/",
        "label": "Browser-Demo starten",
    },
    {
        "step": "02",
        "title": "Spiel verstehen",
        "text": "Sieh dir Gameplay, Controls, Plattformen und den aktuellen Build an, ohne dich durch die ganze Website klicken zu müssen.",
        "href": "/play/",
        "label": "Zum Spielüberblick",
    },
    {
        "step": "03",
        "title": "Welt und Progression entdecken",
        "text": "Kapitel, Biome, Gegner, Skills und Devlog liegen auf eigenen Seiten bereit, damit neue Besucher sofort Orientierung bekommen.",
        "href": "/world/",
        "label": "Welt ansehen",
    },
]

HOME_PILLARS = [
    (
        "fa-eye",
        "Lesbares Pixel-Art-Abenteuer",
        "Dunkle Höhlen, Glow-Licht und klare Blickachsen sorgen dafür, dass Joey's Slimeventure atmosphärisch aussieht, ohne unlesbar zu werden.",
    ),
    (
        "fa-person-running",
        "Sauberes Slime-Movement",
        "Kurze Sprünge, Wall-Tools, Tempo-Wechsel und später neue Traversal-Skills halten den Flow lebendig und gut kontrollierbar.",
    ),
    (
        "fa-hand-fist",
        "Direktes Kampfgefühl",
        "Treffer, Combos, Drops und Gegnerreaktionen sollen jede Begegnung präzise und wertig wirken lassen statt nur laut oder chaotisch.",
    ),
    (
        "fa-door-open",
        "Metroidvania-Fortschritt mit Hub",
        "Neue Türen, Kapitel und Skills öffnen sich entlang der Kampagne. Dadurch bleibt die Progression greifbar und das Worldbuilding nachvollziehbar.",
    ),
]

HOME_LOOP_STEPS = [
    {
        "title": "Erkunden",
        "text": "Du liest Räume über Licht, Kristalle, Wasser, Höhenwechsel und alternative Pfade statt über Markerpfeile und UI-Lärm.",
    },
    {
        "title": "Kämpfen",
        "text": "Frühe Gegner wie die Cave Bat trainieren Timing, Positionierung und Trefferfenster, bevor das Spiel härter wird.",
    },
    {
        "title": "Freischalten",
        "text": "Skills wie Wall Slide, Sticky Form oder Double Jump erweitern Joeys Bewegungsfreiheit Schritt für Schritt entlang der Lernkurve.",
    },
    {
        "title": "Zurück in den Hub",
        "text": "Der Hub verbindet Kapitel, Story-Fortschritt und neue Türen. So bleibt jederzeit klar, wohin die Reise als Nächstes führt.",
    },
]

WORLD_STRUCTURE_STEPS = [
    {
        "title": "Ein Hub verbindet alles",
        "text": "Joey kehrt immer wieder an einen zentralen Ausgangspunkt zurück. Von dort verzweigen sich neue Türen, Kapitel und Freischaltungen.",
    },
    {
        "title": "Jedes Biom hat eine Aufgabe",
        "text": "Die Biome sind nicht nur Kulisse. Jedes Kapitel verschiebt Stimmung, Bossdruck, Traversal und Signatur-Mechaniken bewusst weiter.",
    },
    {
        "title": "Progression bleibt lesbar",
        "text": "Welt, Gegner und Skills sind so organisiert, dass neue Spieler den Kampagnenfluss sofort greifen und Veteranen später tiefer einsteigen können.",
    },
]

SAME_AS_LINKS = [
    "https://github.com/JoshuaPondStudios/JoeysSlimeventure",
    "https://www.tiktok.com/@joeysslimeventure",
    "https://youtube.com/@pondsec",
    "https://pondsec.com",
    "https://portfolio.pondsec.com",
    "https://pondsec.itch.io/joeys-slimeventure",
]

BREADCRUMB_LABELS = {
    "/": "Start",
    "/play/": "Spiel",
    "/world/": "Welt",
    "/devlog/": "Devlog",
    "/wiki/": "Wiki",
    "/wiki/mechanics/": "Mechaniken",
    "/wiki/enemies/": "Gegner",
    "/wiki/items/": "Items",
    "/wiki/progression/": "Progression",
    "/media/": "Media",
    "/faq/": "FAQ",
    "/about/": "Über",
    "/reward/": "Daily Rewards",
}

MEDIA_FACTS = [
    ("Titel", SITE_NAME),
    ("Genre", "Action-Platformer / Metroidvania / Pixel Art Adventure"),
    ("Entwickler", "Joshua Pond"),
    ("Website", SITE_URL),
    ("Demo", f"{SITE_URL}/web_demo/"),
    ("GitHub", "https://github.com/JoshuaPondStudios/JoeysSlimeventure"),
    ("Itch.io", "https://pondsec.itch.io/joeys-slimeventure"),
]

ABOUT_FACTS = [
    ("Studio", "PondSec"),
    ("Portfolio", "https://portfolio.pondsec.com"),
    ("Website", "https://pondsec.com"),
    ("YouTube", "https://youtube.com/@pondsec"),
    ("GitHub", "https://github.com/JoshuaPondStudios/JoeysSlimeventure"),
]


def main() -> None:
    site_data = json.loads((DATA_DIR / "site-data.json").read_text(encoding="utf-8"))
    devlog = json.loads((DATA_DIR / "devlog.json").read_text(encoding="utf-8"))

    write_page("/", render_home(site_data, devlog))
    write_page("/play/", render_play(site_data))
    write_page("/world/", render_world(site_data))
    write_page("/devlog/", render_devlog(site_data, devlog))
    write_page("/wiki/", render_wiki(site_data))
    write_page("/wiki/mechanics/", render_wiki_mechanics(site_data))
    write_page("/wiki/enemies/", render_wiki_enemies(site_data))
    write_page("/wiki/items/", render_wiki_items(site_data))
    write_page("/wiki/progression/", render_wiki_progression(site_data))
    write_page("/media/", render_media(site_data, devlog))
    write_page("/faq/", render_faq())
    write_page("/about/", render_about(site_data))
    write_page("/reward/", render_reward())


def write_page(path: str, html: str) -> None:
    html = localize_html_paths(html, path)
    if path == "/":
        target = SITE_ROOT / "index.html"
    else:
        target = SITE_ROOT / path.strip("/") / "index.html"
        target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")


def localize_html_paths(html: str, path: str) -> str:
    prefix = relative_prefix(path)
    html = re.sub(r'href="/(?!/)', f'href="{prefix}', html)
    html = re.sub(r"href='/(?!/)", f"href='{prefix}", html)
    html = re.sub(r'src="/(?!/)', f'src="{prefix}', html)
    html = re.sub(r"src='/(?!/)", f"src='{prefix}", html)
    html = re.sub(r'href="((?![a-z]+:|//|#)[^"]*/)"', r'href="\1index.html"', html)
    html = re.sub(r"href='((?![a-z]+:|//|#)[^']*/)'", r"href='\1index.html'", html)
    return html


def relative_prefix(path: str) -> str:
    segments = [segment for segment in path.strip("/").split("/") if segment]
    if not segments:
        return "./"
    return "../" * len(segments)


def render_home(site_data: dict, devlog: dict) -> str:
    game = site_data["game"]
    latest_entries = devlog["entries"][:3]
    latest_chapter = site_data["chapters"][0]
    featured_chapters = site_data["chapters"][:4]
    starter_steps = "".join(
        starter_card(item["step"], item["title"], item["text"], item["href"], item["label"])
        for item in HOME_STARTER_STEPS
    )
    feature_cards = "".join(feature_card(icon, title, summary) for icon, title, summary in HOME_PILLARS)
    loop_cards = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(item['title'])}</h3>
            <p>{escape(item['text'])}</p>
        </article>
        """
        for item in HOME_LOOP_STEPS
    )
    chapter_panels = "".join(chapter_panel(chapter) for chapter in featured_chapters)
    build_cards = "".join(
        f"""
        <article class="stat-card scroll-reveal-stagger">
            <strong>{escape(value)}</strong>
            <h3>{escape(label)}</h3>
            <p>{escape(note)}</p>
        </article>
        """
        for value, label, note in [
            ("Demo live", "Sofort spielbar", "Neue Besucher koennen Joey direkt im Browser ausprobieren."),
            (f"Kapitel {latest_chapter['roman']}", "Aktueller Spielstand", f"{latest_chapter['short_title']} ist die erste spielbare Hauptroute."),
            (latest_chapter["skill_unlock"], "Naechster Fokus", "Die aktuelle Kommunikation fuehrt klar zur naechsten grossen Traversal-Freischaltung."),
            ("3 Wege", "Plattformen", "Windows, macOS und Browser Demo sind als offizielle Wege sichtbar verankert."),
        ]
    )
    devlog_preview = "".join(devlog_entry(entry) for entry in latest_entries)

    body = f"""
    <header class="hero hero--landing" id="main">
        <div class="hero-panel hero-panel--split hero-panel--landing scroll-reveal">
            <div class="hero-content landing-copy">
                <span class="eyebrow">Offizielle Website · Pixel-Art Metroidvania</span>
                <h1>{escape(game['title'])}</h1>
                <p class="page-lead">Ein atmosphaerisches Pixel-Art Metroidvania und Action-Platformer-Abenteuer ueber einen gefallenen Krieger, der als Slime in die Tiefe zurueckkehrt.</p>
                <p class="hero-support">Neue Besucher sollen hier sofort verstehen, was Joey's Slimeventure ist, was heute schon spielbar ist und wo Demo, Gameplay, Welt, Wiki und Devlog ohne Umwege liegen.</p>
                <div class="hero-buttons">
                    <a href="/web_demo/" class="btn btn-large btn-magnetic">Demo spielen</a>
                    <a href="/play/" class="btn btn-accent btn-large">Gameplay ansehen</a>
                    <a href="/world/" class="btn btn-secondary btn-large">Welt entdecken</a>
                </div>
                <div class="meta-pills">
                    {pill("Status", game["status"])}
                    {pill("Genre", "Pixel-Art Metroidvania")}
                    {pill("Aktuell spielbar", f"Kapitel {latest_chapter['roman']}")}
                    {pill("Plattformen", ", ".join(game["platforms"]))}
                </div>
            </div>
            <div class="landing-hero-stack">
                <div class="hero-media-panel">
                    {image_tag("/assets/media/hero-screenshot.png", "Gameplay-Screenshot aus Joey's Slimeventure", eager=True)}
                    {image_tag("/assets/media/joey.gif", "Joey in Slime-Form waehrend des Gameplays")}
                </div>
                <article class="content-panel hero-side-card">
                    <h3>Neu hier? So findest du dich sofort zurecht</h3>
                    <div class="hero-side-list">
                        <div class="hero-side-list__item"><strong>1.</strong><span>Starte die Browser-Demo fuer den schnellsten Ersteindruck.</span></div>
                        <div class="hero-side-list__item"><strong>2.</strong><span>Sieh dir Controls, Plattformen und den aktuellen Build kompakt an.</span></div>
                        <div class="hero-side-list__item"><strong>3.</strong><span>Tauche erst danach tiefer in Kapitel, Wiki und Devlog ein.</span></div>
                    </div>
                </article>
            </div>
        </div>
    </header>

    <main>
        <section id="about" class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>In 30 Sekunden orientiert</h2>
                    <p>Die offizielle Website fuehrt neue Besucher zuerst zu Demo und Spielueberblick und erst dann tiefer in Welt, Wiki und Entwicklung.</p>
                </div>
                <div class="content-grid starter-grid">
                    {starter_steps}
                </div>
            </div>
        </section>

        <section id="play">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Was Joey's Slimeventure ausmacht</h2>
                    <p>Die Startseite muss sofort zeigen, was fuer ein Spiel dich erwartet: lesbares Pixel-Art-Design, sauberes Movement, Combat und klarer Metroidvania-Fortschritt.</p>
                </div>
                <div class="features-grid">
                    {feature_cards}
                </div>
            </div>
        </section>

        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Aktueller Build auf einen Blick</h2>
                    <p>Neue Spieler brauchen nicht nur Stimmung, sondern auch Sicherheit: Was ist schon da, wie weit ist das Spiel und worin liegt der aktuelle Fokus?</p>
                </div>
                <div class="content-grid content-grid--wide">
                    <article class="content-panel scroll-reveal-left">
                        <h3>Kapitel I setzt den Ton fuer das ganze Spiel</h3>
                        <p class="page-lead">{escape(latest_chapter['title'])} fuehrt Licht, fruehe Traversal, Hoehlenatmosphaere und erste saubere Gegnerachsen ein. Von hier aus verzweigt sich spaeter die gesamte Kampagnenstruktur mit Hub-Tueren, Biomen und neuen Freischaltungen.</p>
                        <ul class="fact-list">
                            <li><strong>Status</strong><span>{escape(game['status'])}</span></li>
                            <li><strong>Fokus</strong><span>Action-Platformer mit Metroidvania-Struktur</span></li>
                            <li><strong>Aktuelles Kapitel</strong><span>{escape(latest_chapter['roman'])} · {escape(latest_chapter['short_title'])}</span></li>
                            <li><strong>Nächster Skill-Fokus</strong><span>{escape(latest_chapter['skill_unlock'])}</span></li>
                        </ul>
                        <div class="section-links">
                            <a href="/play/">Zur Demo und den Controls</a>
                            <a href="/world/">Zur Welt und Story</a>
                            <a href="/wiki/progression/">Zur Progression</a>
                        </div>
                    </article>
                    <aside class="stat-grid scroll-reveal-right">
                        {build_cards}
                    </aside>
                </div>
            </div>
        </section>

        <section id="features">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>So fuehlt sich der Gameplay-Loop an</h2>
                    <p>Wer Joey's Slimeventure sucht, soll sofort verstehen, wie Exploration, Kampf, Skills und Hub-Fortschritt zusammenspielen.</p>
                </div>
                <div class="content-grid">
                    {loop_cards}
                </div>
            </div>
        </section>

        <section id="story" class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Kapitel, Biome und Roadmap</h2>
                    <p>Die Startseite zeigt nur den wichtigsten Weltueberblick. Fuer mehr Tiefe fuehren eigene Seiten zu Story, Wiki und kompletter Progression.</p>
                </div>
                <div class="content-grid content-grid--chapters">
                    {chapter_panels}
                </div>
                <div class="section-links">
                    <a href="/world/">Alle Kapitel ausfuehrlich ansehen</a>
                    <a href="/wiki/">Mechaniken und Gegner im Wiki</a>
                </div>
            </div>
        </section>

        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Offizielle Kanaele und Projektlinks</h2>
                    <p>Wer Joey's Slimeventure verfolgen will, findet hier die wichtigsten offiziellen Wege fuer Updates, Clips, Builds und Projektfortschritt.</p>
                </div>
                {social_loop()}
            </div>
        </section>

        <section id="devlog" class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Aktuelle Entwicklung</h2>
                    <p>Diese Eintraege werden aus dem Git-Verlauf gezogen und zeigen den echten Stand statt leerer Marketing-Notizen.</p>
                </div>
                <div class="timeline-list">
                    {devlog_preview}
                </div>
                <p class="mini-note">Letzte Quelle: Branch <strong>{escape(devlog['latest_ref'])}</strong> · generiert {escape(devlog['generated_at'])}</p>
                <div class="section-links">
                    <a href="/devlog/">Kompletten Devlog lesen</a>
                    <a href="/about/">Entwickler und Studio ansehen</a>
                </div>
            </div>
        </section>

        {community_section()}
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} | Pixel-Art Metroidvania & Browser-Demo",
        description="Offizielle Website zu Joey's Slimeventure: Pixel-Art Metroidvania und Action-Platformer mit Browser-Demo, Gameplay-Ueberblick, Welt, Wiki, Devlog und offiziellen Projektlinks.",
        path="/",
        body_class="page-home",
        main_content=body,
        json_ld={
            "@context": "https://schema.org",
            "@type": "VideoGame",
            "name": SITE_NAME,
            "description": game["tagline"],
            "genre": game["genres"],
            "gamePlatform": game["platforms"],
            "playMode": "SinglePlayer",
            "operatingSystem": "Windows, macOS, Web Browser",
            "image": f"{SITE_URL}{DEFAULT_IMAGE}",
            "author": {"@type": "Person", "name": game["developer"]},
            "publisher": {"@type": "Organization", "name": "PondSec"},
            "sameAs": SAME_AS_LINKS,
            "url": SITE_URL,
        },
    )


def render_play(site_data: dict) -> str:
    game = site_data["game"]
    latest_chapter = site_data["chapters"][0]
    controls_rows = "".join(
        f"<tr><th>{escape(row['input'])}</th><td><strong>{escape(row['title'])}</strong><br>{escape(row['description'])}</td></tr>"
        for row in site_data["controls"]
    )
    stats_cards = "".join(
        f"""
        <article class="stat-card scroll-reveal-stagger">
            <strong>{escape(str(entry['value']))}</strong>
            <h3>{escape(pretty_label(key))}</h3>
            <p>{escape(entry['note'])}</p>
        </article>
        """
        for key, entry in list(site_data["player_stats"].items())[:8]
    )
    guide_cards = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(item['title'])}</h3>
            <p>{escape(item['text'])}</p>
        </article>
        """
        for item in PLAY_GUIDE
    )
    chapters = "".join(
        f"<li><strong>Kapitel {escape(chapter['roman'])}</strong><span>{escape(chapter['status'])} · {escape(chapter['short_title'])}</span></li>"
        for chapter in site_data["chapters"]
    )
    playable_now = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(title)}</h3>
            <p>{escape(text)}</p>
        </article>
        """
        for title, text in [
            ("Kapitel I ist live", "Die aktuelle spielbare Route fuehrt durch die Tropfsteinhoehle und zeigt den Ton, die Lesbarkeit und die ersten Traversal-Werkzeuge des Spiels."),
            ("Movement vor Reizueberflutung", "Joeys Slime-Movement soll sich weich, klar und kontrollierbar anfuehlen, bevor spaeter mehr vertikale Komplexitaet dazukommt."),
            ("Combat mit direktem Feedback", "Treffer, Combos und Gegnerdruck geben der Demo von Anfang an einen klaren Rhythmus statt losem Button-Spam."),
            ("Roadmap bleibt sichtbar", "Auf dieser Seite siehst du sofort, was schon spielbar ist, welche Plattformen offiziell verlinkt sind und wo du tiefer weiterlesen kannst."),
        ]
    )
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split reward-hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Spiel</span>
                <h1>Browser-Demo, Gameplay und Controls</h1>
                <p class="page-lead">Hier landen Spieler, die sofort loslegen wollen: Browser-Demo, Plattformen, Controls, aktuelle Stats und die wichtigsten Hinweise zum momentanen Stand.</p>
                <div class="hero-buttons">
                    <a href="/web_demo/" class="btn btn-large btn-magnetic">Browser-Demo</a>
                    <a href="https://pondsec.itch.io/joeys-slimeventure" class="btn btn-accent btn-large" target="_blank" rel="noreferrer">Itch.io</a>
                    <a href="/wiki/mechanics/" class="btn btn-secondary btn-large">Mechaniken lesen</a>
                </div>
                <div class="meta-pills">
                    {pill("Status", game["status"])}
                    {pill("Plattformen", ", ".join(game["platforms"]))}
                    {pill("Aktuell", f"Kapitel {latest_chapter['roman']} spielbar")}
                </div>
            </div>
            <div class="hero-media-panel">
                <img src="/assets/media/hero-screenshot.png" alt="Gameplay-Screenshot">
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>So startest du sauber</h2>
                    <p>Die Spielseite trennt Einstieg, Steuerung, aktuelle Werte und Fortschrittskontext, damit Besucher nicht erst die ganze Website entschlüsseln müssen.</p>
                </div>
                <div class="content-grid">
                    {guide_cards}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Controls</h2>
                    <p>Die wichtigsten Eingaben im aktuellen Stand von Joey's Slimeventure.</p>
                </div>
                <div class="table-shell scroll-reveal">
                    <table>
                        <thead>
                            <tr><th>Eingabe</th><th>Aktion</th></tr>
                        </thead>
                        <tbody>
                            {controls_rows}
                        </tbody>
                    </table>
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Aktuelle Joey-Werte</h2>
                    <p>Diese Werte werden aus dem Projekt gelesen und geben der Seite echte Spielnähe statt leerer Marketing-Sprache.</p>
                </div>
                <div class="stat-grid">
                    {stats_cards}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Roadmap der Kapitel</h2>
                    <p>Die Website zeigt klar, was schon spielbar ist und was noch folgt, ohne alles in diffuse Zukunftsversprechen zu verpacken.</p>
                </div>
                <article class="content-panel scroll-reveal">
                    <ul class="fact-list fact-list--stacked">
                        {chapters}
                    </ul>
                    <div class="section-links">
                        <a href="/world/">Kapitel im Detail</a>
                        <a href="/devlog/">Entwicklungsfortschritt ansehen</a>
                        <a href="/faq/">FAQ öffnen</a>
                    </div>
                </article>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Demo & Gameplay von {SITE_NAME} | Browser-Demo und Controls",
        description="Spiele Joey's Slimeventure direkt im Browser und finde Demo, Gameplay, Controls, Plattformen, Kapitelstatus und den aktuellen Build auf einen Blick.",
        path="/play/",
        body_class="page-inner page-play",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "WebPage", "name": "Spiel", "url": f"{SITE_URL}/play/"},
    )


def render_world(site_data: dict) -> str:
    chapters = "".join(chapter_panel(chapter) for chapter in site_data["chapters"])
    enemies = "".join(enemy_tile(enemy) for enemy in site_data["enemies"])
    world_structure = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(item['title'])}</h3>
            <p>{escape(item['text'])}</p>
        </article>
        """
        for item in WORLD_STRUCTURE_STEPS
    )
    skills = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(skill['title'])}</h3>
            <p>{escape(skill['description'])}</p>
            <p class="mini-note">Freischaltung: {escape(', '.join(skill['marker_labels']) or 'Grundausstattung')}</p>
        </article>
        """
        for skill in site_data["skills"][:6]
    )
    story_copy = "".join(f"<p>{escape(paragraph)}</p>" for paragraph in WORLD_STORY)

    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Welt</span>
                <h1>Hub, Kapitel, Biome und Story</h1>
                <p class="page-lead">Hier liegt der Kampagnenkontext: Joeys Ursprung, die Reihenfolge der Kapitel, die Biome, Gegnerrollen und die Progression vom Hub aus.</p>
                <div class="hero-buttons">
                    <a href="/wiki/progression/" class="btn btn-large btn-magnetic">Progression lesen</a>
                    <a href="/play/" class="btn btn-secondary btn-large">Zur Demo-Seite</a>
                </div>
                <div class="meta-pills">
                    {pill("Aktiver Fokus", "Kapitel I")}
                    {pill("Hub-Struktur", "Türen werden nacheinander sichtbar")}
                </div>
            </div>
            <div class="hero-media-panel">
                <img src="/assets/media/sk.png" alt="Stimmungsbild aus Joey's Slimeventure">
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Story-Grundlage</h2>
                    <p>Die Weltseite hält die Hintergrundgeschichte lesbar zusammen, statt sie zwischen Marketing-Text und Einzelabschnitten zu verlieren.</p>
                </div>
                <div class="content-grid content-grid--wide">
                    <article class="content-panel scroll-reveal-left">
                        <h3>Joeys Fall und Rückkehr</h3>
                        {story_copy}
                    </article>
                    <aside class="content-panel scroll-reveal-right">
                        <h3>Weltlogik</h3>
                        <ul class="fact-list">
                            <li><strong>Hub</strong><span>`game.tscn` bleibt die zentrale Spawn-Welt</span></li>
                            <li><strong>Türen</strong><span>Neue Kapitel erscheinen erst nach sauberem Abschluss</span></li>
                            <li><strong>Kapitel I</strong><span>Tropfsteinhöhle mit Lernkurve und Mini-Boss</span></li>
                            <li><strong>Ziel</strong><span>Sieben Kapitel plus Endboss-Finale</span></li>
                        </ul>
                    </aside>
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Kapitelübersicht</h2>
                    <p>Jede Tür steht für ein eigenes Biom mit klarer Signatur, Bossfokus und Skill-Belohnung.</p>
                </div>
                <div class="content-grid content-grid--chapters">
                    {chapters}
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Wie die Kampagne aufgebaut ist</h2>
                    <p>Bevor du die einzelnen Biome liest, zeigt dir dieser Block die Grundlogik der Welt und warum sich neue Spieler schnell orientieren koennen.</p>
                </div>
                <div class="content-grid">
                    {world_structure}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Frühe Gegnerachsen</h2>
                    <p>Der Einstieg lebt von kontrollierten Encounters. Deshalb zeigt die Weltseite nicht nur Namen, sondern auch Rolle, Druckprofil und die Aufgabe eines Gegners im Raum.</p>
                </div>
                <div class="content-grid">
                    {enemies}
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Progression und Freischaltungen</h2>
                    <p>Die Lernkurve von Joey's Slimeventure laeuft ueber Hub-Tueren, Skill-Marker und spaetere biomeabhaengige Erweiterungen. Das macht Fortschritt und Marketing-Aussagen gleichermassen greifbar.</p>
                </div>
                <div class="content-grid">
                    {skills}
                </div>
                <div class="section-links">
                    <a href="/wiki/progression/">Alle Freischaltungen im Wiki</a>
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Welt, Story und Kapitel | {SITE_NAME}",
        description="Entdecke Story, Hub, Kapitel, Biome, Bosse und Freischaltungen von Joey's Slimeventure auf der offiziellen Weltseite.",
        path="/world/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "CollectionPage", "name": "Welt", "url": f"{SITE_URL}/world/"},
    )


def render_devlog(site_data: dict, devlog: dict) -> str:
    categories = sorted({entry["category"] for entry in devlog["entries"]})
    buttons = ['<button class="filter-button active" type="button" data-filter="all">Alle</button>']
    buttons.extend(
        f'<button class="filter-button" type="button" data-filter="{escape(category)}">{escape(category)}</button>'
        for category in categories
    )
    entries = "".join(devlog_entry(entry, filtered=True) for entry in devlog["entries"])
    stats = f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>Quelle</h3>
            <p>Branch <strong>{escape(devlog['latest_ref'])}</strong></p>
        </article>
        <article class="content-panel scroll-reveal-stagger">
            <h3>Einträge</h3>
            <p>{len(devlog['entries'])} Commits im sichtbaren Verlauf</p>
        </article>
        <article class="content-panel scroll-reveal-stagger">
            <h3>Generiert</h3>
            <p>{escape(devlog['generated_at'])}</p>
        </article>
    """
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Devlog</span>
                <h1>Entwicklungsupdates direkt aus dem Projekt</h1>
                <p class="page-lead">Kein von Hand gepflegter Platzhalter-Blog: Diese Seite nimmt echte Commits aus dem Projekt und macht den Fortschritt fuer Spieler, Presse und Community lesbar.</p>
                <div class="meta-pills">
                    {pill("Branch", devlog["latest_ref"])}
                    {pill("Einträge", str(len(devlog["entries"])))}
                    {pill("Stand", devlog["generated_at"])}
                </div>
                <div class="hero-buttons">
                    <a href="https://github.com/JoshuaPondStudios/JoeysSlimeventure" class="btn btn-large btn-magnetic" target="_blank" rel="noreferrer">GitHub öffnen</a>
                    <a href="/wiki/" class="btn btn-secondary btn-large">Zum Wiki</a>
                </div>
            </div>
        </div>
    </header>
    <main data-devlog-root="true">
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Was hier passiert</h2>
                    <p>Der Devlog ist jetzt eine eigene Seite mit Suchfeld und Filterung. So bleibt die Startseite sauber und Spieler können Updates gezielt lesen.</p>
                </div>
                <div class="stat-grid">
                    {stats}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="filter-bar scroll-reveal">
                    <input id="devlogSearch" class="toolbar-input" type="search" placeholder="Devlog durchsuchen">
                    {' '.join(buttons)}
                </div>
                <div class="timeline-list" id="devlogEntries">
                    {entries}
                </div>
                <div class="empty-state" id="devlogEmpty" hidden>Keine Einträge passen zu deinem Filter.</div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Devlog und Entwicklungsupdates | {SITE_NAME}",
        description="Echte Entwicklungsupdates aus dem Git-Verlauf von Joey's Slimeventure mit sichtbarem Projektfortschritt und aktuellem Build-Kontext.",
        path="/devlog/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "Blog", "name": "Joey's Slimeventure Devlog", "url": f"{SITE_URL}/devlog/"},
    )


def render_wiki(site_data: dict) -> str:
    mechanics_preview = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(entry['title'])}</h3>
            <p>{escape(entry['summary'])}</p>
        </article>
        """
        for entry in site_data["mechanics"][:3]
    )
    links = "".join(
        [
            link_card("/wiki/mechanics/", "Mechaniken", "Movement, Glow, Kampf, Controls und frühe Lesbarkeit."),
            link_card("/wiki/enemies/", "Gegner", "Frühe Gegnerrollen, Bossdruck und Verhalten."),
            link_card("/wiki/items/", "Items", "Loot, Drop-Chancen, Relikte und Materialwerte."),
            link_card("/wiki/progression/", "Progression", "Skill-Marker, Kapitel-Freischaltungen und Lernkurve."),
        ]
    )
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Wiki</span>
                <h1>Game Wiki fuer Mechaniken, Gegner und Progression</h1>
                <p class="page-lead">Das Wiki ist die strukturierte Wissenszentrale von Joey's Slimeventure. Spieler bekommen Mechaniken, Gegner, Items und Progression in getrennten Bereichen mit eigener Navigation.</p>
                <div class="hero-buttons">
                    <a href="/wiki/mechanics/" class="btn btn-large btn-magnetic">Mechaniken</a>
                    <a href="/wiki/progression/" class="btn btn-secondary btn-large">Progression</a>
                </div>
            </div>
            <div class="hero-media-panel">
                <img src="/assets/media/bat.gif" alt="Cave Bat als Gameplay-GIF">
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Wiki-Suche</h2>
                    <p>Suche quer über Seiten, Mechaniken, Gegner, Items und Progressionsmarker. Die Ergebnisse kommen aus dem internen Suchindex der Website.</p>
                </div>
                <div class="content-panel scroll-reveal">
                    <input id="wikiSearchInput" class="toolbar-input" type="search" placeholder="Im Wiki suchen">
                    <div id="wikiSearchResults" class="search-results-list"></div>
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Wiki-Bereiche</h2>
                    <p>Jeder Bereich hat jetzt eine eigene Seite, damit Spieler nicht durch einen riesigen Misch-Abschnitt scrollen müssen.</p>
                </div>
                <div class="content-grid">
                    {links}
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Vorschau: Kernmechaniken</h2>
                    <p>Ein schneller Blick auf die wichtigsten Systeme, bevor du tiefer in die Unterseiten springst.</p>
                </div>
                <div class="content-grid">
                    {mechanics_preview}
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Game Wiki | {SITE_NAME}",
        description="Das Game Wiki von Joey's Slimeventure buendelt Mechaniken, Gegner, Items und Progression in einer klaren, suchfreundlichen Struktur.",
        path="/wiki/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "CollectionPage", "name": "Joey's Slimeventure Wiki", "url": f"{SITE_URL}/wiki/"},
    )


def render_wiki_mechanics(site_data: dict) -> str:
    mechanics = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger" id="{escape(item['slug'])}">
            <h3>{escape(item['title'])}</h3>
            <p>{escape(item['summary'])}</p>
            <ul class="fact-list">
                {''.join(f'<li><strong>Hinweis</strong><span>{escape(point)}</span></li>' for point in item['points'])}
            </ul>
        </article>
        """
        for item in site_data["mechanics"]
    )
    controls_rows = "".join(
        f"<tr><th>{escape(row['input'])}</th><td><strong>{escape(row['title'])}</strong><br>{escape(row['description'])}</td></tr>"
        for row in site_data["controls"]
    )
    content = f"""
    {breadcrumb('/wiki/', 'Wiki', 'Mechaniken')}
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Wiki / Mechaniken</span>
                <h1>Movement, Kampf und Lesbarkeit</h1>
                <p class="page-lead">Diese Seite sammelt die Systeme, die Spieler wirklich zum Verstehen des Spiels brauchen: Licht, Slime-Movement, Combo-Gefühl und frühe Traversal-Freischaltungen.</p>
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="table-shell scroll-reveal">
                    <table>
                        <thead><tr><th>Eingabe</th><th>Aktion</th></tr></thead>
                        <tbody>{controls_rows}</tbody>
                    </table>
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="content-grid">
                    {mechanics}
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} · Wiki Mechaniken",
        description="Mechaniken, Controls, Movement, Glow und Kampffluss von Joey's Slimeventure in einer eigenen Wiki-Seite.",
        path="/wiki/mechanics/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "TechArticle", "name": "Mechaniken", "url": f"{SITE_URL}/wiki/mechanics/"},
    )


def render_wiki_enemies(site_data: dict) -> str:
    enemies = "".join(enemy_tile(enemy) for enemy in site_data["enemies"])
    content = f"""
    {breadcrumb('/wiki/', 'Wiki', 'Gegner')}
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Wiki / Gegner</span>
                <h1>Gegner und Raumdruck</h1>
                <p class="page-lead">Gegner sollen Joeys Räume ergänzen, nicht ruinieren. Diese Seite bündelt die wichtigsten Rollen, Werte und frühen Druckprofile.</p>
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="content-grid">
                    {enemies}
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} · Wiki Gegner",
        description="Gegnerrollen, Kontakt-Schaden, Verhalten und Bossdruck in Joey's Slimeventure.",
        path="/wiki/enemies/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "TechArticle", "name": "Gegner", "url": f"{SITE_URL}/wiki/enemies/"},
    )


def render_wiki_items(site_data: dict) -> str:
    items = "".join(item_tile(item) for item in site_data["items"])
    content = f"""
    {breadcrumb('/wiki/', 'Wiki', 'Items')}
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Wiki / Items</span>
                <h1>Loot, Relikte und Ressourcen</h1>
                <p class="page-lead">Das Item-Wiki trennt seltene Relikte, Materialdrops und ihre Boni in einer lesbaren Übersicht mit Bildern und Drop-Chancen.</p>
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="content-grid">
                    {items}
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} · Wiki Items",
        description="Items, Relikte, Drop-Chancen und Boni in Joey's Slimeventure auf einer eigenen Wiki-Seite.",
        path="/wiki/items/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "TechArticle", "name": "Items", "url": f"{SITE_URL}/wiki/items/"},
    )


def render_wiki_progression(site_data: dict) -> str:
    rows = "".join(
        f"""
        <tr>
            <th>{escape(skill['title'])}</th>
            <td>{escape(skill['description'])}</td>
            <td>{escape(', '.join(skill['marker_labels']) or 'Grundausstattung')}</td>
        </tr>
        """
        for skill in site_data["skills"]
    )
    chapters = "".join(
        f"<li><strong>Kapitel {escape(chapter['roman'])}</strong><span>{escape(chapter['short_title'])} · Skill-Fokus: {escape(chapter['skill_unlock'])}</span></li>"
        for chapter in site_data["chapters"]
    )
    content = f"""
    {breadcrumb('/wiki/', 'Wiki', 'Progression')}
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Wiki / Progression</span>
                <h1>Skills, Marker und Kapitelkette</h1>
                <p class="page-lead">Hier wird sichtbar, wie Joey's Slimeventure Freischaltungen entlang von Level- und Kapitelmarkern verteilt. Das hilft Spielern und zukünftiger Kommunikation gleichermaßen.</p>
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="table-shell scroll-reveal">
                    <table>
                        <thead><tr><th>Skill</th><th>Beschreibung</th><th>Freischaltung</th></tr></thead>
                        <tbody>{rows}</tbody>
                    </table>
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <article class="content-panel scroll-reveal">
                    <h3>Kapitel-Folge</h3>
                    <ul class="fact-list fact-list--stacked">{chapters}</ul>
                </article>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} · Wiki Progression",
        description="Skill-Marker, Kapitel-Folge und Freischaltungen in Joey's Slimeventure auf einer eigenen Progressionsseite.",
        path="/wiki/progression/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "TechArticle", "name": "Progression", "url": f"{SITE_URL}/wiki/progression/"},
    )


def render_media(site_data: dict, devlog: dict) -> str:
    gallery = "".join(
        f"""
        <article class="media-tile scroll-reveal-stagger">
            {image_tag(src, title)}
            <h3>{escape(title)}</h3>
            <p>{escape(text)}</p>
        </article>
        """
        for src, title, text in [
            ("/assets/media/hero-screenshot.png", "Gameplay-Screenshot", "Der Hauptscreen gibt Ton, Beleuchtung und Traversal-Fläche des aktuellen Builds wieder."),
            ("/assets/media/joey.gif", "Joey in Bewegung", "Animierter Blick auf Joeys Slime-Form und die momentane Präsenz im Spiel."),
            ("/assets/media/bat.gif", "Cave Bat", "Die frühe Luftgegnerin aus Kapitel I und ein gutes Beispiel für kontrollierte Raumbedrohung."),
            ("/assets/media/sk.png", "Stimmung", "Ein dunklerer Blick auf die Tonalität des Projekts und den Höhlencharakter."),
        ]
    )
    facts = "".join(f"<li><strong>{escape(label)}</strong><span>{escape(value)}</span></li>" for label, value in MEDIA_FACTS)
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Media</span>
                <h1>Media, Press-Kit und offizielle Fakten</h1>
                <p class="page-lead">Diese Seite sammelt Material fuer Spieler, Presse und Creator: Screenshots, Kernfakten, Brand-Kontext, Demo-Wege und offizielle Kontaktpunkte.</p>
                <div class="hero-buttons">
                    <a href="/web_demo/" class="btn btn-large btn-magnetic">Demo öffnen</a>
                    <a href="https://github.com/JoshuaPondStudios/JoeysSlimeventure" class="btn btn-secondary btn-large" target="_blank" rel="noreferrer">Repository</a>
                </div>
            </div>
            <div class="hero-media-panel">
                <img src="/assets/media/hero-screenshot.png" alt="Joey's Slimeventure Screenshot">
            </div>
        </div>
    </header>
    <main>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Offizielle Präsenz</h2>
                    <p>Für Presse, Creator und interessierte Spieler: alle zentralen offiziellen Kanäle in einer durchgehenden Leiste.</p>
                </div>
                {social_loop()}
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="content-grid">
                    {gallery}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="content-grid content-grid--wide">
                    <article class="content-panel scroll-reveal-left">
                        <h3>Fact Sheet</h3>
                        <ul class="fact-list fact-list--stacked">{facts}</ul>
                    </article>
                    <article class="content-panel scroll-reveal-right">
                        <h3>Press-Notiz</h3>
                        <p>Die offizielle Website von Joey's Slimeventure verbindet Demo, Weltueberblick, Wiki, Media und Devlog in einer klaren Struktur. Dadurch finden Spieler und Presse das passende Material schneller und mit weniger Reibung.</p>
                        <p class="mini-note">Letzter sichtbarer Devlog-Eintrag: {escape(devlog['entries'][0]['subject'])}</p>
                        <div class="section-links">
                            <a href="/devlog/">Devlog lesen</a>
                            <a href="/about/">Entwickler ansehen</a>
                            <a href="mailto:contact@pondsec.com">Kontakt aufnehmen</a>
                        </div>
                    </article>
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Media und Press-Kit | {SITE_NAME}",
        description="Screenshots, Fact Sheet, offizielle Links und Press-Material von Joey's Slimeventure an einem zentralen Ort.",
        path="/media/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "MediaGallery", "name": "Joey's Slimeventure Media", "url": f"{SITE_URL}/media/"},
    )


def render_faq() -> str:
    faq_markup = "".join(
        f"""
        <details class="faq-item scroll-reveal" id="{escape(item['id'])}">
            <summary>{escape(item['question'])}</summary>
            <div class="faq-item__body">
                <p>{escape(item['answer'])}</p>
            </div>
        </details>
        """
        for item in FAQ_ENTRIES
    )
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">FAQ</span>
                <h1>Antworten zu Demo, Welt und Entwicklung</h1>
                <p class="page-lead">Hier liegen die wichtigsten Antworten zu Joey's Slimeventure an einem Ort, damit neue Besucher Demo, Plattformen, Progression und offizielle Links schnell finden.</p>
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="faq-list">
                    {faq_markup}
                </div>
            </div>
        </section>
    </main>
    """
    faq_ld = {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": item["question"], "acceptedAnswer": {"@type": "Answer", "text": item["answer"]}}
            for item in FAQ_ENTRIES
        ],
    }
    return page_shell(
        title=f"FAQ zu Demo, Welt und Fortschritt | {SITE_NAME}",
        description="Antworten auf Demo, Kapitel-Progression, Devlog, Wiki, Plattformen und offizielle Links von Joey's Slimeventure.",
        path="/faq/",
        body_class="page-inner",
        main_content=content,
        json_ld=faq_ld,
    )


def render_about(site_data: dict) -> str:
    facts = "".join(f"<li><strong>{escape(label)}</strong><span>{escape(value)}</span></li>" for label, value in ABOUT_FACTS)
    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Über</span>
                <h1>Joshua Pond und PondSec</h1>
                <p class="page-lead">Hier liegen die offiziellen Entwicklerinfos hinter Joey's Slimeventure: Joshua Pond, PondSec, Projektkontext und die wichtigsten Studio-Links an einem Ort.</p>
                <div class="hero-buttons">
                    <a href="https://pondsec.com" class="btn btn-large btn-magnetic" target="_blank" rel="noreferrer">PondSec</a>
                    <a href="https://portfolio.pondsec.com" class="btn btn-secondary btn-large" target="_blank" rel="noreferrer">Portfolio</a>
                </div>
            </div>
            <div class="hero-media-panel">
                <img src="/assets/media/joey.gif" alt="Joey Animation">
            </div>
        </div>
    </header>
    <main>
        <section class="section-dark">
            <div class="container">
                <div class="content-grid content-grid--wide">
                    <article class="content-panel scroll-reveal-left">
                        <h3>Entwicklungshintergrund</h3>
                        <p>Joey's Slimeventure waechst als atmosphaerischer Pixel-Art-Action-Platformer mit starkem Fokus auf Hoehlenstimmung, Traversal, Game-Feel und klarer Progression. Die offizielle Website soll genau dieses Bild fuer neue Spieler sauber transportieren.</p>
                        <p>Deshalb trennt die Seite Einstieg, Welt, Wiki, Devlog und Media bewusst nach Aufgaben. Das macht das Projekt professioneller, benutzerfreundlicher und suchmaschinenfreundlicher, ohne den Retro-Stil zu verlieren.</p>
                    </article>
                    <aside class="content-panel scroll-reveal-right">
                        <h3>Offizielle Links</h3>
                        <ul class="fact-list fact-list--stacked">{facts}</ul>
                        <div class="section-links">
                            <a href="https://github.com/JoshuaPondStudios/JoeysSlimeventure" target="_blank" rel="noreferrer">GitHub</a>
                            <a href="https://youtube.com/@pondsec" target="_blank" rel="noreferrer">YouTube</a>
                            <a href="mailto:contact@pondsec.com">E-Mail</a>
                        </div>
                    </aside>
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"Ueber Joshua Pond und PondSec | {SITE_NAME}",
        description="Joshua Pond, PondSec, Portfolio und offizielle Links hinter Joey's Slimeventure auf der offiziellen Entwicklerseite.",
        path="/about/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "ProfilePage", "name": "Joshua Pond", "url": f"{SITE_URL}/about/"},
    )


def render_reward() -> str:
    guide_cards = "".join(
        f"""
        <article class="content-panel scroll-reveal-stagger">
            <h3>{escape(title)}</h3>
            <p>{escape(text)}</p>
        </article>
        """
        for title, text in [
            ("Automatisch im Spiel", "Die Daily Rewards werden nicht auf der Website eingesammelt, sondern direkt beim Spielstart geprüft und im Build verfügbar gemacht."),
            ("Täglich neuer Pool", "Die Live-API zeigt dir den aktuellen Tagesstand, den Reward-Pool und den letzten Reset, damit klar bleibt, was heute wirklich aktiv ist."),
            ("Für Spieler gedacht", "Die Seite beantwortet auf einen Blick, was heute drin ist, wie der Reset funktioniert und wo du für Details zu Items und Progression weiterlesen kannst."),
        ]
    )

    content = f"""
    <header class="hero" id="main">
        <div class="hero-panel hero-panel--split scroll-reveal">
            <div class="hero-content">
                <span class="eyebrow">Daily Rewards</span>
                <h1>Tägliche Belohnungen ohne Umwege</h1>
                <p class="page-lead">Die Reward-Seite zeigt live, welche Bonus-Items heute aktiv sind, wann der nächste Reset kommt und wie das System im Spiel tatsächlich funktioniert.</p>
                <div class="hero-buttons">
                    <a href="/play/" class="btn btn-large btn-magnetic">Demo öffnen</a>
                    <a href="/wiki/items/" class="btn btn-secondary btn-large">Item-Wiki</a>
                </div>
                <div class="meta-pills">
                    <span class="pill"><strong>Quelle:</strong> Live-API</span>
                    <span class="pill"><strong>Vergabe:</strong> Automatisch im Spiel</span>
                    <span class="pill"><strong>Reset:</strong> Täglich um 00:00 Uhr</span>
                </div>
            </div>
            <div class="reward-hero-stack">
                <article class="content-panel reward-hero-card">
                    <h3>Heutiger Fokus</h3>
                    <p id="rewardHeadline">Belohnungen werden geladen…</p>
                    <div class="meta-pills reward-inline-pills">
                        <span class="pill"><strong>Nächster Reset:</strong> <span id="rewardNextReset">wird berechnet…</span></span>
                        <span class="pill"><strong>Pool-Größe:</strong> <span id="rewardPoolSize">—</span></span>
                    </div>
                </article>
                <div class="reward-preview-grid" aria-hidden="true">
                    <div class="reward-preview-item"><img src="/assets/media/bat_claw.png" alt=""></div>
                    <div class="reward-preview-item"><img src="/assets/media/gold_nugget.png" alt=""></div>
                    <div class="reward-preview-item"><img src="/assets/media/golem_heart.png" alt=""></div>
                    <div class="reward-preview-item reward-preview-item--wide"><img src="/assets/media/hero-screenshot.png" alt=""></div>
                </div>
            </div>
        </div>
    </header>
    <main data-reward-root="true">
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Live-Status</h2>
                    <p>Hier siehst du sofort, ob die API erreichbar ist, wann zuletzt zurückgesetzt wurde und wie groß der heutige Reward-Pool ist.</p>
                </div>
                <div class="content-grid content-grid--wide">
                    <article class="content-panel scroll-reveal-left">
                        <h3>Belohnungsstatus</h3>
                        <ul class="fact-list fact-list--stacked reward-status-list">
                            <li><strong>Heute aktiv</strong><span id="rewardTodaySummary">Belohnungen werden geladen…</span></li>
                            <li><strong>Letzter Reset</strong><span id="rewardLastReset">wird geladen…</span></li>
                            <li><strong>Nächster Reset</strong><span id="rewardCountdown">wird berechnet…</span></li>
                            <li><strong>Spieler-Daten</strong><span id="rewardPlayers">wird geladen…</span></li>
                            <li><strong>Server-Version</strong><span id="rewardServerVersion">wird geladen…</span></li>
                        </ul>
                    </article>
                    <aside class="content-panel scroll-reveal-right">
                        <h3>Wichtig zu wissen</h3>
                        <p>Du musst hier nichts anklicken, um Rewards freizuschalten. Die Seite ist ein Info-Hub: Sie zeigt dir transparent, was heute aktiv ist und führt dich dann zurück zu Demo, Welt oder Wiki.</p>
                        <p class="mini-note" id="rewardLiveMessage">Verbindung zur Reward-API wird aufgebaut…</p>
                        <div class="section-links">
                            <a href="/play/">Jetzt spielen</a>
                            <a href="/wiki/items/">Item-Wiki öffnen</a>
                            <a href="/faq/">FAQ lesen</a>
                        </div>
                    </aside>
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Heutige Belohnungen</h2>
                    <p>Die Live-Karten zeigen dir direkt die aktuellen Bonus-Items des Tages inklusive Kurzbeschreibung und Seltenheit.</p>
                </div>
                <div class="rewards-grid" id="rewardsGrid">
                    <div class="empty-state">Lade Belohnungen…</div>
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>So funktioniert das System</h2>
                    <p>Die Reward-Seite erklärt das Feature endlich klar, statt nur eine lose Liste von Items zu zeigen.</p>
                </div>
                <div class="content-grid">
                    {guide_cards}
                </div>
            </div>
        </section>
        <section>
            <div class="container">
                <div class="section-header scroll-reveal">
                    <h2>Belohnungspool</h2>
                    <p>Der komplette Pool zeigt, welche Items grundsätzlich in Rotation sind und wie selten sie eingeordnet werden.</p>
                </div>
                <div class="reward-pool-grid" id="rewardPoolGrid">
                    <div class="empty-state">Lade Reward-Pool…</div>
                </div>
            </div>
        </section>
        <section class="section-dark">
            <div class="container">
                <div class="cta-container scroll-reveal">
                    <a href="/play/" class="btn btn-large cta-primary btn-magnetic">
                        <i class="fas fa-rocket"></i>
                        Jetzt spielen und Rewards mitnehmen
                    </a>
                </div>
            </div>
        </section>
    </main>
    """
    return page_shell(
        title=f"{SITE_NAME} · Daily Rewards",
        description="Live-Daily-Rewards, Reward-Pool, Reset-Zeiten und direkter Weg zurück zu Joey's Slimeventure.",
        path="/reward/",
        body_class="page-inner",
        main_content=content,
        json_ld={"@context": "https://schema.org", "@type": "WebPage", "name": "Daily Rewards", "url": f"{SITE_URL}/reward/"},
        extra_head='<link rel="stylesheet" href="/assets/css/reward.css">',
        extra_scripts='<script src="/assets/js/reward.js" defer></script>',
        robots_content="noindex,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1",
    )


def image_tag(src: str, alt: str, eager: bool = False) -> str:
    width, height = {
        "/assets/media/hero-screenshot.png": (1920, 1080),
        "/assets/media/sk.png": (572, 778),
        "/assets/media/joey.gif": (512, 512),
        "/assets/media/bat.gif": (32, 32),
        "/assets/media/steam-title-capsule.png": (920, 430),
        "/assets/media/steam-vertical-capsule.png": (748, 896),
    }.get(src, (0, 0))
    attrs = [
        f'src="{escape(src)}"',
        f'alt="{escape(alt)}"',
        'decoding="async"',
    ]
    if width and height:
        attrs.append(f'width="{width}"')
        attrs.append(f'height="{height}"')
    if eager:
        attrs.append('fetchpriority="high"')
    else:
        attrs.append('loading="lazy"')
    return f"<img {' '.join(attrs)}>"


def organization_schema() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "Organization",
        "name": "PondSec",
        "url": "https://pondsec.com",
        "sameAs": SAME_AS_LINKS,
    }


def website_schema() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "name": SITE_NAME,
        "url": SITE_URL,
        "inLanguage": "de-DE",
        "publisher": {"@type": "Organization", "name": "PondSec"},
    }


def breadcrumb_schema(path: str) -> dict | None:
    if path == "/":
        return None

    items = [("/", "Start")]
    if path.startswith("/wiki/") and path != "/wiki/":
        items.append(("/wiki/", "Wiki"))
    label = BREADCRUMB_LABELS.get(path)
    if label:
        items.append((path, label))

    item_list = [
        {
            "@type": "ListItem",
            "position": index + 1,
            "name": name,
            "item": f"{SITE_URL}{href}",
        }
        for index, (href, name) in enumerate(items)
    ]
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": item_list,
    }


def schema_documents(page_schema: dict, path: str) -> list[dict]:
    documents = [website_schema(), organization_schema()]
    breadcrumb = breadcrumb_schema(path)
    if breadcrumb:
        documents.append(breadcrumb)
    documents.append(page_schema)
    return documents


def page_shell(
    title: str,
    description: str,
    path: str,
    body_class: str,
    main_content: str,
    json_ld: dict,
    extra_head: str = "",
    extra_scripts: str = "",
    robots_content: str = "index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1",
) -> str:
    canonical = f"{SITE_URL}{path}"
    page_title = escape(title)
    page_description = escape(description)
    og_image = f"{SITE_URL}{DEFAULT_IMAGE}"
    json_ld_markup = json.dumps(schema_documents(json_ld, path), ensure_ascii=False)
    body = f"""<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{page_title}</title>
    <meta name="description" content="{page_description}">
    <meta name="robots" content="{escape(robots_content)}">
    <meta name="theme-color" content="#050505">
    <meta name="author" content="Joshua Pond">
    <meta property="og:title" content="{page_title}">
    <meta property="og:description" content="{page_description}">
    <meta property="og:type" content="website">
    <meta property="og:url" content="{canonical}">
    <meta property="og:image" content="{og_image}">
    <meta property="og:image:width" content="1920">
    <meta property="og:image:height" content="1080">
    <meta property="og:locale" content="de_DE">
    <meta property="og:site_name" content="{escape(SITE_NAME)}">
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{page_title}">
    <meta name="twitter:description" content="{page_description}">
    <meta name="twitter:image" content="{og_image}">
    <meta name="twitter:image:alt" content="Screenshot aus Joey's Slimeventure">
    <link rel="canonical" href="{canonical}">
    <link rel="icon" href="/logo.ico">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Press+Start+2P&family=VT323&display=swap">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="/assets/css/site.css">
    {extra_head}
    <script type="application/ld+json">{json_ld_markup}</script>
</head>
<body class="{escape(body_class)}" data-current-path="{escape(path)}">
    <a class="skip-link" href="#main">Zum Hauptinhalt springen</a>
    <div class="loading-bar" id="loadingBar"></div>
    {nav(path)}
    {main_content}
    <button class="quick-finder" id="quickFinderOpen" type="button" aria-label="Schnellfinder öffnen">
        <i class="fas fa-compass" aria-hidden="true"></i>
    </button>
    <div class="site-command" id="siteCommand" hidden aria-hidden="true">
        <button class="site-command__backdrop" type="button" data-command-close aria-label="Schnellfinder schließen"></button>
        <div class="site-command__panel" role="dialog" aria-modal="true" aria-labelledby="siteCommandTitle">
            <div class="site-command__header">
                <div>
                    <p class="site-command__eyebrow">Schnellfinder</p>
                    <h2 id="siteCommandTitle">Finde Demo, Wiki, Kapitel und Kanäle sofort</h2>
                </div>
                <button class="site-command__close" type="button" data-command-close aria-label="Schnellfinder schließen">
                    <i class="fas fa-xmark" aria-hidden="true"></i>
                </button>
            </div>
            <p class="site-command__hint">Für neue Besucher und Spieler: schnell zur Demo, zum Wiki, zu Daily Rewards, GitHub, TikTok und den wichtigsten Seiten springen.</p>
            <input id="siteCommandInput" class="toolbar-input site-command__input" type="search" placeholder="Seite, Feature oder Kanal suchen">
            <div class="site-command__results" id="siteCommandResults"></div>
        </div>
    </div>
    {footer()}
    <button class="cursor-toggle" id="cursorToggle" type="button" aria-label="Spezialcursor umschalten" aria-pressed="true">
        <i class="fas fa-crosshairs" aria-hidden="true"></i>
    </button>
    <button class="back-to-top" id="backToTop" aria-label="Zurück nach oben"><i class="fas fa-chevron-up"></i></button>
    {extra_scripts}
    <script src="/assets/js/site.js" defer></script>
</body>
</html>
"""
    return body


def nav(active_path: str) -> str:
    links = []
    for href, label in NAV_ITEMS:
        classes = []
        aria_current = ""
        if href == active_path:
            classes.append("active")
            aria_current = ' aria-current="page"'
        if href == "/shop/":
            classes.append("shop-link")
        if href == "/reward/":
            classes.append("reward-link")
        class_attr = f' class="{" ".join(classes)}"' if classes else ""
        links.append(f'<a href="{href}"{class_attr}{aria_current}>{escape(label)}</a>')
    return f"""
    <nav class="main-nav" aria-label="Hauptnavigation">
        <div class="nav-container">
            <a href="/" class="logo"><span class="logo-title">Slimeventure</span><span class="logo-sub">Official Site</span></a>
            <div class="nav-links" id="site-navigation">
                {''.join(links)}
            </div>
            <button class="hamburger-menu" id="hamburger-menu" aria-label="Menü öffnen" aria-expanded="false" aria-controls="site-navigation">
                <div class="bar"></div>
                <div class="bar"></div>
                <div class="bar"></div>
            </button>
        </div>
    </nav>
    """


def footer() -> str:
    nav_links = "".join(f'<li><a href="{href}">{escape(label)}</a></li>' for href, label in NAV_ITEMS[:-1])
    quick_links = """
        <li><a href="/web_demo/">Demo spielen</a></li>
        <li><a href="/shop/">Steam Shop</a></li>
        <li><a href="/world/">Kapitel & Welt</a></li>
        <li><a href="/wiki/">Game Wiki</a></li>
        <li><a href="/devlog/">Git-Devlog</a></li>
        <li><a href="/reward/">Daily Rewards</a></li>
    """
    return f"""
    <footer>
        <div class="footer-content">
            <div class="footer-column footer-column--brand">
                <h3>Slimeventure</h3>
                <p class="footer-copy">
                    Die offizielle Website zu Joey's Slimeventure mit Browser-Demo, Gameplay-Ueberblick, Welt, Wiki, Devlog und offiziellen Projektlinks.
                </p>
                <div class="footer-status">
                    <span class="footer-pill">Browser-Demo</span>
                    <span class="footer-pill">Steam Shop live</span>
                    <span class="footer-pill">Kapitel I spielbar</span>
                    <span class="footer-pill">Wiki & Devlog</span>
                </div>
                <div class="social-links">
                    <a href="https://store.steampowered.com/app/4536840/Joeys_Slimeventure/" class="social-link" target="_blank" rel="noreferrer" aria-label="Steam"><i class="fab fa-steam"></i></a>
                    <a href="https://github.com/JoshuaPondStudios/JoeysSlimeventure" class="social-link" target="_blank" rel="noreferrer" aria-label="GitHub"><i class="fab fa-github"></i></a>
                    <a href="https://www.tiktok.com/@joeysslimeventure" class="social-link" target="_blank" rel="noreferrer" aria-label="TikTok"><i class="fab fa-tiktok"></i></a>
                    <a href="https://youtube.com/@pondsec" class="social-link" target="_blank" rel="noreferrer" aria-label="YouTube"><i class="fab fa-youtube"></i></a>
                    <a href="https://pondsec.com" class="social-link" target="_blank" rel="noreferrer" aria-label="PondSec"><i class="fas fa-globe"></i></a>
                </div>
            </div>
            <div class="footer-column">
                <h3>Schnell rein</h3>
                <ul class="footer-links">{quick_links}</ul>
            </div>
            <div class="footer-column">
                <h3>Seiten</h3>
                <ul class="footer-links">{nav_links}</ul>
            </div>
            <div class="footer-column">
                <h3>Offiziell</h3>
                <ul class="footer-links">
                    <li><a href="https://store.steampowered.com/app/4536840/Joeys_Slimeventure/" target="_blank" rel="noreferrer">Steam</a></li>
                    <li><a href="https://github.com/JoshuaPondStudios/JoeysSlimeventure" target="_blank" rel="noreferrer">GitHub</a></li>
                    <li><a href="https://www.tiktok.com/@joeysslimeventure" target="_blank" rel="noreferrer">TikTok</a></li>
                    <li><a href="https://pondsec.com" target="_blank" rel="noreferrer">PondSec</a></li>
                    <li><a href="https://portfolio.pondsec.com" target="_blank" rel="noreferrer">Portfolio</a></li>
                    <li><a href="https://pondsec.itch.io/joeys-slimeventure" target="_blank" rel="noreferrer">Itch.io</a></li>
                    <li><a href="mailto:contact@pondsec.com">Kontakt</a></li>
                    <li><a href="https://pondsec.com/impressum" target="_blank" rel="noreferrer">Impressum</a></li>
                </ul>
            </div>
        </div>
        <div class="copyright">
            <p>&copy; 2026 Joey's Slimeventure. Alle Rechte vorbehalten.</p>
        </div>
    </footer>
    """


def social_loop() -> str:
    items = [
        ("fab fa-steam", "Steam", "https://store.steampowered.com/app/4536840/Joeys_Slimeventure/"),
        ("fab fa-github", "GitHub", "https://github.com/JoshuaPondStudios/JoeysSlimeventure"),
        ("fab fa-tiktok", "TikTok", "https://www.tiktok.com/@joeysslimeventure"),
        ("fab fa-youtube", "YouTube", "https://youtube.com/@pondsec"),
        ("fas fa-gamepad", "Itch.io", "https://pondsec.itch.io/joeys-slimeventure"),
        ("fas fa-globe", "PondSec", "https://pondsec.com"),
        ("fas fa-address-card", "Portfolio", "https://portfolio.pondsec.com"),
    ]
    item_markup = "\n                    ".join(
        f'<a class="social-loop__item" href="{escape(href)}" target="_blank" rel="noreferrer" aria-label="{escape(label)}">'
        f'<i class="{escape(icon)}" aria-hidden="true"></i><span>{escape(label)}</span></a>'
        for icon, label, href in items
    )
    return f"""
    <div class="social-loop scroll-reveal" aria-label="Offizielle Kanäle">
        <div class="social-loop__viewport">
            <div class="social-loop__track">
                <div class="social-loop__group">
                    {item_markup}
                </div>
                <div class="social-loop__group" aria-hidden="true">
                    {item_markup}
                </div>
            </div>
        </div>
    </div>
    """


def feature_card(icon: str, title: str, text: str) -> str:
    return f"""
    <article class="feature-card scroll-reveal-stagger">
        <div class="feature-icon"><i class="fas {escape(icon)}"></i></div>
        <h3>{escape(title)}</h3>
        <p>{escape(text)}</p>
    </article>
    """


def starter_card(step: str, title: str, text: str, href: str, label: str) -> str:
    return f"""
    <article class="content-panel starter-card scroll-reveal-stagger">
        <span class="starter-card__step">{escape(step)}</span>
        <h3>{escape(title)}</h3>
        <p>{escape(text)}</p>
        <a class="starter-card__link" href="{escape(href)}">{escape(label)}</a>
    </article>
    """


def chapter_panel(chapter: dict) -> str:
    return f"""
    <article class="content-panel scroll-reveal-stagger">
        <h3>Kapitel {escape(chapter['roman'])} · {escape(chapter['short_title'])}</h3>
        <p>{escape(chapter['description'])}</p>
        <ul class="fact-list fact-list--stacked">
            <li><strong>Status</strong><span>{escape(chapter['status'])}</span></li>
            <li><strong>Boss</strong><span>{escape(chapter['boss'] or 'Noch offen')}</span></li>
            <li><strong>Skill</strong><span>{escape(chapter['skill_unlock'] or 'Noch offen')}</span></li>
            <li><strong>Signatur</strong><span>{escape(chapter['signature'])}</span></li>
        </ul>
    </article>
    """


def devlog_entry(entry: dict, filtered: bool = False) -> str:
    attrs = ""
    if filtered:
        attrs = (
            f' data-devlog-entry="true"'
            f' data-category="{escape(entry["category"])}"'
            f' data-search="{escape((entry["subject"] + " " + entry["summary"] + " " + entry.get("body", "")).lower())}"'
        )
    return f"""
    <article class="timeline-entry scroll-reveal"{attrs}>
        <div class="devlog-entry__meta">
            <span class="pill">{escape(entry['date'])}</span>
            <span class="pill">{escape(entry['category'])}</span>
            <span class="pill">{escape(entry['hash_short'])}</span>
        </div>
        <h3>{escape(entry['subject'])}</h3>
        <p class="devlog-entry__summary">{escape(entry['summary'])}</p>
        <p class="devlog-entry__body">{escape(entry.get('body') or 'Kein zusätzlicher Commit-Text hinterlegt.')}</p>
    </article>
    """


def enemy_tile(enemy: dict) -> str:
    image = image_tag(enemy["image"], enemy["name"]) if enemy.get("image") else ""
    return f"""
    <article class="media-tile scroll-reveal-stagger">
        {image}
        <h3>{escape(enemy['name'])}</h3>
        <p>{escape(enemy['description'])}</p>
        <ul class="fact-list">
            <li><strong>Biom</strong><span>{escape(enemy['biome'])}</span></li>
            <li><strong>Rolle</strong><span>{escape(enemy['role'])}</span></li>
            <li><strong>Leben</strong><span>{escape(str(enemy['health']))}</span></li>
            <li><strong>Kontakt</strong><span>{escape(str(enemy['contact_damage']))}</span></li>
            <li><strong>Signatur</strong><span>{escape(enemy['signature'])}</span></li>
        </ul>
    </article>
    """


def item_tile(item: dict) -> str:
    image = image_tag(item["image"], item["name"]) if item.get("image") else ""
    bonus_list = ''.join(f'<li><strong>{escape(bonus["label"])}</strong><span>{escape(bonus["value"])}</span></li>' for bonus in item.get("bonuses", []))
    return f"""
    <article class="media-tile scroll-reveal-stagger">
        {image}
        <h3>{escape(item['name'])}</h3>
        <p>{escape(item['description'])}</p>
        <ul class="fact-list">
            <li><strong>Art</strong><span>{escape(item['kind'])}</span></li>
            <li><strong>Seltenheit</strong><span>{escape(item['rarity'])}</span></li>
            <li><strong>Drop-Chance</strong><span>{escape(item.get('drop_chance') or 'Nicht gesetzt')}</span></li>
            <li><strong>Wurf-Schaden</strong><span>{escape(str(item.get('throw_damage') or '0'))}</span></li>
            {bonus_list}
        </ul>
    </article>
    """


def link_card(href: str, title: str, text: str) -> str:
    return f"""
    <a class="link-card scroll-reveal-stagger" href="{href}">
        <h3>{escape(title)}</h3>
        <p>{escape(text)}</p>
    </a>
    """


def community_section() -> str:
    return """
    <section id="community" class="section-dark">
        <div class="container">
            <div class="section-header scroll-reveal">
                <h2>Community und Feedback</h2>
                <p>Wer Joey's Slimeventure spannend findet, kann das Projekt direkt auf der offiziellen Startseite unterstuetzen und Feedback hinterlassen.</p>
            </div>
            <div class="community-content">
                <div class="like-section scroll-reveal">
                    <div class="like-container">
                        <h3>Unterstuetze das Projekt</h3>
                        <div class="like-stats">
                            <span class="like-count" id="totalLikes">0</span>
                            <span class="like-label">Likes</span>
                        </div>
                        <button class="btn btn-accent like-btn" id="likeBtn" type="button">
                            <i class="fas fa-thumbs-up"></i>
                            <span class="btn-text">Gefällt mir</span>
                        </button>
                        <div class="like-message" id="likeMessage"></div>
                    </div>
                </div>
                <div class="comments-section scroll-reveal">
                    <div class="comments-header">
                        <h3>Kommentare & Feedback</h3>
                        <div class="comments-controls">
                            <select id="sortComments">
                                <option value="newest">Neueste zuerst</option>
                                <option value="oldest">Älteste zuerst</option>
                                <option value="popular">Beliebteste</option>
                            </select>
                        </div>
                    </div>
                    <div class="comment-form-container">
                        <form id="commentForm" class="comment-form">
                            <div class="form-group">
                                <label for="username">Name:</label>
                                <input type="text" id="username" name="username" maxlength="30" required placeholder="Dein Name" class="form-control">
                            </div>
                            <div class="form-group">
                                <label for="commentContent">Kommentar:</label>
                                <textarea id="commentContent" name="content" maxlength="500" required placeholder="Teile deine Gedanken zum Spiel..." class="form-control"></textarea>
                                <div class="char-counter"><span id="charCount">0</span>/500 Zeichen</div>
                            </div>
                            <button type="submit" class="btn btn-primary"><i class="fas fa-paper-plane"></i> Kommentar posten</button>
                        </form>
                    </div>
                    <div class="comments-list" id="commentsList">
                        <div class="loading-comments">Lade Kommentare...</div>
                    </div>
                    <div class="comments-pagination" id="commentsPagination">
                        <button class="btn btn-secondary pagination-btn" id="prevPage" type="button"> <i class="fas fa-chevron-left"></i> Zurück</button>
                        <span class="page-info" id="pageInfo">Seite 1 von 1</span>
                        <button class="btn btn-secondary pagination-btn" id="nextPage" type="button">Weiter <i class="fas fa-chevron-right"></i></button>
                    </div>
                </div>
            </div>
        </div>
    </section>
    """


def breadcrumb(parent_href: str, parent_title: str, current: str) -> str:
    return f"""
    <div class="container">
        <div class="breadcrumb">
            <a href="/">Start</a>
            <a href="{parent_href}">{escape(parent_title)}</a>
            <span>{escape(current)}</span>
        </div>
    </div>
    """


def pill(label: str, value: str) -> str:
    return f'<span class="pill"><strong>{escape(label)}:</strong> {escape(value)}</span>'


def pretty_label(raw: str) -> str:
    return raw.replace("_", " ").title()


if __name__ == "__main__":
    main()
