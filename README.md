# Yomicha 読み茶

Kurze japanische Texte – so lang wie eine Tasse Tee – bis zur JLPT N2.
Flutter-Web-App auf GitHub Pages, ohne Server: https://thatlionfish.github.io/Yomicha/

## Entwickeln

```
flutter pub get
flutter analyze
flutter test
flutter build web
dart run tool/serve.dart        # Vorschau auf http://localhost:8123
```

## Teeküche (Inhalte)

- Texte: `web/data/texte/<jahr>/<monat>/<id>/text.json`, Verzeichnis `web/data/texte/index.json`
- Lesungen und Stufe prüfen (Sudachi und JLPT-Liste):
  `tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\pruefen.py` (mit `--uebernehmen` werden die JLPT-Stufen eingetragen)
- Aufnahmen: `dart run tool/tts.dart` (Stimme ja-JP-NanamiNeural; `--dry` zeigt nur an)
- Schlüssel in `werkstatt/*.env` – nie veröffentlichen (siehe `.gitignore`)
- `test/data_test.dart` prüft jeden Text: Lesungen, Fragen, Länge der Stufe, Aufnahmen

## Kanji-Karten und Schriften neu bauen

Die Rohdaten liegen in `werkstatt/quellen/` (nicht veröffentlicht): KanjiVG, KANJIDIC2,
JLPT-Listen, Zen Old Mincho, Klee One.

```
python -m venv tool\teekueche\.venv
tool\teekueche\.venv\Scripts\python.exe -m pip install sudachipy sudachidict_core fonttools
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\kanji_daten.py werkstatt\quellen
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\schriften.py werkstatt\quellen
```

Eigene Ergänzungen (deutsche Bedeutung, Schlüsselwort, Merkgeschichte) stehen in
`tool/teekueche/kanji_extra.json` – nie Heisigs Schlüsselwörter oder Geschichten.

## Lizenzen

Code: MIT. Daten und Texte: CC BY-SA 4.0. Schriften: SIL Open Font License.
Alle Quellen: [LIZENZEN.md](LIZENZEN.md).
