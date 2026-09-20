# -*- coding: utf-8 -*-
"""Banc des REGLES DE PARTIE (src/shared/Regles.lua), hors Studio.

Ce qu'il verifie :
  1. l'elixir double dans le dernier tiers, triple en prolongation, simple avant ;
  2. la phase envoyee au client suit exactement ce meme decoupage ;
  3. une egalite de couronnes au chrono n'est plus une fin : elle ouvre la prolongation ;
  4. la prolongation se tranche sur la tour la plus entamee, et seule une egalite PARFAITE
     laisse la partie nulle ;
  5. la zone de pose s'ouvre dans la moitie adverse UNIQUEMENT du cote de la tour tombee ;
  6. le serveur de jeu applique reellement ces regles (sinon le module serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Regles.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    D = 180.0  # duree reglementaire du vrai jeu
    seuil = R.seuilDouble(D)
    cas("le double elixir commence au dernier tiers", 60.0, round(float(seuil), 3))

    # 1 + 2. multiplicateur et phase
    cas("debut de partie : elixir simple", 1, R.multiplicateurElixir(170, D, False))
    cas("juste avant le seuil : encore simple", 1, R.multiplicateurElixir(61, D, False))
    cas("au seuil : elixir double", 2, R.multiplicateurElixir(60, D, False))
    cas("fin de partie : toujours double", 2, R.multiplicateurElixir(3, D, False))
    cas("prolongation : elixir triple", 3, R.multiplicateurElixir(50, D, True))
    cas("phase normale", "normale", R.phase(170, D, False))
    cas("phase double", "double", R.phase(20, D, False))
    cas("phase prolongation", "prolongation", R.phase(20, D, True))

    # 3. fin du temps reglementaire
    cas("celui qui mene gagne au chrono", 1, R.finDuTemps(2, 1))
    cas("celui qui mene gagne au chrono (camp 2)", 2, R.finDuTemps(0, 1))
    cas("egalite de couronnes -> prolongation", None, R.finDuTemps(1, 1))
    cas("0-0 -> prolongation", None, R.finDuTemps(0, 0))

    # 4. fin de prolongation : la tour la plus entamee perd
    cas("tour la plus entamee perd", 1, R.finProlongation(0.8, 0.4))
    cas("tour la plus entamee perd (camp 1)", 2, R.finProlongation(0.2, 0.9))
    cas("egalite parfaite : nulle", 0, R.finProlongation(0.5, 0.5))
    cas("un cheveu d'ecart suffit", 2, R.finProlongation(0.50, 0.51))

    # 5. zone de pose
    cas("camp 1 pose chez lui", True, R.posePermise(1, 5, -10, False, False))
    cas("camp 1 ne pose pas chez l'ennemi sans tour cassee", False, R.posePermise(1, 5, 10, False, False))
    cas("tour DROITE cassee : pose a droite chez l'ennemi", True, R.posePermise(1, 5, 10, False, True))
    cas("tour droite cassee : toujours rien a GAUCHE", False, R.posePermise(1, -5, 10, False, True))
    cas("tour gauche cassee : pose a gauche chez l'ennemi", True, R.posePermise(1, -5, 10, True, False))
    cas("camp 2, sa moitie", True, R.posePermise(2, 5, 10, False, False))
    cas("camp 2 chez l'ennemi sans tour cassee", False, R.posePermise(2, 5, -10, False, False))
    cas("camp 2, tour gauche cassee", True, R.posePermise(2, -5, -10, True, False))
    cas("la bande du pont reste interdite sans tour cassee", False, R.posePermise(1, 5, 1, False, False))

    # 5 bis. anti-aerien : quelles cartes peuvent toucher un volant
    def carte(**kw):
        base = dict(targets="any", range=3, flying=False)
        base.update(kw)
        return lua.table_from(base)
    cas("une melee au sol ne touche pas un volant", False, R.peutViserVolant(carte(range=3)))
    cas("un tireur touche un volant", True, R.peutViserVolant(carte(range=8)))
    cas("un volant touche un volant", True, R.peutViserVolant(carte(range=3, flying=True)))
    cas("une carte anti-tours ne touche aucun volant", False, R.peutViserVolant(carte(range=9, targets="buildings")))
    cas("le robot s'en sert", True, "Regles.peutViserVolant" in SERVEUR.read_text(encoding="utf-8"))

    # 6. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    cas("le serveur double l'elixir", True, "Regles.multiplicateurElixir(" in serveur)
    cas("le serveur ouvre la prolongation", True, "Regles.finDuTemps(" in serveur)
    cas("le serveur tranche la prolongation", True, "Regles.finProlongation(" in serveur)
    cas("le serveur applique la zone de pose", True, "Regles.posePermise(" in serveur)
    cas("le serveur envoie la phase au client", True, "Regles.phase(" in serveur)
    cas("le client annonce la phase", True, "phase" in client)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : double elixir, prolongation et zone de pose se comportent comme annonce")
    return 0


if __name__ == "__main__":
    sys.exit(main())
