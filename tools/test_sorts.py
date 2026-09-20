# -*- coding: utf-8 -*-
"""Banc des SORTS (src/shared/Sorts.lua + les cartes-sorts de Cards.lua), hors Studio.

Ce qu'il verifie :
  1. un sort vise TOUTE l'arene (et rien au-dela des bords) ;
  2. il touche ce qui est dans le rayon et rien d'autre, amis exclus pour les degats ;
  3. la rage ne renforce QUE ses propres unites, jamais les tours ni l'ennemi ;
  4. une tour encaisse moins qu'une unite (sinon deux sorts rasent une tour) ;
  5. la rage se termine NET, sans vitesse residuelle ;
  6. les sorts du vrai catalogue sont equilibres entre eux (degats par elixir) et ne surclassent
     pas les unites de zone ;
  7. le serveur et le client appliquent vraiment ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Sorts.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — le jeu n'a aucun sort" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    S = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    Cards = lua.execute(CARDS.read_text(encoding="utf-8"))

    # 1. zone de visee : toute l'arene
    cas("un sort vise chez l'ennemi", True, S.cibleValide(0, 25, 28, 32))
    cas("un sort vise chez soi", True, S.cibleValide(-10, -25, 28, 32))
    cas("un sort ne sort pas de l'arene (z)", False, S.cibleValide(0, 40, 28, 32))
    cas("un sort ne sort pas de l'arene (x)", False, S.cibleValide(30, 0, 28, 32))

    # 2 + 3. cibles
    objets = lua.eval("""{
      { camp = 1, x = 0, z = 0, batiment = false },   -- allie au centre
      { camp = 2, x = 1, z = 1, batiment = false },   -- ennemi tout pres
      { camp = 2, x = 20, z = 20, batiment = false }, -- ennemi loin
      { camp = 2, x = 0, z = 2, batiment = true },    -- tour ennemie proche
      { camp = 1, x = 2, z = 0, batiment = true },    -- tour alliee proche
    }""")
    touches = list(S.cibles(objets, 1, 0, 0, 4, "degats").values())
    cas("degats : touche l'ennemi proche et sa tour", [2, 4], sorted(touches))
    cas("degats : n'atteint pas l'ennemi hors rayon", False, 3 in touches)
    cas("degats : epargne ses propres unites", False, 1 in touches)
    ragees = sorted(S.cibles(objets, 1, 0, 0, 4, "rage").values())
    cas("rage : seulement ses propres UNITES", [1], ragees)

    # 4. degats : tour vs unite
    sort = lua.eval("{ effet = 'degats', degats = 340, degatsTour = 0.35 }")
    cas("une unite prend les degats pleins", 340, S.degats(sort, False))
    cas("une tour encaisse moins", 119, S.degats(sort, True))

    # 5. rage
    rage = lua.eval("{ effet = 'rage', gain = 0.35, duree = 7 }")
    cas("pendant la rage : plus vif", 1.35, round(float(S.multiplicateurRage(rage, 3)), 3))
    cas("a l'instant du lancer", 1.35, round(float(S.multiplicateurRage(rage, 0)), 3))
    cas("apres la rage : vitesse normale", 1, S.multiplicateurRage(rage, 7))
    cas("bien apres : vitesse normale", 1, S.multiplicateurRage(rage, 99))
    cas("sans rage du tout", 1, S.multiplicateurRage(rage, None))

    # 6. equilibrage entre sorts, sur le VRAI catalogue
    sorts, zones = [], []
    for i in range(1, len(Cards.list) + 1):
        c = Cards.list[i]
        if c.sort is not None:
            sorts.append((c.name, int(c.cost), c.sort.effet, float(c.sort.rayon),
                          float(S.degatsParElixir(c))))
        elif c.splash is not None:
            zones.append((c.name, float(c.dmg)))
    for nom, cout, effet, rayon, dpe in sorts:
        print("  sort %-22s %d elixir  effet=%-7s rayon=%.1f  degats/elixir=%.0f" % (nom, cout, effet, rayon, dpe))
    cas("au moins trois sorts", True, len(sorts) >= 3)
    degats = [d for _, _, e, _, d in sorts if e == "degats"]
    if len(degats) >= 2:
        cas("aucun sort de degats n'ecrase les autres", True, max(degats) / max(min(degats), 1) <= 2.0)
    # un sort doit couvrir plus large qu'une unite de zone, sinon il n'a aucune raison d'exister
    rayons = [r for _, _, e, r, _ in sorts if e == "degats"]
    cas("un sort couvre plus large qu'une attaque de zone", True, max(rayons) > 4)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    cas("le serveur lance les sorts", True, "Sorts.cibles(" in serveur)
    cas("le serveur applique les degats de sort", True, "Sorts.degats(" in serveur)
    cas("le serveur applique la rage", True, "Sorts.multiplicateurRage(" in serveur)
    cas("le serveur verifie la zone visee", True, "Sorts.cibleValide(" in serveur)
    cas("le client laisse viser toute l'arene", True, "card.sort" in client)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les sorts frappent la bonne zone, epargnent les allies et s'arretent net")
    return 0


if __name__ == "__main__":
    sys.exit(main())
