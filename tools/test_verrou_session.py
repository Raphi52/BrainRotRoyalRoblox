# -*- coding: utf-8 -*-
"""Banc hors Studio du VERROU DE SESSION des profils (src/server/Economie.lua).

Le defaut (constate le 2026-09-26) : chaque match se joue dans un serveur RESERVE, donc le joueur
change de serveur a chaque partie. Le profil etait lu par GetAsync et ecrit par SetAsync, sans
trace de QUI le tenait. Le serveur d'arrivee pouvait le lire avant que celui de depart n'ait ecrit
ses derniers gains, puis l'ecraser avec sa copie perimee : la victoire, le coffre, l'achat en
pieces disparaissaient.

Deux serveurs sont simules dans UN runtime Lua : le module est charge deux fois, avec deux
`game.JobId` differents, sur le MEME DataStore factice (qui copie les valeurs, comme Roblox).

  1. course du changement de serveur : le serveur B attend que A rende le profil, et garde ses gains ;
  2. profil ancien (sans verrou) : pris tout de suite, sans attendre ;
  3. serveur mort : B reprend le profil de force apres VERROU_ESSAIS tentatives, et A ne peut
     plus ecraser le disque avec sa copie perimee ;
  4. un achat Robux arrive sur le serveur perime : la vente n'est PAS confirmee ;
  5. le verrou est rendu au depart, et n'entre jamais dans le profil en memoire ;
  6. meme serveur : un retour sur le serveur qui tient deja le profil n'attend pas.

Contre-epreuve : BRR_ECONOMIE=<ancienne version> fait tourner le banc sur un autre fichier ; sur le
code d'avant le verrou, les cas 1, 3 et 4 sont ROUGES.
Prerequis : python -m pip install lupa
"""
import os
import re
import sys
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = pathlib.Path(os.environ.get("BRR_ECONOMIE") or (ROOT / "src" / "server" / "Economie.lua"))


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\1 = \1 - ", code)
    return code


