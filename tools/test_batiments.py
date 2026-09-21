# -*- coding: utf-8 -*-
"""Banc des BATIMENTS POSES (src/shared/Batiments.lua + les cartes-batiments), hors Studio.

Ce qu'il verifie :
  1. un batiment MEURT TOUT SEUL : ses points de vie sont etales sur sa duree de vie, et il
     tient exactement le temps annonce sur la carte quand personne ne le frappe ;
  2. la duree reste bornee, quelle que soit la valeur ecrite sur une carte ;
  3. la pose est limitee a sa moitie, interdite sur la bande de la riviere (sinon il bouche le
     pont) et interdite colle a un autre batiment ;
  4. la production tombe par PALIERS reguliers (un elixir toutes les N secondes, une portee
     d'unites toutes les N secondes), jamais en rafale a la premiere image longue ;
  5. le collecteur du vrai catalogue rend PLUS que ce qu'il coute, mais pas au point d'etre
     le seul coup jouable ;
  6. un batiment pose ne donne jamais de couronne ;
  7. le serveur de jeu applique reellement ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Batiments.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

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
    B = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    cartes = lua.execute(CARDS.read_text(encoding="utf-8"))

    carte = lua.eval("(function() return { cost = 4, batiment = { type = 'defense', duree = 40 } } end)")()
    cas("une carte a batiment est reconnue", True, B.est(carte))
    cas("une carte ordinaire ne l'est pas", False, B.est(lua.eval("(function() return { cost = 3 } end)")()))

    # 1 et 2 : usure et bornes
    cas("usure = PV etales sur la duree", 25.0, B.usure(carte, 1000))
    cas("a mi-vie il reste la moitie", 500.0, B.pvRestants(carte, 1000, 20))
    cas("au bout de sa vie il ne reste rien", 0.0, B.pvRestants(carte, 1000, 40))
    cas("expire au bout de sa duree", True, B.expire(carte, 40))
    folle = lua.eval("(function() return { cost = 1, batiment = { duree = 9999 } } end)")()
    cas("une duree farfelue est bornee", float(B.DUREE_MAX), B.duree(folle))

    # 3 : pose
    cas("camp 1 pose dans sa moitie", True, B.posePermise(1, 0, -20, None))
    cas("camp 1 ne pose pas chez l'adversaire", False, B.posePermise(1, 0, 20, None))
    cas("personne ne pose sur la riviere", False, B.posePermise(1, 0, -1, None))
    voisins = lua.eval("(function() return { { x = 0, z = -20 } } end)")()
    cas("pas deux batiments colles", False, B.posePermise(1, 1, -20, voisins))
    cas("assez loin, c'est permis", True, B.posePermise(1, 8, -20, voisins))

    # 4 : production par paliers
    coll = lua.eval("(function() return { cost = 6, batiment = { type = 'collecteur', duree = 60, "
                    "periode = 8, gain = 1 } } end)")()
    etat = lua.eval("(function() return { poseT = 0 } end)")()
    cas("rien avant la premiere periode", 0, B.produire(etat, coll, 7.9))
    cas("une periode echue = une production", 1, B.produire(etat, coll, 8.1))
    cas("pas de rattrapage silencieux dans la meme image", 0, B.produire(etat, coll, 8.2))
    cas("deux periodes sautees sont rattrapees", 2, B.produire(etat, coll, 24.5))

    # 5 : le collecteur du VRAI catalogue
    vraie = cartes["byId"]["PompaElixir"]
    rendu = B.rendement(vraie)
    net = B.gainNet(vraie)
    print("  Pompa Elixir : rend %.1f elixir pour %d, soit %+.1f net" % (rendu, vraie["cost"], net))
    cas("le collecteur rend plus qu'il ne coute", True, net > 0)
    cas("mais il ne double pas la mise", True, net < float(vraie["cost"]))

    # 6 : aucune couronne
    cas("un batiment pose ne donne pas de couronne", False, B.donneCouronne())

    # 7 : COMBIEN DE TEMPS IL RESTE. Defaut mesure le 2026-09-20 : un batiment pose tombe TOUT
    # SEUL et rien ne disait quand. Le joueur voyait une barre descendre sans savoir si c'est
    # parce qu'on le frappe ou parce que le temps passe : impossible de decider s'il faut le
    # defendre.
    tour = cartes["byId"]["TorreCannoli"]
    duree = float(B.duree(tour))
    pvMax = float(tour["hp"])
    cas("intact : il reste toute sa duree", duree, float(B.tempsRestant(tour, pvMax, pvMax)))
    cas("a moitie use : la moitie du temps", duree / 2, float(B.tempsRestant(tour, pvMax / 2, pvMax)))
    # LES DEGATS COMPTENT : un batiment a moitie detruit tombera deux fois plus tot. C'est le
    # coeur de l'information — sinon le chiffre mentirait des qu'on le frappe.
    cas("mort : plus rien", 0.0, float(B.tempsRestant(tour, 0, pvMax)))
    cas("jamais negatif", 0.0, float(B.tempsRestant(tour, -50, pvMax)))
    # Arrondi au SUPERIEUR : tant qu'il reste une fraction de seconde, le batiment est encore la.
    cas("le texte est en secondes entieres, arrondi au superieur", "1 s",
        B.texteRestant(tour, B.usure(tour, pvMax) * 0.2, pvMax))
    cas("et il porte son unite", True, B.texteRestant(tour, pvMax, pvMax).endswith(" s"))
    # Alerte : le temps de poser une carte pour prendre le relais.
    cas("presque fini quand il reste moins que le seuil", True,
        B.presqueFini(tour, B.usure(tour, pvMax) * (float(B.RESTE_ALERTE) - 1), pvMax))
    cas("pas d'alerte quand il est intact", False, B.presqueFini(tour, pvMax, pvMax))
    cas("le seuil laisse le temps de reagir", True, 3 <= float(B.RESTE_ALERTE) <= 10)

    # 7 : branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Batiments")' in serveur)
    cas("l'usure est appliquee", True, "Batiments.usure(" in serveur)
    cas("la pose est verifiee", True, "Batiments.posePermise(" in serveur)
    cas("la production tourne", True, "Batiments.produire(" in serveur)
    cas("le collecteur rend de l'elixir", True, 'b.type == "collecteur"' in serveur)
    cas("l'invocateur pond des unites", True, 'b.type == "invocateur"' in serveur)
    # Les deux supports d'affichage : le chiffre sur l'etiquette flottante (lisible en jeu) et
    # l'anneau au sol en vraie geometrie (le seul verifiable sur capture).
    cas("le chiffre est affiche sur le batiment", True,
        "Batiments.texteRestant(e.carte, e.hp, e.maxHp)" in serveur)
    cas("il passe en alerte quand la fin approche", True,
        "Batiments.presqueFini(e.carte, e.hp, e.maxHp)" in serveur)
    cas("un anneau au sol montre le meme compte a rebours", True,
        'bout.Name = "ReboursBatiment"' in serveur)
    cas("ses segments s'eteignent avec le temps", True,
        "bout.Transparency = i <= allumes and 0 or 0.9" in serveur)
    # La geometrie de l'anneau vient du module deja teste, elle n'est pas recalculee a la main.
    cas("l'anneau reutilise la geometrie deja verifiee", True,
        "Apercu.segmentsAnneau(rayon, 16)" in serveur)

    # RENTABILITE D'UN COLLECTEUR. Defaut mesure le 2026-09-21 : la fiche donnait la periode et la
    # duree de vie, et laissait le joueur faire la division en pleine partie. Or c'est CE chiffre
    # qui decide de poser une pompe : cassee avant, elle a coute de l'elixir au lieu d'en rendre.
    pompe, defense = None, None
    for c in cartes.list.values():
        b = c["batiment"]
        if b and b["type"] == "collecteur" and pompe is None:
            pompe = c
        if b and b["type"] == "defense" and defense is None:
            defense = c
    ordinaire = cartes.list[1]
    cas("le catalogue a bien un collecteur", True, pompe is not None)
    gain, periode, cout = float(pompe["batiment"]["gain"]), float(pompe["batiment"]["periode"]), float(pompe["cost"])
    import math as _m
    attendu = _m.ceil(cout / gain) * periode
    cas("remboursee au palier qui couvre le cout", attendu, float(B.secondesRentable(pompe)))
    # PALIERS et non regle de trois : l'elixir tombe d'un coup toutes les `periode` secondes,
    # donc un remboursement « a 5,5 paliers » n'existe pas.
    cas("le delai est un multiple de la periode", 0.0, float(B.secondesRentable(pompe)) % periode)
    cas("il tient dans la duree de vie de cette carte", True,
        float(B.secondesRentable(pompe)) <= float(B.duree(pompe)))
    # Un collecteur trop cher pour sa vie ne se rembourse JAMAIS : on ne montre pas un chiffre
    # que la carte ne peut pas atteindre.
    trop = lua.eval("(function(p) return { cost = 99, batiment = p.batiment } end)")(pompe)
    cas("un collecteur qui ne se rembourse jamais ne rend rien", None, B.secondesRentable(trop))
    cas("une carte sans batiment non plus", None, B.secondesRentable(ordinaire))
    cas("un batiment de defense non plus", None, B.secondesRentable(defense))

    ligne = B.texteRentabilite(pompe)
    cas("la ligne donne le delai", True, ("%d s" % int(attendu)) in ligne)
    cas("et le gain net, qui n'etait affiche nulle part", True, "elixir net" in ligne)
    cas("pas de ligne sans collecteur", None, B.texteRentabilite(ordinaire))
    # gainNet existait dans le code et n'etait appele par PERSONNE : il sert maintenant a la ligne.
    cas("le gain net est bien rendement moins cout",
        float(B.rendement(pompe)) - cout, float(B.gainNet(pompe)))

    # ET LES DEUX ECRANS L'AFFICHENT (sinon la regle serait mort-nee) ---------------------------
    for nom, chemin in (("le hub", ROOT / "src" / "client" / "Hub.client.lua"),
                        ("l'ecran de jeu", ROOT / "src" / "client" / "GameClient.client.lua")):
        txt = chemin.read_text(encoding="utf-8")
        cas("%s passe la rentabilite a la fiche" % nom, True,
            "rentabilite = Cards.byId[id] and Batiments.texteRentabilite(Cards.byId[id])" in txt)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les batiments s'usent, produisent et se posent comme annonce")
    return 0


sys.exit(main())
