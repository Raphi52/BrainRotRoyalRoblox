# -*- coding: utf-8 -*-
"""Recherche d'adversaire (src/server/Matchmaking.lua) + son branchement.

1) La logique PURE est EXECUTEE (lupa) : un seul des deux serveurs mene la paire, une entree deja
   prise n'est jamais ecrasee, le robot arrive a ATTENTE_MAX, un serveur reserve est reconnu.
2) Le branchement est lu : JOUER passe par la file, le serveur reserve place le joueur d'office et
   renvoie au hub en fin de match, build.py embarque le module, le hub affiche l'attente.
"""
import re, sys, pathlib
from lupa import LuaRuntime
R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
GS = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
L = lua.eval
def entrees(*items):
    return L("function(...) local t = {} for i, v in ipairs({...}) do t[i] = v end return t end")(*items)
e1 = L('{ cle = "1", valeur = { t = 1 } }'); e2 = L('{ cle = "2", valeur = { t = 2 } }')
e3 = L('{ cle = "3", valeur = { t = 3 } }'); pris = L('{ cle = "0", valeur = { t = 0, code = "X" } }')
ch = M.choisirAdversaire
if ch(entrees(e1, e2), "1") != "2": e.append("le plus ancien doit prendre le suivant")
if ch(entrees(e1, e2), "2") is not None: e.append("le second ne doit PAS mener (double reservation)")
if ch(entrees(e1), "1") is not None: e.append("seul en file : pas d'adversaire")
if ch(entrees(pris, e1, e2), "1") != "2": e.append("une entree deja prise doit etre ignoree")
if ch(entrees(e1, e2, e3), "3") is not None: e.append("un 3e joueur ne rejoint pas une paire formee")
if M.marquer(L('{ t = 1, code = "A" }'), "B") is not None: e.append("marquer ecrase une entree deja prise")
if M.marquer(None, "B") is not None: e.append("marquer recree une entree partie")
if M.marquer(L('{ t = 1 }'), "B").code != "B": e.append("marquer ne pose pas le code")
if M.robotDu(0, 19.9) or not M.robotDu(0, 20): e.append("robot attendu a 20 s pile")
if not M.estServeurDeMatch(L('{ PrivateServerId = "abc", PrivateServerOwnerId = 0 }')): e.append("serveur reserve non reconnu")
if M.estServeurDeMatch(L('{ PrivateServerId = "abc", PrivateServerOwnerId = 42 }')): e.append("serveur VIP pris pour un match")
if M.estServeurDeMatch(L('{ PrivateServerId = "", PrivateServerOwnerId = 0 }')): e.append("serveur public pris pour un match")
for mot in ("MemoryStoreService", "ReserveServer", "ReservedServerAccessCode", "TeleportAsync"):
    if mot not in MM: e.append("Matchmaking : " + mot + " absent")
if 'require(script.Parent:WaitForChild("Matchmaking"))' not in GS: e.append("GameServer ne charge pas Matchmaking")
j = re.search(r'action == "jouer" then(.*?)elseif', GS, re.S)
if not j or "Matchmaking.entrer(player, rejoindre)" not in j.group(1): e.append("JOUER ne passe pas par la file")
if not re.search(r"estServeurDeMatch\(game\) then\s+rejoindre\(player\)", GS): e.append("serveur reserve : joueur non place d'office")
if not re.search(r"estServeurDeMatch\(game\) then\s+task\.delay\(\d+, Matchmaking\.retourHub\)", GS): e.append("fin de match : pas de retour au hub")
if "Matchmaking.sortir(player)" not in GS: e.append("un joueur qui part reste dans la file")
if 'item("ModuleScript", "Matchmaking"' not in B: e.append("build.py n'embarque pas Matchmaking")
if 'InvokeServer("attente")' not in HUB or 'InvokeServer("enMatch")' not in HUB: e.append("hub : attente / arrivee en match non gerees")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
