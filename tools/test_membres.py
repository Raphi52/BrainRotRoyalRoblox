"""Onglet CLAN : la liste du serveur donne les TROPHEES de chacun, triee du plus fort au plus faible."""
import pathlib, sys
from lupa import LuaRuntime
L = LuaRuntime()
A = L.execute(pathlib.Path("src/shared/Adversaire.lua").read_text(encoding="utf-8"))
m = L.eval("""{ { nom = "Zoe", trophees = 120 }, { nom = "Moi", trophees = 340, moi = true },
  { nom = "Abel", trophees = 120 }, { nom = "Nouveau" } }""")
l = list(A.lignesMembres(m).values())
att = ["1. Moi  (toi)   340 trophees", "2. Abel   120 trophees", "3. Zoe   120 trophees", "4. Nouveau"]
ok = l == att
print("  OK " if ok else "  ROUGE", l)
hub = pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8")
ok2 = "lignesMembres(membres)" in hub and 'FindFirstChild("Trophees")' in hub
print("  OK " if ok2 else "  ROUGE", "le hub lit leaderstats.Trophees et passe par le module")
if not (ok and ok2):
    print("ROUGE : liste du serveur sans trophees ou mal triee"); sys.exit(1)
print("VERT : la liste du serveur donne les trophees de chacun, du plus fort au plus faible")
