# -*- coding: utf-8 -*-
"""Banc hors Studio : un PASS ROBLOX paye EN JEU est actif tout de suite, et le VIP est en vente.

Deux defauts constates le 2026-09-26 dans src/server/Economie.lua :
  a) la possession d'un pass ne passait QUE par UserOwnsGamePassAsync, dont Roblox garde la
     reponse en cache pour la session : le joueur qui achetait le pass de saison en jeu le voyait
     rester verrouille jusqu'a sa reconnexion — il payait et ne recevait rien ;
  b) le pass VIP (pieces x2) n'etait propose NULLE PART dans le jeu.

Ici UserOwnsGamePassAsync rend TOUJOURS faux, comme le cache de Roblox apres un achat en jeu :
seul l'evenement d'achat (Economie.noterPassAchete, cable dans GameServer sur
PromptGamePassPurchaseFinished) peut faire passer le pass a « possede ».

Contre-epreuve : BRR_ECONOMIE=<ancienne version> fait tourner le banc sur un autre fichier ; il
est ROUGE sur le code d'avant le correctif.
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
    lua.execute("""
local MS = game:GetService("MarketplaceService")
INVITES = {}
PROPRIETAIRE = false -- vrai : le compte possede d'office ses pass (compte createur)
MS.UserOwnsGamePassAsync = function(_, _uid, _pass) return PROPRIETAIRE end -- cache de Roblox : faux
MS.PromptGamePassPurchase = function(_, _pl, pass) table.insert(INVITES, pass) end
MS.PromptProductPurchase = function(_, _pl, id) table.insert(INVITES, id) end
""")
    g = lua.globals()
    Eco.PASS_SAISON = 555
    Eco.PASS_VIP = 777
    # Les produits livres portent leurs vrais identifiants depuis le 2026-09-26 : on part de 0
    # pour que le cas 3 ne voie QUE l'offre VIP, et le cas 4 pose le sien.
    for i in range(1, len(Eco.PRODUITS) + 1):
        Eco.PRODUITS[i].id = 0
    noter = Eco.noterPassAchete

    def invites():
        return [g.INVITES[i] for i in range(1, len(g.INVITES) + 1)]

    def offres(pl):
        v = Eco.vue(pl).offresRobux
        return [v[i].nom for i in range(1, len(v) + 1)]

    print("\n-- 1. pass de saison paye en jeu : actif tout de suite")
    alice = H.joueur(lua, "Alice", 1)
    Eco.charger(alice)
    cas("avant l'achat : pas de piste premium", False, bool(Eco.aPassPremium(alice)))
    cas("l'achat est retenu", True, bool(noter and noter(alice, 555, True)))
    cas("piste premium ouverte sans reconnexion", True, bool(Eco.aPassPremium(alice)))

    print("\n-- 2. achat annule, ou pass d'un autre jeu : rien n'est accorde")
    bob = H.joueur(lua, "Bob", 2)
    Eco.charger(bob)
    cas("achat annule refuse", False, bool(noter and noter(bob, 555, False)))
    cas("pass inconnu refuse", False, bool(noter and noter(bob, 999, True)))
    cas("toujours pas de piste premium", False, bool(Eco.aPassPremium(bob)))

    print("\n-- 3. le VIP est en vente dans la boutique, et s'achete en jeu")
    cas("offre VIP visible (produits a 0 : seule offre)", ["Pass VIP : pieces x2"], offres(bob))
    v = Eco.vue(bob).offresRobux
    cas("l'offre VIP porte sa pastille (genre)", "vip", v[1].genre if len(v) else None)
    Eco.demanderRobux(bob, "vip")
    cas("achat du VIP propose", [777], invites())
    cas("l'achat du VIP est retenu", True, bool(noter and noter(bob, 777, True)))
    cas("offre VIP retiree une fois possede", [], offres(bob))
    Eco.demanderRobux(bob, "vip")
    cas("pas de second achat propose", [777], invites())
    r = Eco.recompenser(bob, "victoire")
    cas("VIP actif tout de suite : pieces de victoire x2", 60, int(r.pieces))

    print("\n-- 4. les produits se demandent toujours par leur rang")
    Eco.demanderRobux(bob, 1)
    cas("produit a l'identifiant 0 : rien propose", [777], invites())
    Eco.PRODUITS[1].id = 123
    Eco.demanderRobux(bob, 1)
    cas("produit configure : achat propose", [777, 123], invites())

    print("\n-- 5. au depart, l'achat en memoire est oublie (le serveur suivant relit Roblox)")
    Eco.liberer(alice)
    alice2 = H.joueur(lua, "Alice", 1)
    Eco.charger(alice2)
    cas("nouvelle session : on repart de la reponse de Roblox", False, bool(Eco.aPassPremium(alice2)))

    print("\n-- 6. copie de test --vip-non-possede : le createur voit l'offre VIP")
    g.PROPRIETAIRE = True
    carl = H.joueur(lua, "Carl", 3)
    Eco.charger(carl)
    vip = "Pass VIP : pieces x2"
    cas("createur, sans le drapeau : offre VIP masquee", False, vip in offres(carl))
    Eco.vipTestNonPossede = True
    cas("createur, avec le drapeau : offre VIP visible", True, vip in offres(carl))
    noter(carl, 777, True)
    cas("achat en jeu retenu malgre le drapeau : offre retiree", False, vip in offres(carl))
    Eco.vipTestNonPossede = False
    g.PROPRIETAIRE = False

    print()
    if ECHECS:
        print("ROUGE : %d cas en echec -> %s" % (len(ECHECS), ", ".join(ECHECS)))
        return 1
    print("VERT : pass payes en jeu actifs tout de suite, VIP en vente")
    return 0


if __name__ == "__main__":
    sys.exit(main())
