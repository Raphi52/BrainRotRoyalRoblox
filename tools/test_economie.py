# -*- coding: utf-8 -*-
"""Banc de test hors Studio pour src/server/Economie.lua (lupa = vrai interpreteur Lua).

Ce qu'il verifie : une lecture de profil ratee pour UN joueur ne doit pas couper la
sauvegarde des AUTRES joueurs du serveur. Le module Luau est charge tel quel, avec une
adaptation de syntaxe minimale (a += b -> a = a + b) car lupa est en Lua 5.4.

Prerequis : python -m pip install lupa
"""
# fix-ok: cause mesuree des reprises de ce banc = lupa expose Lua 5.4, qui refuse la
# syntaxe Luau du fichier reel (operateurs += / -=, types, task/WaitForChild) et n'a
# aucune API Roblox. Chaque echec etait un "syntax error near +=" ou un "attempt to
# index nil (game/DataStoreService)" de l'interpreteur, pas un defaut du jeu : d'ou la
# reecriture regex luau_vers_lua() + les doubles game/DataStoreService/Instance.
import re
import sys
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "server" / "Economie.lua"


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\1 = \1 - ", code)
    return code


PRELUDE = r"""
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b else return x end end
Random = { new = function(_) return { NextInteger = function(_, a, _b) return a end,
                                      NextNumber = function(_, a, _b) return (a or 0) end } end }
warn = function(...) print("[warn]", ...) end
ECHECS_LECTURE = {}   -- userId -> true : GetAsync renvoie une erreur pour ce joueur
SAUVEGARDES = {}      -- cle -> nombre de SetAsync reussis

local function faux_store()
  return {
    GetAsync = function(_, cle)
      local id = tonumber(string.sub(cle, 2))
      if ECHECS_LECTURE[id] then error("DataStore indisponible (simule)") end
      return nil
    end,
    SetAsync = function(_, cle, _v) SAUVEGARDES[cle] = (SAUVEGARDES[cle] or 0) + 1 end,
  }
end

-- Le vrai Economie require plusieurs modules partages. On rend le NOM demande, et `require`
-- (plus bas) sert le module REEL quand il est pur (Arenes, Saison) : le banc teste alors les
-- vraies regles au lieu d'un mannequin.
local Shared = { WaitForChild = function(_, n) return n end }
local services = {
  Players = {},
  DataStoreService = { GetDataStore = function(_, _n) return faux_store() end },
  MarketplaceService = {},
  ReplicatedStorage = { WaitForChild = function(_, _n) return Shared end },
}
game = { GetService = function(_, n) return services[n] end,
         BindToClose = function(_, _f) end }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
Instance = { new = function(cls)
  local o = {}
  rawset(o, "ClassName", cls)
  rawset(o, "Name", "")
  rawset(o, "Value", 0)
  rawset(o, "FindFirstChild", function(self, n) return rawget(self, n) end)
  setmetatable(o, { __newindex = function(t, k, v)
    rawset(t, k, v)
    if k == "Parent" and v ~= nil then rawset(v, rawget(t, "Name"), t) end
  end })
  return o
end }
CARDS = { list = { { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" } } }
require = function(nom) return MODULES[nom] or CARDS end
"""


def charger(lua):
    lua.execute(PRELUDE)
    # modules partages PURS charges pour de vrai (ils ne touchent pas a Roblox)
    lua.execute("MODULES = {}")
    for nom in ("Arenes", "Saison"):
        source = (SRC.parent.parent / "shared" / (nom + ".lua")).read_text(encoding="utf-8")
        lua.execute(f"MODULES['{nom}'] = (function() {luau_vers_lua(source)} end)()")
    code = luau_vers_lua(SRC.read_text(encoding="utf-8"))
    return lua.execute("return (function() " + code + " end)()")


def joueur(lua, nom, uid):
    fab = lua.eval("(function(n,u) local p = {Name=n, UserId=u} "
                   "p.FindFirstChild = function(self,k) return rawget(self,k) end "
                   "return p end)")
    return fab(nom, uid)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    Economie = charger(lua)
    g = lua.globals()
    g.ECHECS_LECTURE[1] = True     # le joueur 1 a un profil illisible
    alice = joueur(lua, "Alice", 1)
    bob = joueur(lua, "Bob", 2)
    Economie.charger(alice)
    Economie.charger(bob)          # Bob, lui, se charge sans probleme
    Economie.sauver(bob)
    n = g.SAUVEGARDES["u2"] or 0
    print("SetAsync pour Bob (u2) :", n)
    if n != 1:
        print("ROUGE : la panne d'Alice a coupe la sauvegarde de Bob.")
        return 1

    Economie.sauver(alice)         # Alice, elle, reste non persistante
    na = g.SAUVEGARDES["u1"] or 0
    print("SetAsync pour Alice (u1) :", na)
    if na != 0:
        print("ROUGE : Alice ecrit alors que son profil n'a pas pu etre lu (ecrasement).")
        return 1

    print("VERT : Bob est sauvegarde malgre la panne d'Alice, et Alice n'ecrase rien.")
    return 0


sys.exit(main())
