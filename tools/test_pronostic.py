# -*- coding: utf-8 -*-
"""Pronostic des spectateurs : boutons Rouge / Bleu, valide cote serveur, pieces si juste.

1. pronosticAccepte (extraite, lupa) : camp 1 ou 2 seulement, spectateur seulement, un seul par
   partie, refuse une fois la partie finie, et refuse une fois la partie ENGAGEE (paris fermes).
2. Economie.gainPronostic (extraite, lupa) : +GAIN_PRONOSTIC pieces, profil marque a sauver.
3. Cablage serveur : RemoteEvent « Pronostic » ; endMatch paie les pronostics justes ; resetMatch les vide.
4. Client : boutons qui envoient PronosticEvent:FireServer(1|2), visibles seulement au spectateur.
Prerequis : python -m pip install lupa
"""
import re, sys, pathlib
from lupa import LuaRuntime
ROOT = pathlib.Path(__file__).resolve().parent.parent
S = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
E = (ROOT / "src/server/Economie.lua").read_text(encoding="utf-8")
C = (ROOT / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
e = []
def luau(c): return re.sub(r"([\w\.\[\]]+)\s*\+=\s*", r"\1 = \1 + ", c)

fn = re.search(r"^local function pronosticAccepte\(.*?^end\n", S, re.S | re.M)
if not fn:
    e.append("serveur : pronosticAccepte absente")
else:
    f = LuaRuntime().execute(fn.group(0) + "return pronosticAccepte")
    # 5e argument : les paris sont-ils encore OUVERTS. Ajoute le 2026-09-21 — rien n'empechait
    # jusque-la de parier a la derniere seconde sur une issue deja evidente, donc d'encaisser des
    # pieces sans rien risquer.
    for args, att in [((1, False, False, False, True), True), ((2, False, False, False, True), True),
                      ((3, False, False, False, True), False), (("1", False, False, False, True), False),
                      ((1, True, False, False, True), False), ((1, False, True, False, True), False),
                      ((1, False, False, True, True), False),
                      # partie engagee : refus, meme pour un pari par ailleurs valide
                      ((1, False, False, False, False), False), ((2, False, False, False, False), False),
                      # un client qui n'envoie rien ne doit pas ouvrir les paris par defaut
                      ((1, False, False, False, None), False)]:
        if f(*args) != att:
            e.append(f"serveur : pronosticAccepte{args} -> {f(*args)}, attendu {att}")

g = re.search(r"^local GAIN_PRONOSTIC = \d+", E, re.M)
gp = re.search(r"^function Economie\.gainPronostic\(.*?^end\n", E, re.S | re.M)
if not (g and gp):
    e.append("economie : GAIN_PRONOSTIC ou Economie.gainPronostic absent")
else:
    r = LuaRuntime().execute(luau(
        "local SALE = false\nlocal Economie = { marquerSale = function() SALE = true end }\n"
        "local profils = {}\nlocal function leaderstats() end\n" + g.group(0) + "\n" + gp.group(0) +
        "local pl = { Name = 'S' }; profils[pl] = { pieces = 5 }\nEconomie.gainPronostic(pl)\n"
        "return profils[pl].pieces - 5, GAIN_PRONOSTIC, SALE"))
    if not (r[0] == r[1] > 0 and r[2]):
        e.append(f"economie : gainPronostic -> +{r[0]} (attendu +{r[1]}), sale={r[2]}")

if 'PronosticEvent.Name = "Pronostic"' not in S:
    e.append("serveur : RemoteEvent Pronostic absente")
em = re.search(r"^local function endMatch\(.*?^end\n", S, re.S | re.M)
if not em or not re.search(r"vainqueur == camp.*?Economie\.gainPronostic", em.group(0), re.S):
    e.append("serveur : endMatch ne paie pas les pronostics justes")
rm = re.search(r"^local function resetMatch\(.*?^end\n", S, re.S | re.M)
if not rm or "pronostics = {}" not in rm.group(0):
    e.append("serveur : resetMatch ne vide pas les pronostics")
if "PronosticEvent:FireServer(camp)" not in C or "pronoBarre.Visible = s.spectateur" not in C:
    e.append("client : boutons de pronostic absents ou visibles hors spectateur")
for x in e: print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
