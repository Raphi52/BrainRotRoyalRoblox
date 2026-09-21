# -*- coding: utf-8 -*-
"""Banc du PAQUET DU ROBOT (Economie.cartesRobot / cartesPossedees), hors Studio.

Pourquoi il existe : un camp sans joueur tirait son deck dans TOUT le catalogue. Le robot sortait
donc des cartes PAYANTES (jusqu'a 1500 pieces) contre un joueur neuf qui n'a que les cartes
offertes — un duel perdu d'avance que rien ne signalait, puisque aucun test ne regardait d'ou
venait le paquet du robot. Le defaut grossit a chaque carte payante ajoutee.

Ce qu'il verifie :
  1. sans joueur en face, le robot ne recoit QUE des cartes offertes (aucune carte a prix) ;
  2. avec un joueur en face, il recoit EXACTEMENT le paquet de ce joueur ;
  3. un joueur qui possede moins de cartes qu'il n'y a de places retombe sur les cartes offertes
     (sinon le robot jouerait un paquet trop court) ;
  4. cartesPossedees suit les achats du joueur ;
  5. le serveur de jeu APPELLE bien cette regle (sinon elle serait morte-nee).

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

# ARENES : le VRAI module partage (src/shared/Arenes.lua), injecte dans le faux
# environnement. Un bouchon rendrait le banc aveugle a une regression des trophees.
_ARENES_SRC = (pathlib.Path(__file__).resolve().parent.parent / "src/shared/Arenes.lua").read_text(encoding="utf-8")
_SAISON_SRC = (pathlib.Path(__file__).resolve().parent.parent / "src/shared/Saison.lua").read_text(encoding="utf-8")
PRELUDE_ARENES = (
    "math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end"
    + chr(10) + "ARENES = (function() " + _ARENES_SRC + " end)()"
    # SAISON : module pur requis par Economie depuis les saisons de classement.
    + chr(10) + "SAISON = (function() " + _SAISON_SRC + " end)()"
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "server_placeholder"
ECONOMIE = ROOT / "src" / "server" / "Economie.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\1 = \1 - ", code)
    return code


PRELUDE = r"""
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b else return x end end
Random = { new = function(_) return { NextInteger = function(_, a, _b) return a end,
                                      NextNumber = function(_, a, _b) return (a or 0) end } end }
warn = function(...) end
DONNEES = {}
local function faux_store()
  return { GetAsync = function(_, cle) return DONNEES[cle] end,
           SetAsync = function(_, cle, v) DONNEES[cle] = v end }
end
-- WaitForChild rend le NOM demande : le faux require sait alors quel module rendre.
local Shared = { WaitForChild = function(_, n) return n end }
local services = {
  Players = {},
  DataStoreService = { GetDataStore = function(_, _n) return faux_store() end },
  MarketplaceService = {},
  ReplicatedStorage = { WaitForChild = function(_, _n) return Shared end },
}
game = { GetService = function(_, n) return services[n] end, BindToClose = function(_, _f) end }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
local V = {}
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
Instance = { new = function(cls)
  local o = {}
  rawset(o, "ClassName", cls); rawset(o, "Name", ""); rawset(o, "Value", 0)
  rawset(o, "FindFirstChild", function(self, n) return rawget(self, n) end)
  setmetatable(o, { __newindex = function(t, k, v)
    rawset(t, k, v)
    if k == "Parent" and v ~= nil then rawset(v, rawget(t, "Name"), t) end
  end })
  return o
end }
"""

ECHECS = []


def cas(titre, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + titre + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(titre)


def ids(t):
    return sorted(t.values()) if t is not None else None


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    # VRAI catalogue : le banc doit voir les vraies cartes payantes, pas un catalogue invente.
    cartes = lua.execute("return (function() " + CARDS.read_text(encoding="utf-8") + " end)()")
    lua.globals().CARDS = cartes
    lua.execute(PRELUDE_ARENES)
    import pathlib as _pl_ligues
    lua.execute("LIGUES = (function() " + (_pl_ligues.Path(__file__).resolve().parent.parent / "src/shared/Ligues.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("PASSSAISON = (function() " + (_pl_ligues.Path(__file__).resolve().parent.parent / "src/shared/PassSaison.lua").read_text(encoding="utf-8") + " end)()")
    lua.execute("require = function(m) if m == 'Arenes' then return ARENES end if m == 'Saison' then return SAISON end return CARDS end")
    Economie = lua.execute("return (function() " + luau_vers_lua(ECONOMIE.read_text(encoding="utf-8")) + " end)()")

    if Economie.cartesRobot is None:
        print("ROUGE : Economie.cartesRobot absent — le robot tire dans tout le catalogue")
        return 1

    offertes, payantes = [], []
    for i in range(1, len(cartes.list) + 1):
        c = cartes.list[i]
        (payantes if c.prix else offertes).append(c.id)
    print("  catalogue reel : %d cartes, dont %d payantes (%s)" % (len(offertes) + len(payantes), len(payantes), ", ".join(payantes)))
    cas("le catalogue a bien des cartes payantes a exclure", True, len(payantes) > 0)

    # 1. aucun joueur en face
    seul = ids(Economie.cartesRobot(None))
    cas("sans joueur en face : aucune carte payante", [], sorted(set(seul) & set(payantes)))
    cas("sans joueur en face : toutes les offertes", sorted(offertes), seul)

    # 2. joueur en face avec un paquet complet (offertes + une payante achetee)
    achete = sorted(offertes + payantes[:1])
    enFace = lua.eval("(function(t) local o = {} for _, v in ipairs(t) do table.insert(o, v) end return o end)")(
        lua.table_from(achete))
    cas("avec un joueur en face : le robot joue SON paquet", achete, ids(Economie.cartesRobot(enFace)))

    # 3. paquet trop court : repli sur les offertes
    court = lua.table_from(offertes[:3])
    cas("paquet trop court : repli sur les offertes", sorted(offertes), ids(Economie.cartesRobot(court)))

    # 4. cartesPossedees suit le profil
    joueur = lua.eval("(function(n,u) local p = {Name=n, UserId=u} "
                      "p.FindFirstChild = function(self,k) return rawget(self,k) end return p end)")("Neuf", 42)
    Economie.charger(joueur)
    neuf = ids(Economie.cartesPossedees(joueur))
    cas("un joueur neuf possede exactement les offertes", sorted(offertes), neuf)
    profil = Economie.profil(joueur)
    profil.pieces = 99999
    # DEBLOCAGE PAR ARENE : l'or ne suffit plus. Une carte rattachee a un palier reste
    # refusee tant que le joueur n'a pas les trophees, meme riche.
    profil.trophees = 0
    refus = Economie.acheterCarte(joueur, payantes[0])
    cas("carte d'une arene non atteinte : achat refuse malgre l'or", False,
        payantes[0] in ids(Economie.cartesPossedees(joueur)))
    profil.trophees = 9999
    Economie.acheterCarte(joueur, payantes[0])
    cas("arene atteinte : la carte entre dans le paquet", True, payantes[0] in ids(Economie.cartesPossedees(joueur)))

    # 5. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur de jeu applique la regle", True, "Economie.cartesRobot(" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : le robot ne sort jamais une carte payante que le joueur d'en face n'a pas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
