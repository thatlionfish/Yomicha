"""Stufen, für die die Teeküche heute schreibt.

Grundlage ist Leonis Stufe aus config.json (`stufe`, ab einer Stufe darunter).
Nach oben folgt das Fenster der Zielkurve (Spezifikation 9.4), damit
schwerere Texte bereitstehen, wenn sie in der App aufsteigt – die App kann
ihre Stufe nicht melden, der Lernstand liegt nur auf ihrem Gerät. Höchstens
drei Stufen über `stufe`, also höchstens fünf Fassungen pro Inhalt.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\stufen_heute.py [JJJJ-MM-TT]
"""

import datetime as dt
import json
import math
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


def stufen_heute(cfg: dict, day: dt.date) -> tuple[list[int], float]:
    s = int(cfg["stufe"])
    kurve = cfg.get("zielkurve", {})
    start = dt.date.fromisoformat(kurve.get("start", "2026-11-12"))
    z = zielstufe(start, int(kurve.get("startstufe", 2)), day)
    fenster = cfg.get("stufen_fenster", [-1, 0, 1, 2])
    lower = s + min(fenster)
    upper = min(max(s + max(fenster), math.ceil(z) + 1), s + 3)
    return [x for x in range(lower, upper + 1) if 1 <= x <= 7], z


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(__file__).resolve().parents[2]
    cfg = json.loads((root / "tool" / "teekueche" / "config.json").read_text(encoding="utf-8"))
    day = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else dt.date.today()
    stufen, z = stufen_heute(cfg, day)
    print(json.dumps({"datum": day.isoformat(), "stufe": cfg["stufe"], "zielstufe": round(z, 2), "stufen": stufen}, ensure_ascii=False))


if __name__ == "__main__":
    main()
