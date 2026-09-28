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
  3. Fichier > Publier sur Roblox, PAR SON NOM via l'accessibilite (tools/studio_menu_uia.ps1).
     Le premier geste (clic a coordonnees fixes puis 15 fleches) a cesse de marcher avec la mise a
     jour de Studio du 2026-09-27 14 h 45 : barre de menus a une autre echelle, entrees ajoutees au
     menu Fichier (un second « Sauvegarder sur Roblox »).
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
import shutil
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
MENU_UIA = ROOT / "tools" / "studio_menu_uia.ps1"
ENTREE_PUBLIER = "Publier sur Roblox"  # nom EXACT de l'entree du menu Fichier (Studio en francais)
ATTENTE_AVANT_GESTE = 45  # secondes entre « place prete » et le geste (entrees grisees avant)


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


def a_une_barre_de_titre(h):
    return (u32.GetWindowLongW(h, -16) & 0x00C00000) == 0x00C00000  # GWL_STYLE & WS_CAPTION


def ranger_recuperations():
    """Une sauvegarde de RECUPERATION de cette place (Studio en ecrit une toutes les 5 min) fait
    afficher, a chaque ouverture suivante, une boite « recuperer ? » qui BLOQUE le menu Fichier
    (constate le 2026-09-27 : 126168119650545_AutoRecovery_0.rbxl de 08:14). Elles sont DEPLACEES
    dans archives/ (jamais supprimees), et seulement celles de CETTE place."""
    dossier = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "RobloxStudio" / "AutoSaves"
    ranges = []
    for f in dossier.glob("%d_AutoRecovery_*.rbxl" % PLACE_ID):
        dest = ROOT / "archives" / "autosaves-studio" / time.strftime("%Y%m%d-%H%M%S")
        dest.mkdir(parents=True, exist_ok=True)
        shutil.move(str(f), str(dest / f.name))  # autre disque : rename echoue (WinError 17)
        ranges.append(str(dest / f.name))
    return ranges


def publier_par_nom(bureau):
    def boites_bloquantes(d):
        principales = [h for h, t in fenetres(d) if t.endswith("- Roblox Studio")]
        if not principales:
            return "fenetre de Studio introuvable"
        h = principales[0]
        # Une boite de dialogue (barre de titre) bloque la fenetre : ne RIEN lui envoyer.
        boites = [t for m, t in fenetres(d) if m != h and t and a_une_barre_de_titre(m)]
        return "boite de dialogue bloquante : %s" % boites if boites else None
    bloque = dans_le_bureau(bureau, boites_bloquantes)
    if bloque:
        return bloque
    r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(MENU_UIA),
                        "-Bureau", bureau, "-Menu", "Fichier", "-Entree", ENTREE_PUBLIER],
                       capture_output=True, text=True, timeout=60)
    return (r.stdout.strip() or r.stderr.strip() or "sans reponse").splitlines()[-1]


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
    recuperations = ranger_recuperations()
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
        charge = re.search(r"asset/\?id=%d&version=(\d+)" % PLACE_ID, texte)
        res = {"recuperations_rangees": recuperations, "journal": journal.name,
               "version_chargee": int(charge.group(1)) if charge else None, "scripts": int(m.group(1)), "modifies": int(m.group(2)), "absents": int(m.group(3)),
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
        res["geste"] = publier_par_nom("AutowinTest_" + ident)
        time.sleep(3)
        res["fenetres_apres_geste"] = [t for _, t in dans_le_bureau("AutowinTest_" + ident, fenetres) if t]
        fin = time.time() + 90
        while time.time() < fin:
            texte = journal.read_text(encoding="utf-8", errors="replace")
            if texte.count("Go to PublishSuccessful") > n_avant:
                time.sleep(3)  # la ligne « version N » suit la reussite de quelques millisecondes
                texte = journal.read_text(encoding="utf-8", errors="replace")
                v = re.findall(r"CreatorOutput\].*?version (\d+)", texte)
                res["publie"] = True
                res["version"] = int(v[-1]) if v else None
                break
            time.sleep(3)
        else:
            res["publie"] = False
        if res["geste"] != "ok":
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
    print("OK : place en ligne (version %s) identique au code local (%d scripts)." % (c.get("version_chargee"), c["scripts"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
