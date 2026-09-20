# -*- coding: utf-8 -*-
"""Harnais Lua partage pour les bancs hors Studio de src/server/Economie.lua.

CE N'EST PAS UN BANC : il ne teste rien et n'affiche rien. Il s'appelait test_economie_lib.py,
ce qui le faisait compter comme un test muet — donc « non vert » — dans toute execution en lot
de tools/test_*.py.

Le prelude reproduit le minimum d'API Roblox dont le module a besoin (DataStore factice,
services, Instance, Enum) pour que lupa (Lua 5.4) puisse charger du Luau. Extrait de
tools/test_economie.py, qui reste autonome : ce module sert aux bancs ajoutes ensuite.
"""
import re
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "server" / "Economie.lua"


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\g<1> = \g<1> + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\g<1> = \g<1> - ", code)
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

-- WaitForChild rend le NOM demande : le faux `require` ci-dessous sait alors quel module
-- rendre (Cards bidon, ou le VRAI module Arenes charge depuis src/shared).
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
-- ARENES est le VRAI module (charge par le harnais python dans la variable globale ARENES) : les
-- paliers de trophees, la protection du bas de tableau et les recompenses de palier sont ainsi
-- mesures sur le code livre, pas sur une copie.
require = function(m)
  if m == "Arenes" then return ARENES end
  return CARDS
end
"""


def nouveau_lua():
    return LuaRuntime(unpack_returned_tuples=True)


def charger_arenes(lua):
    """Injecte le VRAI src/shared/Arenes.lua dans le faux environnement Roblox."""
    import pathlib as _p
    src = (_p.Path(__file__).resolve().parent.parent / "src" / "shared" / "Arenes.lua").read_text(encoding="utf-8")
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("ARENES = (function() " + src + " end)()")


def charger(lua):
    lua.execute(PRELUDE)
    charger_arenes(lua)
    code = luau_vers_lua(SRC.read_text(encoding="utf-8"))
    return lua.execute("return (function() " + code + " end)()")


def joueur(lua, nom, uid):
    fab = lua.eval("(function(n,u) local p = {Name=n, UserId=u} "
                   "p.FindFirstChild = function(self,k) return rawget(self,k) end "
                   "return p end)")
    return fab(nom, uid)
