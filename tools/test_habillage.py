# -*- coding: utf-8 -*-
"""HABILLAGE DU MENU (src/shared/Habillage.lua) : donnees pures, dessin et branchement dans le hub.

Ce qui est verifie, et pourquoi :
  1. La barre d'onglets tient EXACTEMENT dans l'ecran quel que soit l'onglet actif (somme = 1) :
     une somme de 1,02 fait deborder le dernier onglet, 0,98 laisse un trou a droite.
  2. La levre des boutons commence SOUS le texte au repos : sinon la bande sombre coupe les
     lettres de tous les boutons du menu.
  3. Chaque onglet du hub a son icone, et chaque forme reste DANS le carre de l'icone une fois
     tournee : l'icone est dessinee dans un CanvasGroup, qui rogne tout ce qui depasse.
  4. Le defilement des soldes finit EXACTEMENT sur la valeur du serveur.
  5. Les fonctions qui construisent l'ecran s'executent sans erreur dans un faux Roblox minimal :
     Studio n'est pas toujours disponible, et une faute de frappe y figeait tout le menu.
  6. Le hub appelle le module aux bons endroits, SANS nouvelle variable locale (plafond de 200).
"""
import math, re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
SRC = (R / "src/shared/Habillage.lua").read_text(encoding="utf-8")
HUB = (R / "src/client/Hub.client.lua").read_text(encoding="utf-8")
BUILD = (R / "build.py").read_text(encoding="utf-8")
e = []

def cas(nom, attendu, obtenu):
    if attendu != obtenu:
        e.append(f"{nom} : attendu {attendu!r}, obtenu {obtenu!r}")

L = LuaRuntime(unpack_returned_tuples=True)
H = L.execute(SRC)  # charge SANS Roblox : le haut du fichier doit rester pur

# 1. LARGEURS ------------------------------------------------------------------------------------
noms = re.findall(r'nom = "(\w+)"', re.search(r"local ONGLETS = \{(.*?)\n\}", HUB, re.S).group(1))
n = len(noms)
for i in range(1, n + 1):
    t = H.largeurs(n, i)
    ls = [t[k] for k in range(1, n + 1)]
    if abs(sum(ls) - 1) > 1e-9:
        e.append(f"largeurs : somme {sum(ls)} pour l'onglet actif {i}")
    cas(f"l'onglet actif {i} est le plus large", i - 1, ls.index(max(ls)))
cas("onglet actif a 0,28", 0.28, H.LARGEUR_ACTIF)

# 2. LEVRE ---------------------------------------------------------------------------------------
lev = [(H.LEVRE[k][1], H.LEVRE[k][2]) for k in range(1, len(H.LEVRE) + 1)]
cas("la levre part du haut", 0.0, lev[0][0])
cas("la levre finit en bas", 1.0, lev[-1][0])
if any(b[0] <= a[0] for a, b in zip(lev, lev[1:])):
    e.append("levre : positions non strictement croissantes (ColorSequence les refuserait)")
if not all(0 <= g <= 1 for _, g in lev):
    e.append("levre : facteur de gris hors de 0-1")
saut = max((a[1] - b[1], b[0]) for a, b in zip(lev, lev[1:]))
if saut[0] < 0.15:
    e.append(f"levre : aucun saut net ({saut[0]:.2f}) — le bouton reste plat")
bas_texte = 1 - H.MARGE_REPOS[2]
if saut[1] < bas_texte:
    e.append(f"levre : commence a {saut[1]} AU-DESSUS du bas du texte ({bas_texte:.2f}) : elle coupe les lettres")
if not (H.MARGE_APPUI[1] > H.MARGE_REPOS[1] and H.MARGE_APPUI[2] < H.MARGE_REPOS[2]):
    e.append("appui : le texte ne descend pas")

