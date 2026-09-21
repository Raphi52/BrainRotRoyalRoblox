"""La ligne d'effet de CHAQUE carte tient dans sa tuile de boutique, sans etre coupee.

La tuile (Hub.client.lua, Fiche.resume(card, 1, extrasDe(id))) n'a que DEUX lignes de texte en
taille 11, et coupe le reste (TextTruncate). Mesure du 2026-09-21 sur captures : 62 caracteres
tiennent (Glorbo, shop3.png), 76 debordaient (Glorbo, shop2.png). Limite retenue : 64.
Les extras sont reconstruits EXACTEMENT comme extrasDe du hub, avec les vrais modules."""
import pathlib, sys
from lupa import LuaRuntime

LIMITE = 64
SHARED = pathlib.Path("src/shared")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("math.clamp = math.clamp or function(x, a, b) return math.max(a, math.min(b, x)) end")
L.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
L.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")

sources = L.table_from({p.stem: p.read_text(encoding="utf-8") for p in SHARED.glob("*.lua")})
L.globals().SOURCES = sources
L.execute("""
local cache = {}
function require(nom)
  if cache[nom] == nil then cache[nom] = assert(load(SOURCES[nom], nom))() end
  return cache[nom]
end
local Shared = { WaitForChild = function(_, n) return n end, FindFirstChild = function(_, n) return n end }
local RS = { WaitForChild = function() return Shared end, FindFirstChild = function() return Shared end }
game = { GetService = function() return RS end }
""")
textes = L.execute("""
local Cards = require("Cards"); local Fiche = require("Fiche")
local noms = {}
for _, c in ipairs(Cards.list) do noms[c.id] = c.name end
local out = {}
for _, c in ipairs(Cards.list) do
  local id = c.id
  local R = require("Reperes")
  local ex = {
    specialite = require("Specialite").profil(id), soutien = require("Soutien").profil(id),
    descendance = require("Descendance").profil(id), recul = require("Recul").profil(id), noms = noms,
    rendementSort = require("Sorts").degatsParElixir(c),
    charge = require("Charge").profil(id),
    pointFort = R.texte(R.points(c, Cards.list)),
    assassin = require("Assassin").estAssassin(id) or nil,
    rentabilite = require("Batiments").texteRentabilite(c),
  }
  out[id] = Fiche.resume(c, 1, ex)
end
return out
""")
textes = dict(textes.items())
if len(textes) < 30:
    print('ROUGE : seulement %d cartes lues, le catalogue n a pas ete charge' % len(textes)); sys.exit(1)
for n, i, t in sorted(((len(t), i, t) for i, t in textes.items()), reverse=True)[:5]:
    print("  plus longue %-18s %3d  %s" % (i, n, t))
trop = sorted((len(t), i, t) for i, t in textes.items() if len(t) > LIMITE)
print("  %d cartes controlees, limite %d caracteres" % (len(textes), LIMITE))
for n, i, t in trop:
    print("  DEBORDE %-22s %3d  %s" % (i, n, t))
if trop:
    print("ROUGE : %d ligne(s) d'effet coupee(s) dans la tuile de boutique" % len(trop))
    sys.exit(1)
print("VERT : la ligne d'effet de chaque carte tient dans sa tuile de boutique")
