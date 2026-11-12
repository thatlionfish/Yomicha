"""Teeküche, Schritte 3–6: macht aus einem Entwurf einen fertigen Text.

Claude schreibt nur einen Entwurf (werkstatt/entwuerfe/<id>.json):

{
  "id": "2026-11-13-matcha-export-3",      # Datum-Thema-Stufe
  "date": "2026-11-13", "topic": "tee", "type": "nachricht", "stufe": 3,
  "title": "抹茶の輸出", "titleDe": "Matcha-Export",
  "absaetze": [["1. Satz。", "2. Satz。"], ["3. Satz。"]],
  "glossar": {"抹茶": "Matcha", "輸出": "Export", "2:で": "mit"},   # Schreibung, Grundform oder "Satz:Schreibung"
  "lesungen": {"3:今日": "こんにち"},                               # nur wenn Sudachi falsch liest
  "grammatik": [{"id": "g1", "pattern": "〜ので", "j": 4, "de": "…", "ex": "…", "exDe": "…",
                 "stellen": [[1, "ので"]]}],                      # Satz (ab 1) und Textstück
  "fragen": [{"kind": "inhalt", "q": "…", "qDe": "…", "options": ["…"], "answer": 0,
              "explain": "…", "evidence": [1]}],                  # evidence: Sätze ab 1
  "sources": [{"name": "NHK", "url": "https://…"}]
}

Das Werkzeug zerlegt mit Sudachi in lernfreundliche Wörter (Wort + Endungen),
setzt Lesungen, Furigana, Grundform, JLPT-Stufe, Bedeutung und Grammatik,
gibt Fragen Furigana und schreibt web/data/texte/<jahr>/<monat>/<id>/text.json
sowie das Verzeichnis web/data/texte/index.json. Fehlende Bedeutungen werden gemeldet.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\zerlegen.py werkstatt\\entwuerfe\\<id>.json [...]
Rückgabewert 1, wenn Bedeutungen fehlen (dann Glossar ergänzen und neu laufen lassen).
"""

import json
import pathlib
import re
import sys

from sudachipy import Dictionary, SplitMode

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pruefen import STUFE_JLPT, fmt, hira, word_level  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
KANJI = re.compile(r"[㐀-䶿一-鿿豈-﫿々]")
CONTENT = {"名詞", "代名詞", "動詞", "形容詞", "副詞", "形状詞", "連体詞", "接続詞", "感動詞"}
ATTACH_PARTICLES = {"て", "で", "ば", "たら", "ちゃ", "じゃ"}
# Feste Wendungen, die Sudachi teilt, die man aber als ein Wort lernt.
FIXED = {
    "ので", "のに", "でも", "それに", "それで", "けれど", "けれども", "だから", "なので", "のです", "んです", "とは",
    "だれか", "なにか", "何か", "どこか", "いつか", "これから", "それから", "ここから",
}
TOPIC_LABELS = {"tee": "Tee", "mode": "Mode", "welt": "Weltgeschehen", "jlpt": "JLPT-Thema"}


def align(surface: str, reading: str) -> list[list[str]] | None:
    """Verteilt die Lesung auf die Kanji: 飲みます/のみます → [[飲, の], [みます, ""]]."""
    runs = re.findall(r"[㐀-䶿一-鿿豈-﫿々]+|[^㐀-䶿一-鿿豈-﫿々]+", surface)
    if len(runs) == 1:
        return None
    pattern = "".join("(.+?)" if KANJI.match(r) else "(" + re.escape(hira(r)) + ")" for r in runs)
    m = re.fullmatch(pattern, reading)
    if not m:
        return None
    return [[run, m.group(i + 1) if KANJI.match(run) else ""] for i, run in enumerate(runs)]


def chunks(tok, text: str) -> list[list]:
    """Sudachi-Morpheme → lernfreundliche Wörter (Listen von Morphemen)."""
    out: list[list] = []
    pending_prefix: list = []
    for m in tok.tokenize(text, SplitMode.C):
        pos = m.part_of_speech()
        p1, p2 = pos[0], pos[1]
        prev = out[-1] if out else None
        prev_head = prev[0].part_of_speech()[0] if prev else None
        prev_last = prev[-1] if prev else None
        if p1 == "接頭辞":
            pending_prefix.append(m)
            continue
        attach = False
        inflecting = prev_head in {"動詞", "形容詞", "形状詞"}
        if prev and not pending_prefix:
            if m.dictionary_form() == "です":
                attach = False  # です bleibt immer ein eigenes Wort
            elif p1 == "助動詞" and inflecting:
                attach = True  # 飲み+ます, 寒く+なかった; です/だ nach Nomen bleiben eigene Wörter
            elif p1 == "接尾辞":
                attach = True  # みな+さん
            elif p1 == "助詞" and p2 == "接続助詞" and m.surface() in ATTACH_PARTICLES and prev_head in {"動詞", "形容詞"}:
                attach = True  # 飲ん+で
            elif (p1 == "形容詞" and p2 == "非自立可能" and prev_head in {"動詞", "形容詞"}
                  and prev_last.part_of_speech()[5].startswith("連用形")):
                attach = True  # 飲み+やすい, 苦く+ない
            elif p1 == "動詞" and p2 == "非自立可能" and m.dictionary_form() == "いる" and prev_last.surface() in {"て", "で"}:
                attach = True  # 高まって+いる (〜ている bleibt am Verb)
            elif p1 == "形状詞" and p2 == "助動詞語幹" and prev_head in {"動詞", "形容詞"}:
                attach = True  # 続き+そうだ, 使える+ように
            elif pos[2] == "助数詞可能" and prev[-1].part_of_speech()[1] == "数詞":
                attach = True  # 数+年, 三+人
        if attach:
            prev.append(m)
        else:
            out.append([*pending_prefix, m])
        pending_prefix = []
    if pending_prefix:
        out.append(pending_prefix)
    # Feste Wendungen zusammenfügen (の+で → ので, それ+に → それに).
    merged: list[list] = []
    for c in out:
        if merged:
            joined = "".join(m.surface() for m in merged[-1] + c)
            if joined in FIXED:
                merged[-1] = merged[-1] + c
                continue
        merged.append(c)
    return merged


