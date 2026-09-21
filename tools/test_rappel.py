# -*- coding: utf-8 -*-
"""Banc du RAPPEL DU COFFRE GRATUIT (src/shared/Rappel.lua + accueil), hors Studio.

Defaut corrige le 2026-09-20 : un coffre est offert toutes les 4 h, et RIEN ne le signalait. Le
compte a rebours vivait au fond de l'onglet EVENEMENTS, sur une ligne qu'il faut penser a aller
lire. Un joueur qui enchaine des parties depuis l'accueil pouvait laisser passer plusieurs coffres
dans la meme session — alors que c'est justement le rendez-vous cense faire revenir dans la journee.

Ce qu'il verifie :
  1. « pret » est vrai a zero seconde et en dessous, faux au-dessus ;
  2. l'attente se lit en heures, en minutes, et ne dit jamais « 0h00 » sur 30 secondes ;
  3. la ligne dit OU aller prendre le coffre quand il est la ;
  4. la pastille compte le coffre, les quetes finies non reclamees et le bonus du jour ;
  5. l'accueil emploie vraiment le module (sinon il serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Rappel.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"
ECO = ROOT / "src" / "server" / "Economie.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    hub = HUB.read_text(encoding="utf-8")
    eco = ECO.read_text(encoding="utf-8")

    # 1. PRET OU PAS
    cas("zero seconde : le coffre est la", True, R.pret(0))
    cas("un retard negatif aussi", True, R.pret(-120))
    cas("une seconde d'attente : pas encore", False, R.pret(1))
    cas("quatre heures : pas encore", False, R.pret(4 * 3600))

    # 2. ATTENTE LISIBLE
    cas("des heures", "3h07", R.attente(3 * 3600 + 7 * 60))
    cas("pile une heure", "1h00", R.attente(3600))
    cas("des minutes", "12 min", R.attente(12 * 60 + 30))
    # « 0h00 » sur 30 secondes laisserait croire que le coffre est deja la.
    cas("moins d'une minute se dit en toutes lettres", "moins d'une minute", R.attente(30))
    cas("zero aussi", "moins d'une minute", R.attente(0))
    cas("un negatif ne rend pas un temps a l'envers", "moins d'une minute", R.attente(-90))

    # 3. LA LIGNE
    pret = R.texte(0, "argent")
    cas("elle annonce le coffre", True, "COFFRE GRATUIT" in pret)
    cas("elle en dit le type", True, "argent" in pret)
    # Sans la destination, le joueur sait qu'il a quelque chose mais pas ou le prendre.
    cas("et OU aller le prendre", True, "EVENEMENTS" in pret)
    attente = R.texte(2 * 3600, "argent")
    cas("en attente, elle donne le delai", "Coffre gratuit dans 2h00", attente)
    cas("et ne crie pas", False, "COFFRE GRATUIT" in attente)

    # 4. COULEUR ET PASTILLE
    cas("pret : teinte chaude", True, list(R.teinte(0).values())[0] > list(R.teinte(0).values())[2])
    cas("les deux teintes se distinguent", True,
        list(R.teinte(0).values()) != list(R.teinte(3600).values()))
    cas("pastille visible quand le coffre est la", True, R.pastille(0))
    # Une pastille permanente ne veut plus rien dire.
    cas("pastille eteinte pendant l'attente", False, R.pastille(600))

    # 4 bis. LES QUETES TERMINEES COMPTENT AUSSI. Une quete finie ne se paie pas toute seule : elle
    # se reclame dans ce meme onglet. Sans elle dans la pastille, le joueur gardait des pieces
    # gagnees sur place, sans aucun signal une fois l'annonce de fin de quete passee.
    tbl = lua.table_from
    def q(finie, recue):
        return tbl({"finie": finie, "recue": recue})
    finie = tbl([q(True, False)])
    deux = tbl([q(True, False), q(True, False), q(False, False)])
    prise = tbl([q(True, True)])
    cas("une quete finie allume la pastille meme sans coffre", True, R.pastille(3600, finie))
    cas("et le chiffre le dit", "1", R.compte(3600, finie))
    cas("deux quetes finies : deux", "2", R.compte(3600, deux))
    cas("le coffre s'y ajoute", "3", R.compte(0, deux))
    # Une quete DEJA reclamee ne doit plus compter : la pastille ne s'eteindrait jamais.
    cas("une quete deja reclamee ne compte pas", "0", R.compte(3600, prise))
    cas("ni une quete non finie", "0", R.compte(3600, tbl([q(False, False)])))
    cas("pastille eteinte quand il n'y a rien", False, R.pastille(3600, prise))
    cas("sans liste de quetes, le coffre suffit", "1", R.compte(0, None))
    # 4 ter. LE BONUS DU JOUR (+50 pieces) se reclame au MEME endroit et ne se verse pas tout seul.
    cas("le bonus du jour allume la pastille a lui seul", True, R.pastille(3600, prise, True))
    cas("et compte pour un", "1", R.compte(3600, prise, True))
    cas("bonus deja pris : rien", "0", R.compte(3600, prise, False))
    cas("les trois s'additionnent", "4", R.compte(0, deux, True))
    # `nil` (profil sans ce champ) doit se lire comme « deja pris », pas comme « disponible ».
    cas("un champ absent ne cree pas de fausse alerte", "0", R.compte(3600, prise, None))

    # Plafond : une pastille de 18 pixels ne tient pas un nombre a deux chiffres.
    beaucoup = tbl([q(True, False) for _ in range(12)])
    cas("le compte est plafonne", "9+", R.compte(0, beaucoup))

    # 5. L'ACCUEIL S'EN SERT ----------------------------------------------------------------------
    cas("le hub charge le module", True, 'WaitForChild("Rappel")' in hub)
    # PLAFOND DE LUA : ce fichier est a 200 locales. Le module est range dans la table de ses
    # objets d'ecran ; deux locales de plus et le menu ne se chargeait PLUS DU TOUT
    # (« Out of local registers ... exceeded limit 200 », journal Studio du 2026-09-20).
    cas("sans ajouter une locale de plus", False, "local Rappel = require" in hub or "local rappel =" in hub)
    cas("la ligne vient du module", True, "montee.rappel.texte(reste, typeC, " in hub)
    plein = R.texte(0, "argent", True)
    cas("emplacements pleins : on n'envoie pas chercher un coffre refuse", True, "pleins" in plein and "t'attend" not in plein)
    cas("emplacements pleins : le coffre gratuit ne compte plus", 0, int(R.aPrendre(0, None, False, True)))
    cas("emplacements pleins : pas de pastille pour lui seul", False, R.pastille(0, None, False, True))
    cas("emplacements pleins : le bonus du jour compte encore", "1", R.compte(0, None, True, True))
    cas("les 4 appels du hub passent l'etat plein", 4, hub.count("bonusDispo, #(v"))
    cas("pas encore pret : l'attente prime meme si plein", True, R.texte(3600, "argent", True).startswith("Coffre gratuit dans"))
    cas("la couleur aussi", True, "local t = montee.rappel.teinte(reste)" in hub)
    # L'appel doit viser la FONCTION du module. Un « montee.montee.coffrePastille(reste) » ecrit
    # par erreur coupait tout le reste de l'affichage du profil SANS rien dire a l'ecran
    # (capture cap-coffre5.png du 2026-09-20 : ligne affichee, pastille absente).
    cas("la pastille suit la regle du module", True,
        "montee.coffrePastille.Visible = montee.rappel.pastille(reste, aPrendre, v.bonusDispo, #(v.coffres or {}) >= 4)" in hub)
    cas("elle recoit les quetes du profil", True,
        "local aPrendre = v.evenements and v.evenements.quetes or nil" in hub)
    cas("et affiche le chiffre", True,
        "montee.coffreCompte.Text = montee.rappel.compte(reste, aPrendre, v.bonusDispo, #(v.coffres or {}) >= 4)" in hub)
    cas("aucun appel bancal ne subsiste", False, "montee.montee." in hub)
    cas("elle est posee sur l'onglet EVENEMENTS", True, 'if o.nom == "evenements" then' in hub)
    # Le chiffre est mis a l'echelle : sans plafond de taille il deborde du rond (cap-pastille.png).
    cas("le chiffre tient dans la pastille", True, "montee.coffrePlafond.MaxTextSize" in hub)
    cas("elle est eteinte au depart", True, "montee.coffrePastille.Visible = false" in hub)
    # La barre d'onglets se construit APRES le premier affichage du profil : sans rattrapage, la
    # pastille restait eteinte jusqu'au profil suivant (capture cap-coffre4.png du 2026-09-20).
    cas("et rattrapee a sa creation", True,
        "montee.coffrePastille.Visible = montee.rappel.pastille(vue.evenements.coffreGratuitReste or 0," in hub)
    # Le chiffre vient du SERVEUR : l'ecran ne recalcule pas l'attente, il l'affiche.
    cas("le serveur envoie l'attente", True, "coffreGratuitReste = Economie.attenteCoffreGratuit" in eco)
    cas("et le type de coffre", True, "coffreGratuitType = Economie.COFFRE_GRATUIT_TYPE" in eco)
    cas("l'accueil lit ce champ", True, "v.evenements.coffreGratuitReste" in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : le coffre gratuit se signale a l'accueil, et l'onglet porte sa pastille")
    return 0


sys.exit(main())
