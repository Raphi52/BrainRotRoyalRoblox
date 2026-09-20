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
    cas("le client affiche les cartes a venir", True, "s.suivantes" in client)

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : paquet sans doublon, file qui tourne, cartes a venir annoncees")
    return 0


sys.exit(main())
