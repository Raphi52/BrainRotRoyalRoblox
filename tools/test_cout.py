# -*- coding: utf-8 -*-
"""Banc de CE QUI MANQUE POUR POSER UNE CARTE (src/shared/Cout.lua), hors Studio.

Defaut corrige le 2026-09-20 : une carte trop chere etait simplement PALIE. Rien ne disait
pourquoi, ni combien il manquait : le joueur voyait quatre cartes, deux ternes, et devait faire la
soustraction lui-meme — en pleine partie, a la seconde. Pire, la carte interdite par le tutoriel
etait palie de la MEME facon avec une nuance differente : deux causes opposees (« attends deux
secondes » et « pas maintenant, suis l'etape ») se lisaient pareil.

Ce qu'il verifie :
  1. les trois etats, et leur priorite (une carte interdite le reste meme si l'elixir suffit) ;
  2. le chiffre manquant, jamais negatif ;
  3. la part payee, bornee, y compris sur un cout nul ;
  4. le libelle : le cout nu quand on peut jouer, « IL MANQUE n » sinon, et un texte pour l'interdit ;
  5. les opacites et les teintes se distinguent vraiment (sinon deux etats se liraient pareil) ;
  6. le client l'emploie REELLEMENT pour le texte, l'opacite et la jauge.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Cout.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    C = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    client = CLIENT.read_text(encoding="utf-8")

    # 1. les trois etats
    cas("assez d'elixir : jouable", C.JOUABLE, C.etat(4, 5, False))
    cas("juste le compte : jouable (>=, pas >)", C.JOUABLE, C.etat(4, 4, False))
    cas("pas assez : il manque", C.MANQUE, C.etat(4, 3, False))
    # PRIORITE : le tutoriel passe devant l'elixir. Sinon la carte interdite passerait pour
    # jouable des que l'elixir monte, et le joueur essaierait pour rien.
    cas("interdite par le tutoriel : bloquee meme avec l'elixir", C.BLOQUEE, C.etat(4, 10, True))

    # 2. le chiffre manquant
    cas("il manque 2", 2, C.manque(5, 3))
    cas("rien ne manque", 0, C.manque(3, 5))
    cas("jamais negatif", 0, C.manque(0, 9))
    # L'ELIXIR DU SERVEUR EST A VIRGULE (il monte en continu). Sans arrondi, la carte affichait
    # « IL MANQUE 0.8746849303799018 » - vu a l'ecran. Au SUPERIEUR : a 0,9 pres, il manque bien
    # un point d'elixir entier pour payer.
    cas("un manque fractionnaire s'arrondit au superieur", 1, C.manque(4, 3.13))
    cas("un manque a peine entame compte pour 1", 1, C.manque(4, 3.99))
    cas("et le libelle ne montre jamais de virgule", "IL MANQUE 2", C.libelle(5, 3.2, False))

    # 3. la part payee
    cas("moitie payee", 0.5, C.part(4, 2))
    cas("pleine quand on peut jouer", 1, C.part(4, 9))
    cas("vide sans elixir", 0, C.part(4, 0))
    cas("un cout nul ne divise pas par zero", 1, C.part(0, 0))

    # 4. le libelle
    cas("jouable : le cout nu", "4 elixir", C.libelle(4, 5, False))
    cas("trop chere : ce qui manque", "IL MANQUE 2", C.libelle(5, 3, False))
    cas("interdite : elle le dit", "PAS CETTE CARTE", C.libelle(5, 9, True))
    # Le chiffre affiche doit etre le VRAI manque : un « IL MANQUE 1 » sur 2 d'ecart ferait
    # attendre le joueur pour rien.
    cas("le chiffre colle au manque reel", "IL MANQUE 3", C.libelle(6, 3, False))

    # 5. les etats se DISTINGUENT a l'ecran
    op = [C.opacite(C.JOUABLE), C.opacite(C.MANQUE), C.opacite(C.BLOQUEE)]
    cas("trois opacites distinctes", 3, len(set(op)))
    cas("la carte jouable est pleinement opaque", 0, op[0])
    cas("l'interdite s'efface plus que celle qui attend", True, op[2] > op[1] > op[0])
    teintes = [tuple(C.teinte(e).values()) for e in (C.JOUABLE, C.MANQUE, C.BLOQUEE)]
    cas("trois teintes distinctes", 3, len(set(teintes)))
    # « il manque » est orange (chaud) : c'est l'etat sur lequel le joueur doit agir (attendre).
    cas("le manque est chaud (plus de rouge que de bleu)", True, teintes[1][0] > teintes[1][2])

    # 6. REPERES SUR LA JAUGE D'ELIXIR ------------------------------------------------------------
    # Defaut mesure le 2026-09-20 : la jauge etait une barre lisse avec un chiffre. Le joueur
    # voyait « 3 » mais pas OU s'arrete le prochain palier utile ; il devait relire ses quatre
    # cartes et comparer.
    tbl = lua.table_from
    r = [dict(x) for x in C.reperes(tbl([4, 2, 3, 2]), 10).values()]
    cas("un trait par cout DIFFERENT (les doublons fondent)", 3, len(r))
    cas("du moins cher au plus cher", [2, 3, 4], [x["cout"] for x in r])
    cas("place sur la jauge = cout / plafond", 0.4, r[2]["part"])
    cas("une main vide ne trace rien", 0, len(list(C.reperes(tbl([]), 10).values())))
    # Un cout hors jauge tracerait un trait hors de la barre.
    cas("un cout au-dela du plafond est ignore", 1, len(list(C.reperes(tbl([3, 12]), 10).values())))
    cas("un cout nul aussi", 1, len(list(C.reperes(tbl([0, 3]), 10).values())))

    # 6. LE CLIENT S'EN SERT VRAIMENT --------------------------------------------------------------
    cas("le client charge le module", True, 'WaitForChild("Cout")' in client)
    cas("le texte de la carte vient du module", True,
        "Cout.libelle(card.cost, s.elixir, horsEtape)" in client)
    # Trois lignes de texte rendaient le bouton illisible (il est mis a l'echelle) : l'etiquette
    # d'effet s'efface tant que la carte n'est pas jouable.
    cas("l'etiquette d'effet s'efface quand la carte n'est pas jouable", True,
        'local etiquette = (etat == Cout.JOUABLE and tag ~= "")' in client)
    cas("l'opacite aussi", True, "Cout.opacite(etat)" in client)
    cas("la couleur du texte aussi", True, "Cout.teinte(etat)" in client)
    cas("la jauge suit la part payee", True,
        "Cout.part(card.cost, s.elixir)" in client)
    cas("elle ne s'affiche que s'il manque quelque chose", True,
        "b.fondJauge.Visible = etat == Cout.MANQUE" in client)
    # Le texte du bouton est mis a l'echelle : sans marge reservee, « IL MANQUE 3 » passait SOUS
    # la jauge et se coupait (capture du 2026-09-20).
    cas("le texte laisse la place a la jauge", True,
        "b.marge.PaddingBottom = UDim.new(0, b.fondJauge.Visible and 18 or 0)" in client)
    # NOM LONG : « TextScaled » ne descend pas en dessous d'une taille minimale. Sur un nom qui
    # passe deja sur trois lignes, la derniere ligne (le cout) sortait du bouton — capture
    # cap-etiquettes.png du 2026-09-21, avec l'etiquette CHARGE en plus.
    cas("le texte peut rapetisser assez pour tenir", True,
        "buttons[i].plafond.MinTextSize = 8" in client)
    # Et le nom lui-meme est ramene a deux mots en main : c'est le nombre de LIGNES qui debordait.
    cas("le nom affiche en main est raccourci", True,
        'b.button.Text = Fiche.nomMain(card.name)' in client)

    # Une case vide ne doit pas garder la jauge de la carte precedente.
    cas("une case vide efface sa jauge", True,
        "if not card then\n\t\t\tb.fondJauge.Visible = false" in client)
    # L'ancien calcul en dur ne doit plus vivre a cote du module : deux verites divergeraient.
    cas("plus d'opacite ecrite en dur dans la main", False,
        "b.button.BackgroundTransparency = 0.6" in client)
    cas("les traits de la jauge viennent du module", True, "Cout.reperes(coutsMain, 10)" in client)
    cas("ils suivent la main courante", True, "Cards.byId[mainCourante[i]]" in client)
    # Un trait deja franchi s'allume : sans cela, on ne verrait pas combien de cartes sont payables.
    cas("un trait franchi se distingue", True, "local atteint = s.elixir >= rep.cout" in client)
    cas("et un trait sans carte disparait", True, "m.Visible = rep ~= nil" in client)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : chaque carte dit ce qui lui manque, et la jauge montre le chemin restant")
    return 0


sys.exit(main())
