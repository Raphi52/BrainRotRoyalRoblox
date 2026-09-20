# -*- coding: utf-8 -*-
"""Banc de la SERIE DE VICTOIRES (src/server/Economie.lua), hors Studio.

Pourquoi : la 10e victoire rapportait exactement autant que la premiere. Rien ne recompensait le
fait de rester une partie de plus — le defaut le plus cher d'un jeu de sessions courtes.

Ce qu'il verifie :
  1. le bonus est nul a la premiere victoire, puis monte de 10 pieces par victoire enchainee ;
  2. il est PLAFONNE (une serie infinie ne donne pas un gain infini) ;
  3. une defaite, puis une egalite, remettent la serie a zero ;
  4. le bonus se retrouve VRAIMENT dans les pieces versees et dans le compte-rendu ;
  5. un profil sauvegarde AVANT cette regle continue de marcher (retro-compatibilite).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harnais_economie import charger, joueur, nouveau_lua  # noqa: E402

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = nouveau_lua()
    Economie = charger(lua)
    if Economie.bonusSerie is None:
        print("ROUGE : Economie.bonusSerie absent — aucune serie de victoires")
        return 1

    # 1 + 2. fonction pure
    cas("aucune serie : pas de bonus", 0, Economie.bonusSerie(0))
    cas("1re victoire : pas encore de bonus", 0, Economie.bonusSerie(1))
    cas("2e victoire d'affilee : +10", 10, Economie.bonusSerie(2))
    cas("4e victoire d'affilee : +30", 30, Economie.bonusSerie(4))
    plafond = Economie.SERIE_MAX * 10
    cas("bonus plafonne", plafond, Economie.bonusSerie(50))
    cas("le plafond n'est pas depasse a 999", plafond, Economie.bonusSerie(999))

    # 3 + 4. en situation
    j = joueur(lua, "Serge", 7)
    Economie.charger(j)
    p = Economie.profil(j)
    p.pieces = 0
    r1 = Economie.recompenser(j, "victoire", False)
    cas("1re victoire : 30 pieces", 30, int(r1.pieces))
    cas("serie a 1", 1, int(r1.serie))
    r2 = Economie.recompenser(j, "victoire", False)
    cas("2e victoire : 30 + 10", 40, int(r2.pieces))
    r3 = Economie.recompenser(j, "victoire", False)
    cas("3e victoire : 30 + 20", 50, int(r3.pieces))
    cas("solde = 30 + 40 + 50", 120, int(p.pieces))
    rd = Economie.recompenser(j, "defaite", False)
    cas("une defaite casse la serie", 0, int(rd.serie))
    cas("defaite : pas de bonus de serie", 0, int(rd.bonusSerie))
    Economie.recompenser(j, "victoire", False)
    re = Economie.recompenser(j, "egalite", False)
    cas("une egalite casse aussi la serie", 0, int(re.serie))

    # 5. profil d'avant la regle (aucun champ `serie` sauvegarde)
    vieux = joueur(lua, "Ancien", 8)
    Economie.charger(vieux)
    pv = Economie.profil(vieux)
    pv.serie = None
    rv = Economie.recompenser(vieux, "victoire", False)
    cas("profil ancien : la serie repart de 1 sans erreur", 1, int(rv.serie))
    cas("profil ancien : gain normal", 30, int(rv.pieces))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : enchainer les victoires paye, et une seule defaite remet le compteur a zero")
    return 0


if __name__ == "__main__":
    sys.exit(main())
