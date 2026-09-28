# -*- coding: utf-8 -*-
"""Banc hors Studio : la boutique n'affiche QUE les produits Robux reellement configures.

Pourquoi ce banc existe : les identifiants de Economie.PRODUITS valent 0 tant que le createur
n'a pas cree les produits sur create.roblox.com. Deux regressions possibles, invisibles sans
Roblox : (a) une offre a l'identifiant 0 remonte au client et ouvre un achat qui echoue chez le
joueur ; (b) une fois les vrais identifiants poses, les offres ne remontent PAS et la boutique
reste vide sans message. Ce banc fige les deux bords, sans Studio et sans achat reel.

Prerequis : python -m pip install lupa
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harnais_economie import charger, joueur, nouveau_lua  # noqa: E402

GENRES = []  # genre de chaque offre remontee (pastille dessinee par le client)


def offres(Economie, lua, ids):
    """Pose `ids` dans Economie.PRODUITS puis rend la liste des noms remontes au client."""
    for i, identifiant in enumerate(ids, start=1):
        Economie.PRODUITS[i].id = identifiant
    p = joueur(lua, "Alice", 1)
    Economie.charger(p)
    vue = Economie.vue(p)
    GENRES.extend(vue.offresRobux[i].genre for i in range(1, len(vue.offresRobux) + 1))
    return [vue.offresRobux[i].nom for i in range(1, len(vue.offresRobux) + 1)]


def main():
    lua = nouveau_lua()
    Economie = charger(lua)
    # Ce banc porte sur les PRODUITS. Le pass VIP, configure depuis le 2026-09-26, ajoute sa
    # propre offre : il a son banc (tools/test_pass_achete.py), on l'eteint ici.
    Economie.PASS_VIP = 0

    vides = offres(Economie, lua, [0, 0, 0])
    print("identifiants a 0 -> offres :", vides)
    if vides:
        print("ROUGE : une offre non configuree (id 0) remonte au client.")
        return 1

    attendus = ["Sac de 500 pieces", "Coffre de 1500 pieces", "Poignee de 80 gemmes"]
    del GENRES[:]
    posees = offres(Economie, lua, [111111111, 222222222, 333333333])
    if GENRES != ["pieces", "pieces", "gemmes"]:
        print("ROUGE : genre des offres (pastille) :", GENRES, "attendu ['pieces', 'pieces', 'gemmes']")
        return 1
    print("identifiants poses -> offres :", posees)
    if posees != attendus:
        print("ROUGE : les produits configures ne remontent pas a la boutique.")
        print("        attendu :", attendus)
        return 1

    partiel = offres(Economie, lua, [111111111, 0, 333333333])
    print("un seul manquant -> offres :", partiel)
    if partiel != ["Sac de 500 pieces", "Poignee de 80 gemmes"]:
        print("ROUGE : le filtrage ne porte pas sur chaque produit independamment.")
        return 1

    print("VERT : la boutique n'affiche que les produits Robux configures.")
    return 0


sys.exit(main())
