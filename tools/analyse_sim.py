# -*- coding: utf-8 -*-
"""Depouille les parties [SIM] 1-1 des journaux Studio du jour et mesure DEUX hypotheses :
   1. l'etiquette « fort » a-t-elle un avantage (elle ne devrait pas : niveaux identiques) ;
   2. le CAMP 1 a-t-il un avantage de COTE (le camp « fort » alterne, on peut donc le retrouver).
Le camp fort est le camp 1 aux parties impaires, le camp 2 aux paires (regle lue dans GameServer).
"""
import glob, io, os, re, sys
from math import comb

JOUR = sys.argv[1] if len(sys.argv) > 1 else "20260920"
logs = glob.glob(os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "logs", "*.log"))
lignes = []
for f in sorted(logs, key=os.path.getmtime):
    if JOUR not in os.path.basename(f):
        continue
    try:
        d = io.open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    trouve = re.findall(
        r"\[SIM\] 1-1 partie=(\d+) gagnant=(\w+) couronnes_fort=(\d+) couronnes_faible=(\d+)", d)
    if trouve:
        lignes.append((os.path.basename(f), trouve))

def binom_p(k, n):
    q = sum(comb(n, i) for i in range(n + 1) if abs(i - n / 2) >= abs(k - n / 2))
    return q / 2 ** n

fort = faible = egal = camp1 = camp2 = 0
cf = cd = 0
total = 0
print("runs depouilles :")
for nom, trouve in lignes:
    print("  %2d parties  %s" % (len(trouve), nom))
    for k, g, a, b in trouve:
        total += 1
        cf += int(a); cd += int(b)
        campFort = 1 if int(k) % 2 == 1 else 2
        if g == "fort":
            fort += 1; gagnant = campFort
        elif g == "faible":
            faible += 1; gagnant = 3 - campFort
        else:
            egal += 1; gagnant = 0
        if gagnant == 1: camp1 += 1
        elif gagnant == 2: camp2 += 1

print()
print("parties totales        : %d" % total)
print("etiquette 'fort'       : %d  (faible %d, egalites %d)" % (fort, faible, egal))
print("  probabilite hasard   : %.3f" % binom_p(fort, total))
print("couronnes              : fort %d / faible %d" % (cf, cd))
print("CAMP 1 (z negatifs)    : %d victoires  (%.0f %%)" % (camp1, 100.0 * camp1 / max(1, total)))
print("CAMP 2 (z positifs)    : %d victoires  (%.0f %%)" % (camp2, 100.0 * camp2 / max(1, total)))
print("  probabilite hasard   : %.3f" % binom_p(camp1, camp1 + camp2))
