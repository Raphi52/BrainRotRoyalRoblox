# -*- coding: utf-8 -*-
"""Banc de L'ANNONCE D'UNE QUETE TERMINEE (src/shared/Quetes.lua + serveur + ecran).

Defaut corrige le 2026-09-20 : les quetes du jour s'avancaient en SILENCE. Une quete atteinte en
pleine partie (« Detruire 4 tours », « Poser 25 cartes ») ne produisait rien : ni son, ni texte.
Et comme la recompense n'est pas versee toute seule — elle se RECLAME dans l'ecran des evenements —
un joueur qui ne rouvrait pas cet ecran finissait sa session avec des pieces gagnees jamais vues.

Ce qu'il verifie :
  1. le franchissement STRICT (une quete deja finie ne se re-annonce pas a chaque carte posee) ;
  2. l'intitule rempli, et les trois lignes dont celle qui dit QUOI FAIRE ;
  3. l'extinction par le DELAI, sans accuse de reception du client ;
  4. le serveur pose l'annonce au bon endroit et l'etat de partie l'emporte ;
  5. l'ecran l'affiche vraiment (sinon le module serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Quetes.lua"
ECO = ROOT / "src" / "server" / "Economie.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    Q = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    eco = ECO.read_text(encoding="utf-8")
    serveur = SERVEUR.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")

    # 1. FRANCHISSEMENT STRICT
    cas("atteindre la cible l'annonce", True, Q.vientDeFinir(3, 4, 4))
    cas("la depasser d'un coup aussi", True, Q.vientDeFinir(0, 9, 4))
    cas("en dessous : rien", False, Q.vientDeFinir(1, 2, 4))
    # LE PIEGE : sans « avant < cible », chaque carte posee APRES la fin rejouerait l'annonce.
    cas("une quete deja finie ne se re-annonce pas", False, Q.vientDeFinir(4, 5, 4))
    cas("ni la suivante", False, Q.vientDeFinir(12, 13, 4))
    cas("une cible a zero n'annonce rien en boucle", False, Q.vientDeFinir(1, 2, 0))

    # 2. LE TEXTE
    cas("le gabarit est rempli", "Gagner 2 parties", Q.intitule("Gagner %d parties", 2))
    cas("un texte sans trou passe tel quel", "Jouer", Q.intitule("Jouer", 3))
    lignes = [x for x in Q.lignes("Detruire %d tours", 4, 70).values()]
    cas("trois lignes", 3, len(lignes))
    cas("la premiere nomme l'evenement", "QUETE TERMINEE", lignes[0])
    cas("la deuxieme dit laquelle", "Detruire 4 tours", lignes[1])
    # La recompense n'est PAS automatique : une annonce qui se contenterait de feliciter
    # laisserait les pieces sur place. La troisieme ligne dit quoi faire.
    cas("la troisieme dit le gain", True, "+70 pieces" in lignes[2])
    cas("et ou le prendre", True, "reclamer au menu" in lignes[2])

    # 3. EXTINCTION PAR LE DELAI
    cas("visible a l'instant de la pose", True, Q.encoreVisible(100, 100))
    cas("visible juste avant la fin", True, Q.encoreVisible(100, 100 + float(Q.DUREE) - 0.1))
    cas("eteinte apres le delai", False, Q.encoreVisible(100, 100 + float(Q.DUREE)))
    cas("rien a montrer sans annonce", False, Q.encoreVisible(None, 500))
    cas("une horloge qui recule ne la ressuscite pas", False, Q.encoreVisible(100, 50))

    # 4. LE SERVEUR LA POSE -----------------------------------------------------------------------
    cas("l'economie charge le module", True, 'WaitForChild("Quetes")' in eco)
    cas("l'avancee compare AVANT et APRES", True,
        "local avant = q.faits[type] or 0" in eco)
    cas("et pose l'annonce au franchissement", True,
        "Quetes.vientDeFinir(avant, q.faits[type], quete.cible)" in eco)
    cas("avec les lignes du module", True,
        "lignes = Quetes.lignes(quete.texte, quete.cible, quete.gain)" in eco)
    cas("le serveur sait la relire", True, "function Economie.queteAnnonce(player, maintenant)" in eco)
    cas("et c'est le DELAI qui l'eteint", True,
        "Quetes.encoreVisible(p.queteAnnonce.pose" in eco)
    cas("l'etat de partie l'emporte", True, "queteFinie = Economie.queteAnnonce(player)," in serveur)

    # 5. L'ECRAN L'AFFICHE ------------------------------------------------------------------------
    cas("le cadre existe", True, "hud.quete.cadre = Instance.new(\"Frame\")" in client)
    cas("il suit l'etat", True, "hud.majQuete(s.queteFinie)" in client)
    cas("il disparait sans annonce", True, "hud.quete.cadre.Visible = q ~= nil" in client)
    cas("les lignes viennent du serveur, pas de l'ecran", True,
        "(q and q.lignes and q.lignes[i]) or \"\"" in client)
    # Un son rejoue a chaque image du jeu bourdonnerait : il ne part qu'a l'apparition.
    cas("un seul son, a l'apparition", True, "if q and hud.quete.vue ~= q.pose then" in client)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : la quete qui se termine est nommee a l'ecran, et dit ou prendre sa recompense")
    return 0


sys.exit(main())
