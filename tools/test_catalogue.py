# -*- coding: utf-8 -*-
"""Banc de test du CATALOGUE REEL (src/shared/Cards.lua) face aux 8 places du deck.

Pourquoi ce banc existe : les autres bancs utilisent un catalogue FICTIF, donc aucun
n'a pu voir le defaut constate a l'ecran le 2026-09-16 — 8 cartes au catalogue pour
8 places de deck : l'ecran DECK affichait « PAS ASSEZ DE CARTES » et ne pouvait rien
decider, meme apres avoir tout achete. Ce banc lit le VRAI Cards.lua et le VRAI
Economie.DECK_TAILLE, et exige qu'un choix reste possible.

Ce qu'il verifie :
  1. un joueur NEUF (cartes offertes seulement) peut deja composer un deck complet ;
  2. il lui reste une marge de choix (au moins 2 cartes offertes de plus que de places) ;
  3. acheter une carte payante elargit encore le choix ;
  4. aucun identifiant en double, et chaque carte porte les champs dont le jeu depend.

Prerequis : python -m pip install lupa
"""
import math
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "src" / "shared" / "Cards.lua"
ECONOMIE = ROOT / "src" / "server" / "Economie.lua"

# Marge minimale : avec exactement autant de cartes que de places, il n'existe qu'UN
# seul deck possible — l'ecran de composition n'aurait alors rien a decider.
MARGE_MINIMALE = 2
CHAMPS = ("id", "name", "cost", "hp", "dmg", "range", "speed", "atkSpeed", "count", "desc")

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ECHEC ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    cartes = list(lua.execute(CARDS.read_text(encoding="utf-8"))["list"].values())

    # DECK_TAILLE est lu dans le code reel, pas recopie ici.
    taille = int(re.search(r"Economie\.DECK_TAILLE\s*=\s*(\d+)", ECONOMIE.read_text(encoding="utf-8")).group(1))
    print("catalogue : %d cartes | places de deck : %d" % (len(cartes), taille))

    offertes = [c["id"] for c in cartes if c["prix"] is None]
    payantes = [c["id"] for c in cartes if c["prix"] is not None]
    print("offertes (%d) : %s" % (len(offertes), ", ".join(sorted(offertes))))
    print("payantes (%d) : %s" % (len(payantes), ", ".join(sorted(payantes))))

    cas("un joueur neuf peut composer un deck complet", True, len(offertes) >= taille)
    cas("il lui reste une marge de choix", True, len(offertes) >= taille + MARGE_MINIMALE)

    combinaisons = math.comb(len(offertes), taille) if len(offertes) >= taille else 0
    print("  decks possibles sans rien acheter : %d" % combinaisons)
    cas("plusieurs decks possibles sans rien acheter", True, combinaisons > 1)

    apres_achat = math.comb(len(offertes) + len(payantes), taille)
    cas("acheter une carte elargit le choix", True, apres_achat > combinaisons)

    ids = [c["id"] for c in cartes]
    cas("aucun identifiant en double", len(ids), len(set(ids)))

    manquants = sorted({"%s.%s" % (c["id"], ch) for c in cartes for ch in CHAMPS if c[ch] is None})
    cas("chaque carte porte ses champs de jeu", [], manquants)

    sans_silhouette = sorted(c["id"] for c in cartes if c["morceaux"] is None or len(list(c["morceaux"].values())) == 0)
    cas("chaque carte a une silhouette", [], sans_silhouette)

    if ECHECS:
        print("ROUGE : " + str(len(ECHECS)) + " cas en echec")
        return 1
    print("VERT : le catalogue laisse un vrai choix de deck, avant comme apres achat")
    return 0


sys.exit(main())
