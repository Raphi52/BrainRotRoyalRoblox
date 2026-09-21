# -*- coding: utf-8 -*-
"""Banc des POINTS FORTS (src/shared/Reperes.lua + la fiche de carte), hors Studio.

Defaut corrige le 2026-09-21 : quatre cartes du catalogue (Tralalero, Brr Brr Patapim, Tigrullini,
Giraffa) n'ont AUCUNE regle speciale. Ce n'est pas un defaut en soi — un jeu a besoin de cartes
simples — mais leur fiche n'affichait alors que des nombres bruts. Pour savoir si « portee 15 »
c'est loin, il fallait ouvrir les 46 autres fiches et comparer de tete. La description de Giraffa
promet « portee record » et rien ne le confirmait.

Ce qu'il verifie :
  1. le rang se calcule sur le VRAI catalogue, sorts et batiments exclus ;
  2. le record se dit autrement que le haut du panier ;
  3. une carte moyenne n'affiche RIEN (pas de ligne tiede) ;
  4. le texte suit le catalogue : une carte plus rapide retire la mention a l'ancienne ;
  5. les deux ecrans passent le point fort a la fiche.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Reperes.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    C = lua.execute("return (function() " + CARDS.read_text(encoding="utf-8") + " end)()")
    tbl = lua.table_from

    # 1. QUI ENTRE DANS LA COMPARAISON
    cas("une unite se compare", True, R.comparable(C.byId["Giraffa"]))
    # Un batiment ne bouge pas, un sort n'a ni PV ni vitesse : les melanger fabriquerait des
    # « records » qui ne veulent rien dire.
    cas("un batiment non", False, R.comparable(C.byId["TorreCannoli"]))
    cas("un sort non plus", False, R.comparable(C.byId["PizzaBombarda"]))
    cas("et rien du tout non plus", False, R.comparable(None))

    # 2. LE RECORD SE DIT AUTREMENT QUE LE HAUT DU PANIER
    giraffa = [x for x in R.points(C.byId["Giraffa"], C.list).values()]
    cas("la plus longue portee est nommee comme telle", True,
        any("la plus longue portee du jeu" in x for x in giraffa))
    tigru = [x for x in R.points(C.byId["Tigrullini"], C.list).values()]
    cas("la suivante est seulement dans le haut", True, "longue portee" in tigru)
    cas("et ne se declare pas record", False, any("du jeu" in x for x in tigru))
    # La description de Giraffa promet « portee record » : le jeu doit le CONFIRMER.
    cas("la promesse de la carte est tenue", True, "record" in C.byId["Giraffa"]["desc"])

    # 3. PAS DE LIGNE TIEDE
    cas("une carte moyenne n'a aucun point fort", 0,
        len(list(R.points(C.byId["Tralalero"], C.list).values())))
    cas("et sa ligne est vide", "", R.texte(R.points(C.byId["Tralalero"], C.list)))
    cas("un batiment non plus", "", R.texte(R.points(C.byId["TorreCannoli"], C.list)))
    # Deux mentions au maximum : au-dela, la fiche se transforme en palmares.
    for c in C.list.values():
        n = len(list(R.points(c, C.list).values()))
        if n > int(R.MAX_MENTIONS):
            cas("jamais plus de %d mentions (%s)" % (int(R.MAX_MENTIONS), c["id"]), True, False)
            break

    # 4. LE TEXTE SUIT LE CATALOGUE, il n'est pas ecrit a la main
    petit = tbl([
        tbl({"id": "a", "hp": 100, "dmg": 10, "range": 5, "speed": 10}),
        tbl({"id": "b", "hp": 200, "dmg": 20, "range": 9, "speed": 5}),
    ])
    a, b = petit[1], petit[2]
    cas("dans ce catalogue, b tient le record de portee", True,
        any("la plus longue portee" in x for x in R.points(b, petit).values()))
    cas("et a celui de vitesse", True,
        any("la carte la plus rapide" in x for x in R.points(a, petit).values()))
    # On ajoute une carte encore plus rapide : l'ancienne PERD sa mention, sans toucher au code.
    plusVite = tbl([petit[1], petit[2], tbl({"id": "c", "hp": 50, "dmg": 5, "range": 1, "speed": 99})])
    cas("une carte plus rapide retire la mention a l'ancienne", False,
        any("la carte la plus rapide" in x for x in R.points(a, plusVite).values()))
    cas("et la donne a la nouvelle", True,
        any("la carte la plus rapide" in x for x in R.points(plusVite[3], plusVite).values()))
    # Egalite au sommet : deux cartes a la meme portee sont toutes les deux « la plus longue ».
    egal = tbl([tbl({"id": "x", "hp": 1, "dmg": 1, "range": 9, "speed": 1}),
                tbl({"id": "y", "hp": 1, "dmg": 1, "range": 9, "speed": 1})])
    cas("une egalite au sommet donne le record aux deux", True,
        any("la plus longue portee" in x for x in R.points(egal[1], egal).values())
        and any("la plus longue portee" in x for x in R.points(egal[2], egal).values()))
    # Un catalogue d'une seule carte ne fabrique pas un record : il n'y a personne a battre.
    seule = tbl([tbl({"id": "z", "hp": 1, "dmg": 1, "range": 1, "speed": 1})])
    cas("une carte seule n'est championne de rien", 0, len(list(R.points(seule[1], seule).values())))

    # 5. LES ECRANS L'AFFICHENT
    fiche = (ROOT / "src" / "shared" / "Fiche.lua").read_text(encoding="utf-8")
    cas("la fiche pose la ligne fournie", True, "local pf = extras and extras.pointFort" in fiche)
    cas("et n'invente rien sans elle", True, 'type(pf) == "string" and pf ~= ""' in fiche)
    for nom, chemin in (("le hub", ROOT / "src" / "client" / "Hub.client.lua"),
                        ("l'ecran de jeu", ROOT / "src" / "client" / "GameClient.client.lua")):
        txt = chemin.read_text(encoding="utf-8")
        cas("%s calcule le point fort sur le catalogue" % nom, True,
            "R.texte(R.points(Cards.byId[id], Cards.list))" in txt)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les chiffres d'une carte sont situes dans le catalogue, sans rien ecrire a la main")
    return 0


sys.exit(main())
