"""Beispielsätze für „Kanji schreiben“ (Spezifikation 19, Stufe 2).

Zu jedem Wort ein kurzer Satz im Prüfungsstil mit deutscher Übersetzung und
Aufnahme, damit ich das Wort „in Aktion“ erlebe. Claude schreibt nur einen
Entwurf, das Werkzeug ergänzt die Lesungen (Sudachi), prüft und legt die Sätze ab.

Entwurf (werkstatt/entwuerfe/saetze.json, wird nach dem Übernehmen geleert):

{
  "支える|ささえる": {"s": "母は一人で家族を[支えて]きた。", "de": "Meine Mutter hat die Familie allein unterstützt."},
  "支持|しじ": {"s": "多くの人がその案を[支持]している。", "de": "Viele Menschen unterstützen den Vorschlag.",
               "bedeutung": "Unterstützung, Zustimmung"},
  "日|か": {"s": "旅行は[三日]間の予定だ。", "de": "Die Reise ist für drei Tage geplant."},
  "今日|きょう": {"s": "[今日]は朝から雨だ。", "de": "…", "lesungen": {"朝": "あさ"}}
}

- Schlüssel: Schreibung|Lesung wie in web/data/schreiben/plan.json (Ausgabe von „naechste“).
- s: der Satz, das Wort (auch gebeugt) in eckigen Klammern – genau einmal. Ist das Wort
  nur ein Teil eines Wortes (Zähleinheit, Nachsilbe: 三日, ドイツ人), das ganze Wort einklammern.
- de: deutsche Übersetzung des Satzes.
- bedeutung: deutsche Bedeutung des Wortes – Pflicht, wenn „naechste“ sie englisch zeigt.
- lesungen: nur wenn Sudachi ein Wort falsch liest (Schreibung → Lesung in Hiragana).

Ergebnis: web/data/schreiben/saetze/<bucket>.json (Bucket wie die Kanji-Karten: erstes
Kanji des Wortes), je Wort {"s", "de", "r"}; r ist der Satz in Ruby-Schreibweise
({漢字|かんじ}) mit dem Wort in [ ]. Die Aufnahme macht tool/tts.dart.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\saetze.py naechste [anzahl]
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\saetze.py uebernehmen [entwurf.json]
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\saetze.py pruefen
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\saetze.py neu-bauen     (nach neuen Lesungsregeln)
"""

import datetime as dt
import json
import pathlib
import re
import sys

from sudachipy import Dictionary, SplitMode

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pruefen import STANDARD_LESUNGEN, hira  # noqa: E402
from zerlegen import align  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
PLAN = ROOT / "web" / "data" / "schreiben" / "plan.json"
SAETZE = ROOT / "web" / "data" / "schreiben" / "saetze"
ENTWURF = ROOT / "werkstatt" / "entwuerfe" / "saetze.json"
KANJI = re.compile(r"[㐀-䶿一-鿿豈-﫿々]")
HIRA = re.compile(r"^[ぁ-ゖー]+$")

# Wie in der App: 4 neue Kanji pro Lerntag, höchstens 20 neue Wörter.
KANJI_PRO_TAG = 4
WOERTER_PRO_TAG = 20


def bucket(word: str) -> str:
    first = next(c for c in word if KANJI.match(c) and c != "々")
    return format(ord(first) >> 8, "x")


def load_plan() -> dict:
    return json.loads(PLAN.read_text(encoding="utf-8"))


def load_all() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for f in sorted(SAETZE.glob("*.json")):
        out.update(json.loads(f.read_text(encoding="utf-8")))
    return out


def erwartete_reihenfolge(plan: dict, start: dt.date) -> list[list]:
    """Die Wörter in der Reihenfolge, in der sie mir voraussichtlich neu begegnen:
    wie die App (neueWoerter in lib/learn/schreiben.dart) – zuerst die Wörter der
    zuletzt gelernten Kanji, dann Wörter aus Kanji, die ich schon vorher konnte.
    Ausgangspunkt: mein Vorwissen, ab heute 4 Kanji und 20 Wörter pro Lerntag."""
    order = plan["reihenfolge"]
    learned = {k: "v" for k in plan["vorwissen"]}
    words = plan["woerter"]
    wkanji = [[c for c in w[0] if KANJI.match(c) and c != "々"] for w in words]
    done = [False] * len(words)
    result: list[list] = []
    day = start
    nxt = 0
    while len(result) < len(words) and nxt <= len(order) + 400:
        if day.weekday() != 6:
            tag = day.isoformat()
            for _ in range(KANJI_PRO_TAG):
                while nxt < len(order) and order[nxt] in learned:
                    nxt += 1
                if nxt < len(order):
                    learned[order[nxt]] = tag
                nxt += 1
            lesson, old = [], []
            for i, w in enumerate(words):
                if done[i]:
                    continue
                ds = [learned.get(k) for k in wkanji[i]]
                if None in ds:
                    continue
                newest = max((d for d in ds if d != "v"), default=None)
                (lesson if newest else old).append((newest or "", i))
            lesson.sort()
            for _, i in [*lesson, *old][:WOERTER_PRO_TAG]:
                done[i] = True
                result.append(words[i])
        day += dt.timedelta(days=1)
    return result


