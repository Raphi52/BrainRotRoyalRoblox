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
    UpdateAsync = function(_, cle, f)
      local v = f(DONNEES[cle])
      if v == nil then return nil end
      if PANNE.ecrireProfil then error("ecriture profil indisponible (simule)") end
      COMPTEUR.profil = COMPTEUR.profil + 1
      DONNEES[cle] = v
      return v
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

-- WaitForChild rend le NOM demande : le faux require sait alors quel module rendre.
local Shared = { WaitForChild = function(_, n) return n end }
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
-- ARENES : le VRAI module partage, charge plus bas par le banc (voir charger_arenes).
CARDS = { list = {}, byId = {} }
for i = 1, 10 do
  local c = { id = "c" .. i, name = "c" .. i }
  table.insert(CARDS.list, c)
  CARDS.byId[c.id] = c
end
require = function(m) if m == "Arenes" then return ARENES end if m == "Ligues" then return LIGUES end if m == "PassSaison" then return PASSSAISON end if m == "Saison" then return SAISON end if m == "Journal" then return JOURNAL end return CARDS end
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
    # ARENES : le VRAI module partage, charge AVANT Economie — recompenser passe par lui.
    lua.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
    lua.execute("ARENES = (function() " + (ROOT / "src/shared/Arenes.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("LIGUES = (function() " + (ROOT / "src/shared/Ligues.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("PASSSAISON = (function() " + (ROOT / "src/shared/PassSaison.lua").read_text(encoding="utf-8") + " end)()")
    # SAISON : module pur requis par Economie depuis les saisons de classement.
    lua.execute("SAISON = (function() " + (ROOT / "src/shared/Saison.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("JOURNAL = (function() " + (ROOT / "src/shared/Journal.lua").read_text(encoding="utf-8") + " end)()")
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

    print("\n-- 8. gemmes : un produit de gemmes passe par le meme traitement des paiements")
    idx_gemmes = None
    for i in range(1, len(Economie.PRODUITS) + 1):
        if Economie.PRODUITS[i].gemmes:
            idx_gemmes = i
    cas("un produit de gemmes existe au catalogue", True, idx_gemmes is not None)
    if idx_gemmes is not None:
        # Depuis le 2026-09-26 le produit porte son vrai identifiant : on repose 0 ici pour
        # verifier la regle « id 0 = offre masquee », au lieu de supposer l'etat livre.
        Economie.PRODUITS[idx_gemmes].id = 0
        dora = joueur(lua, "Dora", 4)
        Economie.charger(dora)
        offres = Economie.vue(dora).offresRobux
        cas("... absent des offres tant que son id vaut 0", False,
            any(offres[k].index == idx_gemmes for k in offres))
        Economie.PRODUITS[idx_gemmes].id = 67890
        cas("profil neuf : 0 gemme", 0, Economie.profil(dora).gemmes)
        pieces_avant = Economie.profil(dora).pieces
        n = Economie.PRODUITS[idx_gemmes].gemmes
        cas("achat de gemmes confirme", "GRANTED", process(recu(lua, "achat-G", 67890, 4)))
        cas("... gemmes creditees", n, Economie.profil(dora).gemmes)
        cas("... pieces inchangees", pieces_avant, Economie.profil(dora).pieces)
        cas("rappel du meme recu : confirme", "GRANTED", process(recu(lua, "achat-G", 67890, 4)))
        cas("... pas de double credit", n, Economie.profil(dora).gemmes)
        cas("gemmes visibles dans la vue", n, Economie.vue(dora).gemmes)
        g.PANNE.ecrireProfil = True
        cas("sauvegarde impossible : vente repoussee", "PAS_ENCORE",
            process(recu(lua, "achat-H", 67890, 4)))
        cas("... gemmes reprises", n, Economie.profil(dora).gemmes)
        g.PANNE.ecrireProfil = False

    print("\n-- 9. profil ancien sans champ gemmes : charge sans erreur")
    g.DONNEES["u5"] = lua.eval("{ pieces = 42, trophees = 7, victoires = 0, parties = 0,"
                               " cartes = {}, dernierBonus = 0 }")
    eve = joueur(lua, "Eve", 5)
    Economie.charger(eve)
    cas("pieces conservees", 42, Economie.profil(eve).pieces)
    cas("gemmes a 0", 0, Economie.profil(eve).gemmes)

    if ECHECS:
        print("\nROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        return 1
    print("\nVERT : achats Robux idempotents et confirmes seulement si le disque a pris ;"
          " ecritures de profil regroupees")
    return 0


if __name__ == "__main__":
    sys.exit(main())