# 3. ICONES --------------------------------------------------------------------------------------
TEINTES = {"base", "clair", "sombre", "blanc", "or"}
for nom in noms:
    formes = H.ICONES[nom]
    if formes is None:
        e.append(f"icone : l'onglet « {nom} » n'a pas d'icone")
        continue
    k = len(formes)
    if k < 2:
        e.append(f"icone {nom} : {k} forme(s), trop pauvre pour se reconnaitre")
    for j in range(1, k + 1):
        f = formes[j]
        if f.teinte not in TEINTES:
            e.append(f"icone {nom} forme {j} : teinte inconnue {f.teinte!r}")
        a = math.radians(f.rot)
        # boite englobante de la forme tournee, contour sombre compris (2 px sur ~50 px d'icone)
        demi_l = (abs(f.l * math.cos(a)) + abs(f.h * math.sin(a))) / 2 + 0.04
        demi_h = (abs(f.l * math.sin(a)) + abs(f.h * math.cos(a))) / 2 + 0.04
        if f.anneau:
            demi_l += 0.06; demi_h += 0.06
        if f.x - demi_l < -1e-9 or f.x + demi_l > 1 + 1e-9 or f.y - demi_h < -1e-9 or f.y + demi_h > 1 + 1e-9:
            e.append(f"icone {nom} forme {j} : depasse du carre (rognee par le CanvasGroup)")
# les epees se croisent au centre horizontal
b = H.ICONES["bataille"]
cas("epees symetriques", round(b[3].x + b[4].x, 3), 1.0)

# 4. DEFILEMENT ----------------------------------------------------------------------------------
for avant, apres in ((100, 600), (600, 100), (0, 1), (1500, 1500)):
    cas(f"defilement {avant}->{apres} finit juste", apres, H.intermediaire(avant, apres, 1))
    cas(f"defilement {avant}->{apres} part juste", avant, H.intermediaire(avant, apres, 0))
    cas(f"defilement {avant}->{apres} depasse la fin", apres, H.intermediaire(avant, apres, 1.7))
    vals = [H.intermediaire(avant, apres, k / 20) for k in range(21)]
    if any(int(v) != v for v in vals):
        e.append(f"defilement {avant}->{apres} : valeur non entiere")
    sens = 1 if apres >= avant else -1
    if any((b2 - a2) * sens < 0 for a2, b2 in zip(vals, vals[1:])):
        e.append(f"defilement {avant}->{apres} : recule en chemin")

