-- CAPTURE PRODUITE PAR LE MOTEUR (copie de test seulement).
-- Mesure du 2026-09-14 (conv-531) : CaptureService:CaptureScreenshot fonctionne dans un bureau
-- Windows CACHE, la ou PrintWindow ne rend qu'une zone unie — le moteur rend, seul le compositeur
-- Windows manque. L'image est ecrite par Studio dans %LOCALAPPDATA%\Roblox	mp-capture-storage
-- (fichier wob-<pid>...), au format PNG. C'est la seule voie SANS aucune apparition sur l'ecran de
-- l'utilisateur : tout le reste passe par le bureau reel. Recuperee par tools/studio-capture-moteur.ps1.
local rs = game:GetService("ReplicatedStorage")
if not rs:FindFirstChild("BRR_AUTOTEST") then return end
-- Test multijoueur : chaque client envoie « GG » juste avant la capture, pour que la bulle d'emote
-- soit sur l'image (le serveur refuse celle du spectateur : c'est aussi ce qu'on verifie).
task.delay(22, function()
	local e = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("Emote")
	if e then
		e:FireServer("gg")
	end
end)
-- DELAI AVANT LA PHOTO. 25 s pour une PARTIE : il faut laisser la bataille s'installer et
-- l'emote « GG » monter a 22 s. Mais pour une capture de MENU (BRR_ONGLET present), il n'y a
-- rien a attendre : le hub est pret ~2 s apres Play. Et attendre coute la capture — mesure du
-- 2026-09-20 : trois sessions d'affilee arretees a 23 s par le nettoyage d'un run voisin, donc
-- toujours AVANT la 25e seconde. A 12 s, la photo est prise avant la coupure.
-- DELAI REGLABLE (build.py --capture-delai=N) : certaines scenes n'existent que TARD — la fin
-- du tutoriel arrive vers 70 s. Mesure du 2026-09-20 : la photo partait a 25 s et montrait
-- un menu vide, alors que le journal prouvait l'ouverture de l'ecran a 67 s. Le delai figE
-- photographiait donc autre chose que ce qu'on voulait voir.
local reglage = rs:FindFirstChild("BRR_CAP_DELAI")
local attente = (reglage and reglage.Value > 0 and reglage.Value)
	or (rs:FindFirstChild("BRR_ONGLET") and 12 or 25)
local function prendre()
	local ok, err = pcall(function()
		local cs = game:GetService("CaptureService")
		print("[BRRCAP] service trouve, methodes = " .. tostring(typeof(cs.CaptureScreenshot)))
		-- PAS de PromptSaveCapturesToGallery : mesure du 2026-09-14, il ouvre dans le jeu une boite
		-- « Enregistrer les captures ? » qui MASQUE le centre de la vue sur les captures suivantes.
		-- Le fichier est deja ecrit par Studio dans tmp-capture-storage sans cette confirmation.
		cs:CaptureScreenshot(function(id)
			print("[BRRCAP] capture prete -> " .. tostring(id))
		end)
	end)
	if not ok then print("[BRRCAP] echec -> " .. tostring(err)) end
end
-- PHOTO DECLENCHEE PAR LE JEU (2026-09-21), DANS TOUS LES MODES DE TEST. Un effet bref (onde de
-- givre, couronne qui vole) ne se photographie pas a delai fixe : le debut de la rafale derivait de
-- +-0,5 s d'une partie a l'autre. N'importe quel code de la copie de test pose l'attribut
-- BRR_PHOTO sur ReplicatedStorage a l'instant voulu — le SERVEUR (repique ici), ou le CLIENT
-- lui-meme (signal local) — et la photo part a ce moment-la.
-- BRR_PHOTO_JEU (build.py : --champion, --couronne, ou --photo-jeu) : le mode prend SA photo, la
-- photo a delai fixe est supprimee (sinon elle serait la derniere, et c'est elle qu'on recupererait).
rs:GetAttributeChangedSignal("BRR_PHOTO"):Connect(function()
	print("[BRRCAP] photo demandee par le jeu")
	prendre()
end)
if not rs:FindFirstChild("BRR_PHOTO_JEU") then
	task.delay(attente, prendre)
end
