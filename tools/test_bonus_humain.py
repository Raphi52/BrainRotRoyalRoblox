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
# recompenser appelle Economie.bonusSerie : on injecte la VRAIE fonction et ses constantes
# (un bouchon rendant 0 masquerait une regression du bonus de serie). Voir Economie.lua:41-50.
serie = re.search(r"^local BONUS_SERIE = \d+.*?^end$", ECO, re.S | re.M)
if not (rec and bonus and fn and serie):
    e.append("economie : RECOMPENSE, BONUS_HUMAIN, bonusSerie ou recompenser introuvable")
else:
    lua = LuaRuntime()
    # ARENES : recompenser passe desormais par Arenes.apres (protection du bas de tableau) et
    # Arenes.recompensePalier. On injecte le VRAI module, pas un bouchon : un bouchon rendrait
    # le banc aveugle a une regression des trophees.
    ARENES = (ROOT / "src/shared/Arenes.lua").read_text(encoding="utf-8")
    run = lua.execute(luau(
        "math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end\n"
        "local Arenes = (function() " + ARENES + " end)()\n"
        "local Ligues = (function() " + (ROOT / "src/shared/Ligues.lua").read_text(encoding="utf-8") + " end)()\n"
        "local PassSaison = (function() " + (ROOT / "src/shared/PassSaison.lua").read_text(encoding="utf-8") + " end)()\n"
        # JOURNAL : recompenser range la partie finie. Vrai module, pas un bouchon.
        "local Journal = (function() " + (ROOT / "src/shared/Journal.lua").read_text(encoding="utf-8") + " end)()\n"
        "local Economie = { gagnerCoffre = function() return nil end, marquerSale = function() end, suivreSommet = function() end, avancerPass = function() return 0 end }\n"
        "local profils = {}\nlocal vip = false\nlocal function aVip() return vip end\n"
        "local function leaderstats() end\n" + serie.group(0) + "\n" + rec.group(0) + bonus.group(0) + "\n" + fn.group(0) +
        "return function(issue, humain, v) vip = v; local pl = { Name = 'A' }\n"
        "profils[pl] = { pieces = 0, trophees = 0, parties = 0, victoires = 0, journal = {} }\n"
        "return Economie.recompenser(pl, issue, humain).pieces end"))
    base = lua.execute(rec.group(0) + "return RECOMPENSE")
    b = int(re.search(r"\d+", bonus.group(0)).group(0))
    v = base["victoire"]["pieces"]; d = base["defaite"]["pieces"]
    for issue, h, vip, att in [("victoire", True, False, v + b), ("victoire", False, False, v),
                               ("defaite", True, False, d), ("victoire", True, True, 2 * (v + b))]:
        r = run(issue, h, vip)
        if r != att:
            e.append(f"economie : {issue} humain={h} vip={vip} -> {r}, attendu {att}")
# endMatch doit passer « adversaire humain » a Economie.recompenser. La forme de l'appel a change
# (le gain est desormais garde pour l'ecran de fin), le FAIT teste est le meme.
if not (re.search(r"Economie\.recompenser,\s*joueur,\s*issue,\s*occupant\[3 - camp\] ~= nil", SRV)
        or (re.search(r"local contreHumain = occupant\[3 - camp\] ~= nil", SRV)
            and re.search(r"Economie\.recompenser\(joueur, issue, contreHumain", SRV))):
    e.append("serveur : endMatch ne dit pas si l'adversaire est humain")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
