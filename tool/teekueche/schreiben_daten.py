"""Baut die Daten für „Kanji schreiben“ (Spezifikation 19).

Quellen:
  werkstatt/quellen/jlpt-kanji/kanji-jouyou.json   JLPT-Stufe (jlpt_new) und Häufigkeit
  werkstatt/quellen/jlpt-vokabeln/n1..n5.csv       JLPT-Wörter (open-anki-jlpt-decks, MIT)
  werkstatt/quellen/kanjivg/kanjivg-*.xml.gz       Striche der Kana (CC BY-SA 3.0)
  web/data/kanji/*.json                            Kanji-Karten (Bestandteile, Striche)
  tool/teekueche/schreiben_extra.json              Leonis Vorwissen, deutsche Bedeutungen

Ergebnis:
  web/data/schreiben/plan.json   Reihenfolge der Kanji (N5 → N1), Vorwissen, alle Wörter
  web/data/schreiben/kana.json   Striche von Hiragana, Katakana, ー und 々

Reihenfolge: Stufe für Stufe, darin nach Häufigkeit; ein Bestandteil, der selbst
ein Kanji zum Lernen ist, kommt vor dem Kanji, in dem er steckt – auch ein
N1-Kanji wie 又 vor 支. Danach kommt der Rest der N1.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\schreiben_daten.py
"""

import csv
import gzip
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

KVG = "{http://kanjivg.tagaini.net}"
KANA_SHIFT = ord("ァ") - ord("ぁ")
KANJI = re.compile(r"[㐀-䶿一-鿿豈-﫿]")


def to_hira(s: str) -> str:
    return "".join(chr(ord(c) - KANA_SHIFT) if "ァ" <= c <= "ヶ" else c for c in s)


def clean_expr(s: str) -> str:
    s = re.sub(r"[（(][^)）]*[)）]", "", s)
    return s.replace("〜", "").replace("～", "").replace(" ", "").strip()


def is_kana(c: str) -> bool:
    return "ぁ" <= c <= "ゖ" or "ァ" <= c <= "ヺ" or c in "ー々"


