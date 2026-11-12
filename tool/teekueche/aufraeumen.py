"""Teeküche: räumt alte Texte weg, damit das Repository nicht vollläuft.

Gelöscht werden Text-Ordner (Text und Satzaufnahmen), die älter sind als
`aufbewahren_tage` aus tool/teekueche/config.json. Danach wird das Verzeichnis
web/data/texte/index.json neu geschrieben.

Nie gelöscht werden die Wortaufnahmen (web/data/woerter) und Kumachans Sprüche:
Leonis gespeicherte Wörter behalten so ihre Aussprache, auch wenn der Text weg ist.
Satz, Lesung und Bedeutung der Wörter speichert die App ohnehin selbst.

Aufruf (aus dem Projektordner):
  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\aufraeumen.py [--dry]
"""

import datetime
import json
import pathlib
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from zerlegen import link_versions_and_index  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    dry = "--dry" in sys.argv
    cfg = json.loads((ROOT / "tool" / "teekueche" / "config.json").read_text(encoding="utf-8"))
    keep = int(cfg.get("aufbewahren_tage", 90))
    limit = datetime.date.today() - datetime.timedelta(days=keep)
    removed = []
    for f in sorted((ROOT / "web" / "data" / "texte").rglob("text.json")):
        date = datetime.date.fromisoformat(json.loads(f.read_text(encoding="utf-8"))["date"])
        if date < limit:
            removed.append(f.parent)
    for folder in removed:
        print(f"{'würde löschen' if dry else 'gelöscht'}: {folder.relative_to(ROOT)}")
        if not dry:
            shutil.rmtree(folder)
    if not dry:
        # Leere Monats- und Jahresordner entfernen.
        for d in sorted((ROOT / "web" / "data" / "texte").rglob("*"), reverse=True):
            if d.is_dir() and not any(d.iterdir()):
                d.rmdir()
        link_versions_and_index()
    print(f"Aufbewahrt werden {keep} Tage (bis {limit.isoformat()}). {len(removed)} Text(e) {'zu löschen' if dry else 'gelöscht'}.")


if __name__ == "__main__":
    main()
