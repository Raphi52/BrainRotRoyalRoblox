"""Le manuel explique la PROGRESSION (coffres, exemplaires, niveaux, gemmes, quetes) avec les
chiffres des modules qui les appliquent."""
import pathlib, re, sys
from lupa import LuaRuntime
L = LuaRuntime()
M = L.execute(pathlib.Path("src/shared/Manuel.lua").read_text(encoding="utf-8"))
C = L.execute(pathlib.Path("src/shared/Coffres.lua").read_text(encoding="utf-8"))
Q = L.execute(pathlib.Path("src/shared/Quetes.lua").read_text(encoding="utf-8"))
eco = pathlib.Path("src/server/Economie.lua").read_text(encoding="utf-8")
hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
e = []
emp_serveur = int(re.search(r"Economie\.EMPLACEMENTS = (\d+)", eco).group(1))
emp_hub = int(re.search(r"emplacements = (\d+), -- Economie\.EMPLACEMENTS", hub).group(1))
if emp_hub != emp_serveur:
    e.append(f"le manuel annonce {emp_hub} emplacements, le serveur en a {emp_serveur}")
v = L.eval("{}"); v.emplacements = emp_hub; v.minutesParGemme = C.MINUTES_PAR_GEMME; v.gemmesQuete = Q.GEMMES
secs = {s.titre: s.texte for s in M.sections(v).values()}
p = secs.get("PROGRESSION")
if not p:
    e.append("aucune section PROGRESSION")
else:
    for mot in ("coffre", "EXEMPLAIRES", "niveau", "GEMMES", "quete", "%d emplacements" % emp_serveur,
                "1 par %d min" % C.MINUTES_PAR_GEMME, "en rapporte %d" % Q.GEMMES):
        if mot not in p:
            e.append("la section PROGRESSION ne dit pas : " + mot)
if "PROGRESSION" in {s.titre for s in M.sections(L.eval("{}")).values()}:
    e.append("sans chiffres, la section ne doit pas s'afficher")
for x in e:
    print("  ROUGE", x)
if e:
    print("ROUGE : le manuel n'explique pas la progression"); sys.exit(1)
print("VERT : le manuel explique la progression, avec les chiffres du jeu")
