"""Die Teeküche in einem Befehl: alle Schritte, die eine Shell brauchen.

Damit Leoni nicht jeden Morgen viele einzelne Befehle bestätigen muss, ruft
die Teeküche nur noch dieses Skript auf (Dateien liest und schreibt sie mit
ihren Datei-Werkzeugen). Aufruf aus dem Projektordner:

  tool\\teekueche\\.venv\\Scripts\\python.exe -I tool\\teekueche\\lauf.py <schritt> [...]

Schritte:
  stufen                      Stufen für heute (stufen_heute.py)
  zerlegen <entwurf.json>...  Entwürfe zerlegen (zerlegen.py)
  pruefen [text.json]...      Lesungen, JLPT-Stufen und Stil prüfen (pruefen.py --uebernehmen)
  saetze [anzahl]             die nächsten Wörter ohne Beispielsatz (saetze.py naechste, Standard 40)
  saetze-uebernehmen          Beispielsätze aus werkstatt/entwuerfe/saetze.json prüfen und ablegen
  audio                       Aufnahmen erzeugen; bis aufbau_bis mit dem Aufbau-Zugang, danach F0
  hoerkontrolle               Satzaufnahmen der neuen Texte abhören
  satz-neu <ordner> <datei>   eine Satzaufnahme löschen (z. B. nach einer festen Lesung), dann „audio“
  aufraeumen                  alte Texte wegräumen (aufraeumen.py)
  sicherung                   Leonis Lernstand aus GitHub (privat) auf den PC kopieren – höchstens einmal pro Woche
  test                        flutter test
  veroeffentlichen "<text>"   web/data committen und pushen – nichts anderes
  status                      git status (kurz)

Den Azure-Schlüssel gibt das Skript nie aus.
"""

import datetime as dt
import json
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TK = ROOT / "tool" / "teekueche"
PY = sys.executable
F0_KEY = "../learnwithleoni/werkstatt/azure-speech.env"
ATTRIBUTION = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"


def run(cmd: list[str], check: bool = True) -> int:
    """Befehl im Projektordner ausführen, Ausgabe durchreichen (UTF-8)."""
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    shell = sys.platform == "win32" and cmd[0] in ("dart", "flutter")  # .bat auf Windows
    res = subprocess.run(cmd, cwd=ROOT, env=env, shell=shell)
    if check and res.returncode != 0:
        print(f"\n✗ fehlgeschlagen ({res.returncode}): {' '.join(cmd[:3])} …")
        sys.exit(res.returncode)
    return res.returncode


def out(cmd: list[str]) -> str:
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8").stdout


def key_args() -> list[str]:
    """Bis einschließlich aufbau_bis der Aufbau-Zugang (Standard von tts.dart), danach F0."""
    cfg = json.loads((TK / "config.json").read_text(encoding="utf-8"))
    bis = dt.date.fromisoformat(cfg.get("aufbau_bis", "2026-12-03"))
    return [] if dt.date.today() <= bis else [f"--key={F0_KEY}"]


def veroeffentlichen(message: str) -> None:
    run(["git", "add", "-A", "web/data"])
    staged = [f for f in out(["git", "diff", "--cached", "--name-only"]).splitlines() if f.strip()]
    if not staged:
        print("Nichts zu veröffentlichen.")
        return
    bad = [f for f in staged if not f.startswith("web/data/")]
    if bad:
        print("✗ Vorgemerkt sind auch Dateien außerhalb von web/data – nicht veröffentlicht:")
        for f in bad:
            print("   ", f)
        sys.exit(1)
    run(["git", "commit", "-q", "-m", message, "-m", ATTRIBUTION])
    if run(["git", "push", "-q", "origin", "main"], check=False) != 0:
        # Jemand anderes hat inzwischen gepusht (z. B. eine neue App-Version): nachziehen, erneut pushen.
        run(["git", "pull", "-q", "--rebase", "--autostash", "origin", "main"])
        run(["git", "push", "-q", "origin", "main"])
    print(f"✓ veröffentlicht: {len(staged)} Datei(en), {out(['git', 'log', '--oneline', '-1']).strip()}")


