# -*- coding: utf-8 -*-
"""Banc de la DIFFICULTE DU ROBOT (src/shared/Robot.lua), hors Studio.

Defaut mesure avant ce module : le robot jouait EXACTEMENT pareil a 0 trophee et a 3000. Sa FORCE
suivait deja le joueur (niveau de ses cartes), mais pas son COMPORTEMENT — meme temps de reaction,
aucune erreur, des la premiere partie.

Ce qu'il verifie :
  1. un debutant rencontre un robot lent et maladroit ; un expert un robot vif et sans erreur ;
  2. la difficulte est MONOTONE : plus de trophees ne rend jamais le robot plus facile ;
  3. toutes les valeurs restent BORNEES (aucun robot injouable, aucun robot inerte) ;
  4. des trophees absents, negatifs ou absurdes ne cassent rien ;
  5. l'erreur est bien une probabilite : jamais a 0 trophee elle ne vaut 0, jamais au sommet
     elle ne depasse le plafond ;
  6. le delai entre deux decisions est irregulier mais borne ;
  7. le serveur de jeu applique reellement le profil.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Robot.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — le robot joue pareil a tous les niveaux" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    # 1. les extremes
    debutant = R.profil(0)
    expert = R.profil(3000)
    print("  0 trophee    -> %s : reflexe %.1f s, erreur %.0f %%, garde %d elixir"
          % (debutant.nom, float(debutant.reflexe), float(debutant.erreur) * 100, int(debutant.gardeElixir)))
    print("  3000 trophees -> %s : reflexe %.1f s, erreur %.0f %%, garde %d elixir"
          % (expert.nom, float(expert.reflexe), float(expert.erreur) * 100, int(expert.gardeElixir)))
    cas("un joueur neuf affronte un debutant", "debutant", debutant.nom)
    cas("un joueur aguerri affronte un expert", "expert", expert.nom)
    cas("le debutant reflechit plus longtemps", True, float(debutant.reflexe) > float(expert.reflexe))
    cas("le debutant se trompe, l'expert non", True, float(debutant.erreur) > 0 and float(expert.erreur) == 0)
    cas("l'expert attaque plus tot", True, int(expert.gardeElixir) < int(debutant.gardeElixir))
    cas("le debutant ne repond pas encore aux volants", False, bool(debutant.anticipe))
    cas("l'expert, si", True, bool(expert.anticipe))

    # 2. monotonie sur toute la plage
    valeurs = [(t, R.profil(t)) for t in range(0, 3001, 25)]
    reflexes = [float(p.reflexe) for _, p in valeurs]
    erreurs = [float(p.erreur) for _, p in valeurs]
    gardes = [int(p.gardeElixir) for _, p in valeurs]
    cas("le reflexe ne remonte jamais", True, all(reflexes[i] >= reflexes[i + 1] for i in range(len(reflexes) - 1)))
    cas("l'erreur ne remonte jamais", True, all(erreurs[i] >= erreurs[i + 1] for i in range(len(erreurs) - 1)))
    cas("la garde d'elixir ne remonte jamais", True, all(gardes[i] >= gardes[i + 1] for i in range(len(gardes) - 1)))
    noms = []
    for _, p in valeurs:
        if not noms or noms[-1] != p.nom:
            noms.append(p.nom)
    cas("les paliers se suivent dans l'ordre", ["debutant", "normal", "aguerri", "expert"], noms)

    # 3. bornes
    cas("aucun robot inerte", True, all(r <= float(R.REFLEXE_MAX) for r in reflexes))
    cas("aucun robot surhumain", True, all(r >= float(R.REFLEXE_MIN) for r in reflexes))
    cas("l'erreur reste une probabilite", True, all(0 <= e <= float(R.ERREUR_MAX) for e in erreurs))

    # 4. entrees invalides
    cas("trophees absents : palier le plus tendre", "debutant", R.profil(None).nom)
    cas("trophees negatifs : palier le plus tendre", "debutant", R.profil(-500).nom)
    cas("trophees en texte : lus quand meme", "expert", R.profil("3000").nom)
    cas("texte illisible : palier le plus tendre", "debutant", R.profil("bonjour").nom)
    cas("trophees enormes : on reste expert", "expert", R.profil(10 ** 9).nom)

    # 5. l'erreur est bien un tirage
    cas("tirage sous le seuil : il se trompe", True, R.seTrompe(debutant, 0.0))
    cas("tirage au-dessus : il joue juste", False, R.seTrompe(debutant, 0.99))
    cas("un expert ne se trompe jamais", False, R.seTrompe(expert, 0.0))
    # frequence reelle sur 1000 tirages reguliers
    rates = sum(1 for i in range(1000) if R.seTrompe(debutant, i / 1000.0))
    attendu = round(float(debutant.erreur) * 1000)
    cas("la frequence d'erreur correspond au profil", True, abs(rates - attendu) <= 1)

    # 6. delai entre deux decisions
    court, long = float(R.delai(expert, 0)), float(R.delai(expert, 1))
    cas("le delai part du reflexe", float(expert.reflexe), court)
    cas("et ne depasse pas +50 %%", round(float(expert.reflexe) * 1.5, 6), round(long, 6))
    cas("un debutant reste plus lent qu'un expert, meme au mieux", True,
        float(R.delai(debutant, 0)) > float(R.delai(expert, 1)))

    # 7. CONTRE-ATTAQUE : punir une attaque repoussee
    def etat(**kw):
        base = dict(menaceRepoussee=400, survivants=2, depuisDefense=1.0, elixir=8, cout=4)
        base.update(kw)
        return lua.table_from(base)
    fenetre = float(R.FENETRE_CONTRE)
    mini = float(R.MENACE_MINIMALE)
    reserve = float(R.RESERVE_CONTRE)
    print("  contre-attaque : fenetre %.0f s, menace minimale %.0f PV, reserve %.0f elixir"
          % (fenetre, mini, reserve))
    cas("apres une defense reussie, il punit", True, R.contreAttaque(expert, etat()))
    cas("un debutant ne contre-attaque jamais", False, R.contreAttaque(debutant, etat()))
    cas("sans menace repoussee, ce n'est pas une defense", False,
        R.contreAttaque(expert, etat(menaceRepoussee=mini - 1)))
    cas("au seuil exact de menace, il y va", True, R.contreAttaque(expert, etat(menaceRepoussee=mini)))
    cas("sans survivant, il ne relance pas seul", False, R.contreAttaque(expert, etat(survivants=0)))
    cas("trop tard : la fenetre est passee", False,
        R.contreAttaque(expert, etat(depuisDefense=fenetre + 0.1)))
    cas("juste dans la fenetre : il y va", True, R.contreAttaque(expert, etat(depuisDefense=fenetre)))
    cas("aucune defense recente : rien", False, R.contreAttaque(expert, etat(depuisDefense=None)))
    cas("pas assez d'elixir : il attend", False, R.contreAttaque(expert, etat(elixir=4, cout=4)))
    cas("juste assez d'elixir, reserve comprise", True,
        R.contreAttaque(expert, etat(elixir=4 + reserve, cout=4)))
    cas("sans profil, aucune contre-attaque", False, R.contreAttaque(None, etat()))
    cas("sans etat, aucune contre-attaque", False, R.contreAttaque(expert, None))
    # la capacite suit la difficulte, comme le reste
    contres = [bool(p.contre) for _, p in valeurs]
    cas("la contre-attaque ne se perd jamais en montant", True,
        all(contres[i] <= contres[i + 1] for i in range(len(contres) - 1)))

    # 8. OUVERTURE DE PARTIE : garder son elixir au lieu d'ouvrir a l'aveugle
    D = 180.0
    part = float(R.OUVERTURE_PART)
    supp = float(R.SUPPLEMENT_OUVERTURE)
    plafond = float(R.ELIXIR_MAX)
    print("  ouverture : premier tiers (%.0f s sur %.0f), +%.0f elixir exige, plafond %.0f"
          % (D * part, D, supp, plafond))
    cas("au coup d'envoi, on est en ouverture", True, R.enOuverture(0, D))
    cas("a la fin du premier tiers, encore", True, R.enOuverture(D * part, D))
    cas("juste apres, c'est fini", False, R.enOuverture(D * part + 0.1, D))
    cas("en fin de partie, non", False, R.enOuverture(D - 1, D))
    cas("duree absente : jamais d'ouverture", False, R.enOuverture(0, 0))
    cas("valeurs illisibles : pas de plantage", False, R.enOuverture("x", "y"))

    normal = R.profil(300)
    cas("hors ouverture : seuil normal", float(normal.gardeElixir), float(R.gardeAttaque(normal, False)))
    cas("en ouverture : il attend plus", float(normal.gardeElixir) + supp,
        float(R.gardeAttaque(normal, True)))
    cas("un debutant ne sait pas economiser", float(debutant.gardeElixir),
        float(R.gardeAttaque(debutant, True)))
    # invariant reel : AUCUN profil, dans AUCUN cas, n'exige plus que le plafond du jeu —
    # un seuil a 11 rendrait le robot definitivement inerte.
    tous_seuils = [float(R.gardeAttaque(p, ouv)) for _, p in valeurs for ouv in (True, False)]
    cas("aucun seuil ne depasse le plafond", True, all(x <= plafond for x in tous_seuils))
    cas("aucun seuil absurde non plus", True, all(x >= 1 for x in tous_seuils))
    # un profil qui economise et dont le seuil est deja haut reste sous le plafond
    haut = lua.table_from(dict(gardeElixir=9, economise=True))
    cas("seuil eleve + ouverture : borne au plafond", plafond, float(R.gardeAttaque(haut, True)))
    cas("sans profil : on exige le plafond", plafond, float(R.gardeAttaque(None, False)))
    # MONOTONIE, version corrigee. Premiere ecriture de ce cas : « un robot plus fort n'attend
    # jamais plus longtemps ». Le banc l'a refuse, et il avait raison de le faire : en ouverture,
    # le DEBUTANT (qui n'economise pas) ouvre plus tot que le NORMAL. Ce n'est pas une regression,
    # c'est le sens meme de la regle — economiser est un BON geste, pas une faiblesse. L'invariant
    # qui compte porte donc sur les profils qui economisent entre eux.
    economes = [p for _, p in valeurs if bool(p.economise)]
    seuils = [float(R.gardeAttaque(p, True)) for p in economes]
    cas("entre robots qui economisent, la monotonie tient", True,
        all(seuils[i] >= seuils[i + 1] for i in range(len(seuils) - 1)))
    cas("le debutant, lui, ouvre trop tot : c'est sa faiblesse", True,
        float(R.gardeAttaque(debutant, True)) < float(R.gardeAttaque(normal, True)))
    cas("l'expert ouvre plus tot que le normal, meme en ouverture", True,
        float(R.gardeAttaque(expert, True)) < float(R.gardeAttaque(normal, True)))

    # 9. ERREUR DE PLACEMENT : la faute la plus courante d'un debutant
    ecart_deb = float(R.ecartPlacement(debutant))
    print("  ecart de pose : debutant %.1f stud, normal %.1f, aguerri %.1f, expert %.1f"
          % (ecart_deb, float(R.ecartPlacement(normal)),
             float(R.ecartPlacement(R.profil(800))), float(R.ecartPlacement(expert))))
    cas("un expert pose exactement ou il vise", (0, 0), tuple(R.deviation(expert, 0.0, 1.0)))
    cas("un debutant peut rater franchement", True, abs(float(R.deviation(debutant, 0.0, 0.5)[0])) > 2)
    cas("l'ecart ne depasse jamais celui du palier", True,
        all(abs(float(R.deviation(debutant, tx / 100.0, 0.5)[0])) <= ecart_deb + 1e-9
            for tx in range(101)))
    cas("un tirage centre ne devie pas", (0, 0), tuple(R.deviation(debutant, 0.5, 0.5)))
    cas("les deux extremes sont symetriques",
        round(-float(R.deviation(debutant, 0.0, 0.5)[0]), 6),
        round(float(R.deviation(debutant, 1.0, 0.5)[0]), 6))
    # pas de BIAIS : sur beaucoup de tirages reguliers, la moyenne tend vers zero
    moyenne = sum(float(R.deviation(debutant, t / 1000.0, 0.5)[0]) for t in range(1001)) / 1001
    cas("aucun biais systematique", True, abs(moyenne) < 0.01)
    cas("l'ecart suit la difficulte", True,
        ecart_deb > float(R.ecartPlacement(normal)) > float(R.ecartPlacement(R.profil(800)))
        > float(R.ecartPlacement(expert)))
    ecarts = [float(R.ecartPlacement(p)) for _, p in valeurs]
    cas("l'ecart ne remonte jamais", True, all(ecarts[i] >= ecarts[i + 1] for i in range(len(ecarts) - 1)))
    cas("aucun ecart au-dela du plafond de securite", True,
        all(x <= float(R.ECART_MAX) for x in ecarts))
    cas("sans profil : aucune deviation", (0, 0), tuple(R.deviation(None, 0.0, 0.0)))
    cas("tirages absents : aucune deviation", (0, 0), tuple(R.deviation(debutant, None, None)))
    cas("tirages hors bornes : rien n'explose", True,
        abs(float(R.deviation(debutant, 99, -99)[0])) <= ecart_deb + 1e-9)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur calcule le profil", True, "Robot.profil(" in serveur)
    cas("le serveur utilise le delai de reflexion", True, "Robot.delai(" in serveur)
    cas("le serveur laisse le robot se tromper", True, "Robot.seTrompe(" in serveur)
    # (le serveur ne lit plus `gardeElixir` directement : il demande le seuil a Robot.gardeAttaque,
    # qui tient compte de l'ouverture — c'est le cas « exige plus d'elixir en ouverture » ci-dessous)
    cas("le serveur declenche la contre-attaque", True, "Robot.contreAttaque(" in serveur)
    cas("le serveur retient la voie defendue", True, "voieDefendue" in serveur)
    cas("le serveur connait l'ouverture", True, "Robot.enOuverture(" in serveur)
    cas("le serveur exige plus d'elixir en ouverture", True, "Robot.gardeAttaque(" in serveur)
    cas("le serveur devie la pose du robot", True, "Robot.deviation(" in serveur)
    # la defense ne doit PAS etre bridee par l'ouverture : elle passe avant, dans la meme decision
    cas("la defense reste prioritaire", True, serveur.index("elseif enDanger then") < serveur.index("Robot.gardeAttaque("))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : le robot s'adapte au joueur, sans jamais devenir inerte ni injouable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
