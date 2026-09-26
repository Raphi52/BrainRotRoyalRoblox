# -*- coding: utf-8 -*-
"""Classement des trophees entre serveurs (OrderedDataStore) et top 10 dans le hub.

1. Economie.sauver (extraite, executee avec lupa) : apres une sauvegarde REUSSIE du profil, les
   trophees partent dans le store ordonne sous la cle u<UserId> ; si la sauvegarde echoue, rien.
2. formaterClassement (extraite) : rangs 1..n, nom resolu, « ? » si le nom est inconnu, max 10.
3. Economie.lua ouvre bien GetOrderedDataStore ; le serveur repond a l'action « classement » ;
   le hub la demande et affiche la liste.
Prerequis : python -m pip install lupa
"""
import re, sys, pathlib
from lupa import LuaRuntime
ROOT = pathlib.Path(__file__).resolve().parent.parent
E = (ROOT / "src/server/Economie.lua").read_text(encoding="utf-8")
S = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
H = (ROOT / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []

def luau(c):
    return re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", c)

sv = re.search(r"^function Economie\.sauver\(.*?^end\n", E, re.S | re.M)
if not sv:
    e.append("economie : Economie.sauver introuvable")
else:
    lua = LuaRuntime()
    run = lua.execute(luau(
        "local Economie = { sauvegardeActive = function() return true end,\n"
        "  verrouPeutEcrire = function() return true end }\n"
        "local profils, sales, sansSauvegarde = {}, {}, {}\nlocal ECRITS = {}\nlocal PANNE = false\nlocal MOI = 'srv'\n"
        # verrou de session : ce serveur tient le profil, l'ecriture passe par UpdateAsync
        "local store = { UpdateAsync = function(_, k, f) if PANNE then error('panne') end return f({ _session = { job = MOI } }) end }\n"
        "local storeClassement = { SetAsync = function(_, k, v) ECRITS[k] = v end }\n"
        "warn = function() end\n" + sv.group(0) +
        "return function(panne) PANNE = panne; ECRITS = {}; local pl = { UserId = 7, Name = 'A' }\n"
        "profils[pl] = { trophees = 123 }; Economie.sauver(pl); return ECRITS['u7'] end"))
    if run(False) != 123:
        e.append(f"economie : sauvegarde reussie -> classement {run(False)!r}, attendu 123")
    if run(True) is not None:
        e.append("economie : sauvegarde ratee mais classement ecrit quand meme")

fm = re.search(r"^local function formaterClassement\(.*?^end\n", E, re.S | re.M)
if not fm:
    e.append("economie : formaterClassement absente")
else:
    lua = LuaRuntime()
    f = lua.execute(fm.group(0) + """
return function(n)
  local entrees = {}
  for i = 1, n do entrees[i] = { key = "u" .. i, value = 100 - i } end
  local r = formaterClassement(entrees, function(uid) if uid == 2 then return nil end return "J" .. uid end)
  return #r, r[1].rang, r[1].nom, r[1].trophees, r[2].nom
end""")
    n, rang, nom, tr, nom2 = f(12)
    if (n, rang, nom, tr, nom2) != (10, 1, "J1", 99, "?"):
        e.append(f"economie : formaterClassement -> {(n, rang, nom, tr, nom2)}, attendu (10, 1, 'J1', 99, '?')")
if 'GetOrderedDataStore("BRR_Trophees_v1")' not in E:
    e.append("economie : store ordonne BRR_Trophees_v1 non ouvert")
if not re.search(r'action == "classement"\s*then\s*\n\s*return \{ ok = true, classement = Economie\.classement\(\)', S):
    e.append("serveur : action « classement » absente")
if 'Boutique:InvokeServer("classement")' not in H or "majClassement" not in H:
    e.append("hub : le top 10 n'est ni demande ni affiche")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
