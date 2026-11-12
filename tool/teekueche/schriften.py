"""Verkleinert die japanischen Schriften auf die Zeichen, die Yomicha braucht.

Enthalten sind alle Jōyō-Kanji, alle Kanji aus den Texten, Kana, japanische
Satzzeichen und lateinische Grundzeichen. Seltene Zeichen außerhalb davon
lädt der Browser bei Bedarf als Ersatzschrift nach.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\schriften.py werkstatt\\quellen
"""

import json
import pathlib
import sys

from fontTools import subset

FONTS = {
    "ZenOldMincho-Regular.ttf": "ZenOldMincho-Yomicha.ttf",
    "KleeOne-Regular.ttf": "KleeOne-Yomicha.ttf",
}

RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x00A0, 0x00FF),  # Latin-1 (Umlaute)
    (0x2010, 0x2027),  # Striche, Anführungszeichen, …
    (0x2190, 0x2193),  # Pfeile
    (0x2460, 0x2473),  # ①–⑳
    (0x25A0, 0x25CF),  # ■□▲△○●
    (0x2E80, 0x2EFF),  # CJK-Radikale (Ergänzung) – für die Zerlegung
    (0x2F00, 0x2FDF),  # Kangxi-Radikale
    (0x3000, 0x303F),  # japanische Satzzeichen
    (0x3040, 0x309F),  # Hiragana
    (0x30A0, 0x30FF),  # Katakana
    (0x31F0, 0x31FF),  # kleine Katakana
    (0xFF01, 0xFF5E),  # Vollbreite Zeichen
]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    quellen = pathlib.Path(sys.argv[1])
    root = pathlib.Path(__file__).resolve().parents[2]
    chars: set[str] = set()
    for a, b in RANGES:
        chars.update(chr(c) for c in range(a, b + 1))
    jouyou = json.loads((quellen / "jlpt-kanji" / "kanji-jouyou.json").read_text(encoding="utf-8"))
    chars.update(jouyou.keys())
    text_chars: set[str] = set()
    for f in (root / "web" / "data").rglob("*.json"):
        text_chars.update(ch for ch in f.read_text(encoding="utf-8") if ord(ch) >= 0x2E80)
    chars |= text_chars

    # Klee One (Lehrbuchschrift) steht nur auf den Kanji-Karten: Kanji N5–N2,
    # Radikale und die Kanji aus den Texten genügen.
    card_chars = {k for k, v in jouyou.items() if (v.get("jlpt_new") or 0) >= 2}
    card_chars |= {ch for ch in text_chars if ord(ch) >= 0x3400}
    card_chars.update(chr(c) for c in range(0x2E80, 0x2FE0))
    card_chars.update(chr(c) for c in range(0x0020, 0x007F))

    out_dir = root / "assets" / "fonts"
    for src, dst in FONTS.items():
        text = "".join(sorted(card_chars if src.startswith("Klee") else chars))
        opts = subset.Options()
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.name_legacy = True
        opts.name_languages = ["*"]
        opts.notdef_outline = True
        font = subset.load_font(str(quellen / "schriften" / src), opts)
        sub = subset.Subsetter(opts)
        sub.populate(text=text)
        sub.subset(font)
        target = out_dir / dst
        subset.save_font(font, str(target), opts)
        print(f"{dst}: {target.stat().st_size / 1024:,.0f} KB")


if __name__ == "__main__":
    main()
