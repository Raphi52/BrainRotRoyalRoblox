# -*- coding: utf-8 -*-
"""Banc hors Studio : le scenario moteur [ECOTEST] a-t-il ete rejoue VERT depuis le dernier
changement des regles qu'il exerce ?

Rouge quand : aucun passage moteur n'est enregistre, ou les sources exercees (scenario `ecotest`,
Economie.lua, modules partages d'Economie) ont change depuis le dernier passage vert. Le remede est
de rejouer le moteur : powershell -NoProfile -ExecutionPolicy Bypass -File tools/ecotest_moteur.ps1
(bureau cache, n'arrete que son propre Studio), puis de revoir les cas ECHEC s'il y en a.
Voir tools/ecotest_empreinte.py pour le pourquoi (derive de 9 cas constatee le 2026-09-26).
"""
import json
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ecotest_empreinte as E  # noqa: E402


def main():
    echecs = []
    # Le calcul lui-meme doit reagir a un changement d'un seul caractere.
    base = E.sources()
    modifie = [(n, t + ("x" if n == "Economie.lua" else "")) for n, t in base]
    if E.empreinte(base) == E.empreinte(modifie):
        echecs.append("l'empreinte ne voit pas un changement d'Economie.lua")
    if not E.RECU.exists():
        echecs.append("aucun passage moteur enregistre (%s absent)" % E.RECU.name)
    else:
        recu = json.loads(E.RECU.read_text(encoding="utf-8"))
        if recu.get("echec", 1) != 0:
            echecs.append("le dernier passage moteur enregistre n'est pas vert")
        if recu.get("empreinte") != E.empreinte(base):
            echecs.append("les regles d'economie ont change depuis le dernier passage moteur vert (%s)" % recu.get("date"))
    if echecs:
        for e in echecs:
            print("ROUGE :", e)
        print("Remede : powershell -NoProfile -ExecutionPolicy Bypass -File tools/ecotest_moteur.ps1")
        return 1
    print("VERT : scenario moteur a jour (%s, %d cas OK)" % (recu["date"], recu["ok"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
