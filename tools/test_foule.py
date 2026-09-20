# -*- coding: utf-8 -*-
"""Banc de la FOULE (src/shared/Foule.lua) : les unites s'encombrent au lieu de se traverser.

Pourquoi : deux unites pouvaient occuper EXACTEMENT le meme point. Un groupe de trois se fondait
en une seule silhouette, et « faire barrage » — la defense de base du genre — ne voulait rien dire
puisque rien ne bloquait rien.

Ce qu'il verifie :
  1. deux unites superposees se separent, et dans des sens OPPOSES (jamais le meme) ;
  2. deux unites eloignees ne subissent aucune poussee (pas de tremblement permanent) ;
  3. la poussee grandit avec le chevauchement, et reste BORNEE (aucune teleportation) ;
  4. un volant ne gene pas un terrestre, mais gene un autre volant ;
  5. une tour encombre les unites, ne bouge jamais, et laisse passer les volants ;
  6. le freinage ralentit sans jamais immobiliser completement ;
  7. dix unites empilees ne font pas exploser le calcul ;
  8. le serveur de jeu l'applique VRAIMENT dans sa boucle.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Foule.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les unites se traversent toujours" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    F = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    def u(id, x, z, rayon=1.5, flying=False, batiment=False):
        return lua.table_from(dict(id=id, x=x, z=z, rayon=rayon, flying=flying, batiment=batiment))

    def liste(*unites):
        return lua.table_from(list(unites))

    dt = 0.1

    # 1. superposees : elles se separent, en sens opposes
    a, b = u(1, 0, 0), u(2, 0, 0)
    ax, az = F.poussee(a, liste(a, b), dt)
    bx, bz = F.poussee(b, liste(a, b), dt)
    cas("une unite superposee est poussee", True, abs(float(ax)) + abs(float(az)) > 0)
    cas("l'autre aussi", True, abs(float(bx)) + abs(float(bz)) > 0)
    cas("elles partent en sens OPPOSES", True, float(ax) * float(bx) < 0 or float(az) * float(bz) < 0)

    # 2. eloignees : rien
    loin = u(3, 40, 40)
    lx, lz = F.poussee(a, liste(a, loin), dt)
    cas("deux unites eloignees ne bougent pas", (0, 0), (float(lx), float(lz)))
    # juste au contact, sans chevauchement reel : rien non plus (pas de tremblement)
    contact = u(4, 3.0, 0)
    cx, cz = F.poussee(a, liste(a, contact), dt)
    cas("au contact exact, aucune poussee", (0, 0), (float(cx), float(cz)))

    # 3. la poussee grandit avec le chevauchement, et reste bornee
    def norme(m, voisins):
        x, z = F.poussee(m, voisins, dt)
        return math.hypot(float(x), float(z))
    faible = norme(u(1, 2.5, 0), liste(u(1, 2.5, 0), u(2, 0, 0)))
    fort = norme(u(1, 0.5, 0), liste(u(1, 0.5, 0), u(2, 0, 0)))
    cas("plus ca chevauche, plus ca pousse", True, fort > faible > 0)
    plafond = float(F.POUSSEE_MAX) * dt
    total = norme(u(1, 0, 0), liste(u(1, 0, 0), u(2, 0, 0)))
    cas("la poussee ne depasse jamais le plafond", True, total <= plafond + 1e-9)
    cas("meme avec un chevauchement enorme", True,
        norme(u(1, 0, 0), liste(u(1, 0, 0), u(2, 0, 0, rayon=30))) <= plafond + 1e-9)

    # 4. volants
    sol, vol = u(1, 0, 0), u(2, 0.5, 0, flying=True)
    cas("un volant ne gene pas un terrestre", False, F.seGenent(sol, vol))
    cas("ni l'inverse", False, F.seGenent(vol, sol))
    cas("deux volants se genent", True, F.seGenent(vol, u(3, 0, 0, flying=True)))
    cas("deux terrestres se genent", True, F.seGenent(sol, u(4, 0, 0)))
    vx, vz = F.poussee(sol, liste(sol, vol), dt)
    cas("aucune poussee entre sol et air", (0, 0), (float(vx), float(vz)))

    # 5. tours
    tour = u(9, 0, 0, rayon=3, batiment=True)
    unite = u(1, 1, 0)
    cas("une tour encombre une unite au sol", True, F.seGenent(unite, tour))
    cas("une tour laisse passer un volant", False, F.seGenent(u(2, 1, 0, flying=True), tour))
    cas("deux tours ne se poussent pas", False, F.seGenent(tour, u(8, 0, 0, rayon=3, batiment=True)))
    tx, tz = F.poussee(tour, liste(tour, unite), dt)
    cas("une tour ne bouge JAMAIS", (0, 0), (float(tx), float(tz)))
    ux, uz = F.poussee(unite, liste(unite, tour), dt)
    cas("c'est l'unite qui est repoussee", True, float(ux) > 0)

    # 6. freinage
    cas("sans chevauchement : pleine vitesse", 1, F.freinage(0, 1.5))
    lent = float(F.freinage(1.5, 1.5))
    cas("bloque de partout : on ralentit", True, 0.3 < lent < 0.45)
    cas("mais jamais l'arret complet", True, lent > 0)
    doux = float(F.freinage(0.3, 1.5))
    cas("un petit contact freine a peine", True, lent < doux < 1)
    cas("le freinage ne remonte jamais au-dessus de 1", 1, F.freinage(-5, 1.5))

    # 7. dix unites empilees : pas d'explosion
    pile = [u(i, 0, 0) for i in range(1, 11)]
    px, pz = F.poussee(pile[0], liste(*pile), dt)
    n = math.hypot(float(px), float(pz))
    cas("dix unites empilees : poussee finie", True, n == n and n <= plafond + 1e-9)  # n == n : pas NaN
    cas("et non nulle", True, n > 0)
    chev = float(F.chevauchement(pile[0], liste(*pile)))
    cas("le chevauchement total est compte", True, chev > 0)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur calcule la poussee", True, "Foule.poussee(" in serveur)
    cas("le serveur freine les unites gênées", True, "Foule.freinage(" in serveur)
    cas("le serveur connait l'encombrement des cartes", True, "Foule.rayon(" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les unites se genent, se separent sans trembler, et aucune tour ne recule")
    return 0


if __name__ == "__main__":
    sys.exit(main())
