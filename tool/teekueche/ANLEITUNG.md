# Teeküche – der tägliche Lauf

Diese Anleitung befolgt Claude jeden Morgen (Montag bis Samstag) als geplante Aufgabe.
Ziel: **2 neue Texte**, jeder in **4 Stufen**, geprüft, vertont und veröffentlicht.

Arbeitsordner: `C:\dev\Apps\Study\yomicha`. Mit Leoni wird Deutsch gesprochen.

## Feste Regeln

- **Sonntag ist Ruhetag:** Ist heute Sonntag, nichts erzeugen und sofort aufhören.
- **Keine Kosten:** Azure ab dem 4.12.2026 nur mit dem Gratis-Zugang (F0). Meldet `tool/tts.dart`
  eine Kostengrenze, keine weiteren Aufnahmen erzeugen.
- **Veröffentlichen:** Nur Dateien unter `web/data/` committen und pushen, nie Code.
- **Heisig:** Nie Schlüsselwörter, Elementnamen oder Geschichten aus Heisigs Buch verwenden.
- **Eigene Texte:** Nachrichten nie abschreiben, sondern aus mehreren Quellen einen eigenen Text schreiben.
  Sachlich, ohne reißerische oder belastende Details.
- Kumachan ist ein Mädchen („sie/ihr“).

## 1. Vorbereiten

1. Datum prüfen (Zeitzone Tokio). Sonntag → aufhören.
2. `tool/teekueche/config.json` lesen: `stufe` (Leonis Stufe), `themen` (Anteile), `jlpt_themen`, `textarten`.
   **Die Stufen für heute** liefert
   `tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\stufen_heute.py` (Feld `stufen`):
   Leonis Stufe plus Fenster, nach oben der Zielkurve folgend, höchstens fünf Stufen.
   So stehen schwerere Texte bereit, wenn sie in der App aufsteigt.
3. `web/data/texte/index.json` lesen.
   - Gibt es für heute schon Texte (Ferienpaket oder Vorrat), nichts Neues erzeugen.
   - Themen und Textarten der letzten 7 Tage merken, damit sich nichts wiederholt.

## 2. Themen wählen

- **Text 1, aktuell:** Weltgeschehen, Mode oder Tee, gewichtet nach `themen`. Bei Weltgeschehen mit der
  Websuche die Meldungen der letzten 48 Stunden in mehreren seriösen Quellen lesen (z. B. NHK, Reuters,
  BBC, Asahi). Für Mode und Tee ist auch ein zeitloser Hintergrundtext in Ordnung.
- **Text 2, JLPT-Thema:** eines aus `jlpt_themen`, das in den letzten 10 Texten nicht vorkam.
- Je Text eine Textart aus `textarten`, abwechselnd (Nachricht, Essay, Meinung, Aushang, E-Mail, Infoblatt).
- **Text 3, Vorrat** (nur bis `vorrat_bis` in config.json, Aufbaupaket): ein **zeitloser** Inhalt – Mode, Tee
  oder ein JLPT-Thema, keine Nachricht – in denselben Stufen wie heute, im Entwurf `"vorrat": true`.
  Die App zeigt Vorrat-Texte nur, wenn keine neuen Texte da sind (PC aus, Ferien), und `aufraeumen.py`
  löscht sie nie. Themen und Textarten breit streuen; nichts, was in den letzten 10 Texten vorkam.

## 3. Entwürfe schreiben

Für jedes Thema und jede Stufe einen Entwurf `werkstatt/entwuerfe/<datum>-<thema-kurz>-<stufe>.json`.
Das Format steht in `tool/teekueche/zerlegen.py` (Kopf der Datei); zwei fertige Beispiele liegen in
`tool/teekueche/beispiele/`. Alle Stufen erzählen denselben Inhalt, jede Fassung ist **für ihre Stufe
neu geschrieben**, nicht nur gekürzt.

