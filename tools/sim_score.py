"""Transforme le journal d'une simulation --sim="v:N" en resultat reussi/rate lisible sans IA.

Usage : python tools/sim_score.py <journal Studio> [--seuil K]
Compte les lignes « [SIM] vs partie=... gagnant=nouveau|ancien|egalite ».
Codes de sortie : 0 = nouveau robot gagne >= K parties ; 1 = moins de K ; 2 = aucune partie lue
(ou nombre de parties different du BILAN imprime par le jeu).
Seuil par defaut : 75 % des parties, arrondi au-dessus (6/8, 15/20).
"""
import math
import re
import sys

PARTIE = re.compile(r"\[SIM\] vs partie=(\d+) gagnant=(\w+)")
BILAN = re.compile(r"\[SIM\] vs BILAN nouveau=(\d+)/(\d+)")


def main(argv):
    if not argv or argv[0].startswith("--"):
        print(__doc__)
        return 2
    texte = open(argv[0], encoding="utf-8", errors="replace").read()
    gagnants = [g for _, g in PARTIE.findall(texte)]
    if not gagnants:
        print("AUCUNE_PARTIE : pas de ligne [SIM] vs partie dans le journal")
        return 2
    n = len(gagnants)
    gagnes = gagnants.count("nouveau")
    bilan = BILAN.search(texte)
    if bilan and (int(bilan.group(1)), int(bilan.group(2))) != (gagnes, n):
        print(f"INCOHERENT : compte={gagnes}/{n} BILAN du jeu={bilan.group(1)}/{bilan.group(2)}")
        return 2
    seuil = int(argv[argv.index("--seuil") + 1]) if "--seuil" in argv else math.ceil(0.75 * n)
    ok = gagnes >= seuil
    print(f"{'REUSSI' if ok else 'RATE'} nouveau={gagnes}/{n} ancien={gagnants.count('ancien')} "
          f"egalite={gagnants.count('egalite')} seuil={seuil}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
