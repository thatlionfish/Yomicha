"""Baut die Kanji-Karten und die JLPT-Wortliste aus den offenen Quellen.

Quellen (in werkstatt/quellen, nicht veröffentlicht):
  kanjivg/kanjivg-*.xml.gz      KanjiVG – Zerlegung und Strichfolge (CC BY-SA 3.0)
  kanjidic2/kanjidic2.xml.gz    KANJIDIC2 – Lesungen, Bedeutungen, Heisig-Nr. (CC BY-SA 4.0)
  jlpt-kanji/kanji-jouyou.json  Jōyō-Liste mit JLPT-Stufen (nur das Feld jlpt_new)
  jlpt-vokabeln/n1..n5.csv      JLPT-Wortlisten (open-anki-jlpt-decks, MIT; nach tanos.co.uk)

Ergebnis:
  web/data/kanji/<xx>.json            Kanji-Karten, gebündelt nach Codepunkt (U+xx00–U+xxFF)
  web/data/kanji/teile.json           Namen der Bestandteile
  tool/teekueche/daten/jlpt_woerter.json   JLPT-Stufe pro Wort (für die Stufenprüfung)

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\kanji_daten.py werkstatt\\quellen
"""

import csv
import gzip
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

KVG = "{http://kanjivg.tagaini.net}"

# Namen für Radikal-Formen, die KANJIDIC2 nicht als eigenes Zeichen kennt.
# Bewusst schlichte Wörterbuch-Bedeutungen, keine Namen aus Heisigs Buch.
RADICAL_NAMES = {
    "亻": "person", "氵": "water", "扌": "hand", "忄": "heart", "艹": "grass",
    "辶": "road", "⻌": "road", "⺮": "bamboo", "礻": "altar", "衤": "clothing",
    "阝": "village", "⻏": "village", "⻖": "hill", "刂": "knife", "⺈": "knife",
    "冫": "ice", "灬": "fire", "犭": "dog", "糹": "thread", "纟": "thread",
    "飠": "food", "釒": "metal", "訁": "speech", "宀": "roof", "冖": "cover",
    "广": "shelter", "疒": "sickness", "彳": "step", "夂": "slow step",
    "攵": "strike", "殳": "weapon", "卩": "seal", "㔾": "seal", "厶": "private",
    "亠": "lid", "丷": "eight", "爫": "claw", "罒": "net", "癶": "legs",
    "耂": "old", "牜": "cow", "⺧": "cow", "⺶": "sheep", "⺷": "sheep",
    "丶": "dot", "丿": "stroke", "乚": "hook", "亅": "hook", "⺊": "divination",
    "⺌": "small", "⺍": "small", "⺗": "heart", "⺾": "grass", "⻊": "foot",
    "⻗": "rain", "⺼": "flesh", "⺆": "frame", "⺄": "second", "龷": "grass",
}

KANA_SHIFT = ord("ァ") - ord("ぁ")


def to_hira(s: str) -> str:
    return "".join(chr(ord(c) - KANA_SHIFT) if "ァ" <= c <= "ヶ" else c for c in s)


def parse_kanjidic(path: pathlib.Path) -> dict:
    out = {}
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f):
            if el.tag != "character":
                continue
            lit = el.findtext("literal")
            misc = el.find("misc")
            rec = {
                "strokes": int(misc.findtext("stroke_count") or 0),
                "freq": int(misc.findtext("freq") or 9999),
                "heisig": None,
                "on": [],
                "kun": [],
                "meanings": [],
            }
            for ref in el.iter("dic_ref"):
                if ref.get("dr_type") == "heisig6":
                    rec["heisig"] = int(ref.text)
            for r in el.iter("reading"):
                if r.get("r_type") == "ja_on":
                    rec["on"].append(r.text)
                elif r.get("r_type") == "ja_kun":
                    rec["kun"].append(r.text.replace(".", "・"))
            for m in el.iter("meaning"):
                # „radical number 140“ o. ä. ist keine Bedeutung.
                if m.get("m_lang") is None and not m.text.lower().startswith("radical"):
                    rec["meanings"].append(m.text)
            out[lit] = rec
            el.clear()
    return out


def parse_kanjivg(path: pathlib.Path) -> dict:
    """Kanji → (Bestandteile erster Ebene, Strichpfade, Original-Formen)."""
    out = {}
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f):
            if el.tag != "kanji":
                continue
            top = el.find("g")
            if top is None:
                continue
            char = top.get(KVG + "element")
            if not char:
                el.clear()
                continue
            parts, originals = [], {}

            def walk(g):
                for child in g.findall("g"):
                    e = child.get(KVG + "element")
                    if e:
                        if e != char:
                            parts.append(e)
                            if child.get(KVG + "original"):
                                originals[e] = child.get(KVG + "original")
                    else:
                        walk(child)

            walk(top)
            strokes = [p.get("d") for p in el.iter("path")]
            out[char] = {"parts": parts, "paths": strokes, "originals": originals}
            el.clear()
    return out


