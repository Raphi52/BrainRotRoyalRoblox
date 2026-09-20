# -*- coding: utf-8 -*-
"""Barre d'onglets du hub, style Clash Royale : 5 onglets, chacun avec son ecran et son clic.

Verifie dans Hub.client.lua : les cinq onglets sont declares dans l'ordre du jeu de reference,
chacun pointe un cadre existant, la barre est masquee pendant un match, et les onglets BOUTIQUE
et CARTES rejouent les ouvertures deja ecrites (pas de logique dupliquee).
"""
import re, sys, pathlib
H = (pathlib.Path(__file__).resolve().parent.parent / "src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []
bloc = re.search(r"local ONGLETS = \{(.*?)\n\}", H, re.S)
if not bloc:
    e.append("hub : table ONGLETS introuvable")
else:
    noms = re.findall(r'nom = "(\w+)"', bloc.group(1))
    if noms != ["boutique", "cartes", "bataille", "clan", "evenements"]:
        e.append("hub : ordre des onglets %r, attendu boutique/cartes/bataille/clan/evenements" % noms)
    for cadre in re.findall(r"cadre = (\w+)", bloc.group(1)):
        if not re.search(r"local %s = " % cadre, H):
            e.append("hub : l'onglet pointe le cadre « %s » qui n'existe pas" % cadre)
if "ouvrirEcranBoutique()" not in H or "ouvrirEcranDeck()" not in H:
    e.append("hub : les onglets ne rejouent pas les ouvertures boutique/deck existantes")
if not re.search(r"majOnglets = function", H):
    e.append("hub : majOnglets n'est jamais defini")
# Le retour au hub doit retomber sur BATAILLE. Depuis que la copie de test peut demander un
# autre onglet (BRR_ONGLET), ce n'est plus un appel litteral « majOnglets("bataille") » mais un
# REPLI : on verifie donc que le corps de ouvrirAccueil appelle bien majOnglets avec
# « bataille » comme valeur de secours. Retirer le repli fait retomber ce test au rouge.
corps = re.search(r"local function ouvrirAccueil\(\)(.*?)\nend", H, re.S)
if not corps:
    e.append("hub : ouvrirAccueil introuvable")
elif not re.search(r'majOnglets\((?:[^\n]*or\s*)?"bataille"\)', corps.group(1)):
    e.append("hub : le retour au hub ne selectionne pas l'onglet BATAILLE")
if H.count("barreOnglets.Visible = false") < 2:
    e.append("hub : la barre d'onglets n'est pas masquee pendant un match")
for x in e: print("ROUGE", x)
print("OK" if not e else "%d echec(s)" % len(e))
sys.exit(1 if e else 0)
