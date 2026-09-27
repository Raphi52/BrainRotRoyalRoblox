# -*- coding: utf-8 -*-
"""REPUBLIER la place Brainrot Royale depuis Roblox Studio, sur un bureau Windows CACHE.

Pourquoi (2026-09-27) : publier par l'interface de Studio sur l'ecran reel derangeait l'utilisateur
(et echouait des que sa fenetre Bureau a distance etait reduite ou qu'un autre travail occupait
Studio) ; l'API Open Cloud (tools/publier_place.py) exige une cle que seul lui peut creer. Ici, rien
ne s'affiche chez lui et aucune cle n'est necessaire : Studio est deja connecte a son compte.

Deroule :
  1. `python build.py` reconstruit BrainRotRoyale.rbxlx ; ses 79 scripts sont lus.
  2. Un plugin local TEMPORAIRE (garde par game.PlaceId) ouvre la place EN LIGNE et remplace le
     Source de chaque script qui differe du code local (fins de ligne ignorees). Un script absent
     en ligne arrete tout : cet outil ne transporte que du CODE ; une place dont la STRUCTURE a change
     (build.py) se republie depuis le fichier (Fichier > Publier sur Roblox comme).
  3. Fichier > Publier sur Roblox, AU CLAVIER : un menu Qt s'ouvre au clic poste mais ne s'active
     qu'au clavier (mesure du 2026-09-27) ; « Publier sur Roblox » est la 15e entree du menu Fichier
     d'une place en ligne.
  4. Preuve dans le journal de Studio : « Go to PublishSuccessful » et « version N ».
  5. Controle : un SECOND Studio rouvre la place en ligne et compare les scripts -> 0 ecart attendu.
Seul NOTRE Studio est arrete (ligne de commande -placeId, demarre apres nous) ; le plugin est retire.

Usage : python tools/publier_studio_cache.py [--comparer-seulement]
Code 0 = publie (ou deja a jour) ET controle a 0 ecart ; 1 = echec ; 2 = refus (script absent en ligne).
"""
import ctypes
import ctypes.wintypes as W
import json
import os
import pathlib
import re
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLACE_ID = 126168119650545
UNIVERSE_ID = 10768149063
HDESK_LANCER = r"D:\AutoWinOS\scripts\hdesk-lancer.ps1"
LOGS = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "logs"
PLUGINS = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "Plugins"
ENTREE_PUBLIER = 15  # rang de « Publier sur Roblox » dans le menu Fichier d'une place EN LIGNE
ATTENTE_AVANT_GESTE = 45  # secondes entre « place prete » et le geste clavier


def studio_exe():
    cands = list(pathlib.Path(r"C:\Program Files\Roblox\Versions").glob("*/RobloxStudioBeta.exe"))
    cands += list(pathlib.Path(r"C:\Program Files (x86)\Roblox\Versions").glob("*/RobloxStudioBeta.exe"))
    return str(max(cands, key=lambda p: p.stat().st_mtime))


def scripts_de_la_place(fichier):
    racine = ET.parse(fichier).getroot()
    out = []

    def nom(it):
        props = it.find("Properties")
        for s in (props.findall("string") if props is not None else []):
            if s.get("name") == "Name":
                return s.text
        return it.get("class")

    def parcourir(it, chemin):
        p = chemin + [nom(it)]
        if it.get("class") in ("Script", "LocalScript", "ModuleScript"):
            src = [x for x in it.find("Properties") if x.get("name") == "Source"]
            out.append(("/".join(p), src[0].text or "" if src else ""))
        for enfant in it.findall("Item"):
            parcourir(enfant, p)

    for it in racine.findall("Item"):
        parcourir(it, [])
    return out


