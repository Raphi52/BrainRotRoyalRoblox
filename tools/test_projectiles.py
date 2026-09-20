# -*- coding: utf-8 -*-
"""Banc des PROJECTILES (src/shared/Projectiles.lua), hors Studio.

Defaut corrige : les degats d'un tireur etaient appliques a l'instant meme de l'attaque, et la
boule dessinee n'etait qu'un decor pose apres coup. L'archer frappait donc plus vite que sa propre
fleche a l'ecran — ce que l'oeil lit comme de la triche — et aucune unite ne pouvait esquiver.

Ce qu'il verifie :
  1. le temps de vol suit la distance et la vitesse de la carte, et reste borne ;
  2. la trajectoire part du tireur et arrive sur le point vise, en CLOCHE pour les tirs de zone ;
  3. un tir de ZONE touche tout ce qui est dans le rayon du point vise, meme si la cible d'origine
     est morte en vol ;
  4. un tir SIMPLE se perd si la cible est morte, ou si elle s'est trop deplacee : c'est l'esquive ;
  5. le serveur de jeu applique reellement ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Projectiles.lua"
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
    P = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    rapide = lua.eval("(function() return { vitesseTir = 60 } end)")()
    lente = lua.eval("(function() return { vitesseTir = 1 } end)")()
    sans = lua.eval("(function() return {} end)")()

    # 1. duree de vol
    cas("vitesse par defaut quand la carte n'en donne pas", float(P.VITESSE_DEFAUT), P.vitesse(sans))
    cas("une vitesse derisoire est relevee a la borne", float(P.VITESSE_MIN), P.vitesse(lente))
    cas("30 studs a 60 studs/s = une demi-seconde", 0.5, round(P.duree(rapide, 30), 4))
    cas("le contact arrive tout de suite", 0.0, P.duree(rapide, 0))
    cas("aucun tir ne vit plus que la borne", float(P.DUREE_MAX), P.duree(lente, 100000))

    # 2. trajectoire
    depart = lua.eval("(function() return { x = 0, y = 2, z = 0 } end)")()
    arrivee = lua.eval("(function() return { x = 10, y = 2, z = 0 } end)")()
    x, y, z = P.position(depart, arrivee, 0.5, 1.0, None)
    cas("a mi-vol, le tir est a mi-chemin", (5.0, 2.0, 0.0), (x, y, z))
    x, y, z = P.position(depart, arrivee, 0.5, 1.0, 1)
    cas("un tir de zone monte en cloche", True, y > 2.0)
    x, y, z = P.position(depart, arrivee, 9.0, 1.0, 1)
    cas("apres l'arrivee, il ne depasse pas la cible", (10.0, 2.0, 0.0), (x, y, z))
    cas("arrive", True, P.arrive(1.0, 1.0))
    cas("pas encore arrive", False, P.arrive(0.9, 1.0))

    # 3. tir de zone
    objets = lua.eval(
        "(function() return { { camp = 2, x = 0, z = 0, vivant = true }, "
        "{ camp = 2, x = 2, z = 0, vivant = true }, "
        "{ camp = 2, x = 20, z = 0, vivant = true }, "
        "{ camp = 1, x = 1, z = 0, vivant = true } } end)")()
    visee = lua.eval("(function() return { x = 0, z = 0 } end)")()
    touches = P.touches(objets, 1, visee, 3, 1)
    cas("la zone touche les ennemis du rayon, pas les allies", [1, 2], list(touches.values()))
    morts = lua.eval(
        "(function() return { { camp = 2, x = 0, z = 0, vivant = false }, "
        "{ camp = 2, x = 2, z = 0, vivant = true } } end)")()
    touches = P.touches(morts, 1, visee, 3, 1)
    cas("cible morte en vol : la zone frappe quand meme le sol", [2], list(touches.values()))

    # 4. tir simple et esquive
    touches = P.touches(objets, 1, visee, 0, 1)
    cas("tir simple : la cible restee sur place est touchee", [1], list(touches.values()))
    touches = P.touches(morts, 1, visee, 0, 1)
    cas("cible morte en vol : le tir simple se perd", [], list(touches.values()))
    loin = lua.eval("(function() return { { camp = 2, x = 30, z = 0, vivant = true } } end)")()
    touches = P.touches(loin, 1, visee, 0, 1)
    cas("cible qui a fui : le tir simple la rate (esquive)", [], list(touches.values()))

    # 5. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Projectiles")' in serveur)
    cas("le temps de vol est calcule", True, "Projectiles.duree(" in serveur)
    cas("l'arrivee declenche les degats", True, "Projectiles.arrive(" in serveur)
    cas("l'esquive est appliquee", True, "Projectiles.MARGE_ESQUIVE" in serveur)
    attaque = serveur.split("local function attack(e, target)")[1].split("local function majTirs()")[0]
    cas("un tireur n'inflige plus ses degats a l'instant du tir", False, "damage(target" in attaque)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les tirs volent, arrivent, et peuvent se perdre")
    return 0


sys.exit(main())
