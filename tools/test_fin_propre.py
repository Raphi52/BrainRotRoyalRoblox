# -*- coding: utf-8 -*-
"""Banc : aucun refus de pose ne recouvre l'ecran de fin.

Defaut mesure le 2026-09-21 (capture cap-bonus-humain.png) : apres la victoire, un clic dans
l'arene partait encore au serveur, revenait en refus « partie terminee » et s'ecrivait PAR-DESSUS
le bouton Rejouer. Un vrai joueur qui clique apres sa victoire voyait la meme chose.

La cause est double, et les deux sont traitees :
  1. le client ENVOYAIT une pose alors que la partie etait finie ;
  2. un refus parti juste avant la fin revenait APRES, et etait affiche quand meme.

Ce banc lit le code : ces deux gardes doivent exister, au bon endroit, et reposer sur le meme
etat que l'ecran de fin (sinon l'un se leverait sans l'autre).
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
C = (ROOT / "src" / "client" / "GameClient.client.lua").read_text(encoding="utf-8")
ECHECS = []


def cas(nom, attendu, obtenu):
    ok = attendu == obtenu
    print(("  OK    " if ok else "  ROUGE ") + nom + " : attendu " + repr(attendu) + ", obtenu " + repr(obtenu))
    if not ok:
        ECHECS.append(nom)


def main():
    # Meme etat que l'ecran de fin : les deux sont poses cote a cote, sur `s.result`.
    cas("l'etat 'partie finie' suit l'ecran de fin", True,
        "overlay.Visible = s.result ~= nil" in C and "hud.partieFinie = s.result ~= nil" in C)
    # 1. Le clic n'envoie plus rien apres la fin, et ce test passe AVANT tout le reste.
    debut = C.index("local function deployAtScreen(x, y)")
    corps = C[debut:debut + 900]
    cas("un clic apres la fin n'envoie rien", True, "if hud.partieFinie then" in corps)
    cas("et ce test passe avant toute autre verification", True,
        corps.index("if hud.partieFinie then") < corps.index("if hud.spectateur then"))
    # 2. Un refus arrive trop tard n'est plus affiche.
    r = C.index("RefusEvent.OnClientEvent:Connect(function(motif)")
    cas("un refus tardif n'est pas affiche sur l'ecran de fin", True,
        "if hud.partieFinie then" in C[r:r + 500])
    cas("et il est ignore avant d'etre annonce", True,
        C[r:r + 700].index("if hud.partieFinie then") < C[r:r + 700].index("annoncer("))
    if ECHECS:
        print("ROUGE : %d cas en echec" % len(ECHECS))
        return 1
    print("VERT : apres la fin, aucun refus de pose ne recouvre le bouton Rejouer")
    return 0


sys.exit(main())