def naechste(anzahl: int) -> None:
    plan = load_plan()
    have = load_all()
    entwurf = json.loads(ENTWURF.read_text(encoding="utf-8")) if ENTWURF.exists() else {}
    todo = []
    for w in erwartete_reihenfolge(plan, dt.date.today()):
        key = f"{w[0]}|{w[1]}"
        if key in have or key in entwurf:
            continue
        todo.append({"key": key, "bedeutung": w[4] if len(w) > 4 else w[3], "jlpt": f"N{w[2]}"})
        if len(todo) >= anzahl:
            break
    print(json.dumps({
        "fertig": len(have),
        "gesamt": len(plan["woerter"]),
        "entwurf": str(ENTWURF.relative_to(ROOT)),
        "woerter": todo,
    }, ensure_ascii=False, indent=1))


# --- Lesungen und Prüfung ------------------------------------------------------

# Lesungen, die Sudachi in kurzen Alltagssätzen anders wählt als üblich.
ALLTAG = {"私": "わたし", "明日": "あした"}
# Zahlen, die Sudachi einzeln liest: 四月 しがつ, 九月 くがつ, 四時 よじ, 九時 くじ.
ZAHLZEICHEN = set("一二三四五六七八九十百千万何数")
ZAHL = {("四", "月"): "し", ("九", "月"): "く", ("四", "時"): "よ", ("九", "時"): "く", ("七", "時"): "しち"}


def ruby_segmente(tok, plain: str, lesungen: dict[str, str]) -> list[tuple[str, str]]:
    """Satzstück → [(Text, Lesung)]; Lesung nur bei Kanji, je Kanji-Block (飲|の み)."""
    segs: list[tuple[str, str]] = []
    if not plain:
        return segs
    for m in tok.tokenize(plain, SplitMode.C):
        surface = m.surface()
        if not KANJI.search(surface):
            segs.append((surface, ""))
            continue
        reading = lesungen.get(surface) or STANDARD_LESUNGEN.get(surface) or ALLTAG.get(surface)
        nxt = plain[m.end():m.end() + 1]
        if reading is None and (surface, nxt) in ZAHL:
            reading = ZAHL[(surface, nxt)]
        if reading is None and surface == "何":
            # 何を/何が/何も/何か → なに; 何で/何の/何だ/何人 → なん
            reading = "なに" if nxt in ("を", "が", "も", "か", "に", "へ", "と", "や", "") else "なん"
        reading = reading or hira(m.reading_form())
        for b, r in align(surface, reading) or [[surface, reading]]:
            # Zahl + Zähleinheit (三|みっ 日間|かかん, 四|し 月|がつ) als ein Block lesen.
            if r and segs and segs[-1][1] and set(segs[-1][0]) <= ZAHLZEICHEN and KANJI.match(b[0]):
                pb, pr = segs.pop()
                segs.append((pb + b, pr + r))
            else:
                segs.append((b, r))
    return segs


def render(segs: list[tuple[str, str]]) -> str:
    return "".join(f"{{{b}|{r}}}" if r else b for b, r in segs)


def baue(tok, key: str, entry: dict, deutsch: bool = True) -> tuple[str | None, list[str]]:
    """Ruby-Satz mit [Ziel] bauen und prüfen. → (r, Fehler). [deutsch]: Der Plan
    hat schon eine deutsche Bedeutung des Wortes."""
    t, r = key.split("|")
    s = entry.get("s", "")
    errors: list[str] = []
    if not entry.get("de"):
        errors.append("deutsche Übersetzung (de) fehlt")
    if not deutsch and not entry.get("bedeutung"):
        errors.append("deutsche Bedeutung des Wortes (bedeutung) fehlt")
    if s.count("[") != 1 or s.count("]") != 1 or s.index("[") > s.index("]"):
        return None, [*errors, "das Wort genau einmal in [ ] setzen"]
    vor, rest = s.split("[")
    ziel, nach = rest.split("]")
    plain = vor + ziel + nach
    if not 6 <= len(plain) <= 45:
        errors.append(f"Satz {len(plain)} Zeichen – kurz halten (ca. 10–35)")
    wk = "".join(c for c in t if KANJI.match(c))
    if wk not in "".join(c for c in ziel if KANJI.match(c)):
        errors.append(f"in [ ] steht „{ziel}“, das Wort ist {t}")
    lesungen = dict(entry.get("lesungen") or {})
    # Das Wort selbst immer mit seiner Lesung (今日 → きょう, 一日 → ついたち).
    if ziel == t:
        ziel_segs = [(b, x) for b, x in (align(t, r) or [[t, r]])]
    else:
        ziel_segs = ruby_segmente(tok, ziel, lesungen)
    segs = [*ruby_segmente(tok, vor, lesungen), *ziel_segs, *ruby_segmente(tok, nach, lesungen)]
    gelesen = "".join(x or hira(b) for b, x in ziel_segs)
    if not (r in gelesen or (len(r) > 1 and r[:-1] in gelesen)):
        errors.append(f"Lesung in [ ]: {gelesen}, das Wort liest sich {r} – Wort prüfen oder lesungen angeben")
    for b, x in segs:
        if x and not HIRA.match(x):
            errors.append(f"keine Lesung in Hiragana für {b} ({x})")
    ruby = render(ruby_segmente(tok, vor, lesungen)) + "[" + render(ziel_segs) + "]" + render(ruby_segmente(tok, nach, lesungen))
    return (None if errors else ruby), errors


