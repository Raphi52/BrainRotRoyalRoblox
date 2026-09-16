# -*- coding: utf-8 -*-
"""Banc de test hors Studio pour src/shared/Effets.lua (lupa = vrai interpreteur Lua).

Ce qu'il verifie : chaque evenement de jeu (mort d'unite, chute de tour, impact, pose de
carte, victoire) produit REELLEMENT des instances visuelles -- particules emises, lumiere,
anneau anime par TweenService -- et qu'aucune ne demande d'identifiant d'asset.

Prerequis : python -m pip install lupa
"""
# fix-ok: cause mesuree = lupa expose Lua 5.4 sans aucune API Roblox ; les echecs de ce banc
# viennent de l'interpreteur (ColorSequence/NumberRange/TweenInfo/Enum inconnus), pas du jeu.
# D'ou les doubles ci-dessous qui ENREGISTRENT ce qui est cree au lieu de le dessiner.
import sys
import pathlib
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Effets.lua"

PRELUDE = r"""
CREES = {}      -- ClassName -> nombre d'instances creees
EMIS = 0        -- total de particules emises
TWEENS = 0      -- animations lancees
DEBRIS = 0      -- nettoyages programmes

local function noter(cls) CREES[cls] = (CREES[cls] or 0) + 1 end

Instance = { new = function(cls)
  noter(cls)
  local o = { ClassName = cls }
  o.Emit = function(_, n) EMIS = EMIS + n end
  return o
end }
local TweenService = { Create = function(_, _inst, _info, _props)
  TWEENS = TWEENS + 1
  return { Play = function() end }
end }
local Debris = { AddItem = function(_, _i, _t) DEBRIS = DEBRIS + 1 end }
local services = { Debris = Debris, TweenService = TweenService }
game = { GetService = function(_, n) return services[n] end }

Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
ColorSequence = { new = function(c) return c end }
NumberSequence = { new = function(n) return n end }
NumberRange = { new = function(a, b) return { a, b } end }
TweenInfo = { new = function(...) return { ... } end }
local V = {}
V.__index = V
V.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local C = {}
C.__index = C
C.__mul = function(a, _b) return a end
CFrame = setmetatable({ new = function(...) return setmetatable({}, C) end,
                        Angles = function(...) return setmetatable({}, C) end }, {})
"""


def charger(lua):
    lua.execute(PRELUDE)
    return lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    if not SRC.exists():
        print("ROUGE : %s absent -- le jeu n'a aucun module d'effets" % SRC)
        return 1
    Effets = charger(lua)
    g = lua.globals()
    V3 = lua.eval("Vector3")
    pos = V3.new(0, 0, 0)
    couleur = "ROUGE"
    arene = lua.eval("{}")

    attendus = ["mort", "tourDetruite", "impact", "pose", "victoire"]
    manquants = [n for n in attendus if Effets[n] is None]
    if manquants:
        print("ROUGE : effets manquants -> %s" % ", ".join(manquants))
        return 1

    for nom in attendus:
        Effets[nom](arene, pos, couleur)

    crees = dict(g.CREES)
    emis = int(g.EMIS)
    tweens = int(g.TWEENS)
    debris = int(g.DEBRIS)
    print("instances creees :", crees)
    print("particules emises :", emis, "| animations :", tweens, "| nettoyages :", debris)

    echecs = []
    if crees.get("ParticleEmitter", 0) < 5:
        echecs.append("ParticleEmitter < 5 (un par evenement)")
    if emis < 250:
        echecs.append("trop peu de particules emises (%d)" % emis)
    if crees.get("PointLight", 0) < 3:
        echecs.append("PointLight < 3 (mort, tour, victoire)")
    if tweens < 1:
        echecs.append("aucune animation TweenService (pose de carte)")
    if debris < len(attendus):
        echecs.append("nettoyage Debris incomplet (%d)" % debris)
    # Branchement reel : le serveur doit APPELER chaque effet, sinon le module est mort-ne.
    serveur = (ROOT / "src" / "server" / "GameServer.server.lua").read_text(encoding="utf-8")
    if 'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Effets"))' not in serveur:
        echecs.append("GameServer ne charge pas le module d'effets")
    for nom in attendus:
        if ("Effets." + nom + "(") not in serveur:
            echecs.append("Effets.%s n'est appele nulle part dans GameServer" % nom)
    source = SRC.read_text(encoding="utf-8")
    if "rbxassetid" in source:
        echecs.append("le module depend d'un identifiant d'asset : non portable")

    if echecs:
        for e in echecs:
            print("ROUGE :", e)
        return 1
    print("VERT : les 5 evenements produisent des effets, sans aucun identifiant d'asset.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
