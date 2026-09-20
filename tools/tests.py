# -*- coding: utf-8 -*-
"""Lance TOUTE la batterie tools/test_*.py et rend UN seul code de sortie.

Pourquoi ce fichier existe : chaque test est autonome et se lance a la main, mais rien
ne donnait un verdict GLOBAL. Un outil exterieur (ou une personne pressee) devait donc
ecrire sa propre boucle a chaque fois, et pouvait en oublier un. Ici : une commande,
un verdict.

    python tools/tests.py            # tout
    python tools/tests.py equilibre  # seulement les tests dont le nom contient "equilibre"

Code de sortie : 0 si TOUS passent, sinon le nombre de tests rouges.
"""
import pathlib
import subprocess
import sys
import time

DOSSIER = pathlib.Path(__file__).resolve().parent


def main(argv):
    filtre = argv[0] if argv else ""
    fichiers = sorted(f for f in DOSSIER.glob("test_*.py") if filtre in f.name)
    if not fichiers:
        print("AUCUN TEST : rien ne correspond a %r dans %s" % (filtre, DOSSIER))
        return 1
    rouges = []
    debut = time.time()
    for f in fichiers:
        t = time.time()
        p = subprocess.run([sys.executable, str(f)], capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        derniere = [l for l in (p.stdout or "").splitlines() if l.strip()]
        resume = derniere[-1][:90] if derniere else (p.stderr or "").strip().splitlines()[-1][:90]
        etat = "OK  " if p.returncode == 0 else "ROUGE"
        print("%s %-28s %5.1fs  %s" % (etat, f.name, time.time() - t, resume))
        if p.returncode != 0:
            rouges.append((f.name, p.stdout, p.stderr))
    print("\n%d tests en %.0fs : %d rouge(s)" % (len(fichiers), time.time() - debut, len(rouges)))
    for nom, out, err in rouges:
        print("\n===== %s =====" % nom)
        print((out or "").strip()[-1500:])
        print((err or "").strip()[-1500:])
    return len(rouges)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