def kana_strokes(path: pathlib.Path) -> dict[str, list[str]]:
    out = {}
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f):
            if el.tag != "kanji":
                continue
            top = el.find("g")
            char = top.get(KVG + "element") if top is not None else None
            if not char:
                # Kana haben oft kein element-Attribut: aus der ID lesen.
                m = re.match(r"kvg:kanji_([0-9a-f]+)$", el.get("id", ""))
                char = chr(int(m.group(1), 16)) if m else None
            if char and is_kana(char):
                out[char] = [p.get("d") for p in el.iter("path")]
            el.clear()
    return out


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(__file__).resolve().parents[2]
    q = root / "werkstatt" / "quellen"
    out_dir = root / "web" / "data" / "schreiben"
    out_dir.mkdir(parents=True, exist_ok=True)

    jouyou = json.loads((q / "jlpt-kanji" / "kanji-jouyou.json").read_text(encoding="utf-8"))
    extra = json.loads((root / "tool" / "teekueche" / "schreiben_extra.json").read_text(encoding="utf-8"))
    cards: dict[str, dict] = {}
    for f in (root / "web" / "data" / "kanji").glob("*.json"):
        if f.name != "teile.json":
            cards.update(json.loads(f.read_text(encoding="utf-8")))
    kana = kana_strokes(next((q / "kanjivg").glob("kanjivg-*.xml.gz")))

    # Was gelernt wird: N5–N1 nach der Liste, dazu Leonis Vorwissen in den
    # Stufen ihrer bisherigen App. Nur Kanji mit Strichdaten.
    vorwissen = "".join(extra["vorwissen"][n] for n in ("5", "4", "3"))
    stufe: dict[str, int] = {}
    for c, v in jouyou.items():
        if v.get("jlpt_new") in (5, 4, 3, 2, 1):
            stufe[c] = v["jlpt_new"]
    # Was ich schon kann, steht in der Stufe meiner bisherigen App, wenn die
    # Liste es erst in der N1 (oder gar nicht) führt – z. B. 舌.
    for n, chars in extra["vorwissen"].items():
        for c in chars:
            if stufe.get(c, 1) == 1:
                stufe[c] = int(n)
    ohne_striche = [c for c in stufe if not cards.get(c, {}).get("paths")]
    for c in ohne_striche:
        del stufe[c]

    def freq(c: str) -> int:
        return jouyou.get(c, {}).get("freq") or 9999

    reihenfolge: list[str] = []
    placed: set[str] = set()

    def place(c: str, seen: frozenset = frozenset()) -> None:
        if c in placed or c in seen:
            return
        # Schon Gelerntes zieht keine Bestandteile nach vorn.
        for p in [] if c in vorwissen else cards.get(c, {}).get("parts", []):
            if p in stufe and p != c:
                place(p, seen | {c})
        placed.add(c)
        reihenfolge.append(c)

    for n in (5, 4, 3, 2, 1):
        for c in sorted((c for c in stufe if stufe[c] == n), key=lambda c: (freq(c), c)):
            place(c)
    index = {c: i for i, c in enumerate(reihenfolge)}

    # Wörter: alle JLPT-Wörter N5–N1 mit Kanji, die sich ganz schreiben lassen
    # (jedes Zeichen ist ein Lern-Kanji oder ein Kana mit Strichdaten).
    de = extra.get("de", {})
    korrektur = extra.get("korrektur", {})
    words: dict[str, dict] = {}
    pos = 0
    skipped = 0
    for n in (5, 4, 3, 2, 1):
        with open(q / "jlpt-vokabeln" / f"n{n}.csv", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                pos += 1
                reading = to_hira(re.split(r"[・、/／;]", clean_expr(row["reading"]))[0])
                for variant in re.split(r"[・、/／;]", clean_expr(row["expression"])):
                    if not KANJI.search(variant):
                        continue
                    if not all(c in stufe or (is_kana(c) and c in kana) for c in variant):
                        skipped += 1
                        break
                    r = reading
                    # Manche Lesungen tragen „する“ mit, die Schreibung nicht.
                    if r.endswith("する") and not variant.endswith("する") and len(r) > 2:
                        r = r[:-2]
                    key = f"{variant}|{r}"
                    if key in korrektur:
                        if korrektur[key] is None:
                            break
                        key = korrektur[key]
                        variant, r = key.split("|")
                    if key in words:
                        words[key]["n"] = max(words[key]["n"], n)
                    else:
                        words[key] = {"t": variant, "r": r, "n": n, "en": row["meaning"].strip(), "pos": pos}
                    break

    def release(w: dict) -> int:
        return max(index[c] for c in w["t"] if c in index)

    ordered = sorted(words.values(), key=lambda w: (release(w), -w["n"], w["pos"]))
    woerter = []
    for w in ordered:
        entry = [w["t"], w["r"], w["n"], w["en"]]
        if f"{w['t']}|{w['r']}" in de:
            entry.append(de[f"{w['t']}|{w['r']}"])
        woerter.append(entry)

    plan = {
        "version": 1,
        "hinweis": "Kanji schreiben: Reihenfolge (N5 → N1), Stufe je Kanji, Vorwissen, Bestandteile, Wörter [Schreibung, Lesung, JLPT, englisch, deutsch?].",
        "reihenfolge": "".join(reihenfolge),
        "stufen": "".join(str(stufe[c]) for c in reihenfolge),
        "vorwissen": vorwissen,
        # Bestandteile, die selbst Lern-Kanji sind (für vorgezogene Kanji aus Texten).
        "teile": {
            c: "".join(t for t in cards.get(c, {}).get("parts", []) if t in stufe and t != c)
            for c in reihenfolge
            if any(t in stufe and t != c for t in cards.get(c, {}).get("parts", []))
        },
        "woerter": woerter,
    }
    (out_dir / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (out_dir / "kana.json").write_text(
        json.dumps(dict(sorted(kana.items())), ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )

    offen = [c for c in reihenfolge if c not in vorwissen]
    letztes_n2 = max(i for i, c in enumerate(reihenfolge) if stufe[c] >= 2)
    vorgezogen = [c for c in reihenfolge[:letztes_n2] if stufe[c] == 1]
    print(f"Kanji: {len(reihenfolge)} (davon schon gelernt {len(set(vorwissen) & set(reihenfolge))}, offen {len(offen)})")
    print(f"N1-Bestandteile vor dem Ende der N2: {len(vorgezogen)} ({''.join(vorgezogen[:30])} …)")
    print(f"Ohne Strichdaten weggelassen: {''.join(ohne_striche) or '–'}")
    print(f"Nächste offene: {''.join(offen[:24])}")
    print(f"Wörter: {len(woerter)} (weggelassen, weil ein Zeichen fehlt: {skipped}), deutsch: {sum(len(w) > 4 for w in woerter)}")
    print(f"Kana mit Strichen: {len(kana)}")
    for f in ("plan.json", "kana.json"):
        print(f, f"{(out_dir / f).stat().st_size / 1024:,.0f} KB")


if __name__ == "__main__":
    main()
