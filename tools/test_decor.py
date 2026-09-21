# -*- coding: utf-8 -*-
"""ARENE QUI VARIE (src/shared/Decor.lua + branchement).

Le defaut corrige : tous les duels se jouaient sur le MEME terrain, meme decor, meme lumiere,
memes arbres aux memes endroits. Au bout de dix parties, on ne voit plus l'arene.

LA CONTRAINTE, ET C'EST ELLE QUE CE BANC DEFEND : le decor change, JAMAIS la geometrie. Une arene
dont les dimensions, les ponts ou les tours bougeraient d'un duel a l'autre serait injouable — les
reperes de pose et la portee des tours font partie des regles.

1) Les regles PURES sont EXECUTEES (lupa) : neutralite des themes, choix deterministe, non-repetition.
2) Le branchement est lu : le serveur applique les COULEURS du theme, et sa geometrie reste ecrite
   en dur (HALF_W / HALF_L / BRIDGES), hors de portee du decor.
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
DE = (R / "src/shared/Decor.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(DE)
themes = [M.THEMES[i] for i in range(1, len(M.THEMES) + 1)]

# --- LE DECOR NE TOUCHE PAS AUX REGLES ----------------------------------------------------------
INTERDITS = ("largeur", "longueur", "pont", "bridge", "taille", "size", "position", "portee",
             "vitesse", "pv", "degats", "elixir", "half", "voie", "tour")
def neutre(t):
    # lupa ne rend que la PREMIERE valeur d'un retour multiple : on passe par une table.
    r = lua.eval("function(m, t) local ok, cle = m.neutre(t) return { ok = ok, cle = cle } end")(M, t)
    return r.ok, r.cle

for t in themes:
    ok, fautive = neutre(t)
    if ok is not True:
        e.append(f"theme {t.id} : cle « {fautive} » hors de l'apparence — le decor toucherait aux regles")
    for cle in t:
        if any(mot in str(cle).lower() for mot in INTERDITS):
            e.append(f"theme {t.id} : la cle « {cle} » ressemble a de la GEOMETRIE, pas a de l'apparence")
# Un theme invente avec une cle de regle doit etre REFUSE par le module lui-meme.
faux = lua.eval("function() return { id = 'x', nom = 'X', largeurPont = 9 } end")()
if neutre(faux)[0] is not False:
    e.append("le module doit refuser un theme qui porte une cle de geometrie")

# --- ASSEZ DE VARIETE, ET DES THEMES DISTINCTS --------------------------------------------------
if M.nombre() < 3:
    e.append("moins de trois decors : la variation ne se verrait pas")
ids = [t.id for t in themes]
if len(set(ids)) != len(ids):
    e.append("deux themes portent le meme identifiant")
noms = [t.nom for t in themes]
if len(set(noms)) != len(noms):
    e.append("deux themes portent le meme nom affiche")
for t in themes:
    if not (0 <= t.heure <= 24):
        e.append(f"theme {t.id} : heure hors de la journee")
    if not (0 <= t.brume <= 1):
        e.append(f"theme {t.id} : densite de brume absurde")
    # fix-ok mesure a l'ecran : une brume trop dense, ou d'une couleur qui ne suit pas le theme,
    # NOIE la scene entiere (« Terres brulees » sortait bleu ciel).
    if t.brume > M.BRUME_MAX:
        e.append(f"theme {t.id} : brume a {t.brume} — au-dela de {M.BRUME_MAX}, la scene est noyee")
    for cle in ("herbeProche", "eau", "pierre", "bois", "feuillage", "rocher", "brumeCouleur", "brumeFond"):
        c = t[cle]
        if c is None or len(c) != 3:
            e.append(f"theme {t.id} : couleur {cle} incomplete")
        else:
            for i in range(1, 4):
                if not (0 <= c[i] <= 255):
                    e.append(f"theme {t.id} : composante hors bornes dans {cle}")
# Deux themes ne doivent pas avoir exactement la meme herbe : ce serait la meme arene.
brumes = [tuple(t.brumeCouleur.values()) for t in themes]
if len(set(brumes)) < 3:
    e.append("les brumes se ressemblent trop d'un theme a l'autre : c'est elle qui donne l'ambiance")
herbes = [tuple(t.herbeProche.values()) for t in themes]
if len(set(herbes)) != len(herbes):
    e.append("deux themes partagent la meme couleur de sol : la variation serait invisible")

# --- CHOIX DETERMINISTE : LES DEUX JOUEURS VOIENT LA MEME ARENE ---------------------------------
if M.choisir(7).id != M.choisir(7).id:
    e.append("le choix doit etre DETERMINISTE (sinon chaque client verrait une arene differente)")
vus = {M.choisir(g).id for g in range(0, M.nombre() * 3)}
if len(vus) != M.nombre():
    e.append("toutes les arenes doivent pouvoir sortir")
if M.choisir(None) is None or M.choisir(-5) is None or M.choisir("abc") is None:
    e.append("une graine absurde ne doit pas casser le choix")

# --- JAMAIS DEUX FOIS DE SUITE LE MEME DECOR ----------------------------------------------------
for precedent in ids:
    g = M.graineSuivante(3, precedent)
    if M.choisir(g).id == precedent:
        e.append(f"apres « {precedent} », le duel suivant doit changer de decor")
if M.choisir(M.graineSuivante(3, None)).id is None:
    e.append("sans decor precedent, le choix doit quand meme aboutir")

# --- BRANCHEMENT SERVEUR : COULEURS OUI, GEOMETRIE NON ------------------------------------------
if 'item("ModuleScript", "Decor"' not in B:
    e.append("build : Decor non embarque")
if 'WaitForChild("Decor")' not in S:
    e.append("serveur : module Decor non requis")
if "themeArene = Decor.choisir(grainesDecor)" not in S:
    e.append("serveur : le theme n'est pas tire par partie")
if "Decor.graineSuivante(grainesDecor" not in S:
    e.append("serveur : deux duels de suite pourraient partager le meme decor")
for attendu in ("c3(themeArene.herbeProche)", "c3(themeArene.eau)", "c3(themeArene.bois)",
                "themeArene.heure", "themeArene.brume",
                # la COULEUR de la brume doit suivre le theme : ecrite en dur, elle repeignait tout
                "c3(themeArene.brumeCouleur)", "c3(themeArene.brumeFond)",
                "math.min(themeArene.brume, Decor.BRUME_MAX)"):
    if attendu not in S:
        e.append("serveur : le theme n'est pas applique -> " + attendu)
# LA GEOMETRIE RESTE EN DUR : aucune dimension ne doit venir du theme.
arene = S.split("local function buildArena")[1].split("local function makeHealthBar")[0]
if re.search(r"Size = Vector3\.new\([^)]*themeArene", arene) or re.search(r"Position = Vector3\.new\([^)]*themeArene", arene):
    e.append("LE DECOR CHANGE LA GEOMETRIE : dimensions ou positions tirees du theme")
for repere in ("HALF_W * 2", "HALF_L", "BRIDGES"):
    if repere not in arene:
        e.append(f"serveur : l'arene ne se construit plus sur {repere} (geometrie devenue variable ?)")
if "decor = themeArene.nom" not in S:
    e.append("serveur : le nom du decor n'est pas envoye (la variation passerait inapercue)")
if "s.decor" not in C:
    e.append("client : le nom du decor n'est pas affiche")

for x in e:
    print("ROUGE " + x)
print(f"{len(e)} echec(s)" if e else "VERT : l'arene change d'allure a chaque duel, et pas d'un centimetre de geometrie")
sys.exit(1 if e else 0)