PRELUDE = r"""
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b else return x end end
Random = { new = function(_) return { NextInteger = function(_, a, _b) return a end,
                                      NextNumber = function(_, a, _b) return (a or 0) end } end }
warn = function(...) print("[warn]", ...) end

-- task.wait sans task.spawn : la boucle de fond du module ne demarre pas, mais chaque ATTENTE
-- est comptee et peut declencher ce que « l'autre serveur » fait pendant ce temps.
ATTENTES = 0
QUAND_ATTENTE = nil
task = { wait = function(_s)
  ATTENTES = ATTENTES + 1
  if QUAND_ATTENTE then local f = QUAND_ATTENTE; QUAND_ATTENTE = nil; f() end
end }

-- Roblox SERIALISE ce qu'il stocke : deux serveurs ne partagent jamais la meme table.
local function copie(v)
  if type(v) ~= "table" then return v end
  local c = {}
  for k, x in pairs(v) do c[k] = copie(x) end
  return c
end

DONNEES = {}
RECUS = {}
PANNE = { ecrireProfil = false }

local function storeProfils()
  return {
    GetAsync = function(_, cle) return copie(DONNEES[cle]) end,
    SetAsync = function(_, cle, v)
      if PANNE.ecrireProfil then error("ecriture profil indisponible (simule)") end
      DONNEES[cle] = copie(v)
    end,
    UpdateAsync = function(_, cle, f)
      local nouveau = f(copie(DONNEES[cle]))
      if nouveau ~= nil then
        if PANNE.ecrireProfil then error("ecriture profil indisponible (simule)") end
        DONNEES[cle] = copie(nouveau)
      end
      return copie(nouveau)
    end,
  }
end

local function storeRecus()
  return {
    GetAsync = function(_, cle) return RECUS[cle] end,
    SetAsync = function(_, cle, v) RECUS[cle] = v end,
  }
end

JOUEURS = {}
MarketplaceService = { PromptProductPurchase = function() end }
local Shared = { WaitForChild = function(_, n) return n end }
local services = {
  Players = { GetPlayerByUserId = function(_, uid) return JOUEURS[uid] end },
  DataStoreService = {
    GetDataStore = function(_, n) if n == "BRR_Recus" then return storeRecus() end return storeProfils() end,
    GetOrderedDataStore = function(_, _n) return { SetAsync = function() end } end,
  },
  MarketplaceService = MarketplaceService,
  ReplicatedStorage = { WaitForChild = function(_, _n) return Shared end },
}
game = { GetService = function(_, n) return services[n] end,
         BindToClose = function(_, _f) end, JobId = "" }
Enum = { ProductPurchaseDecision = { PurchaseGranted = "GRANTED", NotProcessedYet = "PAS_ENCORE" } }
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
CARDS = { list = {}, byId = {} }
for i = 1, 10 do
  local c = { id = "c" .. i, name = "c" .. i }
  table.insert(CARDS.list, c)
  CARDS.byId[c.id] = c
end
require = function(m)
  if m == "Arenes" then return ARENES end
  if m == "Ligues" then return LIGUES end
  if m == "PassSaison" then return PASSSAISON end
  if m == "Saison" then return SAISON end
  if m == "Journal" then return JOURNAL end
  if m == "Abandon" then return ABANDON end
  if m == "Quetes" then return QUETES end
  return CARDS
end
"""

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print("  %s  %s : attendu %r, obtenu %r" % ("OK  " if ok else "RATE", nom, attendu, obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    for nom, fichier in (("ARENES", "Arenes"), ("LIGUES", "Ligues"), ("PASSSAISON", "PassSaison"),
                         ("SAISON", "Saison"), ("JOURNAL", "Journal"), ("ABANDON", "Abandon"),
                         ("QUETES", "Quetes")):
        chemin = ROOT / "src" / "shared" / (fichier + ".lua")
        lua.execute("%s = (function() %s end)()" % (nom, luau_vers_lua(chemin.read_text(encoding="utf-8"))))
    lua.execute(PRELUDE)
    g = lua.globals()
    code = luau_vers_lua(SRC.read_text(encoding="utf-8"))

    def serveur(job):
        g.game.JobId = job
        eco = lua.execute("return (function() " + code + " end)()")
        eco.PRODUITS[1].id = 12345
        return eco, g.MarketplaceService.ProcessReceipt

    A, recuA = serveur("srv-A")
    B, recuB = serveur("srv-B")
    essais = int(B.VERROU_ESSAIS or 0)

    fab = lua.eval("(function(n, u) local p = {Name=n, UserId=u} "
                   "p.FindFirstChild = function(self, k) return rawget(self, k) end return p end)")

    def disque(uid):
        return g.DONNEES["u%d" % uid]

    print("\n-- 1. changement de serveur : B attend que A rende le profil")
    pA, pB = fab("Alice", 1), fab("Alice", 1)
    A.charger(pA)
    A.profil(pA).pieces = A.profil(pA).pieces + 500  # gain de victoire, en attente d'ecriture
    A.marquerSale(pA)
    g.ATTENTES = 0
    g.QUAND_ATTENTE = lambda: A.liberer(pA)  # pendant que B attend, A rend le profil (depart)
    B.charger(pB)
    g.QUAND_ATTENTE = None
    cas("B voit le gain fait sur A", 600, int(B.profil(pB).pieces))
    B.profil(pB).pieces = B.profil(pB).pieces + 10
    cas("B ecrit", True, bool(B.sauver(pB)))
    cas("disque : gains de A ET de B", 610, int(disque(1).pieces))

    print("\n-- 2. profil ancien, sans verrou : pris sans attendre")
    g.DONNEES["u2"] = lua.eval("{ pieces = 777, gemmes = 0, cartes = {}, coffres = {} }")
    g.ATTENTES = 0
    pB2 = fab("Bob", 2)
    B.charger(pB2)
    cas("aucune attente", 0, int(g.ATTENTES))
    cas("pieces relues", 777, int(B.profil(pB2).pieces))

    print("\n-- 3. serveur mort : repris de force, et la copie perimee n'ecrase plus rien")
    pA3, pB3 = fab("Carla", 3), fab("Carla", 3)
    A.charger(pA3)
    A.profil(pA3).pieces = 400
    cas("A ecrit tant qu'il tient le profil", True, bool(A.sauver(pA3)))
    g.ATTENTES = 0
    B.charger(pB3)  # A ne rend jamais le profil
    cas("B attend avant de forcer", max(essais - 1, 1), int(g.ATTENTES))
    cas("B lit la derniere ecriture de A", 400, int(B.profil(pB3).pieces))
    B.profil(pB3).pieces = 450
    cas("B ecrit", True, bool(B.sauver(pB3)))
    A.profil(pA3).pieces = 9999  # copie perimee sur A
    cas("A n'ecrit plus", False, bool(A.sauver(pA3)))
    cas("disque : la version de B", 450, int(disque(3).pieces))

    print("\n-- 4. achat Robux arrive sur le serveur perime : vente NON confirmee")
    g.JOUEURS[3] = pA3
    avant = int(A.profil(pA3).pieces)
    r = lua.eval("{ PurchaseId = 'achat-perime', ProductId = 12345, PlayerId = 3 }")
    cas("vente repoussee (Roblox rappellera ailleurs)", "PAS_ENCORE", recuA(r))
    cas("disque intact", 450, int(disque(3).pieces))
    cas("aucun credit sur la copie perimee", avant, int(A.profil(pA3).pieces))
    g.JOUEURS[3] = pB3
    cas("le meme achat, sur le serveur qui tient le profil, passe", "GRANTED", recuB(r))

    print("\n-- 5. le verrou est rendu au depart et reste hors du profil en memoire")
    cas("verrou absent du profil en memoire", None, B.profil(pB)._session)
    B.liberer(pB)
    cas("verrou rendu sur le disque", None, disque(1)._session)

    print("\n-- 6. meme serveur : retour immediat, sans attente")
    pA6 = fab("Dora", 6)
    A.charger(pA6)
    pA6bis = fab("Dora", 6)
    g.ATTENTES = 0
    A.charger(pA6bis)
    cas("aucune attente sur le serveur qui tient deja le profil", 0, int(g.ATTENTES))

    print()
    if ECHECS:
        print("ROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        sys.exit(1)
    print("VERT : verrou de session")


if __name__ == "__main__":
    main()
