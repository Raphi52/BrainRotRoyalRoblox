# -*- coding: utf-8 -*-
"""Compare deux series de simulation : sorts AU NIVEAU (nouvelle regle) contre sorts insensibles
au niveau (ancienne regle), a parties egales par ailleurs.

Question posee (2026-09-21) : appliquer le niveau aux degats des sorts desequilibre-t-il le jeu ?
Trois mesures, par regle et par serie (5-5 = niveaux egaux et eleves, 1-5 = gros ecart) :
  - taux de victoire du camp fort (en 1-5 : la regle creuse-t-elle l'ecart ?) ;
  - duree des parties (des sorts plus forts raccourcissent-ils les parties ?) ;
  - degats de sort envoyes par partie (quelle part du combat ils prennent).

Lit les journaux Studio du jour ; chaque ligne porte `regle=nouvelle|ancienne`.
"""
import glob
import io
import os
import re
import statistics
import sys
from math import comb

JOUR = sys.argv[1] if len(sys.argv) > 1 else None
MOTIF = re.compile(
    r"\[SIM\] (\d+)-(\d+) partie=(\d+) gagnant=(\w+) couronnes_fort=(\d+) couronnes_faible=(\d+) "
    r"pv_tours_fort=(\d+) pv_tours_faible=(\d+) temps_restant=(-?\d+) sorts_fort=(\d+) "
    r"sorts_faible=(\d+) regle=(\w+)")


def binom_p(k, n):
    """Probabilite, sous « 50/50 », d'un ecart au moins aussi grand (bilateral)."""
    if n == 0:
        return 1.0
    return sum(comb(n, i) for i in range(n + 1) if abs(i - n / 2) >= abs(k - n / 2)) / 2 ** n


def main():
    logs = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "logs", "*.log"))
    parties = {}
    for f in logs:
        if JOUR and JOUR not in os.path.basename(f):
            continue
        try:
            texte = io.open(f, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        for m in MOTIF.finditer(texte):
            na, nb, k, g, cf, cd, pf, pd, tr, sf, sd, regle = m.groups()
            cle = (regle, "%s-%s" % (na, nb))
            # une partie = (fichier, numero) : une meme ligne ne compte qu'une fois
            parties.setdefault(cle, {})[(f, int(k))] = dict(
                gagnant=g, temps=int(tr), sorts=int(sf) + int(sd))
    if not parties:
        print("aucune partie [SIM] avec le champ regle= trouvee")
        return 1
    print("%-9s %-5s %4s  %-18s %-14s %-12s" % ("regle", "serie", "n", "fort gagne", "duree moy.", "sorts/partie"))
    for (regle, serie), p in sorted(parties.items()):
        l = list(p.values())
        n = len(l)
        fort = sum(1 for x in l if x["gagnant"] == "fort")
        duree = statistics.mean(180 - x["temps"] for x in l)
        sorts = statistics.mean(x["sorts"] for x in l)
        print("%-9s %-5s %4d  %2d/%-2d (p=%.2f)     %5.0f s        %6.0f"
              % (regle, serie, n, fort, n, binom_p(fort, n), duree, sorts))
    return 0


sys.exit(main())
