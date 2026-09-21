# -*- coding: utf-8 -*-
"""GESTES DE POSE (src/shared/Geste.lua + branchement).

Deux manques de l'audit :
 1. aucun GLISSER-DEPOSER — il fallait taper la carte puis taper l'arene, deux gestes la ou le
    genre entier en demande un seul (et au doigt, deux fois plus de ratés) ;
 2. aucune ANNULATION — une carte choisie par erreur restait armee, et le geste suivant la posait :
    on perdait la carte ET l'elixir.

1) Les regles PURES sont EXECUTEES (lupa).
2) Le branchement est lu : le client arme des l'appui, suit le doigt, decide au relachement, et
   n'a pas perdu le mode en deux temps (le plus sur a la souris pour poser loin).
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
GE = (R / "src/shared/Geste.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(GE)
SEUIL = M.SEUIL_GLISSE

# --- CLIC OU GLISSE -----------------------------------------------------------------------------
if M.distance(0, 0, 3, 4) != 5:
    e.append("la distance doit etre euclidienne")
if M.type(100, 100, 100, 100) != "clic":
    e.append("sans deplacement, c'est un clic")
if M.type(100, 100, 100 + SEUIL - 1, 100) != "clic":
    e.append("juste sous le seuil, un tremblement de doigt reste un clic")
if M.type(100, 100, 100 + SEUIL, 100) != "glisse":
    e.append("au seuil exact, c'est un glisse")
if M.type(100, 100, 300, 400) != "glisse":
    e.append("un grand deplacement est un glisse")
if not (6 <= SEUIL <= 30):
    e.append("un seuil hors de 6-30 px rend le geste soit nerveux, soit mou")

# --- ANNULATION ---------------------------------------------------------------------------------
if M.annuleSurPanneau(700, 650) is not True:
    e.append("relacher SUR la main de cartes doit annuler (on repose la carte d'ou elle vient)")
if M.annuleSurPanneau(600, 650) is not False:
    e.append("au-dessus du panneau, ce n'est pas une annulation")
if M.annuleSurPanneau(None, 650) is not False or M.annuleSurPanneau(700, None) is not False:
    e.append("sans mesure, on n'annule pas par defaut (on ne devine pas l'intention)")
if M.annuleParTouche("Escape") is not True or M.annuleParTouche("MouseButton2") is not True:
    e.append("echap et clic droit doivent annuler")
for autre in ("Space", "MouseButton1", "", None):
    if M.annuleParTouche(autre) is not False:
        e.append(f"{autre!r} ne doit pas annuler (liste FERMEE)")

# --- DECISION AU RELACHEMENT --------------------------------------------------------------------
if M.relachement("glisse", False, True) != "poser":
    e.append("un glisse termine sur l'arene doit POSER")
if M.relachement("glisse", False, False) != "annuler":
    e.append("un glisse termine hors de l'arene est un renoncement, pas une pose ratee")
if M.relachement("glisse", True, True) != "annuler":
    e.append("relacher sur la main annule, meme si l'arene est la")
if M.relachement("clic", False, True) != "garder":
    e.append("un simple clic doit GARDER la carte armee (mode deux temps conserve)")
if M.relachement("clic", True, True) != "annuler":
    e.append("un clic qui finit sur la main annule aussi")
if not M.texteAnnulation() or len(M.texteAnnulation()) < 4:
    e.append("une annulation muette ressemble a un bug : il faut le dire")

# --- BRANCHEMENT --------------------------------------------------------------------------------
if 'item("ModuleScript", "Geste"' not in B:
    e.append("build : Geste non embarque")
if 'WaitForChild("Geste")' not in C:
    e.append("client : module Geste non requis")
if "glisseDepart = { x = input.Position.X, y = input.Position.Y, index = i }" not in C:
    e.append("client : le point de depart du glisse n'est pas retenu")
if "Geste.type(depart.x, depart.y, x, y)" not in C:
    e.append("client : le type de geste n'est pas decide par la regle")
if "Geste.relachement(typeGeste, surPanneau, surArene)" not in C:
    e.append("client : la decision de relachement n'est pas branchee")
if 'action == "poser"' not in C or "deployAtScreen(x, y)" not in C:
    e.append("client : un glisse ne pose pas la carte a l'endroit relache")
if "local function annulerSelection" not in C or "Geste.annuleParTouche(nom)" not in C:
    e.append("client : echap et clic droit n'annulent pas")
if "bottom.AbsolutePosition.Y" not in C:
    e.append("client : la zone d'annulation n'est pas celle du VRAI panneau de cartes")
if "if glisseDepart and pointeurX then" not in C:
    e.append("client : l'apercu ne suit pas le doigt pendant un glisse")
if "UserInputService.InputChanged:Connect" not in C:
    e.append("client : la position du doigt n'est jamais mise a jour")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : un seul geste pose la carte, et une carte armee se repose sans rien perdre")
sys.exit(1 if e else 0)
