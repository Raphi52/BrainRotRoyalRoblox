# -*- coding: utf-8 -*-
"""TELEVERSER les sprites de tools/sprites/ sur Roblox depuis Studio, sur un bureau Windows CACHE.

Pourquoi (2026-10-05) : aucune cle Open Cloud n'est configuree, mais Studio est connecte au compte
de l'utilisateur. Un plugin LOCAL (pas un plugin du Creator Store, pour lesquels l'API est fermee)
peut creer un asset image avec AssetService:CreateAssetAsync a partir d'une EditableImage :
https://create.roblox.com/docs/reference/engine/classes/AssetService#CreateAssetAsync
Rien ne s'affiche chez l'utilisateur (meme voie que tools/studio-capture-moteur.ps1).

Deroule :
  1. Chaque PNG est lu en RGBA et embarque en base64 dans un plugin TEMPORAIRE.
  2. Studio ouvre une place minuscule portant le repere BRR_TELEVERSER_SPRITES (le plugin ne fait
     rien ailleurs) ; le plugin cree l'EditableImage, la televerse, et ecrit
     « [BRRSPRITE] <nom> <id> » dans le journal de Studio.
  3. Le journal est lu, les ids vont dans tools/sprites/ids.json puis dans src/shared/Sprites.lua.
  4. Seul NOTRE Studio est arrete ; le plugin est retire.
Un sprite dont le PNG n'a pas change depuis son dernier envoi (empreinte sha1) n'est pas renvoye.

DEUX VOIES. Avec la variable ROBLOX_ASSETS_API_KEY (cle Open Cloud de l'utilisateur, droits
« Assets : lecture + ecriture »), les PNG partent par l'API Open Cloud comme decalques, et Studio ne
fait que lire l'id de l'IMAGE de chaque decalque (InsertService:LoadAsset). Sans elle, Studio tente
AssetService:CreateAssetAsync — refuse le 2026-10-05 : « CreateAssetAsync and
CreateAssetVersionAsync are not available yet ».

Usage : python tools/televerser_sprites.py [--forcer]
Code 0 = tout est en ligne ; 1 = echec (motif imprime) ; 5 = Studio deconnecte.
"""
import base64
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import time

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITES = ROOT / "tools" / "sprites"
IDS = SPRITES / "ids.json"
MODULE = ROOT / "src" / "shared" / "Sprites.lua"
# Le depot Autowin a change de nom (D:\AutoWinOS -> D:\Autowin, constate le 2026-10-05) : on prend
# le premier lanceur qui existe.
HDESK_LANCER = next((p for p in (r"D:\Autowin\scripts\hdesk-lancer.ps1", r"D:\AutoWinOS\scripts\hdesk-lancer.ps1")
                     if pathlib.Path(p).exists()), r"D:\Autowin\scripts\hdesk-lancer.ps1")
LOGS = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "logs"
PLUGINS = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "Plugins"
PLUGIN = PLUGINS / "BRR_TeleverserSprites.lua"
PLACE = ROOT / "captures" / "televerser-sprites.rbxlx"
REPERE = "BRR_TELEVERSER_SPRITES"
DELAI = 300
UTILISATEUR = 11665960588  # compte connecte a Studio (journal « [BRRSPRITE] debut compte », 2026-10-05)

PLACE_XML = f"""<roblox version="4">
<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string></Properties>
<Item class="Folder" referent="RBX1"><Properties><string name="Name">{REPERE}</string></Properties></Item>
</Item>
</roblox>
"""

