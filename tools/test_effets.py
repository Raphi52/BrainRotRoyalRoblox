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
TOUS = {}       -- ClassName -> liste des objets crees (pour relire leurs proprietes)
EMIS = 0        -- total de particules emises
TWEENS = 0      -- animations lancees
DEBRIS = 0      -- nettoyages programmes

local function noter(cls) CREES[cls] = (CREES[cls] or 0) + 1 end

Instance = { new = function(cls)
  noter(cls)
  local o = { ClassName = cls }
  TOUS[cls] = TOUS[cls] or {}
  table.insert(TOUS[cls], o)
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
local function sequence(v)
  if type(v) == "table" then return { points = #v } end
  return { points = 1, plat = v }
end
ColorSequence = { new = function(c) return sequence(c) end }
NumberSequence = { new = function(n) return sequence(n) end }
ColorSequenceKeypoint = { new = function(t, c) return { t, c } end }
NumberSequenceKeypoint = { new = function(t, n) return { t, n } end }
NumberRange = { new = function(a, b) return { a, b } end }
TweenInfo = { new = function(...) return { ... } end }
local V = {}
V.__index = V
V.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V) end
V.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V) end
V.__mul = function(a, k) return setmetatable({ X = a.X * k, Y = a.Y * k, Z = a.Z * k }, V) end
V.__index = function(t, k)
  if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
  return V[k]
end
Color3 = { new = function(r, g, b) return "BLANC" end }
DIFFERES = {}
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
task = { delay = function(_, f) table.insert(DIFFERES, f) end, spawn = function(f) end }
function piece(couleur, transparence, enfants)
  local attrs = {}
  return { Color = couleur, Transparency = transparence or 0,
    IsA = function(_, c) return c == "BasePart" end,
    GetAttribute = function(_, k) return attrs[k] end,
    SetAttribute = function(_, k, v) attrs[k] = v end,
    GetDescendants = function() return enfants or {} end }
