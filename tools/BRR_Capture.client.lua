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
local attente = rs:FindFirstChild("BRR_ONGLET") and 12 or 25
task.delay(attente, function()
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
end)
