# -*- coding: utf-8 -*-
"""Banc de la TRAVERSEE (src/shared/Traversee.lua) : franchir la riviere sans se figer.

Defaut MESURE en moteur (serie de 6 parties normales, journal du 2026-09-20) : quatre unites
restent BLOQUEES, et toutes au MEME endroit — z = -4, aux abords du pont droit (x = 15 et 18,
pont a 17). L'ancien code visait le point d'entree du pont SUR LA PROPRE RIVE de l'unite quand
elle etait mal alignee : son but n'avait alors AUCUNE composante vers l'autre berge, donc elle ne
progressait pas. Seule, elle s'alignait en une seconde ; mais la FOULE la pousse lateralement en
permanence, et la condition « mal alignee » restait vraie indefiniment.

Premiere hypothese, ECARTEE par ce banc meme : je croyais a un « point fixe » (but egal a la
position courante). Le balayage de 14 577 positions n'en a trouve aucun, ni avec l'ancienne regle
ni avec la nouvelle. Le vrai mecanisme est le verrouillage lateral ci-dessus, et il ne se voit
qu'en rejouant la marche AVEC la poussee de la foule.

Ce qu'il verifie :
  1. on choisit bien le pont le PLUS PROCHE, decale du couloir de l'unite ;
  2. loin de l'eau, on se dirige vers l'entree du pont de son cote ;
  3. une fois a l'entree, on vise l'AUTRE rive — il reste donc toujours du chemin a faire ;
  4. aucune position de l'arene ne rend le but egal a la position courante ;
  5 + 6. les DEUX regles rejouees pas a pas sous la poussee de la foule : l'ancienne bloque des
     2 studs/s, la nouvelle franchit jusqu'a 6 studs/s ;
  7. les unites de groupe ne visent pas toutes exactement le meme point ;
  8. le serveur applique la regle et l'ancien calcul a disparu.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Traversee.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — des unites se figent a l'entree du pont" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    T = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    PONTS = lua.table_from([-17.0, 17.0])
    entree = float(T.ENTREE)
    print("  entree de pont a +/- %.0f studs de la riviere" % entree)

    # 1. choix du pont
    cas("a droite : on prend le pont droit", 17.0, float(T.pont(12.0, PONTS, 0)))
    cas("a gauche : on prend le pont gauche", -17.0, float(T.pont(-12.0, PONTS, 0)))
    cas("au centre, on prend le plus proche", -17.0, float(T.pont(-0.1, PONTS, 0)))
    cas("un couloir decale le point", 17.0 + 0.25, float(T.pont(12.0, PONTS, 1)))
    cas("mais le decalage est borne", 17.0 + float(T.COULOIR_MAX),
        float(T.pont(12.0, PONTS, 99)))
    cas("sans pont connu : rien", None, T.pont(0, lua.table_from([]), 0))

    # 2 + 3. le point vise
    gx, gz = T.point(10.0, -20.0, PONTS, 0)
    cas("loin de l'eau : on vise l'entree de SON cote", (17.0, -entree),
        (float(gx), float(gz)))
    gx, gz = T.point(10.0, 20.0, PONTS, 0)
    cas("depuis l'autre rive, symetrique", (17.0, entree), (float(gx), float(gz)))
    gx, gz = T.point(15.0, -entree, PONTS, 0)
    cas("arrive a l'entree : on vise l'AUTRE rive", (17.0, entree), (float(gx), float(gz)))
    gx, gz = T.point(18.0, -1.0, PONTS, 0)
    cas("sur le pont : on continue vers l'autre rive", (17.0, entree), (float(gx), float(gz)))

    # 4. INVARIANT CENTRAL : jamais de point fixe
    positions = []
    for x in [v * 0.5 for v in range(-56, 57)]:
        for z in [v * 0.5 for v in range(-64, 65)]:
            positions.append((x, z))
    fixes = []
    for (x, z) in positions:
        gx, gz = T.point(x, z, PONTS, 0)
        if T.immobile(x, z, gx, gz, 0.01):
            fixes.append((x, z))
    print("  %d positions testees sur toute l'arene, %d point(s) fixe(s)" % (len(positions), len(fixes)))
    cas("aucune position ne fige l'unite", [], fixes[:5])
    # et avec un couloir de groupe non nul non plus
    fixes2 = [(x, z) for (x, z) in positions
              if T.immobile(x, z, *[float(v) for v in T.point(x, z, PONTS, 2)], 0.01)]
    cas("aucune non plus pour une unite de groupe", [], fixes2[:5])

    # 5 + 6. REPRODUCTION du defaut, puis preuve de la correction, en rejouant les DEUX regles
    # pas a pas avec la poussee laterale de la foule. On reproduit aussi la condition du serveur :
    # le calcul de pont ne s'applique que tant que l'unite et sa cible sont de part et d'autre.
    def cote(zz):
        return 1 if zz >= 0 else -1

    def ancienne(xx, zz):
        """Ancien calcul : entree du pont sur SA PROPRE rive si mal aligne."""
        bx = -17.0 if abs(xx + 17.0) < abs(xx - 17.0) else 17.0
        s = cote(zz)
        if abs(xx - bx) > 0.8:
            return bx, s * 4
        return bx, -s * 4

    def nouvelle(xx, zz):
        gx_, gz_ = T.point(xx, zz, PONTS, 0)
        return float(gx_), float(gz_)

    def marche(regle, xx, zz, poussee, cible=(0.0, 20.0), vitesse=8.0, dt=1 / 30.0, duree=25.0):
        """Rend le temps de franchissement, ou None si l'unite n'y arrive pas."""
        t, zmax = 0.0, zz
        while t < duree:
            t += dt
            gx_, gz_ = regle(xx, zz) if cote(zz) != cote(cible[1]) else cible
            dx, dz = gx_ - xx, gz_ - zz
            n = math.hypot(dx, dz)
            if n < 1e-6:
                return None
            pas = min(n, vitesse * dt)
            xx += dx / n * pas + poussee * dt     # la foule pousse de cote
            zz += dz / n * pas
            zmax = max(zmax, zz)
            if zz > 6:
                return round(t, 1)
        return None

    print("  franchissement depuis (15, -20), cible sur l'autre rive :")
    for nom, poussee in (("sans poussee", 0.0), ("poussee 2 studs/s", 2.0),
                         ("poussee 4 studs/s", 4.0), ("poussee 6 studs/s", 6.0)):
        av, ap = marche(ancienne, 15.0, -20.0, poussee), marche(nouvelle, 15.0, -20.0, poussee)
        print("    %-18s ancienne : %-14s nouvelle : %s"
              % (nom, ("%s s" % av) if av else "BLOQUEE", ("%s s" % ap) if ap else "BLOQUEE"))
        cas("avec %s, la nouvelle regle franchit" % nom, True, ap is not None)

    cas("sans poussee, l'ancienne marchait deja", True,
        marche(ancienne, 15.0, -20.0, 0.0) is not None)
    cas("mais poussee de cote, elle BLOQUAIT", None, marche(ancienne, 15.0, -20.0, 2.0))
    cas("et plus la poussee est forte, plus c'est net", None,
        marche(ancienne, 15.0, -20.0, 4.0))
    cas("depuis le point de blocage mesure (18, -4) : l'ancienne bloque", None,
        marche(ancienne, 18.0, -4.0, 2.0))
    cas("la nouvelle, elle, franchit", True, marche(nouvelle, 18.0, -4.0, 2.0) is not None)
    cas("et de l'autre rive aussi", True,
        marche(nouvelle, -15.0, 20.0, 2.0, cible=(0.0, -20.0)) is not None)

    # 7. couloirs distincts pour un groupe
    points = {(round(float(T.point(12.0, -20.0, PONTS, k)[0]), 3)) for k in (-1, 0, 1)}
    cas("trois unites de groupe visent trois couloirs", 3, len(points))

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Traversee")' in serveur)
    cas("le serveur l'utilise pour franchir", True,
        "Traversee.point(pos.X, pos.Z, BRIDGES, lane)" in serveur)
    code = chr(10).join(l.split("--")[0] for l in serveur.splitlines())
    cas("l'ancien calcul a disparu", False, "sideOf(pos.Z) * 4" in code)
    cas("le module est livre dans la place", True, "shared/Traversee.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : aucune position ne fige une unite, et elle franchit meme poussee de cote")
    return 0


if __name__ == "__main__":
    sys.exit(main())