def make_token(ms: list, sentence_no: int, draft: dict, missing: set) -> dict:
    surface = "".join(m.surface() for m in ms)
    tok: dict = {"t": surface}
    head = next((m for m in ms if m.part_of_speech()[0] in CONTENT), ms[0])
    pos1 = head.part_of_speech()[0]
    if pos1 == "補助記号" or pos1 == "空白":
        return tok
    reading = hira("".join(m.reading_form() for m in ms))
    override = draft.get("lesungen", {}).get(f"{sentence_no}:{surface}") or draft.get("lesungen", {}).get(surface)
    if override:
        reading = override
    if KANJI.search(surface):
        tok["r"] = reading
        segs = align(surface, reading)
        if segs:
            tok["ruby"] = segs
    # Grundform: Vorsilbe + Grundform des Kernworts (お+茶 → お茶, 飲み+ます → 飲む).
    i = ms.index(head)
    prefix = "".join(m.surface() for m in ms[:i] if m.part_of_speech()[0] == "接頭辞")
    suffixes = [m for m in ms[i + 1 :] if m.part_of_speech()[0] == "接尾辞"]
    if suffixes:
        # みな+さん → みなさん, 飲み+やすかった → 飲みやすい
        base = prefix + head.surface() + "".join(s.surface() for s in suffixes[:-1]) + suffixes[-1].dictionary_form()
    else:
        base = prefix + head.dictionary_form()
    if surface in FIXED or head.part_of_speech()[1] == "数詞":
        base = surface
    if base != surface:
        tok["b"] = base
    content = pos1 in CONTENT or surface in FIXED
    glossary = draft.get("glossar", {})
    gloss = (glossary.get(f"{sentence_no}:{surface}") or glossary.get(surface) or glossary.get(base)
             or glossary.get(head.dictionary_form()))
    if gloss:
        tok["g"] = gloss
    elif content and not (head.part_of_speech()[1] == "数詞" and len(ms) == 1):
        missing.add(f"Satz {sentence_no}: {surface}" + (f" ({base})" if base != surface else ""))
    if content:
        base_reading = hira(head.reading_form()) if base == head.dictionary_form() else ""
        found = word_level(surface, reading if KANJI.search(surface) else "", tok.get("b", ""), base_reading)
        if found is not None:
            tok["j"] = found
    return tok


def tokenize_sentence(tok, text: str, sentence_no: int, draft: dict, missing: set) -> list[dict]:
    return [make_token(ms, sentence_no, draft, missing) for ms in chunks(tok, text)]


def ruby_markup(tok, text: str, user_jlpt: int, kanji_levels: dict) -> str:
    """Fragen und Antworten: Furigana für Wörter mit Kanji oberhalb der Stufe."""
    if "{" in text:
        return text
    out = []
    for ms in chunks(tok, text):
        surface = "".join(m.surface() for m in ms)
        if not KANJI.search(surface):
            out.append(surface)
            continue
        reading = hira("".join(m.reading_form() for m in ms))
        hard = any((kanji_levels.get(k) or 0) < user_jlpt for k in surface if KANJI.match(k))
        if not hard:
            out.append(surface)
            continue
        segs = align(surface, reading) or [[surface, reading]]
        out.append("".join(f"{{{b}|{r}}}" if r else b for b, r in segs))
    return "".join(out)


def kanji_levels() -> dict:
    levels = {}
    for f in (ROOT / "web" / "data" / "kanji").glob("*.json"):
        if f.name == "teile.json":
            continue
        for k, v in json.loads(f.read_text(encoding="utf-8")).items():
            levels[k] = v.get("j")
    return levels


def wants_audio(stufe: int, date: str) -> bool:
    """Audio für meine Stufe und die darüber (Speicherplatz, Spezifikation 11);
    während des Aufbaus mit dem Startguthaben für alle Stufen."""
    cfg = json.loads((ROOT / "tool" / "teekueche" / "config.json").read_text(encoding="utf-8"))
    if date <= cfg["aufbau_bis"]:
        return True
    return stufe - cfg["stufe"] in cfg["audio_fuer_stufen"]


