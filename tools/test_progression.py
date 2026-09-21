# -*- coding: utf-8 -*-
"""Banc : combien de VICTOIRES avant l'arene suivante (src/shared/Progression.lua + accueil).

Defaut mesure le 2026-09-21 : l'accueil disait « Plage Tralalero dans 200 trophees ». Un nombre de
trophees ne dit pas combien de parties gagner — et depuis la regle Arenes du meme jour (le robot ne
rapporte que le tiers), la reponse triple selon l'adversaire. Le joueur ne le voyait pas.
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "src" / "shared" / "Progression.lua").read_text(encoding="utf-8")
ARE = (ROOT / "src" / "shared" / "Arenes.lua").read_text(encoding="utf-8")
HUB = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    P = LuaRuntime().execute(SRC)
    # Toutes les fonctions existent des le chargement (lecon du 2026-09-21, Adversaire.lua).
    frais = LuaRuntime().execute(SRC)
    absentes = [n for n in re.findall(r"^function Progression\.(\w+)", SRC, re.M) if frais[n] is None]
    cas("toutes les fonctions existent au chargement", [], absentes)

    cas("200 trophees a 30 par victoire : 7 victoires", 7, P.victoires(200, 30))
    cas("un seul trophee manquant demande encore une victoire", 1, P.victoires(1, 30))
    cas("rien ne manque : zero", 0, P.victoires(0, 30))
    cas("aucun gain : pas de nombre infini promis", None, P.victoires(50, 0))
    t = P.texte("Plage Tralalero", 200, 30, 1 / 3)
    cas("la ligne donne les trophees", True, "Plage Tralalero dans 200 trophees" in t)
    cas("les victoires contre des joueurs", True, "~7 victoires" in t)
    # 200 / (30 x 1/3) = 20 : le robot demande trois fois plus de victoires.
    cas("et contre le robot", True, "20 contre le robot" in t)
    cas("accord au singulier", True, "(~1 victoire" in P.texte("X", 10, 30, 1 / 3))
    cas("sans reduction robot, on ne parle que des joueurs", "Y dans 60 trophees (~2 victoires)",
        P.texte("Y", 60, 30, None))
    cas("derniere arene", "derniere arene", P.texte(None, 0, 30, 1 / 3))
    # Les reglages sont LUS dans Arenes par l'ecran, jamais recopies.
    cas("l'accueil lit le gain et la part robot dans Arenes", True,
        "Arenes.GAIN_VICTOIRE, Arenes.PART_ROBOT)" in HUB)
    cas("et ces reglages existent bien dans Arenes", True,
        "Arenes.GAIN_VICTOIRE = 30" in ARE and "Arenes.PART_ROBOT = 1 / 3" in ARE)
    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : l'accueil dit combien de victoires il reste, contre un joueur et contre le robot")
    return 0


sys.exit(main())
