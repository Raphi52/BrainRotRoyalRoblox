# -*- coding: utf-8 -*-
"""Banc de test hors Studio pour le DECK CHOISI (src/server/Economie.lua).

Ce qu'il verifie, cote SERVEUR (le client n'est jamais cru) :
  1. un deck de 8 cartes possedees est accepte, puis rendu par Economie.deck ;
  2. un deck contenant une carte NON possedee est refuse ;
  3. un deck contenant une carte inconnue est refuse ;
  4. un doublon est refuse ;
  5. une taille != 8 est refusee ;
  6. un profil deja sauvegarde SANS deckChoisi continue de marcher (retro-compat) ;
  7. une carte retiree du catalogue invalide le deck plutot que de le servir troue.

Meme technique que tools/test_economie.py : lupa (Lua 5.4) + adaptation Luau minimale.
Prerequis : python -m pip install lupa
"""
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
DONNEES = {}   -- cle -> profil rendu par GetAsync (nil = joueur neuf)

local function faux_store()
  return {
    GetAsync = function(_, cle) return DONNEES[cle] end,
    SetAsync = function(_, cle, v) DONNEES[cle] = v end,
  }
end

-- WaitForChild rend le NOM demande : le faux `require` ci-dessous sait alors quel module
-- rendre. En rendant toujours "CARDS", il rendait le catalogue bidon pour TOUS les modules.
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
-- catalogue de test : 10 cartes gratuites + 1 payante (non possedee au depart)
CARDS = { list = {}, byId = {} }
for i = 1, 10 do
  local c = { id = "c" .. i, name = "c" .. i }
  table.insert(CARDS.list, c)
  CARDS.byId[c.id] = c
end
local payante = { id = "vip", name = "vip", prix = 500 }
table.insert(CARDS.list, payante)
CARDS.byId["vip"] = payante
-- Chaque module partage dont Economie depend doit etre declare ici, sinon `require` rend le
-- catalogue bidon et ses fonctions sont nil (mesure du 2026-09-20 : Arenes, puis Saison).
require = function(m)
  if m == "Arenes" then return ARENES end if m == "Ligues" then return LIGUES end if m == "PassSaison" then return PASSSAISON end
  if m == "Saison" then return SAISON end if m == "Journal" then return JOURNAL end
  return CARDS
end
"""


def charger(lua):
    # Les VRAIS modules partages dont Economie depend, injectes avant lui.
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    for _nom, _f in (("ARENES", "Arenes"), ("SAISON", "Saison"), ("LIGUES", "Ligues"), ("PASSSAISON", "PassSaison")):
        _src = (ROOT / "src" / "shared" / (_f + ".lua")).read_text(encoding="utf-8")
        lua.execute(_nom + " = (function() " + _src + " end)()")
    lua.execute("SAISON = (function() " + (pathlib.Path(__file__).resolve().parent.parent / "src/shared/Saison.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("JOURNAL = (function() " + (pathlib.Path(__file__).resolve().parent.parent / "src/shared/Journal.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute(PRELUDE)
    code = luau_vers_lua(SRC.read_text(encoding="utf-8"))
    return lua.execute("return (function() " + code + " end)()")


def joueur(lua, nom, uid):
    fab = lua.eval("(function(n,u) local p = {Name=n, UserId=u} "
                   "p.FindFirstChild = function(self,k) return rawget(self,k) end "
                   "return p end)")
    return fab(nom, uid)


ECHECS = []


def cas(titre, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + titre + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(titre)


def appel(res):
    """lupa rend un tuple quand Lua renvoie 2 valeurs, un scalaire quand il n'en renvoie qu'une."""
    return res if isinstance(res, tuple) else (res, None)


def ids(table_lua):
    return sorted(table_lua.values()) if table_lua is not None else None


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    Economie = charger(lua)
    g = lua.globals()
    t = lua.eval("(function(...) return {...} end)")

    if Economie.choisirDeck is None:
        print("ROUGE : Economie.choisirDeck n'existe pas (le joueur ne peut pas choisir son deck)")
        return 1

    alice = joueur(lua, "Alice", 1)
    Economie.charger(alice)

    ok, motif = appel(Economie.choisirDeck(alice, t("c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8")))
    cas("deck de 8 cartes possedees accepte", True, ok)
    cas("... sans motif d'erreur", None, motif)
    huit = ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"]
    cas("Economie.deck rend exactement les 8 cartes choisies", huit, ids(Economie.deck(alice)))

    cas("carte non possedee refusee", False,
        appel(Economie.choisirDeck(alice, t("c1", "c2", "c3", "c4", "c5", "c6", "c7", "vip")))[0])
    cas("carte inconnue refusee", False,
        appel(Economie.choisirDeck(alice, t("c1", "c2", "c3", "c4", "c5", "c6", "c7", "zzz")))[0])
    cas("doublon refuse", False,
        appel(Economie.choisirDeck(alice, t("c1", "c1", "c3", "c4", "c5", "c6", "c7", "c8")))[0])
    cas("deck de 3 cartes refuse", False, appel(Economie.choisirDeck(alice, t("c1", "c2", "c3")))[0])
    cas("le deck valide n'a pas ete abime par les refus", huit, ids(Economie.deck(alice)))

    # la vue envoyee au hub porte le deck reel et le nombre de places
    v = Economie.vue(alice)
    cas("vue : nombre de places", 8, v["deckTaille"])
    cas("vue : deck reel", huit, sorted(v["deck"].values()))
    cas("vue : le joueur a bien un deck choisi", True, v["deckChoisi"])

    # le choix est PERSISTE : le profil relu porte le deck
    Economie.liberer(alice)
    Economie.charger(alice)
    cas("deck retrouve apres rechargement du profil", huit, ids(Economie.deck(alice)))

    # profil ANCIEN, sans deckChoisi : on rend toutes les cartes possedees (comportement d'avant).
    # `charger` offre au passage les cartes gratuites ajoutees depuis : Bob possede donc c1..c10.
    bob = joueur(lua, "Bob", 2)
    g.DONNEES["u2"] = lua.eval("{ pieces = 10, trophees = 0, victoires = 0, parties = 0, "
                               "cartes = { c1 = true, c2 = true }, dernierBonus = 0 }")
    Economie.charger(bob)
    cas("profil sans deck : toutes les cartes possedees", sorted("c%d" % i for i in range(1, 11)),
        ids(Economie.deck(bob)))

    # carte retiree du catalogue : le deck devenu invalide ne doit pas etre servi troue
    lua.execute("CARDS.byId['c8'] = nil "
                "for i, c in ipairs(CARDS.list) do if c.id == 'c8' then table.remove(CARDS.list, i) break end end")
    carol = joueur(lua, "Carol", 3)
    g.DONNEES["u3"] = lua.eval("{ pieces = 10, trophees = 0, victoires = 0, parties = 0, "
                               "cartes = { c1 = true, c2 = true, c3 = true }, dernierBonus = 0, "
                               "deckChoisi = { 'c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7', 'c8' } }")
    Economie.charger(carol)
    cas("deck invalide (carte disparue) : repli sur les cartes possedees",
        sorted("c%d" % i for i in range(1, 11) if i != 8), ids(Economie.deck(carol)))

    if ECHECS:
        print("ROUGE : " + str(len(ECHECS)) + " cas en echec")
        return 1
    print("VERT : deck choisi verifie par le serveur, persiste et retro-compatible")
    return 0


sys.exit(main())
