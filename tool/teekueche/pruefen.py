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


def has_kanji(s: str) -> bool:
    return any("㐀" <= c <= "鿿" or c == "々" for c in s)


def word_level(surface: str, reading: str = "", base: str = "", base_reading: str = "") -> int | None:
    """JLPT-Stufe eines Wortes – dieselbe Regel für Teeküche und Prüfung:
    gebeugte Wörter über die Grundform (飲みたい → 飲む), Kana-Wörter über
    die leichteste Stufe, Kanji-Wörter zur Not über die Lesung (子ども ↔ 子供)."""
    keys = []
    if base and base != surface:
        keys += [f"{base}|{base_reading}", base]
    if has_kanji(surface):
        keys += [f"{surface}|{reading}", surface]
    else:
        keys += [surface]
    found = level(*keys)
    if found is None and has_kanji(surface) and reading:
        found = level(reading)
    return found


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


# --- Stil: vom Plauderton zum Schriftstil der N2 ---------------------------
# Ab Stufe 3 kein gesprochener Stil in Nachricht, Essay und Meinung; ab Stufe 5
# Schriftsprache wie im Leseteil der N2. Wörtliche Rede in 「」 bleibt frei.

HOEFLICH_ERLAUBT = {"email", "aushang", "infoblatt"}
SATZENDE_PARTIKEL = {"ね", "よ", "な", "なあ", "わ", "ぞ", "ぜ", "さ", "よね"}
KURZFORMEN = {"てる", "でる", "ちゃう", "じゃう", "とく", "どく"}
KURZ_OBERFLAECHE = {"なきゃ", "なくちゃ", "ちゃ", "じゃ", "って", "けど", "っけ"}
UMGANGSWOERTER = {"すごく", "すっごく", "すごい", "やっぱり", "やっぱ", "ちょっと", "いっぱい",
                  "めっちゃ", "とっても", "だって", "じゃあ", "ほんと", "ほんとう"}
SCHRIFT_MUSTER = ["である", "ており", "とされ", "に伴", "につれ", "ものの", "にほかならない",
                  "に対し", "によって", "における", "とともに", "わけではない", "ざるを得", "に過ぎない",
                  "に違いない", "をめぐ", "に応じ", "一方", "とはいえ", "にもかかわらず", "つつ"]
# 「ください」 allein ist noch kein Keigo einer Geschäfts-E-Mail.
KEIGO = {"いたす", "申す", "申し上げる", "いただく", "ござる", "存じる", "伺う", "参る", "おる", "なさる", "いらっしゃる"}


def _ohne_zitate(text: str) -> str:
    """Wörtliche Rede in 「」 durch Leerzeichen ersetzen (gleiche Länge)."""
    out, depth = [], 0
    for ch in text:
        if ch == "「":
            depth += 1
        out.append("　" if depth else ch)
        if ch == "」" and depth:
            depth -= 1
    return "".join(out)


def stil(doc: dict, tok) -> tuple[int, list[str]]:
    """Fehler (müssen umgeschrieben werden) und Hinweise zum Stil."""
    stufe, art = doc["stufe"], doc.get("type", "")
    funde: list[tuple[str, str]] = []  # (Satz, Fund)
    hoeflich = 0
    keigo = False
    gesamt = ""
    for si, s in enumerate(doc["sentences"], start=1):
        text = _ohne_zitate("".join(t["t"] for t in s["tokens"]))
        gesamt += text
        ms = [m for m in tok.tokenize(text, SplitMode.C) if m.surface().strip("　")]
        for i, m in enumerate(ms):
            pos, form, surf = m.part_of_speech(), m.dictionary_form(), m.surface()
            nxt = ms[i + 1].surface() if i + 1 < len(ms) else "。"
            if pos[0] == "助動詞" and form in ("です", "ます"):
                hoeflich += 1
            if form in KEIGO:
                keigo = True
            if pos[1] == "終助詞" and surf in SATZENDE_PARTIKEL and nxt[:1] in "。！？」":
                funde.append((f"Satz {si}", f"Satzende-Partikel 「{surf}」"))
            elif form in KURZFORMEN or (surf in KURZ_OBERFLAECHE and pos[0] in ("助詞", "助動詞")):
                funde.append((f"Satz {si}", f"Kurzform 「{surf}」"))
            elif surf in UMGANGSWOERTER:
                funde.append((f"Satz {si}", f"Umgangswort 「{surf}」"))
        # Sudachi trennt でも in で + も – deshalb am Text erkennen.
        anfang = text.lstrip("　")
        for wort, besser in (("でも", "しかし / だが"), ("だけど", "しかし / だが"), ("じゃあ", "では")):
            if anfang.startswith(wort + "、") or anfang.startswith(wort + "，"):
                funde.append((f"Satz {si}", f"「{wort}」 am Satzanfang (schriftlich: {besser})"))
        if "！" in text and art not in HOEFLICH_ERLAUBT:
            funde.append((f"Satz {si}", "Ausrufezeichen"))

    fehler, hinweise = 0, []
    if stufe <= 2:
        # Höflich und einfach ist richtig; nur kein Plauderton wie in einem Blog.
        if len(funde) > 2:
            fehler = len(funde) - 2
            hinweise.append(f"STIL  {len(funde)} Plauder-Stellen (höchstens 2):")
        else:
            hinweise += [f"STIL  {w}: {f} (erlaubt bis 2)" for w, f in funde]
            funde = []
    else:
        fehler = len(funde)
    hinweise += [f"STIL  {w}: {f}" for w, f in funde]

    if stufe >= 3 and art not in HOEFLICH_ERLAUBT and hoeflich:
        fehler += 1
        hinweise.append(f"STIL  です/ます in einem Text der Art „{art}“ – ab Stufe 3 Schriftform (だ / である)")
    if stufe >= 5:
        treffer = [p for p in SCHRIFT_MUSTER if p in gesamt]
        if art not in HOEFLICH_ERLAUBT and len(treffer) < 2:
            hinweise.append("STIL  kaum Schriftsprache der N2 (z. B. である, 〜ており, 〜に伴い, 〜ものの) – einbauen")
        if art == "email" and not keigo:
            hinweise.append("STIL  E-Mail ohne Keigo (いたします, いただく, ございます …) – wie in der N2 ergänzen")
    return fehler, hinweise


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
            base = t.get("b", "")
            found = word_level(t["t"], t.get("r", ""), base, lemma_r if base == lemma else "")
            if found is None and not base:
                found = level(f"{lemma}|{lemma_r}", lemma)
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
    stil_fehler, stil_hinweise = stil(doc, tok)
    for n in stil_hinweise:
        print(f"  {n}")
    if errors or stil_fehler:
        teile = [f"{errors} Lesung(en) prüfen"] if errors else []
        if stil_fehler:
            teile.append(f"{stil_fehler} Stil-Stelle(n) umschreiben")
        print("  " + " · ".join(teile))
    else:
        print("  OK")
    errors += stil_fehler
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
