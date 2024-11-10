# Dungeon Slayer

*Dungeon Slayer* ist ein Beta-Projekt, entwickelt in der Godot 4.3 Engine. Es ist ein spannendes Plattformspiel, bei dem Spieler Levels meistern, verschiedene Gegner besiegen und sich gegen mächtige Mini-Bosse behaupten müssen.

## Spielbeschreibung

In *Dungeon Slayer* steuerst du deinen Charakter durch herausfordernde Dungeons, meisterst komplexe Plattform-Abschnitte und kämpfst gegen eine Vielzahl von Feinden. Jeder Dungeon bietet eine Mischung aus schnellen Reflexen, cleverem Manövrieren und intensiven Kämpfen.

## Technische Details

### 1. **Spielumgebung**
   - Das Spiel besteht aktuell aus zwei Layern: **Background** und **Foreground**.
     - **Background**: Statische oder sich langsam bewegende Grafiken, die die Tiefe und Atmosphäre der Dungeons verstärken.
     - **Foreground**: Der Layer, in dem sich der Spieler und alle interaktiven Objekte befinden. Hier spielt sich die Action ab.
   - Die **Kamera** ist so konfiguriert, dass sie den Spieler weich und dynamisch verfolgt. Das sorgt für eine angenehme Spielerfahrung, da die Bewegungen des Spielers nicht abrupt abgeschnitten werden.

### 2. **Spielerobjekt**
   - Der Hauptcharakter ist durch das **"PlayerModel"**-Objekt in der Godot-Engine implementiert. Dieses Objekt basiert auf der `CharacterBody2D`-Klasse, was bedeutet, dass es über eingebaute Funktionen zur Handhabung von Bewegung und Kollision verfügt.
   - Der Code steuert die Bewegung, Sprunganimation und Gravitationslogik des Spielers.

### 3. **Spielmechanik: Bewegung und Sprung**
   - Der Spieler hat zwei Hauptbewegungsmechaniken: **Laufen** und **Springen**.
   - Im Skript sind zwei Konstanten definiert:
     - `SPEED = 300.0`: Die Geschwindigkeit, mit der sich der Spieler nach links oder rechts bewegt.
     - `JUMP_VELOCITY = -600.0`: Die Geschwindigkeit, mit der der Spieler beim Springen nach oben katapultiert wird.
   - **Laufrichtung**: Eine `Vector2`-Variable namens `direction` wird verwendet, um die aktuelle Richtung der Bewegung zu speichern.

### 4. **Hauptlogik im `_physics_process`**
   - Die `_physics_process`-Funktion sorgt dafür, dass die Physikberechnungen des Spielers kontinuierlich ausgeführt werden.
   - **Gravitation**: Wird auf den Spieler angewendet, wenn er sich nicht auf dem Boden befindet, um eine realistische Fallbewegung zu simulieren.
   - **Springen**: Der Spieler kann springen, wenn die "up"-Taste gedrückt wird und sich der Spieler auf dem Boden befindet.
   - **Horizontale Bewegung**: Die Richtung wird durch die Eingaben "left" und "right" gesteuert. Die Geschwindigkeit des Spielers wird entsprechend angepasst.
   - **Verlangsamung**: Wenn keine Eingabe erfolgt, wird die Geschwindigkeit des Spielers allmählich auf null reduziert.
   - **Kollisionsvermeidung**: Die `move_and_slide()`-Methode wird verwendet, um den Spieler sanft über Oberflächen gleiten zu lassen und Kollisionen zu handhaben.

### 5. **Animationen**
   - Der Code sorgt dafür, dass der Spieler abhängig von der Bewegung die richtige Animation abspielt:
     - Wenn der Spieler sich nach links bewegt, wird das Sprite gespiegelt und die "walk"-Animation gestartet.
     - Wenn der Spieler sich nach rechts bewegt, bleibt das Sprite unverändert und die "walk"-Animation wird abgespielt.
     - Wenn der Spieler still steht, wird die "idle"-Animation abgespielt.
     - Wenn der Spieler in der Luft ist, wird die "jump"-Animation aktiviert.

### 6. **Zusätzliche Funktionen**
   - **`set_animation()`**: Eine Funktion, die für das Umschalten der Animationen zuständig ist.
   - **`is_in_air()`**: Eine Hilfsfunktion, die überprüft, ob sich der Spieler in der Luft befindet oder auf dem Boden steht.

## Installation und Ausführung

1. Lade die neueste Version von *Dungeon Slayer* von [diesem Repository](#) herunter.
2. Öffne das Projekt mit Godot 4.3 oder einer kompatiblen Version.
3. Führe das Spiel im Godot-Editor aus oder exportiere es für die gewünschte Plattform.

## Lizenz und Verbreitung

Die Beta-Version des Spiels ist frei verfügbar, darf jedoch nicht ohne ausdrückliche Erlaubnis von **Joshua Pond Studios** verändert oder kommerziell verbreitet werden. Für Anfragen zur Verbreitung oder kommerziellen Nutzung, kontaktiere uns bitte.

---

**Hinweis**: Diese README bietet einen Überblick über die aktuelle Version der Spielmechanik und wird mit zukünftigen Updates angepasst.