PLUGIN_LUA = r"""-- PLUGIN TEMPORAIRE pose par tools/televerser_sprites.py : il se retire apres usage.
if not workspace:FindFirstChild("__REPERE__") then
	return
end
local AssetService = game:GetService("AssetService")
local StudioService = game:GetService("StudioService")
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VAL = {}
for i = 1, 64 do
	VAL[string.byte(ALPHA, i)] = i - 1
end
local function decoder(s)
	local n = #s
	local pad = 0
	if string.sub(s, -2) == "==" then pad = 2 elseif string.sub(s, -1) == "=" then pad = 1 end
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = VAL[a] * 262144 + VAL[b] * 4096 + (VAL[c] or 0) * 64 + (VAL[d] or 0)
		buffer.writeu8(out, o, v // 65536); o += 1
		if o < buffer.len(out) then buffer.writeu8(out, o, (v // 256) % 256); o += 1 end
		if o < buffer.len(out) then buffer.writeu8(out, o, v % 256); o += 1 end
	end
	return out
end
local IMAGES = __IMAGES__
task.wait(5)
local uid = StudioService:GetUserId()
print("[BRRSPRITE] debut compte " .. tostring(uid) .. " images " .. #IMAGES)
for _, im in ipairs(IMAGES) do
	local ok, err = pcall(function()
		if im.decal then
			-- Voie Open Cloud : le decalque est deja en ligne, on lit l'id de SON image.
			local modele = game:GetService("InsertService"):LoadAsset(im.decal)
			local d = modele:FindFirstChildWhichIsA("Decal", true)
			local id = d and string.match(d.Texture, "(%d+)%s*$")
			if id then
				print("[BRRSPRITE] ok " .. im.nom .. " " .. id)
			else
				print("[BRRSPRITE] echec " .. im.nom .. " decalque " .. im.decal .. " sans image")
			end
			return
		end
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(im.l, im.h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(im.l, im.h), decoder(im.b64))
		local reussi, resultat, id = AssetService:CreateAssetAsync(img, Enum.AssetType.Image, {
			CreatorId = uid,
			CreatorType = Enum.AssetCreatorType.User,
			Name = "BRR " .. im.nom,
			Description = "Brainrot Royale - sprite genere par tools/sprites_coffres.py",
		})
		if reussi then
			print("[BRRSPRITE] ok " .. im.nom .. " " .. tostring(id))
		else
			print("[BRRSPRITE] echec " .. im.nom .. " " .. tostring(resultat) .. " " .. tostring(id))
		end
	end)
	if not ok then
		print("[BRRSPRITE] echec " .. im.nom .. " " .. tostring(err))
	end
end
print("[BRRSPRITE] fin")
"""


def televerser_open_cloud(cle, png):
    """Envoie le PNG comme decalque (type image de l'API) et rend l'id du DECALQUE.
    https://create.roblox.com/docs/cloud/guides/usage-assets — la cle n'est jamais imprimee."""
    import urllib.request
    frontiere = "brr" + empreinte(png)
    requete = json.dumps({"assetType": "Decal", "displayName": "BRR " + png.stem,
                          "description": "Brainrot Royale - sprite genere par tools/sprites_coffres.py",
                          "creationContext": {"creator": {"userId": str(UTILISATEUR)}}})
    corps = (f'--{frontiere}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{requete}\r\n'
             f'--{frontiere}\r\nContent-Disposition: form-data; name="fileContent"; filename="{png.name}"\r\n'
             f'Content-Type: image/png\r\n\r\n').encode() + png.read_bytes() + f"\r\n--{frontiere}--\r\n".encode()
    r = urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=corps, method="POST",
                               headers={"x-api-key": cle, "Content-Type": f"multipart/form-data; boundary={frontiere}"})
    op = json.loads(urllib.request.urlopen(r, timeout=60).read())
    for _ in range(60):
        if op.get("done"):
            return int(op["response"]["assetId"])
        time.sleep(2)
        r = urllib.request.Request("https://apis.roblox.com/assets/v1/" + op["path"], headers={"x-api-key": cle})
        op = json.loads(urllib.request.urlopen(r, timeout=60).read())
    raise RuntimeError("operation Open Cloud non terminee pour " + png.name)


def empreinte(p):
    return hashlib.sha1(p.read_bytes()).hexdigest()


def studio_exe():
    cands = list(pathlib.Path(r"C:\Program Files\Roblox\Versions").glob("*/RobloxStudioBeta.exe"))
    cands += list(pathlib.Path(r"C:\Program Files (x86)\Roblox\Versions").glob("*/RobloxStudioBeta.exe"))
    # Studio s'installe aussi PAR UTILISATEUR (constate le 2026-10-05 : plus rien sous Program Files).
    cands += list((pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "Versions").glob("*/RobloxStudioBeta.exe"))
    return str(max(cands, key=lambda p: p.stat().st_mtime))


def ecrire_module(ids):
    lignes = [
        "-- SPRITES TELEVERSES (genere par tools/televerser_sprites.py, ne pas editer a la main).",
        "-- Source de chaque image : tools/sprites/<nom>.png, dessinee par tools/sprites_coffres.py",
        "-- (aucune ressource externe). Revise le choix « aucun asset a televerser » de Habillage.lua",
        "-- pour les coffres : les cadres empiles etaient juges illisibles (2026-10-05).",
        "-- Un nom absent rend nil : l'appelant garde alors son dessin en cadres.",
        "local Sprites = {}",
        "",
        "Sprites.IDS = {",
    ]
    for nom in sorted(ids):
        lignes.append(f'\t["{nom}"] = {ids[nom]["id"]}, -- tools/sprites/{nom}.png sha1 {ids[nom]["sha1"][:12]}')
    lignes += [
        "}",
        "",
        "function Sprites.image(nom)",
        "\tlocal id = Sprites.IDS[nom]",
        "\tif not id then",
        "\t\treturn nil",
        "\tend",
        '\treturn "rbxassetid://" .. id',
        "end",
        "",
        "return Sprites",
        "",
    ]
    MODULE.write_bytes("\n".join(lignes).encode("utf-8"))


