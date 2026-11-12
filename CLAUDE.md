# Yomicha – Hinweise für Claude

Leonis eigene Lese-App für die JLPT N2 (Prüfung Sonntag, 5.12.2027). Flutter-Web-App
auf GitHub Pages (`thatlionfish/Yomicha`), ohne Server. Mit Leoni wird **Deutsch** gesprochen.
Die Spezifikation `SPEZIFIKATION.md` liegt nur lokal (gitignored) – vor größeren Änderungen lesen.

## Feste Regeln

- **Keine Kosten.** Nichts darf von selbst etwas kosten. Azure nur in der Gratis-Stufe F0;
  droht eine Grenze, anhalten und Leoni Bescheid geben (`web/data/status.json`).
- **Sonntag ist Ruhetag:** keine neuen Texte, nichts fällig, die Lernserie läuft weiter.
- **Heisig:** Nie Heisigs Schlüsselwörter, Elementnamen oder Geschichten ins Repository
  (öffentlich, urheberrechtlich geschützt). Eigene Ergänzungen: `tool/teekueche/kanji_extra.json`.
- **Commit/Push:** nur, wenn Leoni es sagt. Ausnahme: Die Teeküche darf neue Inhalte unter
  `web/data/` selbst committen und pushen, nie Code.
- Schlüssel liegen in `werkstatt/*.env` – nie ausgeben, nie committen.
- Kumachan ist ein Mädchen: in allen Texten „sie/ihr“.

## Teeküche (neue Texte)

Texte: `web/data/texte/<jahr>/<monat>/<id>/text.json`, Verzeichnis `web/data/texte/index.json`.
Format siehe `lib/data/models.dart` und den Beispieltext. Jeder Inhalt wird in Stufen
geschrieben (Stufen 1–7 nach Teesorten, `lib/data/stufen.dart`).

**Leonis Stufe:** Die App kann sie der Teeküche nicht melden (Lernstand nur auf dem Gerät).
Sagt Leoni ihre neue Stufe („Meine Stufe ist jetzt 3“), `stufe` in `tool/teekueche/config.json`
anpassen und nach ihrem OK committen. Welche Stufen die Teeküche heute schreibt, rechnet
`stufen_heute.py`: Leonis Stufe und eine darüber (zwei Fassungen pro Text). Keinen Vorrat; für Ferien das Ferienpaket.

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\stufen_heute.py            # Stufen für heute
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\pruefen.py --uebernehmen   # Lesungen (Sudachi), JLPT-Stufen
dart run tool/tts.dart                                                               # Aufnahmen (Nanami, Kumachan: Aoi)
dart run tool/tts.dart --hoerkontrolle                                               # Satzaufnahmen gegen die Lesung prüfen
flutter test                                                                         # prüft jeden Text
```

## Entwicklung

```
flutter analyze
flutter test
flutter build web && dart run tool/serve.dart    # Vorschau http://localhost:8123
dart run tool/gen_kuma.dart                      # Kumachans Posen neu zeichnen
flutter test tool/render_icon_test.dart          # App-Icon (lib/ui/app_icon.dart) in alle Größen rendern
```

- Design: Wabi-Sabi wie LearnwithLeoni, Farben in `lib/ui/colors.dart`; Lemon Grass nur als Detail, kein Rot.
- Oberfläche Deutsch, Inhalte Japanisch, Erklärungen Deutsch.
- Japanische Schriften: Zen Old Mincho (Text), Klee One (Kanji-Karten), verkleinert mit `tool/teekueche/schriften.py`.
- Kanji-Karten neu bauen: `tool/teekueche/kanji_daten.py` (Rohdaten in `werkstatt/quellen/`, nicht veröffentlicht).
