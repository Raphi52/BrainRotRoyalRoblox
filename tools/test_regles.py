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

    # 6 bis. PREAVIS DE DOUBLE ELIXIR. Defaut mesure le 2026-09-20 : le basculement etait annonce
    # A L'INSTANT ou il arrive. Toute la decision se prend AVANT (garder son elixir pour partir en
    # poussee des la bascule) : l'annonce ne faisait que constater.
    duree = 180.0
    seuil = float(R.seuilDouble(duree))  # 60 s restantes a 180 s de match
    cas("en debut de partie, le double est encore loin", duree - seuil,
        float(R.avantDouble(duree, duree, False)))
    cas("juste avant la bascule, il reste peu", 3.0, float(R.avantDouble(seuil + 3, duree, False)))
    cas("une fois dedans, plus de preavis", None, R.avantDouble(seuil, duree, False))
    cas("ni pendant la prolongation", None, R.avantDouble(duree, duree, True))
    # Le texte n'apparait QUE dans la fenetre de preavis : sinon il resterait a l'ecran 2 minutes.
    cas("pas de texte hors de la fenetre", None, R.texteAvantDouble(duree, duree, False))
    cas("texte dans la fenetre", "DOUBLE ELIXIR DANS 7",
        R.texteAvantDouble(seuil + 6.4, duree, False))
    cas("arrondi au superieur, comme un compte a rebours", "DOUBLE ELIXIR DANS 1",
        R.texteAvantDouble(seuil + 0.2, duree, False))
    cas("rien une fois le double atteint", None, R.texteAvantDouble(seuil - 1, duree, False))
    cas("la fenetre laisse le temps de reagir", True, 5 <= float(R.PREAVIS) <= 20)

    # 6 ter. PREAVIS DE FIN. Meme defaut que le double elixir, en pire : on DECOUVRAIT la
    # prolongation en y entrant. Les dernieres secondes ne se jouent pas pareil selon qu'on va
    # vers une prolongation (garder son elixir) ou vers la fin seche.
    cas("rien tant que la fin est loin", None, R.texteAvantFin(60, 1, 1, False))
    # A EGALITE de couronnes, c'est une prolongation qui vient : le texte doit le DIRE.
    cas("egalite : prolongation annoncee", "PROLONGATION DANS 6", R.texteAvantFin(5.2, 1, 1, False))
    cas("zero partout compte comme une egalite", "PROLONGATION DANS 3", R.texteAvantFin(3, 0, 0, False))
    # Sinon la partie s'arrete vraiment : ce n'est pas le meme jeu dans les dernieres secondes.
    cas("avance : fin seche annoncee", "FIN DANS 4", R.texteAvantFin(3.4, 2, 1, False))
    cas("retard : fin seche aussi", "FIN DANS 4", R.texteAvantFin(3.4, 1, 2, False))
    # L'issue annoncee suit la REGLE, pas une copie : finDuTemps reste la seule source.
    cas("le texte suit la regle de fin du temps", True,
        (R.finDuTemps(1, 1) is None) and "PROLONGATION" in R.texteAvantFin(3, 1, 1, False))
    cas("rien pendant la prolongation elle-meme", None, R.texteAvantFin(3, 1, 1, True))
    cas("rien une fois le temps ecoule", None, R.texteAvantFin(0, 1, 1, False))

    # 6 quater. RAPPEL PERMANENT DE LA PROLONGATION. Defaut mesure le 2026-09-20 : l'entree etait
    # annoncee 2,5 s puis plus rien. Or la prolongation ne se joue PAS comme le reste : la
    # premiere tour prise gagne sur-le-champ. Un joueur qui n'a pas lu le manuel defendait comme
    # d'habitude et perdait sans comprendre qu'une seule tour suffisait.
    cas("rien hors prolongation", None, R.rappelProlongation(False))
    cas("le rappel existe en prolongation", R.RAPPEL_PROLONGATION, R.rappelProlongation(True))
    # Il doit DIRE la regle, pas seulement nommer la phase.
    for mot in ("PREMIERE TOUR", "GAGNE"):
        cas("le rappel porte %s" % mot, True, mot in R.RAPPEL_PROLONGATION)
    # Et cette regle est bien celle que le serveur applique : la premiere tour prise termine.
    cas("la regle annoncee est celle du jeu", True, "prolongation then" in SERVEUR.read_text(encoding="utf-8"))

    # 6. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    cas("le serveur double l'elixir", True, "Regles.multiplicateurElixir(" in serveur)
    cas("le serveur ouvre la prolongation", True, "Regles.finDuTemps(" in serveur)
    cas("le serveur tranche la prolongation", True, "Regles.finProlongation(" in serveur)
    cas("le serveur applique la zone de pose", True, "Regles.posePermise(" in serveur)
    cas("le serveur envoie la phase au client", True, "Regles.phase(" in serveur)
    cas("le client annonce la phase", True, "phase" in client)
    # Le preavis est calcule cote SERVEUR : le client n'a pas la duree du match.
    cas("le serveur envoie le preavis", True,
        "preavisDouble = Regles.texteAvantDouble(timeLeft, MATCH_TIME, prolongation)" in serveur)
    cas("les deux vues le recoivent (joueur et spectateur)", 2,
        serveur.count("preavisDouble = Regles.texteAvantDouble("))
    cas("le client affiche le preavis", True, "banniere.Text = preavis" in client)
    cas("le serveur envoie aussi le preavis de fin", 2,
        serveur.count("preavisFin = Regles.texteAvantFin(timeLeft, crowns(1), crowns(2), prolongation)"))
    # Le preavis de FIN passe devant celui du double : il est plus proche.
    cas("la fin passe devant le double elixir", True,
        "local preavis = s.preavisFin or s.preavisDouble" in client)
    # Deux couleurs : or pour la fin, violet pour le double — on ne les confond pas d'un coup d'oeil.
    cas("le client affiche le rappel de prolongation", True,
        "banniere.Text = Regles.rappelProlongation(true)" in client)
    # Il attend la fin de l'annonce d'entree, sinon il l'ecraserait aussitot.
    cas("il laisse passer l'annonce d'entree", True,
        "(os.clock() - (hud.instantProlongation or 0)) > 3" in client)
    # Plus petit que l'annonce : il reste a l'ecran tout le temps de la prolongation.
    cas("le rappel est plus discret que l'annonce", True, "banniere.TextSize = 26" in client)
    cas("et l'annonce retrouve sa taille", True, client.count("banniere.TextSize = 42") >= 3)
    cas("les deux preavis ne se confondent pas", True,
        "s.preavisFin and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(225, 120, 255)" in client)
    # Il ne doit pas rester colle a l'ecran une fois la partie finie.
    # Ce controle portait sur la FORME « if preavis and not s.result then ». Elle empechait bien le
    # bandeau de s'AFFICHER a la fin, mais aucune branche ne le MASQUAIT : un match termine en
    # prolongation gardait « MORT SUBITE » en travers de l'ecran de fin (capture du 2026-09-20).
    # On verifie donc le FAIT : la fin de partie efface le bandeau.
    cas("il disparait a la fin de la partie", True,
        "banniere.Visible = false" + chr(10) + chr(9) + "elseif preavis then" in client)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : double elixir, prolongation et zone de pose se comportent comme annonce")
    return 0


if __name__ == "__main__":
    sys.exit(main())
