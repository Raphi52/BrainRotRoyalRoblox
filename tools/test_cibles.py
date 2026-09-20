# -*- coding: utf-8 -*-
"""Banc du CHOIX DE CIBLE (src/shared/Cible.lua), hors Studio.

Deux defauts mesures avant ce module, dans `findTarget` :
  1. la cible etait recalculee a chaque image — deux ennemis a distance presque egale faisaient
     PAPILLONNER la tour, qui repartageait ses degats sans jamais achever personne ;
  2. seule la distance comptait — une unite ANTI-TOURS fonçant sur la tour passait apres
     n'importe quel passant plus proche d'un demi-stud.

Ce qu'il verifie :
  1. sans cible en cours, on prend le plus prioritaire (la distance decide par defaut) ;
  2. une TOUR vise en priorite ce qui la menace vraiment (anti-tours), a distance comparable ;
  3. mais un anti-tours tres loin ne passe PAS devant un ennemi au contact ;
  4. une UNITE, elle, ne raisonne pas en menace : elle frappe le plus proche ;
  5. la cible en cours est GARDEE tant qu'aucune autre n'est franchement meilleure ;
  6. elle change des que l'ecart depasse la marge ;
  7. une cible disparue (liste vide) ne bloque rien ;
  8. le serveur applique reellement ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Cible.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — la tour papillonne toujours" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    C = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    tour = lua.table_from(dict(isBuilding=True))
    unite = lua.table_from(dict(isBuilding=False))

    def ennemi(nom, distance, anti=False, batiment=False):
        return lua.table_from(dict(nom=nom, distance=distance,
                                   targets="buildings" if anti else "any", isBuilding=batiment))

    def liste(*e):
        return lua.table_from(list(e))

    bonus = float(C.BONUS_ANTI_TOUR)
    marge = float(C.MARGE_CHANGEMENT)
    print("  bonus anti-tours = %.1f studs, marge de changement = %.1f studs" % (bonus, marge))

    # 1. par defaut, la distance decide
    proche, loin = ennemi("proche", 5), ennemi("loin", 12)
    cas("sans cible en cours : le plus proche", "proche", C.choisir(tour, liste(proche, loin), None).nom)
    cas("l'ordre de la liste ne change rien", "proche", C.choisir(tour, liste(loin, proche), None).nom)

    # 2. menace : a distance comparable, l'anti-tours passe devant
    passant = ennemi("passant", 8)
    belier = ennemi("belier", 10, anti=True)   # 2 studs plus loin, mais anti-tours
    cas("une tour vise d'abord ce qui la detruit", "belier", C.choisir(tour, liste(passant, belier), None).nom)
    cas("la priorite reste lisible en studs", 10 - bonus, float(C.priorite(tour, belier, 10)))
    cas("un ennemi ordinaire n'a aucun bonus", 8.0, float(C.priorite(tour, passant, 8)))

    # 3. mais pas a n'importe quelle distance
    colle = ennemi("colle", 2)
    tresLoin = ennemi("tres_loin", 2 + bonus + 1, anti=True)
    cas("un anti-tours trop loin ne passe pas devant", "colle", C.choisir(tour, liste(colle, tresLoin), None).nom)

    # 4. une unite ne raisonne pas en menace
    cas("une unite frappe le plus proche", "passant", C.choisir(unite, liste(passant, belier), None).nom)
    cas("aucun bonus de menace pour une unite", 10.0, float(C.priorite(unite, belier, 10)))

    # 5 + 6. persistance et hysteresis
    actuelle = ennemi("actuelle", 6)
    quasi = ennemi("quasi", 6 - marge + 0.5)   # meilleure, mais pas assez
    cas("on garde la cible en cours", "actuelle", C.choisir(tour, liste(actuelle, quasi), actuelle).nom)
    franche = ennemi("franche", 6 - marge - 0.5)  # franchement meilleure
    cas("on change pour une menace nettement meilleure", "franche",
        C.choisir(tour, liste(actuelle, franche), actuelle).nom)
    cas("garder : egalite stricte compte comme garder", True, C.garder(6, 6, marge))
    cas("garder : juste sous la marge", True, C.garder(6, 6 - marge, marge))
    cas("garder : au-dela de la marge, on lache", False, C.garder(6, 6 - marge - 0.01, marge))
    cas("sans cible en cours, rien a garder", False, C.garder(None, 3, marge))

    # 7. liste vide
    cas("aucun candidat : aucune cible", None, C.choisir(tour, liste(), None))
    cas("aucun candidat, meme avec une cible en cours", "actuelle",
        C.choisir(tour, liste(), actuelle).nom)

    # 7 bis. LE PAPILLONNAGE, mesure sur 100 images. Deux ennemis dont les distances oscillent
    # autour de la meme valeur : avant, la tour changeait de cible des que l'un passait devant
    # l'autre d'un centieme de stud. On compte les changements reellement produits.
    import math as _m
    choisie, changements = None, 0
    for image in range(100):
        d = _m.sin(image / 3.0) * 0.4      # oscillation de +/- 0,4 stud
        a = ennemi("A", 7 + d)
        b = ennemi("B", 7 - d)
        actuelle_img = None
        if choisie is not None:
            actuelle_img = a if choisie == "A" else b
        nouvelle = C.choisir(tour, liste(a, b), actuelle_img).nom
        if choisie is not None and nouvelle != choisie:
            changements += 1
        choisie = nouvelle
    print("  changements de cible sur 100 images d'oscillation : %d" % changements)
    cas("la tour ne papillonne plus", 0, changements)

    # et elle change QUAND IL LE FAUT : un ennemi qui arrive franchement plus pres
    arrive = ennemi("arrive", 7 - marge - 1)
    courante = ennemi("A", 7)
    cas("mais elle bascule sur une vraie menace", "arrive",
        C.choisir(tour, liste(courante, arrive), courante).nom)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur calcule la priorite", True, "Cible.priorite(" in serveur)
    cas("le serveur garde sa cible", True, "Cible.garder(" in serveur)
    cas("le serveur memorise la cible en cours", True, "e.cibleEnCours" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : la tour vise ce qui la menace et ne papillonne plus")
    return 0


if __name__ == "__main__":
    sys.exit(main())
