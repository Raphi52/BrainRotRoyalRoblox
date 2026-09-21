# -*- coding: utf-8 -*-
"""CHAMPIONS : cartes a capacite activable avec recharge, un seul par deck, bouton en partie.

src/shared/Champions.lua (regles pures) + Cards.lua (cartes champions) + Economie (deck) +
GameServer (activation serveur, effet, etat envoye) + GameClient (bouton de capacite).
"""
import sys, pathlib, re
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
e = []
lua = LuaRuntime()
M = lua.execute((R / "src/shared/Champions.lua").read_text(encoding="utf-8"))
CARDS_SRC = (R / "src/shared/Cards.lua").read_text(encoding="utf-8")
E = (R / "src/server/Economie.lua").read_text(encoding="utf-8")
G = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
GC = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")

byId = lua.eval("{ a = { id = 'a' }, b = { id = 'b' }, c1 = { id = 'c1', capacite = 'bouclierRoyal' },"
                " c2 = { id = 'c2', capacite = 'rugissement' } }")
ids = lambda *x: lua.eval("{" + ",".join(f"'{i}'" for i in x) + "}")
# un seul champion par deck
if not M.deckValide(ids("a", "b", "c1"), byId):
    e.append("deck avec un champion : valide")
if M.deckValide(ids("a", "c1", "c2"), byId) is True:
    e.append("deck avec deux champions : refuse")
# activation : vivant, elixir, recharge
etat = lua.eval("{ capacite = 'bouclierRoyal', vivant = true }")
c = M.CAPACITES.bouclierRoyal
if not M.peutActiver(etat, 10, 100):
    e.append("champion vivant, elixir suffisant, jamais utilise : activable")
if M.peutActiver(etat, c.cout - 1, 100) is True:
    e.append("pas assez d'elixir : refuse")
etat.derniere = 100
if M.peutActiver(etat, 10, 100 + c.recharge - 1) is True:
    e.append("en recharge : refuse")
if not M.peutActiver(etat, 10, 100 + c.recharge):
    e.append("recharge finie : activable")
etat.vivant = False
if M.peutActiver(etat, 10, 1000) is True:
    e.append("champion tombe : refuse")
if M.vue(etat, 10, 1000) is not None:
    e.append("champion tombe : plus de bouton")
etat.vivant = True
v = M.vue(etat, 10, 105)
if v is None or v.reste != c.recharge - 5 or v.pret:
    e.append("vue : secondes restantes et etat non pret attendus")
# chaque capacite a un cout, une recharge, un effet connu
for k in ("bouclierRoyal", "rugissement"):
    cap = M.CAPACITES[k]
    if cap is None or not cap.cout or not cap.recharge or cap.effet not in ("bouclier", "gel"):
        e.append(f"capacite {k} incomplete")
# cartes champions dans le catalogue
champs = re.findall(r'capacite\s*=\s*"(\w+)"', CARDS_SRC)
if len(champs) < 2:
    e.append(f"au moins 2 cartes champions attendues dans Cards.lua, {len(champs)}")
# branchements
if 'item("ModuleScript", "Champions"' not in B:
    e.append("build : Champions non embarque")
if "un seul champion par deck" not in E:
    e.append("economie : un deck a deux champions passerait")
if 'Name = "Capacite"' not in G or "Champions.peutActiver(" not in G:
    e.append("serveur : pas d'activation controlee par le serveur")
if "champion = " not in G or "Champions.vue(" not in G:
    e.append("serveur : l'etat du champion n'est pas envoye au joueur")
if "BoutonCapacite" not in GC or 'WaitForChild("Capacite")' not in GC:
    e.append("partie : pas de bouton de capacite")
for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : champions a capacite (elixir + recharge), un seul par deck, active par le serveur, bouton en partie")
sys.exit(1 if e else 0)