def main():
    forcer = "--forcer" in sys.argv
    ids = json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}
    a_envoyer = []
    for png in sorted(SPRITES.glob("*.png")):
        nom = png.stem
        if not forcer and nom in ids and ids[nom]["sha1"] == empreinte(png):
            continue
        im = Image.open(png).convert("RGBA")
        a_envoyer.append((nom, png, im))
    if not a_envoyer:
        ecrire_module(ids)
        print(json.dumps({"ok": True, "envoyes": 0, "ids": {k: v["id"] for k, v in ids.items()}}))
        return 0
    cle = os.environ.get("ROBLOX_ASSETS_API_KEY")
    if cle:
        decals = {nom: televerser_open_cloud(cle, png) for nom, png, _ in a_envoyer}
        images = ",\n".join(f'{{ nom = "{nom}", decal = {d} }}' for nom, d in decals.items())
    else:
        images = ",\n".join(
            f'{{ nom = "{nom}", l = {im.width}, h = {im.height}, b64 = "{base64.b64encode(im.tobytes()).decode()}" }}'
            for nom, _, im in a_envoyer)
    PLUGINS.mkdir(parents=True, exist_ok=True)
    PLUGIN.write_bytes(PLUGIN_LUA.replace("__REPERE__", REPERE).replace("__IMAGES__", "{\n" + images + "\n}").encode("utf-8"))
    PLACE.parent.mkdir(parents=True, exist_ok=True)
    PLACE.write_bytes(PLACE_XML.encode("utf-8"))
    depart = time.time()
    pid = None
    try:
        sortie = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", HDESK_LANCER,
             "-Id", "brrsprites", "-Executable", studio_exe(), "-Arguments", f'"{PLACE}"',
             "-Travail", "televersement des sprites de coffres", "-Conversation", "brr-sprites"],
            capture_output=True, text=True, timeout=120).stdout.strip().splitlines()
        lance = json.loads(sortie[-1]) if sortie else {}
        pid = lance.get("pid")
        if not pid:
            print("echec : le bureau cache n'a pas rendu de processus :", lance.get("erreur"))
            return 1
        journal = None
        lignes = []
        while time.time() - depart < DELAI:
            time.sleep(3)
            if journal is None:
                for f in sorted(LOGS.glob("*Studio*.log"), key=lambda f: f.stat().st_mtime, reverse=True):
                    if f.stat().st_mtime > depart and PLACE.name in f.read_text(encoding="utf-8", errors="ignore"):
                        journal = f
                        break
                continue
            texte = journal.read_text(encoding="utf-8", errors="ignore")
            if re.search(r"show login dialog \[start\]|awaitQuickSignIn", texte):
                print("Studio n'est plus connecte a Roblox : ouvre Studio une fois et reconnecte-toi.")
                return 5
            lignes = re.findall(r"\[BRRSPRITE\] (.*)", texte)
            if any(l.strip() == "fin" for l in lignes):
                break
        else:
            print("echec : pas de « [BRRSPRITE] fin » en", DELAI, "s ; journal :", journal, "; lignes :", lignes)
            return 1
        echecs = []
        for l in lignes:
            m = re.match(r"ok (\S+) (\d+)", l.strip())
            if m:
                nom = m.group(1)
                ids[nom] = {"id": int(m.group(2)), "sha1": empreinte(SPRITES / (nom + ".png"))}
            elif l.startswith("echec"):
                echecs.append(l.strip())
        IDS.write_bytes((json.dumps(ids, indent=2, sort_keys=True) + "\n").encode("utf-8"))
        ecrire_module(ids)
        print(json.dumps({"ok": not echecs, "journal": str(journal), "lignes": lignes,
                          "ids": {k: v["id"] for k, v in ids.items()}}, ensure_ascii=False))
        if echecs and not cle and any("not available yet" in e for e in echecs):
            print("BLOQUE : Studio refuse de televerser (CreateAssetAsync fermee). Cree une cle Open Cloud "
                  "(Creator Dashboard > Open Cloud > API Keys, droits Assets lecture + ecriture), "
                  "enregistre-la dans la variable ROBLOX_ASSETS_API_KEY, puis relance.")
        return 0 if not echecs else 1
    finally:
        if pid:
            subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
        PLUGIN.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