# 5. FAUX ROBLOX : les fonctions de construction s'executent ------------------------------------
FAUX = r'''
local M = {}
local creees = {}
local function signal() local s = {f = {}}; function s:Connect(fn) table.insert(self.f, fn); return {} end; return s end
local Obj = {}
Obj.__index = function(o, k)
  local m = rawget(Obj, k); if m then return m end
  local p = rawget(o, "_p")
  if p[k] ~= nil then return p[k] end
  if k:match("^Mouse") or k:match("^Activated") then p[k] = signal(); return p[k] end
  return nil
end
Obj.__newindex = function(o, k, v)
  local p = rawget(o, "_p")
  if k == "Parent" then
    local ancien = p.Parent
    if ancien then for i, c in ipairs(rawget(ancien, "_c")) do if c == o then table.remove(rawget(ancien, "_c"), i) break end end end
    if v then table.insert(rawget(v, "_c"), o) end
  end
  p[k] = v
end
function Obj:GetChildren() local t = {}; for i, c in ipairs(rawget(self, "_c")) do t[i] = c end; return t end
function Obj:IsA(c) return rawget(self, "_p").ClassName == c end
function Obj:Destroy() self.Parent = nil end
function Obj:GetAttribute(k) return rawget(self, "_a")[k] end
function Obj:SetAttribute(k, v) rawget(self, "_a")[k] = v end
function Obj:FindFirstChildOfClass(c) for _, x in ipairs(rawget(self, "_c")) do if x:IsA(c) then return x end end end
local function nouveau(classe)
  local o = setmetatable({_p = {ClassName = classe, ZIndex = 1, Size = nil, Visible = true}, _c = {}, _a = {}}, Obj)
  table.insert(creees, o)
  return o
end
Instance = {new = nouveau}
local U = {}
U.__add = function(a, b) return setmetatable({a[1]+b[1], a[2]+b[2], a[3]+b[3], a[4]+b[4]}, U) end
U.__sub = function(a, b) return setmetatable({a[1]-b[1], a[2]-b[2], a[3]-b[3], a[4]-b[4]}, U) end
UDim2 = {
  new = function(a, b, c, d) return setmetatable({a or 0, b or 0, c or 0, d or 0}, U) end,
  fromScale = function(a, c) return setmetatable({a, 0, c, 0}, U) end,
  fromOffset = function(b, d) return setmetatable({0, b, 0, d}, U) end,
}
UDim = {new = function(s, o) return {s, o} end}
Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local function c3(r, g, b) return {R = r, G = g, B = b} end
Color3 = {new = c3, fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end}
ColorSequenceKeypoint = {new = function(t, c) assert(t >= 0 and t <= 1); return {t, c} end}
ColorSequence = {new = function(p) assert(#p >= 2 and #p <= 20); return p end}
NumberSequenceKeypoint = {new = function(t, v) return {t, v} end}
NumberSequence = {new = function(p) return p end}
TweenInfo = {new = function(...) return {...} end}
local enum = {}; enum.__index = function(t, k) local v = setmetatable({}, enum); rawset(t, k, v); return v end
Enum = setmetatable({}, enum)
M.tweens = 0
game = {GetService = function(_, n)
  assert(n == "TweenService", n)
  return {Create = function(_, objet, info, props)
    assert(type(props) == "table")
    for k, v in pairs(props) do objet[k] = v end   -- la cible est posee d'un coup
    M.tweens = M.tweens + 1
    return {Play = function() end}
  end}
end}
M.taches = {}
-- horloge simulee : 1/60 s par pas, comme une image de jeu (le defilement lit os.clock)
M.t = 0
os.clock = function() return M.t end
task = {
  spawn = function(fn) local co = coroutine.create(fn); table.insert(M.taches, co); local ok, err = coroutine.resume(co); assert(ok, err) end,
  wait = function() coroutine.yield() end,
}
M.nouveau = nouveau
M.creees = creees
function M.avancer(n)
  for _ = 1, n do
    M.t = M.t + 1 / 60
    for _, co in ipairs(M.taches) do
      if coroutine.status(co) == "suspended" then local ok, err = coroutine.resume(co); assert(ok, err) end
    end
  end
end
return M
'''
try:
    F = L.execute(FAUX)
    # levre sur un bouton avec sa marge
    b = F.nouveau("TextButton"); pad = F.nouveau("UIPadding"); pad.Parent = b
    H.levre(b, pad)
    for fn in list(b.MouseButton1Down.f.values()):
        fn()
    cas("appui : le texte descend", H.MARGE_APPUI[1], pad.PaddingTop[1])
    for fn in list(b.MouseButton1Up.f.values()):
        fn()
    cas("relache : le texte remonte", H.MARGE_REPOS[1], pad.PaddingTop[1])
    # onglets : equiper puis basculer
    barre = F.nouveau("Frame")
    ongs = []
    for i, nom in enumerate(noms):
        ob = F.nouveau("TextButton"); ob.Parent = barre; ob.ZIndex = 6; ob.Text = nom.upper()
        for c in ("UIPadding", "UIPadding", "UITextSizeConstraint", "UIStroke"):
            x = F.nouveau(c); x.Parent = ob
        o = L.table_from({"nom": nom, "titre": nom.upper(), "bouton": ob, "teinte": L.eval("Color3.fromRGB(60, 170, 80)")})
        H.equiperOnglet(o)
        ongs.append(o)
    for o in ongs:
        restes = [c.ClassName for c in o.bouton.GetChildren(o.bouton).values()]
        cas(f"onglet {o.nom} : plus de marge interne", 0, restes.count("UIPadding"))
        cas(f"onglet {o.nom} : le titre quitte le bouton", "", o.bouton.Text)
        cas(f"onglet {o.nom} : son nom est gardé", o.titre, o.etiquette.Text)
    larg = H.largeurs(n, 3)
    for i, o in enumerate(ongs, 1):
        H.majOnglet(o, i == 3, larg[i], True)
    cas("seul l'onglet actif montre son nom", [False, False, True, False, False][:n], [o.etiquette.Visible for o in ongs])
    cas("l'icone active monte", H.POSE.actif.y, ongs[2].icone.Position[3])
    for i, o in enumerate(ongs, 1):
        H.majOnglet(o, i == 1, H.largeurs(n, 1)[i], False)
    cas("apres bascule, l'onglet 1 est large", H.LARGEUR_ACTIF, ongs[0].bouton.Size[1])
    # icone : deux passes (silhouette + couleur) pour chaque forme
    g = H.icone(F.nouveau("Frame"), "clan", L.eval("Color3.fromRGB(40, 150, 170)"))
    cas("icone clan : deux passes", 2 * len(H.ICONES["clan"]), len(g.GetChildren(g)))
    ob6 = ongs[3].bouton
    zs = [c.ZIndex for c in ongs[3].icone.GetChildren(ongs[3].icone).values()]
    if min(zs) <= ob6.ZIndex:
        e.append(f"icone : formes a ZIndex {min(zs)}, sous le fond de l'onglet ({ob6.ZIndex}) en mode Global")
    if ongs[3].etiquette.ZIndex <= max(zs):
        e.append("icone : le nom de l'onglet passe sous l'icone")
    # glisser, vivant, compter, plus
    cadre = F.nouveau("Frame"); cible = L.eval("UDim2.new(0, 0, 0.085, 0)")
    H.glisser(cadre, cible, 1)
    cas("l'ecran finit a sa place", [0, 0, 0.085, 0], [cadre.Position[k] for k in range(1, 5)])
    jouerB = F.nouveau("TextButton"); jouerB.Parent = F.nouveau("Frame"); jouerB.ZIndex = 1
    H.vivant(jouerB)
    F.avancer(2)
    lab = F.nouveau("TextLabel"); lab.ZIndex = 10
    lab.Text = "100"; H.compter(lab, 100)
    cas("premier affichage : aucun defilement", "100", lab.Text)
    lab.Text = "600"; H.compter(lab, 600)
    F.avancer(400)
    cas("le solde affiche finit sur le serveur", "600", lab.Text)
    pil = F.nouveau("Frame"); v1 = F.nouveau("TextLabel"); v1.Parent = pil; v1.ZIndex = 10
    v1.Size = L.eval("UDim2.new(1, -46, 1, -8)")
    clics = []
    H.plus(L.table_from([v1]), lambda *a: clics.append(1))
    plus = [c for c in pil.GetChildren(pil).values() if c.Name == "Plus"]
    cas("un « + » par jeton", 1, len(plus))
    cas("la valeur se resserre", -72, v1.Size[2])
    if plus:
        for fn in list(plus[0].MouseButton1Click.f.values()):
            fn()
    cas("le « + » repond au clic", 1, len(clics))
except Exception as ex:  # une erreur Lua ici = une erreur dans Studio
    e.append(f"faux Roblox : {ex}")

# 6. BRANCHEMENT DANS LE HUB ---------------------------------------------------------------------
req = 'require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habillage"))'
for appel in (".levre(b, pad)", ".vivant(boutonJouer)", ".equiperOnglet(o)", ".plus({ valPieces, valGemmes }"):
    if req + appel not in HUB:
        e.append(f"hub : appel {appel} absent")
for appel in ("H.largeurs(#ONGLETS", "H.majOnglet(o, actif", "H.glisser(o.cadre", "H.compter(valPieces", "H.compter(valGemmes", "H.compter(valTrophees"):
    if appel not in HUB:
        e.append(f"hub : {appel} absent")
if re.search(r"^local\s+(Habillage|H)\b", HUB, re.M):
    e.append("hub : nouvelle variable locale de premier niveau (plafond de 200)")
if "degrade(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))" in HUB:
    e.append("hub : l'ancien degrade lisse double la levre")
if '"Habillage", source=src("shared/Habillage.lua")' not in BUILD:
    e.append("build.py : le module n'est pas dans la place (le hub attendrait pour toujours)")

for x in e:
    print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
