"""Stufen, für die die Teeküche heute schreibt.

Leonis Wunsch (13.11.2026): **zwei Fassungen pro Text – ihre Stufe und eine
darüber**. Einen Vorrat gibt es nicht; für Ferien sagt sie Bescheid (Ferienpaket). Ihre Stufe steht in config.json
(`stufe`); die App kann sie nicht melden, der Lernstand liegt nur auf ihrem
Gerät. Steigt sie in der App auf, sagt ihr die Startseite, sie soll Claude die
neue Stufe nennen – dann `stufe` hier nachführen.

Die Zielkurve (Spezifikation 9.4) wird nur angezeigt: Liegt sie mehr als eine
Stufe über `stufe`, ist das ein guter Anlass, Leoni nach ihrem Stand zu fragen.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\stufen_heute.py [JJJJ-MM-TT]
"""

import datetime as dt
import json
import pathlib
import sys

# Wie lib/learn/goal.dart: Gyokuro (6) Ende August 2027, Matcha (7) Ende November.
GYOKURO = dt.date(2027, 8, 31)
MATCHA = dt.date(2027, 11, 30)


def zielstufe(start: dt.date, startstufe: int, day: dt.date) -> float:
    def lerp(a: dt.date, va: float, b: dt.date, vb: float) -> float:
        t = (day - a).days / (b - a).days
        return va + (vb - va) * min(max(t, 0.0), 1.0)

    if day <= start:
        return float(startstufe)
    if day <= GYOKURO:
        return lerp(start, startstufe, GYOKURO, 6)
    if day <= MATCHA:
        return lerp(GYOKURO, 6, MATCHA, 7)
    return 7.0


def stufen_heute(cfg: dict, day: dt.date) -> dict:
    s = int(cfg["stufe"])
    kurve = cfg.get("zielkurve", {})
    start = dt.date.fromisoformat(kurve.get("start", "2026-11-12"))
    z = zielstufe(start, int(kurve.get("startstufe", 2)), day)

    def clip(offsets: list[int]) -> list[int]:
        return [x for x in sorted({s + o for o in offsets}) if 1 <= x <= 7]

    out = {
        "datum": day.isoformat(),
        "stufe": s,
        "stufen": clip(cfg.get("stufen_fenster", [0, 1])),
        "zielstufe": round(z, 2),
    }
    if z - s > 1:
        out["hinweis"] = "Die Zielkurve liegt mehr als eine Stufe darüber – Leoni nach ihrer Stufe fragen."
    return out


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(__file__).resolve().parents[2]
    cfg = json.loads((root / "tool" / "teekueche" / "config.json").read_text(encoding="utf-8"))
    day = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else dt.date.today()
    print(json.dumps(stufen_heute(cfg, day), ensure_ascii=False))


if __name__ == "__main__":
    main()
