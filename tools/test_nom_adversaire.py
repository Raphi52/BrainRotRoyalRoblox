# -*- coding: utf-8 -*-
"""Le score doit afficher le vrai nom de l'adversaire, pas « Bot » en dur.

1. Serveur : la fonction nomAdversaire (extraite de GameServer.server.lua) rend le DisplayName
   de l'occupant du camp adverse, ou « Bot » si ce camp est vide ; sendState l'envoie.
2. Client : la ligne du score lit s.nomAdversaire et n'ecrit plus « Bot » en dur.
Prerequis : python -m pip install lupa
"""
import re
import sys
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVEUR = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")
CLIENT = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
echecs = []

m = re.search(r"^local function nomAdversaire\(.*?^end\n", SERVEUR, re.S | re.M)
if not m:
    echecs.append("serveur : fonction nomAdversaire absente")
else:
    lua = LuaRuntime()
    f = lua.execute("local occupant = {}\n" + m.group(0) +
                    "\nreturn function(o1, o2, camp) occupant[1] = o1; occupant[2] = o2; return nomAdversaire(camp) end")
    alice = lua.eval("{ DisplayName = 'Alice' }")
    bob = lua.eval("{ DisplayName = 'Bob' }")
    for o1, o2, camp, attendu in [(alice, bob, 1, "Bob"), (alice, bob, 2, "Alice"),
                                  (alice, None, 1, "Bot"), (None, bob, 2, "Bot")]:
        r = f(o1, o2, camp)
        if r != attendu:
            echecs.append(f"serveur : camp {camp} -> {r!r}, attendu {attendu!r}")
if not re.search(r"nomAdversaire\s*=\s*nomAdversaire\(monCamp\)", SERVEUR):
    echecs.append("serveur : sendState n'envoie pas nomAdversaire")

score = [l for l in CLIENT.splitlines() if "crownsLabel.Text" in l and "crownsEnemy" in l]
if not score:
    echecs.append("client : ligne du score introuvable")
for l in score:
    if '" Bot"' in l or "nomAdversaire" not in l:
        echecs.append("client : le score n'affiche pas s.nomAdversaire : " + l.strip())

for e in echecs:
    print("ROUGE", e)
print("OK" if not echecs else f"{len(echecs)} echec(s)")
sys.exit(1 if echecs else 0)