| Stufe | Name | JLPT | Länge (Zeichen) | Stil |
|---|---|---|---|---|
| 1 | Bancha | N5 | 120–200 | です/ます, kurze Sätze, fast nur N5-Kanji |
| 2 | Hōjicha | N4 | 150–250 | です/ます wie Memo, Brief, Aushang oder Tagebuch der N4 – kein Blog-Plauderton |
| 3 | Genmaicha | N3 leicht | 200–300 | Schriftform (だ) in Nachricht, Essay, Meinung; 2–3 neue N3-Muster |
| 4 | Sencha | N3 | 250–400 | Schriftform (だ / である), Zeitungston; mehr 漢語 (増加する, 行う) |
| 5 | Kabusecha | N2 leicht | 300–450 | Schriftsprache der N2 (である, 〜ており, 〜に伴い, 〜ものの), E-Mails mit Keigo; 2–3 neue N2-Muster |
| 6 | Gyokuro | N2 | 350–550 | wie in der N2-Leseprüfung: lange Sätze, Meinung des Verfassers, Geschäfts-E-Mail, Mitteilung |
| 7 | Matcha | N2+ | 400–700 | wie 6, dazu zwei Texte im Vergleich (統合理解) oder Infoblatt (情報検索) |

**Der Stil wächst mit der Stufe – das Ziel ist die Sprache der Prüfung, nicht die Sprache eines Blogs.**
- **Stufe 1–2:** höflich und einfach. Höchstens zwei Plauder-Stellen pro Text (Satzende ね/よ, „みなさんも…てください“, 〜し).
  Textarten wie in der N4: kurze Mitteilung, Brief/E-Mail, Aushang, Tagebuch, Infotext.
- **Ab Stufe 3:** in Nachricht, Essay und Meinung **Schriftform, keine gesprochene Sprache**: kein ね/よ am Satzende,
  keine Kurzformen (〜てる, 〜ちゃう, 〜とく, 〜なきゃ, じゃ, って, けど), keine Umgangswörter (すごく, やっぱり,
  ちょっと, いっぱい), kein でも/だけど am Satzanfang (しかし, だが), keine Ausrufezeichen.
  です/ます nur in E-Mail, Aushang und Infoblatt. Wörtliche Rede in 「」 darf gesprochen klingen.
- **Ab Stufe 5:** Schriftsprache wie im Leseteil der N2 – in jedem Text mehrere Ausdrücke wie である, 〜ており,
  〜とされる, 〜に伴い, 〜につれ, 〜ものの, 〜わけではない, 〜にほかならない, 〜をめぐって. E-Mails und Mitteilungen
  mit **Keigo** (いたします, 申し上げます, いただけますでしょうか, ございます), wie Firmen sie schreiben.
- **Fragen ab Stufe 5** im Wortlaut der N2: „筆者の考えに合うのはどれか“, „〜とあるが、それはなぜか“,
  „このメールで一番伝えたいことは何か“. Ab Stufe 6 auch Fragen zum ganzen Text (主張理解).
- **Grammatik:** Muster wählen, die in den letzten 30 Texten noch nicht vorkamen (`grammar` der Texte in
  `web/data/texte/` ansehen), ab Stufe 5 vor allem Muster der N2. So kommt über das Jahr die ganze N2-Grammatik dran.
- `pruefen.py` prüft den Stil (`STIL …`). Fehler dort heißen: **die Fassung umschreiben**, nicht nur das Wort tauschen.

Für jeden Entwurf:
- **Glossar:** deutsche Bedeutung für jedes Inhaltswort, passend zum Satz (Schlüssel: Schreibung,
  Grundform oder `"Satz:Schreibung"` für eine Stelle). Namen mit kurzer Erklärung („Kōenji (Stadtviertel in Tokio)“).
- **Grammatik:** 2–5 Muster der Stufe, jedes mit Erklärung auf Deutsch, Beispielsatz in Ruby-Schreibweise
  (`{漢字|かんじ}`) mit Übersetzung, und `stellen` (Satz ab 1 und das Textstück).
- **Fragen:** genau 4 – drei zum Inhalt, eine zur Sprache (Lesung, gleiche Bedeutung oder Grammatik).
  Je 4 Antworten, eine richtig. Falsche Antworten dürfen im Text vorkommen (typisch JLPT).
  Erklärung auf Deutsch mit Satznummer, `evidence` = Sätze ab 1. Bei Lesungsfragen das gefragte Wort
  ohne Furigana schreiben und den Rest selbst in Ruby-Schreibweise.
- **Quellen** bei Nachrichten (Name und Link).

