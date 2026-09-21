# -*- coding: utf-8 -*-
"""Banc des PROMESSES DE CARTES : la description doit etre tenue par les chiffres.

Pourquoi ce banc (2026-09-21) : une carte se vend par sa phrase. « Portee record », « ultra
rapide », « mur vivant » — si les nombres ne suivent pas, le joueur achete une promesse et decouvre
autre chose. Rien ne controlait ce lien : la description vit dans le catalogue, les chiffres a cote,
et personne ne les comparait.

L'audit a tourne sur les 47 cartes : AUCUNE ne ment aujourd'hui. Ce banc fige ce resultat pour que
la prochaine carte ajoutee ne puisse pas mentir en silence.

DEUX PIEGES MESURES pendant l'ecriture, tous deux sources de faux positifs :
  1. chercher un mot en SOUS-CHAINE : « harcelent » contient « lent », « ralentit » aussi. Trois
     fausses alertes sur trois. On cherche donc des mots entiers.
  2. oublier le BOUCLIER : Scudo Banana annonce « encaisse » avec 420 PV, sous la mediane — mais
     son bouclier de 520 porte son encaissement reel a 940. On compare les PV EFFECTIFS.

Prerequis : python -m pip install lupa
"""
import pathlib
import re
import statistics
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def mot(texte, motif):
    """Mot ENTIER : « harcelent » ne doit pas compter comme « lent »."""
    return re.search(r"(?<![a-z])" + motif + r"(?![a-z])", texte) is not None


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }")
    lua.execute("Vector3 = { new = function(x, y, z) return { x, y, z } end }")
    C = lua.execute("return (function() "
                    + (ROOT / "src" / "shared" / "Cards.lua").read_text(encoding="utf-8") + " end)()")
    R = lua.execute("return (function() "
                    + (ROOT / "src" / "shared" / "Reperes.lua").read_text(encoding="utf-8") + " end)()")

    unites = [c for c in C.list.values() if not c["sort"] and not c["batiment"]]
    cas("le catalogue a des unites a comparer", True, len(unites) > 10)

    def pv(c):
        # PV EFFECTIFS : le bouclier encaisse AVANT les points de vie, il compte donc.
        return (c["hp"] or 0) + (c["bouclier"] or 0)

    mediane = lambda f: statistics.median([f(c) for c in unites])
    mPV, mDeg, mVit = mediane(pv), mediane(lambda c: c["dmg"]), mediane(lambda c: c["speed"])

    # Chaque mot d'une description engage un chiffre. Au-dessus (ou en dessous) de la mediane des
    # unites : on ne demande pas un record, seulement que la promesse soit du bon cote.
    PROMESSES = [
        ("rapide", lambda c: c["speed"] > mVit, "vitesse"),
        ("vite", lambda c: c["speed"] > mVit, "vitesse"),
        ("lent", lambda c: c["speed"] < mVit, "vitesse"),
        ("lente", lambda c: c["speed"] < mVit, "vitesse"),
        ("solide", lambda c: pv(c) > mPV, "PV effectifs"),
        ("resistant", lambda c: pv(c) > mPV, "PV effectifs"),
        ("tank", lambda c: pv(c) > mPV, "PV effectifs"),
        ("mur", lambda c: pv(c) > mPV, "PV effectifs"),
        ("costaud", lambda c: pv(c) > mPV, "PV effectifs"),
        ("fragile", lambda c: pv(c) < mPV, "PV effectifs"),
        ("puissant", lambda c: c["dmg"] > mDeg, "degats"),
    ]

    menteuses = []
    for c in unites:
        d = (c["desc"] or "").lower()
        for motif, tenue, quoi in PROMESSES:
            if mot(d, motif) and not tenue(c):
                menteuses.append("%s dit « %s » mais ses %s ne suivent pas" % (c["id"], motif, quoi))
    cas("aucune carte ne promet ce que ses chiffres ne tiennent pas", [], menteuses)

    # PROMESSE DE RANG : « record », « la plus ». Elle exige d'etre REELLEMENT en tete, ce que
    # Reperes calcule sur le catalogue entier.
    rangs = []
    for c in unites:
        d = (c["desc"] or "").lower()
        if "record" in d or "la plus" in d or "le plus" in d:
            points = [x for x in R.points(c, C.list).values()]
            if not any(("du jeu" in p) or p.startswith("la ") for p in points):
                rangs.append("%s annonce un record que le catalogue ne confirme pas" % c["id"])
    cas("toute promesse de record est tenue", [], rangs)

    # LE BANC ATTRAPE-T-IL VRAIMENT UN MENSONGE ? On fabrique une carte qui ment, et on verifie
    # qu'elle serait signalee : sans ce controle, un banc toujours vert ne prouve rien.
    fausse = lua.eval('(function() return { id = "faux", desc = "Colosse lent et solide",'
                      ' hp = 10, dmg = 1, speed = 99, range = 1 } end)')()
    prise = []
    d = (fausse["desc"] or "").lower()
    for motif, tenue, quoi in PROMESSES:
        if mot(d, motif) and not tenue(fausse):
            prise.append(motif)
    cas("une carte qui ment serait signalee", True, "lent" in prise and "solide" in prise)
    # Et les deux pieges mesures ne doivent PAS produire de fausse alerte.
    cas("« harcelent » n'est pas « lent »", False, mot("deux poissons, harcelent vite", "lent"))
    cas("« ralentit » non plus", False, mot("tireuse : ralentit ce qu'elle touche", "lent"))
    scudo = C.byId["ScudoBanana"]
    cas("le bouclier compte dans l'encaissement", True, pv(scudo) > mPV and scudo["hp"] < mPV)

    # ===== SORTS ET BATIMENTS : LES CHIFFRES ANNONCES DOIVENT ETRE LES VRAIS =====
    #
    # Une unite promet une qualite (« rapide »), un sort ou un batiment promet un NOMBRE :
    # « retient tout 20 s », « rend 1 elixir toutes les 8 s », « la foudre frappe les 3 plus
    # solides ». Ces chiffres sont ecrits DEUX FOIS — dans la phrase et dans les reglages — et rien
    # ne garantissait qu'ils restent d'accord. Changer un equilibrage, c'est rendre la phrase
    # fausse sans s'en apercevoir.
    speciales = [c for c in C.list.values() if c["sort"] or c["batiment"]]
    cas("le catalogue a des sorts et des batiments", True, len(speciales) > 5)

    def reglages(c):
        """Tous les nombres REELS de la carte, avec le nom du reglage qui les porte."""
        d = {}
        s, b = c["sort"], c["batiment"]
        if s:
            for k in ("degats", "rayon", "duree", "cibles"):
                if s[k] is not None:
                    d[k] = s[k]
        if b:
            for k in ("duree", "periode", "gain", "nombre"):
                if b[k] is not None:
                    d[k] = b[k]
        return d

    def annonces(desc):
        """Les nombres que la PHRASE promet, avec ce a quoi ils se rapportent."""
        d = (desc or "").lower()
        out = []
        for n in re.findall(r"toutes les (\d+(?:[.,]\d+)?) s", d):
            out.append(("periode", float(n.replace(",", "."))))
        for n in re.findall(r"rend (\d+(?:[.,]\d+)?) elixir", d):
            out.append(("gain", float(n.replace(",", "."))))
        for n in re.findall(r"les (\d+) plus", d):
            out.append(("cibles", float(n)))
        # Une duree en secondes qui n'est pas une periode : « retient tout 20 s », « pendant 8 s ».
        for n in re.findall(r"(?<!toutes les )(\d+(?:[.,]\d+)?) s(?![a-z])", d):
            v = float(n.replace(",", "."))
            if ("periode", v) not in out:
                out.append(("duree", v))
        return out

    faux = []
    controlees = 0
    for c in speciales:
        vrais = reglages(c)
        for quoi, valeur in annonces(c["desc"]):
            controlees += 1
            if vrais.get(quoi) is None or float(vrais[quoi]) != valeur:
                faux.append("%s annonce %s = %g, le jeu applique %s"
                            % (c["id"], quoi, valeur, vrais.get(quoi)))
    cas("chaque chiffre annonce est celui du jeu", [], faux)
    # Sans ce garde-fou, le banc pourrait etre vert parce qu'il ne controle RIEN.
    cas("des chiffres ont bien ete controles", True, controlees >= 5)
    print("  %d chiffres annonces verifies sur %d sorts et batiments" % (controlees, len(speciales)))

    # AUTO-TEST : une carte qui annonce une duree fausse doit etre prise.
    menteur = lua.eval('(function() return { id = "faux2", desc = "Batiment : retient tout 30 s",'
                       ' batiment = { type = "leurre", duree = 20 } } end)')()
    pris = []
    for quoi, valeur in annonces(menteur["desc"]):
        v = reglages(menteur)
        if v.get(quoi) is None or float(v[quoi]) != valeur:
            pris.append(quoi)
    cas("une duree fausse serait signalee", True, "duree" in pris)
    # Et « toutes les 8 s » ne doit pas etre lu comme une duree de vie.
    cas("une periode n'est pas confondue avec une duree", [("periode", 8.0)],
        annonces("Batiment : rend 1 elixir toutes les 8 s")[:1])

    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : chaque carte tient ce que sa description promet")
    return 0


sys.exit(main())
