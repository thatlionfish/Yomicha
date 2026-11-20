# Teeküche – der tägliche Lauf

Diese Anleitung befolgt Claude jeden Morgen (Montag bis Samstag) als geplante Aufgabe.
Ziel: **1 neuer Text** pro Tag in **einer Fassung – Leonis Stufe**, geprüft, vertont und veröffentlicht.
Leoni liest einen Text am Tag (13.11.2026); mehr zu schreiben verbraucht nur ihr Nutzungskontingent.

Arbeitsordner: `C:\dev\Apps\Study\yomicha`. Mit Leoni wird Deutsch gesprochen.

**Nur ein Shell-Befehl:** Alles, was eine Shell braucht, läuft über
`tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py <schritt>` (Liste: `… lauf.py hilfe`).
Keine anderen Shell-Befehle – kein `Set-Location`, kein `git`, `dart` oder `flutter` direkt, kein `Get-Content`.
Dateien liest und schreibt die Teeküche mit ihren Datei-Werkzeugen (Lesen, Schreiben, Bearbeiten), im Web
sucht sie mit der Websuche. So muss Leoni nichts bestätigen: Die Freigabe gilt genau für diesen Befehl.

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
   **Die Stufe für heute** liefert `… lauf.py stufen` (Feld `stufen`):
   **nur Leonis Stufe – genau eine Fassung pro Text** (ihr Wunsch vom 19.11.2026; sie liest einen Text und
   braucht keine Fassung darüber). Keine weiteren Stufen schreiben – das schont auch ihr Nutzungskontingent.
   Steht im Ergebnis ein `hinweis` (Zielkurve voraus), Leoni in `web/data/status.json` nach ihrer Stufe fragen.
3. `web/data/texte/index.json` lesen.
   - Gibt es für heute schon Texte (Ferienpaket), nichts Neues erzeugen.
   - Themen und Textarten der letzten 7 Tage merken, damit sich nichts wiederholt.

## 2. Themen wählen

- **Ein Text pro Tag, abwechselnd** – war der letzte Text (`topic` im Verzeichnis) ein JLPT-Thema, heute ein
  aktuelles Thema, sonst ein JLPT-Thema.
- **Aktuelles Thema:** Weltgeschehen, Mode oder Tee, gewichtet nach `themen`. Bei Weltgeschehen mit der
  Websuche die Meldungen der letzten 48 Stunden in mehreren seriösen Quellen lesen (z. B. NHK, Reuters,
  BBC, Asahi). Für Mode und Tee ist auch ein zeitloser Hintergrundtext in Ordnung.
- **JLPT-Thema:** eines aus `jlpt_themen`, das in den letzten 10 Texten nicht vorkam.
- Eine Textart aus `textarten`, abwechselnd (Nachricht, Essay, Meinung, Aushang, E-Mail, Infoblatt).
- **Kein Vorrat:** Für Ferien sagt Leoni rechtzeitig Bescheid; dann gilt das Ferienpaket (unten).

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
- **Fragen – wirklich im Prüfungsstil** (Leonis Wunsch vom 19.11.2026). Leoni liest zuerst den
  **Prüfungsdurchgang**: Text und alle Fragen auf einer Seite, ohne Nachschlagen, Vorlesen oder Übersetzung.
  Nur dieses Ergebnis zählt für ihren Aufstieg – die Fragen müssen also echtes Verstehen prüfen:
  - Genau 4 Fragen mit je 4 Antworten, eine richtig. Frage und Antworten **nur Japanisch**, im Wortlaut der
    JLPT: „〜とあるが、なぜか。“, „〜とはどういうことか。“, „この文章の内容と合っているものはどれか。“,
    „筆者の考えに合うのはどれか。“, „このメールで一番伝えたいことは何か。“
  - Stufe 1–2: drei zum Inhalt, eine zur Sprache (Lesung, gleiche Bedeutung oder Grammatik). **Ab Stufe 3 alle
    vier zum Verständnis** wie im Leseteil (Gründe, Bezüge, Absicht, Meinung); ab Stufe 5 mindestens eine zum
    ganzen Text (主張理解: „筆者が最も言いたいことは何か“).
  - **Nicht durch Wörterabgleich lösbar:** Die richtige Antwort **sagt dasselbe mit anderen Worten** (言い換え)
    als der Text. Die falschen Antworten nehmen gern Wörter aus dem Text, sagen aber etwas anderes: falscher
    Grund, vertauschte Personen oder Zeiten, nur halb richtig, zu allgemein, im Text gar nicht gesagt.
  - Mindestens eine Frage braucht **zwei Sätze zusammen** (Grund und Folge, Bezug von こうした / その / これ).
  - Die Antworten sind etwa gleich lang; die richtige ist nicht immer die längste und steht nicht immer an
    derselben Stelle.
  - **Gegenprobe** vor dem Zerlegen: jede Frage nur mit dem Text beantworten. Lässt sie sich lösen, weil ein
    auffälliges Wort aus Frage oder Text wortgleich nur in der richtigen Antwort steht, umformulieren.
  - Erklärung auf Deutsch (Leoni sieht sie erst in der Auswertung) mit Satznummer, `evidence` = Sätze ab 1.
    Bei Lesungsfragen das gefragte Wort ohne Furigana schreiben und den Rest selbst in Ruby-Schreibweise.
