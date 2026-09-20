# -*- coding: utf-8 -*-
"""Banc des STATUTS (src/shared/Statuts.lua), hors Studio.

Ce qu'il verifie :
  1. le gel arrete TOUT (marche et coups), et se termine net ;
  2. le ralentissement divise la vitesse, se cumule en PROLONGEANT (jamais en s'empilant),
     et ne descend jamais sous la borne du module ;
  3. le poison tombe par TICS reguliers, jamais image par image ;
  4. le bouclier encaisse AVANT les points de vie, et signale l'instant ou il casse ;
  5. un soin ne depasse jamais les PV maximaux et ne ressuscite pas ;
  6. l'unite est intouchable pendant la fraction de seconde de sa pose ;
  7. l'explosion a la mort ne touche que les ENNEMIS dans son rayon ;
  8. le serveur de jeu applique reellement ces regles (sinon le module serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Statuts.lua"
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
    S = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    porteur = lua.eval("(function() return { statuts = {}, hp = 100, maxHp = 400, alive = true } end)")

    # 1. GEL
    u = porteur()
    S.appliquer(u, "gel", lua.table(duree=2), 10.0)
    cas("gele : ne peut plus agir", False, S.peutAgir(u, 10.5))
    cas("gele : vitesse nulle", 0, S.facteurVitesse(u, 10.5, 1))
    cas("gel fini : il agit de nouveau", True, S.peutAgir(u, 12.1))
    cas("gel fini : vitesse pleine, sans residu", 1, S.facteurVitesse(u, 12.1, 1))
    S.appliquer(u, "gel", lua.table(duree=99), 20.0)
    cas("un gel ne depasse jamais la borne du module", True,
        S.peutAgir(u, 20.0 + float(S.GEL_MAX) + 0.01))

    # 2. RALENTISSEMENT
    u = porteur()
    S.appliquer(u, "lent", lua.table(duree=3, part=0.5), 0.0)
    cas("ralenti de moitie", 0.5, round(S.facteurVitesse(u, 1.0, 1), 3))
    S.appliquer(u, "lent", lua.table(duree=1, part=0.2), 1.0)
    cas("re-appliquer PROLONGE et garde le plus fort", 0.5, round(S.facteurVitesse(u, 2.0, 1), 3))
    cas("ralentissement fini : plus aucun residu", 1, S.facteurVitesse(u, 3.1, 1))
    u = porteur()
    S.appliquer(u, "lent", lua.table(duree=3, part=0.99), 0.0)
    cas("une carte ne peut pas immobiliser par le froid", True,
        S.facteurVitesse(u, 1.0, 1) >= 1 - float(S.LENT_PART_MAX))
    u = porteur()
    S.appliquer(u, "gel", lua.table(duree=2), 0.0)
    S.appliquer(u, "lent", lua.table(duree=5, part=0.5), 0.0)
    cas("le gel prime sur le ralentissement", 0, S.facteurVitesse(u, 1.0, 1))

    # 3. POISON par tics
    u = porteur()
    S.appliquer(u, "poison", lua.table(duree=4, degats=20, tic=0.5), 0.0)
    cas("rien avant le premier tic", 0, S.tic(u, "poison", 0.4))
    cas("un tic echu = un palier de degats", 20, S.tic(u, "poison", 0.6))
    cas("deux tics rattrapes d'un coup", 40, S.tic(u, "poison", 1.7))
    cas("poison expire : plus rien", 0, S.tic(u, "poison", 9.0))

    # 4. BOUCLIER
    u = porteur()
    S.poserBouclier(u, 300)
    sur_pv, reste, casse = S.encaisser(u, 100)
    cas("le bouclier encaisse d'abord", (0, 200, False), (sur_pv, reste, casse))
    sur_pv, reste, casse = S.encaisser(u, 250)
    cas("ce qui depasse passe aux points de vie", (50, 0, True), (sur_pv, reste, casse))
    sur_pv, reste, casse = S.encaisser(u, 40)
    cas("bouclier casse : tout passe", (40, 0, False), (sur_pv, reste, casse))

    # 5. SOIN
    u = porteur()
    u.hp = 100
    cas("un soin remet des PV", 150, S.soigner(u, 150) + 0)
    cas("il ne depasse pas le maximum", 150, S.soigner(u, 999))
    u.alive = False
    cas("un soin ne ressuscite pas", 0, S.soigner(u, 100))

    # 6. GRACE A LA POSE
    u = porteur()
    u.poseT = 5.0
    cas("intouchable a l'instant de la pose", True, S.invulnerable(u, 5.0))
    cas("touchable des la grace ecoulee", False, S.invulnerable(u, 5.0 + float(S.INVULN_POSE) + 0.01))

    # 7. EXPLOSION A LA MORT
    carte = lua.eval("(function() return { mort = { degats = 200, rayon = 4 } } end)")()
    objets = lua.eval(
        "(function() return { { camp = 2, x = 0, z = 0 }, { camp = 2, x = 10, z = 0 }, "
        "{ camp = 1, x = 1, z = 1 } } end)")()
    touches, degats = S.explosionMort(carte, objets, 1, 0, 0)
    cas("l'explosion ne touche que l'ennemi a portee", [1], list(touches.values()))
    cas("elle rend les degats de la carte", 200, degats)
    sans = lua.eval("(function() return {} end)")()
    touches, degats = S.explosionMort(sans, objets, 1, 0, 0)
    cas("une carte sans explosion n'explose pas", ([], 0), (list(touches.values()), degats))

    # 8. le serveur applique
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Statuts")' in serveur)
    cas("le bouclier est lu dans la fonction de degats", True,
        "Statuts.encaisser(" in serveur.split("local function damage(")[1].split("local function attack(")[0])
    cas("une unite gelee ne frappe pas", True, "Statuts.peutAgir(" in serveur)
    cas("le froid freine la marche", True, "Statuts.facteurVitesse(" in serveur)
    cas("le poison ronge image par image", True, 'Statuts.tic(e, "poison"' in serveur)
    cas("les soigneurs soignent", True, "Statuts.soigner(" in serveur)
    cas("la grace de pose protege", True, "Statuts.invulnerable(" in serveur)
    cas("l'explosion a la mort est appliquee", True, "Statuts.explosionMort(" in serveur)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : gel, froid, poison, bouclier, soin et explosion se comportent comme annonce")
    return 0


sys.exit(main())
