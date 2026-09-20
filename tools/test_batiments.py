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

    # 7 : branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Batiments")' in serveur)
    cas("l'usure est appliquee", True, "Batiments.usure(" in serveur)
    cas("la pose est verifiee", True, "Batiments.posePermise(" in serveur)
    cas("la production tourne", True, "Batiments.produire(" in serveur)
    cas("le collecteur rend de l'elixir", True, 'b.type == "collecteur"' in serveur)
    cas("l'invocateur pond des unites", True, 'b.type == "invocateur"' in serveur)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les batiments s'usent, produisent et se posent comme annonce")
    return 0


sys.exit(main())