def uebernehmen(path: pathlib.Path) -> int:
    if not path.exists():
        print(f"Kein Entwurf: {path.relative_to(ROOT)}")
        return 0
    draft = json.loads(path.read_text(encoding="utf-8"))
    plan_de = {f"{w[0]}|{w[1]}": len(w) > 4 for w in load_plan()["woerter"]}
    plan_keys = set(plan_de)
    tok = Dictionary(dict="core").tokenizer()
    buckets: dict[str, dict] = {}
    rest: dict[str, dict] = {}
    ok = 0
    for key, entry in draft.items():
        if key not in plan_keys:
            print(f"✗ {key}: nicht im Lernplan (Schlüssel wie in „naechste“)")
            rest[key] = entry
            continue
        ruby, errors = baue(tok, key, entry, plan_de[key])
        if errors:
            print(f"✗ {key}: " + "; ".join(errors))
            rest[key] = entry
            continue
        b = bucket(key.split("|")[0])
        if b not in buckets:
            f = SAETZE / f"{b}.json"
            buckets[b] = json.loads(f.read_text(encoding="utf-8")) if f.exists() else {}
        item = {"s": entry["s"], "de": entry["de"], "r": ruby}
        if entry.get("bedeutung"):
            item["bedeutung"] = entry["bedeutung"]
        if entry.get("lesungen"):
            item["lesungen"] = entry["lesungen"]
        buckets[b][key] = item
        ok += 1
        print(f"✓ {key}: {ruby}")
    SAETZE.mkdir(parents=True, exist_ok=True)
    for b, data in buckets.items():
        (SAETZE / f"{b}.json").write_text(
            json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=0) + "\n", encoding="utf-8"
        )
    path.write_text(json.dumps(rest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = len(load_all())
    print(f"\nÜbernommen: {ok} · offen im Entwurf: {len(rest)} · Sätze insgesamt: {total}")
    if rest:
        print("Die offenen Sätze im Entwurf verbessern und noch einmal übernehmen.")
    return 1 if rest else 0


def neu_bauen() -> None:
    """Alle Sätze mit den aktuellen Regeln neu bauen (r), z. B. nach einer neuen Lesungsregel."""
    tok = Dictionary(dict="core").tokenizer()
    plan_de = {f"{w[0]}|{w[1]}": len(w) > 4 for w in load_plan()["woerter"]}
    for f in sorted(SAETZE.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        for key, entry in data.items():
            ruby, errors = baue(tok, key, entry, plan_de.get(key, True))
            if errors:
                print(f"✗ {key}: " + "; ".join(errors))
            elif ruby != entry.get("r"):
                print(f"neu {key}: {ruby}")
                entry["r"] = ruby
        f.write_text(json.dumps(dict(sorted(data.items())), ensure_ascii=False, indent=0) + "\n", encoding="utf-8")


def pruefen() -> int:
    tok = Dictionary(dict="core").tokenizer()
    plan_de = {f"{w[0]}|{w[1]}": len(w) > 4 for w in load_plan()["woerter"]}
    bad = 0
    for key, entry in load_all().items():
        if key not in plan_de:
            bad += 1
            print(f"✗ {key}: nicht (mehr) im Lernplan")
            continue
        ruby, errors = baue(tok, key, entry, plan_de[key])
        if errors or ruby != entry.get("r"):
            bad += 1
            print(f"✗ {key}: " + ("; ".join(errors) or f"r veraltet: {entry.get('r')} → {ruby}"))
    print(f"Geprüft: {len(load_all())} Sätze, Fehler: {bad}")
    return 1 if bad else 0


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help", "hilfe"):
        print(__doc__)
        return
    if args[0] == "naechste":
        naechste(int(args[1]) if len(args) > 1 else 40)
    elif args[0] == "uebernehmen":
        sys.exit(uebernehmen(ROOT / args[1] if len(args) > 1 else ENTWURF))
    elif args[0] == "pruefen":
        sys.exit(pruefen())
    elif args[0] == "neu-bauen":
        neu_bauen()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
