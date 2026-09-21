# -*- coding: utf-8 -*-
"""Banc de la FIN DU TUTORIEL : la partie se termine et le menu revient tout seul.

Defaut mesure le 2026-09-20, en jouant le tutoriel en entier dans le moteur : les cinq etapes
finies, le serveur « rendait la main au jeu normal » et le debutant restait seul dans une bataille
de 3 minutes qu'il n'avait pas demandee, face a un robot lache d'un coup. Le seul retour au menu
etait le bouton MENU en haut a gauche, qui demande de confirmer un ABANDON : finir son
apprentissage coutait une defaite.

Ce qu'il verifie :
  1. la regle pure (Tutoriel.retourMenu) : une seule fois, et seulement apres le delai ;
  2. le serveur TERMINE bien la partie a la derniere etape, au credit du joueur ;
  3. il l'annonce dans l'etat envoye a CE joueur (`tutoTermine`) et l'oublie a la partie suivante ;
  4. le hub ecoute cet etat et rejoue le geste du bouton MENU (ouvrirAccueil) ;
  5. la copie de test ne rejoue PLUS ce retour a la place du jeu (sinon la capture prouverait un
     chemin qui n'existe pas en vrai).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Tutoriel.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    T = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    serveur = SERVEUR.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")

    # 1. la regle pure
    d = T.DELAI_RETOUR_MENU
    cas("un delai existe, assez long pour lire l'ecran de fin", True, 3 <= d <= 12)
    cas("rien tant que le tutoriel n'est pas fini", False, T.retourMenu(False, False, 99))
    cas("rien avant le delai", False, T.retourMenu(True, False, d - 0.1))
    cas("le menu revient une fois le delai passe", True, T.retourMenu(True, False, d))
    cas("et une SEULE fois (sinon il rouvrirait a chaque etat recu)", False, T.retourMenu(True, True, 99))
    cas("un temps absent ne declenche rien", False, T.retourMenu(True, False, None))
    # Le vainqueur est le joueur : sa premiere partie ne doit pas se solder par une defaite.
    cas("le camp du joueur gagne sa partie de tutoriel", 2, T.campVainqueur(2))

    # 2. le serveur termine la partie
    cas("la derniere etape termine la partie", True,
        "endMatch(Tutoriel.campVainqueur(campJoueur))" in serveur)
    cas("le tutoriel est marque comme fait avant", True, "Economie.marquerTutoriel(joueur)" in serveur)

    # 3. l'etat le dit au bon joueur, et l'oublie ensuite
    cas("l'etat porte la fin du tutoriel", True, "tutoTermine = (tutoFiniPour ~= nil and tutoFiniPour == player)" in serveur)
    cas("une nouvelle partie l'oublie", True, "tutoFiniPour = nil" in serveur)

    # 4. le hub le suit et rejoue le geste du bouton MENU
    cas("le hub charge la regle", True, 'WaitForChild("Tutoriel")' in hub)
    cas("il ecoute l'etat de la partie", True, "etatTuto.OnClientEvent:Connect" in hub)
    cas("il applique la regle, il ne la reecrit pas", True, "Tutoriel.retourMenu(" in hub)
    cas("et il rejoue le geste du bouton MENU", True,
        "retourTutoFait = true" in hub and "ouvrirAccueil()" in hub)

    # 5. la copie de test ne fait plus le travail a la place du jeu
    cas("le crochet de capture ne rejoue plus le retour", False,
        '[HUB] tutoriel fini : retour au menu (comme le bouton MENU)' in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : la fin du tutoriel termine la partie et ramene le joueur au menu")
    return 0


sys.exit(main())
