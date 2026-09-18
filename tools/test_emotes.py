# -*- coding: utf-8 -*-
"""Emotes rapides : RemoteEvent Emote, liste fermee, delai par joueur, bulle sur la tour du Roi.

1. Serveur : emoteAutorisee (extraite, executee avec lupa) refuse un id inconnu ou non texte,
   accepte la premiere emote, refuse avant EMOTE_DELAI, accepte apres.
2. Serveur : la RemoteEvent « Emote » existe ; le spectateur est refuse ; la bulle va sur towers[3] (le Roi).
3. Client : les boutons envoient EmoteEvent:FireServer(id) et sont caches au spectateur.
Prerequis : python -m pip install lupa
"""
import re, sys, pathlib
from lupa import LuaRuntime
ROOT = pathlib.Path(__file__).resolve().parent.parent
S = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (ROOT / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
e = []
em = re.search(r"^local EMOTES = \{.*?\}$", S, re.M)
de = re.search(r"^local EMOTE_DELAI = \d+", S, re.M)
fn = re.search(r"^local function emoteAutorisee\(.*?^end\n", S, re.S | re.M)
if not (em and de and fn):
    e.append("serveur : EMOTES, EMOTE_DELAI ou emoteAutorisee absent")
else:
    f = LuaRuntime().execute(em.group(0) + "\n" + de.group(0) + "\n" + fn.group(0) + "return emoteAutorisee")
    d = int(re.search(r"\d+", de.group(0)).group(0))
    for args, att in [(("gg", None, 10), True), (("inconnue", None, 10), False), ((42, None, 10), False),
                      (("rire", 10, 10 + d - 0.5), False), (("rire", 10, 10 + d), True)]:
        if f(*args) != att:
            e.append(f"serveur : emoteAutorisee{args} -> {f(*args)}, attendu {att}")
if not re.search(r'EmoteEvent\.Name = "Emote"', S):
    e.append("serveur : RemoteEvent Emote absente")
h = re.search(r"EmoteEvent\.OnServerEvent:Connect\(function\(player, id\).*?\nend\)", S, re.S)
if not h or "equipeDe[player]" not in h.group(0) or "emoteAutorisee" not in h.group(0):
    e.append("serveur : le gestionnaire ne verifie pas camp + delai")
a = re.search(r"local function afficherEmote.*?\nend\n", S, re.S)
if not a or "towers[3]" not in a.group(0):
    e.append("serveur : la bulle n'est pas posee sur la tour du Roi")
if 'EmoteEvent:FireServer(e[1])' not in C:
    e.append("client : aucun bouton n'envoie d'emote")
if "emotesBarre.Visible = not s.spectateur" not in C:
    e.append("client : les emotes ne sont pas cachees au spectateur")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
