# -*- coding: utf-8 -*-
"""Banc : toute fonction declaree d'un module partage EXISTE des son chargement.

Defaut mesure le 2026-09-21 : dans src/shared/Adversaire.lua, deux fonctions avaient ete inserees
PAR ERREUR a l'interieur d'une branche de `Adversaire.nom`. Elles n'existaient qu'une fois `nom`
appele avec un palier. Le banc du module appelait `nom` plus haut, les definissait par effet de
bord, et passait VERT — pendant que le serveur plantait a CHAQUE etat de partie (« attempt to call
a nil value », 150 fois) et que le client restait fige, main vide.

Ce banc charge chaque module de src/shared dans un faux Roblox TOLERANT, SANS appeler aucune de ses
fonctions, puis verifie que chaque `function Module.nom(` ecrite en tete de ligne existe bien dans
la table rendue. Un module qui ne se charge pas hors Studio (API Roblox trop profonde) est LISTE
comme non verifie — jamais compte comme vert en silence.
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"

# Faux Roblox TOLERANT : tout acces rend un objet qui accepte tout (appel, index, arithmetique).
# Le but n'est pas d'executer le jeu, seulement de laisser le CORPS du module se charger.
PRELUDE = r"""
local function faux(nom)
  local o = {}
  return setmetatable(o, {
    __index = function(_, k) return faux(tostring(nom) .. "." .. tostring(k)) end,
    __call = function() return faux(tostring(nom) .. "()") end,
    __add = function() return 0 end, __sub = function() return 0 end,
    __mul = function() return 0 end, __div = function() return 1 end,
    __unm = function() return 0 end, __concat = function() return "" end,
    __lt = function() return false end, __le = function() return true end,
    __tostring = function() return tostring(nom) end,
  })
end
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b else return x end end
game = faux("game"); workspace = faux("workspace"); script = faux("script")
Instance = faux("Instance"); Enum = faux("Enum"); Color3 = faux("Color3")
Vector3 = faux("Vector3"); Vector2 = faux("Vector2"); CFrame = faux("CFrame")
UDim2 = faux("UDim2"); UDim = faux("UDim"); TweenInfo = faux("TweenInfo")
NumberSequence = faux("NumberSequence"); ColorSequence = faux("ColorSequence")
NumberRange = faux("NumberRange"); NumberSequenceKeypoint = faux("NumberSequenceKeypoint")
ColorSequenceKeypoint = faux("ColorSequenceKeypoint"); Random = faux("Random")
RaycastParams = faux("RaycastParams"); Region3 = faux("Region3"); Rect = faux("Rect")
task = faux("task"); warn = function() end; typeof = type; tick = os.clock
require = function(_) return faux("module") end
"""


def luau_vers_lua(code):
    code = re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\g<1> = \g<1> + ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*-=\s*", r"\g<1> = \g<1> - ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*\*=\s*", r"\g<1> = \g<1> * ", code)
    code = re.sub(r"([\w\.\[\]]+)\s*/=\s*", r"\g<1> = \g<1> / ", code)
    return code


def main():
    fichiers = sorted(SHARED.glob("*.lua"))
    absentes, non_verifies, verifies, fonctions = [], [], 0, 0
    for f in fichiers:
        texte = f.read_text(encoding="utf-8")
        declarees = re.findall(r"^function (\w+)\.(\w+)\s*\(", texte, re.M)
        if not declarees:
            continue
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(PRELUDE)
        try:
            module = lua.execute("return (function() " + luau_vers_lua(texte) + " end)()")
        except Exception as e:
            non_verifies.append("%s (%s)" % (f.name, str(e).splitlines()[0][:70]))
            continue
        if module is None or not hasattr(module, "keys"):
            non_verifies.append("%s (ne rend pas de table)" % f.name)
            continue
        verifies += 1
        for tab, nom in declarees:
            fonctions += 1
            # La table rendue porte-t-elle ce nom ? (on ne controle que les fonctions de la table
            # que le module RENVOIE ; une table interne d'aide n'est pas concernee.)
            if module[nom] is None:
                absentes.append("%s : %s.%s" % (f.name, tab, nom))
    print("  %d modules charges hors Studio, %d fonctions controlees" % (verifies, fonctions))
    for n in non_verifies:
        print("  NON VERIFIE " + n)
    ok = True
    if absentes:
        ok = False
        for a in absentes:
            print("  ROUGE fonction absente au chargement : " + a)
    # Garde-fou : un banc qui ne controle presque rien ne prouve rien.
    if verifies < len(fichiers) * 0.8:
        ok = False
        print("  ROUGE trop peu de modules verifies (%d sur %d)" % (verifies, len(fichiers)))
    if not ok:
        print("ROUGE : des fonctions n'existent qu'apres un appel, ou la couverture est insuffisante")
        return 1
    print("VERT : les %d fonctions des %d modules partages existent des le chargement" % (fonctions, verifies))
    return 0


sys.exit(main())
