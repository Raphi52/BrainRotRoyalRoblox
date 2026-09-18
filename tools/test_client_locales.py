# -*- coding: utf-8 -*-
"""Garde-fou : chaque variable de premier niveau utilisee dans GameClient/Hub y est DECLAREE avant.

Cause mesuree le 2026-09-18 (Studio, 3 clients) : une edition a supprime `local bottom = ...` ;
`bottom.Size` indexait alors un global nil et TOUT le script client s'arretait (ecran fige).
Les tests textuels n'avaient rien vu. Ici : pour chaque `X.Propriete = ...` en debut de ligne
(niveau 0), X doit avoir un `local X` (ou `local function X`) plus haut, ou etre un global Roblox connu.
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
GLOBAUX = {"game", "workspace", "script", "Enum", "Instance", "UDim2", "UDim", "Vector2", "Vector3",
           "Color3", "CFrame", "TweenInfo", "task", "math", "string", "table", "os"}
e = []
for rel in ["src/client/GameClient.client.lua", "src/client/Hub.client.lua"]:
    lignes = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    declares = set(GLOBAUX)
    for n, l in enumerate(lignes, 1):
        for m in re.finditer(r"^local\s+(?:function\s+)?([\w\s,]+?)(?:=|\(|$)", l):
            declares.update(x.strip() for x in m.group(1).split(",") if x.strip())
        m = re.match(r"^([A-Za-z_]\w*)[.:]\w", l)
        if m and m.group(1) not in declares:
            e.append(f"{rel}:{n} : « {m.group(1)} » utilise sans declaration prealable")
for x in e[:20]: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