def ecrire_plugin(scripts, mode, jeton):
    tout = "".join(s for _, s in scripts)
    niveau = 1
    while ("]" + "=" * niveau + "]") in tout:
        niveau += 1
    o, f = "[" + "=" * niveau + "[", "]" + "=" * niveau + "]"
    lignes = ["-- Plugin TEMPORAIRE ecrit par tools/publier_studio_cache.py (a supprimer s'il reste la).",
              "local RunService = game:GetService('RunService')",
              "if not RunService:IsEdit() then return end",
              "local PLACE = %d" % PLACE_ID, "local MODE = '%s'" % mode, "local TAG = '[BRRPUB %s]'" % jeton,
              "local SCRIPTS = {"]
    for chemin, src in scripts:
        lignes.append("{ %s, %s%s%s }," % (json.dumps(chemin), o, "\n" + src, f))
    lignes.append("}")
    lignes.append("""
local function norm(s) return (string.gsub(s, "\\r", "")) end
task.spawn(function()
	for _ = 1, 180 do
		if game.PlaceId == PLACE then break end
		task.wait(1)
	end
	if game.PlaceId ~= PLACE then return end
	task.wait(3)
	local modifies, absents, refus = 0, 0, 0
	local SES = game:GetService("ScriptEditorService")
	for _, e in ipairs(SCRIPTS) do
		local inst = game
		for morceau in string.gmatch(e[1], "[^/]+") do
			inst = inst and inst:FindFirstChild(morceau)
		end
		if not inst then
			absents += 1
			print(TAG .. " ABSENT " .. e[1])
		elseif norm(inst.Source) ~= norm(e[2]) then
			modifies += 1
			if MODE == "appliquer" then
				-- UpdateSourceAsync : l'affectation directe de Source est plafonnee a 200 000
				-- caracteres (GameServer en fait plus de 250 000, mesure du 2026-09-27).
				local ok, err = pcall(function()
					SES:UpdateSourceAsync(inst, function() return e[2] end)
				end)
				if not ok or norm(inst.Source) ~= norm(e[2]) then
					refus += 1
					print(TAG .. " REFUS " .. e[1] .. " " .. tostring(err))
				end
			end
			print(TAG .. " DIFFERENT " .. e[1])
		end
	end
	print(string.format("%s PRET mode=%s scripts=%d modifies=%d absents=%d refus=%d", TAG, MODE, #SCRIPTS, modifies, absents, refus))
end)
""")
    chemin = PLUGINS / ("BRR_Publier-%s.lua" % jeton)
    PLUGINS.mkdir(parents=True, exist_ok=True)
    # « [==[\n » : Lua ignore le premier saut de ligne d'une chaine longue, le source reste intact.
    chemin.write_text("\n".join(lignes), encoding="utf-8")
    return chemin


# ---------- fenetres du bureau cache (ctypes) ----------
u32 = ctypes.WinDLL("user32", use_last_error=True)
ENUM = ctypes.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
u32.OpenDesktopW.restype = W.HANDLE
u32.SetThreadDpiAwarenessContext.restype = ctypes.c_void_p
u32.SetThreadDpiAwarenessContext.argtypes = [ctypes.c_void_p]


def dans_le_bureau(bureau, fonction):
    """Execute `fonction()` dans un FIL NEUF attache au bureau cache (SetThreadDesktop l'exige)."""
    res = {}

    def corps():
        u32.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
        d = u32.OpenDesktopW(bureau, 0, False, 0x10000000)
        if not d:
            res["erreur"] = "bureau introuvable : %s" % bureau
            return
        u32.SetThreadDesktop(d)
        try:
            res["valeur"] = fonction(d)
        finally:
            u32.CloseDesktop(d)

    t = threading.Thread(target=corps)
    t.start()
    t.join()
    if "erreur" in res:
        raise RuntimeError(res["erreur"])
    return res.get("valeur")


def fenetres(d):
    liste = []

    def cb(h, _l):
        if u32.IsWindowVisible(h):
            buf = ctypes.create_unicode_buffer(256)
            u32.GetWindowTextW(h, buf, 256)
            liste.append((h, buf.value))
        return True
    u32.EnumDesktopWindows(d, ENUM(cb), 0)
    return liste


def poster_clic(h, x, y):
    lp = (y << 16) | (x & 0xFFFF)
    u32.PostMessageW(h, 0x200, 0, lp)
    time.sleep(0.04)
    u32.PostMessageW(h, 0x201, 1, lp)
    time.sleep(0.06)
    u32.PostMessageW(h, 0x202, 0, lp)


def poster_touche(h, vk, n=1):
    for _ in range(n):
        u32.PostMessageW(h, 0x100, vk, 1)
        time.sleep(0.04)
        u32.PostMessageW(h, 0x101, vk, 0xC0000001)
        time.sleep(0.06)


def publier_au_clavier(bureau):
    def geste(d):
        principales = [h for h, t in fenetres(d) if t.endswith("- Roblox Studio")]
        if not principales:
            return "fenetre de Studio introuvable"
        h = principales[0]
        u32.ShowWindow(h, 3)  # maximiser : sinon le menu Fichier peut sortir du bureau
        time.sleep(1.0)
        echelle = (u32.GetDpiForWindow(h) or 96) / 96.0
        poster_clic(h, int(25 * echelle), int(12 * echelle))  # « Fichier », coordonnees client
        time.sleep(1.2)
        menus = [m for m, t in fenetres(d) if t == "RobloxStudio" and m != h]
        if not menus:
            return "le menu Fichier ne s'est pas ouvert"
        poster_touche(menus[0], 0x28, ENTREE_PUBLIER)
        poster_touche(menus[0], 0x0D)
        return "ok"
    return dans_le_bureau(bureau, geste)


# ---------- journal et processus ----------
def journal_du_jeton(jeton, depuis, delai):
    fin = time.time() + delai
    while time.time() < fin:
        for f in sorted(LOGS.glob("*Studio*.log"), key=lambda p: p.stat().st_mtime, reverse=True)[:6]:
            if f.stat().st_mtime < depuis:
                continue
            texte = f.read_text(encoding="utf-8", errors="replace")
            if "[BRRPUB %s] PRET" % jeton in texte:
                return f
        time.sleep(3)
    return None


