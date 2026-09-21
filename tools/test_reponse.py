# -*- coding: utf-8 -*-
"""Banc de la REPONSE du robot (src/shared/Reponse.lua) : quelle carte contre quoi.

Defaut mesure avant ce module, dans botThink : le robot prenait « la carte la plus CHERE qu'il
peut payer », avec un seul filtre (savoir viser les volants). Il ignorait donc tout ce que le jeu
sait faire depuis — anti-air x2, anti-groupe x1,8, assassins, auras — et il vidait son elixir sur
une grosse carte sans rapport avec la menace.

Ce qu'il verifie :
  1. la menace est lue correctement (volants, essaims, tireurs), et seulement chez l'ADVERSAIRE ;
  2. face a des volants, il prend un anti-air — et surtout JAMAIS une carte incapable de viser ;
  3. face a un essaim, il prend l'anti-groupe, sinon une carte a degats de zone ;
  4. il ne pose pas un soutien pour DEFENDRE (un tambour ne repousse rien tout seul) ;
  5. a pertinence egale, il prend la carte la MOINS chere — c'est l'inverse de l'ancien critere ;
  6. sans menace particuliere, il reste raisonnable (il ne joue pas n'importe quoi) ;
  7. le choix est REPRODUCTIBLE (aucune dependance a l'ordre de parcours) ;
  8. COMPARAISON directe avec l'ancienne regle « la plus chere », sur des scenes concretes ;
  9. le serveur l'utilise vraiment, et le palier debutant continue d'ignorer la menace.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Reponse.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — le robot joue toujours la carte la plus chere" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    R = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    def obj(camp=2, pv=300, volant=False, groupe=False, portee=3.0, batiment=False):
        return lua.table_from(dict(camp=camp, pv=pv, volant=volant, enGroupe=groupe,
                                   portee=portee, batiment=batiment))

    def liste(*e):
        return lua.table_from(list(e))

    # 1. lecture de la menace
    vue = R.menace(liste(obj(pv=200), obj(pv=300, volant=True)), 1, 5)
    cas("les PV ennemis sont comptes", 500.0, float(vue.pv))
    cas("un volant est vu", True, vue.volante)
    cas("aucun essaim ici", False, vue.essaim)
    vue = R.menace(liste(obj(groupe=True)), 1, 5)
    cas("un essaim est vu", True, vue.essaim)
    vue = R.menace(liste(obj(portee=9.0)), 1, 5)
    cas("un tireur est vu", True, vue.tireur)
    cas("une melee n'est pas un tireur", False, R.menace(liste(obj(portee=3.0)), 1, 5).tireur)
    vue = R.menace(liste(obj(camp=1, volant=True), obj(camp=1, groupe=True)), 1, 5)
    cas("ses PROPRES unites ne sont pas une menace", (0.0, False, False),
        (float(vue.pv), vue.volante, vue.essaim))
    vue = R.menace(liste(obj(batiment=True, pv=3000, portee=20.0)), 1, 5)
    cas("un batiment adverse n'est pas une menace d'attaque", (0.0, False),
        (float(vue.pv), vue.tireur))
    cas("aucun objet : aucune menace", 0.0, float(R.menace(None, 1, 5).pv))

    # traits de cartes types
    def traits(cout=3, volant_ok=True, air=False, groupe=False, assassin=False,
               soutien=False, zone=False, corps=1.0):
        return lua.table_from(dict(peutViserVolant=volant_ok, antiAir=air, antiGroupe=groupe,
                                   assassin=assassin, soutien=soutien, zone=zone,
                                   cout=cout, corps=corps))

    def main_de(*paires):
        return lua.table_from([lua.table_from(dict(index=i + 1, traits=t))
                               for i, t in enumerate(paires)])

    vol = R.menace(liste(obj(volant=True)), 1, 5)
    essaim = R.menace(liste(obj(groupe=True)), 1, 5)
    tireur = R.menace(liste(obj(portee=9.0)), 1, 5)
    rien = R.menace(liste(obj()), 1, 5)

    # 2. volants
    grosse_melee = traits(cout=6, volant_ok=False, corps=5.0)   # ce que l'ancien robot prenait
    petit_antiair = traits(cout=2, air=True, corps=0.8)
    cas("face a des volants : l'anti-air, pas la grosse melee", 2,
        R.choisir(main_de(grosse_melee, petit_antiair), vol, False)[0])
    tireur_simple = traits(cout=4, corps=2.0)
    cas("a defaut d'anti-air, au moins une carte qui vise en l'air", 2,
        R.choisir(main_de(grosse_melee, tireur_simple), vol, False)[0])
    cas("une carte incapable de viser un volant est presque exclue", True,
        float(R.note(grosse_melee, vol, False)) < float(R.note(tireur_simple, vol, False)))

    # 3. essaim
    anti_groupe = traits(cout=4, groupe=True, corps=2.0)
    zone = traits(cout=3, zone=True, corps=1.5)
    mono = traits(cout=6, corps=5.0)
    cas("face a un essaim : l'anti-groupe", 1,
        R.choisir(main_de(anti_groupe, zone, mono), essaim, False)[0])
    cas("a defaut, les degats de zone", 1,
        R.choisir(main_de(zone, mono), essaim, False)[0])
    cas("une grosse carte mono-cible ne repond pas a un essaim", True,
        float(R.note(mono, essaim, False)) < float(R.note(zone, essaim, False)))

    # assassin face a un tireur installe
    assassin = traits(cout=2, assassin=True, corps=0.8)
    cas("face a un tireur installe : l'assassin", 1,
        R.choisir(main_de(assassin, mono), tireur, True)[0])

    # 4. LE SOUTIEN. Regle corrigee apres mesure : ce qui compte n'est pas d'attaquer ou de
    # defendre, c'est d'avoir QUELQU'UN a renforcer. Avec l'ancienne regle (-50 en defense), les
    # trois cartes de soutien du jeu n'ont ete jouees AUCUNE fois sur une partie entiere : le
    # robot defend la plupart du temps, elles etaient donc mortes.
    soutien = traits(cout=3, soutien=True, corps=1.0)
    ordinaire = traits(cout=3, corps=1.0)
    seul = R.menace(liste(obj()), 1, 5)                      # aucun allie sur le terrain
    entoure = R.menace(liste(obj(), obj(camp=1)), 1, 5)      # un allie a renforcer
    cas("on compte les allies", (0.0, 1.0), (float(seul.allies), float(entoure.allies)))
    cas("sans personne a renforcer : mauvais choix", 2,
        R.choisir(main_de(soutien, ordinaire), seul, False)[0])
    cas("avec un allie a renforcer : bon choix, meme en DEFENSE", 1,
        R.choisir(main_de(soutien, ordinaire), entoure, False)[0])
    cas("et en attaque aussi", 1, R.choisir(main_de(soutien, ordinaire), entoure, True)[0])
    # le malus doit rester MODERE : une carte mal placee reste jouable en dernier recours
    ecart = float(R.note(ordinaire, seul, False)) - float(R.note(soutien, seul, False))
    print("  soutien sans allie : %.0f points sous une carte ordinaire (bonus max du jeu : %.0f)"
          % (ecart, float(R.BONUS_ANTI_AIR)))
    cas("le malus reste bien plus petit que les bonus", True, ecart < float(R.BONUS_ANTI_AIR) / 2)
    cas("un soutien n'est jamais exclu comme une carte impuissante", True,
        float(R.note(soutien, seul, False)) > float(R.MALUS_IMPUISSANT) / 2)

    # 5. a pertinence egale, le moins cher
    cher = traits(cout=6, corps=1.0)
    pas_cher = traits(cout=2, corps=1.0)
    cas("a pertinence egale : la moins chere", 2,
        R.choisir(main_de(cher, pas_cher), rien, False)[0])
    cas("l'ancien critere (la plus chere) est bien abandonne", True,
        float(R.note(pas_cher, rien, False)) > float(R.note(cher, rien, False)))

    # 6. sans menace, il reste raisonnable : entre deux cartes de meme cout, la plus consistante
    faible = traits(cout=3, corps=0.5)
    solide = traits(cout=3, corps=3.0)
    cas("a cout egal : la plus consistante", 2,
        R.choisir(main_de(faible, solide), rien, False)[0])

    # 7. reproductibilite
    m = main_de(traits(cout=3, corps=1.0), traits(cout=3, corps=1.0))
    cas("egalite stricte : toujours le meme choix", [1] * 5,
        [R.choisir(m, rien, False)[0] for _ in range(5)])
    cas("main vide : aucun choix", None, R.choisir(main_de(), rien, False)[0])
    cas("main absente : aucun choix", None, R.choisir(None, rien, False)[0])

    # 8. COMPARAISON avec l'ancienne regle, sur des scenes concretes
    def ancien(mains_py):
        """L'ancien robot : la carte la plus chere qu'il peut payer."""
        return max(mains_py, key=lambda p: p[1]["cout"])[0]

    scenes = [
        ("des volants arrivent", vol,
         [(1, dict(cout=6, volant_ok=False, corps=5.0)), (2, dict(cout=2, air=True, corps=0.8))], 2),
        ("un essaim arrive", essaim,
         [(1, dict(cout=6, corps=5.0)), (2, dict(cout=4, groupe=True, corps=2.0))], 2),
        ("un tireur s'installe", tireur,
         [(1, dict(cout=5, corps=4.0)), (2, dict(cout=2, assassin=True, corps=0.8))], 2),
    ]
    print()
    print("  %-26s %-22s %s" % ("SCENE", "ANCIEN ROBOT", "NOUVEAU ROBOT"))
    for nom, menace_, cartes, attendu in scenes:
        mains_lua = main_de(*[traits(**c[1]) for c in cartes])
        choix = R.choisir(mains_lua, menace_, False)[0]
        vieux = ancien(cartes)
        print("  %-26s carte %-16s carte %s" % (nom, vieux, choix))
        cas("scene : %s" % nom, attendu, choix)
        cas("  et l'ancien se trompait", True, vieux != attendu)

    # 9. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Reponse")' in serveur)
    cas("le serveur lit la menace", True, "Reponse.menace(objetsVus, team, Cible.PORTEE_TIREUR)" in serveur)
    cas("le serveur choisit par la note", True, "Reponse.choisir(mains, vuePrise, enAttaque)" in serveur)
    cas("le serveur decrit bien les traits d'anti-air", True, 'specialite.contre == "air"' in serveur)
    cas("et ceux d'assassin", True, "Assassin.estAssassin(c.id)" in serveur)
    # ecrit en if/else depuis qu'on a retire le piege Lua `a and vue or {}`
    cas("le debutant continue d'ignorer la menace", True,
        "vuePrise = vue" in serveur and "vuePrise = {}" in serveur)
    cas("et le piege Lua and/or n'a pas ete reintroduit", False,
        "profil.anticipe) and vue or {}" in serveur)
    cas("un sort garde une valeur pour le robot", True,
        "c.sort ~= nil and (c.sort.degats or 0) > 0" in serveur)
    cas("l'ancien critere 'la plus chere' a disparu", False, "c.cost > cout" in serveur)
    cas("le module est livre dans la place", True, "shared/Reponse.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : le robot repond a ce qui arrive au lieu de vider son elixir")
    return 0


if __name__ == "__main__":
    sys.exit(main())
