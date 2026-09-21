# -*- coding: utf-8 -*-
"""Banc du LISSAGE des brainrots sans modele 3D (src/shared/Arrondi.lua + habillage serveur).

Constat du 2026-09-21 : 11 des 28 brainrots n'ont aucun modele 3D dans la Boutique Roblox (ni avec
ni sans script ; 40 remplacants celebres testes, aucun). Ils etaient assembles en BLOCS a aretes
vives. On les rend desormais en formes lisses, SANS toucher au catalogue.

Ce qu'il verifie :
  1. un bloc ordinaire devient un ellipsoide ; une forme declaree est respectee ;
  2. une PLAQUE (aile, nageoire) reste un bloc, sinon elle disparaitrait vue de profil ;
  3. le lissage ne concerne QUE les brainrots dessines faute de modele (ni batiment, ni sort,
     ni un personnage qui a son modele) ;
  4. sur le VRAI catalogue : les 11 personnages sans modele sont bien lisses, et la majorite de
     leurs morceaux devient ronde (sinon le changement ne se verrait pas) ;
  5. le serveur applique la regle, et le catalogue n'est pas modifie.

Prerequis : python -m pip install lupa
"""
import json
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Arrondi.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
MODELES = ROOT / "tools" / "boutique" / "modeles.json"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }")
    A = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    C = lua.execute("return (function() " + CARDS.read_text(encoding="utf-8") + " end)()")
    v3 = lua.eval("Vector3.new")

    # 1. FORMES
    cas("un bloc ordinaire devient un ellipsoide", "ellipsoide", A.forme(v3(1, 1.2, 0.9), None))
    cas("une boule declaree reste declaree", "declaree", A.forme(v3(1, 1, 1), "boule"))
    cas("un cylindre declare aussi", "declaree", A.forme(v3(1, 2, 1), "cylindre"))
    # 2. PLAQUES : un ellipsoide tres plat se reduit a une ligne vue de profil.
    cas("une aile fine reste une plaque", "plaque", A.forme(v3(3, 0.2, 1.5), None))
    cas("juste au-dessus du seuil, c'est un ellipsoide", "ellipsoide", A.forme(v3(1, 0.25, 1), None))
    cas("sans taille, on arrondit quand meme", "ellipsoide", A.forme(None, None))

    # 3. A QUI ON L'APPLIQUE
    byId = C.byId
    cas("un brainrot sans modele est lisse", True, A.applicable(byId["Ballerina"], False))
    cas("pas un brainrot qui a son modele", False, A.applicable(byId["Tralalero"], True))
    cas("pas un batiment", False, A.applicable(byId["TorreCannoli"], False))
    # UNITES QUI NE SONT PAS DES BRAINROTS (2026-09-21) : elles restaient les dernieres en blocs
    # dans une arene devenue ronde. Elles sont lissees aussi ; les batiments, non.
    autres = ["ScudoBanana", "DottorePizza", "BombaSalsiccia", "ReginaGhiaccio",
              "SerpenteVeleno", "AquilaFrizzante", "MinatoreMozzarella"]
    for i in autres:
        cas("%s (unite, pas un brainrot) est lisse" % i, True, A.applicable(byId[i], False))
        cas("%s a une silhouette a lisser" % i, True,
            byId[i]["morceaux"] is not None and len(list(byId[i]["morceaux"].values())) > 0)
    for i in ["TorreCannoli", "PompaElixir", "NidoBrainrot", "MuroSpaghetti"]:
        cas("%s (batiment) reste angulaire" % i, False, A.applicable(byId[i], False))
    cas("pas un sort", False, A.applicable(byId["PizzaBombarda"], False))
    cas("pas une carte absente", False, A.applicable(None, False))

    # 4. SUR LE VRAI CATALOGUE
    modeles = set(json.loads(MODELES.read_text(encoding="utf-8")))
    sans = [c for c in C.list.values()
            if c["hauteurModele"] is not None and c["sort"] is None and c["batiment"] is None
            and (c["modele"] or c["id"]) not in modeles]
    cas("onze brainrots n'ont pas de modele", 11, len(sans))
    cas("tous seront lisses", True, all(A.applicable(c, False) for c in sans))
    total = ronds = 0
    for c in sans:
        for m in (c["morceaux"] or {}).values():
            total += 1
            if A.forme(m["taille"], m["forme"]) != "plaque":
                ronds += 1
    print("  %d morceaux sur %d deviennent ronds (ellipsoide ou forme declaree)" % (ronds, total))
    # Le changement doit SE VOIR : si la majorite restait en plaques, rien n'aurait change.
    cas("la majorite des morceaux devient ronde", True, total > 0 and ronds / total > 0.6)

    # 4 bis. MODELES EN BLOCS ECARTES. Six brainrots ont un modele dans la Boutique, mais il est
    # lui-meme en blocs (verifie sur les apercus, tools/boutique/planche-actuels.png). Pour eux, la
    # silhouette lissee remplace le modele.
    ecartes = ["Trippi", "Frigo", "Giraffa", "Tralaleritos", "Tigrullini", "Bananita"]
    for i in ecartes:
        cas("%s : modele en blocs ecarte" % i, False, A.modeleRetenu(i))
        # Il doit avoir des morceaux, sinon l'ecarter le ferait DISPARAITRE au lieu de le lisser.
        cas("%s : a une silhouette de repli" % i, True,
            byId[i]["morceaux"] is not None and len(list(byId[i]["morceaux"].values())) > 0)
        cas("%s : sera lisse" % i, True, A.applicable(byId[i], False))
        cas("%s : son modele reste disponible (retour possible)" % i, True, i in modeles)
    # Un modele premium, lui, reste retenu.
    for i in ["Tralalero", "TungSahur", "Patapim", "Boneca"]:
        cas("%s : modele premium garde" % i, True, A.modeleRetenu(i))
    tous_lisses = [c for c in C.list.values()
                   if c["hauteurModele"] is not None and c["sort"] is None and c["batiment"] is None
                   and ((c["modele"] or c["id"]) not in modeles or not A.modeleRetenu(c["modele"] or c["id"]))]
    cas("dix-sept brainrots rendus en formes lisses (11 sans modele + 6 en blocs)", 17, len(tous_lisses))

    # 5. LE SERVEUR APPLIQUE, LE CATALOGUE N'EST PAS TOUCHE
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge la regle", True, 'WaitForChild("Arrondi")' in serveur)
    cas("il n'arrondit que les cartes concernees", True, "local lisser = arrondi.applicable(card, false)" in serveur)
    cas("il pose un maillage sphere sur les blocs", True,
        'arrondi.forme(m.taille, m.forme) == "ellipsoide"' in serveur
        and "lisse.MeshType = Enum.MeshType.Sphere" in serveur)
    cas("le catalogue ne connait pas cette regle", False, "Arrondi" in CARDS.read_text(encoding="utf-8"))
    # LE PORTRAIT DE LA CARTE suit la meme regle : sans lui, le personnage etait rond dans l'arene
    # et en blocs sur sa carte en main (capture cap-lisse-1.png du 2026-09-21).
    fig = (ROOT / "src" / "shared" / "Figurine.lua").read_text(encoding="utf-8")
    cas("le portrait des cartes charge la meme regle", True, 'WaitForChild("Arrondi")' in fig)
    cas("le serveur ecarte les modeles en blocs", True,
        "if MODELES and arrondi.modeleRetenu(card.modele or card.id) then" in serveur)
    cas("le portrait aussi, sinon il divergerait de l'arene", True,
        'if modeles and require(Shared:WaitForChild("Arrondi")).modeleRetenu(carte.modele or carte.id) then' in fig)
    # PIEGE MESURE le 2026-09-21 : « a and b and c » rendait `false` pour un modele ecarte, et la
    # ligne suivante appelait une methode sur ce booleen — le menu entier restait fige.
    cas("aucune chaine and/and qui pourrait rendre false comme modele", False,
        ("modeleRetenu(carte.id)" + chr(10) + chr(9) + chr(9) + "and modeles:FindFirstChild") in fig
        or "arrondi.modeleRetenu(card.id) and MODELES" in serveur)
    cas("et lisse les memes morceaux", True,
        'arrondi.forme(m.taille, m.forme) == "ellipsoide"' in fig and "Enum.MeshType.Sphere" in fig)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les brainrots sans modele sont rendus en formes lisses, catalogue intact")
    return 0


sys.exit(main())
