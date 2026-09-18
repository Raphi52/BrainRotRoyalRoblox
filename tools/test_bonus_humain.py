# -*- coding: utf-8 -*-
"""Une victoire contre un HUMAIN rapporte un bonus de pieces ; contre le bot, rien de plus.

1. Economie.recompenser(player, issue, contreHumain) (extraite d'Economie.lua, executee avec lupa) :
   victoire contre humain = pieces de base + BONUS_HUMAIN ; contre le bot = base ; defaite : aucun bonus ;
   le pass VIP double aussi le bonus.
2. GameServer : endMatch passe contreHumain = (occupant du camp adverse present).
Prerequis : python -m pip install lupa
"""
import re, sys, pathlib
from lupa import LuaRuntime
ROOT = pathlib.Path(__file__).resolve().parent.parent
ECO = (ROOT / "src/server/Economie.lua").read_text(encoding="utf-8")
SRV = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
e = []

def luau(c):
    return re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", c)

rec = re.search(r"^local RECOMPENSE = \{.*?^\}\n", ECO, re.S | re.M)
bonus = re.search(r"^local BONUS_HUMAIN = \d+.*$", ECO, re.M)
fn = re.search(r"^function Economie\.recompenser\(.*?^end\n", ECO, re.S | re.M)
if not (rec and bonus and fn):
    e.append("economie : RECOMPENSE, BONUS_HUMAIN ou recompenser introuvable")
else:
    lua = LuaRuntime()
    run = lua.execute(luau(
        "local Economie = { gagnerCoffre = function() return nil end, marquerSale = function() end }\n"
        "local profils = {}\nlocal vip = false\nlocal function aVip() return vip end\n"
        "local function leaderstats() end\n" + rec.group(0) + bonus.group(0) + "\n" + fn.group(0) +
        "return function(issue, humain, v) vip = v; local pl = { Name = 'A' }\n"
        "profils[pl] = { pieces = 0, trophees = 0, parties = 0, victoires = 0 }\n"
        "return Economie.recompenser(pl, issue, humain).pieces end"))
    base = lua.execute(rec.group(0) + "return RECOMPENSE")
    b = int(re.search(r"\d+", bonus.group(0)).group(0))
    v = base["victoire"]["pieces"]; d = base["defaite"]["pieces"]
    for issue, h, vip, att in [("victoire", True, False, v + b), ("victoire", False, False, v),
                               ("defaite", True, False, d), ("victoire", True, True, 2 * (v + b))]:
        r = run(issue, h, vip)
        if r != att:
            e.append(f"economie : {issue} humain={h} vip={vip} -> {r}, attendu {att}")
if not re.search(r"Economie\.recompenser,\s*joueur,\s*issue,\s*occupant\[3 - camp\] ~= nil", SRV):
    e.append("serveur : endMatch ne dit pas si l'adversaire est humain")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
