# -*- coding: utf-8 -*-
"""Banc de la CHARGE (src/shared/Charge.lua) : l'elan fait mal, l'arret le vole.

Defaut mesure avant ce module : une unite de melee frappait exactement pareil qu'elle vienne de
traverser l'arene ou qu'elle soit posee au contact. Aucune raison de lancer une unite de loin,
aucune parade en la bloquant en route.

Ce qu'il verifie :
  1. seules les cartes declarees ont une charge, les autres ne changent rien ;
  2. les bornes de securite tiennent (multiplicateur, vitesse) ;
  3. l'elan s'accumule en courant et se PERD des qu'on arrete l'unite ;
  4. le coup charge fait le multiplicateur annonce, en nombre entier ;
  5. l'acceleration n'arrive qu'APRES la course, jamais avant ;
  6. une course freinee par la foule ne charge pas ;
  7. simulation image par image : distance reelle avant declenchement, et remise a zero au coup ;
  8. le serveur applique reellement la regle.

Prerequis : python -m pip install lupa
"""
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "shared" / "Charge.lua"
SERVEUR = ROOT / "src" / "server" / "GameServer.server.lua"
CARTES = ROOT / "src" / "shared" / "Cards.lua"
BUILD = ROOT / "build.py"

ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    if not SRC.exists():
        print("ROUGE : %s absent — aucune unite ne charge" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    # math.clamp n'existe que dans Luau : on le fournit comme le fait le moteur.
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")
    C = lua.execute("return (function() " + SRC.read_text(encoding="utf-8") + " end)()")

    # 1. qui charge, qui ne charge pas
    noms = sorted(C.PROFILS.keys())
    print("  cartes a charge : " + ", ".join(noms))
    cas("au moins trois cartes chargent", True, len(noms) >= 3)
    cas("une carte ordinaire n'a pas de charge", None, C.profil("Tralalero"))
    cas("un identifiant inconnu n'est pas une erreur", None, C.profil("CarteQuiNExistePas"))
    cas("aUneCharge repond non pour une tour", False, C.aUneCharge("TorreCannoli"))
    cas("aUneCharge repond oui pour un chargeur", True, C.aUneCharge(noms[0]))

    # les identifiants declares EXISTENT vraiment dans le catalogue (sinon la regle ne s'applique
    # a personne, et tout le banc serait vert pour rien)
    cartes = CARTES.read_text(encoding="utf-8")
    for n in noms:
        cas("la carte %s existe au catalogue" % n, True, ('id = "%s"' % n) in cartes)

    # 2. bornes
    for n in noms:
        p = C.profil(n)
        cas("%s : multiplicateur borne" % n, True, 1 < float(p.multiplicateur) <= float(C.MULTIPLICATEUR_MAX))
        cas("%s : vitesse bornee" % n, True, 1 <= float(p.vitesse) <= float(C.VITESSE_MAX))
        cas("%s : distance utile" % n, True, float(p.distance) > 0)

    p = C.profil(noms[0])
    d = float(p.distance)

    # 3. accumulation et perte
    cas("un pas compte", 1.0, float(C.maj(0, 1)))
    cas("les pas s'additionnent", 3.0, float(C.maj(2, 1)))
    cas("s'arreter vole toute la charge", 0.0, float(C.maj(d + 50, 0)))
    cas("un pas derisoire aussi (elle pietine)", 0.0, float(C.maj(d + 50, float(C.PAS_MINIMAL) / 2)))
    cas("un pas juste au seuil compte", True, float(C.maj(5, float(C.PAS_MINIMAL))) > 5)

    # 4. seuil et degats
    cas("juste avant la distance : pas lancee", False, C.lancee(d - 0.01, p))
    cas("a la distance pile : lancee", True, C.lancee(d, p))
    cas("sans profil, jamais lancee", False, C.lancee(9999, None))
    cas("degats normaux tant qu'elle n'a pas charge", 100, C.degats(100, p, False))
    cas("degats normaux sans profil", 100, C.degats(100, None, True))
    charge = C.degats(100, p, True)
    cas("le coup charge suit le multiplicateur", int(round(100 * float(p.multiplicateur))), charge)
    cas("les degats restent entiers", True, float(charge) == int(charge))
    cas("un chargeur frappe plus fort qu'un non-chargeur", True, charge > 100)

    # 5. vitesse
    cas("pas d'acceleration avant la charge", 5.0, float(C.vitesse(5, p, False)))
    cas("acceleration une fois lancee", 5 * float(p.vitesse), float(C.vitesse(5, p, True)))
    cas("aucune acceleration sans profil", 5.0, float(C.vitesse(5, None, True)))
    cas("avancement a mi-course", 0.5, float(C.avancement(d / 2, p)))
    cas("avancement plafonne a 1", 1.0, float(C.avancement(d * 10, p)))
    cas("avancement nul sans profil", 0.0, float(C.avancement(50, None)))

    # 6 + 7. simulation image par image, 30 images par seconde
    dt = 1.0 / 30
    def courir(vitesse_base, frein, images, profil):
        """Rend (distance reelle parcourue avant declenchement, image du declenchement)."""
        parcouru, reel, declenche = 0.0, 0.0, None
        for i in range(images):
            lancee = C.lancee(parcouru, profil)
            v = float(C.vitesse(vitesse_base, profil, lancee))
            pas = v * frein * dt
            reel += pas
            parcouru = float(C.maj(parcouru, pas))
            if declenche is None and C.lancee(parcouru, profil):
                declenche = (reel, i)
        return declenche

    reel, image = courir(8, 1.0, 300, p)
    print("  charge declenchee apres %.1f studs (image %d, vitesse 8 studs/s)" % (reel, image))
    cas("elle charge apres la distance annoncee", True, d <= reel < d + 1)
    cas("et pas des la premiere image", True, image > 3)

    # freinee a 35 % (mur d'unites) : le pas reste au-dessus du seuil, elle met donc BIEN plus
    # longtemps — et bloquee net, elle ne charge jamais.
    lent = courir(8, 0.35, 300, p)
    cas("freinee, elle met plus d'images a charger", True, lent[1] > image * 2)
    bloquee = courir(8, 0.0, 300, p)
    cas("bloquee net, elle ne charge JAMAIS", None, bloquee)

    # arret au milieu de la course : tout est a refaire
    parcouru = 0.0
    for _ in range(int(d / (8 * dt)) - 2):   # presque arrivee au seuil
        parcouru = float(C.maj(parcouru, 8 * dt))
    cas("elle est presque lancee", True, parcouru > d * 0.8 and not C.lancee(parcouru, p))
    parcouru = float(C.maj(parcouru, 0))     # un mur l'arrete une seule image
    cas("une seule image d'arret efface tout", 0.0, parcouru)
    cas("et elle n'est plus lancee", False, C.lancee(parcouru, p))

    # 9. COHERENCE AVEC LA DESCRIPTION DE LA CARTE. Les charges avaient ete attribuees sans lire
    # les descriptions : la carte qui PROMETTAIT une charge n'en avait pas, et un « tireur longue
    # portee » en avait une. Ce controle interdit les deux, dans les deux sens.
    import re as _re
    fiches = {}
    for bloc in cartes.split(chr(9) + "{")[1:]:
        mi = _re.search(r'id = "(\w+)"', bloc)
        md = _re.search(r'desc = "([^"]+)"', bloc)
        if mi:
            fiches[mi.group(1)] = (md.group(1) if md else "").lower()

    # (a) toute carte qui ANNONCE une charge doit en avoir une
    annoncent = [i for i, d in fiches.items() if "charge" in d]
    print("  cartes dont la description annonce une charge : " + (", ".join(annoncent) or "aucune"))
    for ident in annoncent:
        cas("%s annonce une charge, elle doit en avoir une" % ident, True, C.aUneCharge(ident))

    # (b) aucune carte a charge ne doit se decrire comme un TIREUR : elle s'arreterait a portee
    # pour tirer, donc ne courrait jamais assez longtemps — la regle serait un mensonge.
    for ident in noms:
        d = fiches.get(ident, "")
        cas("%s n'est pas decrit comme un tireur" % ident, False,
            ("tireur" in d) or ("tire loin" in d) or ("longue portee" in d))

    # (c) une carte a charge doit pouvoir COURIR : une portee trop longue l'arrete trop tot pour
    # qu'elle accumule sa distance d'elan.
    for ident in noms:
        i = cartes.find('id = "%s"' % ident)
        portee = _re.search(r"range = ([\d.]+)", cartes[i:i + 900])
        p = float(portee.group(1)) if portee else 0
        cas("%s a une portee compatible avec une charge (%.1f)" % (ident, p), True,
            p <= float(C.profil(ident).distance) / 2)

    # 8. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Charge")' in serveur)
    cas("le serveur donne un profil a l'unite", True, "Charge.profil(card.id)" in serveur)
    cas("le serveur accumule l'elan en marchant", True, "Charge.maj(" in serveur)
    cas("le serveur accelere la charge", True, "Charge.vitesse(" in serveur)
    cas("le serveur majore le coup", True, "Charge.degats(e.dmg" in serveur)
    cas("le serveur remet l'elan a zero apres le coup", True, "e.chargeParcouru, e.chargeLancee = 0, false" in serveur)
    cas("le module est livre dans la place", True, 'shared/Charge.lua' in BUILD.read_text(encoding="utf-8"))

    # 9. L'ELAN SE VOIT. Defaut mesure le 2026-09-20 : la regle etait codee, testee et appliquee,
    # mais RIEN ne la montrait. Celui qui lance l'unite ne savait pas si sa charge etait prete ;
    # celui d'en face ne voyait pas la menace arriver, alors que la parade existe (la bloquer lui
    # vole sa charge). Une mecanique decisive, invisible des deux cotes.
    cas("un disque d'elan est cree pour les cartes a charge", True,
        'd.Name = "DisqueElan"' in serveur)
    # Uniquement pour elles : quarante disques au sol seraient du bruit.
    cas("et pour elles seulement", True, "if Charge.aUneCharge(card.id) then" in serveur)
    # C'est la fonction d'avancement, jusque-la inutilisee, qui pilote la taille.
    cas("il grandit avec l'avancement REEL de la course", True,
        "Charge.avancement(e.chargeParcouru, e.chargeProfil)" in serveur)
    cas("il s'allume quand la charge est lancee", True,
        "e.disqueElan.Transparency = e.chargeLancee and 0.25" in serveur)
    # Deux etats, deux couleurs : « elle prend de l'elan » et « elle est lancee » ne se lisent pas
    # pareil, sinon le signal n'apprend rien a l'adversaire.
    cas("lancee, il change de couleur", True,
        "e.chargeLancee and Color3.fromRGB(255, 90, 70)" in serveur)

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : la charge recompense l'elan et un simple mur la vole")
    return 0


if __name__ == "__main__":
    sys.exit(main())
