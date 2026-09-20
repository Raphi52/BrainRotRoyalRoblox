# -*- coding: utf-8 -*-
"""Banc des CHIFFRES DE DEGATS FLOTTANTS (src/shared/Effets.lua), hors Studio.

Pourquoi : rien ne disait COMBIEN un coup enlevait. Le joueur voyait une barre descendre sans
savoir si son unite faisait mal ou rien du tout. C'est le retour le plus direct qui manquait en
combat — et il ne se verifie par aucun autre banc, puisqu'il ne change aucune regle.

Ce qu'il verifie :
  1. la taille du chiffre grandit avec le coup, mais reste BORNEE (un sort a 340 n'ecrase pas
     l'ecran) et ne descend jamais sous la taille minimale ;
  2. un coup a 0 (ou negatif) n'affiche RIEN ;
  3. le chiffre affiche le montant arrondi, precede du signe moins, a la couleur demandee ;
  4. il monte et s'efface (deux animations), puis il est NETTOYE — aucun reste dans l'arene ;
  5. le limiteur tient le nombre de chiffres par seconde, et repart a la seconde suivante ;
  6. le serveur de jeu l'appelle VRAIMENT a chaque degat, en le plafonnant.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Effets.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

PRELUDE = r"""
CREES = {}
DEBRIS = 0
TWEENS = {}
local function noter(cls) CREES[cls] = (CREES[cls] or 0) + 1 end
Instance = { new = function(cls)
  noter(cls)
  local o = { ClassName = cls }
  o.Emit = function(_, n) end
  return o
end }
local TweenService = { Create = function(_, inst, _info, props)
  table.insert(TWEENS, { cible = inst, props = props })
  return { Play = function() end }
end }
local Debris = { AddItem = function(_, _i, t) DEBRIS = DEBRIS + 1; DERNIER_DELAI = t end }
local services = { Debris = Debris, TweenService = TweenService, RunService = { Heartbeat = { Wait = function() end } } }
game = { GetService = function(_, n) return services[n] end }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
ColorSequence = { new = function(c) return c end }
NumberSequence = { new = function(n) return n end }
NumberRange = { new = function(a, b) return { a, b } end }
TweenInfo = { new = function(...) return { ... } end }
UDim2 = { new = function(...) return { ... } end }
Color3 = { new = function(r, g, b) return "rgb(" .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. ")" end,
           fromRGB = function(r, g, b) return "RGB" .. r .. "-" .. g .. "-" .. b end }
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
os = { clock = function() return 0 end }
task = { delay = function(_, f) end, spawn = function(f) end }
local V = {}
V.__index = V
V.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, k) return Vector3.new(a.X * k, a.Y * k, a.Z * k) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local C = {}
C.__index = C
C.__mul = function(a, _b) return a end
CFrame = setmetatable({ new = function(...) return setmetatable({}, C) end,
                        Angles = function(...) return setmetatable({}, C) end,
                        lookAt = function(...) return setmetatable({}, C) end }, {})
"""

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    E = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    g = lua.globals()

    if E.chiffreDegats is None:
        print("ROUGE : Effets.chiffreDegats absent — aucun chiffre de degats")
        return 1

    # 1. taille selon le montant
    tmin, tmax = int(E.DEGATS_TAILLE_MIN), int(E.DEGATS_TAILLE_MAX)
    cas("un coup a 0 garde la taille minimale", tmin, int(E.tailleChiffre(0)))
    cas("un gros coup atteint la taille maximale", tmax, int(E.tailleChiffre(E.DEGATS_PLAFOND)))
    cas("au-dela du plafond, ca ne grossit plus", tmax, int(E.tailleChiffre(9999)))
    milieu = int(E.tailleChiffre(int(E.DEGATS_PLAFOND) / 2))
    cas("un coup moyen est entre les deux", True, tmin < milieu < tmax)
    croissant = [int(E.tailleChiffre(m)) for m in (10, 50, 100, 200, 250)]
    cas("la taille ne decroit jamais", True, all(croissant[i] <= croissant[i + 1] for i in range(4)))

    # 2. un coup nul n'affiche rien
    arene = lua.eval("{}")
    blanc = lua.eval('Color3.fromRGB(255,255,255)')
    cas("un coup a 0 n'affiche rien", None, E.chiffreDegats(arene, lua.eval("Vector3.new(0,0,0)"), 0, blanc))
    cas("un coup negatif n'affiche rien", None, E.chiffreDegats(arene, lua.eval("Vector3.new(0,0,0)"), -5, blanc))
    cas("rien n'a ete cree pour autant", None, g.CREES["TextLabel"])

    # 3. le chiffre affiche le bon texte
    hote = E.chiffreDegats(arene, lua.eval("Vector3.new(1,0,2)"), 95.4, blanc)
    cas("le chiffre existe", True, hote is not None)
    cas("une etiquette 3D est creee", 1, int(g.CREES["BillboardGui"]))
    cas("un texte est creee", 1, int(g.CREES["TextLabel"]))
    tweens = g.TWEENS
    textes = [tweens[i].cible for i in range(1, len(tweens) + 1) if tweens[i].cible.Text is not None]
    cas("le texte porte le montant arrondi", "-95", textes[0].Text if textes else None)
    cas("le texte porte la couleur demandee", str(blanc), str(textes[0].TextColor3) if textes else None)
    cas("la taille suit le montant", int(E.tailleChiffre(95)), int(textes[0].TextSize) if textes else None)

    # 4. animations + nettoyage
    cas("deux animations lancees (montee + fondu)", 2, len(tweens))
    monte = [tweens[i] for i in range(1, len(tweens) + 1) if tweens[i].props.Position is not None]
    cas("le chiffre monte", True, len(monte) == 1 and float(monte[0].props.Position.Y) > float(hote.Position.Y))
    cas("le chiffre s'efface", True, any(tweens[i].props.TextTransparency == 1 for i in range(1, len(tweens) + 1)))
    cas("le chiffre est nettoye", 1, int(g.DEBRIS))
    cas("nettoye apres la fin de l'animation", True, float(g.DERNIER_DELAI) > float(E.DEGATS_DUREE))

    # 5. limiteur
    limiteur = E.limiteurChiffres(3)
    acceptes = sum(1 for _ in range(10) if limiteur(100.0))
    cas("le limiteur tient sa cadence", 3, acceptes)
    cas("la seconde suivante repart", True, bool(limiteur(101.0)))
    cas("et se referme aussitot", 2, sum(1 for _ in range(10) if limiteur(101.0)))

    # 6. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur affiche un chiffre a chaque degat", True, "Effets.chiffreDegats(" in serveur)
    cas("le serveur plafonne les chiffres", True, "Effets.limiteurChiffres(" in serveur)
    cas("le chiffre est pose dans la fonction de degats", True,
        "Effets.chiffreDegats(" in serveur.split("local function damage(")[1].split("local function attack(")[0])

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : chaque coup affiche ce qu'il enleve, sans noyer l'ecran")
    return 0


if __name__ == "__main__":
    sys.exit(main())
