# -*- coding: utf-8 -*-
"""Banc de la FRAPPE (src/shared/Frappe.lua) : jusqu'ou les bonus de degats peuvent s'empiler.

Defaut trouve par la mesure, pas par une plainte : trois regles majorent le meme coup (Soutien
x1,5 max, Specialite x2,5 max, Charge x3 max) et elles se MULTIPLIAIENT sans plafond commun —
x11,25 possible en theorie. Personne ne s'en apercevait parce que la meilleure combinaison
reellement jouable atteint x3,25 ; mais la prochaine carte qui cumulerait les trois ferait
n'importe quoi, une fois le jeu publie.

Ce qu'il verifie :
  1. la composition est bien le PRODUIT des bonus, tant qu'on reste sous le plafond ;
  2. le plafond mord au-dela, et il est SIGNALE (pour qu'un desequilibre soit visible) ;
  3. aucun bonus ne peut AFFAIBLIR un coup ;
  4. les degats restent entiers ;
  5. le plafond est place AU-DESSUS de la meilleure combinaison jouable aujourd'hui — c'est un
     garde-fou, pas un affaiblissement : aucune situation actuelle ne change ;
  6. l'empilement theorique des trois modules DEPASSE le plafond (sinon ce module ne servirait
     a rien, et il faudrait le dire) ;
  7. le serveur compose reellement les trois bonus a cet endroit-la.

Prerequis : python -m pip install lupa
"""
import io
import pathlib
import sys
from lupa import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
SRC = SHARED / "Frappe.lua"
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
        print("ROUGE : %s absent — les bonus s'empilent sans plafond" % SRC)
        return 1
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("function math.clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end")

    def mod(nom):
        return lua.execute("return (function() " + (SHARED / nom).read_text(encoding="utf-8") + " end)()")

    F = mod("Frappe.lua")
    So, Sp, Ch = mod("Soutien.lua"), mod("Specialite.lua"), mod("Charge.lua")

    plafond = float(F.PLAFOND)
    print("  plafond commun : x%.2f" % plafond)

    def liste(*v):
        return lua.table_from(list(v))

    # 1. produit simple
    total, mordu = F.composer(liste(1.3, 2.0))
    cas("deux bonus se multiplient", 2.6, round(float(total), 6))
    cas("et le plafond n'a pas mordu", False, mordu)
    total, _ = F.composer(liste(1.0, 1.0, 1.0))
    cas("aucun bonus : coup normal", 1.0, float(total))
    total, _ = F.composer(liste())
    cas("liste vide : coup normal", 1.0, float(total))
    total, _ = F.composer(None)
    cas("liste absente : coup normal", 1.0, float(total))
    total, _ = F.composer(liste(1.15, 1.1, 1.2))
    cas("trois petits bonus se composent", round(1.15 * 1.1 * 1.2, 6), round(float(total), 6))

    # 2. plafond
    total, mordu = F.composer(liste(1.5, 2.5, 3.0))
    cas("l'empilement maximal est ramene au plafond", plafond, float(total))
    cas("et le plafond le SIGNALE", True, mordu)
    total, mordu = F.composer(liste(plafond))
    cas("pile au plafond : accepte sans signal", (plafond, False), (float(total), mordu))
    total, mordu = F.composer(liste(plafond + 0.01))
    cas("juste au-dessus : plafonne et signale", (plafond, True), (float(total), mordu))

    # 3. aucun affaiblissement
    total, _ = F.composer(liste(0.5))
    cas("un multiplicateur sous 1 n'affaiblit pas", 1.0, float(total))
    total, _ = F.composer(liste(0.5, 0.5))
    cas("meme plusieurs", 1.0, float(total))
    total, _ = F.composer(liste(0, 2.0))
    cas("un zero est ignore, pas destructeur", 2.0, float(total))
    cas("degats : un multiplicateur sous 1 ne retire rien", 100, F.degats(100, 0.3))
    cas("degats : un multiplicateur absent ne change rien", 100, F.degats(100, None))

    # 4. entiers
    cas("degats majores, en entier", 130, F.degats(100, 1.3))
    cas("arrondi au plus proche", 131, F.degats(101, 1.3))
    cas("les degats restent entiers", True, float(F.degats(137, 1.37)) == int(F.degats(137, 1.37)))
    cas("zero reste zero", 0, F.degats(0, 3))
    cas("degats plafonnes aussi", F.degats(100, plafond), F.degats(100, 99))

    # 5 + 6. le plafond est-il bien place ? On mesure les VRAIES valeurs des trois modules.
    max_soutien = float(So.MAX)
    max_specialite = float(Sp.MULTIPLICATEUR_MAX)
    max_charge = float(Ch.MULTIPLICATEUR_MAX)
    theorique = max_soutien * max_specialite * max_charge
    print("  bornes reelles : soutien x%.2f, specialite x%.2f, charge x%.2f -> x%.2f en theorie"
          % (max_soutien, max_specialite, max_charge, theorique))
    cas("l'empilement theorique depasse bien le plafond (le module sert a quelque chose)",
        True, theorique > plafond)

    # meilleure combinaison REELLEMENT jouable : le plus gros elan du catalogue, sous la meilleure
    # aura du catalogue. (Aucune carte du jeu n'est a la fois chargeur ET specialiste.)
    elan_max = max(float(Ch.profil(n).multiplicateur) for n in dict(Ch.PROFILS))
    aura_max = max(float(So.profil(n).degats) for n in dict(So.PROFILS))
    jouable = elan_max * aura_max
    print("  meilleure combinaison jouable aujourd'hui : elan x%.2f sous aura x%.2f = x%.2f"
          % (elan_max, aura_max, jouable))
    cas("le plafond est AU-DESSUS du jeu actuel (garde-fou, pas affaiblissement)",
        True, jouable <= plafond)
    total, mordu = F.composer(liste(aura_max, 1.0, elan_max))
    cas("la meilleure combinaison actuelle passe sans etre rabotee", round(jouable, 6),
        round(float(total), 6))
    cas("et sans declencher le plafond", False, mordu)

    # une carte qui cumulerait les trois, elle, serait bien retenue
    total, mordu = F.composer(liste(aura_max, float(Sp.MULTIPLICATEUR_MAX), elan_max))
    cas("mais un futur cumul des trois serait retenu", True, mordu)

    # 7. branchement reel
    serveur = SERVEUR.read_text(encoding="utf-8")
    cas("le serveur charge le module", True, 'WaitForChild("Frappe")' in serveur)
    cas("le serveur compose les trois bonus", True,
        "Frappe.composer({ e.bonusDegats or 1, specialite, elan })" in serveur)
    cas("le serveur applique la composition", True, "Frappe.degats(e.dmg, total)" in serveur)
    cas("le serveur trace un plafonnement", True, 'plafonne and " (PLAFONNE)"' in serveur)
    cas("l'elan ne s'applique pas aux frappes de zone", True,
        "if not e.splash and e.chargeProfil and e.chargeLancee then" in serveur)
    cas("le module est livre dans la place", True, "shared/Frappe.lua" in BUILD.read_text(encoding="utf-8"))

    if ECHECS:
        print("ROUGE : " + ", ".join(ECHECS))
        return 1
    print("VERT : les bonus se composent sous un plafond commun, sans rien affaiblir aujourd'hui")
    return 0


if __name__ == "__main__":
    sys.exit(main())
