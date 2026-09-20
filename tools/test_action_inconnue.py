# -*- coding: utf-8 -*-
"""Le point d'entree « Boutique » refuse EXPLICITEMENT une action qu'il ne connait pas.

Avant ce garde-fou, le gestionnaire se terminait par `return { ok = true, vue = ... }` : une
action mal orthographiee (cote client) repondait comme un SUCCES, le menu se rafraichissait, et
le bouton casse passait inapercu. Audit du 2026-09-20.

Deux bords figes ici :
1. le retour final du gestionnaire porte ok = false ET un motif ;
2. CHAQUE action reellement appelee par le menu (src/client/Hub.client.lua) est traitee par une
   branche nommee du gestionnaire — sinon elle tomberait dans le refus et le menu casserait.
"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRV = (ROOT / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
HUB = (ROOT / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []

bloc = re.search(r"BoutiqueFn\.OnServerInvoke = function\(.*?\n^end\n", SRV, re.S | re.M)
if not bloc:
    e.append("gestionnaire BoutiqueFn.OnServerInvoke introuvable")
else:
    corps = bloc.group(0)

    # 1. le retour de sortie (apres le dernier `end` de la chaine if/elseif) refuse
    queue = corps[corps.rindex("\n\tend\n"):]
    if "ok = false" not in queue:
        e.append("action inconnue : le retour final ne porte pas ok = false -> %r" % queue.strip()[:120])
    if "motif" not in queue:
        e.append("action inconnue : le retour final ne porte aucun motif")
    if "vue = Economie.vue(player)" not in queue:
        e.append("action inconnue : la vue n'est plus renvoyee, le menu ne pourrait plus se rafraichir")

    # 2. toute action appelee par le menu doit exister comme branche nommee
    traitees = set(re.findall(r'action == "(\w+)"', corps))
    # le client construit deux actions par expression : `debloquee and "ameliorer" or "acheter"`
    # et `c.fin == 0 and "demarrerCoffre" or "ouvrirCoffre"` : on les lit aussi.
    appelees = set(re.findall(r'InvokeServer\("(\w+)"', HUB))
    # Le choix ternaire n'est compte que s'il ALIMENTE l'appel : `local action = ... and "x" or
    # "y"`. Sans cette restriction, un `Sons.jouer(r.ok and "coffre" or "refus")` serait pris
    # pour une action serveur (mesure : premier passage de ce test, 2026-09-20).
    for a, b in re.findall(r'local action = .*?and "(\w+)" or "(\w+)"', HUB):
        appelees.add(a)
        appelees.add(b)
    manquantes = sorted(a for a in appelees if a not in traitees)
    if manquantes:
        e.append("actions appelees par le menu mais non traitees par le serveur : %s" % ", ".join(manquantes))
    else:
        print("  OK    %d actions du menu, toutes traitees par une branche nommee" % len(appelees))

if e:
    print("\n".join("ROUGE " + x for x in e))
    print("%d echec(s)" % len(e))
    sys.exit(1)
print("VERT : action inconnue refusee avec motif, et aucune action du menu ne tombe dans ce refus")
