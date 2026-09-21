# -*- coding: utf-8 -*-
"""Banc du DEPLOIEMENT (src/shared/Deploiement.lua) : une unite qui arrive n'agit pas encore.

Defaut lu dans le code : `addEntity` posait `e.cooldown = 0` et rien n'empechait une unite de se
deplacer des sa premiere image. Une carte posee AGISSAIT donc instantanement :
  * aucun contre-jeu a la pose — poser une unite au contact d'un ennemi le frappait avant qu'il
    puisse reagir ;
  * le jeu mentait a l'oeil — l'animation d'arrivee dure 0,45 s (chute, contact au sol vers
    0,25 s, rebond) et l'unite frappait pendant qu'elle etait encore en l'air ;
  * l'invulnerabilite de pose protegeait une unite qui, elle, pouvait deja agir.

Ce qu'il verifie :
  1. la duree de la REGLE est exactement celle de l'ANIMATION (aucune des deux ne peut deriver
     sans que ce banc le dise) ;
  2. l'unite n'est pas prete avant, l'est pile a l'echeance, et le reste ensuite ;
  3. une unite sans instant de pose (une tour) est TOUJOURS prete — on ne fige rien par accident ;
  4. la duree est bornee, et une carte peut la regler sans sortir des bornes ;
  5. la fenetre de contre-jeu existe vraiment : le deploiement dure PLUS longtemps que
     l'invulnerabilite de pose, sinon l'unite serait protegee tout le temps ou elle est inerte ;
  6. SIMULATION image par image : l'unite ne frappe pas pendant sa chute, et frappe apres ;
  7. le serveur applique la regle, et seulement aux unites (pas aux tours).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
SRC = SHARED / "Deploiement.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — les unites frappent en tombant du ciel" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    D = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    # Les DEUX autres verites du jeu sont LUES dans leur source, pas recopiees ici. On ne peut pas
    # charger Effets.lua hors du moteur (il utilise Color3), donc on lit la constante elle-meme :
    # si quelqu'un la change, ce banc le verra.
    import re as _re

    def constante(fichier, nom):
        texte = (SHARED / fichier).read_text(encoding="utf-8")
        m = _re.search(nom + r"\s*=\s*([\d.]+)", texte)
        if not m:
            print("ROUGE : %s introuvable dans %s" % (nom, fichier))
            sys.exit(1)
        return float(m.group(1))

    duree = float(D.DUREE)
    animation = constante("Effets.lua", "Effets.APPARITION_DUREE")
    invuln = constante("Statuts.lua", "Statuts.INVULN_POSE")
    print("  deploiement %.2f s | animation d'arrivee %.2f s | invulnerabilite de pose %.2f s"
          % (duree, animation, invuln))

    # 1. la regle colle a l'image
    cas("la duree de la regle est celle de l'animation", animation, duree)

    # 2. avant / pendant / apres
    cas("a la pose : pas prete", False, D.pret(0, duree))
    cas("a mi-chute : pas prete", False, D.pret(duree / 2, duree))
    cas("juste avant l'echeance : pas prete", False, D.pret(duree - 0.001, duree))
    cas("a l'echeance pile : prete", True, D.pret(duree, duree))
    cas("apres : prete", True, D.pret(duree + 1, duree))
    cas("restant a la pose", duree, round(float(D.restant(0, duree)), 6))
    cas("restant a mi-chemin", round(duree / 2, 6), round(float(D.restant(duree / 2, duree)), 6))
    cas("restant apres l'echeance : zero", 0.0, float(D.restant(duree * 3, duree)))

    # 3. une unite sans pose connue n'est jamais figee
    cas("sans instant de pose : prete", True, D.pret(None, duree))
    cas("et rien a attendre", 0.0, float(D.restant(None, duree)))

    # 4. bornes et reglage par carte
    cas("carte sans reglage : duree par defaut", duree, float(D.duree(None)))
    cas("carte sans reglage (table vide) : idem", duree, float(D.duree(lua.table_from({}))))
    cas("une carte peut regler sa duree", 0.8,
        float(D.duree(lua.table_from(dict(deploiement=0.8)))))
    cas("une duree farfelue est plafonnee", float(D.DUREE_MAX),
        float(D.duree(lua.table_from(dict(deploiement=99)))))
    cas("une duree negative est ramenee a zero", 0.0,
        float(D.duree(lua.table_from(dict(deploiement=-5)))))

    # 5. LA FENETRE DE CONTRE-JEU. Si le deploiement etait plus court que l'invulnerabilite,
    # l'unite serait protegee pendant toute sa periode d'inaction : l'adversaire n'aurait aucun
    # moment pour la punir, et la regle ne servirait a rien.
    fenetre = duree - invuln
    print("  fenetre ou l'unite est vulnerable ET inerte : %.2f s" % fenetre)
    cas("le deploiement dure plus que l'invulnerabilite", True, duree > invuln)
    cas("la fenetre de contre-jeu n'est pas nulle", True, fenetre > 0)

    # 6. SIMULATION image par image d'une pose au contact d'un ennemi
    dt = 1 / 30.0
    coups_avant, coups_apres, t = 0, 0, 0.0
    while t < duree * 3:
        if D.pret(t, duree):
            coups_apres += 1
        else:
            coups_avant += 1
        t += dt
    print("  sur %d images : %d inactives (chute) puis %d actives"
          % (coups_avant + coups_apres, coups_avant, coups_apres))
    cas("elle ne frappe pas pendant sa chute", True, coups_avant >= 13)
    cas("puis elle frappe", True, coups_apres > 0)
    # elle touche le sol a 55 % de l'animation : a ce moment-la elle doit encore etre inerte
    cas("elle est encore inerte au contact du sol", False, D.pret(animation * 0.55, duree))

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Deploiement")' in serveur)
    cas("le serveur calcule la duree a la pose", True, "Deploiement.duree(card)" in serveur)
    cas("le serveur empeche d'agir pendant l'arrivee", True,
        "not Deploiement.pret(horloge - (e.poseT or -99), e.dureeDeploiement)" in serveur)
    cas("mais seulement pour les unites, pas les tours", True,
        "if target and not e.isBuilding" in serveur)
    cas("le module est livre dans la place", True,
        "shared/Deploiement.lua" in BUILD.read_text(encoding="utf-8"))

    # LE MONTRER A L'ECRAN. Defaut mesure le 2026-09-21 : la regle etait appliquee et expliquee au
    # manuel, mais rien ne la montrait en jeu. Celui qui pose ignorait quand sa carte devient
    # active ; celui d'en face ne voyait pas qu'il avait encore une demi-seconde pour reagir.
    cas("a peine posee, l'avancement est nul", 0, D.avancement(0, 0.45))
    cas("a mi-parcours, la moitie", 0.5, D.avancement(0.225, 0.45))
    cas("au bout, il est plein", 1, D.avancement(0.45, 0.45))
    cas("et ne depasse jamais 1", 1, D.avancement(99, 0.45))
    cas("une duree nulle rend une unite deja prete", 1, D.avancement(0, 0))
    # L'anneau se REFERME : large au depart (on le voit), serre a la fin (le geste EST le signal).
    cas("l'anneau part large", D.ANNEAU_LARGE, D.diametreAnneau(0))
    cas("et finit serre", D.ANNEAU_SERRE, D.diametreAnneau(1))
    cas("il ne fait que retrecir", True, D.diametreAnneau(0.3) > D.diametreAnneau(0.7))
    cas("une valeur aberrante reste bornee", D.ANNEAU_SERRE, D.diametreAnneau(5))
    # Il s'efface en se refermant : sinon sa disparition passerait pour un defaut d'affichage.
    cas("il s'efface en chemin", True, D.transparenceAnneau(0.9) > D.transparenceAnneau(0.1))
    cas("mais reste visible au depart", True, D.transparenceAnneau(0) < 0.3)

    # EN GEOMETRIE, et mis a jour a CHAQUE image : une etiquette flottante n'apparait sur aucune
    # capture du moteur, et une unite en cours de deploiement NE BOUGE PAS — son anneau serait
    # reste fige puis oublie sur le terrain s'il etait rafraichi dans le deplacement.
    cas("l'anneau est une vraie piece posee au sol", True,
        'a.Name = "AnneauDeploiement"' in serveur and "Enum.PartType.Cylinder" in serveur)
    # Il est rafraichi pour TOUTE entite vivante, et non dans `animer` (qui ne tourne que pour les
    # unites) ni dans le deplacement (une unite en deploiement ne bouge pas). Mesure du
    # 2026-09-21 : place dans `animer`, un batiment pose gardait son anneau FIGE pour toujours —
    # le journal comptait « 112 anneaux vivants » pour trois poses.
    # Et AVANT le filtre `e.active` : place apres, l'anneau d'une entite inactive n'etait jamais
    # rafraichi et restait fige a son diametre de depart (journal du 2026-09-21 : « 112 anneaux
    # VISIBLES » pour trois poses reelles). Un anneau fige ment : il annonce « pas encore prete ».
    cas("l'anneau est rafraichi avant le filtre des entites actives", True,
        serveur.index("majAnneauDeploiement(e)", serveur.index("for _, e in ipairs(entities) do"))
        < serveur.index("if e.alive and e.active then"))
    cas("et plus depuis l'animation des seules unites", False,
        "local function animer(e, dt)" + chr(10) + chr(9) + "majAnneauDeploiement(e)" in serveur)
    cas("sa taille vient du module", True, "Deploiement.diametreAnneau(avance)" in serveur)
    cas("son effacement aussi", True, "Deploiement.transparenceAnneau(avance)" in serveur)
    # Il DISPARAIT a l'instant ou l'unite devient active : c'est ce qui en fait un signal.
    cas("il est detruit une fois l'unite prete", True,
        "e.anneauDeploiement:Destroy()" in serveur and "e.anneauDeploiement = nil" in serveur)

    # L'INVULNERABILITE DE POSE, montree par la COULEUR de l'anneau. Defaut mesure le 2026-09-21 :
    # l'unite qui arrive est intouchable pendant 0,35 s — c'est ce qui empeche le « sort pile sur
    # la pose ». Applique et explique au manuel, mais invisible : celui qui lance son sort croit
    # l'avoir rate, celui qui pose ignore qu'il est protege.
    cas("a l'arrivee, elle est intouchable", True, D.intouchable(0, 0.35))
    cas("juste avant la fin aussi", True, D.intouchable(0.34, 0.35))
    cas("a l'instant pile, elle ne l'est plus", False, D.intouchable(0.35, 0.35))
    cas("ni apres", False, D.intouchable(1, 0.35))
    cas("sans duree, aucune protection", False, D.intouchable(0, 0))
    blanc = list(D.couleurAnneau(0.1, 0.35).values())
    apres = list(D.couleurAnneau(0.4, 0.35).values())
    cas("intouchable : anneau blanc", [255, 255, 255], blanc)
    cas("puis une autre couleur", True, apres != blanc)
    # Elle doit TRANCHER, pas seulement differer : sous l'eclairage bleu d'une arene de nuit, un or
    # pale se lisait comme du blanc sur la photo (capture cap-invuln.png du 2026-09-21).
    cas("et cette couleur tranche vraiment", True, apres[2] < 120 and apres[0] > 200)
    # La protection s'arrete AVANT la fin du deploiement (0,35 s contre 0,45 s) : les deux temps
    # doivent donc se distinguer, sinon l'anneau ne raconterait qu'une seule des deux regles.
    cas("les deux temps de la pose se voient", True,
        list(D.couleurAnneau(0.2, 0.35).values()) != list(D.couleurAnneau(0.44, 0.35).values()))
    cas("le serveur applique la couleur", True,
        "Deploiement.couleurAnneau(horloge - (e.poseT or 0), Statuts.INVULN_POSE)" in serveur)
    # La duree vient du module qui FAIT respecter l'invulnerabilite, pas d'une copie.
    cas("avec la duree du module qui l'applique", True, "Statuts.INVULN_POSE" in serveur)

    # AUCUNE COQUE : essayee puis RETIREE le 2026-09-21. Trois formes tentees (couleur de
    # l'anneau, second disque, coque spherique), sept captures, aucune lisible : les unites
    # portent deja un halo lumineux qui absorbe ce qu'on pose par-dessus. La regle reste
    # appliquee par le serveur et expliquee au manuel (section LA POSE). Ce banc empeche que
    # l'effet revienne par inadvertance, avec son cout et sans sa preuve.
    cas("aucune coque n'est posee sur l'unite", False,
        "BulleInvulnerabilite" in serveur or "haloInvuln" in serveur)
    cas("ni dans le module", False, "FACTEUR_BULLE" in SRC.read_text(encoding="utf-8"))
    # L'anneau de deploiement, lui, reste : c'est le signal qui A ete prouve a l'ecran.
    cas("l'anneau de deploiement reste en place", True, 'a.Name = "AnneauDeploiement"' in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : une unite qui tombe du ciel ne frappe plus avant d'avoir touche le sol")
    return 0


if __name__ == "__main__":
    sys.exit(main())
