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

    # 9. BARRE DE MONTEE. `Arenes.progression` etait ecrite, testee... et appelee par PERSONNE.
    # La ligne de texte disait « X dans 40 trophees », mais un chiffre ne se compare pas d'un coup
    # d'oeil : on ne voyait pas si l'on etait au debut du palier ou a deux victoires de la montee.
    seuils = [a["seuil"] for a in paliers]
    cas("au seuil exact, la barre est vide", 0.0, float(A.progression(seuils[1])))
    cas("juste avant le palier suivant, elle est presque pleine", True,
        float(A.progression(seuils[2] - 1)) > 0.9)
    cas("a mi-chemin, elle est a la moitie", True,
        abs(float(A.progression((seuils[1] + seuils[2]) / 2)) - 0.5) < 0.05)
    cas("bornee entre 0 et 1", True,
        0.0 <= float(A.progression(0)) <= 1.0 and 0.0 <= float(A.progression(99999)) <= 1.0)
    # Derniere arene : il n'y a plus rien a atteindre, la barre est pleine.
    cas("la derniere arene rend une barre pleine", 1.0, float(A.progression(seuils[-1] + 500)))

    hub = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    cas("le hub trace la barre", True, "montee.jauge.Size = UDim2.new(Arenes.progression(v.trophees or 0)" in hub)
    # Elle disparait a la derniere arene, ou elle n'aurait plus de sens.
    cas("elle disparait quand il n'y a plus de palier", True, "montee.fond.Visible = suivante ~= nil" in hub)

    # 10. MONTEE D'ARENE ANNONCEE. Defaut mesure le 2026-09-20 : franchir un palier versait
    # jusqu'a 1800 pieces et ouvrait des cartes en boutique EN SILENCE. L'ecran de fin affichait
    # « +30 trophees   +12 pieces » : les pieces de palier n'y etaient meme pas comptees.
    client = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
    cas("une partie ordinaire n'annonce rien", None, A.montee(seuils[1] + 10, seuils[1] + 40))
    m = A.montee(seuils[1] + 10, seuils[2])
    cas("franchir un palier l'annonce", paliers[2]["nom"], m["nom"])
    cas("avec la recompense versee", paliers[2]["recompense"], m["pieces"])
    cas("et les cartes ouvertes", len(list(paliers[2]["deblocage"].values())),
        len(list(m["cartes"].values())))
    cas("le coffre annonce est celui de la nouvelle arene", paliers[2]["coffre"], m["coffre"])
    # SAUT DE DEUX PALIERS : on annonce la plus HAUTE arene, mais TOUTES les cartes ouvertes.
    m2 = A.montee(seuils[1] - 1, seuils[3])
    cas("deux paliers d'un coup : la plus haute arene est nommee", paliers[3]["nom"], m2["nom"])
    cas("la recompense cumule les deux", paliers[1]["recompense"] + paliers[2]["recompense"]
        + paliers[3]["recompense"], m2["pieces"])
    cas("et toutes les cartes des paliers franchis sont citees", True,
        len(list(m2["cartes"].values())) > len(list(m["cartes"].values())))
    # Une descente n'annonce jamais une montee.
    cas("descendre n'annonce rien", None, A.montee(seuils[2], seuils[1]))

    lignes = [x for x in A.lignesMontee(m, lambda i: "Carte " + i).values()]
    cas("la premiere ligne nomme l'arene", True, lignes[0].startswith("NOUVELLE ARENE : "))
    cas("une ligne dit les pieces", True, any("+%d pieces" % paliers[2]["recompense"] in l for l in lignes))
    # Les NOMS de cartes, pas les identifiants : « Bicus » ne dit rien de plus que l'id, mais une
    # carte au nom affiche en boutique doit se retrouver.
    cas("les cartes sont nommees, pas identifiees", True, any("Carte " in l for l in lignes))
    cas("accord au pluriel sur deux cartes", True, any("Nouvelles cartes" in l for l in lignes))
    cas("quatre lignes au plus (le cadre en tient quatre)", True, len(lignes) <= 4)
    cas("aucune montee : aucune ligne", 0, len(list(A.lignesMontee(None).values())))
    # Sans traducteur, l'identifiant brut passe : mieux qu'une ligne vide.
    cas("sans traducteur, l'identifiant s'affiche quand meme", True,
        any("Bicus" in l for l in A.lignesMontee(m).values()))

    # LE SERVEUR LE FAIT REMONTER, ET L'ECRAN L'AFFICHE ------------------------------------------
    cas("la recompense de fin porte la montee", True, "montee = Arenes.montee(avant, p.trophees)" in eco)
    cas("avec les cartes traduites en noms", True, "monteeLignes = Arenes.lignesMontee(montee," in eco)
    # Les pieces de palier etaient versees au profil sans figurer dans le « +N pieces » affiche :
    # le joueur voyait un total FAUX.
    cas("les pieces affichees comptent le palier", True, "pieces = pieces + palier," in eco)
    cas("l'ecran de fin affiche les lignes", True, "hud.majMontee(g.monteeLignes)" in client)
    cas("et les efface sans montee", True, "hud.majMontee(nil)" in client)
    cas("le cadre disparait quand il n'y a rien a dire", True,
        "hud.montee.cadre.Visible = n > 0" in client)

    # 9. L'ENJEU SUIT L'ADVERSAIRE. Defaut mesure le 2026-09-21 : +30 par victoire QUEL QUE SOIT
    #    l'adversaire — le robot debutant (qui remplace l'adversaire apres 20 s d'attente) autant
    #    qu'un humain. On grimpait au classement mondial en battant le robot en boucle.
    # Sans adversaire precise, l'ancien enjeu reste identique (compatibilite).
    cas("sans adversaire, victoire : enjeu de base", 130, A.apres(100, "victoire"))
    cas("sans adversaire, defaite : enjeu de base", 485, A.apres(500, "defaite"))
    # Contre le ROBOT : le tiers seulement, dans les deux sens.
    cas("victoire contre le robot : le tiers", 110, A.apres(100, "victoire", None, False))
    cas("defaite contre le robot : le tiers", 495, A.apres(500, "defaite", None, False))
    # LE SCENARIO QUI COMPTE : combien de victoires contre le robot pour atteindre l'arene 3 (600) ?
    def victoires_pour(cible, humain):
        t, n = 0, 0
        while t < cible and n < 10000:
            t = A.apres(t, "victoire", t if humain else None, True if humain else False)
            n += 1
        return n
    avant_robot = -(-600 // 30)  # ancienne regle : 20 victoires, robot ou humain
    robot = victoires_pour(600, False)
    humain = victoires_pour(600, True)
    cas("contre le robot, il faut beaucoup plus de victoires pour grimper", True, robot >= 2.5 * avant_robot)
    cas("contre des humains de meme niveau, la progression ne change pas", avant_robot, humain)
    cas("la voie la plus rapide passe par les humains", True, humain < robot)
    # Contre un HUMAIN : l'ecart de trophees compte.
    cas("battre plus fort rapporte plus", True,
        A.variation("victoire", 1000, 1600, True) > A.variation("victoire", 1000, 1000, True))
    cas("battre plus faible rapporte moins", True,
        A.variation("victoire", 1000, 400, True) < A.variation("victoire", 1000, 1000, True))
    cas("perdre contre plus faible coute plus", True,
        A.variation("defaite", 1000, 400, True) < A.variation("defaite", 1000, 1000, True))
    cas("perdre contre plus fort coute moins", True,
        A.variation("defaite", 1000, 1600, True) > A.variation("defaite", 1000, 1000, True))
    # Bornes : une seule partie ne decide jamais de tout.
    cas("gain plafonne a 1,5 fois", 45, A.variation("victoire", 0, 99999, True))
    cas("gain jamais sous la moitie", 15, A.variation("victoire", 99999, 0, True))
    cas("perte plafonnee a 1,5 fois", -23, A.variation("defaite", 99999, 0, True))
    cas("perte jamais sous la moitie", -8, A.variation("defaite", 0, 99999, True))
    # L'egalite ne bouge rien, contre qui que ce soit.
    cas("egalite contre un humain : rien", 0, A.variation("egalite", 1000, 1600, True))
    cas("egalite contre le robot : rien", 0, A.variation("egalite", 1000, None, False))
    # Le plancher protege tient toujours, meme contre un adversaire bien plus faible.
    cas("le plancher protege tient contre un adversaire faible", 100, A.apres(100, "defaite", 0, True))

    # 10. Branchement : l'economie transmet l'adversaire, le serveur fige les trophees AVANT.
    serveur = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")
    cas("l'economie transmet l'adversaire a la regle", True,
        "Arenes.apres(avant, issue, tropheesAdverses, contreHumain == true)" in eco)
    cas("le serveur transmet les trophees de l'adversaire", True,
        "enFace and tropheesAvant[3 - camp] or nil" in serveur)
    # Les joueurs sont recompenses l'un APRES l'autre : sans cliche prealable, le second lirait les
    # trophees du premier deja mis a jour, et l'enjeu dependrait de l'ordre de la boucle.
    fin = serveur.split("local tropheesAvant = {}")[1] if "local tropheesAvant = {}" in serveur else ""
    cas("les trophees sont figes AVANT la premiere recompense", True,
        bool(fin) and fin.index("tropheesAvant[camp] = Economie.tropheesDe(joueur)")
        < fin.index("Economie.recompenser(joueur"))

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les paliers nomment, protegent, recompensent et debloquent")
    return 0


sys.exit(main())
