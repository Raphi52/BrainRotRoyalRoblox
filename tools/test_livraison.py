# -*- coding: utf-8 -*-
"""Garde-fou : TOUT module de src/shared doit etre livre dans la place par build.py.

Defaut mesure le 2026-09-20 : le module Fiche a ete ecrit, les deux clients l'ont demande par
`WaitForChild("Fiche")`... et build.py ne le copiait pas dans la place. Consequence a l'ecran :
le hub ne s'affichait PLUS DU TOUT — il attendait indefiniment un module qui n'arriverait jamais
(journal Studio : « Infinite yield possible on ReplicatedStorage.Shared:WaitForChild("Fiche") »).
Aucun test ne pouvait voir ce defaut : le Lua compile, les bancs passent, et seule une capture
d'ecran vide le revele.

Ce qu'il verifie :
  1. chaque fichier de src/shared est livre par build.py, sous son nom de module ;
  2. chaque module DEMANDE par un script (WaitForChild) existe bien dans src/shared ;
  3. les modules serveur (src/server/*.lua hors scripts) sont livres eux aussi.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUILD = (ROOT / "build.py").read_text(encoding="utf-8")

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    livres = set(re.findall(r'item\("ModuleScript",\s*"(\w+)",\s*source=src\("shared/(\w+)\.lua"\)', BUILD))
    noms_livres = {n for n, _ in livres}
    fichiers_livres = {f for _, f in livres}

    sur_disque = {f.stem for f in (ROOT / "src" / "shared").glob("*.lua")}
    manquants = sorted(sur_disque - fichiers_livres)
    cas("tout module partage est livre dans la place", [], manquants)

    # Un module livre sous un nom different de son fichier ferait echouer WaitForChild.
    mal_nommes = sorted("%s -> %s" % (f, n) for n, f in livres if n != f)
    cas("chaque module garde son nom de fichier", [], mal_nommes)

    # Tout ce que les scripts DEMANDENT doit exister et etre livre.
    demandes = set()
    for chemin in list((ROOT / "src").rglob("*.lua")):
        if chemin.name.endswith(".bak") or ".bak-" in chemin.name:
            continue
        texte = chemin.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'WaitForChild\("Shared"\):WaitForChild\("(\w+)"\)', texte):
            demandes.add(m.group(1))
    introuvables = sorted(d for d in demandes if d not in sur_disque)
    cas("aucun script ne demande un module inexistant", [], introuvables)
    non_livres = sorted(d for d in demandes if d not in noms_livres)
    cas("aucun script ne demande un module non livre", [], non_livres)
    print("  %d modules partages, %d demandes par les scripts" % (len(sur_disque), len(demandes)))

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : tout module ecrit est livre, et tout module demande existe")
    return 0


sys.exit(main())
