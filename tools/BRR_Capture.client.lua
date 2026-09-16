-- CAPTURE PRODUITE PAR LE MOTEUR (copie de test seulement).
-- Mesure du 2026-09-14 (conv-531) : CaptureService:CaptureScreenshot fonctionne dans un bureau
-- Windows CACHE, la ou PrintWindow ne rend qu'une zone unie — le moteur rend, seul le compositeur
-- Windows manque. L'image est ecrite par Studio dans %LOCALAPPDATA%\Roblox	mp-capture-storage
-- (fichier wob-<pid>...), au format PNG. C'est la seule voie SANS aucune apparition sur l'ecran de
-- l'utilisateur : tout le reste passe par le bureau reel. Recuperee par tools/studio-capture-moteur.ps1.
local rs = game:GetService("ReplicatedStorage")
if not rs:FindFirstChild("BRR_AUTOTEST") then return end
task.delay(25, function()
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