def arreter_notre_studio(depuis):
    ps = ("Get-CimInstance Win32_Process -Filter \"Name='RobloxStudioBeta.exe'\" | "
          "Where-Object { $_.CommandLine -like '*-placeId %d*' -and $_.CreationDate -ge [datetime]::FromFileTime(%d) } | "
          "ForEach-Object { Stop-Process -Id $_.ProcessId -Force; $_.ProcessId }") % (PLACE_ID, int((depuis + 11644473600) * 10**7))
    r = subprocess.run(["powershell", "-NoProfile", "-Command", ps], capture_output=True, text=True)
    return r.stdout.split()


def session(mode, jeton, scripts, delai=180):
    plugin = ecrire_plugin(scripts, mode, jeton)
    depuis = time.time()
    ident = "publier-%s" % jeton
    try:
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", HDESK_LANCER,
                        "-Id", ident, "-Executable", studio_exe(),
                        "-Arguments", "-task EditPlace -placeId %d -universeId %d" % (PLACE_ID, UNIVERSE_ID),
                        "-Travail", "republication Brainrot Royale (%s)" % mode,
                        "-Conversation", os.environ.get("AUTOWIN_CONVERSATION_ID", "conv-873"),
                        "-AttenteSecondes", "60", "-SurvieSecondes", "1"], capture_output=True, text=True)
        journal = journal_du_jeton(jeton, depuis, delai)
        if not journal:
            return {"erreur": "le plugin n'a rien ecrit en %d s (place en ligne non chargee ?)" % delai}
        texte = journal.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"\[BRRPUB %s\] PRET mode=\w+ scripts=(\d+) modifies=(\d+) absents=(\d+) refus=(\d+)" % jeton, texte)
        res = {"journal": journal.name, "scripts": int(m.group(1)), "modifies": int(m.group(2)), "absents": int(m.group(3)),
               "refus": int(m.group(4)),
               "differents": re.findall(r"\[BRRPUB %s\] DIFFERENT (\S+)" % jeton, texte)}
        if mode != "appliquer" or res["absents"] or res["refus"] or not res["modifies"]:
            return res
        n_avant = texte.count("Go to PublishSuccessful")
        # Studio finit de charger ses modules integres APRES l'ouverture de la place ; tant que ce
        # n'est pas fait, des entrees du menu Fichier restent grisees et les fleches (qui sautent
        # les entrees grisees) n'atteignent pas « Publier sur Roblox » (constate le 2026-09-27 :
        # geste 8 s apres le chargement -> aucune publication).
        time.sleep(ATTENTE_AVANT_GESTE)
        res["geste"] = publier_au_clavier("AutowinTest_" + ident)
        time.sleep(3)
        res["fenetres_apres_geste"] = [t for _, t in dans_le_bureau("AutowinTest_" + ident, fenetres) if t]
        fin = time.time() + 90
        while time.time() < fin:
            texte = journal.read_text(encoding="utf-8", errors="replace")
            if texte.count("Go to PublishSuccessful") > n_avant:
                v = re.findall(r"CreatorOutput\].*?version (\d+)", texte)
                res["publie"] = True
                res["version"] = int(v[-1]) if v else None
                break
            time.sleep(3)
        else:
            res["publie"] = False
        return res
    finally:
        res_arret = arreter_notre_studio(depuis)
        try:
            plugin.unlink()
        except OSError:
            pass
        time.sleep(1)


def main(argv):
    comparer_seulement = "--comparer-seulement" in argv
    if subprocess.run([sys.executable, str(ROOT / "build.py")], cwd=ROOT, capture_output=True).returncode != 0:
        print("ECHEC : build.py")
        return 1
    scripts = scripts_de_la_place(ROOT / "BrainRotRoyale.rbxlx")
    jeton = str(os.getpid())
    rapport = {"scripts_locaux": len(scripts)}
    if not comparer_seulement:
        a = session("appliquer", jeton + "a", scripts)
        rapport["publication"] = a
        if a.get("erreur"):
            print(json.dumps(rapport, ensure_ascii=False))
            return 1
        if a.get("absents") or a.get("refus"):
            print(json.dumps(rapport, ensure_ascii=False))
            print("REFUS : scripts absents en ligne ou non ecrivables : rien n'est publie.")
            return 2
        if a.get("modifies") and not a.get("publie"):
            print(json.dumps(rapport, ensure_ascii=False))
            print("ECHEC : aucune publication constatee dans le journal (%s)." % a.get("geste"))
            return 1
    c = session("comparer", jeton + "c", scripts)
    rapport["controle"] = c
    print(json.dumps(rapport, ensure_ascii=False))
    if c.get("erreur") or c.get("absents") or c.get("modifies"):
        print("ECHEC : la place en ligne differe encore du code local.")
        return 1
    v = (rapport.get("publication") or {}).get("version")
    print("OK : place en ligne identique au code local (%d scripts)%s." % (c["scripts"], (", version %s" % v) if v else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
