# -*- coding: utf-8 -*-
"""Banc des QUETES DU JOUR et du COFFRE GRATUIT (src/server/Economie.lua), hors Studio.

Pourquoi : le jeu n'avait qu'UN rendez-vous par jour (le bonus quotidien, pris en trois secondes).
Rien ne donnait un but pendant la session, ni une raison de repasser dans la journee.

Ce qu'il verifie :
  1. les quetes du jour sont DETERMINISTES (memes quetes pour tous le meme jour) et changent
     de jour en jour ;
  2. l'avancee ne compte que ce qui concerne une quete du jour, et ne deborde pas la cible ;
  3. une quete non finie est refusee, une quete finie paie UNE SEULE fois ;
  4. le changement de jour remet l'avancee a zero (sans effacer les pieces gagnees) ;
  5. le coffre gratuit attend 4 h, refuse si les emplacements sont pleins, et repart pour 4 h ;
  6. la vue envoyee au hub porte tout ce qu'il affiche ;
  7. un profil sauvegarde AVANT cette regle continue de marcher ;
  8. le serveur de jeu fait REELLEMENT avancer les quetes et le hub les affiche.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from harnais_economie import charger, joueur, nouveau_lua  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def ids(t):
    return [t[i].id for i in range(1, len(t) + 1)]


def main():
    lua = nouveau_lua()
    Economie = charger(lua)
    if Economie.quetesDuJour is None:
        print("ROUGE : Economie.quetesDuJour absent — aucune quete quotidienne")
        return 1

    # 1. deterministe et tournant
    jour = int(Economie.jourDe(1758326400))  # 2025-09-20 00:00 UTC
    a = ids(Economie.quetesDuJour(jour))
    b = ids(Economie.quetesDuJour(jour))
    c = ids(Economie.quetesDuJour(jour + 1))
    cas("3 quetes par jour", 3, len(a))
    cas("memes quetes pour tous le meme jour", a, b)
    cas("les quetes changent le lendemain", True, a != c)
    cas("aucune quete en double dans la journee", 3, len(set(a)))

    # 2 + 3. avancee et reclamation
    j = joueur(lua, "Quentin", 11)
    Economie.charger(j)
    p = Economie.profil(j)
    p.pieces = 0
    vq = Economie.vueQuetes(j)
    premiere = vq.quetes[1]
    cible, gain, qid = int(premiere.cible), int(premiere.gain), premiere.id
    ok, motif = Economie.reclamerQuete(j, qid)
    cas("quete non finie : refusee", (False, "pas encore finie"), (ok, motif))
    for _ in range(cible):
        Economie.avancerQuete(j, qid, 1)
    cas("l'avancee est bien comptee", cible, int(Economie.vueQuetes(j).quetes[1].fait))
    Economie.avancerQuete(j, qid, 10)
    cas("l'affichage ne depasse jamais la cible", cible, int(Economie.vueQuetes(j).quetes[1].fait))
    ok, montant = Economie.reclamerQuete(j, qid)
    cas("quete finie : payee", True, ok)
    cas("le gain annonce est verse", gain, int(p.pieces))
    ok2, motif2 = Economie.reclamerQuete(j, qid)
    cas("on ne la reclame pas deux fois", (False, "deja recue"), (ok2, motif2))
    ok3, motif3 = Economie.reclamerQuete(j, "quete_qui_nexiste_pas")
    cas("quete inconnue refusee", (False, "quete inconnue"), (ok3, motif3))

    # un type qui n'est PAS une quete du jour ne fait rien avancer
    absents = [q.id for q in Economie.QUETES.values() if q.id not in ids(Economie.quetesDuJour(
        int(Economie.jourDe(None))))]
    if absents:
        avant = [int(x.fait) for x in Economie.vueQuetes(j).quetes.values()]
        Economie.avancerQuete(j, absents[0], 5)
        apres = [int(x.fait) for x in Economie.vueQuetes(j).quetes.values()]
        cas("un evenement hors quete du jour ne compte pas", avant, apres)

    # 4. changement de jour
    p.quetes.jour = int(p.quetes.jour) - 1  # on fait comme si l'avancee datait d'hier
    neuf = Economie.vueQuetes(j)
    cas("nouveau jour : avancee remise a zero", 0, int(neuf.quetes[1].fait))
    cas("nouveau jour : rien n'est deja recu", False, bool(neuf.quetes[1].recue))
    cas("les pieces gagnees hier restent", gain, int(p.pieces))

    # 5. coffre gratuit
    cas("delai de 4 h", 4 * 3600, int(Economie.COFFRE_GRATUIT_DELAI))
    cas("attente pleine juste apres l'avoir pris", 4 * 3600, int(Economie.attenteCoffreGratuit(1000, 1000)))
    cas("attente a moitie ecoulee", 2 * 3600, int(Economie.attenteCoffreGratuit(1000, 1000 + 2 * 3600)))
    cas("attente finie = 0", 0, int(Economie.attenteCoffreGratuit(1000, 1000 + 5 * 3600)))
    p.dernierCoffreGratuit = 0
    p.coffres = lua.eval("{}")
    okc, coffre = Economie.reclamerCoffreGratuit(j)
    cas("premier coffre gratuit donne", True, okc)
    cas("c'est bien un coffre d'argent", "argent", str(coffre) if okc else None)
    cas("il occupe un emplacement", 1, len(p.coffres))
    okc2, motifc2 = Economie.reclamerCoffreGratuit(j)
    cas("pas deux coffres d'affilee", False, okc2)
    cas("le refus dit quand revenir", True, "revenir dans" in str(motifc2))
    # emplacements pleins
    p.dernierCoffreGratuit = 0
    for _ in range(int(Economie.EMPLACEMENTS)):
        Economie.gagnerCoffre(j, "bois")
    okc3, motifc3 = Economie.reclamerCoffreGratuit(j)
    cas("emplacements pleins : refuse", (False, "emplacements pleins"), (okc3, motifc3))

    # 6. vue pour le hub
    v = Economie.vue(j)
    cas("la vue porte les evenements", True, v.evenements is not None)
    cas("la vue porte les 3 quetes", 3, len(v.evenements.quetes))
    cas("la vue porte l'attente du coffre", True, v.evenements.coffreGratuitReste is not None)

    # 7. profil d'avant la regle
    vieux = joueur(lua, "Ancien", 12)
    Economie.charger(vieux)
    pv = Economie.profil(vieux)
    pv.quetes = None
    pv.dernierCoffreGratuit = None
    vv = Economie.vueQuetes(vieux)
    cas("profil ancien : quetes reconstruites", 3, len(vv.quetes))
    cas("profil ancien : coffre gratuit disponible", 0, int(vv.coffreGratuitReste))

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")
    cas("le serveur compte les cartes posees", True, 'avancerQuete(joueur, "cartes"' in serveur)
    cas("le serveur compte les sorts", True, '"sorts", 1)' in serveur)
    cas("le serveur compte les tours detruites", True, '"tours", 1)' in serveur)
    cas("le serveur compte les victoires", True, '"victoires", 1)' in serveur)
    cas("le serveur accepte la reclamation", True, 'Economie.reclamerQuete(' in serveur)
    cas("le serveur donne le coffre gratuit", True, 'Economie.reclamerCoffreGratuit(' in serveur)
    cas("le hub affiche les quetes", True, "QUETES DU JOUR" in hub)
    cas("le hub affiche le coffre gratuit", True, "COFFRE GRATUIT" in hub)
    # Piege deja paye une fois : une fonction du hub portait DEJA le nom `majEvenements` (pastille
    # d'onglet). Une seconde fonction du meme nom l'ecrasait, et les quetes restaient vides a
    # l'ecran alors que tous les autres cas etaient verts. On fige donc l'unicite du nom.
    cas("le hub a sa propre fonction de mise a jour des quetes", True, "majQuetes = function" in hub)
    cas("aucune redefinition de majEvenements en double", 1, hub.count("majEvenements = function"))
    cas("le hub rafraichit les quetes en continu", True, "majQuetes(vue)" in hub)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : quetes du jour et coffre gratuit tiennent leurs promesses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
