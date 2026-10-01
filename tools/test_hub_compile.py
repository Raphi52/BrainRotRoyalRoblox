# -*- coding: utf-8 -*-
"""Les scripts clients COMPILENT, et le hub reste sous le plafond des 200 variables locales.

Cause mesuree le 2026-09-20 (journal Studio) : « Hub:2432: Out of local registers ... exceeded
limit 200 » — une variable locale de trop dans le corps principal de Hub.client.lua et le menu ne
se chargeait PLUS DU TOUT. Jusqu'ici, seul Studio pouvait le dire.

Ici : l'interpreteur Lua du banc (lupa) compile chaque script. Lua a la MEME limite que Luau
(200 variables locales actives par fonction). Les deux ecritures propres a Luau que le code
emploie (`x += 1`, `x -= 1`...) sont d'abord reecrites en Lua standard. Le banc mesure aussi la
MARGE : combien de variables locales on peut encore ajouter a la fin du corps principal.
Limite : c'est une compilation, pas une execution — un nom mal orthographie ne se voit qu'a
l'execution (voir test_client_locales.py et le faux Roblox de test_habillage.py).
"""
import re, sys, pathlib
from lupa import LuaRuntime

R = pathlib.Path(__file__).resolve().parent.parent
L = LuaRuntime()
compiler = L.eval("function(s) local f, err = load(s) return err end")


def en_lua(src):
    return re.sub(r"^(\s*)([\w\.\[\]\"]+)\s*([+\-*/]|\.\.)=\s*(.+)$",
                  lambda m: f"{m.group(1)}{m.group(2)} = {m.group(2)} {m.group(3)} ({m.group(4)})",
                  src, flags=re.M)


e = []
for rel in ("src/client/Hub.client.lua", "src/client/GameClient.client.lua", "src/shared/Habillage.lua"):
    src = en_lua((R / rel).read_text(encoding="utf-8"))
    err = compiler(src)
    if err:
        e.append(f"{rel} ne compile pas : {err}")
        continue
    if rel.endswith("Hub.client.lua"):
        marge = 0
        while marge < 50 and not compiler(src + "\n" + "\n".join(f"local _m{i} = {i}" for i in range(marge + 1))):
            marge += 1
        print(f"hub : {marge} variable(s) locale(s) de marge a la fin du corps principal")
for x in e:
    print("ROUGE", x)
print("OK" if not e else f"{len(e)} echec(s)")
sys.exit(1 if e else 0)