- **Quellen** bei Nachrichten (Name und Link).

## 4. Zerlegen und prüfen

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py zerlegen werkstatt\entwuerfe\<datum>-<thema>-<stufe>.json ...
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py pruefen
```

- `zerlegen.py` meldet `FEHLT …` für fehlende Bedeutungen oder Grammatikstellen: Glossar ergänzen und neu laufen lassen,
  bis nichts mehr fehlt.
- `pruefen.py` meldet `STIL …` bei gesprochener Sprache ab Stufe 3 (und bei mehr als zwei Plauder-Stellen in
  Stufe 1–2): die betroffenen Sätze im Entwurf in Schriftform umschreiben und neu prüfen, bis `OK` steht.
  Hinweise ohne Fehler (z. B. „kaum Schriftsprache der N2“) ebenfalls beheben.
- `pruefen.py` meldet `FRAGE …`, wenn die richtige Antwort Text wörtlich übernimmt, die falschen aber nicht
  (dann findet man sie durch Wörterabgleich): die richtige Antwort mit anderen Worten sagen (言い換え) oder die
  falschen ebenfalls mit Wörtern aus dem Text bauen. Gilt für alle Stufen.
- `pruefen.py` meldet `LESUNG …`, wenn Sudachi anders liest: im Zusammenhang entscheiden und, falls die
  Text-Lesung falsch ist, im Entwurf unter `lesungen` eintragen (`"Satz:Schreibung": "lesung"`).
- Stufenregeln (Spezifikation 9.1), sonst umschreiben:
  - höchstens **10 %** der Listenwörter eine Stufe darüber, **keines weit darüber**
  - höchstens **4 Themenwörter** ohne Listeneintrag
  - Länge im Bereich der Tabelle

## 4b. Beispielsätze für „Kanji schreiben“

Zu jedem Wort, das Leoni schreiben lernt, ein kurzer Beispielsatz mit Übersetzung und Aufnahme
(Spezifikation 19, Stufe 2). Jeden Lauf **40 Sätze** für die Wörter, die als Nächstes drankommen:

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py saetze 40
```

Die Liste (`woerter`: Schlüssel, Bedeutung, JLPT-Stufe) in `werkstatt/entwuerfe/saetze.json` beantworten:

```json
{
 "支える|ささえる": {"s": "母は一人で家族を[支えて]きた。", "de": "Meine Mutter hat die Familie allein unterstützt."},
 "支持|しじ": {"s": "多くの人がその案を[支持]している。", "de": "Viele Menschen unterstützen diesen Vorschlag.",
              "bedeutung": "Unterstützung, Zustimmung"},
 "日|か": {"s": "旅行は[三日間]の予定だ。", "de": "Die Reise ist für drei Tage geplant."}
}
```

- **s:** ein natürlicher Satz, 10–35 Zeichen, Grammatik etwa N3 (für N1-Wörter darf es N2 sein), so wie das
  Wort in der Prüfung oder im Alltag vorkommt. Das Wort (auch gebeugt: 支えて, 済んだ) **genau einmal in [ ]**.
  Ist das Wort nur ein Teil eines Wortes (Zähleinheit, Nachsilbe: 三日, ドイツ人, 大好き), das ganze Wort einklammern.
  Möglichst nur geläufige Kanji, keine echten Personen, nichts Belastendes.
