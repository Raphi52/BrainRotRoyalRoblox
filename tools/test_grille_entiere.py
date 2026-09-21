# -*- coding: utf-8 -*-
"""Garde-fou : la grille de cartes ne doit jamais couper une rangee en deux.
Defaut mesure le 2026-09-20 (cap-final-boutique.png) : hauteur de cellule donnee en proportion,
mesuree par Roblox sur le CANEVAS -> rangee de 295 px dans une fenetre de 392 px, 2e rangee
tranchee a mi-hauteur. Le calage doit se faire en PIXELS sur la taille affichee du cadre."""
import io, os, re, sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = io.open(os.path.join(RACINE, "src/client/Hub.client.lua"), encoding="utf-8").read()
fonc = src[src.index("local function grilleDefilante"):src.index("local grille = grilleDefilante")]

echecs = []
if "cadre.AbsoluteSize.Y" not in fonc:
    echecs.append("la hauteur de rangee n'est pas calculee sur la taille affichee (AbsoluteSize.Y)")
if 'GetPropertyChangedSignal("AbsoluteSize")' not in fonc:
    echecs.append("aucun recalage quand le cadre change de taille")
for prop, args in re.findall(r"layout\.(CellSize|CellPadding) = UDim2\.new\(([^\n]*)\)\s*$", fonc, re.M):
    champs = [c.strip() for c in args.split(",")]
    if len(champs) == 4 and champs[2] != "0":
        echecs.append("%s garde une hauteur en proportion (%s) : rangee coupee" % (prop, champs[2]))
# hauteur et ecart sont des DECIMAUX ; une marge entiere optionnelle peut suivre (2026-09-21)
for h, e in re.findall(r"grilleDefilante\(.*?,\s*([0-9]*\.[0-9]+)\s*,\s*([0-9]*\.[0-9]+)\s*(?:,\s*\d+\s*)?\)\s*$", src, re.M):
    if 1 / (float(h) + float(e)) < 1:
        echecs.append("appel avec %s/%s : moins d'une rangee tient dans la fenetre" % (h, e))

if echecs:
    for x in echecs:
        print("ECHEC:", x)
    sys.exit(1)
print("OK: hauteur de rangee calee en pixels sur la zone visible, recalage branche")