end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local C = {}
C.__index = C
C.__mul = function(a, _b) return a end
CFrame = setmetatable({ new = function(...) return setmetatable({}, C) end,
                        Angles = function(...) return setmetatable({}, C) end,
                        lookAt = function(...) return setmetatable({}, C) end }, {})
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
    # --- QUALITE DE RENDU : un emetteur plat (couleur unie, taille fixe, aucune retombee)
    # donne l'aspect « bloc de confettis » d'un prototype. Chaque emetteur doit porter une
    # courbe de taille, un fondu d'opacite, un degrade de couleur, de l'emission lumineuse,
    # une rotation et une acceleration (les debris retombent).
    emetteurs = list(g.TOUS["ParticleEmitter"].values()) if g.TOUS["ParticleEmitter"] else []
    for i, e in enumerate(emetteurs):
        taille = e.Size
        if taille is None or int(taille.points) < 3:
            echecs.append("emetteur %d : taille plate, pas de courbe d'expansion" % i)
        opac = e.Transparency
        if opac is None or int(opac.points) < 3:
            echecs.append("emetteur %d : aucun fondu d'opacite (apparition/disparition seche)" % i)
        coul = e.Color
        if coul is None or int(coul.points) < 2:
            echecs.append("emetteur %d : couleur unie, pas de degrade (coeur chaud)" % i)
        if (e.LightEmission or 0) <= 0:
            echecs.append("emetteur %d : aucune emission lumineuse" % i)
        if e.RotSpeed is None:
            echecs.append("emetteur %d : particules sans rotation" % i)
        acc = e.Acceleration
        if acc is None or acc.Y >= 0:
            echecs.append("emetteur %d : aucune retombee (Acceleration)" % i)

    # --- ONDE DE CHOC : la chute d'une tour et la victoire poussent un anneau qui s'etale.
    # 1 animation = seulement la pose de carte ; il en faut une par onde.
    if tweens < 3:
        echecs.append("pas d'onde de choc animee sur tour detruite / victoire (%d animation(s))" % tweens)

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

    # --- COUP ENCAISSE : flash blanc puis couleur d'origine, meme sur deux coups rapproches.
    if Effets.coup is None:
        echecs.append("Effets.coup absent : un coup encaisse ne se voit pas")
    else:
        bras = lua.eval('piece("VERT")')
        cache = lua.eval('piece("GRIS", 1)')
        corps = lua.eval('function(a, b) return piece("BLEU", 0, { a, b }) end')(bras, cache)
        Effets.coup(corps)
        Effets.coup(corps)  # 2e coup pendant le flash
        if bras.Color != "BLANC" or corps.Color != "BLANC":
            echecs.append("coup : la cible ne vire pas au blanc (%s)" % bras.Color)
        if cache.Color != "GRIS":
            echecs.append("coup : une piece invisible a ete touchee")
        lua.execute("for _, f in ipairs(DIFFERES) do f() end")
        if bras.Color != "VERT" or corps.Color != "BLEU":
            echecs.append("coup : couleur non restauree (%s / %s)" % (bras.Color, corps.Color))
        if "Effets.coup(" not in serveur:
            echecs.append("Effets.coup n'est appele nulle part dans GameServer")
    # --- POSE D'ANIMATION : la marche bouge, l'arret non, l'attaque avance, le coup recule.
    if Effets.posture is None:
        echecs.append("Effets.posture absent : les unites glissent")
    else:
        hauts = [Effets.posture(1, ph / 10.0, 99, 99)[0] for ph in range(0, 32)]
        if max(hauts) - min(hauts) < 0.2:
            echecs.append("pose : aucun rebond de marche (%.3f)" % (max(hauts) - min(hauts)))
        if any(abs(x) > 1e-9 for x in Effets.posture(0, 1.3, 99, 99)):
            echecs.append("pose : une unite a l'arret bouge encore")
        if Effets.posture(0, 0, 0.125, 99)[2] < 0.5:
            echecs.append("pose : pas d'elan a l'attaque")
        if Effets.posture(0, 0, 99, 0.0)[2] > -0.29:
            echecs.append("pose : pas de recul de 0,3 stud au coup")
        if "animer(e, dt)" not in serveur or "Effets.posture(" not in serveur:
            echecs.append("GameServer n'anime pas les unites")
    # --- PROJECTILE : part de a, arrive en b, parabole seulement pour les zones.
    if Effets.trajectoire is None or Effets.projectile is None:
        echecs.append("Effets.trajectoire/projectile absents : les tirs sont instantanes")
    else:
        a, b = V3.new(0, 0, 0), V3.new(10, 0, 0)
        d, m, f = (Effets.trajectoire(a, b, u, 4) for u in (0, 0.5, 1))
        if abs(d.X) > 1e-9 or abs(f.X - 10) > 1e-9 or abs(f.Y) > 1e-9:
            echecs.append("trajectoire : depart/arrivee faux")
        if abs(m.Y - 4) > 1e-9:
            echecs.append("trajectoire : sommet de cloche faux (%s)" % m.Y)
        if abs(Effets.trajectoire(a, b, 0.5, 0).Y) > 1e-9:
            echecs.append("trajectoire : un tir droit monte")
        avant = g.CREES["Trail"] or 0
        _, duree = Effets.projectile(arene, a, b, couleur, True)
        if not (0.15 <= duree <= 0.35):
            echecs.append("projectile : duree de vol hors 0,15-0,35 s (%s)" % duree)
        if (g.CREES["Trail"] or 0) <= avant:
            echecs.append("projectile : aucune trainee")
        if "Effets.projectile(" not in serveur:
            echecs.append("Effets.projectile n'est appele nulle part dans GameServer")

    if echecs:
        for e in echecs:
            print("ROUGE :", e)
        return 1
    print("VERT : coup, pose, projectile OK ; les 5 evenements produisent des effets, sans aucun identifiant d'asset.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