## 4. Zerlegen und prüfen

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\zerlegen.py werkstatt\entwuerfe\<datum>-*.json
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\pruefen.py
```

- `zerlegen.py` meldet `FEHLT …` für fehlende Bedeutungen oder Grammatikstellen: Glossar ergänzen und neu laufen lassen,
  bis nichts mehr fehlt.
- `pruefen.py` meldet `STIL …` bei gesprochener Sprache ab Stufe 3 (und bei mehr als zwei Plauder-Stellen in
  Stufe 1–2): die betroffenen Sätze im Entwurf in Schriftform umschreiben und neu prüfen, bis `OK` steht.
  Hinweise ohne Fehler (z. B. „kaum Schriftsprache der N2“) ebenfalls beheben.
- `pruefen.py` meldet `LESUNG …`, wenn Sudachi anders liest: im Zusammenhang entscheiden und, falls die
  Text-Lesung falsch ist, im Entwurf unter `lesungen` eintragen (`"Satz:Schreibung": "lesung"`).
- Stufenregeln (Spezifikation 9.1), sonst umschreiben:
  - höchstens **10 %** der Listenwörter eine Stufe darüber, **keines weit darüber**
  - höchstens **4 Themenwörter** ohne Listeneintrag
  - Länge im Bereich der Tabelle

## 5. Aufnahmen

- Bis einschließlich `aufbau_bis` (3.12.2026): `dart run tool/tts.dart` (Aufbau-Zugang, Startguthaben).
- Danach: `dart run tool/tts.dart --key=../learnwithleoni/werkstatt/azure-speech.env` (Gratis-Zugang F0).
- Den Schlüssel nie ausgeben. Meldet das Skript eine Kostengrenze oder Fehler, keine weiteren Aufnahmen.
- **Hörkontrolle** der neuen Texte: `dart run tool/tts.dart --hoerkontrolle` (danach mit demselben `--key=` wie oben).
  Azure bewertet jede Satzaufnahme gegen die Lesung des Textes. Bei `ABWEICHUNG` das Wort im Zusammenhang prüfen:
  - Liest die Stimme falsch (z. B. 今日 als こんにち), im Text beim Wort `"say": "<lesung>"` eintragen,
    die Satzaufnahme löschen und `tts.dart` neu laufen lassen.
  - Steht im Text eine unübliche Lesung, die Lesung korrigieren (`lesungen` im Entwurf). Übliche Lesungen
    für Wörter, bei denen Sudachi danebenliegt, stehen in `STANDARD_LESUNGEN` (pruefen.py), z. B. 日本 → にほん.
  - Eigennamen (Orte, Personen) bekommen immer `say`, damit die Stimme sie sicher richtig liest.
  - Die Erkennung meldet manchmal Unsinn. Ist die Lesung im Text richtig und die Stimme vermutlich auch,
    die Abweichung stehen lassen.

## 6. Aufräumen, testen und veröffentlichen

Alte Texte wegräumen (älter als `aufbewahren_tage`, Standard 90). Wortaufnahmen bleiben immer,
damit Leonis gespeicherte Wörter ihre Aussprache behalten:

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\aufraeumen.py
```

```
flutter test
git add -A web/data
git status --short      # nur web/data darf vorgemerkt sein
git commit -m "Teeküche: Texte vom <datum>"
git push
```

Commit-Nachrichten enden mit der Zeile `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
Schlägt `flutter test` fehl: Ursache im Text beheben, nie Tests ändern oder abschalten.

## 7. Wenn etwas schiefgeht

Kann der Lauf nicht fertig werden (keine Websuche, Kontingent erschöpft, Tests rot), eine Meldung oben in
`web/data/status.json` eintragen, z. B. `{"datum": "2026-11-13", "text": "Heute keine neuen Texte – die Teeküche konnte nicht laufen."}`,
nur diese Datei committen und pushen. Die App zeigt dann Texte aus dem Vorrat.

## 8. Abschluss

Kurze Zusammenfassung auf Deutsch: welche Texte (Titel, Thema, Stufen), wie viele Zeichen Azure,
Hinweise aus `pruefen.py`, ob veröffentlicht wurde.

## Ferienpaket (auf Zuruf)

Sagt Leoni z. B. „Ich bin vom 1. bis 14. August weg“: für jeden Lerntag (Mo–Sa) in diesem Zeitraum
wie oben 2 Texte in 4 Stufen schreiben, mit dem Datum des jeweiligen Tages. Nur zeitlose Themen (keine
Nachrichten). Die App zeigt Texte erst an ihrem Datum.
