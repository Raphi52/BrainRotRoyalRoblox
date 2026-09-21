# -*- coding: utf-8 -*-
"""Banc de la DEFENSE (src/shared/Defense.lua) : ne repondre qu'a ce qui n'est pas deja couvert.

Defaut mesure le 2026-09-21, duel normal contre expert, 60 parties : l'expert ne gagnait que
40 %, avec 9,0 defenses par attaque contre 3,8 au normal. Le serveur defendait des qu'une menace
existait, sans regarder ce qui la couvrait deja : tant que l'unite ennemie vivait, chaque cycle
de reflexion reposait une carte. Plus le robot reflechissait vite, plus il sur-defendait.

Ce qu'il verifie :
  1. une menace deja tenue ne declenche plus de nouvelle defense ;
  2. une menace pas encore tenue, si ;
  3. sans menace, on ne defend jamais ;
  4. l'exigence de couverture est bornee des deux cotes ;
  5. SIMULATION du defaut : sur une meme menace qui dure, combien de cartes un robot rapide
     posait-il AVANT, et combien APRES ? Le nombre ne doit plus dependre de sa vitesse ;
  6. le serveur compte les unites engagees dans la BONNE voie, et applique la regle avant de
     choisir de defendre.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Defense.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — le robot repose une defense a chaque cycle" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    D = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    c = float(D.COUVERTURE)
    print("  couverture exigee : %.0f %% des PV de la menace" % (100 * c))

    # 1 + 2. couverte / pas couverte
    cas("menace de 800 PV, 1000 PV engages : couverte", True, D.couverte(800, 1000))
    cas("donc on ne repose rien", False, D.doitRepondre(800, 1000))
    cas("menace de 800 PV, 300 PV engages : pas couverte", False, D.couverte(800, 300))
    cas("donc on defend", True, D.doitRepondre(800, 300))
    cas("pile a egalite : couverte", True, D.couverte(800, 800 * c))
    cas("un point en dessous : pas couverte", False, D.couverte(800, 800 * c - 1))
    cas("il manque exactement ce qu'il faut", 500.0, float(D.manque(800, 300)))
    cas("rien ne manque une fois couverte", 0.0, float(D.manque(800, 1200)))

    # 3. sans menace
    cas("aucune menace : couverte d'office", True, D.couverte(0, 0))
    cas("aucune menace : on ne defend JAMAIS", False, D.doitRepondre(0, 0))
    cas("menace negative (absurde) : rien", False, D.doitRepondre(-50, 0))
    cas("entrees absentes : rien ne casse", False, D.doitRepondre(None, None))

    # 4. bornes de l'exigence
    cas("exigence farfelue haute : plafonnee",
        True, D.couverte(100, 100 * float(D.COUVERTURE_MAX)) and
        not D.couverte(100, 100 * float(D.COUVERTURE_MAX) - 1, 99))
    cas("exigence farfelue basse : relevee au plancher",
        False, D.couverte(100, 100 * float(D.COUVERTURE_MIN) - 1, 0))

    # 5. SIMULATION DU DEFAUT. Une menace de 900 PV reste 12 s dans sa moitie. Le robot pose une
    # unite de 500 PV quand il defend. On compte les cartes posees selon son temps de reflexion.
    def simule(reflexe, avec_regle):
        t, engages, poses = 0.0, 0.0, 0
        while t < 12.0:
            menace = 900.0
            if avec_regle:
                if D.doitRepondre(menace, engages):
                    poses += 1
                    engages += 500
            else:
                poses += 1          # ancien code : `elseif enDanger then` a chaque cycle
                engages += 500
            t += reflexe
        return poses

    print("  meme menace pendant 12 s — cartes posees en defense :")
    print("    %-22s %-8s %s" % ("temps de reflexion", "AVANT", "APRES"))
    avant, apres = {}, {}
    for nom, r in (("normal (2,4 s)", 2.4), ("aguerri (1,7 s)", 1.7), ("expert (1,1 s)", 1.1)):
        avant[nom], apres[nom] = simule(r, False), simule(r, True)
        print("    %-22s %-8d %d" % (nom, avant[nom], apres[nom]))
    cas("AVANT : l'expert posait plus que le normal (le defaut)", True,
        avant["expert (1,1 s)"] > avant["normal (2,4 s)"])
    cas("APRES : tous posent autant, quelle que soit leur vitesse", 1,
        len(set(apres.values())))
    cas("et juste ce qu'il faut pour couvrir 900 PV avec des unites de 500", 2,
        apres["expert (1,1 s)"])

    # 6. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("le serveur charge le module", True, 'WaitForChild("Defense")' in serveur)
    cas("il compte ses unites engagees par voie", True, "engages[voie]" in code)
    cas("il ne defend que si la menace n'est pas couverte", True,
        "enDanger and Defense.doitRepondre(" in code)
    cas("la raison est nommee quand il s'abstient", True, "defense_couverte" in code)
    cas("le module est livre dans la place", True,
        "shared/Defense.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : une menace deja tenue n'appelle plus de renfort, quelle que soit la vitesse du robot")
    return 0


if __name__ == "__main__":
    sys.exit(main())