def clean_expr(s: str) -> str:
    s = re.sub(r"[（(][^)）]*[)）]", "", s)
    return s.replace("〜", "").replace("～", "").replace(" ", "").strip()


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    q = pathlib.Path(sys.argv[1])
    root = pathlib.Path(__file__).resolve().parents[2]
    out_dir = root / "web" / "data" / "kanji"
    out_dir.mkdir(parents=True, exist_ok=True)

    dic = parse_kanjidic(q / "kanjidic2" / "kanjidic2.xml.gz")
    kvg = parse_kanjivg(next((q / "kanjivg").glob("kanjivg-*.xml.gz")))
    jouyou = json.loads((q / "jlpt-kanji" / "kanji-jouyou.json").read_text(encoding="utf-8"))
    extra = json.loads((root / "tool" / "teekueche" / "kanji_extra.json").read_text(encoding="utf-8"))["kanji"]

    # Welche Kanji bekommen eine Karte: alle Jōyō-Kanji, alle aus den Texten,
    # und Bestandteile, die selbst Kanji sind.
    wanted = set(jouyou)
    for f in (root / "web" / "data" / "texte").rglob("text.json"):
        wanted.update(ch for ch in f.read_text(encoding="utf-8") if "一" <= ch <= "鿿")
    for k in list(wanted):
        for p in kvg.get(k, {}).get("parts", []):
            if p in dic:
                wanted.add(p)

    # Eigene Schlüsselwörter: erste englische Bedeutung, ohne Doppelte
    # (häufige Kanji wählen zuerst).
    used: set[str] = set()
    keyword = {}
    for k in sorted(wanted, key=lambda k: dic.get(k, {}).get("freq", 9999)):
        meanings = [m.lower() for m in dic.get(k, {}).get("meanings", [])]
        if not meanings:
            continue
        choice = next((m for m in meanings if m not in used), None)
        if choice is None:
            choice = f"{meanings[0]} ({meanings[1]})" if len(meanings) > 1 else f"{meanings[0]} ({k})"
        used.add(choice)
        keyword[k] = choice

    buckets: dict[str, dict] = {}
    part_names: dict[str, str] = {}
    missing_vg = []
    for k in sorted(wanted):
        d = dic.get(k)
        if d is None:
            continue
        v = kvg.get(k)
        if v is None:
            missing_vg.append(k)
        rec = {
            "keyword": extra.get(k, {}).get("keyword", keyword.get(k, "")),
            "meanings": d["meanings"][:4],
            "on": d["on"],
            "kun": d["kun"],
            "strokes": d["strokes"],
            "heisig": d["heisig"],
            "j": jouyou.get(k, {}).get("jlpt_new"),
            "parts": v["parts"] if v else [],
            "paths": v["paths"] if v else [],
        }
        for key in ("de", "story"):
            if key in extra.get(k, {}):
                rec[key] = extra[k][key]
        rec = {a: b for a, b in rec.items() if b not in (None, [], "")}
        buckets.setdefault(f"{ord(k) >> 8:x}", {})[k] = rec
        if v:
            for p in v["parts"]:
                orig = v["originals"].get(p, p)
                name = RADICAL_NAMES.get(p) or keyword.get(p) or keyword.get(orig)
                if not name and orig in dic and dic[orig]["meanings"]:
                    name = dic[orig]["meanings"][0].lower()
                name = name or RADICAL_NAMES.get(p) or RADICAL_NAMES.get(orig)
                if name:
                    part_names.setdefault(p, name)

    for name, data in buckets.items():
        (out_dir / f"{name}.json").write_text(
            json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
        )
    (out_dir / "teile.json").write_text(
        json.dumps(dict(sorted(part_names.items())), ensure_ascii=False, indent=0), encoding="utf-8"
    )

    # JLPT-Wortliste: Schreibung (und Schreibung|Lesung) → leichteste Stufe.
    words: dict[str, int] = {}
    for n in range(1, 6):
        with open(q / "jlpt-vokabeln" / f"n{n}.csv", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                expr = clean_expr(row["expression"])
                reading = to_hira(clean_expr(row["reading"]))
                for variant in re.split(r"[・、/／;]", expr):
                    if not variant:
                        continue
                    for key in (variant, f"{variant}|{reading}"):
                        words[key] = max(words.get(key, 0), n)
                if reading:
                    words[reading] = max(words.get(reading, 0), n)
    daten = root / "tool" / "teekueche" / "daten"
    daten.mkdir(parents=True, exist_ok=True)
    (daten / "jlpt_woerter.json").write_text(
        json.dumps(dict(sorted(words.items())), ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )

    total = sum(len(b) for b in buckets.values())
    size = sum(p.stat().st_size for p in out_dir.glob("*.json")) / 1024
    print(f"Kanji-Karten: {total} in {len(buckets)} Dateien, {size:,.0f} KB")
    print(f"Ohne KanjiVG-Daten: {len(missing_vg)} {''.join(missing_vg[:20])}")
    print(f"Namen für Bestandteile: {len(part_names)}")
    print(f"JLPT-Wortliste: {len(words)} Einträge")
    for k in "茶飲寒香節":
        b = buckets[f"{ord(k) >> 8:x}"][k]
        print(k, {a: b[a] for a in b if a != "paths"}, f"{len(b.get('paths', []))} Striche")


if __name__ == "__main__":
    main()
