# -*- coding: utf-8 -*-
"""Banc des ARENES (src/shared/Arenes.lua + son branchement dans Economie), hors Studio.

Defaut corrige : les trophees n'etaient qu'un nombre. Aucun palier, aucun nom, aucune recompense
en les franchissant, aucune protection en bas de tableau — un debutant qui enchainait les defaites
voyait un compteur qui ne faisait que baisser. Et une carte legendaire s'achetait des la premiere
partie du moment qu'on avait l'or.

Ce qu'il verifie :
  1. chaque total de trophees tombe dans une arene nommee, y compris 0 et une valeur farfelue ;
  2. la progression vers l'arene suivante va de 0 a 1, et vaut 1 dans la derniere ;
  3. une victoire monte, une defaite descend, MAIS jamais sous le plancher protege ;
  4. la recompense de palier est versee une seule fois, meme en sautant deux paliers ;
  5. une carte rattachee a une arene reste verrouillee tant qu'on ne l'a pas atteinte ;
  6. le meilleur coffre possible suit l'arene ;
  7. les paliers sont coherents entre eux (seuils croissants, cartes du vrai catalogue) ;
  8. l'economie applique reellement ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Arenes.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
ECONOMIE = ROOT / "src" / "server" / "Economie.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    A = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cartes = lua.execute(CARDS.read_text(encoding="utf-8"))

    paliers = list(A.LISTE.values())
    print("  %d arenes : %s" % (len(paliers), ", ".join("%s (%d)" % (a["nom"], a["seuil"]) for a in paliers)))

    # 1. nom de l'arene
    cas("un joueur neuf est dans la premiere arene", paliers[0]["nom"], A.nom(0))
    cas("des trophees negatifs retombent sur la premiere", paliers[0]["nom"], A.nom(-500))
    cas("un total enorme reste dans la derniere", paliers[-1]["nom"], A.nom(999999))
    cas("le seuil exact fait entrer dans l'arene", paliers[1]["nom"], A.nom(paliers[1]["seuil"]))

    # 2. progression
    cas("progression nulle a l'entree d'une arene", 0.0, A.progression(paliers[1]["seuil"]))
    cas("progression pleine dans la derniere arene", 1.0, A.progression(paliers[-1]["seuil"] + 10))
    milieu = (paliers[0]["seuil"] + paliers[1]["seuil"]) / 2
    cas("a mi-chemin, la progression vaut la moitie", 0.5, round(A.progression(milieu), 3))

    # 3. montee, descente, protection
    cas("une victoire monte", 500 + int(A.GAIN_VICTOIRE), A.apres(500, "victoire"))
    cas("une defaite descend", 500 - int(A.PERTE_DEFAITE), A.apres(500, "defaite"))
    cas("une egalite ne change rien", 500, A.apres(500, "egalite"))
    cas("sous le plancher, une defaite ne retire plus rien", 30, A.apres(30, "defaite"))
    cas("une defaite ne fait jamais passer sous le plancher", int(A.PLANCHER_PROTEGE),
        A.apres(int(A.PLANCHER_PROTEGE) + 5, "defaite"))
    cas("on peut toujours monter depuis le plancher", int(A.PLANCHER_PROTEGE) + int(A.GAIN_VICTOIRE),
        A.apres(int(A.PLANCHER_PROTEGE), "victoire"))

    # 4. recompense de palier
    cas("aucun palier franchi : aucune recompense", 0, A.recompensePalier(10, 40))
    cas("un palier franchi : sa recompense", paliers[1]["recompense"],
        A.recompensePalier(paliers[1]["seuil"] - 1, paliers[1]["seuil"]))
    deux = paliers[1]["recompense"] + paliers[2]["recompense"]
    cas("deux paliers d'un coup : les deux recompenses, une seule fois", deux,
        A.recompensePalier(0, paliers[2]["seuil"]))
    cas("redescendre ne repaie rien", 0, A.recompensePalier(paliers[2]["seuil"], 0))

    # 5. deblocage des cartes
    verrouillee = list(paliers[3]["deblocage"].values())[0]
    ouverte, arene = A.carteDebloquee(verrouillee, 0)
    cas("carte d'une arene lointaine : verrouillee a 0 trophee", False, ouverte)
    cas("le refus dit dans quelle arene elle vit", paliers[3]["nom"], arene)
    ouverte, _ = A.carteDebloquee(verrouillee, paliers[3]["seuil"])
    cas("arene atteinte : la carte s'ouvre", True, ouverte)
    ouverte, _ = A.carteDebloquee("CarteQuiNExistePas", 0)
    cas("une carte hors paliers est disponible des le depart", True, ouverte)

    # 6. coffres
    cas("premiere arene : pas de coffre d'or", paliers[0]["coffre"], A.coffreMax(0))
    cas("derniere arene : meilleur coffre", paliers[-1]["coffre"], A.coffreMax(paliers[-1]["seuil"]))

    # 7. coherence des paliers et du catalogue
    seuils = [a["seuil"] for a in paliers]
    cas("les seuils sont strictement croissants", sorted(set(seuils)), seuils)
    inconnues = sorted(cid for a in paliers for cid in a["deblocage"].values() if cartes["byId"][cid] is None)
    cas("toutes les cartes des paliers existent au catalogue", [], inconnues)
    offertes = sorted(cid for a in paliers for cid in a["deblocage"].values()
                      if cartes["byId"][cid]["prix"] is None)
    cas("aucune carte OFFERTE n'est verrouillee par une arene", [], offertes)

    # 8. branchement reel
    eco = ECONOMIE.read_text(encoding="utf-8")
    cas("l'economie charge le module", True, 'WaitForChild("Arenes")' in eco)
    cas("les trophees passent par la protection", True, "Arenes.apres(" in eco)
    cas("la recompense de palier est versee", True, "Arenes.recompensePalier(" in eco)
    cas("le coffre est plafonne par l'arene", True, "Arenes.coffreMax(" in eco)
    cas("l'achat verifie l'arene", True, "Arenes.carteDebloquee(" in eco)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les paliers nomment, protegent, recompensent et debloquent")
    return 0


sys.exit(main())
