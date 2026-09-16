# -*- coding: utf-8 -*-
"""Banc de test hors Studio pour les ACHATS ROBUX et les ECRITURES REGROUPEES
(src/server/Economie.lua).

Ce qu'il verifie, cote SERVEUR :
  1. le meme PurchaseId rejoue deux fois ne credite qu'UNE fois ;
  2. si la sauvegarde du profil echoue, la vente n'est PAS confirmee et rien n'est credite ;
  3. si le registre des recus ne peut pas etre ecrit, la vente n'est pas confirmee non plus ;
  4. si le registre est illisible, on refuse de trancher plutot que de risquer un double credit ;
  5. les gestes ordinaires (recompense, coffre, niveau) n'ecrivent plus a chaque fois :
     ils marquent le profil, et une seule ecriture part au passage suivant.

Meme technique que tools/test_deck.py : lupa (Lua 5.4) + adaptation Luau minimale.
Prerequis : python -m pip install lupa
"""
import os
import re
import sys
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
# BRR_ECONOMIE permet de faire tourner le banc contre une AUTRE version du module : c'est ainsi
# qu'on verifie que ces cas sont bien ROUGES sur le code d'avant le correctif.
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
task = nil  -- hors Studio : pas de boucle de fond, on declenche viderSales a la main

DONNEES = {}      -- profils ecrits
RECUS = {}        -- registre des recus
COMPTEUR = { profil = 0, recu = 0 }
PANNE = { ecrireProfil = false, ecrireRecu = false, lireRecu = false }

local function storeProfils()
  return {
    GetAsync = function(_, cle) return DONNEES[cle] end,
    SetAsync = function(_, cle, v)
      if PANNE.ecrireProfil then error("ecriture profil indisponible (simule)") end
      COMPTEUR.profil = COMPTEUR.profil + 1
      DONNEES[cle] = v
    end,
  }
end

local function storeRecus()
  return {
    GetAsync = function(_, cle)
      if PANNE.lireRecu then error("registre illisible (simule)") end
      return RECUS[cle]
    end,
    SetAsync = function(_, cle, v)
      if PANNE.ecrireRecu then error("ecriture recu indisponible (simule)") end
      COMPTEUR.recu = COMPTEUR.recu + 1
      RECUS[cle] = v
    end,
  }
end

JOUEURS = {}  -- UserId -> player
MarketplaceService = { PromptProductPurchase = function() end }

local Shared = { WaitForChild = function(_, _n) return "CARDS" end }
local services = {
  Players = { GetPlayerByUserId = function(_, uid) return JOUEURS[uid] end },
  DataStoreService = { GetDataStore = function(_, n)
    if n == "BRR_Recus" then return storeRecus() end
    return storeProfils()
  end },
  MarketplaceService = MarketplaceService,
  ReplicatedStorage = { WaitForChild = function(_, _n) return Shared end },
}
game = { GetService = function(_, n) return services[n] end,
         BindToClose = function(_, _f) end }
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
require = function(_m) return CARDS end
"""

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print("  %s  %s : attendu %r, obtenu %r" % ("OK  " if ok else "RATE", nom, attendu, obtenu))
    if not ok:
        ECHECS.append(nom)


def joueur(lua, nom, uid):
    fab = lua.eval("(function(n,u) local p = {Name=n, UserId=u} "
                   "p.FindFirstChild = function(self,k) return rawget(self,k) end "
                   "return p end)")
    p = fab(nom, uid)
    lua.globals().JOUEURS[uid] = p
    return p


def recu(lua, purchase_id, product_id, user_id):
    fab = lua.eval("(function(a,b,c) return {PurchaseId=a, ProductId=b, PlayerId=c} end)")
    return fab(purchase_id, product_id, user_id)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    code = luau_vers_lua(SRC.read_text(encoding="utf-8"))
    Economie = lua.execute("return (function() " + code + " end)()")
    g = lua.globals()

    # les produits du jeu portent encore id = 0 (non crees chez Roblox) : on en cable un vrai
    Economie.PRODUITS[1].id = 12345
    pieces_produit = Economie.PRODUITS[1].pieces

    process = g.MarketplaceService.ProcessReceipt

    alice = joueur(lua, "Alice", 1)
    Economie.charger(alice)
    depart = Economie.profil(alice).pieces

    print("\n-- 1. le meme recu rejoue ne credite qu'une fois")
    r = recu(lua, "achat-A", 12345, 1)
    cas("1er passage : vente confirmee", "GRANTED", process(r))
    cas("... pieces creditees", depart + pieces_produit, Economie.profil(alice).pieces)
    cas("2e passage : vente confirmee sans recrediter", "GRANTED", process(r))
    cas("... pieces inchangees", depart + pieces_produit, Economie.profil(alice).pieces)

    print("\n-- 2. sauvegarde du profil impossible : pas de vente")
    avant = Economie.profil(alice).pieces
    g.PANNE.ecrireProfil = True
    cas("vente repoussee", "PAS_ENCORE", process(recu(lua, "achat-B", 12345, 1)))
    cas("... aucune piece creditee", avant, Economie.profil(alice).pieces)
    g.PANNE.ecrireProfil = False

    print("\n-- 3. registre des recus non ecrivable : pas de vente")
    avant = Economie.profil(alice).pieces
    g.PANNE.ecrireRecu = True
    cas("vente repoussee", "PAS_ENCORE", process(recu(lua, "achat-C", 12345, 1)))
    cas("... aucune piece creditee", avant, Economie.profil(alice).pieces)
    g.PANNE.ecrireRecu = False

    print("\n-- 4. registre illisible : on refuse de trancher")
    avant = Economie.profil(alice).pieces
    g.PANNE.lireRecu = True
    cas("vente repoussee", "PAS_ENCORE", process(recu(lua, "achat-D", 12345, 1)))
    cas("... aucune piece creditee", avant, Economie.profil(alice).pieces)
    g.PANNE.lireRecu = False

    print("\n-- 5. un achat deja honore reste honore apres la panne")
    cas("achat-A toujours reconnu", "GRANTED", process(recu(lua, "achat-A", 12345, 1)))

    print("\n-- 6. ecritures regroupees : les gestes ordinaires n'ecrivent plus a chaque fois")
    g.COMPTEUR.profil = 0
    Economie.recompenser(alice, "victoire")
    Economie.recompenser(alice, "defaite")
    Economie.bonusQuotidien(alice)
    cas("aucune ecriture pendant les gestes", 0, int(g.COMPTEUR.profil))
    ecrits = Economie.viderSales()
    cas("un seul profil ecrit au passage", 1, int(ecrits))
    cas("une seule ecriture disque", 1, int(g.COMPTEUR.profil))
    Economie.viderSales()
    cas("passage suivant : plus rien a ecrire", 1, int(g.COMPTEUR.profil))

    print("\n-- 7. le depart du joueur ecrit tout de suite")
    Economie.recompenser(alice, "victoire")
    avant = int(g.COMPTEUR.profil)
    Economie.liberer(alice)
    cas("liberer ecrit sans attendre", avant + 1, int(g.COMPTEUR.profil))

    if ECHECS:
        print("\nROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        return 1
    print("\nVERT : achats Robux idempotents et confirmes seulement si le disque a pris ;"
          " ecritures de profil regroupees")
    return 0


if __name__ == "__main__":
    sys.exit(main())
