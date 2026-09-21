# -*- coding: utf-8 -*-
"""Banc du JOURNAL DES PARTIES (src/shared/Journal.lua), hors Studio.

Defaut corrige le 2026-09-20 : le profil ne gardait que DEUX nombres, `parties` et `victoires`.
Le joueur ne pouvait pas repondre a la question la plus banale d'un jeu de duel : « ca va mieux ou
moins bien en ce moment ? ». Une serie de defaites ne se voyait qu'au compteur de trophees qui
descend, sans savoir contre qui ni sur combien de parties. Meme la partie qu'on venait de finir
n'etait affichee nulle part une fois revenu au menu.

Ce qu'il verifie :
  1. la regle pure : la plus recente en tete, la plus ancienne qui sort, la liste d'origine intacte ;
  2. le texte d'une ligne : issue, signe des trophees, adversaire, temps ecoule ;
  3. le bilan et le resume comptent juste, y compris la liste vide ;
  4. le serveur RANGE vraiment la partie, avec le delta REEL de trophees et le nom de l'adversaire ;
  5. le profil le transporte et le hub l'affiche (sinon le module serait mort-ne).

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Journal.lua"
ECO = ROOT / "src" / "server" / "Economie.lua"
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
    J = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    eco = ECO.read_text(encoding="utf-8")
    serveur = SERVEUR.read_text(encoding="utf-8")
    hub = HUB.read_text(encoding="utf-8")

    vide = lua.eval("{}")
    # 1. ordre et plafond
    l = J.ajouter(vide, J.entree("victoire", 30, "Robot", 100))
    l = J.ajouter(l, J.entree("defaite", -15, "Zoe", 200))
    cas("la plus recente est en tete", "defaite", l[1]["issue"])
    cas("l'ancienne reste dessous", "victoire", l[2]["issue"])
    cas("deux parties rangees", 2, len(list(l.values())))

    # PLAFOND : au-dela de MAX, la plus ancienne sort. Sans cela, un profil grossirait sans fin
    # et la sauvegarde finirait par etre refusee par Roblox.
    grosse = vide
    for i in range(1, int(J.MAX) + 6):
        grosse = J.ajouter(grosse, J.entree("victoire", 1, "A" + str(i), i))
    cas("la liste ne depasse jamais son plafond", int(J.MAX), len(list(grosse.values())))
    cas("et c'est la plus ANCIENNE qui sort", "A" + str(int(J.MAX) + 5), grosse[1]["adversaire"])

    # La liste d'origine ne doit pas etre modifiee sur place (le profil garde la sienne).
    avant = len(list(l.values()))
    J.ajouter(l, J.entree("egalite", 0, "Max", 300))
    cas("la liste d'origine reste intacte", avant, len(list(l.values())))

    # 2. l'entree se nettoie elle-meme
    e = J.entree("victoire", 30, None, 100)
    cas("un adversaire absent devient Robot", "Robot", e["adversaire"])
    cas("un adversaire vide aussi", "Robot", J.entree("victoire", 30, "", 100)["adversaire"])

    # 3. temps ecoule, lisible par un humain
    cas("moins d'une minute : a l'instant", "a l'instant", J.depuis(100, 130))
    cas("des minutes", "il y a 5 min", J.depuis(0, 5 * 60))
    cas("des heures", "il y a 2 h", J.depuis(0, 2 * 3600))
    cas("des jours", "il y a 3 j", J.depuis(0, 3 * 86400))
    cas("un futur ne rend pas un negatif", "a l'instant", J.depuis(500, 100))

    # 4. la ligne affichee
    ligne = J.ligne(J.entree("victoire", 30, "Zoe", 0), 300)
    for bout in ("VICTOIRE", "+30", "Zoe", "il y a 5 min"):
        cas("la ligne porte %s" % bout, True, bout in ligne)
    # « 30 » et « -15 » se confondent en diagonale : le signe est toujours ecrit.
    cas("une defaite montre son signe", True, "-15" in J.ligne(J.entree("defaite", -15, "Zoe", 0), 0))

    # 5. bilan et resume
    b = J.bilan(l)
    cas("le bilan compte les parties", 2, b["parties"])
    cas("les victoires", 1, b["victoires"])
    cas("les defaites", 1, b["defaites"])
    cas("et le solde REEL de trophees", 15, b["trophees"])
    cas("une liste vide ne ment pas", 0, J.bilan(vide)["parties"])
    cas("le resume vide le dit en clair", True, "Aucune partie" in J.resume(vide))
    r = J.resume(l)
    cas("une seule partie s'accorde au singulier", True,
        "1 derniere partie :" in J.resume(J.ajouter(vide, J.entree("victoire", 30, "Robot", 0))))
    for bout in ("2 dernieres parties", "1 V / 1 D", "+15"):
        cas("le resume porte %s" % bout, True, bout in r)

    # Couleurs decidees par le module, donc verifiables : vert gagne, rouge perdu.
    cas("une victoire est verte", True, J.teinte("victoire")[2] > J.teinte("victoire")[1])
    cas("une defaite est rouge", True, J.teinte("defaite")[1] > J.teinte("defaite")[2])

    # 6. LE SERVEUR RANGE VRAIMENT LA PARTIE ------------------------------------------------------
    cas("le profil neuf porte un journal", True, "journal = {}," in eco)
    cas("un ancien profil en recoit un", True, "p.journal = p.journal or {}" in eco)
    cas("la partie finie est rangee", True,
        "p.journal = Journal.ajouter(p.journal, Journal.entree(issue, p.trophees - avant, adversaire, os.time()))" in eco)
    # Le delta REEL (amorti par le plancher d'arene), pas la valeur theorique de l'issue.
    cas("avec le delta REEL de trophees", True, "p.trophees - avant" in eco)
    cas("la recompense accepte le nom de l'adversaire", True,
        re.search(r"function Economie\.recompenser\(player, issue, contreHumain, adversaire[,)]", eco) is not None)
    cas("le serveur le fournit", True, 'enFace and enFace.DisplayName or "Robot"' in serveur)

    # 7. LE PROFIL LE TRANSPORTE ET LE HUB L'AFFICHE ----------------------------------------------
    cas("la vue du profil porte le journal", True, "journal = p.journal or {}" in eco)
    cas("et son resume", True, "journalResume = Journal.resume(p.journal)" in eco)
    cas("le hub charge le module", True, 'WaitForChild("Journal")' in hub)
    cas("un bouton ouvre l'ecran", True, "boutonJournal.MouseButton1Click" in hub)
    cas("il relit le profil a l'ouverture (la derniere partie doit y etre)", True,
        'local v = Boutique:InvokeServer("profil").vue or {}' in hub)
    cas("les lignes viennent du module, elles ne sont pas reecrites", True,
        "Journal.ligne(e, maintenant)" in hub and "Journal.teinte(e.issue)" in hub)
    cas("et il se ferme", True, "journalFermer.MouseButton1Click" in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : les dernieres parties sont gardees, comptees et affichees telles qu'elles ont eu lieu")
    return 0


sys.exit(main())
