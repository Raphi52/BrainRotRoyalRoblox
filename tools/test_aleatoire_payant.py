# -*- coding: utf-8 -*-
"""Banc hors Studio : les ARTICLES ALEATOIRES PAYANTS sont bloques la ou Roblox les interdit.

Questionnaire de maturite du 2026-09-27 : « Oui » aux articles aleatoires payants. Deux chemins du
jeu donnent un contenu TIRE AU HASARD contre de l'argent reel :
  a) ouvrir un coffre EN COURS contre des gemmes (les gemmes se vendent en Robux) ;
  b) le coffre d'or de la piste PREMIUM du pass de saison (pass vendu 299 R$).
Roblox exige de les masquer, remplacer ou bloquer pour les joueurs dont le pays les interdit
(PolicyService:GetPolicyInfoForPlayerAsync().ArePaidRandomItemsRestricted,
https://create.roblox.com/docs/production/promotion/content-maturity).
Attendu : (a) refuse AVANT toute depense, (b) remplace par un gain fixe, et si Roblox ne repond
pas, on bloque (vendre un tirage interdit ne se rattrape pas).

Contre-epreuve : BRR_ECONOMIE=<ancienne version d'Economie.lua> -> ROUGE.
Prerequis : python -m pip install lupa
"""
import os
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import harnais_economie as H  # noqa: E402

if os.environ.get("BRR_ECONOMIE"):
    H.SRC = pathlib.Path(os.environ["BRR_ECONOMIE"])

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print("  %s  %s : attendu %r, obtenu %r" % ("OK  " if ok else "RATE", nom, attendu, obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = H.nouveau_lua()
    Eco = H.charger(lua)
    g = lua.globals()
    Eco.passPremiumTest = True  # piste premium ouverte (pass paye)
    interdit = Eco.aleatoirePayantInterdit or (lambda _p: False)

    def joueur_pret(nom, uid):
        pl = H.joueur(lua, nom, uid)
        Eco.charger(pl)
        p = Eco.profil(pl)
        p.gemmes = 100
        Eco.passEtat(p)[0].points = 5 * 30  # palier 5 atteint : coffre d'or sur la piste premium
        Eco.gagnerCoffre(pl, "or")
        Eco.demarrerCoffre(pl, 1)  # coffre EN COURS : ouvrable tout de suite contre des gemmes
        return pl, p

    def nb_coffres(p):
        return len(p.coffres)

    print("\n-- 1. pays qui INTERDIT les tirages payants")
    g.POLITIQUE_INTERDIT = True
    alice, pa = joueur_pret("Alice", 1)
    cas("le serveur le sait", True, bool(interdit(alice)))
    ok, motif = Eco.accelererCoffre(alice, 1)
    cas("ouverture contre des gemmes refusee", False, bool(ok))
    cas("motif lisible", "ouverture contre des gemmes indisponible dans ton pays", motif)
    cas("aucune gemme depensee", 100, int(pa.gemmes))
    cas("le coffre attend toujours", 1, nb_coffres(pa))
    avant = int(pa.pieces)
    ok, texte = Eco.reclamerPalier(alice, 5, "premium")
    cas("palier premium 5 reclame", True, bool(ok))
    cas("coffre d'or remplace par 400 pieces fixes", 400, int(pa.pieces) - avant)
    cas("aucun coffre ajoute", 1, nb_coffres(pa))
    v = Eco.vue(alice)
    cas("l'ecran le sait (vue)", True, bool(v.sansAleatoirePayant))
    cas("l'ecran du pass le sait", True, bool(v["pass"].sansAleatoirePayant))

    print("\n-- 2. pays qui PERMET : rien ne change")
    g.POLITIQUE_INTERDIT = False
    bob, pb = joueur_pret("Bob", 2)
    cas("permis", False, bool(interdit(bob)))
    ok, _gain = Eco.accelererCoffre(bob, 1)
    cas("ouverture contre des gemmes acceptee", True, bool(ok))
    cas("gemmes depensees", True, int(pb.gemmes) < 100)
    ok, _t = Eco.reclamerPalier(bob, 5, "premium")
    cas("palier premium 5 : un coffre d'or", "or", pb.coffres[nb_coffres(pb)].type if ok and nb_coffres(pb) else None)
    cas("l'ecran ne masque rien", False, bool(Eco.vue(bob).sansAleatoirePayant))

    print("\n-- 3. Roblox ne repond pas : on BLOQUE")
    g.POLITIQUE_PANNE = True
    carl, pc = joueur_pret("Carl", 3)
    g.POLITIQUE_PANNE = False
    cas("panne -> interdit", True, bool(interdit(carl)))
    ok, _m = Eco.accelererCoffre(carl, 1)
    cas("pas de vente pendant la panne", False, bool(ok))
    cas("gemmes intactes", 100, int(pc.gemmes))

    print("\n-- 4. modules partages : textes et recompenses")
    ps = g.PASSSAISON
    co = g.COFFRES
    cas("piste GRATUITE inchangee (coffre gagne en jouant)", "coffre", ps.recompense(5, "gratuit", True).type)
    cas("premium, pays qui interdit : pieces", "400 pieces", ps.recompense(5, "premium", True).texte)
    cas("premium, pays qui permet : coffre d'or", "Coffre d'or", ps.recompense(5, "premium", False).texte)
    cas("coffre en cours sans prix en gemmes", "1h00", co.texteEnCours(3600, True))
    cas("coffre en cours avec prix sinon", "1h00  |  6 gemmes", co.texteEnCours(3600))
    cas("bulle des gemmes sans promesse d'ouverture", False, "ouvrent" in co.texteGemmes(5, 2, True))

    print()
    if ECHECS:
        print("ROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        return 1
    print("VERT : tirages payants bloques ou remplaces la ou ils sont interdits")
    return 0


if __name__ == "__main__":
    sys.exit(main())
