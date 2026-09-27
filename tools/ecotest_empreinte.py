# -*- coding: utf-8 -*-
"""EMPREINTE des regles que joue le scenario moteur [ECOTEST] — pas un banc.

Pourquoi (2026-09-26) : le scenario [ECOTEST] (fonction `ecotest` de GameServer.server.lua) n'est
rejoue que dans Roblox Studio. Quand le deblocage des cartes par arene et l'enjeu au tiers contre le
robot sont arrives, il a derive de 9 cas (71 OK / 9 ECHEC) sans qu'aucun des 122 bancs hors Studio
ne le voie. On retient donc l'empreinte des sources qu'il exerce au dernier passage moteur VERT
(tools/ecotest-dernier.json, ecrit par tools/ecotest_moteur.ps1) ; tools/test_ecotest_a_jour.py
passe au rouge des que ces sources changent sans nouveau passage vert.

Usage : python tools/ecotest_empreinte.py                  -> affiche l'empreinte courante
        python tools/ecotest_empreinte.py --ecrire OK ECHEC -> enregistre un passage (ECHEC doit valoir 0)
"""
import datetime
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import corps_fonction  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
RECU = ROOT / "tools" / "ecotest-dernier.json"
# Ce que le scenario exerce : le scenario lui-meme, Economie, et les modules partages qu'Economie requiert.
MODULES = ["Abandon", "Arenes", "Cards", "Coffres", "Cosmetiques", "Emotes", "Journal", "Ligues",
           "PassSaison", "Quetes", "Saison"]


def _lire(chemin):
    return chemin.read_text(encoding="utf-8").replace("\r\n", "\n")


def sources():
    serveur = _lire(ROOT / "src" / "server" / "GameServer.server.lua")
    morceaux = [("ecotest", corps_fonction(serveur, "local function ecotest(player)")),
                ("Economie.lua", _lire(ROOT / "src" / "server" / "Economie.lua"))]
    for m in MODULES:
        morceaux.append((m + ".lua", _lire(ROOT / "src" / "shared" / (m + ".lua"))))
    return morceaux


def empreinte(morceaux=None):
    h = hashlib.sha256()
    for nom, texte in (morceaux or sources()):
        h.update(nom.encode("utf-8") + b"\0" + texte.encode("utf-8") + b"\0")
    return h.hexdigest()


def main(argv):
    if len(argv) >= 3 and argv[0] == "--ecrire":
        ok, echec = int(argv[1]), int(argv[2])
        if echec != 0 or ok <= 0:
            print("REFUS : on n'enregistre qu'un passage VERT (ok=%d, echec=%d)" % (ok, echec))
            return 1
        recu = {"empreinte": empreinte(), "ok": ok, "echec": echec,
                "date": datetime.datetime.now().isoformat(timespec="seconds")}
        RECU.write_text(json.dumps(recu, indent=2) + "\n", encoding="utf-8")
        print("ENREGISTRE : %s" % json.dumps(recu))
        return 0
    print(empreinte())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
