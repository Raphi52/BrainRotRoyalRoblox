# -*- coding: utf-8 -*-
"""Banc des ANIMATIONS d'unites (src/shared/Effets.lua), hors Studio.

Pourquoi il existe : `test_effets.py` prouve que chaque evenement fabrique des particules, mais
rien ne verifiait la POSE image par image. Une demarche fausse ne casse aucun test et ne se voit
qu'a l'ecran — c'est exactement le genre de defaut qui restait invisible.

Ce qu'il verifie, sur le VRAI module et le VRAI catalogue :
  1. chaque carte recoit un style de demarche connu (Effets.style) ;
  2. les cinq styles existent et ne donnent PAS la meme pose (sinon l'animation est decorative) ;
  3. un volant flotte meme a l'arret, un marcheur a l'arret ne bouge pas d'un stud ;
  4. l'arrivee du ciel part de haut et retombe EXACTEMENT a zero (aucune derive de position) ;
  5. l'agonie replace puis detruit le corps, sans le laisser dans l'arene.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Effets.lua"
CARDS = ROOT / "src" / "shared" / "Cards.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

# Doubles Lua : lupa n'a aucune API Roblox. On enregistre ce qui est fait au lieu de le dessiner.
PRELUDE = r"""
DETRUITS = 0
HORLOGE = 0
local function noter() end
Instance = { new = function(cls) return { ClassName = cls } end }
local Debris = { AddItem = function(_, _i, _t) end }
local services = { Debris = Debris, TweenService = { Create = function() return { Play = function() end } end },
                   RunService = { Heartbeat = { Wait = function() HORLOGE = HORLOGE + 0.05 end } } }
game = { GetService = function(_, n) return services[n] end }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function(_, k) return k end }) end })
ColorSequence = { new = function(c) return c end }
NumberSequence = { new = function(n) return n end }
NumberRange = { new = function(a, b) return { a, b } end }
TweenInfo = { new = function(...) return { ... } end }
Color3 = { new = function() return "BLANC" end, fromRGB = function(r, g, b) return { r, g, b } end }
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
os = { clock = function() return HORLOGE end }
FILS = {}
task = { delay = function(_, f) table.insert(FILS, f) end, spawn = function(f) table.insert(FILS, f) end }
local V = {}
V.__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end return V[k] end
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
-- corps factice : compte les replacements et sa destruction
function corps()
  local o = { Transparency = 0, CFrame = setmetatable({}, C), Parent = "arene", poses = 0 }
  o.IsA = function(_, c) return c == "BasePart" end
  o.GetDescendants = function() return {} end
  o.Destroy = function(self) self.Parent = nil; DETRUITS = DETRUITS + 1 end
  return setmetatable({}, {
    __index = o,
    __newindex = function(_, k, v) if k == "CFrame" then o.poses = o.poses + 1 end; o[k] = v end,
  })
end
"""

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ECHEC ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def charger(lua, chemin):
    return lua.execute("return (function() " + chemin.read_text(encoding="utf-8") + " end)()")


def main():
    for f in (SRC, CARDS, SERVEUR):
        if not f.exists():
            print("ROUGE : %s absent" % f)
            return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(PRELUDE)
    Effets = charger(lua, SRC)
    Cards = charger(lua, CARDS)

    # 1. chaque carte a un style connu
    styles = {}
    inconnus = []
    for i in range(1, len(Cards.list) + 1):
        c = Cards.list[i]
        st = Effets.style(c)
        styles.setdefault(st, []).append(c.name)
        if Effets.STYLES[st] is None:
            inconnus.append(c.name)
    print("  styles utilises : " + ", ".join("%s x%d" % (k, len(v)) for k, v in sorted(styles.items())))
    cas("chaque carte a un style connu", [], inconnus)
    cas("au moins 4 demarches differentes en jeu", True, len(styles) >= 4)

    # 2. les styles produisent des poses REELLEMENT differentes (marche pleine, meme phase)
    poses = {}
    for st in ("marche", "vol", "bond", "lourd", "tir"):
        poses[st] = tuple(round(x, 4) for x in Effets.posture(1, 0.9, 99, 99, st))
    cas("5 poses distinctes entre styles", 5, len(set(poses.values())))

    # 3. volant a l'arret = flotte ; marcheur a l'arret = immobile
    vol_arret = [abs(x) for x in Effets.posture(0, 1.3, 99, 99, "vol")]
    cas("un volant plane encore a l'arret", True, max(vol_arret) > 0.05)
    cas("un marcheur a l'arret ne bouge pas", True, max(abs(x) for x in Effets.posture(0, 1.3, 99, 99, "marche")) < 1e-9)

    # 3 bis. un tireur RECULE quand il tire, un melee AVANCE
    avant_tir = Effets.posture(0, 0, 0.125, 99, "tir")[2]
    avant_melee = Effets.posture(0, 0, 0.125, 99, "marche")[2]
    cas("le tireur recule au tir", True, avant_tir < 0)
    cas("le melee se jette en avant", True, avant_melee > 0.5)

    # 4. arrivee du ciel : part haut, finit EXACTEMENT a zero
    h0 = Effets.apparition(0)[0]
    cas("l'unite arrive de haut", True, h0 > 5)
    cas("aucune derive apres l'arrivee", (0, 0), tuple(Effets.apparition(Effets.APPARITION_DUREE)))
    cas("aucune derive bien plus tard", (0, 0), tuple(Effets.apparition(30)))
    milieu = [Effets.apparition(Effets.APPARITION_DUREE * k / 20.0)[0] for k in range(21)]
    cas("la chute est monotone jusqu'au sol", True, all(milieu[k] >= milieu[k + 1] - 1e-9 for k in range(10)))

    # 5. agonie : le corps est replace puis detruit, il ne reste pas dans l'arene
    g = lua.globals()
    g.HORLOGE = 0
    g.DETRUITS = 0
    c = lua.eval("corps()")
    Effets.agonie(c, 0.2)
    fils = g.FILS
    for i in range(1, len(fils) + 1):
        fils[i]()
    cas("le corps abattu est bien retire", 1, int(g.DETRUITS))
    cas("le corps abattu s'efface completement", 1.0, round(float(c.Transparency), 3))

    # 6. branchement reel cote serveur : sans appel, tout ceci resterait mort-ne
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur choisit un style par carte", True, "Effets.style(card)" in serveur)
    cas("le serveur joue l'arrivee", True, "Effets.apparition(" in serveur)
    cas("le serveur joue l'agonie", True, "Effets.agonie(" in serveur)
    cas("le serveur passe le style a la pose", True, "e.style)" in serveur)

    # 7. SYNCHRO DU SON DE MORT. Le client joue le son et secoue la camera sur la DISPARITION de la
    # part dans l'arene (GameClient, ChildRemoved). Si le corps restait dans l'arene le temps de son
    # agonie, le son arriverait 0,45 s apres l'explosion : le corps doit en SORTIR d'abord.
    client = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
    cas("le client entend la mort sur la sortie de l'arene", True, "ChildRemoved" in client)
    sortie = serveur.find("target.part.Parent = dossierRestes()")
    agonie = serveur.find("Effets.agonie(target.part)")
    cas("le corps quitte l'arene AVANT de commencer son agonie", True, 0 < sortie < agonie)
    cas("les restes sont vides a chaque nouvelle partie", True, "restes:Destroy()" in serveur)
    cas("l'etiquette part avec le mort", True, "target.etiquette:Destroy()" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : chaque carte a sa demarche, l'arrivee ne derive pas, les corps abattus disparaissent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
