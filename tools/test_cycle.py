# -*- coding: utf-8 -*-
"""Banc du CYCLE DES CARTES (src/shared/Cycle.lua), hors Studio.

Defaut corrige : un paquet de moins de 8 cartes etait complete en REPETANT les identifiants, si
bien que la meme carte pouvait occuper deux cases de la main de depart. Le joueur en voyait deux,
n'en comprenait qu'une, et son cycle n'avait plus de sens.

Ce qu'il verifie :
  1. le paquet fait toujours 8 cartes, sans doublon tant qu'il y a de quoi ;
  2. avec moins de 8 cartes distinctes, les repetitions sont repoussees a la FIN, donc la main de
     depart (les 4 premieres) ne montre jamais deux fois la meme carte ;
  3. jouer une carte la renvoie en FOND de file et fait remonter la tete de file ;
  4. la file annonce plusieurs cartes a venir, pas une seule ;
  5. on sait dans combien de coups une carte revient (le calcul que le joueur fait de tete) ;
  6. le cout moyen d'un paquet se mesure ;
  7. le serveur de jeu applique reellement ces regles.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Cycle.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CLIENT = ROOT / "src" / "client" / "GameClient.client.lua"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def liste(t):
    return list(t.values()) if t is not None else None


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    C = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")
    # tirage FIGE : le banc doit etre rejouable. `tirage(n) = n` ne permute rien.
    fige = lua.eval("(function(n) return n end)")

    douze = lua.table_from(["c%d" % i for i in range(1, 13)])
    p = liste(C.paquet(douze, fige))
    cas("le paquet fait 8 cartes", 8, len(p))
    cas("aucun doublon quand il y a de quoi", 8, len(set(p)))

    cinq = lua.table_from(["a", "b", "c", "d", "e"])
    p = liste(C.paquet(cinq, fige))
    cas("le paquet fait 8 cartes meme avec 5 distinctes", 8, len(p))
    cas("la main de depart ne montre jamais deux fois la meme carte", 4, len(set(p[:4])))

    main_, file = C.distribuer(douze, fige)
    main_, file = liste(main_), liste(file)
    cas("4 en main, 4 en file", (4, 4), (len(main_), len(file)))

    m = lua.table_from(["a", "b", "c", "d"])
    f = lua.table_from(["e", "f", "g", "h"])
    jouee, ok = C.jouer(m, f, 2)
    cas("la carte jouee est rendue", ("b", True), (jouee, ok))
    cas("la tete de file prend sa place", ["a", "e", "c", "d"], liste(m))
    cas("la carte jouee repart en fond de file", ["f", "g", "h", "b"], liste(f))
    jouee, ok = C.jouer(m, f, 9)
    cas("une case hors bornes ne consomme rien", (None, False), (jouee, ok))

    cas("la file annonce plusieurs cartes a venir", ["f", "g"], liste(C.suivantes(f, None)))
    cas("au moins deux cartes annoncees", True, int(C.SUIVANTES_VUES) >= 2)

    cas("une carte en main revient dans 0 coup", 0, C.retour(m, f, "a"))
    cas("la carte en fond de file revient au 4e coup", 4, C.retour(m, f, "b"))
    cas("une carte absente du paquet n'a pas de retour", None, C.retour(m, f, "zz"))

    couts = lua.eval("(function() local t = { a = 2, b = 4, c = 3, d = 3 } return function(id) return t[id] end end)")()
    cas("cout moyen du paquet", 3.0, C.coutMoyen(lua.table_from(["a", "b", "c", "d"]), couts))

    serveur = SERVEUR.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Cycle")' in serveur)
    cas("le paquet de depart vient du module", True, "Cycle.distribuer(" in serveur)
    cas("le cycle de jeu vient du module", True, "Cycle.jouer(" in serveur)
    cas("les cartes a venir sont envoyees au client", True, "Cycle.suivantes(" in serveur)
    # RETOUR DE LA DERNIERE JOUEE. Defaut mesure le 2026-09-20 : `Cycle.retour` etait ecrit et
    # teste ici meme, mais appele par PERSONNE. Compter son cycle est le coeur du genre : c'est ce
    # qui dit si l'on peut depenser sa carte de defense maintenant ou s'il faut la garder. Le
    # joueur devait tenir ce compte de tete, sur huit cartes.
    main4 = lua.table_from(["a", "b", "c", "d"])
    file4 = lua.table_from(["e", "f", "g", "h"])
    cas("une carte en main revient tout de suite", 0, C.retour(main4, file4, "a"))
    cas("la tete de file revient dans 1", 1, C.retour(main4, file4, "e"))
    cas("le fond de file revient dans 4", 4, C.retour(main4, file4, "h"))
    cas("une carte hors paquet ne revient pas", None, C.retour(main4, file4, "zz"))
    # Le TEXTE affiche, avec l'accord du pluriel : « 1 carte », « 4 cartes ».
    cas("texte du retour lointain", "Torre\nrevient dans 4 cartes", C.texteRetour("Torre", 4))
    cas("texte au singulier", "Torre\nrevient dans 1 carte", C.texteRetour("Torre", 1))
    cas("texte quand elle est revenue", "Torre\nde retour en main", C.texteRetour("Torre", 0))
    cas("rien tant qu'aucune carte n'a ete jouee", "", C.texteRetour("Torre", None))
    cas("ni sans nom de carte", "", C.texteRetour(None, 3))

    # LE JEU S'EN SERT VRAIMENT
    cas("le serveur retient la derniere carte jouee", True, "t.derniereJouee = card.id" in serveur)
    cas("et envoie son rang de retour", True,
        "retourDerniere = t.derniereJouee and Cycle.retour(t.hand, t.queue, t.derniereJouee)" in serveur)
    cas("le client l'affiche", True, "buttons.retour.Text = Cycle.texteRetour(" in client)
    # Le texte vient du module : l'ecran ne recalcule pas le cycle.
    cas("l'ecran ne recalcule pas le cycle lui-meme", True, "s.retourDerniere)" in client)

    # DIAGNOSTIC DU DECK. Defaut mesure le 2026-09-20 : `Cycle.coutMoyen` existait, etait teste
    # ici meme... et n'etait appele NULLE PART. L'ecran DECK montrait huit vignettes et « 8 / 8 »,
    # sans le chiffre que tout joueur regarde en premier, ni le trou qui coute le plus de parties.
    couts = lua.eval("(function() local t = { a = 2, b = 3, c = 4, d = 7 } return function(id) return t[id] end end)()")
    air = lua.eval("(function() local t = { a = true, c = true } return function(id) return t[id] == true end end)()")
    deck = lua.table_from(["a", "b", "c", "d"])
    r = C.resumeDeck(deck, couts, air)
    cas("le cout moyen est calcule", 4.0, float(r["moyenne"]))
    cas("les reponses aux volants sont comptees", 2, r["antiAir"])
    cas("un deck qui repond aux volants n'a pas d'alerte", None, r["alerte"])
    # LE TROU LE PLUS COUTEUX : une attaque aerienne sans reponse prend une tour entiere.
    sansAir = lua.eval("(function() return function() return false end end)()")
    cas("un deck sans anti-air est signale", "AUCUNE REPONSE AUX VOLANTS",
        C.resumeDeck(deck, couts, sansAir)["alerte"])
    cas("un deck vide n'alerte sur rien", None, C.resumeDeck(lua.table_from([]), couts, sansAir)["alerte"])
    # Jugement : les seuils se lisent, et les trois verdicts se distinguent.
    cas("un deck rapide est dit leger", "LEGER", C.jugementCout(float(C.COUT_LEGER) - 0.1))
    cas("entre les deux, equilibre", "EQUILIBRE", C.jugementCout(float(C.COUT_LEGER)))
    cas("au-dessus, lourd", "LOURD", C.jugementCout(float(C.COUT_LOURD) + 0.1))
    cas("un deck vide le dit", "VIDE", C.jugementCout(0))
    cas("les seuils restent dans le raisonnable", True, 3 <= float(C.COUT_LEGER) < float(C.COUT_LOURD) <= 5)
    # Le texte affiche : virgule decimale francaise, et accord du pluriel.
    texte = C.texteResume(r)
    for bout in ("Cout moyen 4,0", "EQUILIBRE", "2 cartes anti-air"):
        cas("le resume porte %s" % bout, True, bout in texte)
    cas("une seule carte anti-air s'accorde", True,
        "1 carte anti-air" in C.texteResume(C.resumeDeck(lua.table_from(["a"]), couts, air)))

    # L'ECRAN S'EN SERT (sinon le module reste mort-ne, comme coutMoyen l'etait)
    hub = (ROOT / "src" / "client" / "Hub.client.lua").read_text(encoding="utf-8")
    cas("l'ecran DECK charge le module", True, 'WaitForChild("Cycle")' in hub)
    cas("il calcule le resume du deck en cours", True, "Cycle.resumeDeck(choisies," in hub)
    cas("il l'affiche", True, "deckResume.Text = Cycle.texteResume(resume)" in hub)
    cas("les reponses aux volants viennent de la REGLE du jeu", True,
        "Regles.peutViserVolant(Cards.byId[id])" in hub)
    cas("l'alerte se voit (couleur differente)", True, "deckResume.TextColor3 = Color3.fromRGB(255, 150, 90)" in hub)

    cas("le client affiche les cartes a venir", True, "s.suivantes" in client)

    # LISIBILITE DES CARTES A VENIR. Defaut vu a l'ecran le 2026-09-20 : elles etaient une ligne de
    # texte gris (« A venir Tralalero Tralala 3 ... ») a cote de quatre vignettes colorees. Il
    # fallait la LIRE mot a mot, alors que tout l'interet de les annoncer est le coup d'oeil.
    cas("ce ne sont plus des lignes de texte", False, "nextLabel" in client)
    cas("ce sont des vignettes", True, "apercus[n] = { vignette = v, stroke = st }" in client)
    cas("elles portent la couleur de la carte", True, "a.vignette.BackgroundColor3 = c.color" in client)
    cas("et son cout", True, 'a.vignette.Text = c.name .. "' + chr(92) + 'n" .. c.cost .. " elixir"' in client)
    # Le contour de rarete est ce qui les fait lire comme des CARTES et non comme des etiquettes.
    cas("elles gardent le contour de rarete", True, "local rr = Cards.RARETES[c.rarete]" in client)
    # En retrait : sinon elles se confondraient avec la main et on essaierait de les poser.
    cas("elles restent en retrait de la main", True,
        "a.vignette.BackgroundTransparency = 0.25" in client)
    # Une case sans carte ne doit pas garder la vignette precedente.
    cas("une case sans carte disparait", True, "a.vignette.Visible = c ~= nil" in client)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : paquet sans doublon, file qui tourne, cartes a venir annoncees")
    return 0


sys.exit(main())
