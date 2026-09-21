# -*- coding: utf-8 -*-
"""Banc de la PROGRESSION DE COLLECTION (src/shared/Collection.lua + ecran des cartes).

Defaut corrige le 2026-09-21 : le jeu compte 40 cartes et le joueur ne voyait NULLE PART combien
il en possede. L'ecran des cartes affiche une grille ou les cartes non possedees sont ternes : pour
savoir ou il en est, il fallait les compter a l'oeil. Le seul chiffre affiche (« X cartes sur 8 »)
parle du DECK, pas de la collection — il entretenait meme la confusion.

Ce qu'il verifie :
  1. les trois comptes, et surtout la SEPARATION entre ce qui s'achete et ce qui attend une arene ;
  2. la part possedee, bornee, sans division par zero ;
  3. la ligne affichee : pas de reste a zero, accord au singulier, collection complete ;
  4. l'ecran des cartes l'emploie vraiment, avec les VRAIES regles d'arene.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Collection.lua"
HUB = ROOT / "src" / "client" / "Hub.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    C = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    hub = HUB.read_text(encoding="utf-8")
    tbl = lua.table_from

    catalogue = tbl([
        tbl({"id": "offerte", "prix": 0}),
        tbl({"id": "achetable1", "prix": 500}),
        tbl({"id": "achetable2", "prix": 700}),
        tbl({"id": "verrouillee", "prix": 900}),
    ])
    possedees = tbl({"offerte": True})
    ouverte = lua.eval('(function(id) return id ~= "verrouillee" end)')

    b = dict(C.bilan(possedees, catalogue, ouverte))
    cas("le total porte sur TOUT le catalogue", 4, b["total"])
    cas("une seule carte possedee", 1, b["possedees"])
    # LA SEPARATION : des pieces d'un cote, des trophees de l'autre.
    cas("deux cartes a acheter maintenant", 2, b["aAcheter"])
    cas("une carte attend une arene", 1, b["plusHaut"])
    # Une carte verrouillee ne doit PAS compter comme achetable : ce serait promettre une carte
    # qu'aucune somme de pieces n'ouvre aujourd'hui.
    cas("aucune carte comptee deux fois", 4, b["possedees"] + b["aAcheter"] + b["plusHaut"])
    cas("sans regle d'arene, rien n'est verrouille", 0,
        dict(C.bilan(possedees, catalogue, None))["plusHaut"])
    # Une carte offerte non possedee (prix 0) n'est ni a acheter ni verrouillee.
    cas("une carte gratuite non possedee ne se vend pas", 2,
        dict(C.bilan(tbl({}), catalogue, ouverte))["aAcheter"])

    cas("part possedee", 0.25, C.part(C.bilan(possedees, catalogue, ouverte)))
    cas("un catalogue vide ne divise pas par zero", 0, C.part(C.bilan(tbl({}), tbl([]), None)))
    toutes = tbl({"offerte": True, "achetable1": True, "achetable2": True, "verrouillee": True})
    cas("une collection complete remplit la barre", 1, C.part(C.bilan(toutes, catalogue, ouverte)))

    t = C.texte(C.bilan(possedees, catalogue, ouverte))
    cas("la ligne donne le rapport", True, "1 / 4" in t)
    cas("elle dit ce qui s'achete", True, "2 a acheter" in t)
    cas("accord au singulier sur une seule carte", True, "1 s'ouvre plus haut" in t)
    deux = C.texte(C.bilan(tbl({}), catalogue,
                           lua.eval('(function(id) return id == "offerte" or id == "achetable1" end)')))
    cas("accord au pluriel sinon", True, "2 s'ouvrent plus haut" in deux)
    complete = C.texte(C.bilan(toutes, catalogue, ouverte))
    cas("collection complete : on le dit", True, "complete" in complete)
    # « 0 a acheter » sur une collection complete serait du bruit.
    cas("et on n'ajoute pas de reste a zero", False, "0 a" in complete)
    cas("un catalogue vide ne rend aucune ligne", "", C.texte(C.bilan(tbl({}), tbl([]), None)))

    # 5. BOUTIQUE : CE QUI RESTE A PRENDRE. Defaut mesure le 2026-09-21 : elle n'affichait que le
    # solde. Devant 47 tuiles, le joueur ne savait ni ce qu'il peut s'offrir maintenant, ni combien
    # il lui manque pour la premiere, ni ce que la prochaine arene ouvrira.
    r = dict(C.aPortee(possedees, catalogue, ouverte, 600))
    cas("une seule carte a portee avec 600 pieces", 1, r["abordables"])
    cas("il peut l'enchainer avec son solde", 1, r["enchainables"])
    cas("et cela lui coute son prix", 500, r["coutEnchainables"])
    # Les verrouillees par l'arene ne comptent PAS : promettre un achat impossible serait pire.
    cas("deux cartes restent a prendre a cette arene", 2, r["restantes"])
    cas("la plus proche hors de portee est chiffree", 700, r["prochainPrix"])
    cas("et l'effort restant aussi", 100, r["manque"])
    riche = dict(C.aPortee(possedees, catalogue, ouverte, 5000))
    cas("avec assez de pieces, tout est a portee", 2, riche["abordables"])
    cas("et plus rien ne manque", None, riche.get("manque"))
    fauche = dict(C.aPortee(possedees, catalogue, ouverte, 0))
    cas("sans pieces, aucune carte a portee", 0, fauche["abordables"])
    cas("il manque le prix de la moins chere", 500, fauche["manque"])

    cas("le texte dit ce qui est a portee", True, "1 carte a ta portee" in C.texteBoutique(r))
    # DEFAUT VU A L'ECRAN (cap-boutique-riche.png du 2026-09-21) : avec 2000 pieces, la boutique
    # annoncait « 7 cartes a ta portee (5800 pieces en tout) » — une somme que le joueur ne peut
    # PAS payer. Le compte porte desormais sur ce qu'il peut enchainer, et le cout est payable.
    cas("le cout annonce est payable avec le solde", True, "500 pieces sur 600" in C.texteBoutique(r))
    cas("accord au pluriel", True, "2 cartes a ta portee" in C.texteBoutique(riche))
    # Trois cartes a 500, 700 et 900 avec 1300 pieces : deux d'affilee, pas trois.
    troisPrix = tbl([tbl({"id": "a", "prix": 500}), tbl({"id": "b", "prix": 700}), tbl({"id": "c", "prix": 900})])
    serre = dict(C.aPortee(tbl({}), troisPrix, None, 1300))
    cas("il n'en prend que ce que son solde permet d'affilee", 2, serre["enchainables"])
    cas("et le cumul reste sous son solde", True, serre["coutEnchainables"] <= 1300)
    # Les TROIS sont abordables prises isolement (900 <= 1300) : c'est exactement la nuance que
    # l'ancien texte ecrasait en annoncant leur somme.
    cas("alors que les trois sont abordables une par une", 3, serre["abordables"])
    cas("le texte n'annonce jamais plus que le solde", True,
        "1200 pieces sur 1300" in C.texteBoutique(C.aPortee(tbl({}), troisPrix, None, 1300)))
    # Aucune a portee : on donne l'EFFORT restant, pas un simple « non ».
    cas("sans le sou, il dit ce qui manque", "Il te manque 500 pieces pour la moins chere",
        C.texteBoutique(fauche))
    tout = C.aPortee(toutes, catalogue, ouverte, 0)
    cas("tout achete : on le dit sans promettre autre chose", True,
        "toutes les cartes ouvertes" in C.texteBoutique(tout))

    a = C.texteProchaineArene("Foret Patapim", 200, tbl(["Bicus", "Tigrullini"]))
    cas("l'arene suivante est nommee", True, "Foret Patapim" in a)
    cas("avec les trophees qui restent", True, "dans 200 trophees" in a)
    cas("et les cartes qu'elle ouvre", True, "Bicus, Tigrullini" in a)
    cas("une arene sans nouvelle carte le dit", True,
        "aucune nouvelle carte" in C.texteProchaineArene("Foret Patapim", 200, tbl([])))
    # Derniere arene : promettre une suite qui n'existe pas serait pire que se taire.
    cas("pas d'arene suivante : aucune ligne", "", C.texteProchaineArene(None, 0, tbl([])))

    # L'ECRAN S'EN SERT VRAIMENT ------------------------------------------------------------------
    cas("le hub charge le module", True, 'WaitForChild("Collection")' in hub)
    cas("la ligne vient du module", True, "montee.collection.texte(bilan)" in hub)
    cas("la barre aussi", True, "montee.collection.part(bilan)" in hub)
    # Les regles d'arene REELLES, pas une copie : une carte verrouillee doit l'etre pour la meme
    # raison que dans la boutique.
    cas("le verrou vient des arenes", True, "Arenes.carteDebloquee(id, vue.trophees or 0)" in hub)
    cas("le compte porte sur tout le catalogue", True,
        "montee.collection.bilan(vue.cartes, Cards.list," in hub)
    cas("la boutique dit ce qui est a portee", True,
        "montee.boutiquePortee.Text = montee.collection.texteBoutique(portee)" in hub)
    cas("elle calcule avec le VRAI solde", True,
        "end, v.pieces or 0)" in hub)
    cas("et annonce la prochaine arene", True,
        "montee.collection.texteProchaineArene(suivante.nom," in hub)
    cas("avec les NOMS des cartes, pas les identifiants", True,
        "Cards.byId[id] and Cards.byId[id].name or id" in hub)
    # Derniere arene : la ligne disparait au lieu de promettre une suite qui n'existe pas.
    cas("rien a annoncer dans la derniere arene", True, 'montee.boutiqueArene.Text = suivante' in hub)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : la collection dit ou on en est, et separe ce qui s'achete de ce qui s'ouvre plus haut")
    return 0


def _etat_deck():
    from lupa import LuaRuntime
    L = LuaRuntime()
    NL = chr(10)
    src = pathlib.Path("src/shared/Collection.lua").read_text(encoding="utf-8")
    a = src.index("function Collection.etatDeck"); b = src.index(NL + "end" + NL, a) + 5
    f = L.execute("local Collection = {}" + NL + src[a:b] + NL + "return Collection.etatDeck")
    assert f(False, False, False) == "verrouillee"
    assert f(False, False, False, 150, 500) == "encore 150 trophees"
    assert f(False, False, False, 0, 700) == "en boutique : 700 pieces"
    assert f(True, True, True) == "DANS LE DECK"
    assert f(True, False, True) == "deck plein : retire une carte"
    assert f(True, False, False) == "+ AJOUTER"
    assert ".etatDeck(" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    a = src.index("function Collection.deckModifie"); b = src.index(NL + "end" + NL, a) + 5
    m = L.execute("local Collection = {}" + NL + src[a:b] + NL + "return Collection.deckModifie")
    ch = L.eval("{ a = true, b = true }")
    assert not m(ch, L.eval("{ 'a', 'b' }"), 2)
    assert not m(ch, L.eval("{ 'a', 'b', 'c', 'd' }"), 2), "sans deck choisi : seules les 2 premieres comptent"
    assert m(L.eval("{ a = true }"), L.eval("{ 'a', 'b' }"), 2)
    assert m(L.eval("{ a = true, c = true }"), L.eval("{ 'a', 'b' }"), 2)
    assert "deckModifie(choix, vue.deck, taille)" in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
    i = hub.index('deckEcran:GetPropertyChangedSignal("Visible")')
    bloc = hub[i:i + 1400]
    assert "deckModifie(choix, vue.deck, taille)" in bloc and 'InvokeServer("deck", liste)' in bloc, "sortie : enregistrement auto"
    assert "nbChoix ~= taille" in bloc and "ancien deck est garde" in bloc, "sortie : deck incomplet dit"
    print("VERT : chaque tuile du deck dit ce que fera le clic, deck plein compris")

_etat_deck()
sys.exit(main())
