"""Le panneau DUEL ENTRE AMIS dit ce que le duel met en jeu, en accord avec le serveur."""
import pathlib, sys
from lupa import LuaRuntime
L = LuaRuntime()
D = L.execute(pathlib.Path("src/shared/Duel.lua").read_text(encoding="utf-8"))
e = []
# ce que le texte promet doit etre ce que le serveur applique
if D.compteAuClassement(False, True):
    e.append("le serveur fait compter un duel entre amis : le texte « ni trophees ni coffre » mentirait")
a = D.texteAide(False, 3); b = D.texteAide(True, 3)
if "ni trophees ni coffre" not in a: e.append(a)
if "niveau 3" not in b: e.append(b)
hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
if "D.texteAide(egaliseActif, E.NIVEAU)" not in hub: e.append("le panneau n'affiche pas l'aide")
for x in e: print("  ROUGE", x)
if e: print("ROUGE : duel entre amis sans explication"); sys.exit(1)
print("VERT : le panneau des amis dit ce que le duel met en jeu")
