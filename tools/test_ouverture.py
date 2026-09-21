# -*- coding: utf-8 -*-
"""OUVERTURE DE COFFRE MISE EN SCENE (src/shared/Ouverture.lua + branchement Hub).

Defaut corrige : ouvrir un coffre n'affichait qu'une ligne de texte. On veut : coffre qui
tremble, flash, puis cartes retournees une a une dans la couleur de leur rarete.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
e = []
src = R / "src/shared/Ouverture.lua"
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
if not src.exists():
    print("ROUGE Ouverture.lua absent"); sys.exit(1)
lua = LuaRuntime()
M = lua.execute(src.read_text(encoding="utf-8"))
cartes = lua.execute("""
local R = { commune = { couleur = 'gris' }, legendaire = { couleur = 'orange' }, rare = { couleur = 'bleu' } }
return { RARETES = R, byId = {
  a = { id = 'a', name = 'Tung', rarete = 'commune' },
  b = { id = 'b', name = 'Tralalero', rarete = 'legendaire' } } }
""")
g = lua.eval("{ pieces = 40, exemplaires = 4, exemplaireCarte = 'a', carte = 'b' }")
l = M.cartes(g, cartes)
n = len(l)
if n != 3:
    e.append(f"3 cartes attendues (pieces, exemplaires, nouvelle), obtenu {n}")
else:
    if l[1].rarete != "pieces" or l[2].couleur != "gris" or l[3].couleur != "orange":
        e.append("ordre ou couleur de rarete faux")
    if not l[3].nouvelle:
        e.append("la carte nouvelle garde le dernier retournement et le marque")
if len(M.cartes(lua.eval("{ pieces = 12, exemplaires = 0 }"), cartes)) != 1:
    e.append("sans exemplaire (deck au max), seules les pieces se revelent")
if not (M.instant(2) - M.instant(1) > 0.3 and M.instant(1) >= M.TREMBLE + M.FLASH):
    e.append("les cartes doivent se retourner UNE A UNE, apres tremblement et flash")
if not (M.tremblement(0.9) > M.tremblement(0.1) > 0 and M.tremblement(M.TREMBLE + 0.1) == 0):
    e.append("le tremblement doit monter puis s'arreter au flash")
if 'item("ModuleScript", "Ouverture"' not in B:
    e.append("build : Ouverture non embarque")
for mot in ("Ouverture.cartes(", "Ouverture.tremblement(", "Ouverture.instant(", "montee.ouverture("):
    if mot not in H:
        e.append("hub : " + mot + " absent")
# FINAL : la carte NOUVELLE doit se distinguer (halo tournant + agrandissement), pas un simple bord.
scene_src = H.split("function montee.ouverture")[1] if "function montee.ouverture" in H else ""
if "HaloNouvelle" not in scene_src or "UIScale" not in scene_src:
    e.append("hub : la carte nouvelle n'a ni halo ni agrandissement")
if "Economie.carteImposee" not in (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8"):
    e.append("mode --ouverture : aucune carte nouvelle imposee, le final ne se photographie pas")
# LEGENDAIRE != PIECES (2026-09-21) : l'or legendaire (255,190,60) et l'or des pieces (255,205,60)
# se confondaient sur la photo de la revelation, et l'eclair teintait TOUT l'ecran.
import re
CS = (R / 'src/shared/Cards.lua').read_text(encoding='utf-8')
m = re.search(r'legendaire = \{[^}]*fromRGB\((\d+), (\d+), (\d+)\)', CS)
pieces = (255, 205, 60)
if not m:
    e.append('couleur legendaire introuvable')
else:
    leg = tuple(int(x) for x in m.groups())
    if sum(abs(a - b) for a, b in zip(leg, pieces)) < 90:
        e.append(f'legendaire {leg} trop proche de l or des pieces {pieces}')
scene = H.split('function montee.ouverture')[1] if 'function montee.ouverture' in H else ''
if 'flash.BackgroundColor3 = Color3.fromRGB(255, 220, 110)' in scene:
    e.append('l eclair de la carte nouvelle teinte encore tout l ecran')
if 'EclairHalo' not in scene or 'Etincelle' not in scene:
    e.append('legendaire : ni eclair limite au halo ni etincelles')
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : le coffre tremble, flashe et retourne ses cartes une a une, en couleur de rarete")
sys.exit(1 if e else 0)