def build(path: pathlib.Path, tok, levels: dict) -> tuple[dict, set]:
    draft = json.loads(path.read_text(encoding="utf-8"))
    missing: set[str] = set()
    user_jlpt = STUFE_JLPT[draft["stufe"]]
    audio = wants_audio(draft["stufe"], draft["date"])

    sentences = []
    n = 0
    for para in draft["absaetze"]:
        for i, text in enumerate(para):
            n += 1
            s = {"tokens": tokenize_sentence(tok, text, n, draft, missing)}
            if audio:
                s["audio"] = f"s{n:02d}.mp3"
            if i == 0 and sentences:
                s = {"p": True, **s}
            sentences.append(s)

    # Grammatik: Stellen (Satz ab 1, Textstück) → gr bei den Wörtern darin.
    grammar = []
    for g in draft.get("grammatik", []):
        for satz, piece in g.get("stellen", []):
            s = sentences[satz - 1]
            text = "".join(t["t"] for t in s["tokens"])
            start = text.find(piece)
            if start < 0:
                missing.add(f"Grammatik {g['id']}: „{piece}“ nicht in Satz {satz}")
                continue
            pos = 0
            for t in s["tokens"]:
                a, b = pos, pos + len(t["t"])
                pos = b
                if a < start + len(piece) and b > start:
                    t["gr"] = g["id"]
        grammar.append({k: v for k, v in g.items() if k != "stellen"})

    questions = []
    for q in draft.get("fragen", []):
        q = dict(q)
        q["q"] = ruby_markup(tok, q["q"], user_jlpt, levels)
        q["options"] = [ruby_markup(tok, o, user_jlpt, levels) for o in q["options"]]
        q["evidence"] = [e - 1 for e in q.get("evidence", [])]
        questions.append(q)

    doc = {
        "id": draft["id"],
        "date": draft["date"],
        "topic": draft["topic"],
        "type": draft.get("type", "essay"),
        "stufe": draft["stufe"],
        "titleDe": draft["titleDe"],
        "title": tokenize_sentence(tok, draft["title"], 0, draft, missing),
        "sentences": sentences,
        "grammar": grammar,
        "questions": questions,
        "sources": draft.get("sources", []),
    }
    return doc, missing


def write(doc: dict) -> pathlib.Path:
    y, m = doc["date"][:4], doc["date"][5:7]
    folder = ROOT / "web" / "data" / "texte" / y / m / doc["id"]
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "text.json").write_text(fmt(doc) + "\n", encoding="utf-8")
    return folder


def link_versions_and_index() -> None:
    """Verknüpft die Stufen desselben Inhalts und schreibt das Verzeichnis neu."""
    texte = ROOT / "web" / "data" / "texte"
    docs = []
    for f in sorted(texte.rglob("text.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        d["_folder"] = f.parent.relative_to(ROOT / "web" / "data").as_posix()
        d["_file"] = f
        docs.append(d)
    by_content: dict[str, list] = {}
    for d in docs:
        content = re.sub(r"-\d$", "", d["id"])
        by_content.setdefault(content, []).append(d)
    for group in by_content.values():
        versions = {str(d["stufe"]): d["_folder"] for d in group}
        for d in group:
            others = {k: v for k, v in sorted(versions.items()) if k != str(d["stufe"])}
            if d.get("versions", {}) == others:
                continue
            clean = {k: v for k, v in d.items() if not k.startswith("_")}
            if others:
                clean["versions"] = others
            else:
                clean.pop("versions", None)
            d["_file"].write_text(fmt(clean) + "\n", encoding="utf-8")
            d["versions"] = others
    entries = []
    for d in docs:
        chars = sum(len(t["t"]) for s in d["sentences"] for t in s["tokens"])
        entries.append({
            "id": d["id"],
            "folder": d["_folder"],
            "date": d["date"],
            "topic": d["topic"],
            "stufe": d["stufe"],
            "title": "".join(t["t"] for t in d["title"]),
            "titleDe": d["titleDe"],
            "minutes": max(1, round(chars / 80)),
        })
    entries.sort(key=lambda e: (e["date"], e["id"]), reverse=True)
    (texte / "index.json").write_text(fmt({"texts": entries}) + "\n", encoding="utf-8")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    tok = Dictionary(dict="core").tokenizer()
    levels = kanji_levels()
    missing_any = False
    for p in sys.argv[1:]:
        doc, missing = build(pathlib.Path(p), tok, levels)
        folder = write(doc)
        chars = sum(len(t["t"]) for s in doc["sentences"] for t in s["tokens"])
        print(f"{doc['id']}: {len(doc['sentences'])} Sätze, {chars} Zeichen → {folder.relative_to(ROOT)}")
        for m in sorted(missing):
            print(f"  FEHLT {m}")
        missing_any |= bool(missing)
    link_versions_and_index()
    print("Verzeichnis web/data/texte/index.json aktualisiert.")
    sys.exit(1 if missing_any else 0)


if __name__ == "__main__":
    main()
