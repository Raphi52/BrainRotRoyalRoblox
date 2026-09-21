# -*- coding: utf-8 -*-
"""COSMETIQUES : skins de tours + emotes premium, en gemmes, SANS impact sur l'equilibre.

src/shared/Cosmetiques.lua (regles pures) + Emotes.lua (emotes premium) + Economie (achat,
equipement) + GameServer (skin applique aux tours, emote premium refusee si non possedee) + Hub
(ecran avec apercu 3D) + GameClient (barre d'emotes = emotes possedees).
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
e = []
lua = LuaRuntime()
C = lua.execute((R / "src/shared/Cosmetiques.lua").read_text(encoding="utf-8"))
EM = lua.execute((R / "src/shared/Emotes.lua").read_text(encoding="utf-8"))
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
G = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
H = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
GC = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")

# 1. AUCUN IMPACT SUR L'EQUILIBRE : pas un seul champ de statistique dans un skin
STATS = {"hp", "maxHp", "dmg", "degats", "range", "portee", "atkSpeed", "vitesse", "speed", "elixir", "pv"}
n = len(C.SKINS)
if n < 4:
    e.append(f"au moins 3 skins payants attendus (+ classique), {n} au total")
for i in range(1, n + 1):
    s = C.SKINS[i]
    champs = set(s.keys())
    if champs & STATS:
        e.append(f"skin {s.id} : champ de statistique {champs & STATS}")
    if s.prix > 0 and (s.creneaux is None or s.accent is None):
        e.append(f"skin payant {s.id} sans ornement ni liseret : il ne se verrait pas")
    if "corps" in champs and s.corps is None:
        e.append(f"skin {s.id} sans materiau de corps")
if C.skin("inconnu").id != "classique":
    e.append("skin inconnu : retomber sur le classique")
# le corps garde la couleur du camp : aucun skin ne definit de couleur de corps
for i in range(1, n + 1):
    if C.SKINS[i].couleurCorps is not None:
        e.append("un skin ne doit pas recolorer le CORPS de la tour (couleur du camp)")

# 2. EMOTES PREMIUM dans la liste unique, avec un prix ; les gratuites restent gratuites
prem = [EM.LISTE[i] for i in range(1, len(EM.LISTE) + 1) if EM.LISTE[i].prix]
if len(prem) < 3:
    e.append(f"au moins 3 emotes premium attendues, {len(prem)}")
if EM.LISTE[1].prix:
    e.append("les emotes de base doivent rester gratuites")

# 3. CATALOGUE, ACHAT, EQUIPEMENT
cat = C.catalogue(EM)
types = {cat[i].type for i in range(1, len(cat) + 1)}
if types != {"skin", "emote"}:
    e.append(f"catalogue : skins ET emotes attendus, {types}")
etat = C.neuf()
if not C.peutAcheter(EM, etat, 999, "or"):
    e.append("achat possible avec assez de gemmes")
if C.peutAcheter(EM, etat, 5, "or") is True:
    e.append("achat sans assez de gemmes : refuse")
if C.peutAcheter(EM, etat, 999, "classique") is True:
    e.append("le classique est gratuit et deja possede : pas en vente")
if C.peutEquiper(etat, "or") is True:
    e.append("equiper un skin non possede : refuse")
etat.possedes["or"] = True
if not C.peutEquiper(etat, "or"):
    e.append("equiper un skin possede : accepte")
if C.peutAcheter(EM, etat, 999, "or") is True:
    e.append("racheter un article possede : refuse")
p_id = prem[0].id if prem else "x"
if C.emotePermise(EM, etat, p_id):
    e.append("emote premium non possedee : refusee")
if not C.emotePermise(EM, etat, "gg"):
    e.append("emote gratuite : toujours permise")
abime = C.normaliser(lua.eval("{ possedes = { lave = true }, skin = 'glace' }"))
if abime.skin != "classique" or not abime.possedes["classique"]:
    e.append("normaliser : skin non possede -> classique, classique toujours possede")

# 4. BRANCHEMENTS
if 'item("ModuleScript", "Cosmetiques"' not in B:
    e.append("build : Cosmetiques non embarque")
if "Economie.acheterCosmetique" not in E or "Economie.equiperSkin" not in E:
    e.append("economie : achat ou equipement absent")
if "appliquerSkin(" not in G or "skinCamp" not in G:
    e.append("serveur : le skin n'est pas applique aux tours du joueur")
if "Cosmetiques.emotePermise(" not in G:
    e.append("serveur : une emote premium non possedee passerait")
if 'action == "cosmetique"' not in G:
    e.append("serveur : action cosmetique absente")
if "PanneauCosmetiques" not in H or "ViewportFrame" not in H:
    e.append("hub : pas d'ecran de cosmetiques avec apercu 3D")
if "EmotesPossedees" not in GC:
    e.append("partie : la barre d'emotes ne suit pas les emotes possedees")
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : skins de tours et emotes premium en gemmes, apercu 3D, visibles en partie, aucune statistique touchee")
sys.exit(1 if e else 0)
