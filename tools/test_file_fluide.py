# -*- coding: utf-8 -*-
"""FILE PVP FLUIDE (src/server/Matchmaking.lua) — trois defauts corriges le 2026-09-21.

1) FILE BLOQUEE : seul le plus ancien de toute la file pouvait former un match. Un joueur isole
   (3000 trophees) bloquait tous les duels derriere lui, jusqu'a 3 minutes en mode patient.
2) JOUEUR PATIENT INVISIBLE : l'entree expirait a 60 s sans jamais etre renouvelee, alors que
   l'attente patiente dure 180 s.
3) FILE TRONQUEE : 20 entrees lues dans l'ordre des IDENTIFIANTS ; au-dela, des joueurs n'etaient
   jamais vus. Et une paire pouvait se former pendant qu'un troisieme serveur prenait le meneur.

Regles PURES executees (lupa) + branchement lu par contenu.
"""
import sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
MM = (R / "src/server/Matchmaking.lua").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(MM)
L = lua.eval
mk = L("""function(specs)
  local t = {}
  for i, s in ipairs(specs) do
    t[i] = { cle = s[1], valeur = { t = s[2], tr = s[3], nv = s[4], code = s[5] } }
  end
  return t
end""")
def file(*specs):
    return mk(lua.table_from([lua.table_from(list(s)) for s in specs]))
ch = M.choisirAdversaire
NOW = 105

# --- 1. UN JOUEUR ISOLE NE BLOQUE PLUS LA FILE ------------------------------------------------------
f = file(("isole", 100, 3000, 5), ("a", 101, 300, 2), ("b", 102, 320, 2))
if ch(f, "a", NOW) != "b":
    e.append("un joueur isole en tete de file empeche encore les autres de jouer (a devrait prendre b)")
if ch(f, "b", NOW) is not None:
    e.append("b est le plus recent de sa paire : il ne doit pas mener (double reservation)")
if ch(f, "isole", NOW) is not None:
    e.append("le joueur isole n'a personne de compatible : il attend l'elargissement")
# Deux paires a la fois, chacune avec un seul meneur.
f = file(("a", 100, 300, 2), ("x", 101, 2000, 4), ("b", 102, 310, 2), ("y", 103, 2010, 4))
res = {k: ch(f, k, NOW) for k in ("a", "x", "b", "y")}
if res != {"a": "b", "x": "y", "b": None, "y": None}:
    e.append("deux paires compatibles doivent se former en meme temps, un meneur chacune : %r" % res)
# Un joueur deja pris par une paire plus ancienne n'est pas repris par un autre.
f = file(("a", 100, 300, 2), ("b", 101, 305, 2), ("c", 102, 310, 2))
if ch(f, "b", NOW) is not None or ch(f, "a", NOW) != "b":
    e.append("b est deja pris par a : il ne peut pas mener une autre paire")

# --- 2. RENOUVELLEMENT ------------------------------------------------------------------------------
v = L("{ t = 1, tr = 10 }")
if M.renouveler(v) is None or M.renouveler(v).tr != 10:
    e.append("une entree libre doit etre renouvelee telle quelle")
if M.renouveler(L('{ t = 1, code = "X" }')) is not None or M.renouveler(None) is not None:
    e.append("une entree prise ou partie ne doit pas etre renouvelee")
if "M.renouveler(v)" not in MM:
    e.append("le tour de recherche ne renouvelle pas l'entree : un joueur patient disparait a 60 s")
if "map:SetAsync(moi, etat.entree, M.DUREE_ENTREE, etat.entree.t)" not in MM:
    e.append("une entree expiree n'est pas reposee : le joueur resterait introuvable")
if M.ATTENTE_PATIENTE > M.DUREE_ENTREE and "M.renouveler" not in MM:
    e.append("l'attente patiente depasse la duree de l'entree sans renouvellement")

# --- 3. ORDRE, LECTURE, VERROU ------------------------------------------------------------------------
if "GetRangeAsync(Enum.SortDirection.Ascending, M.LECTURE_FILE)" not in MM or M.LECTURE_FILE < 100:
    e.append("la file n'est pas lue en entier (100 entrees)")
if "M.DUREE_ENTREE, arrivee)" not in MM:
    e.append("l'entree n'est pas triee par heure d'arrivee : la lecture suit les identifiants")
# Toute mise a jour doit rendre la cle de tri, sinon l'entree sort de l'ordre.
if MM.count("return n, n.t") < 4:
    e.append("une mise a jour de file perd la cle de tri (%d sur 4)" % MM.count("return n, n.t"))
# Verrou : le meneur se marque lui-meme avant de prendre l'autre, et se libere s'il le rate.
if "local moiPris = false" not in MM or "if okCode and code and moiPris then" not in MM:
    e.append("le meneur ne se reserve pas avant de prendre l'autre : il pourrait partir seul")
libre = M.liberer(L('{ t = 5, code = "C", tr = 7 }'), "C")
if libre is None or libre.code is not None or libre.tr != 7 or libre.t != 5:
    e.append("se liberer doit rendre l'entree libre, avec son rang et son profil")
if M.liberer(L('{ t = 5, code = "AUTRE" }'), "C") is not None:
    e.append("on ne doit jamais effacer le code d'un match forme par un autre serveur")
if M.marquer(L("{ t = 5, tr = 7, nv = 2 }"), "C").tr != 7:
    e.append("marquer une entree efface son profil : la liberer la rendrait inappariable")

for x in e:
    print("ROUGE " + x)
print("%d echec(s)" % len(e) if e else
      "VERT : la file ne se bloque plus, ne perd plus ses joueurs patients, et se lit en entier")
sys.exit(1 if e else 0)