def satz_neu(folder: str, name: str) -> None:
    path = (ROOT / folder / name).resolve()
    texte = (ROOT / "web" / "data" / "texte").resolve()
    if texte not in path.parents or path.suffix != ".mp3":
        sys.exit("✗ Nur Satzaufnahmen (.mp3) unter web/data/texte.")
    if path.exists():
        path.unlink()
        print(f"gelöscht: {path.relative_to(ROOT)} – jetzt „audio“ laufen lassen")
    else:
        print("Diese Aufnahme gibt es nicht.")


SICHERUNGS_REPO = "thatlionfish/Yomicha-lernstand"
SICHERUNGEN = ROOT / "werkstatt" / "sicherungen"
SICHERUNGEN_BEHALTEN = 12


def sicherung(immer: bool = False) -> None:
    """Kopiert die wöchentlichen Sicherungen der App (privates Repository) nach
    werkstatt/sicherungen/<datum>/ – nie veröffentlicht. Höchstens einmal pro Woche,
    die letzten 12 Kopien bleiben."""
    SICHERUNGEN.mkdir(parents=True, exist_ok=True)
    alt = sorted(d for d in SICHERUNGEN.iterdir() if d.is_dir())
    heute = dt.date.today()
    if alt and not immer:
        letzte = dt.date.fromisoformat(alt[-1].name)
        if (heute - letzte).days < 7:
            print(f"Letzte Kopie vom {letzte} – noch keine neue nötig.")
            return
    res = subprocess.run(["gh", "api", f"repos/{SICHERUNGS_REPO}/contents/sicherungen"],
                         cwd=ROOT, capture_output=True)
    if res.returncode != 0:
        print("Noch keine Sicherung auf GitHub (oder kein Zugriff) – nichts kopiert.")
        return
    ziel = SICHERUNGEN / heute.isoformat()
    ziel.mkdir(exist_ok=True)
    n = 0
    for e in json.loads(res.stdout.decode("utf-8")):
        if e.get("type") != "file" or not e["name"].endswith(".json"):
            continue
        f = subprocess.run(["gh", "api", "-H", "Accept: application/vnd.github.raw+json",
                            f"repos/{SICHERUNGS_REPO}/contents/sicherungen/{e['name']}"],
                           cwd=ROOT, capture_output=True)
        if f.returncode == 0:
            (ziel / e["name"]).write_bytes(f.stdout)
            n += 1
    for d in sorted(d for d in SICHERUNGEN.iterdir() if d.is_dir())[:-SICHERUNGEN_BEHALTEN]:
        for x in d.iterdir():
            x.unlink()
        d.rmdir()
    print(f"✓ {n} Sicherung(en) nach {ziel.relative_to(ROOT)} kopiert.")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "hilfe"):
        print(__doc__)
        return
    step, args = sys.argv[1], sys.argv[2:]
    if step == "stufen":
        run([PY, "-I", str(TK / "stufen_heute.py"), *args])
    elif step == "zerlegen":
        run([PY, "-I", str(TK / "zerlegen.py"), *args])
    elif step == "pruefen":
        run([PY, "-I", str(TK / "pruefen.py"), "--uebernehmen", *args], check=False)
    elif step == "saetze":
        run([PY, "-I", str(TK / "saetze.py"), "naechste", *args])
    elif step == "saetze-uebernehmen":
        run([PY, "-I", str(TK / "saetze.py"), "uebernehmen"], check=False)
    elif step == "audio":
        run(["dart", "run", "tool/tts.dart", *key_args()])
    elif step == "hoerkontrolle":
        run(["dart", "run", "tool/tts.dart", "--hoerkontrolle", *key_args(), *args], check=False)
    elif step == "satz-neu" and len(args) == 2:
        satz_neu(*args)
    elif step == "sicherung":
        sicherung(immer="--jetzt" in args)
    elif step == "aufraeumen":
        run([PY, "-I", str(TK / "aufraeumen.py"), *args])
    elif step == "test":
        run(["flutter", "test"])
    elif step == "veroeffentlichen" and len(args) == 1:
        veroeffentlichen(args[0])
    elif step == "status":
        print(out(["git", "status", "--short"]) or "Nichts geändert.")
    else:
        sys.exit(f"Unbekannter Schritt: {' '.join(sys.argv[1:])}\n\n{__doc__}")


if __name__ == "__main__":
    main()
