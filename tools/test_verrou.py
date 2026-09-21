"""Une carte verrouillee par une arene dit COMBIEN de trophees il manque."""
import pathlib, sys
from lupa import LuaRuntime
L = LuaRuntime()
A = L.execute(pathlib.Path("src/shared/Arenes.lua").read_text(encoding="utf-8"))
e = []
if A.tropheesManquants("Bombardiro", 50) != 150: e.append("Bombardiro a 50 trophees : 150 manquent")
if A.tropheesManquants("Bicus", 0) != 600: e.append("Bicus : 600")
if A.tropheesManquants("Tralalero", 0) is not None: e.append("carte libre : pas de verrou")
if A.texteVerrou(500, "Bombardiro", 50) != "500 pieces - encore 150 trophees": e.append(A.texteVerrou(500, "Bombardiro", 50))
if A.texteVerrou(500, "Bombardiro", 300) != "500 pieces": e.append("arene atteinte : prix seul")
if "Arenes.texteVerrou(card.prix, card.id" not in pathlib.Path("src/client/Hub.client.lua").read_text(encoding="utf-8"):
    e.append("la boutique n'utilise pas texteVerrou")
for x in e: print("  ROUGE", x)
if e: print("ROUGE : verrou d'arene muet"); sys.exit(1)
print("VERT : une carte verrouillee dit combien de trophees il manque")
