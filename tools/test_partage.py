# -*- coding: utf-8 -*-
"""PARTAGE D'UNE FIN DE PARTIE (src/shared/Partage.lua).

Le defaut corrige : rien ne sortait du jeu. La partie finie disparaissait a l'ecran suivant — on
ne pouvait ni la montrer, ni la comparer, ni s'en souvenir precisement.

CE QUI N'EST PAS PROMIS : un replay. On n'enregistre pas les coups. Le banc verifie donc ce qui
est reellement livre : un RESUME lisible et un CODE compact qui se RELIT (aller-retour exact).

1) Regles PURES executees (lupa) : code deterministe, relecture fidele, refus d'un code etranger,
   bornes, duree en minutes:secondes, resume contenant les faits de la partie.
2) Branchement lu : le module est embarque dans la place, le serveur calcule le resume a la fin et
   l'expose, le client l'affiche dans un champ SELECTIONNABLE et non modifiable.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bancs import zone  # decoupe par CONTENU (voir tools/bancs.py)
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
PA = (R / "src/shared/Partage.lua").read_text(encoding="utf-8")
S = (R / "src/server/GameServer.server.lua").read_text(encoding="utf-8")
C = (R / "src/client/GameClient.client.lua").read_text(encoding="utf-8")
B = (R / "build.py").read_text(encoding="utf-8")
e = []
lua = LuaRuntime()
M = lua.execute(PA)

PARTIE = dict(issue="victoire", couronnesMoi=3, couronnesLui=1, adversaire="Zoe",
              duree=134, cartes=17, gaspille=6, degatsTours=2480, decor="Prairie")
def t(d):
    return lua.table_from(d)

# --- CODE : deterministe, compact, lisible a voix haute -----------------------------------------
code = M.code(t(PARTIE))
if M.code(t(PARTIE)) != code:
    e.append("le meme match doit toujours donner le meme code")
if not code.startswith("BRR1-"):
    e.append("le code doit porter sa version, sinon on ne saura pas le relire plus tard : " + code)
if len(code) > 24 or "\n" in code:
    e.append("le code doit tenir sur une ligne courte (dictable) : " + code)

# --- ALLER-RETOUR : le code PORTE les chiffres, il ne les perd pas ------------------------------
lu = M.lire(code)
if lu is None:
    e.append("le code qu'on vient d'ecrire doit se relire")
else:
    for cle, attendu in (("issue", "victoire"), ("couronnesMoi", 3), ("couronnesLui", 1),
                         ("duree", 134), ("gaspille", 6), ("cartes", 17)):
        if lu[cle] != attendu:
            e.append("relecture fausse pour %s : %r au lieu de %r" % (cle, lu[cle], attendu))

# Une defaite et une egalite doivent se distinguer d'une victoire, sinon le code ne dit rien.
issues = {i: M.code(t(dict(PARTIE, issue=i))) for i in ("victoire", "defaite", "egalite")}
if len(set(issues.values())) != 3:
    e.append("victoire, defaite et egalite produisent le meme code : %r" % issues)
for i, c in issues.items():
    if M.lire(c)["issue"] != i:
        e.append("l'issue %s ne se relit pas" % i)

# --- REFUS : un code etranger ne doit pas produire des chiffres inventes -------------------------
for mauvais in ("", "bonjour", "BRR1-V3", "BRR9-V30-134-6-17", "BRR1-X30-134-6-17",
                "BRR1-V30-134-6", "BRR1-V30-134-6-17-2", None, 42):
    if M.lire(mauvais) is not None:
        e.append("un code invalide doit etre refuse, pas devine : %r" % (mauvais,))

# --- BORNES : des donnees aberrantes ne cassent ni le code ni sa relecture -----------------------
extreme = M.code(t(dict(PARTIE, couronnesMoi=99, couronnesLui=-4, duree=-10, gaspille=100000)))
relu = M.lire(extreme)
if relu is None:
    e.append("un match aux valeurs extremes doit quand meme produire un code relisible : " + extreme)
else:
    if relu["couronnesMoi"] != 3 or relu["couronnesLui"] != 0:
        e.append("les couronnes doivent rester entre 0 et 3 : %r" % extreme)
    if relu["duree"] < 0:
        e.append("une duree negative ne doit pas sortir du code")

# --- DUREE lisible -------------------------------------------------------------------------------
for secondes, attendu in ((0, "0:00"), (9, "0:09"), (134, "2:14"), (180, "3:00")):
    if M.duree(secondes) != attendu:
        e.append("duree %s : %r au lieu de %r" % (secondes, M.duree(secondes), attendu))

# --- RESUME LISIBLE : les faits de la partie, et le code au bout ---------------------------------
resume = M.resume(t(PARTIE))
for morceau in ("Victoire", "3-1", "Zoe", "2:14", "17", "6", "2480", "Prairie", code):
    if morceau not in resume:
        e.append("le resume ne porte pas %r :\n%s" % (morceau, resume))
# Aucune ligne ne doit commencer ni finir par un separateur orphelin : le resume est colle tel
# quel dans un message, une ligne bancale s'y voit immediatement.
for ligne in resume.splitlines():
    if ligne.strip() != ligne or ligne.lstrip().startswith("·") or ligne.rstrip().endswith("·"):
        e.append("ligne mal formee dans le resume : %r" % ligne)
if len(resume.splitlines()) > 6:
    e.append("le resume doit rester court (un message, pas un rapport) :\n" + resume)
if "Defaite" not in M.resume(t(dict(PARTIE, issue="defaite"))):
    e.append("une defaite doit s'annoncer comme telle dans le resume")
# Un match sans adversaire humain ne doit pas afficher un nom vide.
if "Robot" not in M.resume(t(dict(PARTIE, adversaire=None))):
    e.append("sans nom d'adversaire, le resume doit nommer le robot")
# Le resume doit se passer de toute donnee : un appel nu ne doit pas planter.
if not M.resume(None):
    e.append("un resume sans donnees doit rester un texte, pas une erreur")

# --- BRANCHEMENT ---------------------------------------------------------------------------------
if 'source=src("shared/Partage.lua")' not in B:
    e.append("Partage.lua n'est pas embarque dans la place : le client attendra le module a l'infini")
if 'WaitForChild("Partage")' not in S:
    e.append("le serveur ne charge pas Partage")
if "Partage.resume(" not in S:
    e.append("le serveur ne calcule jamais le resume")
if "partage = result and resumePartage(" not in S:
    e.append("le resume n'est pas expose au client a la fin de la partie")
if "vainqueur == nil" not in S.split("local function resumePartage(")[1].split("\nend")[0]:
    e.append("le resume doit rester vide tant que la partie n'est pas finie")
if "hud.partageTexte.Text = texte" not in C:
    e.append("le client n'affiche pas le resume")
if "hud.partageTexte.TextEditable = false" not in C:
    e.append("le champ de partage doit etre non modifiable : on partage un resume, pas un brouillon")
if "hud.partageTexte.ClearTextOnFocus = false" not in C:
    e.append("sans ClearTextOnFocus=false, le clic pour selectionner EFFACE le resume")
# Le bouton « Rejouer » traversait le resume (capture du 2026-09-20) : il doit etre REPLACE selon
# ce qui est visible, pas pose a un offset fixe.
suite = zone(C, "	majPartage(s)", "overlay.Visible")
if "local function placerRejouer()" not in C or "placerRejouer()" not in suite:
    e.append("le bouton Rejouer n'est pas replace apres l'affichage du resume : il le recouvrira")
# La place du resume vient desormais de la mise en page calculee (src/shared/Mise.lua, bloc
# « finpartage »), verifiee sur tous les formats par tools/test_mise.py — plus aucun offset a la
# main sous le recapitulatif.
if 'poser(hud.partageCadre, Mise.trouver(fins, "finpartage"))' not in C:
    e.append("le bloc de partage n'est pas pose par la mise en page calculee")
if 'hud.misePermet["finpartage"]' not in C:
    e.append("le resume ignore la mise en page : il s'afficherait meme sans place pour lui")
if "majPartage(s)" not in C:
    e.append("majPartage n'est jamais appele : le bloc resterait fige")

if e:
    print("ROUGE : partage de fin de partie")
    for m in e:
        print("  - " + m)
    sys.exit(1)
print("VERT : partage de fin de partie (code relisible, resume copiable, branchement)")
print("  code du match temoin : " + code)
print("  " + resume.replace("\n", "\n  "))
