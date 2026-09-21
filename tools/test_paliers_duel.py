# -*- coding: utf-8 -*-
"""Banc du DUEL DE PALIERS (Robot.paliersDuel) : faire s'affronter deux niveaux de robot.

Pourquoi : `BRR_ROBOT` n'acceptait qu'un seul nom, donc les deux camps jouaient toujours au meme
palier. Le classement des quatre paliers — debutant < normal < aguerri < expert — n'avait donc
JAMAIS ete verifie en partie : il reposait entierement sur l'intention des reglages.

Ce qu'il verifie :
  1. « a:b » donne bien un palier different a chaque camp ;
  2. ALTERNANCE : le camp qui porte le premier palier change a chaque partie — sinon on
     mesurerait la force du palier ET l'avantage de cote dans le meme chiffre ;
  3. sur une serie, chaque palier tient chaque camp exactement la moitie du temps ;
  4. un nom seul garde l'ancien comportement (les deux camps au meme niveau) ;
  5. les noms cites existent vraiment parmi les paliers declares ;
  6. entrees farfelues : rien ne casse, et on retombe sur l'ancien comportement ;
  7. le serveur applique la regle.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from collections import Counter
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Robot.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    noms = [p.nom for p in R.PALIERS.values()]
    print("  paliers declares : " + ", ".join(noms))
    cas("les quatre paliers existent", 4, len(noms))

    # 0. LE CLASSEMENT DES PALIERS DOIT ETRE MONOTONE.
    # Mesure du 2026-09-21, 120 parties (les six duels deux a deux) : debutant 35 victoires,
    # normal 33, aguerri 27, expert 25 — l'INVERSE EXACT de l'ordre voulu. Cause : correlation
    # r = +0,98 entre le seuil d'attaque (`gardeElixir`) et les victoires. Plus le robot attaque
    # tot, plus il perd. Ce banc fige les trois progressions qui doivent aller dans le bon sens.
    paliers = [R.PALIERS[i + 1] for i in range(len(R.PALIERS))]
    ordre = [p.nom for p in paliers]
    cas("les paliers vont du plus tendre au plus dur",
        ["debutant", "normal", "aguerri", "expert"], ordre)
    refl = [float(p.reflexe) for p in paliers]
    err = [float(p.erreur) for p in paliers]
    garde = [float(p.gardeElixir) for p in paliers]
    print("  reflexe %s | erreur %s | seuil d'attaque %s" % (refl, err, garde))
    # Experience du 2026-09-21 (duel normal contre expert, 60 parties par reglage) : a 1,1 s de
    # reflexion l'expert gagnait 35 a 42 % selon son seuil ; ramene a 2,4 s, il gagne 67 %
    # (p = 0,013). Un robot qui reflechit trop vite reagit a tout et se disperse. La vitesse ne
    # separe donc plus les paliers hauts ; seul le debutant reste plus lent.
    cas("le debutant reflechit plus lentement que les autres", True,
        all(refl[0] > r for r in refl[1:]))
    cas("la vitesse ne separe PLUS les paliers hauts", 1, len(set(refl[1:])))
    cas("le taux d'erreur DIMINUE avec le niveau", True,
        all(err[i] > err[i + 1] for i in range(len(err) - 1)))
    # LE POINT QUI AVAIT ETE MANQUE : ce seuil etait decroissant, et il dominait tout le reste.
    cas("le seuil d'attaque MONTE avec le niveau (la patience est une force)", True,
        all(garde[i] < garde[i + 1] for i in range(len(garde) - 1)))
    cas("et aucun seuil ne rend le robot inerte", True,
        max(garde) <= float(R.ELIXIR_MAX) - 1)

    # 1. un palier par camp
    cas("partie 1, camp 1 : premier palier", "normal", R.paliersDuel("normal:expert", 1, 1))
    cas("partie 1, camp 2 : second palier", "expert", R.paliersDuel("normal:expert", 2, 1))

    # 2. ALTERNANCE a la partie suivante
    cas("partie 2, camp 1 : les roles s'echangent", "expert",
        R.paliersDuel("normal:expert", 1, 2))
    cas("partie 2, camp 2 : idem", "normal", R.paliersDuel("normal:expert", 2, 2))
    cas("partie 3 : retour a l'ordre initial", "normal",
        R.paliersDuel("normal:expert", 1, 3))

    # 3. sur une serie, chaque palier tient chaque camp la MOITIE du temps
    serie = 40
    c1 = Counter(R.paliersDuel("normal:expert", 1, k) for k in range(1, serie + 1))
    c2 = Counter(R.paliersDuel("normal:expert", 2, k) for k in range(1, serie + 1))
    print("  sur %d parties — camp 1 : %s | camp 2 : %s" % (serie, dict(c1), dict(c2)))
    cas("le premier palier tient le camp 1 la moitie du temps", serie // 2, c1["normal"])
    cas("et le camp 2 l'autre moitie", serie // 2, c2["normal"])
    cas("aucune partie sans palier", 0,
        sum(1 for k in range(1, serie + 1) if R.paliersDuel("normal:expert", 1, k) is None))
    # les deux camps ne portent JAMAIS le meme palier : sinon ce ne serait plus un duel
    memes = sum(1 for k in range(1, serie + 1)
                if R.paliersDuel("normal:expert", 1, k) == R.paliersDuel("normal:expert", 2, k))
    cas("les deux camps ne sont jamais au meme palier", 0, memes)

    # 4. un nom seul : ancien comportement
    cas("un nom seul n'est pas un duel", None, R.paliersDuel("expert", 1, 1))
    cas("ni pour l'autre camp", None, R.paliersDuel("expert", 2, 1))

    # 5. les noms cites existent
    for duel in ("debutant:normal", "normal:aguerri", "aguerri:expert", "debutant:expert"):
        a, b = duel.split(":")
        cas("%s : les deux paliers existent" % duel, True, a in noms and b in noms)
        cas("%s : camp 1 en partie 1 porte %s" % (duel, a), a, R.paliersDuel(duel, 1, 1))

    # 6. entrees farfelues
    cas("valeur absente", None, R.paliersDuel(None, 1, 1))
    cas("chaine vide", None, R.paliersDuel("", 1, 1))
    cas("deux-points seuls", None, R.paliersDuel(":", 1, 1))
    cas("trois noms : refuse", None, R.paliersDuel("a:b:c", 1, 1))
    cas("nombre au lieu d'une chaine", None, R.paliersDuel(7, 1, 1))
    cas("sans numero de partie : se comporte comme la partie 1", "normal",
        R.paliersDuel("normal:expert", 1, None))

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("le serveur consulte le duel de paliers", True, "Robot.paliersDuel(" in code)
    # Le numero de partie est porte par l'objet BRR_SIM : le fichier principal du serveur est a
    # la limite des 200 variables locales de Luau, une declaration de plus ne compile pas.
    cas("le serveur ecrit le numero de partie de la serie", True,
        'SIM:SetAttribute("partie", k)' in code)
    cas("et le relit pour choisir le palier", True, 'GetAttribute("partie")' in code)
    cas("et retombe sur un palier unique sinon", True, "Robot.profilNomme(" in code)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : deux paliers s'affrontent, et chacun tient chaque cote la moitie du temps")
    return 0


if __name__ == "__main__":
    sys.exit(main())
