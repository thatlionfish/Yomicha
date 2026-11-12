"""Teeküche, Schritte 4 und 5: prüft Lesungen und Stufe jedes Textes mit Sudachi.

- Lesung: Stimmt die Lesung jedes Wortes mit Sudachi überein?
- JLPT: Welche Stufe hat das Wort laut JLPT-Liste (tool/teekueche/daten/jlpt_woerter.json)?
- Stufe: Passt der Wortschatz zur Stufe des Textes (Spezifikation 9.1)?

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\pruefen.py [web\\data\\texte\\...\\text.json]
Ohne Pfad werden alle Texte geprüft. Rückgabewert 1, wenn eine Lesung abweicht.
Mit --uebernehmen werden die JLPT-Stufen der Liste in die Texte geschrieben.
"""

import json
import pathlib
import sys

from sudachipy import Dictionary, SplitMode

ROOT = pathlib.Path(__file__).resolve().parents[2]
JLPT = json.loads((ROOT / "tool" / "teekueche" / "daten" / "jlpt_woerter.json").read_text(encoding="utf-8"))
STUFE_JLPT = {1: 5, 2: 4, 3: 3, 4: 3, 5: 2, 6: 2, 7: 2}
KANA_SHIFT = ord("ァ") - ord("ぁ")
CONTENT_POS = {"名詞", "動詞", "形容詞", "副詞", "形状詞", "連体詞", "接続詞", "感動詞"}


def hira(s: str) -> str:
    return "".join(chr(ord(c) - KANA_SHIFT) if "ァ" <= c <= "ヶ" else c for c in s)


def level(*keys: str) -> int | None:
    for k in keys:
        if k and k in JLPT:
            return JLPT[k]
    return None


def fmt(o, ind: int = 0) -> str:
    """JSON wie in den Texten: jedes Wort auf einer Zeile."""
    pad = "  " * ind
    flat = json.dumps(o, ensure_ascii=False, separators=(", ", ": "))
    if isinstance(o, dict):
        if "t" in o and not any(isinstance(v, dict) for v in o.values()):
            return flat
        items = [f"{pad}  {json.dumps(k, ensure_ascii=False)}: {fmt(v, ind + 1)}" for k, v in o.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(o, list):
        if all(not isinstance(x, (dict, list)) for x in o) or len(flat) < 60:
            return flat
        return "[\n" + ",\n".join(pad + "  " + fmt(x, ind + 1) for x in o) + "\n" + pad + "]"
    return json.dumps(o, ensure_ascii=False)


def check(path: pathlib.Path, tok, apply: bool = False) -> int:
    doc = json.loads(path.read_text(encoding="utf-8"))
    stufe = doc["stufe"]
    user = STUFE_JLPT[stufe]
    errors = 0
    counts = {"passt": 0, "darüber": 0, "weit darüber": 0, "unbekannt": 0}
    notes = []
    seen: set[str] = set()
    print(f"\n== {doc['id']} (Stufe {stufe}, N{user}) ==")

    for si, s in enumerate([{"tokens": doc["title"]}] + doc["sentences"]):
        text = "".join(t["t"] for t in s["tokens"])
        ms = tok.tokenize(text, SplitMode.C)
        pos = 0
        for t in s["tokens"]:
            start, end = pos, pos + len(t["t"])
            pos = end
            inside = [m for m in ms if m.begin() >= start and m.end() <= end]
            aligned = inside and inside[0].begin() == start and inside[-1].end() == end
            where = "Titel" if si == 0 else f"Satz {si}"
            if t.get("r") and aligned:
                sudachi = hira("".join(m.reading_form() for m in inside))
                if sudachi != t["r"]:
                    errors += 1
                    print(f"  LESUNG  {where}: {t['t']} – Text: {t['r']}, Sudachi: {sudachi}")
            elif t.get("r") and not aligned:
                notes.append(f"{where}: Wortgrenze bei {t['t']} weicht von Sudachi ab")

            if not t.get("g") or not inside:
                continue
            # Lehnwörter in Katakana zählen nicht; jedes Wort zählt nur einmal.
            if all("ァ" <= c <= "ヺ" or c == "ー" for c in t["t"]):
                continue
            word_key = t.get("b") or t["t"]
            first = word_key not in seen
            seen.add(word_key)
            head = next((m for m in inside if m.part_of_speech()[0] in CONTENT_POS), None)
            if head is None:
                continue
            if head.part_of_speech()[1] == "固有名詞":
                continue
            lemma = head.dictionary_form()
            lemma_r = hira(tok.tokenize(lemma, SplitMode.C)[0].reading_form()) if lemma else ""
            # Zuerst das ganze Wort (お茶, ください), dann Sudachis Grundform.
            kana_only = t.get("r") is None
            found = level(
                f"{t['t']}|{t.get('r', '')}",
                t["t"],
                t.get("b", ""),
                t["t"] if kana_only else "",
                f"{lemma}|{lemma_r}",
                lemma,
            )
            if apply:
                if found is None:
                    t.pop("j", None)
                else:
                    t["j"] = found
            if not first:
                continue
            if found is None:
                counts["unbekannt"] += 1
                notes.append(f"{where}: {t['t']} ({lemma}) steht in keiner JLPT-Liste")
            elif found >= user:
                counts["passt"] += 1
            elif found == user - 1:
                counts["darüber"] += 1
            else:
                counts["weit darüber"] += 1
                notes.append(f"{where}: {t['t']} ist N{found} – weit über N{user}")
            if t.get("j") is not None and found is not None and t["j"] != found:
                notes.append(f"{where}: {t['t']} hat im Text N{t['j']}, laut Liste N{found}")

    total = sum(counts.values()) or 1
    share = {k: round(100 * v / total) for k, v in counts.items()}
    print(f"  Wörter: {total} · passend {share['passt']} % · eine Stufe darüber {share['darüber']} % · "
          f"weit darüber {share['weit darüber']} % · nicht in den Listen {share['unbekannt']} %")
    for n in notes:
        print(f"  Hinweis {n}")
    print(f"  {'OK' if errors == 0 else f'{errors} Lesung(en) prüfen'}")
    if apply:
        path.write_text(fmt(doc) + "\n", encoding="utf-8")
        print("  JLPT-Stufen aus der Liste übernommen.")
    return errors


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    apply = "--uebernehmen" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tok = Dictionary(dict="core").tokenizer()
    paths = [pathlib.Path(p) for p in args] or sorted((ROOT / "web" / "data" / "texte").rglob("text.json"))
    errors = sum(check(p, tok, apply) for p in paths)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
