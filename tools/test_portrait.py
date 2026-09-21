# -*- coding: utf-8 -*-
"""PORTRAITS DES PERSONNAGES DANS LE MENU (src/shared/Portrait.lua + Hub.client.lua).

Le defaut corrige (2026-09-21) : le menu n'affichait AUCUNE image — les cartes du deck etaient des
aplats de couleur portant un nom, sur l'ecran meme qui doit donner envie de jouer.

L'image vient du MODELE DU JEU (ReplicatedStorage.Modeles, ecrit dans la place par build.py), rendu
en 3D dans la carte. PAS de la vignette du catalogue : Cards.lua refuse explicitement de dependre
d'un element du catalogue au moment de jouer (« rien qui disparaisse si son auteur le retire »).

1) Cadrage PUR execute (lupa) : le personnage tient dans le cadre, la camera voit son visage.
2) Branchement lu : meme correction d'orientation que le serveur, pas de catalogue, repli propre.
"""
import sys, json, math, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
PO = (R / "src/shared/Portrait.lua").read_text(encoding="utf-8")
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(PO)

# --- LE PERSONNAGE TIENT DANS LE CADRE -----------------------------------------------------------
# A la distance calculee, la plus grande dimension vue de face doit occuper moins que le champ.
for (l, h, p) in ((2, 4, 1), (6, 3, 2), (1, 1, 1), (3, 9, 8)):
    d = M.distance(l, h, p)
    visible = 2 * (d - p / 2) * math.tan(math.radians(M.CHAMP / 2))
    if max(l, h) > visible:
        e.append("un personnage %sx%s deborde du cadre (champ %.2f)" % (l, h, visible))
    if max(l, h) < visible * 0.6:
        e.append("un personnage %sx%s est perdu au milieu du cadre (occupe %.0f %%)" % (l, h, 100 * max(l, h) / visible))
# Plus grand = plus loin, sans quoi un grand modele deborderait.
if not (M.distance(2, 8, 1) > M.distance(2, 4, 1)):
    e.append("un personnage plus grand doit etre cadre de plus loin")
# Donnees aberrantes : pas de camera plutot qu'une camera folle.
for mauvais in ((0, 0, 0), (None, None, None), (-3, -1, 0)):
    if M.distance(*mauvais) is not None:
        e.append("un modele vide ou aberrant ne doit pas produire de cadrage : %r" % (mauvais,))

# --- LA CAMERA VOIT LE VISAGE --------------------------------------------------------------------
# Le serveur tourne chaque modele pour que son avant regarde vers -Z : la camera doit etre du cote -Z.
r = lua.eval("function(m, d) local x, y, z = m.oeil(d) return {x, y, z} end")(M, 10)
x, y, z = r[1], r[2], r[3]
if not z < 0:
    e.append("la camera est derriere le personnage : elle doit etre du cote -Z, ou il regarde")
if not y > 0:
    e.append("la camera doit etre legerement au-dessus (vue plongeante), obtenu y=%s" % y)
if abs(math.sqrt(x * x + z * z) - 10) > 1e-6:
    e.append("la camera doit rester a la distance calculee")
if x == 0:
    e.append("le portrait doit etre de trois quarts, pas strictement de face")
if M.oeil(0) is not None or M.oeil(None) is not None:
    e.append("sans distance, aucune position de camera")

# --- QUELLES CARTES ONT UN PORTRAIT --------------------------------------------------------------
modeles = json.loads((R / "tools/boutique/modeles.json").read_text(encoding="utf-8"))
noms = lua.table_from({k: True for k in modeles})
if M.disponible("Tralalero", noms) is not True:
    e.append("une carte qui a un modele doit avoir un portrait")
if M.disponible("Ballerina", noms) is not False:
    e.append("une carte SANS modele ne doit pas pretendre avoir un portrait")
if M.disponible(None, noms) is not False:
    e.append("sans carte, aucun portrait")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'source=src("shared/Portrait.lua")' not in B:
    e.append("Portrait n'est pas embarque dans la place")
rendu = H.split("jeuxDeck.portrait = function(vue, id)")[1].split("\nend\n")[0] if "jeuxDeck.portrait = function(vue, id)" in H else ""
if not rendu:
    e.append("le menu ne rend aucun portrait")
# Depuis 2026-09-21 le rendu vit dans Figurine.lua (partage par la main, le deck, la collection) :
# le menu delegue, et les exigences portent sur le module.
elif 'WaitForChild("Figurine")).rendre(vue, id)' in rendu:
    rendu = (R / "src/shared/Figurine.lua").read_text(encoding="utf-8")
# PAS de catalogue : c'est la decision consignee dans Cards.lua.
if "rbxthumb://" in H or "rbxassetid://" in rendu:
    e.append("le menu depend du catalogue Roblox, ce que Cards.lua refuse explicitement")
if 'ReplicatedStorage:FindFirstChild("Modeles")' not in rendu:
    e.append("le portrait ne vient pas du modele du jeu")
# MEME orientation que le serveur : sinon le personnage montrerait son dos ou son profil.
if "PivotTo(CFrame.Angles(0, math.rad(card.modeleRotY or 0), 0))" not in S:
    e.append("le serveur n'oriente plus ses modeles comme avant : ce banc doit etre relu")
if "math.rad(carte.modeleRotY or 0)" not in rendu:
    e.append("le portrait n'applique pas la correction d'orientation du serveur")
if "copie.WorldPivot = CFrame.new()" not in rendu:
    e.append("le pivot du modele n'est pas recale sur son centre, comme le fait le serveur")
# Repli propre : une carte sans modele garde son aplat, et on ne reconstruit pas la scene sans cesse.
if "vue.Visible = modele ~= nil" not in rendu:
    e.append("une carte sans modele afficherait une vue vide")
if 'vue:GetAttribute("Carte") == id' not in rendu:
    e.append("la scene serait reconstruite a chaque rafraichissement du menu")
# UTILISE AVANT D'ETRE DEFINI : c'est l'erreur qui a casse le menu (capture du 2026-09-21). Appele
# plus haut que sa definition, `jeuxDeck` valait nil ; le script s'arretait, et tout ce qui suivait
# — deck, onglets, bandeau de ressources — n'etait jamais construit. Le compilateur ne dit rien :
# il prend ce nom pour une variable globale. Seul l'ordre du fichier le revele.
_defs = [i for i, l in enumerate(H.split(chr(10))) if l.startswith("local jeuxDeck = {}")]
_appels = [i for i, l in enumerate(H.split(chr(10))) if "jeuxDeck.portrait(" in l and "= function" not in l]
if _defs and any(i < _defs[0] for i in _appels):
    e.append("jeuxDeck.portrait est appele AVANT la definition de jeuxDeck : le menu s'arreterait sur une erreur")
if "jeuxDeck.portrait(d.portrait, card and card.id or nil)" not in H:
    e.append("le deck n'appelle jamais le rendu des portraits")
if 'portrait.ZIndex' in H and "pastille.ZIndex = 2" not in H:
    e.append("la pastille d'elixir doit rester devant le portrait")

if e:
    print("ROUGE : portraits du menu")
    for m in e:
        print("  - " + m)
    sys.exit(1)
print("VERT : portraits (modele du jeu, cadre, de face-trois-quarts, repli propre) — %d cartes sur %d en ont un"
      % (len(modeles), 47))
