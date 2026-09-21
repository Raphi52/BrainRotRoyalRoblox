# -*- coding: utf-8 -*-
"""BORDURE DE RARETE dans l'onglet CARTES (collection ET rangee « TON DECK »).

Constat du 2026-09-21 (photo prise par le jeu, --onglet=cartes --deck-legendaire) : aucune carte de
l'onglet ne montrait sa rarete. Dans la collection, la tuile portait DEUX UIStroke (rarete + selection
invisible) : l'ordre de rendu de deux UIStroke sur le meme parent n'est pas defini
(https://create.roblox.com/docs/ui/appearance-modifiers), la selection transparente masquait la rarete.
La rangee du deck n'avait qu'un contour sombre fixe.
"""
import sys, pathlib, re

R = pathlib.Path(__file__).resolve().parent.parent
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []

# collection : la boucle des tuiles de l'editeur de deck
debut = H.index("for _, card in ipairs(Cards.list) do\n\tlocal tuile = Instance.new(\"TextButton\")")
bloc = H[debut:H.index("tuilesDeck[card.id] =", debut)]
if bloc.count('Instance.new("UIStroke")') > 1:
    e.append("collection : deux UIStroke sur la meme tuile, la rarete peut etre masquee")
if "ApplyStrokeMode.Border" not in bloc:
    e.append("collection : sur un TextButton, le contour entoure le TEXTE (vide) sans mode Border")
if "t.bord.Transparency = choix[card.id] and 0 or 1" in H:
    e.append("collection : la selection passe encore par un second contour transparent")
if "rarete" not in H[H.index("t.bord", debut):H.index("t.bord", debut) + 400]:
    e.append("collection : hors selection, le contour ne revient pas a la couleur de rarete")
# rangee du deck
maj = H[H.index("majDeckBataille = function()"):]
maj = maj[:maj.index("\nend\n")]
if "RARETES" not in maj or "bord" not in maj:
    e.append("rangee TON DECK : le contour ne suit pas la rarete de la carte")
# CAPTURE D ONGLET : meme chemin que le bouton (sinon selection vide et « NON ENREGISTRE » factice)
crochet = H[H.index('local ongletDemande = ReplicatedStorage:FindFirstChild("BRR_ONGLET")'):]
crochet = crochet[:crochet.index("majOnglets(ongletDemande.Value)")]
if "ouvrirEcranDeck()" not in crochet:
    e.append("capture --onglet=cartes : l ecran n est pas charge comme par le bouton (0 / 8 factice)")
# MARGE : le contour est dessine a l EXTERIEUR de la tuile, le ScrollingFrame le rognait
if "0.3, 0.03, 5)" not in H or "UIPadding" not in H:
    e.append("collection : aucune marge interieure, la bordure de la 1re rangee est rognee")
if "0.36, 0.03, 5)" not in H:
    e.append("boutique : aucune marge interieure, la bordure de la 1re rangee est rognee")
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : chaque carte de l'onglet CARTES porte la bordure de sa rarete (collection et deck)")
sys.exit(1 if e else 0)
