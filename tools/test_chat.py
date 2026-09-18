# -*- coding: utf-8 -*-
"""Le chat Roblox est masque contre le bot, visible face a un humain et pour les spectateurs.

Serveur : sendState envoie chatVisible (vrai pour le spectateur, vrai si le camp adverse a un occupant).
Client : plus aucune coupure inconditionnelle ; l'etat recu pilote SetCoreGuiEnabled(Chat, chatVoulu).
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
S = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (ROOT / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
e = []
if not re.search(r"spectateur = true,\s*\n\s*chatVisible = true", S):
    e.append("serveur : spectateur sans chatVisible = true")
if not re.search(r"chatVisible = occupant\[3 - monCamp\] ~= nil", S):
    e.append("serveur : joueur sans chatVisible lie a l'adversaire humain")
if "CoreGuiType.Chat, false" in C:
    e.append("client : le chat est encore coupe sans condition")
if "CoreGuiType.Chat, chatVoulu" not in C:
    e.append("client : SetCoreGuiEnabled ne suit pas chatVoulu")
if not re.search(r"OnClientEvent:Connect\(function\(s\)\s*\n\s*chatVoulu = s\.chatVisible == true\s*\n\s*appliquerChat\(\)", C):
    e.append("client : l'etat recu ne pilote pas le chat")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