- **de:** deutsche Übersetzung des ganzen Satzes.
- **bedeutung:** deutsche Bedeutung des Wortes (kurz, wie im Wörterbuch) – **Pflicht, wenn `saetze` sie englisch zeigt**.
- **lesungen:** nur, wenn das Werkzeug ein Wort falsch liest (`{"Schreibung": "lesung"}`).

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py saetze-uebernehmen
```

Das Werkzeug ergänzt die Lesungen (Sudachi), prüft und legt die Sätze unter `web/data/schreiben/saetze/` ab.
Jede übernommene Zeile (`✓`) mit Lesungen ansehen: Stimmt eine Lesung nicht (z. B. {方|ほう} statt かた), im
Entwurf unter `lesungen` eintragen und neu übernehmen. Bei `✗` den Satz verbessern und erneut übernehmen, bis
nichts mehr offen ist. Die Aufnahmen macht der nächste Schritt (`audio`) von selbst.

## 5. Aufnahmen

- `… lauf.py audio` – bis einschließlich `aufbau_bis` (3.12.2026) mit dem Aufbau-Zugang, danach von selbst
  mit dem Gratis-Zugang F0.
- Den Schlüssel nie ausgeben. Meldet das Skript eine Kostengrenze oder Fehler, keine weiteren Aufnahmen.
- **Hörkontrolle** der neuen Texte: `… lauf.py hoerkontrolle`.
  Azure bewertet jede Satzaufnahme gegen die Lesung des Textes. Bei `ABWEICHUNG` das Wort im Zusammenhang prüfen:
  - Liest die Stimme falsch (z. B. 今日 als こんにち), im Text beim Wort `"say": "<lesung>"` eintragen,
    die Satzaufnahme mit `… lauf.py satz-neu <textordner> sNN.mp3` löschen und `… lauf.py audio` neu laufen lassen.
  - Steht im Text eine unübliche Lesung, die Lesung korrigieren (`lesungen` im Entwurf). Übliche Lesungen
    für Wörter, bei denen Sudachi danebenliegt, stehen in `STANDARD_LESUNGEN` (pruefen.py), z. B. 日本 → にほん.
  - Eigennamen (Orte, Personen) bekommen immer `say`, damit die Stimme sie sicher richtig liest.
  - Die Erkennung meldet manchmal Unsinn. Ist die Lesung im Text richtig und die Stimme vermutlich auch,
    die Abweichung stehen lassen.

## 6. Aufräumen, testen und veröffentlichen

Zuerst Leonis Lernstand sichern: `… lauf.py sicherung` kopiert die wöchentliche Sicherung der App aus dem
privaten Repository `Yomicha-lernstand` nach `werkstatt/sicherungen/` (höchstens einmal pro Woche, nie
veröffentlicht). Steht dort „nichts kopiert“, ist das kein Fehler.

Alte Texte wegräumen (älter als `aufbewahren_tage`, Standard 90). Wortaufnahmen bleiben immer,
damit Leonis gespeicherte Wörter ihre Aussprache behalten:

```
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py aufraeumen
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py test
tool\teekueche\.venv\Scripts\python.exe -I tool\teekueche\lauf.py veroeffentlichen "Teeküche: Text vom <datum>"
```

`veroeffentlichen` merkt nur `web/data` vor, bricht ab, wenn etwas anderes dabei ist, hängt die Zeile
`Co-Authored-By` an und zieht neue Commits von GitHub nach, falls der Push abgelehnt wird.
Schlägt `flutter test` fehl: Ursache im Text beheben, nie Tests ändern oder abschalten.

## 7. Wenn etwas schiefgeht

Kann der Lauf nicht fertig werden (keine Websuche, Kontingent erschöpft, Tests rot), eine Meldung oben in
`web/data/status.json` eintragen, z. B. `{"datum": "2026-11-13", "text": "Heute keine neuen Texte – die Teeküche konnte nicht laufen."}`,
mit `… lauf.py veroeffentlichen "Teeküche: Meldung"` veröffentlichen. Die App zeigt dann die neuesten ungelesenen Texte.

## 8. Abschluss

Kurze Zusammenfassung auf Deutsch: welche Texte (Titel, Thema, Stufen), wie viele Beispielsätze,
wie viele Zeichen Azure, Hinweise aus `pruefen.py`, ob veröffentlicht wurde.

## Ferienpaket (auf Zuruf)

Sagt Leoni z. B. „Ich bin vom 1. bis 14. August weg“: für jeden Lerntag (Mo–Sa) in diesem Zeitraum
wie oben 1 Text in Leonis Stufe schreiben, mit dem Datum des jeweiligen Tages. Nur zeitlose Themen (keine
Nachrichten). Die App zeigt Texte erst an ihrem Datum.
